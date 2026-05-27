import assert from 'node:assert/strict';
import test from 'node:test';

import worker from '../src/index.js';

let fetchedUrl;

async function request(path, { origin = 'https://willthehuman.github.io', method = 'GET' } = {}) {
  fetchedUrl = undefined;
  globalThis.fetch = async (url) => {
    fetchedUrl = String(url);
    return new Response('ok', {
      status: 200,
      headers: { 'Content-Type': 'text/plain' },
    });
  };

  return worker.fetch(
    new Request(`https://proxy.example${path}`, {
      method,
      headers: origin ? { Origin: origin } : {},
    }),
    {},
    {},
  );
}

test('handles CORS preflight for localhost dev origins', async () => {
  const response = await request('/proxy/crawl.dcss.io/static/tileinfo-main.js', {
    method: 'OPTIONS',
    origin: 'http://localhost:5173',
  });

  assert.equal(response.status, 204);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'http://localhost:5173');
  assert.equal(fetchedUrl, undefined);
});

test('proxies an advertised production server from the GitHub Pages origin', async () => {
  const response = await request('/proxy/crawl.project357.org/gamedata/hash/main.png');

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'https://willthehuman.github.io');
  assert.equal(fetchedUrl, 'https://crawl.project357.org/gamedata/hash/main.png');
});

test('proxies advertised servers with explicit ports', async () => {
  const response = await request('/proxy/underhound.eu:8080/gamedata/hash/main.png');

  assert.equal(response.status, 200);
  assert.equal(fetchedUrl, 'https://underhound.eu:8080/gamedata/hash/main.png');
});

test('allows loopback PWA development origins', async () => {
  const response = await request('/proxy/crawl.nemelex.cards/static/tileinfo-main.js', {
    origin: 'http://127.0.0.1:7357',
  });

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'http://127.0.0.1:7357');
});

test('blocks non-DCSS hosts', async () => {
  const response = await request('/proxy/example.com/static/tileinfo-main.js');

  assert.equal(response.status, 403);
  assert.equal(await response.text(), 'Target host not allowed');
  assert.equal(fetchedUrl, undefined);
});
