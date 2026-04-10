# Terraform

This directory provisions the app-specific deployment layer for `api-core`, on top of the shared AWS foundation module in the sibling `infra` repo:

- ECS on EC2 with:
  - one `t3.small` web host
  - one `t3.medium` worker host
- An Elastic IP for the web host so Cloudflare can proxy traffic to it
- PostgreSQL on RDS using `db.t4g.micro` by default
- Redis on ElastiCache using `cache.t4g.micro` by default
- One S3 bucket for the frontend, Django media, and Django static assets

## Layout

- `backend.tf`: partial remote-state backend declaration
- `versions.tf`: Terraform and provider constraints
- `foundation.tf`: shared AWS foundation module call from `../../infra`
- `ecs.tf`: IAM, ECS cluster, EC2 instances, ECS services, and the web Elastic IP
- `cloudflare.tf`: Cloudflare DNS records and CDN rules
- `moved.tf`: state migrations from the old in-repo AWS resources into the shared module

## Defaults

The defaults are intentionally cost-sensitive rather than production-hard:

- ECS instances live in public subnets to avoid a NAT gateway bill
- Caddy terminates origin TLS on the web EC2 instance and proxies to the ECS web task on host port `8080`
- Cloudflare is expected to sit in front of the web Elastic IP, and the default web-origin ingress only allows Cloudflare's published IPv4 ranges
- RDS is single-AZ with no deletion protection and no retention window
- ElastiCache is a single-node cache cluster
- The S3 bucket is public-read so it can serve the frontend, media, and static assets directly
- The S3 bucket emits CORS headers for `https://<web_hostname>` by default so the app origin can fetch hashed CSS, JS, fonts, and media from the CDN hostname

That keeps spend down, but it is not a hardened production posture.

## Architecture Notes

- There is no ALB in this version because the fixed monthly cost is high for an early-stage single-replica setup.
- The web origin is a single ECS task bound to host port `8080` on a single EC2 instance, fronted by Caddy on `80/443`.
- The worker runs on its own single EC2 instance with no public ingress.
- Deployments should update `web` and `worker` together so both services move to the same application release.
- The web and worker task definitions share one application image and differ only in their ECS `command` values.
- Because there is only one web task and no ALB, deploys and rollbacks will have a brief interruption while ECS stops the old task and starts the new one.
- If you need to allow something besides Cloudflare to hit the origin, override `web_ingress_cidrs`. Otherwise it defaults to Cloudflare's published IPv4 ranges.
- If assets need to be fetched from additional browser origins, override `frontend_cors_allowed_origins`.

## Cloudflare Setup

Cloudflare ownership is split:

- Terraform manages the proxied DNS records for `web_hostname` and `cdn_hostname`
- Terraform manages the CDN hostname configuration rule that forces `SSL: Flexible`
- `./scripts/cloudflare-setup` manages Cloudflare Origin CA issuance plus the Caddy reload on the web host

During `terraform apply`, set `CLOUDFLARE_API_TOKEN` in your shell so the Cloudflare provider can manage the DNS records and ruleset. Then run:

```bash
CLOUDFLARE_API_TOKEN=... ./scripts/cloudflare-setup <stack-name> <environment>
```

That script will:

1. Generate a Cloudflare Origin CA certificate for `web_hostname`.
2. Store the certificate and key in the SSM parameter names configured by:
   - `cloudflare_origin_cert_parameter_name`
   - `cloudflare_origin_key_parameter_name`
3. Reload Caddy on the web host through SSM so it starts serving the new origin certificate.

The Terraform Cloudflare resources expect the zone to already exist in your Cloudflare account. By default the config infers the zone name from the last two labels of `web_hostname`; override that with `cloudflare_zone_name` in your `.tfvars` file if your zone does not follow that shape.

The API token should have permissions for:

- `Zone:Read`
- `DNS:Edit`
- `Config Rules:Edit`
- `SSL and Certificates:Edit`

## Rough Monthly Shape

Using the defaults in `us-east-1`, the rough shape is:

- `t3.small` web EC2: about `$15/mo`
- `t3.medium` worker EC2: about `$30/mo`
- RDS `db.t4g.micro`: roughly `$12/mo` plus storage
- ElastiCache `cache.t4g.micro`: roughly `$12-14/mo`
- Cloudflare: outside AWS billing

So the stack is roughly in the `$70/mo` range before transfer, EBS, snapshots, and growth-driven usage.

## Remote State

Do not commit local state files.

This directory includes a partial `s3` backend block so you can keep state in a shared Terraform state bucket instead of in git. I would keep that bucket outside this stack, at the account or platform level, and pass backend settings during `terraform init`.

Example `backend.hcl`:

```hcl
bucket       = "shared-terraform-state"
key          = "openbase/api-core/dev.tfstate"
region       = "us-east-1"
use_lockfile = true
encrypt      = true
```

Then initialize with:

```bash
terraform init -backend-config=backend.hcl
```

That avoids bootstrapping-state-with-the-same-stack and keeps the state file off developer machines.

## Lock File

You asked not to commit lockfiles here, so `.terraform.lock.hcl` is ignored in this directory. Normally I would commit it for reproducibility, but this setup follows your repo preference.

## Usage

1. Copy `terraform.tfvars.example` to a local `.tfvars` file that stays untracked.
2. Set `web_hostname`, `app_image`, and secret/parameter names.
   Build inputs like `APP_REQUIREMENTS` and the intended `IMAGE_TAG` live in `deploy/<environment>.env`, not in Terraform.
3. Ensure the sibling `infra` repo is present in the workspace, since `foundation.tf` uses a local module source at `../../infra/terraform/modules/aws-app-foundation`.
4. Initialize Terraform with the remote backend config.
5. Run `terraform plan`.
6. Run `terraform apply`.

## Adding Environment Variables

The ECS task definitions take environment configuration from these tfvars maps:

- `common_secrets`: all operator-managed app config values, shared by `web` and `worker`

Terraform still injects infrastructure-derived values like database host, Redis host, ports, bucket names, and `ALLOWED_HOSTS` as plain environment variables.

For operator-managed app config, use `./scripts/cloud-config`. It writes an SSM SecureString parameter and updates `common_secrets` in one step. Both `web` and `worker` always receive the same config set.

Example: migrate the Stripe secret from the legacy Heroku app into prod without writing the secret into git:

```bash
./scripts/cloud-config set openbase-api-core prod STRIPE_SECRET_KEY --from-heroku openbase
```

That command writes the value to SSM at `/openbase-api-core/prod/stripe-secret-key` and updates `terraform/prod.tfvars` under `common_secrets`.
By default it then reapplies the ECS task definitions in Terraform and redeploys ECS using `IMAGE_TAG` from `deploy/<environment>.env`.

For generated or local secrets, pipe the value in:

```bash
openssl rand -base64 32 | ./scripts/cloud-config set openbase-api-core prod DJANGO_SECRET_KEY
```

To remove a shared config value from tfvars and SSM:

```bash
./scripts/cloud-config unset openbase-api-core prod STRIPE_SECRET_KEY
```

Use `--no-redeploy` only if you want to stage the config change without immediately rolling ECS.

## Notes

- The web and worker services expect one prebuilt application image, and the ECS task definitions provide the different runtime commands.
- The web origin presents a Cloudflare Origin CA certificate from SSM. If you use a customer-managed KMS key for those parameters, grant the web instance role permission to decrypt it.
- The Django app uses PostgreSQL locally, so the Terraform defaults target RDS PostgreSQL.
- If you rely on `pgvector`, confirm the chosen RDS PostgreSQL engine version in your target region before apply.
