# Dúvidas e decisões — ecolchain-infra-general

Registro de divergências encontradas durante mudanças de infra, com a decisão
adotada em cada uma (checkbox = ponto que valeria revisão futura).

## management-web (hosting da SPA de gestão)

- [ ] **Bucket "privado" vs `ObjectRead`**: o pedido falava em bucket privado,
  mas o módulo `web-hosting` (mesmo do `core-web`) cria `access_type =
  "ObjectRead"` — o objeto é legível por quem tiver a URL direta do bucket.
  Decisão: **manter o módulo idêntico ao padrão do chain** (o gate real de dev
  fica no worker: Basic Auth + `noindex`; a URL do bucket é ofuscada e não
  indexável). Se quisermos privacidade real, a evolução é o worker assinar
  requests (PAR/OCI auth) em vez de bucket público de leitura.
- [ ] **Worker compartilhado alterado**: `worker.js` ganhou a cadeia
  `<rota>.html` → `<rota>/index.html` → `/index.html` para servir o export
  estático do Next (`out/` vira uma página `.html` por rota; o fallback antigo
  sempre no `/index.html` entraria em loop com a página-redirect `/` →
  `/pt-br`). O comportamento novo só ativa com `html_routes = true`
  (binding `HTML_ROUTES`) — `core-web` segue no caminho antigo, mas seu plano
  mostra update de conteúdo do worker (redeploy idêntico) por compartilhar o
  arquivo.
- [ ] **`worker_name_prefix` dedicado** (`ecolchain-web-mgmt`): necessário para
  não colidir com os scripts `ecolchain-web-dev/prod` do core-web.
- [ ] **Hostnames escolhidos**: `manage-dev.ecolchain.com` (dev, Basic Auth +
  noindex) e `manage.ecolchain.com` (prod, aberto) — espelhando
  `app-dev-tester`/`app` do core-web. Hostnames da API combinados com o front:
  `api-dev.ecolchain.com` (dev) e `api.ecolchain.com` (prod) — documentados no
  `docs/AMBIENTES.md` do `ecolchain-management-web` para alinhar quando a API
  for deployada.

## management-api-runtime (VM + LB + OCIR para dev/prod na mesma VM)

- [ ] **Uma VM só para dev+prod** — o modelo `<env>/<app>` 1:1 não cabe
  (cota Always Free: 4 OCPU/24 GB no total). Decisão: root único
  `infra/terraform/management-api-runtime` com key
  `prod/management-api-runtime/` — cai no gate de prod do CD, correto
  porque a VM hospeda prod. Containers separados por porta (dev :8080,
  prod :8081) e por env file.
- [ ] **VM em subnet pública com IP próprio** (vs. privada atrás do LB):
  a privada exigiria NAT Gateway, que **não** entra no Always Free
  (egress para OCIR/GitHub/yum sairia só via service gateway para
  serviços OCI, mas yum/GitHub/Docker Hub morreriam). Pública resolve
  egress grátis via IGW e deixa o Ansible do CD chegar por SSH.
  Superfície: :22 (key-only) + nada de app exposto (NSG fecha
  :8080/:8081 para fora da VCN).
- [ ] **Deploy converge por polling do OCIR** (timer systemd a cada
  2 min: `docker compose pull` + `up -d` por serviço) — variante mais
  simples do item (c) do prompt. Sem SSH de entrada nem runner para o
  deploy. Pull autenticado por **instance principal** (dynamic group +
  `read repos in tenancy`); fallback = auth token estático entregue
  pelo Ansible. Alternativas avaliadas: (a) SSH do CI — precisaria da
  chave privada como secret do repo api (bot não escreve secrets) e
  :22 aberto mesmo assim; (b) self-hosted runner — token de registro
  tem TTL ~1h e exigiria PAT em secrets para bootstrap; a role existe
  (`playbooks/runner.yml`) mas fora do default.
- [ ] **Ansible roda no job de apply** (`ci-terraform-apply.yml`), via
  SSH com a chave `tls_private_key` do state + `--extra-vars` do
  `terraform output -json ansible_vars` — nenhuma credencial em
  cloud-init/user_data e nenhum secret novo no GitHub.
- [ ] **TLS: Cloudflare Full (strict) + Origin CA cert no LB :443**
  (vs. Flexible com origin :80). Custo quase zero (provider já cria
  `cloudflare_origin_ca_certificate`) e o tráfego CF->LB fica cifrado
  — necessário porque a API transporta tokens/OTP. Listener único :443
  com `routing_policy` por hostname (`HMN:`) -> backend set dev/prod.
- [ ] **SSH :22 para 0.0.0.0/0** — runners do GitHub não têm IP fixo;
  auth é key-only e a chave privada só existe no state. Pendente de
  revisão: restringir quando houver bastion/IP fixo.
- [ ] **`oci_identity_auth_token` para push do CI** — usuário tem limite
  de 2 auth tokens; se o apply falhar por limite, gerar usuário
  dedicado ou informar token existente. O valor sai por
  `terraform output ocir_push_token` (sensível) -> secrets
  `OCIR_USERNAME`/`OCIR_AUTH_TOKEN` no repo da API.
- [ ] **Sem health check em :80/redirect** — só :443 no LB (a Cloudflare
  fala com a origem em TLS). Acesso direto por IP do LB sem Host
  correto cai no backend dev (default_backend_set) — comportamento
  inócuo, documentado.
- [ ] **Shape conservador 1 OCPU / 8 GB** — sobra quota Always Free
  (4 OCPU/24 GB) e 2 JVMs Quarkus cabem folgadas; subir via tfvars se
  faltar memória.

## Apply do runtime — erros encontrados e resolução (2026-10-09)

- [ ] **Nomes de listener/routing policy sem hífen** — OCI exige
  `^[a-zA-Z_][a-zA-Z_0-9]*$` nesses campos (display_name aceita hífen,
  name não). `api-hostname-routing`/`https-443` viraram
  `api_hostname_routing`/`https_443`.
- [ ] **Condição de routing por hostname é JMESPath V1**, não `HMN:` —
  forma correta validada no apply:
  `any(http.request.headers[(i 'host')] eq (i '<hostname>'))`.
- [ ] **sa-saopaulo-1 tem 1 único AD** — `vm_ad_index` só aceita 0; a
  variável permanece para o caso de migração de região. Sem AD
  alternativo, "Out of host capacity" do A1.Flex só resolve com retry
  temporal (capacidade flutua).
- [ ] **Bot não pode re-rodar job de apply** (`gh run rerun` = 403) —
  retry do apply acontece via novo merge em main que toque o diretório
  do módulo (detect-changed-modules inclui por diff).

## Pivot de compute: A1.Flex (ARM) -> 2x E2.1.Micro (x86) — 2026-10-09

- [ ] **`Out of host capacity` crônico no A1.Flex** — 4 retries pelo CD
  falharam; GRU tem 1 único AD (`availability_domains` = 1 elemento).
  Decisão do dono: pivotar p/ 2x `VM.Standard.E2.1.Micro` (AMD x86,
  também Always Free) — `mgmt-api-vm-dev` e `mgmt-api-vm-prod`, 1 GB
  RAM cada, 1 container por VM. `vm_shape` virou variável; voltar p/
  ARM = `-var vm_shape=VM.Standard.A1.Flex` + imagem arm64 + count.
- [ ] **2 VMs em vez de 1** — E2.1.Micro é fixo (sem shape_config;
  bloco virou `dynamic` condicionado ao shape Flex). Ambas as VMs no
  mesmo dynamic group (`ANY{instance.id=...}`) e mesmo NSG.
- [ ] **Imagem da app passa a ser linux/amd64** — workflows da API
  ajustados; Dockerfile continua multi-stage com `$BUILDPLATFORM`.
- [ ] **Tuning JVM p/ 1 GB**: `JAVA_MAX_MEM_RATIO=70` +
  `GC_CONTAINER_OPTIONS=-XX:+UseSerialGC` nos env files (SerialGC tem
  menos overhead de memória em containers pequenos).
- [ ] **Ansible roda 2x no job de apply** — mesma `site.yml` com
  `mgmt_envs` filtrado por VM (`["dev"]`/`["prod"]`).

## Provisionamento Ansible nas VMs Micro — gotchas encontrados (2026-10-09)

- [ ] **dnf OOM-kill (rc -9) na 1GB** — resolvido com swapfile 1.5G em
  `pre_tasks` (site.yml) antes de qualquer dnf. Linha em /etc/fstab p/
  persistir.
- [ ] **"Transaction test error: package X already installed"** — corrida
  anterior do dnf morreu no meio; `rpm -q` guard nos installs (firewalld,
  dnf-automatic, yum-utils, docker-ce*, python3-pip).
- [ ] **`command` não interpreta `&&`** — apply da rich rule do firewalld
  usa `shell`; a rule inteira vai num único argumento quotado
  (`--add-rich-rule='rule ...'`). `nc -z` no :22 passa mesmo com sshd
  faminto — o apply job agora faz probe SSH real (banner+auth, até 15min).
- [ ] **Smoke local /q/health é não-fatal** — no 1º provisionamento a tag
  `:dev`/`:prod` ainda não existe no OCIR; o mgmt-pull.timer sobe o
  container quando a esteira da API publicar a 1ª imagem.
- [ ] **Ansible step depende de módulo terraform detectado** — mudanças em
  `infra/ansible/**` agora marcam `management-api-runtime` no
  detect-changed-modules.sh (apply vira no-op, Ansible re-roda). Mudanças
  só em `.github/` não disparam nada.
- [ ] **Squash-merge + mesma linha final** — comentário "# Trigger" no fim
  de main.tf conflita a cada merge (mesma linha tocada por branches
  concorrentes); resolve com rebase + reescrever a linha.

## Pivot de compute: 2x E2.1.Micro -> 2x E4.Flex (PAYG) — 2026-10-10

- [ ] **E2.1.Micro inviável p/ provisionamento** — ~500 MB RAM reais:
  `dnf` (depsolve) infla a ~350 MB e o OOM-killer global mata o processo
  (`rc -9`) até com swap 1.5G e VM idle; `dnf makecache` do sistema morreu
  do mesmo jeito. Decisão do dono: sair do Always Free p/ `E4.Flex`
  (x86 PAYG, conta com saldo) — default `vm_ocpus=2`/`vm_memory_gbs=8`.
  Shape Flex é atualizado in-place pela OCI (reboot, sem recriar).
- [ ] **`shape_config` genérico p/ Flex** — condição virou
  `strcontains(var.vm_shape, "Flex")` (E4.Flex, A1.Flex...); shapes fixed
  seguem sem o bloco. Imagens da API continuam linux/amd64.
- [ ] **JVM tuning 1 GB** (`JAVA_MAX_MEM_RATIO=70` + SerialGC) fica
  conservador demais p/ 8 GB mas segue válido — revertível no env do
  `ansible_vars` se quiser G1/heap maior.
