/**
 * /static/cenefas + /arrivals: official service identity and realtime
 * arrival states. State derivation is pure (exported for testing); the
 * handlers stay thin, matching gtfs-schedule.ts house style.
 */
import { CORS_HEADERS } from './types';
import { CENEFAS } from './data/cenefas';

export function handleCenefas(): Response {
  return new Response(JSON.stringify(CENEFAS), {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=86400',
    },
  });
}
