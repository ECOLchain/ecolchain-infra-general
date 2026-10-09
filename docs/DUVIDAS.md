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
