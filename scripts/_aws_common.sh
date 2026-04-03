#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${REPO_DIR}/terraform"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID_CACHE="${AWS_ACCOUNT_ID_CACHE:-}"

fail() {
    echo "Error: $*" >&2
    exit 1
}

require_commands() {
    local cmd
    for cmd in "$@"; do
        command -v "${cmd}" >/dev/null 2>&1 || fail "Missing required command: ${cmd}"
    done
}

require_env() {
    local name="$1"
    [[ -n "${!name:-}" ]] || fail "Missing required environment variable: ${name}"
}

default_image_tag() {
    git -C "${REPO_DIR}" rev-parse --short HEAD
}

aws_account_id() {
    if [[ -z "${AWS_ACCOUNT_ID_CACHE}" ]]; then
        AWS_ACCOUNT_ID_CACHE="$(
            aws sts get-caller-identity \
                --query 'Account' \
                --output text
        )"
    fi

    printf '%s\n' "${AWS_ACCOUNT_ID_CACHE}"
}

ecr_repository_name() {
    local stack_name="$1"
    local environment="$2"
    local component="$3"

    printf '%s-%s-%s\n' "${stack_name}" "${environment}" "${component}"
}

ecr_repository_uri() {
    local stack_name="$1"
    local environment="$2"
    local component="$3"

    printf '%s.dkr.ecr.%s.amazonaws.com/%s\n' \
        "$(aws_account_id)" \
        "${AWS_REGION}" \
        "$(ecr_repository_name "${stack_name}" "${environment}" "${component}")"
}

ensure_ecr_repository() {
    local stack_name="$1"
    local environment="$2"
    local component="$3"
    local repository_name

    repository_name="$(ecr_repository_name "${stack_name}" "${environment}" "${component}")"

    if ! aws ecr describe-repositories --repository-names "${repository_name}" >/dev/null 2>&1; then
        aws ecr create-repository \
            --repository-name "${repository_name}" \
            --image-scanning-configuration scanOnPush=true >/dev/null
    fi
}

ensure_ecr_image_tag() {
    local stack_name="$1"
    local environment="$2"
    local component="$3"
    local image_tag="$4"
    local repository_name

    repository_name="$(ecr_repository_name "${stack_name}" "${environment}" "${component}")"

    aws ecr describe-images \
        --repository-name "${repository_name}" \
        --image-ids "imageTag=${image_tag}" >/dev/null 2>&1 || \
        fail "Missing ${component} image tag ${image_tag} in ${repository_name}. Run ./scripts/prod-build first."
}

ecr_login() {
    aws ecr get-login-password --region "${AWS_REGION}" | \
        docker login \
            --username AWS \
            --password-stdin "$(aws_account_id).dkr.ecr.${AWS_REGION}.amazonaws.com"
}

tfvars_file_for_environment() {
    local environment="$1"

    if [[ -n "${TF_VARS_FILE:-}" ]]; then
        printf '%s\n' "${TF_VARS_FILE}"
        return
    fi

    printf '%s/%s.tfvars\n' "${TERRAFORM_DIR}" "${environment}"
}

require_tfvars_file() {
    local environment="$1"
    local tfvars_file

    tfvars_file="$(tfvars_file_for_environment "${environment}")"
    [[ -f "${tfvars_file}" ]] || fail "Missing Terraform vars file: ${tfvars_file}"
    printf '%s\n' "${tfvars_file}"
}

terraform_backend_key() {
    local stack_name="$1"
    local environment="$2"

    printf 'api-core/%s/%s.tfstate\n' "${stack_name}" "${environment}"
}

default_tf_state_bucket() {
    printf 'openbase-terraform-state-%s-%s\n' "$(aws_account_id)" "${AWS_REGION}"
}

write_backend_config() {
    local stack_name="$1"
    local environment="$2"
    local backend_file

    local tf_state_bucket="${TF_STATE_BUCKET:-$(default_tf_state_bucket)}"

    backend_file="$(mktemp "${TMPDIR:-/tmp}/api-core-terraform-backend.XXXXXX.hcl")"
    cat > "${backend_file}" <<EOF
bucket       = "${tf_state_bucket}"
key          = "$(terraform_backend_key "${stack_name}" "${environment}")"
region       = "${AWS_REGION}"
use_lockfile = true
encrypt      = true
EOF

    printf '%s\n' "${backend_file}"
}

terraform_init() {
    local stack_name="$1"
    local environment="$2"
    local backend_file

    backend_file="$(write_backend_config "${stack_name}" "${environment}")"
    terraform -chdir="${TERRAFORM_DIR}" init -reconfigure -backend-config="${backend_file}" >/dev/null
    rm -f "${backend_file}"
}

terraform_output_raw() {
    local output_name="$1"

    terraform -chdir="${TERRAFORM_DIR}" output -raw "${output_name}"
}

terraform_managed_task_definition() {
    local resource_name="$1"

    terraform -chdir="${TERRAFORM_DIR}" state pull | jq -r \
        --arg resource_name "${resource_name}" \
        '.resources[]
        | select(.mode == "managed" and .type == "aws_ecs_task_definition" and .name == $resource_name)
        | .instances[0].attributes.arn'
}

current_service_task_definition() {
    local cluster_name="$1"
    local service_name="$2"

    aws ecs describe-services \
        --cluster "${cluster_name}" \
        --services "${service_name}" \
        --query 'services[0].taskDefinition' \
        --output text
}

task_definition_family() {
    local task_definition_arn="$1"
    local family_revision

    family_revision="${task_definition_arn##*/}"
    printf '%s\n' "${family_revision%:*}"
}

previous_active_task_definition() {
    local family="$1"
    local current_task_definition="$2"

    aws ecs list-task-definitions \
        --family-prefix "${family}" \
        --status ACTIVE \
        --sort DESC \
        --query 'taskDefinitionArns' \
        --output json | jq -r \
        --arg current "${current_task_definition}" \
        '[.[] | select(. != $current)][0] // empty'
}

register_task_definition_with_image() {
    local current_task_definition="$1"
    local container_name="$2"
    local new_image="$3"
    local describe_file
    local register_file

    describe_file="$(mktemp "${TMPDIR:-/tmp}/api-core-task-def.describe.XXXXXX.json")"
    register_file="$(mktemp "${TMPDIR:-/tmp}/api-core-task-def.register.XXXXXX.json")"

    aws ecs describe-task-definition \
        --task-definition "${current_task_definition}" \
        --query 'taskDefinition' \
        --output json > "${describe_file}"

    jq \
        --arg container_name "${container_name}" \
        --arg image "${new_image}" \
        '{
            family,
            taskRoleArn,
            executionRoleArn,
            networkMode,
            containerDefinitions: (
                .containerDefinitions |
                map(if .name == $container_name then .image = $image else . end)
            ),
            volumes,
            placementConstraints,
            requiresCompatibilities,
            cpu,
            memory,
            pidMode,
            ipcMode,
            proxyConfiguration,
            inferenceAccelerators,
            ephemeralStorage,
            runtimePlatform
        } | with_entries(select(.value != null))' \
        "${describe_file}" > "${register_file}"

    aws ecs register-task-definition \
        --cli-input-json "file://${register_file}" \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text

    rm -f "${describe_file}" "${register_file}"
}
