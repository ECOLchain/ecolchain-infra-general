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
    if (!path.includes(".")) path = "/index.html";

    const objectUrl = env.BUCKET_BASE_URL + encodeURI(path) + url.search;

    let resp = await fetch(objectUrl, {
      cf: { cacheEverything: true, cacheTtl: 300 },
    });

    // Fallback: objeto inexistente + navegacao HTML -> index.html (SPA)
    if (resp.status === 404 && request.method === "GET") {
      const accept = request.headers.get("Accept") || "";
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
