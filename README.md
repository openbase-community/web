# API Core

This repo provides the backbone of all Django webapps/APIs. It is a framework that these webapps/APIs fit into and can rely on, with a shared `settings.py` file, logic regarding users, contact, and email. To add functionality, you can install "app packages", which are pip packages containing one or more Django apps that will automatically have their URLs and models imported.

## Local Setup

Use the workspace-level setup script for a full local install:

`./scripts/setup`

For coding agents or other unattended environments, use:

`./scripts/setup --non-interactive`

Non-interactive setup behavior:

- Requires the workspace `.env` file to already exist and exits immediately if it does not.
- Creates or updates the default development superuser without prompting.
- Defaults to `test@example.com` / `test` for the development superuser.
- Allows overriding the default superuser with `DEV_SUPERUSER_EMAIL` and `DEV_SUPERUSER_PASSWORD`.
- Skips Google OAuth setup if credentials are not provided.
- Allows providing Google OAuth credentials through `GOOGLE_OAUTH_CREDENTIALS_JSON`.

## Production Deployment Scripts

The `scripts/` directory is now oriented around Terraform + ECS on AWS instead of Heroku.

Environment prerequisites:

- `AWS_REGION` defaults to `us-east-1` if unset
- `GH_PAT` is optional, but needed to install the private GitHub package list during image builds
- `CLOUDFLARE_API_TOKEN` is needed for the Cloudflare DNS/origin-cert setup step

Terraform state defaults to `openbase-terraform-state-<aws-account-id>-<aws-region>`. Set `TF_STATE_BUCKET` only if you want to override that convention.

Typical flow:

1. Create a local Terraform vars file:
   `./scripts/prod-new-deployment <stack-name> [environment]`
2. Build and push the shared app image:
   `./scripts/prod-build <stack-name> "<app-requirements>" [environment] [image-tag]`
   If omitted, the build defaults to installing `openbase-cloud-api` from GitHub.
3. Apply infrastructure:
   `./scripts/prod-infra-apply <stack-name> [environment] [image-tag]`
4. Configure Cloudflare DNS, origin certs, and strict SSL:
   `./scripts/prod-cloudflare-setup <stack-name> [environment]`
5. Deploy both ECS services together:
   `./scripts/prod-deploy <stack-name> [environment] [image-tag]`
6. Roll back both ECS services together if needed:
   `./scripts/prod-rollback <stack-name> [environment]`
7. Open an interactive one-off shell in the web image:
   `./scripts/prod-shell <stack-name> [environment]`
8. View merged CloudWatch logs across web, worker, and host-level Caddy access logs:
   `./scripts/prod-logs <stack-name> [environment] [--tail] [--lines <count>]`

Production-facing operational entrypoints are prefixed with `prod-` so they do not read like local dev helpers.
`./scripts/prod-deploy` always updates `web` and `worker` in the same release, using the same application image for both task definitions, and runs database migrations before shifting the services.
`./scripts/prod-shell` starts a one-off ECS task from the current web task definition and attaches with ECS Exec. It requires `session-manager-plugin` locally, and the image must include `/bin/bash`.
`./scripts/prod-logs` reads `/web`, `/worker`, and `/caddy` CloudWatch log groups, merges them by timestamp, and can either show recent logs or keep polling with `--tail`. Use `--lines <count>` if you want the last N merged log lines instead of a fixed time window.
The S3/CDN bucket CORS policy is Terraform-managed; by default it allows the configured `web_hostname` origin to fetch assets, and you can extend that with `frontend_cors_allowed_origins` in your tfvars file.
