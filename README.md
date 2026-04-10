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
The reusable AWS foundation Terraform now lives in the sibling `infra` repo, while `api-core/terraform` keeps the app-specific ECS and Cloudflare layer.

Environment prerequisites:

- `AWS_REGION` defaults to `us-east-1` if unset
- `GH_PAT` is optional, but needed to install the private GitHub package list during image builds
- `CLOUDFLARE_API_TOKEN` is needed for Terraform-managed Cloudflare DNS/rules and the Origin CA setup step

Terraform state defaults to `openbase-terraform-state-<aws-account-id>-<aws-region>`. Set `TF_STATE_BUCKET` only if you want to override that convention.

Typical flow:

1. Create a local Terraform vars file:
   `./scripts/new-deployment <stack-name> [environment]`
2. Set `APP_REQUIREMENTS` in `deploy/<environment>.env`.
   That untracked deploy manifest is the source of truth for the private app package list and the currently intended image tag.
3. Build and push the shared app image:
   `./scripts/build <stack-name> [app-requirements] [environment] [image-tag]`
   If `app-requirements` is omitted, build reads `APP_REQUIREMENTS` from `deploy/<environment>.env`.
   If `image-tag` is omitted, the build generates a UTC timestamp tag automatically.
   After a successful push, build updates `deploy/<environment>.env` with the canonical `APP_REQUIREMENTS` and the new `IMAGE_TAG`.
4. Apply infrastructure:
   `./scripts/infra-apply <stack-name> [environment] [image-tag]`
   If `image-tag` is omitted, infra apply uses `IMAGE_TAG` from `deploy/<environment>.env`.
5. Issue the Cloudflare Origin CA cert and reload Caddy:
   `./scripts/cloudflare-setup <stack-name> [environment]`
6. Deploy both ECS services together:
   `./scripts/deploy <stack-name> [environment] [image-tag]`
   If `image-tag` is omitted, deploy uses `IMAGE_TAG` from `deploy/<environment>.env`.
7. Roll back both ECS services together if needed:
   `./scripts/rollback-deployment <stack-name> [environment]`
8. Open an interactive one-off shell in the web image:
   `./scripts/cloud-shell <stack-name> [environment]`
9. View merged CloudWatch logs across web, worker, and host-level Caddy access logs:
   `./scripts/cloud-logs <stack-name> [environment] [--tail] [--lines <count>]`
10. Set or unset shared ECS secrets in SSM + tfvars:
   `./scripts/cloud-config set <stack-name> <environment> <env-var> [value]`
   `./scripts/cloud-config unset <stack-name> <environment> <env-var>`

Only the top-level commands in `scripts/` are intended as operator entrypoints. Internal helper scripts live under `scripts/internal/`.
`./scripts/deploy` always updates `web` and `worker` in the same release, using the same application image for both task definitions, and runs database migrations before shifting the services.
`./scripts/cloud-shell` starts a one-off ECS task from the current web task definition and attaches with ECS Exec. It requires `session-manager-plugin` locally, and the image must include `/bin/bash`.
`./scripts/cloud-logs` reads `/web`, `/worker`, and `/caddy` CloudWatch log groups, merges them by timestamp, and can either show recent logs or keep polling with `--tail`. Use `--lines <count>` if you want the last N merged log lines instead of a fixed time window.
The S3/CDN bucket CORS policy is Terraform-managed; by default it allows the configured `web_hostname` origin to fetch assets, and you can extend that with `frontend_cors_allowed_origins` in your tfvars file.
Cloudflare DNS for `web_hostname` / `cdn_hostname` and the CDN flexible-SSL config rule are Terraform-managed; `./scripts/cloudflare-setup` now only handles Origin CA certificate issuance and host reload.

## Adding an Environment Variable

Environment variables for ECS are configured through your untracked `terraform/<environment>.tfvars` file:

- Use `common_secrets` for all operator-managed app config values. `web` and `worker` always receive the same set through ECS secret injection.
- Terraform still injects infrastructure-derived values like database host, Redis host, bucket names, ports, and `ALLOWED_HOSTS` as plain environment variables.

For operator-managed app config, use `./scripts/cloud-config`. It always writes to `common_secrets`, so both `web` and `worker` get the same config set through SSM.

```bash
./scripts/cloud-config set openbase-api-core prod STRIPE_SECRET_KEY --from-heroku openbase
```

That one command:

- reads the config value from Heroku
- writes it to SSM Parameter Store at `/<stack-name>/<environment>/<lowercase-secret-name>`
- updates `common_secrets` in tfvars with the parameter ARN
- formats the tfvars file
- reapplies the ECS task definitions in Terraform and redeploys ECS using `IMAGE_TAG` from `deploy/<environment>.env`

You can also pipe a generated or local value into it:

```bash
openssl rand -base64 32 | ./scripts/cloud-config set openbase-api-core prod DJANGO_SECRET_KEY
```

To remove a shared config value from tfvars and delete its SSM parameter:

```bash
./scripts/cloud-config unset openbase-api-core prod STRIPE_SECRET_KEY
```

Use `--no-redeploy` only if you want to stage the config change without immediately rolling ECS.
