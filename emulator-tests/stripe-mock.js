// Minimal Stripe API stand-in for emulator tests: just the endpoints the
// Cloud Functions call (PaymentIntents create/retrieve/capture/cancel and
// refunds). Every call is logged so tests can assert what was charged,
// released or refunded. `authorize(id)` simulates the cliente completing
// the PaymentSheet (the PI moves to requires_capture / succeeded).

const http = require('http');

function parseForm(body) {
  const out = {};
  for (const [k, v] of new URLSearchParams(body)) {
    const m = /^(\w+)\[(\w+)\](?:\[(\w+)\])?$/.exec(k);
    if (m) {
      out[m[1]] = out[m[1]] || {};
      if (m[3]) {
        out[m[1]][m[2]] = out[m[1]][m[2]] || {};
        out[m[1]][m[2]][m[3]] = v;
      } else {
        out[m[1]][m[2]] = v;
      }
    } else {
      out[k] = v;
    }
  }
  return out;
}

function start(port = 12111) {
  const intents = new Map();
  const log = [];
  let seq = 0;

  const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      const send = (code, obj) => {
        res.writeHead(code, { 'content-type': 'application/json' });
        res.end(JSON.stringify(obj));
      };
      const url = req.url.split('?')[0];
      const form = parseForm(body);
      let m;

      if (req.method === 'POST' && url === '/v1/payment_intents') {
        const id = `pi_mock_${++seq}`;
        const pi = {
          id,
          object: 'payment_intent',
          amount: Number(form.amount),
          amount_received: 0,
          currency: form.currency,
          capture_method: form.capture_method || 'automatic',
          application_fee_amount: Number(form.application_fee_amount || 0),
          status: 'requires_payment_method',
          client_secret: `${id}_secret_mock`,
          metadata: form.metadata || {},
        };
        intents.set(id, pi);
        log.push({ op: 'create', id, amount: pi.amount, capture: pi.capture_method, fee: pi.application_fee_amount, metadata: pi.metadata });
        return send(200, pi);
      }
      if ((m = /^\/v1\/payment_intents\/([\w]+)$/.exec(url)) && req.method === 'GET') {
        const pi = intents.get(m[1]);
        return pi ? send(200, pi) : send(404, { error: { message: 'No such payment_intent' } });
      }
      if ((m = /^\/v1\/payment_intents\/([\w]+)\/capture$/.exec(url))) {
        const pi = intents.get(m[1]);
        if (!pi || pi.status !== 'requires_capture') {
          return send(400, { error: { message: `cannot capture from ${pi && pi.status}` } });
        }
        pi.status = 'succeeded';
        pi.amount_received = pi.amount;
        log.push({ op: 'capture', id: pi.id, amount: pi.amount });
        return send(200, pi);
      }
      if ((m = /^\/v1\/payment_intents\/([\w]+)\/cancel$/.exec(url))) {
        const pi = intents.get(m[1]);
        if (!pi) return send(404, { error: { message: 'No such payment_intent' } });
        pi.status = 'canceled';
        log.push({ op: 'cancel', id: pi.id });
        return send(200, pi);
      }
      if (req.method === 'POST' && url === '/v1/refunds') {
        const pi = intents.get(form.payment_intent);
        const amount = form.amount ? Number(form.amount) : pi ? pi.amount : 0;
        log.push({
          op: 'refund',
          id: form.payment_intent,
          amount,
          refund_application_fee: form.refund_application_fee,
          reverse_transfer: form.reverse_transfer,
        });
        return send(200, { id: `re_mock_${++seq}`, object: 'refund', amount, payment_intent: form.payment_intent, status: 'succeeded' });
      }
      send(404, { error: { message: `mock: unhandled ${req.method} ${url}` } });
    });
  });

  return new Promise((resolve) =>
    server.listen(port, '127.0.0.1', () =>
      resolve({
        log,
        intents,
        /** The PaymentSheet succeeded: a hold becomes capturable, a normal PI succeeds. */
        authorize(id) {
          const pi = intents.get(id);
          pi.status = pi.capture_method === 'manual' ? 'requires_capture' : 'succeeded';
          if (pi.status === 'succeeded') pi.amount_received = pi.amount;
          return pi;
        },
        close: () => new Promise((r) => server.close(r)),
      }),
    ),
  );
}

module.exports = { start };
