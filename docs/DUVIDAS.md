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
