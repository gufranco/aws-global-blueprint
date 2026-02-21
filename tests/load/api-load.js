// =============================================================================
// K6 Load Test - API
// =============================================================================
// Run with: k6 run tests/load/api-load.js
// =============================================================================

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const orderCreationTime = new Trend('order_creation_time');
const orderGetTime = new Trend('order_get_time');
const ordersCreated = new Counter('orders_created');
const ordersRetrieved = new Counter('orders_retrieved');

// Test configuration
export const options = {
  // Stages simulate gradual load increase
  stages: [
    { duration: '1m', target: 10 },   // Ramp up to 10 users
    { duration: '3m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  // Thresholds for pass/fail
  thresholds: {
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],  // 95% under 1s, 99% under 2s
    errors: ['rate<0.05'],  // Error rate under 5%
    order_creation_time: ['p(95)<1500'],
    order_get_time: ['p(95)<500'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

// Generate random UUID
function uuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Generate random order data
function generateOrder() {
  const itemCount = Math.floor(Math.random() * 5) + 1;
  const items = [];
  
  for (let i = 0; i < itemCount; i++) {
    const quantity = Math.floor(Math.random() * 5) + 1;
    const unitPrice = Math.random() * 100 + 10;
    items.push({
      productId: uuid(),
      productName: `Product ${i + 1}`,
      quantity,
      unitPrice: Math.round(unitPrice * 100) / 100,
      totalPrice: Math.round(quantity * unitPrice * 100) / 100,
    });
  }

  return {
    customerId: uuid(),
    items,
    shippingAddress: {
      street: '123 Test Street',
      city: 'Test City',
      state: 'TS',
      country: 'US',
      postalCode: '12345',
    },
  };
}

export default function() {
  const headers = {
    'Content-Type': 'application/json',
  };

  // Health check
  group('Health Check', function() {
    const healthRes = http.get(`${BASE_URL}/health`);
    
    check(healthRes, {
      'health check status is 200': (r) => r.status === 200,
      'health check response is healthy': (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.status === 'healthy';
        } catch {
          return false;
        }
      },
    });

    errorRate.add(healthRes.status !== 200);
  });

  // Create order
  let orderId = null;
  
  group('Create Order', function() {
    const orderData = generateOrder();
    const startTime = new Date();
    
    const createRes = http.post(
      `${BASE_URL}/api/orders`,
      JSON.stringify(orderData),
      { headers }
    );

    const duration = new Date() - startTime;
    orderCreationTime.add(duration);

    const success = check(createRes, {
      'create order status is 201': (r) => r.status === 201,
      'create order has id': (r) => {
        try {
          if (r.status === 201) {
            const body = JSON.parse(r.body);
            orderId = body.id;
            return !!body.id;
          }
          return false;
        } catch {
          return false;
        }
      },
    });

    if (success) {
      ordersCreated.add(1);
    }
    
    errorRate.add(createRes.status !== 201);
  });

  sleep(0.5);

  // Get order
  if (orderId) {
    group('Get Order', function() {
      const startTime = new Date();
      
      const getRes = http.get(`${BASE_URL}/api/orders/${orderId}`, { headers });
      
      const duration = new Date() - startTime;
      orderGetTime.add(duration);

      const success = check(getRes, {
        'get order status is 200': (r) => r.status === 200,
        'get order has correct id': (r) => {
          try {
            if (r.status === 200) {
              const body = JSON.parse(r.body);
              return body.id === orderId;
            }
            return false;
          } catch {
            return false;
          }
        },
      });

      if (success) {
        ordersRetrieved.add(1);
      }

      errorRate.add(getRes.status !== 200);
    });
  }

  // List orders
  group('List Orders', function() {
    const listRes = http.get(`${BASE_URL}/api/orders?page=1&limit=10`, { headers });
    
    check(listRes, {
      'list orders status is 200': (r) => r.status === 200,
      'list orders has pagination': (r) => {
        try {
          if (r.status === 200) {
            const body = JSON.parse(r.body);
            return body.pagination !== undefined;
          }
          return false;
        } catch {
          return false;
        }
      },
    });

    errorRate.add(listRes.status !== 200);
  });

  sleep(Math.random() * 2 + 1);
}

// Setup function (runs once before test)
export function setup() {
  // Verify API is accessible
  const res = http.get(`${BASE_URL}/health`);
  
  if (res.status !== 200) {
    throw new Error(`API not available: ${res.status}`);
  }

  console.log('API is healthy, starting load test...');
  
  return {
    startTime: new Date().toISOString(),
  };
}

// Teardown function (runs once after test)
export function teardown(data) {
  console.log(`Load test completed. Started at: ${data.startTime}`);
}

// Handle summary
export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'tests/load/results/summary.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(data, opts) {
  const { metrics } = data;
  
  let output = '\n=== Load Test Summary ===\n\n';
  
  output += `Total Requests: ${metrics.http_reqs.values.count}\n`;
  output += `Request Rate: ${metrics.http_reqs.values.rate.toFixed(2)}/s\n`;
  output += `Avg Duration: ${metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  output += `P95 Duration: ${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  output += `P99 Duration: ${metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n`;
  output += `Error Rate: ${(metrics.errors?.values?.rate * 100 || 0).toFixed(2)}%\n`;
  
  if (metrics.orders_created) {
    output += `Orders Created: ${metrics.orders_created.values.count}\n`;
  }
  if (metrics.orders_retrieved) {
    output += `Orders Retrieved: ${metrics.orders_retrieved.values.count}\n`;
  }
  
  output += '\n';
  
  return output;
}
