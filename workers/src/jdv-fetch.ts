/**
 * Client for the jdv-bot /fetch endpoint.
 *
 * Routes outbound HTTP through IPRoyal Web Unblocker (residential IPs) by
 * proxying through jdv-bot, which is a Bun service running on Render with
 * IPRoyal credentials. This is necessary because Cloudflare Workers cannot
 * use HTTP proxies directly — the standard fetch() doesn't accept proxy
 * configuration.
 *
 * Target source sites (metrobus.cdmx.gob.mx, incidentesmovilidad.cdmx.gob.mx)
 * block tráfico from datacenter ASNs (Cloudflare, AWS, etc.), so direct fetch
 * from Workers gets blanked-out or rejected.
 */

import type { Env } from './types';

export interface JdvFetchOptions {
  referer?: string;
  /**
   * ISO 3166-1 alpha-2. Defaults to undefined (let IPRoyal auto-pick exit).
   * Counter-intuitive: forcing country="mx" against .gob.mx sites fails with
   * BoringSSL WRONG_VERSION_NUMBER — Mexican residential pool has TLS issues
   * against this specific upstream. Auto-picked (usually US) works in 2s.
   */
  country?: string;
  /** Force routing through IPRoyal proxy regardless of jdv-bot's PROXY_DOMAINS. */
  proxy?: boolean;
  /** Enable Chromium JS rendering in the proxy (costlier, slower). */
  render?: boolean;
  /** Extra headers merged into the upstream request. */
  headers?: Record<string, string>;
  /** Number of retries on transient failures. Defaults to 2. */
  retries?: number;
}

interface JdvFetchSuccess {
  ok: true;
  body: string;
  bytes: number;
  ms: number;
}

interface JdvFetchFailure {
  ok: false;
  error: string;
  ms?: number;
}

type JdvFetchResponse = JdvFetchSuccess | JdvFetchFailure;

const DEFAULT_RETRIES = 2;
const RETRY_BACKOFF_MS = 1500;

/**
 * Fetch a URL through jdv-bot's residential proxy. Returns the body string.
 * Throws on failure after exhausting retries.
 */
export async function jdvFetch(
  env: Env,
  targetUrl: string,
  opts: JdvFetchOptions = {},
): Promise<string> {
  if (!env.JDV_BOT_URL || !env.JDV_BOT_SECRET) {
    throw new Error(
      'jdvFetch: JDV_BOT_URL and JDV_BOT_SECRET must be set as secrets',
    );
  }

  const endpoint = new URL('/fetch', env.JDV_BOT_URL).toString();
  const retries = opts.retries ?? DEFAULT_RETRIES;

  const payload = {
    url: targetUrl,
    referer: opts.referer,
    country: opts.country,
    proxy: opts.proxy ?? true,
    render: opts.render ?? false,
    headers: opts.headers,
  };

  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= retries; attempt++) {
    if (attempt > 0) {
      await sleep(RETRY_BACKOFF_MS * Math.pow(2, attempt - 1));
      console.log(`jdvFetch retry ${attempt} for ${targetUrl}`);
    }

    try {
      const resp = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.JDV_BOT_SECRET}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const data = (await resp.json()) as JdvFetchResponse;

      if (resp.ok && data.ok) {
        return data.body;
      }

      // Non-2xx or ok:false → treat as retryable except 4xx auth errors
      const errMsg = data.ok === false
        ? data.error
        : `jdv-bot HTTP ${resp.status}`;

      // Don't retry auth failures or bad requests
      if (resp.status === 401 || resp.status === 400 || resp.status === 503) {
        throw new Error(`jdvFetch: ${errMsg}`);
      }

      lastError = new Error(`jdvFetch: ${errMsg}`);
    } catch (err) {
      // Network-level failure (DNS, TLS, abort, etc.) — retryable.
      const msg = err instanceof Error ? err.message : String(err);
      // Non-retryable errors we threw above also land here; re-throw them.
      if (msg.startsWith('jdvFetch: ') && (
        msg.includes('invalid bearer') ||
        msg.includes('FETCH_SHARED_SECRET') ||
        msg.includes('field "url"')
      )) {
        throw err;
      }
      lastError = err instanceof Error ? err : new Error(String(err));
    }
  }

  throw lastError ?? new Error('jdvFetch: exhausted retries with no error captured');
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
