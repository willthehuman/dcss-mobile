/**
 * DCSS Mobile — CORS proxy worker
 *
 * Routes:
 *   GET /proxy/<url>   — fetches <url> and injects CORS headers
 *   OPTIONS *          — handles pre-flight
 *
 * Deploy with Wrangler:
 *   cd worker/cors-proxy
 *   npx wrangler deploy
 *
 * After deploying, copy your worker URL (e.g. https://dcss-cors-proxy.YOUR-NAME.workers.dev)
 * into lib/game/tile_loader.dart as the value of _corsProxyBaseUrl.
 */

const ALLOWED_ORIGINS = [
  'https://willthehuman.github.io',
];

/** Builds CORS response headers for a given request origin. */
function corsHeaders(requestOrigin) {
  const origin = ALLOWED_ORIGINS.includes(requestOrigin)
    ? requestOrigin
    : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
  };
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin') ?? '';

    // Handle CORS pre-flight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    // Expect path: /proxy/<target-url>
    const prefix = '/proxy/';
    if (!url.pathname.startsWith(prefix)) {
      return new Response('Not found', { status: 404 });
    }

    const targetUrl = url.pathname.slice(prefix.length) + url.search;

    // Basic allow-list: only proxy crawl servers
    const allowedHosts = [
      'crawl.dcss.io',
      'crawl.akrasiac.org',
      'crawl.develz.org',
      'crawl.xtasen.org',
      'cbro.berotato.org',
    ];
    let targetHost;
    try {
      targetHost = new URL('https://' + targetUrl).hostname;
    } catch {
      return new Response('Bad target URL', { status: 400 });
    }
    if (!allowedHosts.includes(targetHost)) {
      return new Response('Target host not allowed', { status: 403 });
    }

    const upstreamResponse = await fetch('https://' + targetUrl, {
      headers: { 'User-Agent': 'dcss-mobile-cors-proxy/1.0' },
    });

    // Stream the body through with CORS headers added
    const response = new Response(upstreamResponse.body, upstreamResponse);
    const headers = corsHeaders(origin);
    for (const [k, v] of Object.entries(headers)) {
      response.headers.set(k, v);
    }
    return response;
  },
};
