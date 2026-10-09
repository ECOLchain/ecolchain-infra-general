# AGENTS.md

Terraform IaC (OCI, Cloudflare, Vercel). Full docs in README.md.

## Key facts
- Root module = any dir under `infra/terraform` containing `backend.tf` (CI matrix uses `find -name backend.tf`).
- Reusable modules live in `infra/terraform/modules/<name>` and must NOT have `backend.tf`.
- State: OCI bucket `ecolchain-tfstate` via S3 backend; key `<env>/<app>/terraform.tfstate`, unique per root module.
- New variable needing a secret: `gh secret set NAME` + add `TF_VAR_<name>` to `env` of BOTH workflows in `.github/workflows/`.
- CI (push `feature/**`/`feat/**`): `.github/scripts/detect-changed-modules.sh` diffs vs `main` and plans only affected root modules (changes under `modules/` mark consumers). CD (push `main`): non-prod keys (`dev/`, `staging/`...) apply via matrix; `prod/` keys apply sequentially in a single job gated by GitHub environment `prod` (Required reviewers). Unknown key prefixes fall back to prod.
- Cloudflare worker scripts using `export default` need `main_module` set.

## Verification
- `terraform fmt -check -recursive infra/terraform`
- `terraform -chdir=<dir> validate` (after `init`; backend creds from `infra/terraform/oci/tfstate-backend/env/backend.env`)
- After adding providers: `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`
