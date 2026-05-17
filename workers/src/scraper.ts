/**
 * Scraper Module for Metrobus CDMX
 *
 * Fetches and parses data from Metrobus CDMX website.
 * Handles errors gracefully and returns partial data when possible.
 */

import {
  Env,
  LineStatus,
  MaintenanceInfo,
  ElevatorInfo,
  IncidentesResult,
  MantenimientoResult,
  ScrapeResult,
  URLS,
} from './types';

import {
  parseIncidentsTable,
  parseMaintenancePage,
  parseSourceTimestamp,
  mergeWithDefaults,
} from './parser';

import { jdvFetch } from './jdv-fetch';

// ============================================================================
// Main Scrape Function
// ============================================================================

/**
 * Scrape both data sources in parallel via the jdv-bot residential proxy.
 *
 * The Metrobús CDMX public sites block datacenter ASN tráfico. We route HTTP
 * through jdv-bot (which uses IPRoyal Web Unblocker) so the upstream sees
 * residential Mexican IPs. Retries, timeout, and proxy escalation are all
 * handled inside jdvFetch / jdv-bot — this module just orchestrates parsing.
 */
export async function scrapeAll(env: Env): Promise<ScrapeResult> {
  const [incidentes, mantenimiento] = await Promise.all([
    scrapeIncidentes(env),
    scrapeMantenimiento(env),
  ]);

  return { incidentes, mantenimiento };
}

// ============================================================================
// Incidents Scraper
// ============================================================================

async function scrapeIncidentes(env: Env): Promise<IncidentesResult> {
  try {
    let html = await jdvFetch(env, URLS.incidentes, {
      referer: URLS.servicioMB,
    });
    let lines = parseIncidentsTable(html);
    let sourceTimestamp = parseSourceTimestamp(html);

    // If the incidents URL returns no parseable data, try the iframe in the
    // main ServicioMB page.
    if (lines.length === 0) {
      console.log('Incidents table not found at direct URL, trying ServicioMB page...');
      try {
        html = await jdvFetch(env, URLS.servicioMB);
        lines = parseIncidentsTable(html);
        sourceTimestamp = parseSourceTimestamp(html);
      } catch (fallbackError) {
        console.log('Fallback to ServicioMB also failed:', fallbackError);
      }
    }

    const mergedLines = mergeWithDefaults(lines);

    return {
      success: true,
      sourceTimestamp,
      lines: mergedLines,
    };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error('Failed to scrape incidents:', errorMessage);

    return {
      success: false,
      error: errorMessage,
      sourceTimestamp: null,
      lines: mergeWithDefaults([]),
    };
  }
}

// ============================================================================
// Maintenance Scraper
// ============================================================================

async function scrapeMantenimiento(env: Env): Promise<MantenimientoResult> {
  try {
    const html = await jdvFetch(env, URLS.servicioMB);
    const { maintenance, elevators } = parseMaintenancePage(html);

    return {
      success: true,
      maintenance,
      elevators,
    };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error('Failed to scrape maintenance:', errorMessage);

    return {
      success: false,
      error: errorMessage,
      maintenance: [],
      elevators: [],
    };
  }
}

// ============================================================================
// Filter Functions
// ============================================================================

/**
 * Filter line statuses by line numbers
 */
export function filterLines(lines: LineStatus[], lineFilter: string[]): LineStatus[] {
  if (lineFilter.length === 0) {
    return lines;
  }

  const filterSet = new Set(lineFilter.map((l) => l.trim()));
  return lines.filter((line) => filterSet.has(line.line));
}

/**
 * Filter maintenance info by line numbers
 */
export function filterMaintenance(
  maintenance: MaintenanceInfo[],
  lineFilter: string[]
): MaintenanceInfo[] {
  if (lineFilter.length === 0) {
    return maintenance;
  }

  const filterSet = new Set(lineFilter.map((l) => l.trim()));
  return maintenance.filter((m) => filterSet.has(m.line));
}

/**
 * Filter elevator info by line numbers
 */
export function filterElevators(
  elevators: ElevatorInfo[],
  lineFilter: string[]
): ElevatorInfo[] {
  if (lineFilter.length === 0) {
    return elevators;
  }

  const filterSet = new Set(lineFilter.map((l) => l.trim()));
  return elevators.filter((e) => filterSet.has(e.line));
}
