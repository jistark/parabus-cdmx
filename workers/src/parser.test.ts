import { describe, it, expect } from 'vitest';
import { parseAffectedStations, parseSourceTimestamp } from './parser';

/**
 * Regression tests for the parser changes in this cleanup pass.
 *
 *   LOW-03: parseAffectedStations used to split on `\sy\s`, which shredded
 *           Spanish station names containing " y " ("Insurgentes y
 *           Cuauhtémoc"). Now it splits only on punctuation.
 *
 *   LOW-04: parseSourceTimestamp had a greedy fallback `(\d{1,2}:\d{2})\s*hrs?`
 *           that matched operating-hours strings ("Servicio de 5:00 hrs a
 *           24:00 hrs") and surfaced them as the "last updated" timestamp.
 *           Pattern was removed; only the three anchored patterns remain.
 */

describe('parseAffectedStations (LOW-03 regression)', () => {
  it('keeps " y " inside station names intact', () => {
    expect(parseAffectedStations('Insurgentes y Cuauhtémoc')).toEqual([
      'Insurgentes y Cuauhtémoc',
    ]);
  });

  it('still splits on commas', () => {
    expect(parseAffectedStations('Insurgentes, Reforma, Hidalgo')).toEqual([
      'Insurgentes',
      'Reforma',
      'Hidalgo',
    ]);
  });

  it('still splits on semicolons', () => {
    expect(parseAffectedStations('Insurgentes; Reforma')).toEqual([
      'Insurgentes',
      'Reforma',
    ]);
  });

  it('handles mixed comma + station-name-with-y', () => {
    expect(parseAffectedStations('Insurgentes y Cuauhtémoc, Buenavista')).toEqual([
      'Insurgentes y Cuauhtémoc',
      'Buenavista',
    ]);
  });

  it('returns [] for null / dash placeholders', () => {
    expect(parseAffectedStations(null)).toEqual([]);
    expect(parseAffectedStations('-')).toEqual([]);
  });

  it('filters empty + dash entries after splitting', () => {
    expect(parseAffectedStations('Insurgentes, , -, Reforma')).toEqual([
      'Insurgentes',
      'Reforma',
    ]);
  });
});

describe('parseSourceTimestamp (LOW-04 regression)', () => {
  it('matches the canonical "Actualización: HH:MM" pattern', () => {
    expect(parseSourceTimestamp('<p>Actualización: 14:30</p>')).toBe('14:30');
    expect(parseSourceTimestamp('Actualizacion: 8:05')).toBe('8:05');
  });

  it('matches "Última actualización: HH:MM"', () => {
    expect(parseSourceTimestamp('Última actualización: 09:15')).toBe('09:15');
    expect(parseSourceTimestamp('Ultima actualizacion: 09:15')).toBe('09:15');
  });

  it('matches "Actualizado: HH:MM"', () => {
    expect(parseSourceTimestamp('Actualizado: 21:00')).toBe('21:00');
  });

  it('does NOT match operating-hours strings (LOW-04 regression)', () => {
    // The dropped `(\d{1,2}:\d{2})\s*hrs?` catch-all used to return "5:00"
    // for a page that only contained operating hours but no actualización
    // header.
    const html = '<p>Servicio de 5:00 hrs a 24:00 hrs</p>';
    expect(parseSourceTimestamp(html)).toBeNull();
  });

  it('returns null when no anchored pattern matches', () => {
    expect(parseSourceTimestamp('<p>No timestamp here</p>')).toBeNull();
    expect(parseSourceTimestamp('')).toBeNull();
  });

  it('prefers the actualización header when both forms appear', () => {
    const html = 'Actualización: 18:00 — Servicio de 5:00 hrs a 24:00 hrs';
    expect(parseSourceTimestamp(html)).toBe('18:00');
  });
});
