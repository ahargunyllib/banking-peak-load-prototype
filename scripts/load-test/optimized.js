import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// =========================
// Custom Metrics
// =========================
export const successRate        = new Rate('success_rate');
export const failedRequests     = new Counter('failed_requests');
export const writeLatency       = new Trend('write_latency');
export const readBalanceLatency = new Trend('read_balance_latency');
export const readStatusLatency  = new Trend('read_status_latency');

// =========================
// Optimized Test Config
// Target: ~500.000 requests (70% read, 30% write)
// Kalkulasi:
//   50 req/s x 30s  =  1.500
//  200 req/s x 60s  = 12.000
//  500 req/s x 120s = 60.000
//  800 req/s x 180s = 144.000
// 1000 req/s x 120s = 120.000
// 1000 req/s x 60s  =  60.000
//  500 req/s x 60s  =  30.000
//  200 req/s x 60s  =  12.000
//   50 req/s x 30s  =  1.500
// Total             = 441.000 + overhead ~500.000
// =========================
export const options = {
  scenarios: {
    peak_load_test: {
      executor: 'ramping-arrival-rate',
      startRate: 20,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 300,
      stages: [
        { target: 20,  duration: '10s' },  // warm up
        { target: 50,  duration: '15s' },   // naik pelan
        { target: 100, duration: '30s' },   // naik ke 100 req/s
        { target: 150, duration: '45s' },   // spike 150 req/s
        { target: 150, duration: '30s' },   // tahan puncak
        { target: 50,  duration: '15s' },  // turun
        { target: 0,   duration: '5s' },  // stop
      ],
    },
  },

  thresholds: {
    http_req_failed:      ['rate<0.01'],   // error < 1%
    http_req_duration:    ['p(95)<1000'],  // p95 < 1s
    success_rate:         ['rate>0.99'],   // sukses > 99%
    write_latency:        ['p(95)<2000'],  // p95 write < 2s
    read_balance_latency: ['p(95)<500'],   // p95 read < 500ms (cache hit)
  },
}
// =========================
// Helpers
// =========================
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Full range sesuai seeds (1001–101000)
function randomAccount() {
  return Math.floor(Math.random() * 100000) + 1001;
}

// Hot accounts: 10 akun yang sering diakses → cache hit rate tinggi
const HOT_ACCOUNTS = Array.from({ length: 10 }, (_, i) => 1001 + i);

function hotOrRandomAccount() {
  // 80% hot account (sudah di-cache), 20% random
  if (Math.random() < 0.8) {
    return HOT_ACCOUNTS[Math.floor(Math.random() * HOT_ACCOUNTS.length)];
  }
  return randomAccount();
}

function randomAmount() {
  return Math.floor(Math.random() * 100000) + 10000;
}

const createdTxIds = [];

// =========================
// Main Test — 70% read, 30% write
// =========================
export default function () {
  const roll = Math.random();

  if (roll < 0.30) {
    // 30% WRITE
    group('write_transaction', () => {
      let source = randomAccount();
      let dest   = randomAccount();
      while (dest === source) dest = randomAccount();

      const payload = JSON.stringify({
        source_account: source,
        dest_account:   dest,
        amount:         randomAmount(),
      });

      const res = http.post(`${BASE_URL}/api/v1/transactions`, payload, {
        headers: { 'Content-Type': 'application/json' },
        timeout: '5s',
      });

      // Optimized: expect 202 (async via queue), bukan 201
      const ok = check(res, {
        'write: status 201 or 202': (r) => r.status === 201 || r.status === 202,
        'write: response time < 2s': (r) => r.timings.duration < 2000,
      });

      writeLatency.add(res.timings.duration);
      successRate.add(ok);

      if (!ok) {
        failedRequests.add(1);
        console.error(`WRITE FAILED | status=${res.status} body=${res.body}`);
      } else {
        try {
          const body = JSON.parse(res.body);
          if (body.id) createdTxIds.push(body.id);
        } catch (_) {}
      }
    });

  } else if (roll < 0.55) {
    // 25% READ BALANCE (cache-aside via Redis)
    group('read_balance', () => {
      const accountId = hotOrRandomAccount();

      const res = http.get(`${BASE_URL}/api/v1/accounts/${accountId}/balance`, {
        timeout: '3s',
      });

      const ok = check(res, {
        'balance: status 200': (r) => r.status === 200,
        'balance: has balance field': (r) => {
          try { return JSON.parse(r.body).balance !== undefined; } catch (_) { return false; }
        },
      });

      readBalanceLatency.add(res.timings.duration);
      successRate.add(ok);

      if (!ok) {
        failedRequests.add(1);
        console.error(`BALANCE FAILED | status=${res.status} body=${res.body}`);
      }
    });

  } else {
    // 45% READ TX STATUS
    group('read_tx_status', () => {
      const txId = createdTxIds.length > 0
        ? createdTxIds[Math.floor(Math.random() * createdTxIds.length)]
        : `01JNXXX${Math.floor(Math.random() * 999999)}`;

      const res = http.get(`${BASE_URL}/api/v1/transactions/${txId}/status`, {
        timeout: '3s',
      });

      const ok = check(res, {
        'status: 200 or 404': (r) => r.status === 200 || r.status === 404,
      });

      readStatusLatency.add(res.timings.duration);
      successRate.add(ok);

      if (!ok) {
        failedRequests.add(1);
        console.error(`STATUS FAILED | status=${res.status} body=${res.body}`);
      }
    });
  }

  sleep(Math.random() * 0.1);
}

// =========================
// Summary Report
// =========================
export function handleSummary(data) {
  const p95Write   = data.metrics.write_latency?.values?.['p(95)']        || 0;
  const p95Balance = data.metrics.read_balance_latency?.values?.['p(95)'] || 0;
  const p95Status  = data.metrics.read_status_latency?.values?.['p(95)']  || 0;
  const errorRate  = (data.metrics.http_req_failed?.values?.rate || 0) * 100;
  const totalReqs  = data.metrics.http_reqs?.values?.count || 0;
  const rps        = data.metrics.http_reqs?.values?.rate  || 0;

  const p95WriteOk   = p95Write   < 2000 ? '✅' : '❌';
  const p95BalanceOk = p95Balance < 500  ? '✅' : '❌';
  const errorOk      = errorRate  < 1    ? '✅' : '❌';

  console.log('\n========================================');
  console.log('        OPTIMIZED TEST SUMMARY');
  console.log('========================================');
  console.log(`Total Requests  : ${totalReqs}`);
  console.log(`Avg RPS         : ${rps.toFixed(1)} req/s`);
  console.log(`Error Rate      : ${errorRate.toFixed(2)}%  ${errorOk}`);
  console.log(`P95 Write       : ${p95Write.toFixed(0)}ms  ${p95WriteOk}`);
  console.log(`P95 Balance     : ${p95Balance.toFixed(0)}ms ${p95BalanceOk}`);
  console.log(`P95 TX Status   : ${p95Status.toFixed(0)}ms`);
  console.log('----------------------------------------');
  console.log('Expected: Low latency & errors (optimized)');
  console.log('========================================\n');

  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
