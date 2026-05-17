/**
 * Metrobus CDMX Status API Types
 *
 * These types define the shape of data returned by the scraping API.
 */

// ============================================================================
// Response Types
// ============================================================================

export interface MetrobusResponse {
  /** ISO 8601 timestamp when we scraped the data */
  lastUpdated: string;
  /** Timestamp from the source page if available */
  sourceTimestamp: string | null;
  /** True if serving stale cache after a fetch failure */
  stale?: boolean;
  /** Error message if something went wrong */
  error?: string;
  /** Status of each data source */
  sources: SourcesStatus;
  /** Status of each Metrobus line */
  lines: LineStatus[];
  /** Scheduled maintenance closures */
  scheduledMaintenance: MaintenanceInfo[];
  /** Elevators out of service */
  elevators: ElevatorInfo[];
}

export interface SourcesStatus {
  incidentes: SourceStatus;
  mantenimiento: SourceStatus;
}

export interface SourceStatus {
  available: boolean;
  error?: string;
}

/**
 * Service status categories:
 * - normal: "Servicio regular" - Good service, no issues
 * - delayed: "Congestionamiento vial" or "Retraso en el servicio" - Delays
 * - maintenance: "Intervención en la estación" - Station maintenance (not incident)
 * - closure: "Eventos temporales" - Temporary closures
 * - limited: Service between specific stations only (detected from details)
 * - suspended: "Sin servicio la ruta" or "Suspendido" - No service
 * - protest: "Manifestación" - Protest/demonstration affecting service (urgent)
 * - unknown: Unrecognized status text
 */
export type ServiceStatus =
  | 'normal'
  | 'delayed'
  | 'maintenance'
  | 'closure'
  | 'limited'
  | 'suspended'
  | 'protest'
  | 'unknown';

/**
 * Individual incident for a line.
 * A line can have multiple incidents (e.g., protest + maintenance).
 */
export interface LineIncident {
  /** Normalized status for this incident */
  status: ServiceStatus;
  /** Original status text in Spanish (unmodified) */
  statusText: string;
  /** List of affected stations for this incident */
  affectedStations: string[];
  /** Additional details about this incident */
  details: string | null;
}

export interface LineStatus {
  /** Line number as string: "1", "2", etc. */
  line: string;
  /** Line identifier: "MB1", "MB2", etc. */
  lineId: string;
  /** Worst status across all incidents (for backwards compat) */
  status: ServiceStatus;
  /** Status text of worst incident (for backwards compat) */
  statusText: string;
  /** All affected stations combined from all incidents (for backwards compat) */
  affectedStations: string[];
  /** Details of worst incident (for backwards compat) */
  details: string | null;
  /** All incidents for this line */
  incidents: LineIncident[];
}

export interface MaintenanceInfo {
  /** Station name */
  station: string;
  /** Line identifier: "MB1", "MB2", etc. */
  lineId: string;
  /** Line number as string */
  line: string;
  /** Direction: "Ambos sentidos", "Norte a Sur", etc. */
  direction: string;
  /** Reason for closure */
  reason: string;
  /** Closure period: "4 y 5 de Diciembre", "8 dic, 20:00-cierre" */
  closurePeriod: string;
}

export interface ElevatorInfo {
  /** Station name */
  station: string;
  /** Line identifier: "MB1", "MB2", etc. */
  lineId: string;
  /** Line number as string */
  line: string;
  /** Direction: "Ambos sentidos", "Norte", etc. */
  direction: string;
  /** Reason for outage */
  reason: string;
  /** Estimated repair date or null if unknown */
  estimatedRepair: string | null;
}

// ============================================================================
// Health Check Types
// ============================================================================

export interface HealthResponse {
  status: 'ok' | 'degraded' | 'error';
  timestamp: string;
  cacheAge: number | null;
}

// ============================================================================
// Internal Types
// ============================================================================

export interface CachedData {
  data: MetrobusResponse;
  timestamp: number;
}

export interface ScrapeResult {
  incidentes: IncidentesResult;
  mantenimiento: MantenimientoResult;
}

export interface IncidentesResult {
  success: boolean;
  error?: string;
  sourceTimestamp: string | null;
  lines: LineStatus[];
}

export interface MantenimientoResult {
  success: boolean;
  error?: string;
  maintenance: MaintenanceInfo[];
  elevators: ElevatorInfo[];
}

// ============================================================================
// Cloudflare Worker Types
// ============================================================================

export interface Env {
  METROBUS_CACHE: KVNamespace;
  /** jdv-bot base URL (e.g. https://jdv-bot.onrender.com). Secret. */
  JDV_BOT_URL: string;
  /** Bearer token shared with jdv-bot's /fetch endpoint. Secret. */
  JDV_BOT_SECRET: string;
  /** Sinoptico Plus partner API username. Secret. */
  METROBUS_USUARIO: string;
  /** Sinoptico Plus partner API password. Secret. */
  METROBUS_SENHA: string;
}

export interface ScheduledEvent {
  cron: string;
  type: string;
  scheduledTime: number;
}

// ============================================================================
// Constants
// ============================================================================

export const CACHE_KEY = 'metrobus-status';
export const CACHE_TTL_SECONDS = 5 * 60; // 5 minutes

export const METROBUS_LINES = ['1', '2', '3', '4', '5', '6', '7'] as const;

export const URLS = {
  incidentes: 'https://incidentesmovilidad.cdmx.gob.mx/public/bandejaEstadoServicio.xhtml?idMedioTransporte=mb',
  servicioMB: 'https://www.metrobus.cdmx.gob.mx/ServicioMB',
} as const;

