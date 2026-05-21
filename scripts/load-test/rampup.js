import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// =========================
// Custom Metrics
// =========================
export const successRate = new Rate('success_rate');
export const failedRequests = new Counter('failed_requests');
export const transactionLatency = new Trend('transaction_latency');

const INITIAL_RATE = Number(__ENV.INITIAL_RATE || 500);
const RATE_STEP = Number(__ENV.RATE_STEP || 10);
const STAGE_DURATION = __ENV.STAGE_DURATION || '1s';
const MAX_STAGES = Number(__ENV.MAX_STAGES || 60); // 1 minute
const PRE_ALLOCATED_VUS = Number(__ENV.PRE_ALLOCATED_VUS || 200);
const MAX_VUS = Number(__ENV.MAX_VUS || 5000);

function buildRampStages() {
	const stages = [];

	for (let index = 0; index < MAX_STAGES; index += 1) {
		stages.push({
			target: INITIAL_RATE + (index * RATE_STEP),
			duration: STAGE_DURATION,
		});
	}

	return stages;
}

// =========================
// Test Config
// Ramps up every 2s until the run is stopped or MAX_STAGES is reached.
// =========================
export const options = {
	scenarios: {
		continuous_ramp_up: {
			executor: 'ramping-arrival-rate',
			startRate: INITIAL_RATE,
			timeUnit: '1s',
			preAllocatedVUs: PRE_ALLOCATED_VUS,
			maxVUs: MAX_VUS,
			stages: buildRampStages(),
		},
	},

	thresholds: {
		http_req_failed: ['rate<0.01'],
		http_req_duration: ['p(95)<1000'],
		success_rate: ['rate>0.99'],
	},
};

function randomAccount() {
	return Math.floor(Math.random() * 100000) + 1001;
}

function buildTransactionPayload() {
	let source = randomAccount();
	let dest = randomAccount();

	while (dest === source) {
		dest = randomAccount();
	}

	return JSON.stringify({
		source_account: source,
		dest_account: dest,
		amount: Math.floor(Math.random() * 100000) + 10000,
	});
}

// =========================
// Main Test
// =========================
export default function () {
	const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

	const payload = buildTransactionPayload();

	const params = {
		headers: { 'Content-Type': 'application/json' },
		timeout: '5s',
	};

	const res = http.post(`${BASE_URL}/api/v1/transactions`, payload, params);

	const ok = check(res, {
		'status is 201 or 202': (r) => r.status === 201 || r.status === 202,
		'response time < 2s': (r) => r.timings.duration < 2000,
	});

	successRate.add(ok);
	transactionLatency.add(res.timings.duration);

	if (!ok) {
		failedRequests.add(1);
		console.error(`FAILED | status=${res.status} body=${res.body}`);
	}

	sleep(Math.random() * 0.1);
}
