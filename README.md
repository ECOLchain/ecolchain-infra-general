# ecolchain-infra-general

Infraestrutura como código (Terraform) do ecossistema ecolchain: recursos de rede,
DNS, e-mail e hosting nos providers **OCI**, **Cloudflare** e **Vercel**.

## Estrutura

```
infra/
├── secret.env                  # LOCAL (gitignored) - credenciais de uso local
└── terraform/
    ├── oci/
    │   └── tfstate-backend/    # Bucket OCI de state + Customer Secret Key (S3)
    ├── landing-page/           # Projeto Vercel + DNS ecolchain.com / www (Cloudflare)
    └── cloudflare/
        └── email-routing/      # Email Routing catch-all -> Gmail (Cloudflare)
```

Cada pasta com `*.tf` é um **módulo raiz** com state próprio. A esteira detecta
automaticamente qualquer diretório novo com arquivos `.tf` sob `infra/terraform`.

## Backend remoto (OCI Object Storage)

O state de todos os módulos fica no bucket **`ecolchain-tfstate`** na OCI
(região `sa-saopaulo-1`), acessado via API compatível com S3:

```
bucket    = ecolchain-tfstate
endpoint  = https://grmykw8bmw9d.compat.objectstorage.sa-saopaulo-1.oraclecloud.com
key       = <ambiente>/<modulo>/terraform.tfstate
```

Layout de chaves adotado: **`{env}/{módulo}/terraform.tfstate`** — ex.:

```
prod/oci/tfstate-backend/terraform.tfstate
prod/landing-page/terraform.tfstate
prod/cloudflare/email-routing/terraform.tfstate
```

O bucket é compartilhado com outros repos — para projetar um state de outro
repo/app, basta usar uma key única (`dev/backend-core/`, `prod/app-x/`...).

- **Locking**: `use_lockfile = true` — lock nativo por objeto `.tflock` no bucket.
- **Versioning** do bucket habilitado (histórico de states para recuperação).
- Credenciais do backend = Customer Secret Key OCI (`AWS_ACCESS_KEY_ID` /
  `AWS_SECRET_ACCESS_KEY`), **não** é AWS — é só o protocolo S3-compatible.

## Esteira CI/CD (feature -> main)

```
push em feature/** ──► CI: fmt + validate + plan (matrix: cada módulo)
                     └─► auto-cria/atualiza PR → main com o plan no comentário
                     └─► revisão/aprovação do PR é o gate humano

merge na main ──────► CD: init + plan -out + apply (matrix: cada módulo)
                     └─► escreve no state remoto e aplica nos providers
```

| Workflow | Trigger | O que faz |
|---|---|---|
| `ci-terraform-plan.yml` | push em `feature/**`, `feat/**` | Detecta módulos → matrix: `fmt -check`, `init`, `validate`, `plan` → abre/atualiza PR para `main` com o output do plan de cada módulo em comentário |
| `ci-terraform-apply.yml` | push em `main` | Mesmo matrix → `init`, `plan -out=tfplan`, `apply tfplan` (concurrency por módulo) |

## Secrets

### GitHub Secrets (repo) — criadas com `gh secret set`

| Secret | Uso |
|---|---|
| `OCI_S3_ACCESS_KEY` / `OCI_S3_SECRET_KEY` | Backend S3 da OCI (`AWS_*_KEY`) |
| `OCI_TENANCY_OCID` / `OCI_USER_OCID` / `OCI_FINGERPRINT` | Provider `oci` (módulo tfstate-backend) |
| `OCI_PRIVATE_KEY` | API key PEM do provider `oci` (escrita em arquivo no runner) |
| `CLOUDFLARE_API_KEY` | `TF_VAR_cloudflare_api_key` |
| `CLOUDFLARE_EMAIL` | `TF_VAR_cloudflare_email` |
| `CLOUDFLARE_ZONE_ID` | `TF_VAR_cloudflare_zone_id` |
| `CLOUDFLARE_ACCOUNT_ID` | `TF_VAR_cloudflare_account_id` |
| `VERCEL_API_TOKEN` | `TF_VAR_vercel_api_token` |

Variáveis viram `TF_VAR_*` no env dos workflows. Se um módulo declarar uma
`variable` nova, crie a secret correspondente e adicione `TF_VAR_<nome>` no
bloco `env` dos dois workflows.

### Arquivos locais (todos gitignored — nunca commitar)

| Arquivo | Conteúdo |
|---|---|
| `infra/secret.env` | Credenciais gerais (Cloudflare key, Vercel token, bloco OCI) |
| `<módulo>/env/terraform.tfvars` | Valores de variáveis para uso local (`-var-file`) |
| `oci/tfstate-backend/env/backend.env` | `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` do backend |
| `~/.oci/ecolchain_terraform.pem` | API key OCI (chmod 600) |

## Como alterar recursos existentes

1. Crie a branch a partir da `main`:
   ```bash
   git checkout -b feat/minha-mudanca
   ```
2. Edite os `.tf` do módulo desejado.
3. (Opcional) valide localmente — veja "Uso local" abaixo.
4. Commit + push:
   ```bash
   git push -u origin feat/minha-mudanca
   ```
5. A esteira roda `fmt`/`validate`/`plan` e abre (ou atualiza) o PR para `main`
   com o plan de cada módulo no comentário.
6. Revise o plan no PR. Se estiver correto, aprove e faça o merge.
7. No merge, a esteira de CD executa `terraform apply` nos módulos.

## Como adicionar um novo módulo

1. Crie o diretório seguindo a hierarquia do provider/serviço:
   ```bash
   mkdir -p infra/terraform/<provider>/<app>
   ```
2. Crie `backend.tf` copiando um existente e trocando apenas a `key`:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "ecolchain-tfstate"
       key    = "prod/<provider>/<app>/terraform.tfstate"   # única por módulo
       region = "sa-saopaulo-1"
       endpoints = {
         s3 = "https://grmykw8bmw9d.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
       }
       skip_region_validation      = true
       skip_credentials_validation = true
       skip_requesting_account_id  = true
       skip_metadata_api_check     = true
       skip_s3_checksum            = true   # obrigatório p/ OCI
       use_path_style              = true   # obrigatório p/ OCI (cert TLS)
       use_lockfile                = true
     }
   }
   ```
3. Crie `main.tf` / `variables.tf` / `outputs.tf` com os recursos.
4. Se usar variáveis sensíveis: crie as secrets (`gh secret set NOME -b "valor"`)
   e adicione `TF_VAR_nome: ${{ secrets.NOME }}` no `env` dos dois workflows.
5. Rode localmente para gerar o lock file multiplataforma e commitar:
   ```bash
   source infra/terraform/oci/tfstate-backend/env/backend.env
   terraform -chdir=infra/terraform/<provider>/<app> init -input=false
   terraform -chdir=infra/terraform/<provider>/<app> providers lock \
     -platform=linux_amd64 -platform=darwin_arm64
   ```
   > Para um módulo novo (sem state a migrar), `terraform init` já cria o state
   > remoto vazio no primeiro uso — nada a fazer além disso.
6. Push na `feat/...` — a esteira descobre o módulo automaticamente pelo matrix.

## Como adicionar um novo ambiente

Use o prefixo da `key` do backend: `dev/`, `staging/`, `prod/`...

Para o mesmo app em outro ambiente, crie outra pasta de módulo (ou use
workspaces/tfvars separados por ambiente) apontando para a key
`dev/<app>/terraform.tfstate` — nunca compartilhe a mesma key entre ambientes.

## Uso local

```bash
cd infra/terraform/<provider>/<app>

# credenciais do backend (S3/OCI)
source ../../oci/tfstate-backend/env/backend.env   # exporta AWS_*_KEY + region

terraform init -input=false                        # 1a vez: cria/migra state remoto
terraform plan -var-file=env/terraform.tfvars
terraform apply -var-file=env/terraform.tfvars
```

O módulo `oci/tfstate-backend` adicionalmente lê `env/terraform.tfvars` com
`tenancy_ocid`, `user_ocid`, `fingerprint`, `region` e a key em
`~/.oci/ecolchain_terraform.pem` (`private_key_path`).

## Requisitos do backend OCI (por que o backend.tf é assim)

- `use_path_style = true`: o certificado TLS da OCI não cobre o subdomínio do
  bucket (`<bucket>.<namespace>.compat...`) — virtual-hosted falha.
- `skip_s3_checksum = true` + `AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED`:
  o SDK Go v2 envia trailers de checksum que a OCI não suporta.
- Customer Secret Keys da OCI podem levar alguns minutos para propagar após a
  criação — um `SignatureDoesNotMatch` transitório logo após criar é esperado.

## Convenções

- Variáveis sensíveis sempre `sensitive = true` em `variables.tf`.
- `.terraform.lock.hcl` **é commitado** — sempre gere para `linux_amd64`
  (CI) e `darwin_arm64` (local) com `terraform providers lock`.
- `*.tfstate`, `*.tfvars`, `*.env`, `*.pem`, `env/` são gitignored por padrão.
# ecolchain-infra-general
Projetc for save general docs
