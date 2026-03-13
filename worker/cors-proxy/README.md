# DCSS Mobile — CORS Proxy Worker

A minimal Cloudflare Worker that proxies tile asset requests from DCSS servers
and injects `Access-Control-Allow-Origin` headers so the GitHub Pages web build
can fetch them.

## Setup

1. [Create a free Cloudflare account](https://dash.cloudflare.com/sign-up) if you don't have one.
2. Install Wrangler (Cloudflare's CLI):
   ```bash
   npm install -g wrangler
   ```
3. Log in:
   ```bash
   wrangler login
   ```
4. Deploy:
   ```bash
   cd worker/cors-proxy
   npm install
   npm run deploy
   ```
5. Wrangler will print your worker URL, e.g.:
   ```
   https://dcss-cors-proxy.<your-subdomain>.workers.dev
   ```
6. Copy that URL and paste it into `lib/game/tile_loader.dart` as the value of
   `_corsProxyBaseUrl`:
   ```dart
   const String _corsProxyBaseUrl = 'https://dcss-cors-proxy.<your-subdomain>.workers.dev/proxy';
   ```
7. Rebuild and redeploy the Flutter web app.

## How it works

The worker receives requests at `/proxy/<host>/<path>` and forwards them to
`https://<host>/<path>`, adding CORS headers to the response. Only the crawl
servers in the allow-list inside `src/index.js` are permitted.
