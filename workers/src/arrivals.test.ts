// workers/src/arrivals.test.ts
import { describe, it, expect } from 'vitest';
import { handleCenefas } from './arrivals';

describe('GET /static/cenefas', () => {
  it('returns the dataset with version and 24h cache header', async () => {
    const res = handleCenefas();
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toBe('public, max-age=86400');
    const body = await res.json() as { version: string; lines: unknown[] };
    expect(body.version).toMatch(/^\d{4}-\d{2}-\d{2}/);
    expect(body.lines.length).toBeGreaterThanOrEqual(7);
  });
});
