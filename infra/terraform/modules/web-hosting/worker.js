export default {
  async fetch(request, env) {
    // Gate de dev: Basic Auth (binding secreto DEV_AUTH so existe quando configurado)
    if (env.DEV_AUTH) {
      const expected = "Basic " + btoa(env.DEV_AUTH);
      if (request.headers.get("Authorization") !== expected) {
        return new Response("401 Unauthorized", {
          status: 401,
          headers: { "WWW-Authenticate": 'Basic realm="ecolchain-dev"' },
        });
      }
    }

    const url = new URL(request.url);
    let path = url.pathname;

    // SPA: raiz e rotas de cliente (sem extensao) caem no index.html
    if (path.endsWith("/")) path += "index.html";

    // Candidatos de objeto no bucket, em ordem.
    // - HTML_ROUTES (export estatico estilo Next `out/`): cada rota vira
    //   `<rota>.html` (ou `<rota>/index.html`); tenta os dois antes do index raiz.
    // - Padrao (SPA bundle unico): rota sem extensao vai direto ao index raiz.
    const candidates =
      env.HTML_ROUTES && !path.includes(".")
        ? [`${path}.html`, `${path}/index.html`, "/index.html"]
        : [path.includes(".") ? path : "/index.html"];

    const accept = request.headers.get("Accept") || "";
    let resp;
    for (const candidate of candidates) {
      resp = await fetch(env.BUCKET_BASE_URL + encodeURI(candidate) + url.search, {
        cf: { cacheEverything: true, cacheTtl: 300 },
      });
      if (resp.status !== 404) break;
    }

    // Fallback: objeto inexistente + navegacao HTML -> index.html (SPA)
    if (resp.status === 404 && request.method === "GET") {
      if (accept.includes("text/html")) {
        resp = await fetch(env.BUCKET_BASE_URL + "/index.html", {
          cf: { cacheEverything: true, cacheTtl: 60 },
        });
      }
    }

    const out = new Response(resp.body, resp);
    // Dev: nunca indexar em buscadores
    if (env.DEV_AUTH) out.headers.set("X-Robots-Tag", "noindex, nofollow");
    return out;
  },
};
