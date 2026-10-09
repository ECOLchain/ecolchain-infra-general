# ecolchain-infra-general

Infraestrutura como código (Terraform) do ecossistema ecolchain: recursos de rede,
DNS, e-mail e hosting nos providers **OCI**, **Cloudflare** e **Vercel**.

## Estrutura

```
infra/
├── secret.env                  # LOCAL (gitignored) - credenciais de uso local
└── terraform/
    ├── oci/
    │   ├── tfstate-backend/    # Bucket OCI de state + Customer Secret Key (S3)
    │   └── email-delivery/     # OCI Email Delivery: dominio ecolchain.com + DKIM (Cloudflare) + sender + SMTP
    ├── landing-page/           # Projeto Vercel + DNS ecolchain.com / www (Cloudflare)
    ├── cloudflare/
    │   └── email-routing/      # Email Routing catch-all -> Gmail (Cloudflare)
    ├── core-web/
    │   ├── prod/               # app.ecolchain.com (bucket OCI + worker Cloudflare)
    │   └── dev/                # app-dev-tester.ecolchain.com (Basic Auth)
    ├── management-api/         # Dados da API de gestão (ADB + bucket de documentos)
    ├── management-web/
    │   ├── prod/               # manage.ecolchain.com (bucket OCI + worker Cloudflare)
    │   └── dev/                # manage-dev.ecolchain.com (Basic Auth)
    └── modules/
        ├── web-hosting/        # Modulo reutilizavel (bucket OCI + worker + dominio)
        └── management-api-data/ # Dados da management-api (ADB, schemas, bucket docs)
```

Cada pasta com `backend.tf` é um **módulo raiz** com state próprio. A esteira
detecta automaticamente qualquer diretório novo com `backend.tf` sob
`infra/terraform`. Diretórios em `modules/` são **módulos reutilizáveis**
(sem `backend.tf`) consumidos pelos módulos raiz.

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
prod/oci/email-delivery/terraform.tfstate
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
push em feature/** ──► CI: detecta módulos ALTERADOS (diff vs main)
                     └─► matrix só com eles: fmt + validate + plan
                     └─► auto-cria/atualiza PR → main com o plan no comentário
                     └─► revisão/aprovação do PR é o gate humano

merge na main ──────► CD: detecta módulos alterados pelo merge
                     ├─► não-prod (key dev/, staging/...): apply automático (matrix)
                     └─► prod (key prod/): job com environment "prod"
                         └─► exige aprovação manual → apply sequencial
```

| Workflow | Trigger | O que faz |
|---|---|---|
| `ci-terraform-plan.yml` | push em `feature/**`, `feat/**` | Detecta módulos **alterados** (diff contra `main`; mudança em `modules/` marca os consumidores) → matrix: `fmt -check`, `init`, `validate`, `plan` → abre/atualiza PR para `main` com tabela de status + plan enxuto por módulo (plan completo no job summary) |
| `ci-terraform-apply.yml` | push em `main` | Detecta módulos alterados pelo merge → **não-prod**: `init`/`plan -out`/`apply` em matrix paralelo → **prod**: job único com `environment: prod` (aprovação obrigatória) que aplica os módulos em sequência |

A classificação prod/não-prod sai do primeiro segmento da `key` do `backend.tf`
(`prod/...` = prod; `dev|staging|stage|qa|test|sandbox` = não-prod; qualquer
outro prefixo cai em prod por segurança). Script:
`.github/scripts/detect-changed-modules.sh` (executável localmente:
`detect-changed-modules.sh --three-dot origin/main HEAD`).

### Gate de produção (environment `prod`)

O job `apply-prod` referencia o environment `prod`, que o GitHub cria
automaticamente no primeiro uso. Para o gate de aprovação funcionar, um **admin
do repo** precisa configurar uma vez:
**Settings → Environments → prod → Required reviewers** (ex.: `leandroleitetech`).

Sem essa regra, o job aplica sem gate (comportamento anterior). Opcionalmente,
em "Deployment branches", restrinja o environment à branch `main`.

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

## E-mail transacional (OCI Email Delivery)

Módulo `infra/terraform/oci/email-delivery` (state
`prod/oci/email-delivery/terraform.tfstate`). Habilita o envio de e-mails da
app (ex.: código de verificação de cadastro da `ecolchain-management-api`)
pelo OCI Email Delivery, com remetente `ecolchain@ecolchain.com`, região
`sa-saopaulo-1`.

| Recurso | O que é |
|---|---|
| `oci_email_email_domain.ecolchain` | Email Domain `ecolchain.com` |
| `oci_email_dkim.ecolchain` + `cloudflare_dns_record.dkim` | Assinatura DKIM; CNAME criado no Cloudflare (DNS only) |
| `oci_email_sender.ecolchain` | Approved Sender `ecolchain@ecolchain.com` — o `From` das mensagens precisa ser exatamente esse |
| `oci_identity_smtp_credential.app` | Usuário/senha SMTP gerados pela OCI, no usuário do Terraform |

Não exige secrets novas: usa as mesmas `TF_VAR_*` dos outros módulos
(OCI + Cloudflare). Todas as variáveis novas têm default (`email_domain`,
`sender_email`, `dkim_selector`, `smtp_credential_description`; também
`region`, `private_key_path`, `cloudflare_email`, `cloudflare_zone_id`).
Como no resto do repo, `tenancy_ocid`, `user_ocid`, `fingerprint` e
`cloudflare_api_key` **não** têm default (vêm das GitHub Secrets ou do
`env/terraform.tfvars` local).

### Obter as credenciais SMTP (para a app)

```bash
set -a; source infra/terraform/oci/tfstate-backend/env/backend.env; set +a   # backend.env nao tem "export": set -a exporta para o terraform
terraform -chdir=infra/terraform/oci/email-delivery init -input=false
terraform -chdir=infra/terraform/oci/email-delivery output smtp_endpoint    # quarkus.mailer.host
terraform -chdir=infra/terraform/oci/email-delivery output smtp_port        # 465 (TLS implícito)
terraform -chdir=infra/terraform/oci/email-delivery output -raw smtp_username
terraform -chdir=infra/terraform/oci/email-delivery output -raw smtp_password
```

Como configurar a app: seção "Envio de e-mail" do README da
`ecolchain-management-api`.

### Outputs atuais (prod)

Valores do apply em prod (08/10/2026); sem secrets. `smtp_username` (contém
OCIDs) e `smtp_password` saem só via `terraform output -raw` e **não** devem
ser commitados.

| Output | Valor | Uso na app |
|---|---|---|
| `smtp_endpoint` | `smtp.email.sa-saopaulo-1.oci.oraclecloud.com` | `quarkus.mailer.host` |
| `smtp_port` | `465` (TLS implícito) | `quarkus.mailer.port` + `quarkus.mailer.tls=true` |
| `sender_email` | `ecolchain@ecolchain.com` | `quarkus.mailer.from` |
| `smtp_username` | sensível (ver comando acima: `terraform output -raw smtp_username`) | `QUARKUS_MAILER_USERNAME` |
| `smtp_password` | sensível (`terraform output -raw smtp_password`) | `QUARKUS_MAILER_PASSWORD` |
| `dkim_cname` | `ecolchain-gru-20261008._domainkey.ecolchain.com` -> `ecolchain-gru-20261008.ecolchain.com.dkim.gru1.oracleemaildelivery.com` | criado pelo módulo no Cloudflare (DNS only) |
| `dkim_state` | `ACTIVE` (o output só reflete o último apply/refresh; o log do apply mostrou `NEEDS_ATTENTION` até a OCI validar o CNAME) | - |
| `email_domain_id` | `ocid1.emaildomain.oc1.sa-saopaulo-1.amaaaaaavyhgtvaa4vqciragts3aoaei6psq5phwano2s5pzqyjf2jrrcdqa` | - |

Verificação pós-apply (08/10/2026): Email Domain, DKIM e Approved Sender em
`ACTIVE` (OCI CLI); CNAME do DKIM resolvendo até a OCI (`dig`); envio de
teste por SMTP (465/TLS) aceito pelo servidor (`250 Ok`).

### Pontos de atenção

- **Primeiro apply**: o DKIM nasce `NEEDS_ATTENTION` e vira `ACTIVE` quando a
  OCI valida o CNAME (alguns minutos); acompanhe em Developer Services ->
  Email Delivery -> Email Domains -> ecolchain.com. Approved Sender
  recém-criado também pode demorar a ficar utilizável: se o SMTP responder
  `535 Authorization failed: address not authorized`, fazer retry com backoff.
- **SPF/DMARC não são alterados**: o SPF do apex (`v=spf1
  include:_spf.reach.hostinger.com include:_spf.mx.cloudflare.net ~all`) e o
  `_dmarc` (`v=DMARC1; p=none`) existem fora do Terraform. Por padrão o Email
  Delivery usa Return-Path próprio, então o DMARC passa pelo DKIM alinhado.
  Para pedir aumento de limite à Oracle, SPF e DKIM são exigidos: nesse caso
  adicionar `include:rp.oracleemaildelivery.com` ao SPF do apex (cuidado com
  o limite de 10 lookups DNS).
- **Limites atuais da tenancy** (verificados com `oci limits value list
  --service-name email-delivery`): 200 e-mails/24h, 10 e-mails/min, mensagem
  de até ~2 MB, 2000 approved senders.
- E-mails enviados **para** `ecolchain@ecolchain.com` continuam no catch-all
  do Cloudflare Email Routing -> Gmail (módulo `cloudflare/email-routing`,
  intocado).
- **Rotação da senha SMTP**: `terraform apply
  -replace=oci_identity_smtp_credential.app` rodando local (ver "Uso local");
  cada usuário tem no máximo 2 credenciais SMTP; a senha só é retornada na
  criação e fica no state; atualizar a app com o novo valor.
- A key do módulo começa com `prod/`, então o CD aplica no job do environment
  `prod` com aprovação manual.

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
