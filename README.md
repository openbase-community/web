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

## AWS Deployment Scripts

The `scripts/` directory is now oriented around Terraform + ECS on AWS instead of Heroku.

Environment prerequisites:

- `AWS_REGION` defaults to `us-east-1` if unset
- `GH_PAT` is optional, but needed to install the private GitHub package list during image builds
- `CLOUDFLARE_API_TOKEN` is needed for the Cloudflare DNS/origin-cert setup step

Terraform state defaults to `openbase-terraform-state-<aws-account-id>-<aws-region>`. Set `TF_STATE_BUCKET` only if you want to override that convention.

Typical flow:

1. Create a local Terraform vars file:
   `./scripts/new_deployment <stack-name> [environment]`
2. Build and push both images together:
   `./scripts/build <stack-name> "<app-requirements>" [environment] [image-tag]`
   If omitted, the build defaults to installing `openbase-cloud-api` from GitHub.
3. Apply infrastructure:
   `./scripts/infra_apply <stack-name> [environment] [image-tag]`
4. Configure Cloudflare DNS, origin certs, and strict SSL:
   `./scripts/cloudflare_setup <stack-name> [environment]`
5. Deploy both ECS services together:
   `./scripts/deploy <stack-name> [environment] [image-tag]`
6. Roll back both ECS services together if needed:
   `./scripts/rollback <stack-name> [environment]`
7. Open an interactive one-off shell in the web image:
   `./scripts/shell <stack-name> [environment]`
8. View merged CloudWatch logs across web, worker, and host-level Caddy access logs:
   `./scripts/logs <stack-name> [environment] [--tail]`

`./scripts/deploy` always updates `web` and `worker` in the same release and runs database migrations before shifting the services.
`./scripts/shell` starts a one-off ECS task from the current web task definition and attaches with ECS Exec. It requires `session-manager-plugin` locally, and the image must include `/bin/bash`.
`./scripts/logs` reads `/web`, `/worker`, and `/caddy` CloudWatch log groups, merges them by timestamp, and can either show recent logs or keep polling with `--tail`.
