// workers/src/data/cenefas.ts
import type { CenefaDataset } from './cenefas-types';

/**
 * Curated from official Metrobús references (ME_LX line maps + service pages).
 * version bumps whenever any service changes — the app caches on it.
 *
 * Línea 1 — Insurgentes (Indios Verdes ↔ El Caminero), 46 stations.
 *
 * Sources:
 *   - Official line map ME_L1_2022.pdf (data.metrobus.cdmx.gob.mx/docs):
 *     full ordered station sequence; no servicios cortos are printed on the
 *     cenefa, so L1 is modeled as a single regular service.
 *   - metrobus.cdmx.gob.mx/FelixCuevas: Félix Cuevas operates with two
 *     physical platforms ("dos estaciones"), but the partner GTFS exposes a
 *     single stop_id (09619f) shared by both directions.
 *
 * GTFS platform-stop convention (verified against the live snapshot +
 * /static/schedule sequences on 2026-06-11):
 *   - Most L1 stations are a single GTFS stop shared by both directions.
 *   - Five stations have per-direction platform pairs distinguished by a
 *     trailing period in the stop name: the base name ("Insurgentes",
 *     "Indios Verdes L1", …) is the southbound (Ida → El Caminero) platform
 *     and the dotted variant ("Insurgentes.", "Indios Verdes L1.", …) is the
 *     northbound (Volta → Indios Verdes) platform. Each assignment was
 *     confirmed empirically via /static/schedule stop sequences (e.g.
 *     319cb7 → Ida seq 1; 244d59 → Volta seq 46; fa078b → Volta seq 1).
 *   - trip_headsign in this feed is the vendor's "Ida"/"Volta" pair
 *     (outbound/return), NOT a destination name. Ida = toward El Caminero,
 *     Volta = toward Indios Verdes; route_id suffix -1 = Ida, -2 = Volta.
 *
 * gtfsRouteIds per direction: all L1 route variants whose trips terminate at
 * that direction's cenefa terminal (their stop sequences are contiguous
 * sub-slices of the full sequence, so positional derivation stays valid).
 * Variants terminating mid-line (e.g. 19492 indios verdes → dr. gálvez,
 * 19997 indios verdes → col. del valle) and interlínea routes are excluded
 * until they are curated as their own services.
 */
export const CENEFAS: CenefaDataset = {
  version: '2026-06-11',
  lines: [
    {
      line: '1',
      services: [
        {
          id: 'L1-regular',
          type: 'regular',
          lines: ['1'],
          directions: [
            {
              destination: 'Indios Verdes',
              // 19500 = L01a07-2 el caminero - indios verdes (full line)
              // 19491 = L01a01-2 dr. gálvez - indios verdes
              // 19493 = L01a02-2 insurgentes - indios verdes
              gtfsRouteIds: ['19500', '19491', '19493'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'fa0791', name: 'El Caminero', pictogram: 'el-caminero' },
                { stopId: 'fa0793', name: 'La Joya', pictogram: 'la-joya' },
                { stopId: 'fa0799', name: 'Santa Úrsula', pictogram: 'santa-ursula' },
                { stopId: 'fa0797', name: 'Fuentes Brotantes', pictogram: 'fuentes-brotantes' },
                { stopId: 'fa079c', name: 'Ayuntamiento', pictogram: 'ayuntamiento' },
                { stopId: 'fa079f', name: 'Corregidora', pictogram: 'corregidora' },
                { stopId: 'fa07a4', name: 'Villa Olímpica', pictogram: 'villa-olimpica' },
                { stopId: 'fa07a5', name: 'Perisur', pictogram: 'perisur' },
                { stopId: 'fa07a7', name: 'C.C.U.', pictogram: 'ccu' },
                { stopId: 'fa07ac', name: 'Ciudad Universitaria', pictogram: 'ciudad-universitaria' },
                { stopId: '1d6ab9', name: 'Doctor Gálvez', pictogram: 'doctor-galvez' },
                { stopId: 'fa07a8', name: 'La Bombilla', pictogram: 'la-bombilla' },
                { stopId: 'fa07a6', name: 'Altavista', pictogram: 'altavista' },
                { stopId: 'fa07a3', name: 'Olivo', pictogram: 'olivo' },
                { stopId: 'fa07a2', name: 'Francia', pictogram: 'francia' },
                { stopId: 'fa07a1', name: 'José María Velasco', pictogram: 'jose-maria-velasco' },
                { stopId: 'fa07a0', name: 'Teatro Insurgentes', pictogram: 'teatro-insurgentes' },
                { stopId: 'fa079e', name: 'Río Churubusco', pictogram: 'rio-churubusco' },
                { stopId: '09619f', name: 'Félix Cuevas', pictogram: 'felix-cuevas' },
                { stopId: 'fa079b', name: 'Parque Hundido', pictogram: 'parque-hundido' },
                { stopId: 'fa079a', name: 'Ciudad de los Deportes', pictogram: 'ciudad-de-los-deportes' },
                { stopId: 'fa0798', name: 'Colonia del Valle', pictogram: 'colonia-del-valle' },
                { stopId: 'fa0796', name: 'Nápoles', pictogram: 'napoles' },
                { stopId: 'fa0795', name: 'Polifórum', pictogram: 'poliforum' },
                { stopId: 'fa0794', name: 'La Piedad', pictogram: 'la-piedad' },
                { stopId: 'fa0792', name: 'Nuevo León', pictogram: 'nuevo-leon' },
                { stopId: 'fa0790', name: 'Chilpancingo', pictogram: 'chilpancingo' },
                { stopId: 'fa078f', name: 'Campeche', pictogram: 'campeche' },
                { stopId: 'fa078e', name: 'Sonora', pictogram: 'sonora' },
                { stopId: 'fa078d', name: 'Álvaro Obregón', pictogram: 'alvaro-obregon' },
                { stopId: 'fa078c', name: 'Durango', pictogram: 'durango' },
                { stopId: 'fa078b', name: 'Insurgentes', pictogram: 'insurgentes' },
                { stopId: 'fa0789', name: 'Hamburgo', pictogram: 'hamburgo' },
                { stopId: 'fa0788', name: 'Reforma', pictogram: 'reforma' },
                { stopId: 'fa0787', name: 'Plaza de la República', pictogram: 'plaza-de-la-republica' },
                { stopId: 'fa0786', name: 'Revolución', pictogram: 'revolucion' },
                { stopId: 'fa0785', name: 'El Chopo', pictogram: 'el-chopo' },
                { stopId: 'fa0784', name: 'Buenavista', pictogram: 'buenavista' },
                { stopId: 'fa0783', name: 'Manuel González', pictogram: 'manuel-gonzalez' },
                { stopId: 'fa0782', name: 'San Simón', pictogram: 'san-simon' },
                { stopId: 'fa0781', name: 'Circuito', pictogram: 'circuito' },
                { stopId: 'e88c44', name: 'La Raza', pictogram: 'la-raza' },
                { stopId: '05c635', name: 'Potrero', pictogram: 'potrero' },
                { stopId: '952042', name: 'Euzkaro', pictogram: 'euzkaro' },
                { stopId: '05c62a', name: 'Deportivo 18 de Marzo', pictogram: 'deportivo-18-de-marzo' },
                { stopId: '244d59', name: 'Indios Verdes', pictogram: 'indios-verdes' },
              ],
            },
            {
              destination: 'El Caminero',
              // 19499 = L01a07-1 indios verdes - el caminero (full line)
              // 19497 = L01a03-1 buenavista - el caminero
              // 26885 = L01a53-1 colonia del valle - el caminero
              // 26888 = L01a54-1 ciudad universitaria - el caminero
              gtfsRouteIds: ['19499', '19497', '26885', '26888'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: '319cb7', name: 'Indios Verdes', pictogram: 'indios-verdes' },
                { stopId: 'fa07aa', name: 'Deportivo 18 de Marzo', pictogram: 'deportivo-18-de-marzo' },
                { stopId: 'fa07ab', name: 'Euzkaro', pictogram: 'euzkaro' },
                { stopId: 'fa077f', name: 'Potrero', pictogram: 'potrero' },
                { stopId: 'e88c44', name: 'La Raza', pictogram: 'la-raza' },
                { stopId: 'fa0781', name: 'Circuito', pictogram: 'circuito' },
                { stopId: 'fa0782', name: 'San Simón', pictogram: 'san-simon' },
                { stopId: 'fa0783', name: 'Manuel González', pictogram: 'manuel-gonzalez' },
                { stopId: 'fa0784', name: 'Buenavista', pictogram: 'buenavista' },
                { stopId: 'fa0785', name: 'El Chopo', pictogram: 'el-chopo' },
                { stopId: 'fa0786', name: 'Revolución', pictogram: 'revolucion' },
                { stopId: 'fa0787', name: 'Plaza de la República', pictogram: 'plaza-de-la-republica' },
                { stopId: 'fa0788', name: 'Reforma', pictogram: 'reforma' },
                { stopId: 'fa0789', name: 'Hamburgo', pictogram: 'hamburgo' },
                { stopId: 'fa078a', name: 'Insurgentes', pictogram: 'insurgentes' },
                { stopId: 'fa078c', name: 'Durango', pictogram: 'durango' },
                { stopId: 'fa078d', name: 'Álvaro Obregón', pictogram: 'alvaro-obregon' },
                { stopId: 'fa078e', name: 'Sonora', pictogram: 'sonora' },
                { stopId: 'fa078f', name: 'Campeche', pictogram: 'campeche' },
                { stopId: 'fa0790', name: 'Chilpancingo', pictogram: 'chilpancingo' },
                { stopId: 'fa0792', name: 'Nuevo León', pictogram: 'nuevo-leon' },
                { stopId: 'fa0794', name: 'La Piedad', pictogram: 'la-piedad' },
                { stopId: 'fa0795', name: 'Polifórum', pictogram: 'poliforum' },
                { stopId: 'fa0796', name: 'Nápoles', pictogram: 'napoles' },
                { stopId: 'fa0798', name: 'Colonia del Valle', pictogram: 'colonia-del-valle' },
                { stopId: 'fa079a', name: 'Ciudad de los Deportes', pictogram: 'ciudad-de-los-deportes' },
                { stopId: 'fa079b', name: 'Parque Hundido', pictogram: 'parque-hundido' },
                { stopId: '09619f', name: 'Félix Cuevas', pictogram: 'felix-cuevas' },
                { stopId: 'fa079e', name: 'Río Churubusco', pictogram: 'rio-churubusco' },
                { stopId: 'fa07a0', name: 'Teatro Insurgentes', pictogram: 'teatro-insurgentes' },
                { stopId: 'fa07a1', name: 'José María Velasco', pictogram: 'jose-maria-velasco' },
                { stopId: 'fa07a2', name: 'Francia', pictogram: 'francia' },
                { stopId: 'fa07a3', name: 'Olivo', pictogram: 'olivo' },
                { stopId: 'fa07a6', name: 'Altavista', pictogram: 'altavista' },
                { stopId: 'fa07a8', name: 'La Bombilla', pictogram: 'la-bombilla' },
                { stopId: '1d6ab9', name: 'Doctor Gálvez', pictogram: 'doctor-galvez' },
                { stopId: 'fa07ac', name: 'Ciudad Universitaria', pictogram: 'ciudad-universitaria' },
                { stopId: 'fa07a7', name: 'C.C.U.', pictogram: 'ccu' },
                { stopId: 'fa07a5', name: 'Perisur', pictogram: 'perisur' },
                { stopId: 'fa07a4', name: 'Villa Olímpica', pictogram: 'villa-olimpica' },
                { stopId: 'fa079f', name: 'Corregidora', pictogram: 'corregidora' },
                { stopId: 'fa079c', name: 'Ayuntamiento', pictogram: 'ayuntamiento' },
                { stopId: 'fa0797', name: 'Fuentes Brotantes', pictogram: 'fuentes-brotantes' },
                { stopId: 'fa0799', name: 'Santa Úrsula', pictogram: 'santa-ursula' },
                { stopId: 'fa0793', name: 'La Joya', pictogram: 'la-joya' },
                { stopId: 'fa0791', name: 'El Caminero', pictogram: 'el-caminero' },
              ],
            },
          ],
          // App LineColors.line1 — PANTONE 1807 C (Sources/Theme/DesignTokens.swift).
          style: { colors: ['#A4343A'] },
        },
      ],
    },
  ],
};
