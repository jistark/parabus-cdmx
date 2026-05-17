import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { partnerValidation } from './partner-client';
import type { Env } from './types';

// Stub env with just the secrets partnerValidation reads.
function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    METROBUS_CACHE: {} as KVNamespace,
    JDV_BOT_URL: 'https://example',
    JDV_BOT_SECRET: 'secret',
    METROBUS_USUARIO: 'test-user',
    METROBUS_SENHA: 'test-pass',
    ...overrides,
  };
}

function mockFetch(impl: (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>) {
  return vi.spyOn(globalThis, 'fetch').mockImplementation(
    impl as unknown as typeof fetch,
  );
}

describe('partnerValidation', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns parsed response on success', async () => {
    const payload = {
      generationDateTime: '2026-05-17 14:00:00',
      expirationDateTime: '2026-05-17 14:10:00',
      urlRealTime: 'https://s3/realtime',
      urlStatic: 'https://s3/static',
    };
    mockFetch(async () =>
      new Response(JSON.stringify(payload), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    const result = await partnerValidation(makeEnv());
    expect(result).toEqual(payload);
  });

  it('returns null when service inactive (empty payload)', async () => {
    mockFetch(async () => new Response('{}', { status: 200 }));
    const result = await partnerValidation(makeEnv());
    expect(result).toBeNull();
  });

  it('returns null when payload missing urlRealTime', async () => {
    mockFetch(async () =>
      new Response(
        JSON.stringify({
          generationDateTime: '2026-05-17 14:00:00',
          urlStatic: 'https://s3/static',
        }),
        { status: 200 },
      ),
    );
    expect(await partnerValidation(makeEnv())).toBeNull();
  });

  it('returns null when payload is not JSON', async () => {
    mockFetch(async () => new Response('<html>Maintenance</html>', { status: 200 }));
    expect(await partnerValidation(makeEnv())).toBeNull();
  });

  it('throws on 401', async () => {
    mockFetch(async () => new Response('Incorrect username or password', { status: 401 }));
    await expect(partnerValidation(makeEnv())).rejects.toThrow(/HTTP 401/);
  });

  it('throws on 500', async () => {
    mockFetch(async () => new Response('upstream broken', { status: 500 }));
    await expect(partnerValidation(makeEnv())).rejects.toThrow(/HTTP 500/);
  });

  it('throws when credentials are not configured', async () => {
    await expect(
      partnerValidation(makeEnv({ METROBUS_USUARIO: '' })),
    ).rejects.toThrow(/METROBUS_USUARIO/);
    await expect(
      partnerValidation(makeEnv({ METROBUS_SENHA: '' })),
    ).rejects.toThrow(/METROBUS_USUARIO/);
  });

  it('sends usuario+senha in JSON body', async () => {
    let capturedBody: string | null = null;
    mockFetch(async (_input, init) => {
      capturedBody = init?.body as string;
      return new Response(
        JSON.stringify({
          generationDateTime: '2026-05-17 14:00:00',
          expirationDateTime: '2026-05-17 14:10:00',
          urlRealTime: 'a',
          urlStatic: 'b',
        }),
        { status: 200 },
      );
    });

    await partnerValidation(makeEnv({
      METROBUS_USUARIO: 'real-user',
      METROBUS_SENHA: 'real-pass',
    }));

    expect(capturedBody).not.toBeNull();
    const parsed = JSON.parse(capturedBody!);
    expect(parsed.usuario).toBe('real-user');
    expect(parsed.senha).toBe('real-pass');
  });

  it('POSTs to the Sinoptico partnerValidation endpoint', async () => {
    let capturedUrl: string | null = null;
    let capturedMethod: string | null = null;
    mockFetch(async (input, init) => {
      capturedUrl = typeof input === 'string' ? input : (input as URL).toString();
      capturedMethod = init?.method ?? null;
      return new Response('{}', { status: 200 });
    });
    await partnerValidation(makeEnv());
    expect(capturedUrl).toContain('metrobus-gtfs.sinopticoplus.com');
    expect(capturedUrl).toContain('/gtfs-api/partnerValidation');
    expect(capturedMethod).toBe('POST');
  });
});
