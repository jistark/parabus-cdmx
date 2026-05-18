/**
 * HTML Parsing Functions for Metrobus CDMX
 *
 * Uses regex-based parsing since Cloudflare Workers don't support DOM APIs.
 * All parsers are defensive and handle malformed HTML gracefully.
 */

import {
  LineStatus,
  LineIncident,
  MaintenanceInfo,
  ElevatorInfo,
  ServiceStatus,
  METROBUS_LINES,
} from './types';

// ============================================================================
// Status Normalization
// ============================================================================

/**
 * Normalize Spanish status text to standard status enum.
 *
 * Status mapping:
 * - "Servicio regular" -> normal (Buen servicio)
 * - "Congestionamiento vial" / "Retraso en el servicio" -> delayed (Retraso)
 * - "Intervencion en la estacion" -> maintenance (Mantenimiento)
 * - "Eventos temporales" -> closure (Cierre)
 * - "Sin servicio la ruta" / "Suspendido" -> suspended (Sin servicio)
 * - Unrecognized -> unknown
 *
 * Note: "limited" status is determined by examining details, not statusText.
 * Use determineStatus() for full status determination including details check.
 */
export function normalizeStatus(text: string): ServiceStatus {
  const lower = text.toLowerCase().trim();

  // Normal service indicators - "Servicio regular" -> "Buen servicio"
  if (
    lower.includes('regular') ||
    lower.includes('normal') ||
    lower.includes('operando') ||
    lower.includes('servicio activo')
  ) {
    return 'normal';
  }

  // Suspended service - "Sin servicio la ruta" / "Suspendido" -> "Sin servicio"
  if (
    lower.includes('sin servicio') ||
    lower.includes('suspendido')
  ) {
    return 'suspended';
  }

  // Maintenance - "Intervencion en la estacion" -> "Mantenimiento"
  // Note: This should ideally be moved to scheduledMaintenance section
  if (
    lower.includes('intervención en la estación') ||
    lower.includes('intervencion en la estacion') ||
    lower.includes('intervención') ||
    lower.includes('intervencion')
  ) {
    return 'maintenance';
  }

  // Delayed service - "Congestionamiento vial" / "Retraso en el servicio" -> "Retraso"
  if (
    lower.includes('congestionamiento') ||
    lower.includes('retraso')
  ) {
    return 'delayed';
  }

  // Temporary closure - "Eventos temporales" -> "Cierre"
  if (
    lower.includes('eventos temporales') ||
    lower.includes('evento temporal') ||
    lower.includes('cerrado') ||
    lower.includes('fuera de servicio')
  ) {
    return 'closure';
  }

  // Protest/demonstration - "Manifestación" -> "protest" (urgent)
  if (
    lower.includes('manifestación') ||
    lower.includes('manifestacion') ||
    lower.includes('marcha') ||
    lower.includes('bloqueo')
  ) {
    return 'protest';
  }

  // Unrecognized status
  return 'unknown';
}

/**
 * Check if details indicate limited service.
 * Pattern: "Servicio de [station] a [station] y [station] a [station]"
 */
export function isLimitedService(details: string | null): boolean {
  if (!details) return false;

  const lower = details.toLowerCase();

  // Pattern for limited service: "Servicio de X a Y"
  // This indicates service only runs between specific stations
  const limitedPattern = /servicio\s+de\s+.+\s+a\s+.+/i;

  return limitedPattern.test(lower);
}

/**
 * Check if details indicate suspended route within limited service.
 * Pattern: "Sin servicio la ruta" appears in details
 */
export function hasSuspendedRoute(details: string | null): boolean {
  if (!details) return false;

  const lower = details.toLowerCase();
  return lower.includes('sin servicio la ruta');
}

/**
 * Determine final status considering both statusText and details.
 *
 * Priority:
 * 1. If details contains "Sin servicio la ruta" -> suspended
 * 2. If details indicates limited service pattern -> limited
 * 3. Otherwise use normalized status from statusText
 */
export function determineStatus(statusText: string, details: string | null): ServiceStatus {
  // First check details for suspended route (highest priority)
  if (hasSuspendedRoute(details)) {
    return 'suspended';
  }

  // Check for limited service pattern in details
  if (isLimitedService(details)) {
    return 'limited';
  }

  // Fall back to status from statusText
  return normalizeStatus(statusText);
}

/**
 * Get severity score for a status.
 * Higher = more severe. Used to determine worst status across incidents.
 *
 * Severity order (worst to least):
 * protest > suspended > delayed > limited > closure > maintenance > unknown > normal
 */
export function getStatusSeverity(status: ServiceStatus): number {
  const severityMap: Record<ServiceStatus, number> = {
    protest: 100,    // Most urgent - affects commute immediately
    suspended: 90,   // No service
    delayed: 70,     // Service running but slow
    limited: 60,     // Partial service
    closure: 50,     // Temporary closure
    maintenance: 40, // Planned maintenance
    unknown: 20,     // Unknown status
    normal: 0,       // Good service
  };
  return severityMap[status];
}

/**
 * Extract line number from various formats
 * Examples: "Linea 1", "L1", "MB1", "1", "linea1"
 */
export function extractLineNumber(text: string): string | null {
  if (!text) return null;

  // Try to match "Linea X" or "Linea X"
  const lineaMatch = text.match(/l[ií]nea\s*(\d+)/i);
  if (lineaMatch && lineaMatch[1]) return lineaMatch[1];

  // Try to match "MB1", "MB2", etc.
  const mbMatch = text.match(/MB(\d+)/i);
  if (mbMatch && mbMatch[1]) return mbMatch[1];

  // Try to match "L1", "L2", etc.
  const lMatch = text.match(/L(\d+)/i);
  if (lMatch && lMatch[1]) return lMatch[1];

  // Try to match just a number
  const numMatch = text.match(/^(\d+)$/);
  if (numMatch && numMatch[1]) return numMatch[1];

  return null;
}

/**
 * Create line ID from line number
 */
export function createLineId(lineNumber: string): string {
  return `MB${lineNumber}`;
}

// ============================================================================
// Incidents Table Parser (bandejaEstadoServicio.xhtml)
// ============================================================================

/**
 * Parse the incidents table from the estado de servicio page.
 * Collects ALL rows and groups incidents by line number.
 *
 * Expected HTML structure:
 * <tbody id="frmEstadoServicio:tblEstadoServicio_data">
 *   <tr data-ri="0">
 *     <td><img src="...MB1.png" /></td>
 *     <td>Servicio Regular</td>
 *     <td>-</td>
 *   </tr>
 * </tbody>
 */
export function parseIncidentsTable(html: string): LineStatus[] {
  // Try to find the table body
  const tableBodyMatch = html.match(
    /<tbody[^>]*id=["']frmEstadoServicio:tblEstadoServicio_data["'][^>]*>([\s\S]*?)<\/tbody>/i
  );

  if (!tableBodyMatch || !tableBodyMatch[1]) {
    // Table not found - return empty array
    return [];
  }

  const tableBody = tableBodyMatch[1];

  // Collect all incidents grouped by line number
  const incidentsByLine = new Map<string, LineIncident[]>();

  // Find all rows
  const rowRegex = /<tr[^>]*data-ri=["'](\d+)["'][^>]*>([\s\S]*?)<\/tr>/gi;
  let rowMatch;

  while ((rowMatch = rowRegex.exec(tableBody)) !== null) {
    const rowContent = rowMatch[2];
    if (rowContent) {
      const parsed = parseIncidentRowData(rowContent);
      if (parsed) {
        const { lineNumber, incident } = parsed;
        const existing = incidentsByLine.get(lineNumber) || [];
        existing.push(incident);
        incidentsByLine.set(lineNumber, existing);
      }
    }
  }

  // Convert grouped incidents to LineStatus objects
  const lines: LineStatus[] = [];

  for (const [lineNumber, incidents] of incidentsByLine) {
    const lineStatus = buildLineStatus(lineNumber, incidents);
    lines.push(lineStatus);
  }

  return lines;
}

/**
 * Build a LineStatus from a line number and its incidents.
 * Sets top-level fields based on the most severe incident.
 */
function buildLineStatus(lineNumber: string, incidents: LineIncident[]): LineStatus {
  // Guard against empty incidents (should never happen, but TypeScript needs assurance)
  if (incidents.length === 0) {
    const defaultIncident: LineIncident = {
      status: 'normal',
      statusText: 'Servicio Regular',
      affectedStations: [],
      details: null,
    };
    return {
      line: lineNumber,
      lineId: createLineId(lineNumber),
      status: 'normal',
      statusText: 'Servicio Regular',
      affectedStations: [],
      details: null,
      incidents: [defaultIncident],
    };
  }

  // Find the most severe incident
  let worstIncident = incidents[0]!;
  let worstSeverity = getStatusSeverity(worstIncident.status);

  for (let i = 1; i < incidents.length; i++) {
    const incident = incidents[i]!;
    const severity = getStatusSeverity(incident.status);
    if (severity > worstSeverity) {
      worstSeverity = severity;
      worstIncident = incident;
    }
  }

  // Combine all affected stations from all incidents (deduplicated)
  const allStations = new Set<string>();
  for (const incident of incidents) {
    for (const station of incident.affectedStations) {
      allStations.add(station);
    }
  }

  return {
    line: lineNumber,
    lineId: createLineId(lineNumber),
    status: worstIncident.status,
    statusText: worstIncident.statusText,
    affectedStations: Array.from(allStations),
    details: worstIncident.details,
    incidents,
  };
}

/**
 * Parse a single row and return the line number and incident data.
 * Returns null if the row cannot be parsed.
 */
function parseIncidentRowData(rowHtml: string): { lineNumber: string; incident: LineIncident } | null {
  // Extract cells
  const cellRegex = /<td[^>]*>([\s\S]*?)<\/td>/gi;
  const cells: string[] = [];
  let cellMatch;

  while ((cellMatch = cellRegex.exec(rowHtml)) !== null) {
    if (cellMatch[1]) {
      cells.push(cellMatch[1]);
    }
  }

  if (cells.length < 2) {
    return null;
  }

  const cell0 = cells[0];
  const cell1 = cells[1];

  if (!cell0 || !cell1) {
    return null;
  }

  // Cell 0: Image with line number
  const imgMatch = cell0.match(/MB(\d+)\.png/i);
  const lineNumber = (imgMatch && imgMatch[1]) ? imgMatch[1] : extractLineNumber(cell0);

  if (!lineNumber) {
    return null;
  }

  // Cell 1: Status text (preserve original, unmodified)
  const statusText = stripHtml(cell1).trim();

  // Cell 2: Estaciones afectadas (affected stations)
  const cell2 = cells[2];
  const rawStations = cell2 ? stripHtml(cell2).trim() : null;
  const stationsText = rawStations && rawStations !== '-' && rawStations.toLowerCase() !== 'ninguna'
    ? rawStations
    : null;

  // Cell 3: Informacion adicional (additional details) - THE COMPLETE INFO
  // IMPORTANT: Preserve the COMPLETE details text, do not truncate
  const cell3 = cells[3];
  const rawDetails = cell3 ? stripHtml(cell3).trim() : null;
  const details = rawDetails && rawDetails !== '-' && rawDetails.length > 0 ? rawDetails : null;

  // Determine status using both statusText and details
  // This allows detecting "limited" service from details pattern
  const status = determineStatus(statusText, details);

  // Parse affected stations from the stations column (Cell 2), not details
  const affectedStations = parseAffectedStations(stationsText);

  const incident: LineIncident = {
    status,
    statusText: statusText || 'Servicio Regular',
    affectedStations,
    details,
  };

  return { lineNumber, incident };
}

/**
 * Parse affected stations from details text.
 *
 * Only splits on punctuation. Spanish station names commonly include " y "
 * ("Insurgentes y Cuauhtémoc"); splitting on `\sy\s` would shred those.
 * Operators that need to list two stations should separate with a comma.
 */
export function parseAffectedStations(details: string | null): string[] {
  if (!details || details === '-') {
    return [];
  }

  const stations = details
    .split(/[,;]/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && s !== '-');

  return stations;
}

// ============================================================================
// Maintenance Tables Parser (ServicioMB)
// ============================================================================

/**
 * Parse both maintenance tables from the ServicioMB page
 */
export function parseMaintenancePage(html: string): {
  maintenance: MaintenanceInfo[];
  elevators: ElevatorInfo[];
} {
  return {
    maintenance: parseMaintenanceTable(html),
    elevators: parseElevatorsTable(html),
  };
}

/**
 * Parse the "Estaciones cerradas por mantenimiento" table
 *
 * Expected columns: Linea, Estacion, Sentido, Razon, Periodo de cierre
 */
function parseMaintenanceTable(html: string): MaintenanceInfo[] {
  // Find the maintenance table - look for the heading first
  const sectionMatch = html.match(
    /Estaciones?\s+cerradas?\s+por\s+mantenimiento[\s\S]*?<table[^>]*>([\s\S]*?)<\/table>/i
  );

  if (!sectionMatch || !sectionMatch[1]) {
    // Try alternative: look for any table after the maintenance heading
    const altMatch = findTableAfterHeading(html, /mantenimiento/i);
    if (!altMatch) return [];
    return parseGenericTable(altMatch, parseMaintenanceRow);
  }

  return parseGenericTable(sectionMatch[1], parseMaintenanceRow);
}

/**
 * Parse a maintenance table row
 */
function parseMaintenanceRow(cells: string[]): MaintenanceInfo | null {
  // Expected: Linea, Estacion, Sentido, Razon, Periodo
  if (cells.length < 4) return null;

  const cell0 = cells[0];
  const cell1 = cells[1];
  const cell2 = cells[2];
  const cell3 = cells[3];
  const cell4 = cells[4];

  if (!cell0 || !cell1 || !cell2 || !cell3) return null;

  const lineText = stripHtml(cell0).trim();
  const lineNumber = extractLineNumber(lineText);

  if (!lineNumber) return null;

  return {
    lineId: createLineId(lineNumber),
    line: lineNumber,
    station: stripHtml(cell1).trim(),
    direction: stripHtml(cell2).trim() || 'Ambos sentidos',
    reason: stripHtml(cell3).trim() || 'Mantenimiento',
    closurePeriod: cell4 ? stripHtml(cell4).trim() : 'No especificado',
  };
}

/**
 * Parse the "Elevadores Fuera de Servicio" table
 *
 * Expected columns: Linea, Estacion, Sentido de circulacion, Motivo, Fecha estimada de reparacion
 */
function parseElevatorsTable(html: string): ElevatorInfo[] {
  // Find the elevators table
  const sectionMatch = html.match(
    /Elevadores?\s+[Ff]uera\s+de\s+[Ss]ervicio[\s\S]*?<table[^>]*>([\s\S]*?)<\/table>/i
  );

  if (!sectionMatch || !sectionMatch[1]) {
    const altMatch = findTableAfterHeading(html, /elevador/i);
    if (!altMatch) return [];
    return parseGenericTable(altMatch, parseElevatorRow);
  }

  return parseGenericTable(sectionMatch[1], parseElevatorRow);
}

/**
 * Parse an elevator table row
 */
function parseElevatorRow(cells: string[]): ElevatorInfo | null {
  // Expected: Linea, Estacion, Sentido, Motivo, Fecha estimada
  if (cells.length < 4) return null;

  const cell0 = cells[0];
  const cell1 = cells[1];
  const cell2 = cells[2];
  const cell3 = cells[3];
  const cell4 = cells[4];

  if (!cell0 || !cell1 || !cell2 || !cell3) return null;

  const lineText = stripHtml(cell0).trim();
  const lineNumber = extractLineNumber(lineText);

  if (!lineNumber) return null;

  const estimatedRepair = cell4 ? stripHtml(cell4).trim() : null;

  return {
    lineId: createLineId(lineNumber),
    line: lineNumber,
    station: stripHtml(cell1).trim(),
    direction: stripHtml(cell2).trim() || 'Ambos sentidos',
    reason: stripHtml(cell3).trim() || 'Sin especificar',
    estimatedRepair: estimatedRepair && estimatedRepair !== '-' ? estimatedRepair : null,
  };
}

/**
 * Generic table parser that extracts rows and applies a row parser function
 */
function parseGenericTable<T>(
  tableHtml: string,
  rowParser: (cells: string[]) => T | null
): T[] {
  const results: T[] = [];

  // Find tbody or use the whole table
  const tbodyMatch = tableHtml.match(/<tbody[^>]*>([\s\S]*?)<\/tbody>/i);
  const bodyHtml = tbodyMatch && tbodyMatch[1] ? tbodyMatch[1] : tableHtml;

  // Find all rows (skip header rows)
  const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let rowMatch;
  let isFirstRow = true;

  while ((rowMatch = rowRegex.exec(bodyHtml)) !== null) {
    const rowContent = rowMatch[1];

    if (!rowContent) continue;

    // Skip header rows (contain <th>)
    if (rowContent.includes('<th')) {
      continue;
    }

    // Skip first row if it looks like a header
    if (isFirstRow) {
      isFirstRow = false;
      const firstCellText = stripHtml(rowContent).toLowerCase();
      if (
        firstCellText.includes('linea') ||
        firstCellText.includes('linea') ||
        firstCellText.includes('estacion') ||
        firstCellText.includes('estacion')
      ) {
        continue;
      }
    }

    // Extract cells
    const cells = extractCells(rowContent);
    if (cells.length === 0) continue;

    const parsed = rowParser(cells);
    if (parsed) {
      results.push(parsed);
    }
  }

  return results;
}

/**
 * Find a table that appears after a heading matching the given pattern
 */
function findTableAfterHeading(html: string, headingPattern: RegExp): string | null {
  // Look for h1-h6 or strong/b containing the heading
  const headingRegex = new RegExp(
    `(?:<h[1-6][^>]*>|<strong>|<b>)[^<]*${headingPattern.source}[^<]*(?:<\/h[1-6]>|<\/strong>|<\/b>)`,
    'i'
  );

  const headingMatch = html.match(headingRegex);
  if (!headingMatch || headingMatch.index === undefined) return null;

  // Find the next table after this heading
  const afterHeading = html.slice(headingMatch.index + headingMatch[0].length);
  const tableMatch = afterHeading.match(/<table[^>]*>([\s\S]*?)<\/table>/i);

  return tableMatch && tableMatch[1] ? tableMatch[1] : null;
}

// ============================================================================
// Source Timestamp Parser
// ============================================================================

/**
 * Extract the "Actualizacion: HH:mm" timestamp from the page
 */
export function parseSourceTimestamp(html: string): string | null {
  // Anchored patterns only. A naked `(\d{1,2}:\d{2})\s*hrs?` catch-all used
  // to match any "HH:MM hrs" on the page (e.g. "Servicio de 5:00 hrs a
  // 24:00 hrs") and surfaced operating hours as "last updated".
  const patterns = [
    /Actualizaci[oó]n:\s*(\d{1,2}:\d{2})/i,
    /[Úú]ltima\s+actualizaci[oó]n:\s*(\d{1,2}:\d{2})/i,
    /Actualizado:\s*(\d{1,2}:\d{2})/i,
  ];

  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      return match[1];
    }
  }

  return null;
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Strip HTML tags from a string
 */
export function stripHtml(html: string): string {
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Extract table cells from a row
 */
function extractCells(rowHtml: string): string[] {
  const cells: string[] = [];
  const cellRegex = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;
  let match;

  while ((match = cellRegex.exec(rowHtml)) !== null) {
    if (match[1]) {
      cells.push(match[1]);
    }
  }

  return cells;
}

/**
 * Generate default line statuses for all 7 lines (assume normal service)
 */
export function getDefaultLineStatuses(): LineStatus[] {
  return METROBUS_LINES.map((line): LineStatus => {
    const defaultIncident: LineIncident = {
      status: 'normal',
      statusText: 'Servicio Regular',
      affectedStations: [],
      details: null,
    };
    return {
      line,
      lineId: createLineId(line),
      status: 'normal',
      statusText: 'Servicio Regular',
      affectedStations: [],
      details: null,
      incidents: [defaultIncident],
    };
  });
}

/**
 * Merge scraped line statuses with defaults
 * Ensures all 7 lines are represented
 */
export function mergeWithDefaults(scraped: LineStatus[]): LineStatus[] {
  const defaults = getDefaultLineStatuses();
  const scrapedMap = new Map(scraped.map((l) => [l.line, l]));

  return defaults.map((defaultLine) => {
    const scrapedLine = scrapedMap.get(defaultLine.line);
    return scrapedLine || defaultLine;
  });
}
