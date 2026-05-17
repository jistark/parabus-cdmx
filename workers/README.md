# Metrobus CDMX Status API

Cloudflare Worker that scrapes and serves real-time status information for Metrobus CDMX.

## Features

- Real-time line status (normal, disrupted, suspended)
- Scheduled maintenance closures
- Elevator outages
- KV-based caching with 5-minute TTL
- Cron trigger for pre-warming cache at 4:30 AM CDMX
- Line filtering support
- Graceful degradation when sources are unavailable

## Prerequisites

- Node.js 18+ and npm
- Cloudflare account with Workers access
- Wrangler CLI (`npm install -g wrangler`)

## Setup

### 1. Install Dependencies

```bash
cd workers
npm install
```

### 2. Authenticate with Cloudflare

```bash
wrangler login
```

### 3. Create KV Namespace

```bash
# Create production namespace
npm run kv:create

# Create preview namespace for local development
npm run kv:create:preview
```

Copy the namespace IDs from the output and update `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "METROBUS_CACHE"
id = "your-production-namespace-id"
preview_id = "your-preview-namespace-id"
```

### 4. Local Development

```bash
# Start local dev server
npm run dev

# Or with remote KV access
npm run dev:remote
```

The API will be available at `http://localhost:8787`

### 5. Deploy

```bash
# Deploy to production
npm run deploy

# Deploy to staging
npm run deploy:staging
```

## API Endpoints

### GET /status

Returns complete status information for all Metrobus lines.

**Query Parameters:**

| Parameter | Type    | Description                          |
|-----------|---------|--------------------------------------|
| refresh   | boolean | Bypass cache and fetch fresh data    |
| lines     | string  | Comma-separated line numbers (1,3,5) |

**Response Headers:**

| Header        | Description                              |
|---------------|------------------------------------------|
| X-Cache       | HIT or MISS                              |
| X-Cache-Age   | Age of cached data in seconds            |
| Cache-Control | Browser cache directive (max-age=60)     |

**Example Request:**

```bash
# Get all lines
curl https://metrobus-status.your-subdomain.workers.dev/status

# Force refresh
curl "https://metrobus-status.your-subdomain.workers.dev/status?refresh=true"

# Filter to specific lines
curl "https://metrobus-status.your-subdomain.workers.dev/status?lines=1,3,5"
```

**Example Response:**

```json
{
  "lastUpdated": "2024-12-06T10:30:00.000Z",
  "sourceTimestamp": "10:25",
  "sources": {
    "incidentes": { "available": true },
    "mantenimiento": { "available": true }
  },
  "lines": [
    {
      "line": "1",
      "lineId": "MB1",
      "status": "normal",
      "statusText": "Servicio Regular",
      "affectedStations": [],
      "details": null
    },
    {
      "line": "2",
      "lineId": "MB2",
      "status": "disrupted",
      "statusText": "Servicio con demoras",
      "affectedStations": ["Insurgentes", "Reforma"],
      "details": "Accidente vehicular"
    }
  ],
  "scheduledMaintenance": [
    {
      "station": "Manuel Gonzalez",
      "lineId": "MB1",
      "line": "1",
      "direction": "Ambos sentidos",
      "reason": "Mantenimiento Mayor",
      "closurePeriod": "4 y 5 de Diciembre"
    }
  ],
  "elevators": [
    {
      "station": "La Raza",
      "lineId": "MB3",
      "line": "3",
      "direction": "Norte",
      "reason": "Reparacion",
      "estimatedRepair": "15 de Diciembre"
    }
  ]
}
```

### GET /health

Simple health check endpoint.

**Example Request:**

```bash
curl https://metrobus-status.your-subdomain.workers.dev/health
```

**Example Response:**

```json
{
  "status": "ok",
  "timestamp": "2024-12-06T10:30:00.000Z",
  "cacheAge": 145
}
```

### GET /

API information and available endpoints.

## Data Sources

The worker scrapes two URLs:

1. **Incidents/Status**: `https://www.metrobus.cdmx.gob.mx/public/bandejaEstadoServicio.xhtml`
   - Real-time line status
   - Note: May return 404, falls back to ServicioMB

2. **Maintenance**: `https://www.metrobus.cdmx.gob.mx/ServicioMB`
   - Scheduled maintenance closures
   - Elevator outages

## Caching Strategy

- **TTL**: 5 minutes (configurable in `types.ts`)
- **Stale data**: Served with `stale: true` flag when fresh fetch fails
- **Pre-warming**: Cron trigger at 4:30 AM CDMX (10:30 UTC)
- **Manual refresh**: Use `?refresh=true` query parameter

## Error Handling

The API is designed to always return a valid response:

- If one source fails, partial data is returned with error info in `sources`
- If all sources fail but cache exists, stale data is served with `stale: true`
- If everything fails, an error response with empty arrays is returned

## Development

```bash
# Type checking
npm run typecheck

# Run tests
npm run test

# Watch mode for tests
npm run test:watch

# Lint code
npm run lint

# Format code
npm run format
```

## Monitoring

```bash
# View real-time logs
npm run tail

# View staging logs
npm run tail:staging
```

## Project Structure

```
workers/
├── src/
│   ├── index.ts      # Entry point, routing, handlers
│   ├── scraper.ts    # HTTP fetching and orchestration
│   ├── parser.ts     # HTML parsing functions
│   └── types.ts      # TypeScript interfaces and constants
├── wrangler.toml     # Cloudflare configuration
├── package.json
├── tsconfig.json
└── README.md
```

## iOS Integration

For the Parabus iOS app, use the `/status` endpoint on app load:

```swift
// Swift example
let url = URL(string: "https://metrobus-status.workers.dev/status")!
let (data, response) = try await URLSession.shared.data(from: url)

// Check cache status
if let httpResponse = response as? HTTPURLResponse {
    let cacheHit = httpResponse.value(forHTTPHeaderField: "X-Cache") == "HIT"
    let cacheAge = Int(httpResponse.value(forHTTPHeaderField: "X-Cache-Age") ?? "0")
}
```

For widgets, the 60-second browser cache (`Cache-Control: max-age=60`) helps reduce API calls.

## License

MIT
