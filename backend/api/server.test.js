const { test, describe } = require('node:test');
const assert = require('node:assert');
const request = require('supertest');
const { app } = require('./server');

describe('U-Art Node.js API Integration Tests', () => {
  test('GET /api/health should return status OK and timestamp', async () => {
    const res = await request(app).get('/api/health');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'OK');
    assert.ok(res.body.timestamp);
  });

  test('GET /api/performances/:id returns 404 or 500 when DB offline', async () => {
    const res = await request(app).get('/api/performances/NON_EXISTENT_ID_99999');
    assert.ok(res.status === 404 || res.status === 500);
  });

  test('GET /api/performances handles query filters gracefully', async () => {
    const res = await request(app)
      .get('/api/performances')
      .query({ genre: '뮤지컬', district: '중구', q: '테스트' });
    assert.ok(res.status === 200 || res.status === 500);
  });
});
