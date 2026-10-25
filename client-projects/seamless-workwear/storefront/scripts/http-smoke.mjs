import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {createServer} from '../server.mjs';
import {QuoteStore} from '../src/quote-store.mjs';

// Uses temporary fixture data and an ephemeral port; never opens the runtime DB.
const directory = mkdtempSync(path.join(tmpdir(), 'seamless-http-'));
const store = new QuoteStore(path.join(directory, 'smoke.sqlite'));
const staff = randomBytes(32).toString('hex');
const owner = randomBytes(32).toString('hex');
const server = createServer({store, staffToken: staff});
try {
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const base = 'http://127.0.0.1:' + server.address().port;
  const send = (route, body, headers = {}) => fetch(base + route, {
    method: 'POST',
    headers: {Origin: base, 'Content-Type': 'application/json', ...headers},
    body: JSON.stringify(body),
  });
  for (const route of ['/', '/staff', '/matrix.js', '/fonts/Inter.ttf']) {
    assert.equal((await fetch(base + route)).status, 200);
  }
  const input = {
    items: [{id: 'golf-shirt', quantity: 3, branding: 'embroidery',
      requestedVariants: [{colour: 'Navy', size: 'M', quantity: 3}]}],
    contact: {name: 'Smoke fixture', email: 'smoke@example.test'},
  };
  const created = await send('/api/quotes', input, {'X-Request-Token': owner});
  assert.equal(created.status, 201);
  const quote = await created.json();
  assert.equal(quote.price, null);
  assert.equal(quote.paymentAvailable, false);
  const retried = await send('/api/quotes', input, {'X-Request-Token': owner});
  assert.equal(retried.status, 201);
  assert.equal((await retried.json()).id, quote.id);
  assert.equal((await fetch(base + '/api/quotes/' + quote.id)).status, 404);
  assert.equal((await fetch(base + '/api/quotes/' + quote.id, {
    headers: {Authorization: 'Bearer ' + owner},
  })).status, 200);
  assert.equal((await fetch(base + '/api/staff/quotes')).status, 401);
  const reviewed = await send('/api/staff/quotes/' + quote.id, {
    status: 'in_review', note: 'HTTP smoke check', expectedRevision: 1,
  }, {Authorization: 'Bearer ' + staff});
  assert.equal(reviewed.status, 200);
  assert.equal((await reviewed.json()).revision, 2);
  const stale = await send('/api/staff/quotes/' + quote.id, {
    status: 'closed', note: 'Stale review', expectedRevision: 1,
  }, {Authorization: 'Bearer ' + staff});
  assert.equal(stale.status, 409);
  assert.equal((await fetch(base + '/runtime/seamless.sqlite')).status, 404);
  console.log('HTTP smoke passed: assets, create/retry, ownership, staff review and database isolation.');
} finally {
  await new Promise(resolve => server.close(resolve));
  store.close();
  rmSync(directory, {recursive: true, force: true});
}
