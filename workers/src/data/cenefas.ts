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
 *     319cb7 → Ida seq 1; 244d59 → Volta seq 46; fa078b → Volta seq 1)
 *     (stop_sequence in the GTFS trip, not array index).
 *   - trip_headsign in this feed is the vendor's "Ida"/"Volta" pair
 *     (outbound/return), NOT a destination name. Ida = toward El Caminero,
 *     Volta = toward Indios Verdes; route_id suffix -1 = Ida, -2 = Volta.
 *
 * gtfsRouteIds per direction: all L1 route variants whose trips terminate at
 * that direction's cenefa terminal (their stop sequences are contiguous
 * sub-slices of the full sequence, so positional derivation stays valid).
 * Variants whose trips do NOT reach this direction's cenefa terminal
 * (short-turns that stop mid-line) are excluded (e.g. 19492 indios verdes →
 * dr. gálvez, 19997 indios verdes → col. del valle). Variants that start
 * mid-line but terminate at the cenefa terminal are included — their stop
 * sequence is a suffix of the full sequence, so positional derivation remains
 * valid. Interlínea routes are excluded until they are curated as their own
 * services.
 *
 * ── Líneas 2–7 (curated 2026-06-11 from the official ME_LX line maps; every
 * direction's stop order + platform-id assignment verified empirically via
 * /static/schedule stop sequences — the full-line trip of each direction
 * matches the arrays below position-for-position) ─────────────────────────
 *
 * Línea 2 — Eje 4 Sur (Tepalcates ↔ Tacubaya), ME_L2_2022.pdf.
 *   One-way couplet stations at both ends: Parque Lira, Río Frío and
 *   Gral. Antonio de León are Ida-only (→ Tacubaya); Antonio Maceo,
 *   Del Moral, Canal de San Juan and Nicolás Bravo are Volta-only
 *   (→ Tepalcates). All other stations share one stop both directions.
 *   "Rojo Gómez." (34b450) is the L21 interlínea berth, NOT an L2 platform
 *   (L21c21 rojo gómez ↔ dr. gálvez trips start/end there); L2 uses f8579f
 *   both ways. The L72 interlínea (curated below as
 *   L2L7-tacubaya-cuitlahuac) shares NO L2 platform: it uses its own
 *   Alameda Tacubaya (ba0966) and De la Salle L72 (0b47bb/f7f029) berths
 *   beside the L2 corridor — verified in stop_times 2026-06-11.
 *
 *   Vendor interlínea route families (GTFS color 42A76B), decoded from
 *   routes.txt + trips 2026-06-11: the prefix is "L<line><other line>" —
 *   L21c21 (19983/19984) = interlínea L2/L1 rojo gómez ↔ dr. gálvez;
 *   L31a31 (20295/20296) = interlínea L3/L1 indios verdes ↔ pueblo sta.
 *   cruz atoyac; L72h72/h73 (20263/20264, 20439/20440) = interlínea L7/L2
 *   alameda tacubaya ↔ parís / glorieta cuitláhuac. Only the L72 corridor
 *   is an official published service (servicioL2L7); L21/L31 remain
 *   uncurated.
 *
 * Línea 3 — Eje 1 Poniente (Tenayuca ↔ Pueblo Sta. Cruz Atoyac),
 * ME_L3_2022.pdf prints 38 stations, but current GTFS through-trips skip
 * La Raza and Buenavista in BOTH directions (36 stops/direction):
 *   - "La Raza L3" (542ae9) appears only as the terminus/origin of the
 *     L03d03 short-turns (19429/19430).
 *   - "Buenavista L3 Norte/Sur" (697b0c/f85805 — platform pair named with
 *     Norte/Sur suffixes instead of the dot convention) appear only as
 *     short-turn terminals (19455/26895 end at Norte; 19456 departs Sur).
 *   Both stations are therefore omitted from the arrays so positional
 *   derivation against live trips stays exact; re-add when the operator
 *   restores through service.
 *
 * Línea 4 — Centro Histórico (ME_Linea4C_BO_2024 map) is FOUR services, not
 * directions: Ruta Norte (Buenavista ↔ San Lázaro Pte, route e08), Ruta Sur
 * (Buenavista ↔ San Lázaro Ote, route e02), Ruta Pantitlán (Hidalgo ↔
 * Pantitlán, e04) and Ruta Alameda Oriente (Hidalgo ↔ Alameda Ote, e05),
 * plus the Ruta Aeropuerto curated as the fifth service (see its own
 * comment block below). Notes:
 *   - trip_headsign orientation is PER ROUTE: on e02/e08 Ida = eastbound,
 *     while on e04/e05 Ida = westbound (toward Hidalgo) — the eastbound
 *     Pantitlán/Alameda trips carry headsign "Volta".
 *   - e04/e05 share the Ruta Norte platforms from Bellas Artes east, start
 *     eastbound at the dedicated "Hidalgo L4 E4" berth (b51170), end
 *     westbound at "Hidalgo L4." (f857fe), and BYPASS San Lázaro station.
 *   - Ruta Sur one-way streets: Museo de la Ciudad / Pino Suárez /
 *     Las Cruces / La Merced / Mercado Sonora and Moctezuma are
 *     eastbound-only; 20 de Noviembre / Pino Suárez Sur / San Pablo /
 *     Mercado Sonora Sur and Hospital Balbuena are westbound-only.
 *   - "Calle 6" base (f857b5) is the westbound platform; "Calle 6 (ret)"
 *     (52920d) is the eastbound retorno platform.
 *
 * Línea 5 — Eje 3 Oriente (Río de los Remedios ↔ Preparatoria 1, 51
 * stations), ME_L5_2022.pdf. Platform pairs follow the L1 dot convention
 * (base = Ida → Preparatoria 1, dotted = Volta → Río de los Remedios)
 * except San Lázaro, which is a Norte/Sur-named pair: southbound trips use
 * "San Lázaro Sur L5" (f85760), northbound "San Lázaro Norte L5" (f8579c).
 *
 * Línea 6 — Eje 5 Norte (El Rosario ↔ Villa de Aragón), ME_Linea6_2026.pdf.
 *   La Villa is bidirectional, but Hospital Infantil La Villa and
 *   De los Misterios (L6 ids) are Ida-only (→ El Rosario). The eastern
 *   loop is a one-way couplet: 482 / 414 / 416 Oriente (dotted-only ids)
 *   are Volta-only (→ Villa de Aragón); Volcán de Fuego / A. Providencia /
 *   D. los Galeana / 416 Poniente are Ida-only.
 *
 * Línea 7 — Reforma double-decker (Indios Verdes ↔ Campo Marte),
 * ME_L7_2022.pdf. Nearly every station is a dot-convention platform pair
 * (base = Ida → Campo Marte, dotted = Volta → Indios Verdes). Deviations:
 *   - Glorieta Cuitláhuac is two physical stations southbound (Nte b315cb,
 *     then Sur b46d55); northbound uses the single dotted "Sur." (b315d3).
 *   - Gustavo A. Madero exists only as the dotted northbound stop (f857b3);
 *     southbound through-trips run Indios Verdes → De los Misterios direct
 *     (without stopping at Gustavo A. Madero).
 *   - The Hospital Infantil La Villa / De los Misterios couplet: southbound
 *     serves De los Misterios L7 (f857c1); Hospital Infantil L7 (f8578f) is
 *     only the origin/terminus of short-turn variants (19578/19579/19956),
 *     so northbound through-trips have 29 stops vs 30 southbound.
 *   - The GTFS also carries "Glorieta de Colón L7"/"." ids (f85793/f8583d)
 *     at the same coordinates as Amajac L7 — a renamed duplicate used by
 *     some La Diana short-turn variants; the cenefa prints AMAJAC and the
 *     full-line trips use the Amajac ids, so those are used here.
 *
 * ── SNAPSHOT REFRESH / RE-CURATION ────────────────────────────────────────
 * The stop-id validity of this dataset is tested against a PINNED snapshot
 * (`gtfs-stops-snapshot.json`) — CI does NOT track the live GTFS. To refresh
 * after an operator update:
 *   1. curl https://metrobus-status.starkji.workers.dev/static/stops \
 *        -o src/data/gtfs-stops-snapshot.json
 *   2. npx vitest run src/data/cenefas.test.ts
 *      Missing-stop failures list exactly which stations need re-curation
 *      against the official PDFs named per line above (ME_LX line maps).
 *   3. Re-verify the pin tests (station/service counts) and bump the
 *      dataset `version`.
 * Until that happens, an operator update surfaces at runtime as vehicles
 * matching nothing → scheduled fallback; for renamed stops, /arrivals
 * returns its empty-rows + warning contract (see handleArrivals).
 */
export const CENEFAS: CenefaDataset = {
  version: '2026-06-11c',
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
    {
      line: '2',
      services: [
        {
          id: 'L2-regular',
          type: 'regular',
          lines: ['2'],
          directions: [
            {
              destination: 'Tepalcates',
              // 19562 = L02c01-2 tacubaya - tepalcates (full line)
              // 19565 = L02c02-2 etiopía l3 - tepalcates (joins at Doctor Vértiz)
              // 19567 = L02c03-2 col. del valle - tepalcates
              gtfsRouteIds: ['19562', '19565', '19567'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'f857b2', name: 'Tacubaya', pictogram: 'tacubaya' },
                { stopId: 'f8578e', name: 'Antonio Maceo', pictogram: 'antonio-maceo' },
                { stopId: 'f85843', name: 'De la Salle', pictogram: 'de-la-salle' },
                { stopId: 'f857bd', name: 'Patriotismo', pictogram: 'patriotismo' },
                { stopId: 'f8584e', name: 'Escandón', pictogram: 'escandon' },
                { stopId: 'f857c8', name: 'Nuevo León', pictogram: 'nuevo-leon' },
                { stopId: 'f8575c', name: 'Viaducto', pictogram: 'viaducto' },
                { stopId: 'f857d3', name: 'Amores', pictogram: 'amores' },
                { stopId: 'f8577d', name: 'Etiopía', pictogram: 'etiopia' },
                { stopId: 'f857c2', name: 'Doctor Vértiz', pictogram: 'doctor-vertiz' },
                { stopId: 'f85851', name: 'Centro SCOP', pictogram: 'centro-scop' },
                { stopId: 'f85782', name: 'Álamos', pictogram: 'alamos' },
                { stopId: 'f857b1', name: 'Xola', pictogram: 'xola' },
                { stopId: 'f85809', name: 'Las Américas', pictogram: 'las-americas' },
                { stopId: 'f85812', name: 'Andrés Molina Enríquez', pictogram: 'andres-molina-enriquez' },
                { stopId: 'f85758', name: 'La Viga', pictogram: 'la-viga' },
                { stopId: 'f85779', name: 'Coyuya', pictogram: 'coyuya' },
                { stopId: 'f857be', name: 'Metro Coyuya', pictogram: 'metro-coyuya' },
                { stopId: 'f857df', name: 'Canela', pictogram: 'canela' },
                { stopId: 'f857b4', name: 'Tlacotal', pictogram: 'tlacotal' },
                { stopId: 'f8585d', name: 'Goma', pictogram: 'goma' },
                { stopId: 'f857ef', name: 'Iztacalco', pictogram: 'iztacalco' },
                { stopId: 'f85862', name: 'UPIICSA', pictogram: 'upiicsa' },
                { stopId: 'f857dc', name: 'El Rodeo', pictogram: 'el-rodeo' },
                { stopId: 'f8574c', name: 'Río Tecolutla', pictogram: 'rio-tecolutla' },
                { stopId: 'f85825', name: 'Río Mayo', pictogram: 'rio-mayo' },
                { stopId: 'f8579f', name: 'Rojo Gómez', pictogram: 'rojo-gomez' },
                { stopId: 'f857aa', name: 'Del Moral', pictogram: 'del-moral' },
                { stopId: 'f85762', name: 'Leyes de Reforma', pictogram: 'leyes-de-reforma' },
                { stopId: 'f85818', name: 'CCH Oriente', pictogram: 'cch-oriente' },
                { stopId: 'f857fa', name: 'Const. de Apatzingán', pictogram: 'const-de-apatzingan' },
                { stopId: 'f85791', name: 'Canal de San Juan', pictogram: 'canal-de-san-juan' },
                { stopId: 'f85846', name: 'Nicolás Bravo', pictogram: 'nicolas-bravo' },
                { stopId: 'f85822', name: 'Tepalcates', pictogram: 'tepalcates' },
              ],
            },
            {
              destination: 'Tacubaya',
              // 19563 = L02c01-1 tepalcates - tacubaya (full line)
              // 26891 = L02c50-1 río frío - tacubaya
              gtfsRouteIds: ['19563', '26891'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'f85822', name: 'Tepalcates', pictogram: 'tepalcates' },
                { stopId: 'f85749', name: 'Gral. Antonio de León', pictogram: 'gral-antonio-de-leon' },
                { stopId: 'f857fa', name: 'Const. de Apatzingán', pictogram: 'const-de-apatzingan' },
                { stopId: 'f85818', name: 'CCH Oriente', pictogram: 'cch-oriente' },
                { stopId: 'f85762', name: 'Leyes de Reforma', pictogram: 'leyes-de-reforma' },
                { stopId: 'f85854', name: 'Río Frío', pictogram: 'rio-frio' },
                { stopId: 'f8579f', name: 'Rojo Gómez', pictogram: 'rojo-gomez' },
                { stopId: 'f85825', name: 'Río Mayo', pictogram: 'rio-mayo' },
                { stopId: 'f8574c', name: 'Río Tecolutla', pictogram: 'rio-tecolutla' },
                { stopId: 'f857dc', name: 'El Rodeo', pictogram: 'el-rodeo' },
                { stopId: 'f85862', name: 'UPIICSA', pictogram: 'upiicsa' },
                { stopId: 'f857ef', name: 'Iztacalco', pictogram: 'iztacalco' },
                { stopId: 'f8585d', name: 'Goma', pictogram: 'goma' },
                { stopId: 'f857b4', name: 'Tlacotal', pictogram: 'tlacotal' },
                { stopId: 'f857df', name: 'Canela', pictogram: 'canela' },
                { stopId: 'f857be', name: 'Metro Coyuya', pictogram: 'metro-coyuya' },
                { stopId: 'f85779', name: 'Coyuya', pictogram: 'coyuya' },
                { stopId: 'f85758', name: 'La Viga', pictogram: 'la-viga' },
                { stopId: 'f85812', name: 'Andrés Molina Enríquez', pictogram: 'andres-molina-enriquez' },
                { stopId: 'f85809', name: 'Las Américas', pictogram: 'las-americas' },
                { stopId: 'f857b1', name: 'Xola', pictogram: 'xola' },
                { stopId: 'f85782', name: 'Álamos', pictogram: 'alamos' },
                { stopId: 'f85851', name: 'Centro SCOP', pictogram: 'centro-scop' },
                { stopId: 'f857c2', name: 'Doctor Vértiz', pictogram: 'doctor-vertiz' },
                { stopId: 'f8577d', name: 'Etiopía', pictogram: 'etiopia' },
                { stopId: 'f857d3', name: 'Amores', pictogram: 'amores' },
                { stopId: 'f8575c', name: 'Viaducto', pictogram: 'viaducto' },
                { stopId: 'f857c8', name: 'Nuevo León', pictogram: 'nuevo-leon' },
                { stopId: 'f8584e', name: 'Escandón', pictogram: 'escandon' },
                { stopId: 'f857bd', name: 'Patriotismo', pictogram: 'patriotismo' },
                { stopId: 'f85843', name: 'De la Salle', pictogram: 'de-la-salle' },
                { stopId: 'f857d6', name: 'Parque Lira', pictogram: 'parque-lira' },
                { stopId: 'f857b2', name: 'Tacubaya', pictogram: 'tacubaya' },
              ],
            },
          ],
          // App LineColors.line2 — PANTONE 2602 C (Sources/Theme/DesignTokens.swift).
          style: { colors: ['#87189D'] },
        },
        {
          // Interlínea L2/L7 — "Servicio Alameda Tacubaya – Glorieta
          // Cuitláhuac" (metrobus.cdmx.gob.mx/servicioL2L7 +
          // Mapa_Tacubaya_Paris.pdf): support service introduced during the
          // Metro L1 modernization, extending the original Alameda
          // Tacubaya – París route. From the dedicated Alameda Tacubaya
          // berth (ba0966, beside L2's Tacubaya terminal) it climbs the
          // Circuito Interior to Chapultepec and then runs the full L7
          // Reforma corridor to Glorieta Cuitláhuac.
          //
          // Platforms (verified in stop_times 2026-06-11): Alameda Tacubaya
          // and the "De la Salle L72(.)" berths (0b47bb/f7f029) are
          // exclusive to this service — no L2 platform is shared. From
          // Chapultepec onward every platform is shared with L7-regular
          // (dotted ids toward Glorieta Cuitláhuac = L7 northbound; base
          // ids on the return = L7 southbound). Deviations from L7-regular:
          //   - It calls at the "Glorieta de Colón L7(.)" ids
          //     (f8583d/f85793) instead of the Amajac ids — the same
          //     physical station, which both the L7 cenefa and the official
          //     extension map print as AMAJAC, so that name is used here.
          //   - Northbound it terminates at the dotted "Glorieta Cuitláhuac
          //     Sur." (b315d3, the L7 northbound platform); the return
          //     departs the base "Glorieta Cuitláhuac Sur" (b46d55).
          // Headsign quirk (per-route orientation, like L4 e04/e05): route
          // suffix -1 (20439, → Glorieta Cuitláhuac) carries headsign
          // "Volta" and -2 (20440/20263, → Alameda Tacubaya) carries "Ida".
          id: 'L2L7-tacubaya-cuitlahuac',
          type: 'interlinea',
          lines: ['2', '7'],
          directions: [
            {
              destination: 'Glorieta Cuitláhuac',
              // 20439 = L72h73-1 alameda tacubaya - glorieta cuitláhuac sur. (full)
              // 20264 = L72h72-1 alameda tacubaya - parís is excluded: it
              //   short-turns mid-line and never reaches the cenefa terminal.
              gtfsRouteIds: ['20439'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'ba0966', name: 'Alameda Tacubaya', pictogram: 'alameda-tacubaya' },
                { stopId: '0b47bb', name: 'De la Salle', pictogram: 'de-la-salle' },
                { stopId: 'f85775', name: 'Chapultepec', pictogram: 'chapultepec' },
                { stopId: 'f8582a', name: 'La Diana', pictogram: 'la-diana' },
                { stopId: 'f857a4', name: 'El Ángel', pictogram: 'el-angel' },
                { stopId: 'aefdfc', name: 'El Ahuehuete', pictogram: 'el-ahuehuete' },
                { stopId: 'f8578b', name: 'Hamburgo', pictogram: 'hamburgo' },
                { stopId: 'f85790', name: 'Reforma', pictogram: 'reforma' },
                { stopId: 'f85803', name: 'París', pictogram: 'paris' },
                { stopId: 'f8583d', name: 'Amajac', pictogram: 'amajac' },
                { stopId: 'f8580e', name: 'El Caballito', pictogram: 'el-caballito' },
                { stopId: 'f8578a', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f857ee', name: 'Glorieta Violeta', pictogram: 'glorieta-violeta' },
                { stopId: 'f85769', name: 'Garibaldi / Lagunilla', pictogram: 'garibaldi-lagunilla' },
                { stopId: 'b315d3', name: 'Glorieta Cuitláhuac', pictogram: 'glorieta-cuitlahuac' },
              ],
            },
            {
              destination: 'Alameda Tacubaya',
              // 20440 = L72h73-2 glorieta cuitláhuac sur - alameda tacubaya (full)
              // 20263 = L72h72-2 parís - alameda tacubaya: its sequence is a
              //   suffix of the full sequence and terminates at the cenefa
              //   terminal — included per the route-inclusion rule.
              gtfsRouteIds: ['20440', '20263'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'b46d55', name: 'Glorieta Cuitláhuac', pictogram: 'glorieta-cuitlahuac' },
                { stopId: 'f85800', name: 'Garibaldi / Lagunilla', pictogram: 'garibaldi-lagunilla' },
                { stopId: 'f8575e', name: 'Glorieta Violeta', pictogram: 'glorieta-violeta' },
                { stopId: 'f85833', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f85785', name: 'El Caballito', pictogram: 'el-caballito' },
                { stopId: 'f85793', name: 'Amajac', pictogram: 'amajac' },
                { stopId: 'f857c5', name: 'París', pictogram: 'paris' },
                { stopId: 'f85754', name: 'Reforma', pictogram: 'reforma' },
                { stopId: 'f85743', name: 'Hamburgo', pictogram: 'hamburgo' },
                { stopId: '749a60', name: 'El Ahuehuete', pictogram: 'el-ahuehuete' },
                { stopId: 'f85780', name: 'El Ángel', pictogram: 'el-angel' },
                { stopId: 'f8580a', name: 'La Diana', pictogram: 'la-diana' },
                { stopId: 'f85751', name: 'Chapultepec', pictogram: 'chapultepec' },
                { stopId: 'f7f029', name: 'De la Salle', pictogram: 'de-la-salle' },
                { stopId: 'ba0966', name: 'Alameda Tacubaya', pictogram: 'alameda-tacubaya' },
              ],
            },
          ],
          // Both lines' identities, L2 first then L7 — app LineColors.line2
          // + line7 (Sources/Theme/DesignTokens.swift).
          style: {
            colors: ['#87189D', '#046A38'],
            notes: 'Interlínea Alameda Tacubaya – Glorieta Cuitláhuac',
          },
        },
      ],
    },
    {
      line: '3',
      services: [
        {
          id: 'L3-regular',
          type: 'regular',
          lines: ['3'],
          directions: [
            {
              destination: 'Tenayuca',
              // 19460 = L03d05-2 pueblo sta. cruz atoyac - tenayuca (full line)
              // 19456 = L03d02-2 buenavista - tenayuca (departs Buenavista L3 Sur)
              // 19458 = L03d04-2 balderas - tenayuca
              // 19430 = L03d03-2 la raza - tenayuca
              gtfsRouteIds: ['19460', '19456', '19458', '19430'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: '697b28', name: 'Pueblo Sta. Cruz Atoyac', pictogram: 'pueblo-sta-cruz-atoyac' },
                { stopId: '697b27', name: 'Miguel Laurent', pictogram: 'miguel-laurent' },
                { stopId: '697b1a', name: 'División del Norte', pictogram: 'division-del-norte' },
                { stopId: '697b19', name: 'Eugenia', pictogram: 'eugenia' },
                { stopId: '697b18', name: 'Luz Saviñón', pictogram: 'luz-savinon' },
                { stopId: '697b17', name: 'Etiopía', pictogram: 'etiopia' },
                { stopId: '697b16', name: 'Obrero Mundial', pictogram: 'obrero-mundial' },
                { stopId: '697b15', name: 'Centro Médico', pictogram: 'centro-medico' },
                { stopId: '697b14', name: 'Doctor Márquez', pictogram: 'doctor-marquez' },
                { stopId: '697b13', name: 'Hospital General', pictogram: 'hospital-general' },
                { stopId: '697b12', name: 'Jardín Pushkin', pictogram: 'jardin-pushkin' },
                { stopId: '697b11', name: 'Cuauhtémoc', pictogram: 'cuauhtemoc' },
                { stopId: '697b10', name: 'Balderas', pictogram: 'balderas' },
                { stopId: '697b0f', name: 'Juárez', pictogram: 'juarez' },
                { stopId: '697b0e', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: '697b0d', name: 'Mina', pictogram: 'mina' },
                { stopId: '697b0b', name: 'Guerrero', pictogram: 'guerrero' },
                { stopId: '697b0a', name: 'R. Flores Magón', pictogram: 'r-flores-magon' },
                { stopId: '697b09', name: 'Tlatelolco', pictogram: 'tlatelolco' },
                { stopId: '697b08', name: 'Tolnáhuac', pictogram: 'tolnahuac' },
                { stopId: '697b07', name: 'Circuito', pictogram: 'circuito' },
                { stopId: '697b06', name: 'Hospital La Raza', pictogram: 'hospital-la-raza' },
                { stopId: 'f85753', name: 'Héroe de Nacozari', pictogram: 'heroe-de-nacozari' },
                { stopId: 'f857e3', name: 'Cuitláhuac', pictogram: 'cuitlahuac' },
                { stopId: 'f857e4', name: 'Coltongo', pictogram: 'coltongo' },
                { stopId: 'f857a9', name: 'M. de las Salinas', pictogram: 'm-de-las-salinas' },
                { stopId: 'f857e6', name: 'Poniente 128', pictogram: 'poniente-128' },
                { stopId: 'f8576f', name: 'Poniente 134', pictogram: 'poniente-134' },
                { stopId: 'f857f3', name: 'Montevideo', pictogram: 'montevideo' },
                { stopId: 'f857a1', name: 'Poniente 146', pictogram: 'poniente-146' },
                { stopId: 'f85839', name: 'La Patera', pictogram: 'la-patera' },
                { stopId: 'f857cc', name: 'Júpiter', pictogram: 'jupiter' },
                { stopId: '697b1e', name: 'Tres Anegas', pictogram: 'tres-anegas' },
                { stopId: '697b1d', name: 'Progreso Nacional', pictogram: 'progreso-nacional' },
                { stopId: '697b1c', name: 'S. J. de la Escalera', pictogram: 's-j-de-la-escalera' },
                { stopId: '697b1b', name: 'Tenayuca', pictogram: 'tenayuca' },
              ],
            },
            {
              destination: 'Pueblo Sta. Cruz Atoyac',
              // 19459 = L03d05-1 tenayuca - pueblo sta. cruz atoyac (full line)
              // 26899 = L03d53-1 júpiter - pueblo sta. cruz atoyac
              gtfsRouteIds: ['19459', '26899'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: '697b1b', name: 'Tenayuca', pictogram: 'tenayuca' },
                { stopId: '697b1c', name: 'S. J. de la Escalera', pictogram: 's-j-de-la-escalera' },
                { stopId: '697b1d', name: 'Progreso Nacional', pictogram: 'progreso-nacional' },
                { stopId: '697b1e', name: 'Tres Anegas', pictogram: 'tres-anegas' },
                { stopId: 'f857cc', name: 'Júpiter', pictogram: 'jupiter' },
                { stopId: 'f85839', name: 'La Patera', pictogram: 'la-patera' },
                { stopId: 'f857a1', name: 'Poniente 146', pictogram: 'poniente-146' },
                { stopId: 'f857f3', name: 'Montevideo', pictogram: 'montevideo' },
                { stopId: 'f8576f', name: 'Poniente 134', pictogram: 'poniente-134' },
                { stopId: 'f857e6', name: 'Poniente 128', pictogram: 'poniente-128' },
                { stopId: 'f857a9', name: 'M. de las Salinas', pictogram: 'm-de-las-salinas' },
                { stopId: 'f857e4', name: 'Coltongo', pictogram: 'coltongo' },
                { stopId: 'f857e3', name: 'Cuitláhuac', pictogram: 'cuitlahuac' },
                { stopId: 'f85753', name: 'Héroe de Nacozari', pictogram: 'heroe-de-nacozari' },
                { stopId: '697b06', name: 'Hospital La Raza', pictogram: 'hospital-la-raza' },
                { stopId: '697b07', name: 'Circuito', pictogram: 'circuito' },
                { stopId: '697b08', name: 'Tolnáhuac', pictogram: 'tolnahuac' },
                { stopId: '697b09', name: 'Tlatelolco', pictogram: 'tlatelolco' },
                { stopId: '697b0a', name: 'R. Flores Magón', pictogram: 'r-flores-magon' },
                { stopId: '697b0b', name: 'Guerrero', pictogram: 'guerrero' },
                { stopId: '697b0d', name: 'Mina', pictogram: 'mina' },
                { stopId: '697b0e', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: '697b0f', name: 'Juárez', pictogram: 'juarez' },
                { stopId: '697b10', name: 'Balderas', pictogram: 'balderas' },
                { stopId: '697b11', name: 'Cuauhtémoc', pictogram: 'cuauhtemoc' },
                { stopId: '697b12', name: 'Jardín Pushkin', pictogram: 'jardin-pushkin' },
                { stopId: '697b13', name: 'Hospital General', pictogram: 'hospital-general' },
                { stopId: '697b14', name: 'Doctor Márquez', pictogram: 'doctor-marquez' },
                { stopId: '697b15', name: 'Centro Médico', pictogram: 'centro-medico' },
                { stopId: '697b16', name: 'Obrero Mundial', pictogram: 'obrero-mundial' },
                { stopId: '697b17', name: 'Etiopía', pictogram: 'etiopia' },
                { stopId: '697b18', name: 'Luz Saviñón', pictogram: 'luz-savinon' },
                { stopId: '697b19', name: 'Eugenia', pictogram: 'eugenia' },
                { stopId: '697b1a', name: 'División del Norte', pictogram: 'division-del-norte' },
                { stopId: '697b27', name: 'Miguel Laurent', pictogram: 'miguel-laurent' },
                { stopId: '697b28', name: 'Pueblo Sta. Cruz Atoyac', pictogram: 'pueblo-sta-cruz-atoyac' },
              ],
            },
          ],
          // App LineColors.line3 — PANTONE 377 C (Sources/Theme/DesignTokens.swift).
          style: { colors: ['#7A9A01'] },
        },
      ],
    },
    {
      line: '4',
      services: [
        {
          id: 'L4-ruta-norte',
          type: 'regular',
          lines: ['4'],
          directions: [
            {
              destination: 'Buenavista',
              // 19518 = L04e08-2 san lázaro pte - buenavista
              gtfsRouteIds: ['19518'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'f857d8', name: 'San Lázaro', pictogram: 'san-lazaro' },
                { stopId: 'f8577e', name: 'Archivo General de la Nación', pictogram: 'archivo-general-de-la-nacion' },
                { stopId: 'f85804', name: 'Morelos', pictogram: 'morelos' },
                { stopId: 'f85819', name: 'Ferrocarril de Cintura', pictogram: 'ferrocarril-de-cintura' },
                { stopId: 'f85810', name: 'Mixcalco', pictogram: 'mixcalco' },
                { stopId: 'f85771', name: 'Teatro del Pueblo', pictogram: 'teatro-del-pueblo' },
                { stopId: 'f857c0', name: 'República de Argentina', pictogram: 'republica-de-argentina' },
                { stopId: 'f85829', name: 'República de Chile', pictogram: 'republica-de-chile' },
                { stopId: 'f8578d', name: 'Teatro Blanquita', pictogram: 'teatro-blanquita' },
                { stopId: 'f85837', name: 'Bellas Artes', pictogram: 'bellas-artes' },
                { stopId: 'f857fe', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f85756', name: 'Museo San Carlos', pictogram: 'museo-san-carlos' },
                { stopId: 'f857fc', name: 'México Tenochtitlan', pictogram: 'mexico-tenochtitlan' },
                { stopId: 'f8574b', name: 'Alcaldía Cuauhtémoc', pictogram: 'alcaldia-cuauhtemoc' },
                { stopId: '9c45f7', name: 'Buenavista', pictogram: 'buenavista' },
              ],
            },
            {
              destination: 'San Lázaro',
              // 19517 = L04e08-1 buenavista - san lázaro pte
              gtfsRouteIds: ['19517'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'f85824', name: 'Buenavista', pictogram: 'buenavista' },
                { stopId: 'f85848', name: 'Alcaldía Cuauhtémoc', pictogram: 'alcaldia-cuauhtemoc' },
                { stopId: 'f857b7', name: 'México Tenochtitlan', pictogram: 'mexico-tenochtitlan' },
                { stopId: 'f8582f', name: 'Museo San Carlos', pictogram: 'museo-san-carlos' },
                { stopId: 'f85817', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f85815', name: 'Bellas Artes', pictogram: 'bellas-artes' },
                { stopId: 'f85842', name: 'Teatro Blanquita', pictogram: 'teatro-blanquita' },
                { stopId: 'f85774', name: 'República de Chile', pictogram: 'republica-de-chile' },
                { stopId: 'f857de', name: 'República de Argentina', pictogram: 'republica-de-argentina' },
                { stopId: 'f857b9', name: 'Teatro del Pueblo', pictogram: 'teatro-del-pueblo' },
                { stopId: 'f8577c', name: 'Mixcalco', pictogram: 'mixcalco' },
                { stopId: 'f85763', name: 'Ferrocarril de Cintura', pictogram: 'ferrocarril-de-cintura' },
                { stopId: 'f85823', name: 'Morelos', pictogram: 'morelos' },
                { stopId: 'f85845', name: 'Archivo General de la Nación', pictogram: 'archivo-general-de-la-nacion' },
                { stopId: 'f857d8', name: 'San Lázaro', pictogram: 'san-lazaro' },
              ],
            },
          ],
          // App LineColors.line4 — PANTONE Orange 021 C (Sources/Theme/DesignTokens.swift).
          style: { colors: ['#FE5000'], notes: 'Ruta Norte' },
        },
        {
          id: 'L4-ruta-sur',
          type: 'regular',
          lines: ['4'],
          directions: [
            {
              destination: 'Buenavista',
              // 19516 = L04e02-2 san lázaro ote - buenavista
              gtfsRouteIds: ['19516'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'f85863', name: 'San Lázaro', pictogram: 'san-lazaro' },
                { stopId: 'f85852', name: 'Ing. Eduardo Molina', pictogram: 'ing-eduardo-molina' },
                { stopId: 'f8582e', name: 'Hospital Balbuena', pictogram: 'hospital-balbuena' },
                { stopId: 'f85847', name: 'Cecilio Robelo', pictogram: 'cecilio-robelo' },
                { stopId: 'f85855', name: 'Mercado Sonora Sur', pictogram: 'mercado-sonora-sur' },
                { stopId: 'b50ecd', name: 'San Pablo', pictogram: 'san-pablo' },
                { stopId: '80cd40', name: 'Pino Suárez Sur', pictogram: 'pino-suarez-sur' },
                { stopId: '0c8439', name: '20 de Noviembre', pictogram: '20-de-noviembre' },
                { stopId: 'f85798', name: 'Isabel la Católica', pictogram: 'isabel-la-catolica' },
                { stopId: 'f85745', name: 'El Salvador', pictogram: 'el-salvador' },
                { stopId: 'f857d5', name: 'Eje Central', pictogram: 'eje-central' },
                { stopId: 'f85850', name: 'Mercados de San Juan', pictogram: 'mercados-de-san-juan' },
                { stopId: 'f8583a', name: 'Juárez', pictogram: 'juarez' },
                { stopId: 'f857f0', name: 'Vocacional 5', pictogram: 'vocacional-5' },
                { stopId: '80cc0b', name: 'Defensoría Pública', pictogram: 'defensoria-publica' },
                { stopId: 'aefe05', name: 'Amajac', pictogram: 'amajac' },
                { stopId: 'f857ac', name: 'Plaza de la República', pictogram: 'plaza-de-la-republica' },
                { stopId: 'f857fc', name: 'México Tenochtitlan', pictogram: 'mexico-tenochtitlan' },
                { stopId: 'f8574b', name: 'Alcaldía Cuauhtémoc', pictogram: 'alcaldia-cuauhtemoc' },
                { stopId: '9c45f7', name: 'Buenavista', pictogram: 'buenavista' },
              ],
            },
            {
              destination: 'San Lázaro',
              // 19515 = L04e02-1 buenavista - san lázaro ote
              gtfsRouteIds: ['19515'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'f85824', name: 'Buenavista', pictogram: 'buenavista' },
                { stopId: 'f85848', name: 'Alcaldía Cuauhtémoc', pictogram: 'alcaldia-cuauhtemoc' },
                { stopId: 'f857b7', name: 'México Tenochtitlan', pictogram: 'mexico-tenochtitlan' },
                { stopId: 'f85788', name: 'Plaza de la República', pictogram: 'plaza-de-la-republica' },
                { stopId: '605459', name: 'Amajac', pictogram: 'amajac' },
                { stopId: 'f85853', name: 'Defensoría Pública', pictogram: 'defensoria-publica' },
                { stopId: 'f8577a', name: 'Vocacional 5', pictogram: 'vocacional-5' },
                { stopId: 'f857a8', name: 'Juárez', pictogram: 'juarez' },
                { stopId: 'f857a6', name: 'Mercados de San Juan', pictogram: 'mercados-de-san-juan' },
                { stopId: 'f8585b', name: 'Eje Central', pictogram: 'eje-central' },
                { stopId: 'f857e0', name: 'El Salvador', pictogram: 'el-salvador' },
                { stopId: 'f857bc', name: 'Isabel la Católica', pictogram: 'isabel-la-catolica' },
                { stopId: 'f857a3', name: 'Museo de la Ciudad', pictogram: 'museo-de-la-ciudad' },
                { stopId: 'f8577f', name: 'Pino Suárez', pictogram: 'pino-suarez' },
                { stopId: 'f85766', name: 'Las Cruces', pictogram: 'las-cruces' },
                { stopId: 'f85826', name: 'La Merced', pictogram: 'la-merced' },
                { stopId: 'f857f2', name: 'Mercado Sonora', pictogram: 'mercado-sonora' },
                { stopId: 'f857b6', name: 'Cecilio Robelo', pictogram: 'cecilio-robelo' },
                { stopId: 'f85852', name: 'Ing. Eduardo Molina', pictogram: 'ing-eduardo-molina' },
                { stopId: 'f8575d', name: 'Moctezuma', pictogram: 'moctezuma' },
                { stopId: 'f85863', name: 'San Lázaro', pictogram: 'san-lazaro' },
              ],
            },
          ],
          style: { colors: ['#FE5000'], notes: 'Ruta Sur' },
        },
        {
          id: 'L4-pantitlan',
          type: 'regular',
          lines: ['4'],
          directions: [
            {
              destination: 'Pantitlán',
              // 19520 = L04e04-2 hidalgo - pantitlán (Volta = eastbound on this route)
              gtfsRouteIds: ['19520'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'b51170', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f85815', name: 'Bellas Artes', pictogram: 'bellas-artes' },
                { stopId: 'f85842', name: 'Teatro Blanquita', pictogram: 'teatro-blanquita' },
                { stopId: 'f85774', name: 'República de Chile', pictogram: 'republica-de-chile' },
                { stopId: 'f857de', name: 'República de Argentina', pictogram: 'republica-de-argentina' },
                { stopId: 'f857b9', name: 'Teatro del Pueblo', pictogram: 'teatro-del-pueblo' },
                { stopId: 'f8577c', name: 'Mixcalco', pictogram: 'mixcalco' },
                { stopId: 'f85763', name: 'Ferrocarril de Cintura', pictogram: 'ferrocarril-de-cintura' },
                { stopId: 'f85823', name: 'Morelos', pictogram: 'morelos' },
                { stopId: 'f85845', name: 'Archivo General de la Nación', pictogram: 'archivo-general-de-la-nacion' },
                { stopId: 'f85830', name: 'Pantitlán', pictogram: 'pantitlan' },
              ],
            },
            {
              destination: 'Hidalgo',
              // 19519 = L04e04-1 pantitlán - hidalgo
              gtfsRouteIds: ['19519'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'e9eed2', name: 'Pantitlán', pictogram: 'pantitlan' },
                { stopId: 'f8577e', name: 'Archivo General de la Nación', pictogram: 'archivo-general-de-la-nacion' },
                { stopId: 'f85804', name: 'Morelos', pictogram: 'morelos' },
                { stopId: 'f85819', name: 'Ferrocarril de Cintura', pictogram: 'ferrocarril-de-cintura' },
                { stopId: 'f85810', name: 'Mixcalco', pictogram: 'mixcalco' },
                { stopId: 'f85771', name: 'Teatro del Pueblo', pictogram: 'teatro-del-pueblo' },
                { stopId: 'f857c0', name: 'República de Argentina', pictogram: 'republica-de-argentina' },
                { stopId: 'f85829', name: 'República de Chile', pictogram: 'republica-de-chile' },
                { stopId: 'f8578d', name: 'Teatro Blanquita', pictogram: 'teatro-blanquita' },
                { stopId: 'f85837', name: 'Bellas Artes', pictogram: 'bellas-artes' },
                { stopId: 'f857fe', name: 'Hidalgo', pictogram: 'hidalgo' },
              ],
            },
          ],
          style: { colors: ['#FE5000'], notes: 'Ruta Pantitlán' },
        },
        {
          id: 'L4-alameda-oriente',
          type: 'regular',
          lines: ['4'],
          directions: [
            {
              destination: 'Alameda Oriente',
              // 19523 = L04e05-2 hidalgo - alameda ote (Volta = eastbound on this route)
              gtfsRouteIds: ['19523'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'b51170', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f85815', name: 'Bellas Artes', pictogram: 'bellas-artes' },
                { stopId: 'f85842', name: 'Teatro Blanquita', pictogram: 'teatro-blanquita' },
                { stopId: 'f85774', name: 'República de Chile', pictogram: 'republica-de-chile' },
                { stopId: 'f857de', name: 'República de Argentina', pictogram: 'republica-de-argentina' },
                { stopId: 'f857b9', name: 'Teatro del Pueblo', pictogram: 'teatro-del-pueblo' },
                { stopId: 'f8577c', name: 'Mixcalco', pictogram: 'mixcalco' },
                { stopId: 'f85763', name: 'Ferrocarril de Cintura', pictogram: 'ferrocarril-de-cintura' },
                { stopId: 'f85823', name: 'Morelos', pictogram: 'morelos' },
                { stopId: 'f85845', name: 'Archivo General de la Nación', pictogram: 'archivo-general-de-la-nacion' },
                { stopId: 'f85830', name: 'Pantitlán', pictogram: 'pantitlan' },
                { stopId: '52920d', name: 'Calle 6', pictogram: 'calle-6' },
                { stopId: 'f8576d', name: 'Alameda Oriente', pictogram: 'alameda-oriente' },
              ],
            },
            {
              destination: 'Hidalgo',
              // 19522 = L04e05-1 alameda ote - hidalgo
              gtfsRouteIds: ['19522'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'f8576d', name: 'Alameda Oriente', pictogram: 'alameda-oriente' },
                { stopId: 'f857b5', name: 'Calle 6', pictogram: 'calle-6' },
                { stopId: 'e9eed2', name: 'Pantitlán', pictogram: 'pantitlan' },
                { stopId: 'f8577e', name: 'Archivo General de la Nación', pictogram: 'archivo-general-de-la-nacion' },
                { stopId: 'f85804', name: 'Morelos', pictogram: 'morelos' },
                { stopId: 'f85819', name: 'Ferrocarril de Cintura', pictogram: 'ferrocarril-de-cintura' },
                { stopId: 'f85810', name: 'Mixcalco', pictogram: 'mixcalco' },
                { stopId: 'f85771', name: 'Teatro del Pueblo', pictogram: 'teatro-del-pueblo' },
                { stopId: 'f857c0', name: 'República de Argentina', pictogram: 'republica-de-argentina' },
                { stopId: 'f85829', name: 'República de Chile', pictogram: 'republica-de-chile' },
                { stopId: 'f8578d', name: 'Teatro Blanquita', pictogram: 'teatro-blanquita' },
                { stopId: 'f85837', name: 'Bellas Artes', pictogram: 'bellas-artes' },
                { stopId: 'f857fe', name: 'Hidalgo', pictogram: 'hidalgo' },
              ],
            },
          ],
          style: { colors: ['#FE5000'], notes: 'Ruta Alameda Oriente' },
        },
        {
          // Ruta Aeropuerto — official "Ruta Amajac - Aeropuerto T1 Y T2",
          // aka Ruta Quetzalcóatl (metrobus.cdmx.gob.mx/ruta-aeropuerto):
          // dedicated electric buses from Amajac on Paseo de la Reforma to
          // AICM. Placed under line '4' because it IS an L4 service
          // operationally: vendor route ids L04e10/e11, GTFS lineRoutes
          // maps 27054–27057 to line "4", and the official page presents it
          // as part of Línea 4 — so lines: ['4'] and the app's L4 identity
          // #FE5000 (DesignTokens even names line4 "Buenavista-Aeropuerto").
          //
          // Trip patterns verified in stop_times 2026-06-11:
          //   - L04e10 (27054 → AICM "Ida" / 27055 → Amajac "Volta"),
          //     ~453 trips/day each — the published Amajac ↔ AICM service
          //     modeled here.
          //   - L04e11 (27056/27057, ~25/28 trips/day) is a limited-hour
          //     Buenavista extension. EXCLUDED: its sequences extend BEYOND
          //     the cenefa arrays (4 extra stops Buenavista ↔ Plaza de la
          //     República), i.e. they are super-sequences, not contiguous
          //     sub-slices, so positional derivation cannot place their
          //     pre-Amajac portion (and 27057 also skips the ef2555 berth).
          //   - T1/T2 are NOT branches: outbound trips end at Terminal 1;
          //     the return serves the two Terminal 2 berths (ef2555 drop-off
          //     then f857c3, both printed TERMINAL 2) right after departing
          //     T1, then heads back to the city — one service, two
          //     directions, no extra branching needed.
          // Corridor sharing: outbound equals L4 Ruta Sur eastbound from
          // Amajac (605459 …) plus the airport leg; the return runs the
          // Ruta Sur westbound couplet but enters the city via "San Lázaro
          // L4 Pte" (f857d8, the Ruta Norte platform) instead of Ote.
          id: 'L4-aeropuerto',
          type: 'aeropuerto',
          lines: ['4'],
          directions: [
            {
              destination: 'Amajac',
              // 27055 = L04e10-2 aicm - amajac
              gtfsRouteIds: ['27055'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'f85770', name: 'Aeropuerto Terminal 1', pictogram: 'aeropuerto-terminal-1' },
                { stopId: 'ef2555', name: 'Aeropuerto Terminal 2', pictogram: 'aeropuerto-terminal-2' },
                { stopId: 'f857c3', name: 'Aeropuerto Terminal 2', pictogram: 'aeropuerto-terminal-2' },
                { stopId: 'f857d8', name: 'San Lázaro', pictogram: 'san-lazaro' },
                { stopId: 'f85852', name: 'Ing. Eduardo Molina', pictogram: 'ing-eduardo-molina' },
                { stopId: 'f8582e', name: 'Hospital Balbuena', pictogram: 'hospital-balbuena' },
                { stopId: 'f85847', name: 'Cecilio Robelo', pictogram: 'cecilio-robelo' },
                { stopId: 'f85855', name: 'Mercado Sonora Sur', pictogram: 'mercado-sonora-sur' },
                { stopId: 'b50ecd', name: 'San Pablo', pictogram: 'san-pablo' },
                { stopId: '80cd40', name: 'Pino Suárez Sur', pictogram: 'pino-suarez-sur' },
                { stopId: '0c8439', name: '20 de Noviembre', pictogram: '20-de-noviembre' },
                { stopId: 'f85798', name: 'Isabel la Católica', pictogram: 'isabel-la-catolica' },
                { stopId: 'f85745', name: 'El Salvador', pictogram: 'el-salvador' },
                { stopId: 'f857d5', name: 'Eje Central', pictogram: 'eje-central' },
                { stopId: 'f85850', name: 'Mercados de San Juan', pictogram: 'mercados-de-san-juan' },
                { stopId: 'f8583a', name: 'Juárez', pictogram: 'juarez' },
                { stopId: 'f857f0', name: 'Vocacional 5', pictogram: 'vocacional-5' },
                { stopId: '80cc0b', name: 'Defensoría Pública', pictogram: 'defensoria-publica' },
                { stopId: 'aefe05', name: 'Amajac', pictogram: 'amajac' },
              ],
            },
            {
              destination: 'Aeropuerto T1 y T2',
              // 27054 = L04e10-1 amajac - aicm
              gtfsRouteIds: ['27054'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: '605459', name: 'Amajac', pictogram: 'amajac' },
                { stopId: 'f85853', name: 'Defensoría Pública', pictogram: 'defensoria-publica' },
                { stopId: 'f8577a', name: 'Vocacional 5', pictogram: 'vocacional-5' },
                { stopId: 'f857a8', name: 'Juárez', pictogram: 'juarez' },
                { stopId: 'f857a6', name: 'Mercados de San Juan', pictogram: 'mercados-de-san-juan' },
                { stopId: 'f8585b', name: 'Eje Central', pictogram: 'eje-central' },
                { stopId: 'f857e0', name: 'El Salvador', pictogram: 'el-salvador' },
                { stopId: 'f857bc', name: 'Isabel la Católica', pictogram: 'isabel-la-catolica' },
                { stopId: 'f857a3', name: 'Museo de la Ciudad', pictogram: 'museo-de-la-ciudad' },
                { stopId: 'f8577f', name: 'Pino Suárez', pictogram: 'pino-suarez' },
                { stopId: 'f85766', name: 'Las Cruces', pictogram: 'las-cruces' },
                { stopId: 'f85826', name: 'La Merced', pictogram: 'la-merced' },
                { stopId: 'f857f2', name: 'Mercado Sonora', pictogram: 'mercado-sonora' },
                { stopId: 'f857b6', name: 'Cecilio Robelo', pictogram: 'cecilio-robelo' },
                { stopId: 'f85852', name: 'Ing. Eduardo Molina', pictogram: 'ing-eduardo-molina' },
                { stopId: 'f8575d', name: 'Moctezuma', pictogram: 'moctezuma' },
                { stopId: 'f85863', name: 'San Lázaro', pictogram: 'san-lazaro' },
                { stopId: 'f85770', name: 'Aeropuerto Terminal 1', pictogram: 'aeropuerto-terminal-1' },
              ],
            },
          ],
          style: { colors: ['#FE5000'], notes: 'Ruta Aeropuerto (Amajac – AICM T1 y T2)' },
        },
      ],
    },
    {
      line: '5',
      services: [
        {
          id: 'L5-regular',
          type: 'regular',
          lines: ['5'],
          directions: [
            {
              destination: 'Río de los Remedios',
              // 19553 = L05f01-2 san lázaro nte - río de los remedios
              // 19558 = L05f05-2 preparatoria 1 - río de los remedios (full line)
              // 20212 = L05f03-2 las bombas - río de los remedios
              gtfsRouteIds: ['19558', '19553', '20212'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'c98d35', name: 'Preparatoria 1', pictogram: 'preparatoria-1' },
                { stopId: 'f857e5', name: 'DIF Xochimilco', pictogram: 'dif-xochimilco' },
                { stopId: 'f85755', name: 'Circuito Cuemanco', pictogram: 'circuito-cuemanco' },
                { stopId: 'f857ba', name: 'Muyuguarda', pictogram: 'muyuguarda' },
                { stopId: 'f85827', name: 'Cañaverales', pictogram: 'canaverales' },
                { stopId: 'f85844', name: 'Calz. del Hueso', pictogram: 'calz-del-hueso' },
                { stopId: 'f8585a', name: 'Vista Hermosa', pictogram: 'vista-hermosa' },
                { stopId: 'f85768', name: 'Las Bombas', pictogram: 'las-bombas' },
                { stopId: 'f85836', name: 'Tepetlapa', pictogram: 'tepetlapa' },
                { stopId: 'f8576b', name: 'La Virgen', pictogram: 'la-virgen' },
                { stopId: 'f857d7', name: 'Manuela Sáenz', pictogram: 'manuela-saenz' },
                { stopId: 'f85820', name: 'ESIME Culhuacán', pictogram: 'esime-culhuacan' },
                { stopId: 'f8584f', name: 'Cafetales', pictogram: 'cafetales' },
                { stopId: 'f8582b', name: 'Calz. Taxqueña', pictogram: 'calz-taxquena' },
                { stopId: 'f857c9', name: 'Barrio San Antonio', pictogram: 'barrio-san-antonio' },
                { stopId: 'f857f6', name: 'Pueblo de los Reyes', pictogram: 'pueblo-de-los-reyes' },
                { stopId: '40f477', name: 'Ganaderos', pictogram: 'ganaderos' },
                { stopId: 'f857d4', name: 'Ermita-Iztapalapa', pictogram: 'ermita-iztapalapa' },
                { stopId: 'f8581d', name: 'Atanasio G. Sarabia', pictogram: 'atanasio-g-sarabia' },
                { stopId: 'f857bb', name: 'Escuadrón 201', pictogram: 'escuadron-201' },
                { stopId: '2db7c3', name: 'Churubusco Ote.', pictogram: 'churubusco-ote' },
                { stopId: '25e233', name: 'Aculco', pictogram: 'aculco' },
                { stopId: '40f471', name: 'Apatlaco', pictogram: 'apatlaco' },
                { stopId: '2db7b5', name: 'Canal Apatlaco', pictogram: 'canal-apatlaco' },
                { stopId: '25e227', name: 'C. de Bachilleres 3', pictogram: 'c-de-bachilleres-3' },
                { stopId: '40f461', name: 'Oriente 116', pictogram: 'oriente-116' },
                { stopId: '405e4f', name: 'Recreo', pictogram: 'recreo' },
                { stopId: '2db7a4', name: 'Metro Coyuya', pictogram: 'metro-coyuya' },
                { stopId: 'f85747', name: 'Hospital Gral. Troncoso', pictogram: 'hospital-gral-troncoso' },
                { stopId: 'f85752', name: 'Mixiuhca', pictogram: 'mixiuhca' },
                { stopId: 'f8580b', name: 'Av. del Taller', pictogram: 'av-del-taller' },
                { stopId: 'f857a5', name: 'V. Carranza', pictogram: 'v-carranza' },
                { stopId: 'f857b0', name: 'Moctezuma', pictogram: 'moctezuma' },
                { stopId: 'f8579c', name: 'San Lázaro', pictogram: 'san-lazaro' },
                { stopId: 'f8580d', name: 'Archivo General', pictogram: 'archivo-general' },
                { stopId: 'f85802', name: 'Mercado Morelos', pictogram: 'mercado-morelos' },
                { stopId: 'f85781', name: 'Deportivo E. Molina', pictogram: 'deportivo-e-molina' },
                { stopId: 'f85841', name: 'Canal del Norte', pictogram: 'canal-del-norte' },
                { stopId: '25e216', name: 'Río Consulado', pictogram: 'rio-consulado' },
                { stopId: 'dd52c3', name: 'Río Santa Coleta', pictogram: 'rio-santa-coleta' },
                { stopId: '405e42', name: 'Oriente 101', pictogram: 'oriente-101' },
                { stopId: '25e20b', name: 'Victoria', pictogram: 'victoria' },
                { stopId: 'c98d0a', name: 'Talismán', pictogram: 'talisman' },
                { stopId: '2db784', name: 'Río de Guadalupe', pictogram: 'rio-de-guadalupe' },
                { stopId: '25e1ff', name: 'San Juan de Aragón', pictogram: 'san-juan-de-aragon' },
                { stopId: 'c98cf8', name: 'Preparatoria 3', pictogram: 'preparatoria-3' },
                { stopId: '405e23', name: 'El Coyol', pictogram: 'el-coyol' },
                { stopId: 'c98cea', name: 'Vasco de Quiroga', pictogram: 'vasco-de-quiroga' },
                { stopId: '405dd7', name: '5 de Mayo', pictogram: '5-de-mayo' },
                { stopId: '078bbb', name: '314 Memorial New\'s Divine', pictogram: '314-memorial-news-divine' },
                { stopId: 'f85794', name: 'Río de los Remedios', pictogram: 'rio-de-los-remedios' },
              ],
            },
            {
              destination: 'Preparatoria 1',
              // 19559 = L05f05-1 río de los remedios - preparatoria 1 (full line)
              // 19556 = L05f04-1 san lázaro sur - preparatoria 1
              // 26903 = L05f51-1 la virgen - preparatoria 1
              // 26908 = L05f52-1 las bombas - preparatoria 1
              gtfsRouteIds: ['19559', '19556', '26903', '26908'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'f85794', name: 'Río de los Remedios', pictogram: 'rio-de-los-remedios' },
                { stopId: 'f8581b', name: '314 Memorial New\'s Divine', pictogram: '314-memorial-news-divine' },
                { stopId: 'f8583e', name: '5 de Mayo', pictogram: '5-de-mayo' },
                { stopId: 'f85765', name: 'Vasco de Quiroga', pictogram: 'vasco-de-quiroga' },
                { stopId: 'f857ad', name: 'El Coyol', pictogram: 'el-coyol' },
                { stopId: 'f857d1', name: 'Preparatoria 3', pictogram: 'preparatoria-3' },
                { stopId: 'f85808', name: 'San Juan de Aragón', pictogram: 'san-juan-de-aragon' },
                { stopId: 'f8583f', name: 'Río de Guadalupe', pictogram: 'rio-de-guadalupe' },
                { stopId: 'f8575a', name: 'Talismán', pictogram: 'talisman' },
                { stopId: 'f85796', name: 'Victoria', pictogram: 'victoria' },
                { stopId: 'f857d2', name: 'Oriente 101', pictogram: 'oriente-101' },
                { stopId: 'f8584c', name: 'Río Santa Coleta', pictogram: 'rio-santa-coleta' },
                { stopId: 'f85797', name: 'Río Consulado', pictogram: 'rio-consulado' },
                { stopId: 'f85841', name: 'Canal del Norte', pictogram: 'canal-del-norte' },
                { stopId: 'f85781', name: 'Deportivo E. Molina', pictogram: 'deportivo-e-molina' },
                { stopId: 'f85802', name: 'Mercado Morelos', pictogram: 'mercado-morelos' },
                { stopId: 'f8580d', name: 'Archivo General', pictogram: 'archivo-general' },
                { stopId: 'f85760', name: 'San Lázaro', pictogram: 'san-lazaro' },
                { stopId: 'f857b0', name: 'Moctezuma', pictogram: 'moctezuma' },
                { stopId: 'f857a5', name: 'V. Carranza', pictogram: 'v-carranza' },
                { stopId: 'f8580b', name: 'Av. del Taller', pictogram: 'av-del-taller' },
                { stopId: 'f85752', name: 'Mixiuhca', pictogram: 'mixiuhca' },
                { stopId: 'f85747', name: 'Hospital Gral. Troncoso', pictogram: 'hospital-gral-troncoso' },
                { stopId: 'f857e2', name: 'Metro Coyuya', pictogram: 'metro-coyuya' },
                { stopId: 'f8579a', name: 'Recreo', pictogram: 'recreo' },
                { stopId: 'f857ed', name: 'Oriente 116', pictogram: 'oriente-116' },
                { stopId: 'f85814', name: 'C. de Bachilleres 3', pictogram: 'c-de-bachilleres-3' },
                { stopId: 'f85744', name: 'Canal Apatlaco', pictogram: 'canal-apatlaco' },
                { stopId: 'f857ff', name: 'Apatlaco', pictogram: 'apatlaco' },
                { stopId: 'f85773', name: 'Aculco', pictogram: 'aculco' },
                { stopId: 'f8574f', name: 'Churubusco Ote.', pictogram: 'churubusco-ote' },
                { stopId: 'f857bb', name: 'Escuadrón 201', pictogram: 'escuadron-201' },
                { stopId: 'f8581d', name: 'Atanasio G. Sarabia', pictogram: 'atanasio-g-sarabia' },
                { stopId: 'f857d4', name: 'Ermita-Iztapalapa', pictogram: 'ermita-iztapalapa' },
                { stopId: 'f8578c', name: 'Ganaderos', pictogram: 'ganaderos' },
                { stopId: 'f857f6', name: 'Pueblo de los Reyes', pictogram: 'pueblo-de-los-reyes' },
                { stopId: 'f857c9', name: 'Barrio San Antonio', pictogram: 'barrio-san-antonio' },
                { stopId: 'f8582b', name: 'Calz. Taxqueña', pictogram: 'calz-taxquena' },
                { stopId: 'f8584f', name: 'Cafetales', pictogram: 'cafetales' },
                { stopId: 'f85820', name: 'ESIME Culhuacán', pictogram: 'esime-culhuacan' },
                { stopId: 'f857d7', name: 'Manuela Sáenz', pictogram: 'manuela-saenz' },
                { stopId: 'f8576b', name: 'La Virgen', pictogram: 'la-virgen' },
                { stopId: 'f85836', name: 'Tepetlapa', pictogram: 'tepetlapa' },
                { stopId: 'f85768', name: 'Las Bombas', pictogram: 'las-bombas' },
                { stopId: 'f8585a', name: 'Vista Hermosa', pictogram: 'vista-hermosa' },
                { stopId: 'f85844', name: 'Calz. del Hueso', pictogram: 'calz-del-hueso' },
                { stopId: 'f85827', name: 'Cañaverales', pictogram: 'canaverales' },
                { stopId: 'f857ba', name: 'Muyuguarda', pictogram: 'muyuguarda' },
                { stopId: 'f85755', name: 'Circuito Cuemanco', pictogram: 'circuito-cuemanco' },
                { stopId: 'f857e5', name: 'DIF Xochimilco', pictogram: 'dif-xochimilco' },
                { stopId: 'f857da', name: 'Preparatoria 1', pictogram: 'preparatoria-1' },
              ],
            },
          ],
          // App LineColors.line5 — PANTONE 2757 C (Sources/Theme/DesignTokens.swift).
          style: { colors: ['#001E60'] },
        },
      ],
    },
    {
      line: '6',
      services: [
        {
          id: 'L6-regular',
          type: 'regular',
          lines: ['6'],
          directions: [
            {
              destination: 'Villa de Aragón',
              // 19471 = L06g01-2 el rosario - villa de aragón (full line)
              // 19472 = L06g02-2 ipn - villa de aragón
              gtfsRouteIds: ['19471', '19472'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'f857cb', name: 'El Rosario', pictogram: 'el-rosario' },
                { stopId: 'f8575f', name: 'C. de Bachilleres 1', pictogram: 'c-de-bachilleres-1' },
                { stopId: 'f85816', name: 'De las Culturas', pictogram: 'de-las-culturas' },
                { stopId: 'f857f8', name: 'F.F.C.C. Nacionales', pictogram: 'ffcc-nacionales' },
                { stopId: 'f8581f', name: 'UAM Azcapotzalco', pictogram: 'uam-azcapotzalco' },
                { stopId: 'f85799', name: 'Tecnoparque', pictogram: 'tecnoparque' },
                { stopId: 'f85813', name: 'Norte 59', pictogram: 'norte-59' },
                { stopId: 'f85772', name: 'Norte 45', pictogram: 'norte-45' },
                { stopId: 'bfc9a0', name: 'Montevideo', pictogram: 'montevideo' },
                { stopId: 'f857cd', name: 'Lindavista-Vallejo', pictogram: 'lindavista-vallejo' },
                { stopId: 'f8579b', name: 'I. del Petróleo', pictogram: 'i-del-petroleo' },
                { stopId: 'f8581e', name: 'San Bartolo', pictogram: 'san-bartolo' },
                { stopId: 'f857c7', name: 'I.P.N.', pictogram: 'ipn' },
                { stopId: 'f857f9', name: 'Riobamba', pictogram: 'riobamba' },
                { stopId: 'f857cf', name: 'Dep. 18 de Marzo', pictogram: 'dep-18-de-marzo' },
                { stopId: 'f8574a', name: 'La Villa', pictogram: 'la-villa' },
                { stopId: 'f85776', name: 'Gustavo A. Madero', pictogram: 'gustavo-a-madero' },
                { stopId: 'f85828', name: 'Martín Carrera', pictogram: 'martin-carrera' },
                { stopId: 'f85778', name: 'Hospital Gral. La Villa', pictogram: 'hospital-gral-la-villa' },
                { stopId: 'f85821', name: 'San Juan de Aragón', pictogram: 'san-juan-de-aragon' },
                { stopId: 'f85789', name: 'Gran Canal', pictogram: 'gran-canal' },
                { stopId: 'f857fd', name: 'Casas Alemán', pictogram: 'casas-aleman' },
                { stopId: 'f857b8', name: 'Pueblo S. J. de Aragón', pictogram: 'pueblo-s-j-de-aragon' },
                { stopId: 'f85849', name: 'Loreto Fabela', pictogram: 'loreto-fabela' },
                { stopId: 'f8577b', name: '482', pictogram: '482' },
                { stopId: 'f857f1', name: '414', pictogram: '414' },
                { stopId: 'f857ce', name: '416 Oriente', pictogram: '416-oriente' },
                { stopId: 'f85786', name: 'La Pradera', pictogram: 'la-pradera' },
                { stopId: 'f8585f', name: 'C. de Bachilleres 9', pictogram: 'c-de-bachilleres-9' },
                { stopId: 'f8583b', name: 'Francisco Morazán', pictogram: 'francisco-morazan' },
                { stopId: 'f857d9', name: 'Villa de Aragón', pictogram: 'villa-de-aragon' },
              ],
            },
            {
              destination: 'El Rosario',
              // 19470 = L06g01-1 villa de aragón - el rosario (full line)
              // 19474 = L06g03-1 dep. 18 de marzo - el rosario
              gtfsRouteIds: ['19470', '19474'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'f857d9', name: 'Villa de Aragón', pictogram: 'villa-de-aragon' },
                { stopId: 'f8583b', name: 'Francisco Morazán', pictogram: 'francisco-morazan' },
                { stopId: 'f8585f', name: 'C. de Bachilleres 9', pictogram: 'c-de-bachilleres-9' },
                { stopId: 'f85786', name: 'La Pradera', pictogram: 'la-pradera' },
                { stopId: 'f8580f', name: 'Volcán de Fuego', pictogram: 'volcan-de-fuego' },
                { stopId: 'f85757', name: 'A. Providencia', pictogram: 'a-providencia' },
                { stopId: 'f857e7', name: 'D. los Galeana', pictogram: 'd-los-galeana' },
                { stopId: 'f85806', name: '416 Poniente', pictogram: '416-poniente' },
                { stopId: 'f85849', name: 'Loreto Fabela', pictogram: 'loreto-fabela' },
                { stopId: 'f857b8', name: 'Pueblo S. J. de Aragón', pictogram: 'pueblo-s-j-de-aragon' },
                { stopId: 'f857fd', name: 'Casas Alemán', pictogram: 'casas-aleman' },
                { stopId: 'f85789', name: 'Gran Canal', pictogram: 'gran-canal' },
                { stopId: 'f85821', name: 'San Juan de Aragón', pictogram: 'san-juan-de-aragon' },
                { stopId: 'f85778', name: 'Hospital Gral. La Villa', pictogram: 'hospital-gral-la-villa' },
                { stopId: 'f85828', name: 'Martín Carrera', pictogram: 'martin-carrera' },
                { stopId: 'f85776', name: 'Gustavo A. Madero', pictogram: 'gustavo-a-madero' },
                { stopId: 'f857f4', name: 'Hospital Infantil La Villa', pictogram: 'hospital-infantil-la-villa' },
                { stopId: 'f8579d', name: 'De los Misterios', pictogram: 'de-los-misterios' },
                { stopId: 'f8574a', name: 'La Villa', pictogram: 'la-villa' },
                { stopId: 'f857cf', name: 'Dep. 18 de Marzo', pictogram: 'dep-18-de-marzo' },
                { stopId: 'f857f9', name: 'Riobamba', pictogram: 'riobamba' },
                { stopId: 'f857c7', name: 'I.P.N.', pictogram: 'ipn' },
                { stopId: 'f8581e', name: 'San Bartolo', pictogram: 'san-bartolo' },
                { stopId: 'f8579b', name: 'I. del Petróleo', pictogram: 'i-del-petroleo' },
                { stopId: 'f857cd', name: 'Lindavista-Vallejo', pictogram: 'lindavista-vallejo' },
                { stopId: 'bfc9a0', name: 'Montevideo', pictogram: 'montevideo' },
                { stopId: 'f85772', name: 'Norte 45', pictogram: 'norte-45' },
                { stopId: 'f85813', name: 'Norte 59', pictogram: 'norte-59' },
                { stopId: 'f85799', name: 'Tecnoparque', pictogram: 'tecnoparque' },
                { stopId: 'f8581f', name: 'UAM Azcapotzalco', pictogram: 'uam-azcapotzalco' },
                { stopId: 'f857f8', name: 'F.F.C.C. Nacionales', pictogram: 'ffcc-nacionales' },
                { stopId: 'f85816', name: 'De las Culturas', pictogram: 'de-las-culturas' },
                { stopId: 'f8575f', name: 'C. de Bachilleres 1', pictogram: 'c-de-bachilleres-1' },
                { stopId: 'f857cb', name: 'El Rosario', pictogram: 'el-rosario' },
              ],
            },
          ],
          // App LineColors.line6 — PANTONE Rhodamine Red C (Sources/Theme/DesignTokens.swift).
          style: { colors: ['#E10098'] },
        },
      ],
    },
    {
      line: '7',
      services: [
        {
          id: 'L7-regular',
          type: 'regular',
          lines: ['7'],
          directions: [
            {
              destination: 'Indios Verdes',
              // 19577 = L07h01-2 campo marte - indios verdes (full line)
              // 19583 = L07h04-2 la diana - indios verdes
              // 19959 = L07h05-2 la diana - indios verdes
              gtfsRouteIds: ['19577', '19583', '19959'],
              gtfsHeadsigns: ['Volta'],
              stops: [
                { stopId: 'f857a7', name: 'Campo Marte', pictogram: 'campo-marte' },
                { stopId: 'f8585c', name: 'Auditorio', pictogram: 'auditorio' },
                { stopId: 'f8576a', name: 'Antropología', pictogram: 'antropologia' },
                { stopId: 'f85801', name: 'Gandhi', pictogram: 'gandhi' },
                { stopId: 'f85775', name: 'Chapultepec', pictogram: 'chapultepec' },
                { stopId: 'f8582a', name: 'La Diana', pictogram: 'la-diana' },
                { stopId: 'f857a4', name: 'El Ángel', pictogram: 'el-angel' },
                { stopId: 'aefdfc', name: 'El Ahuehuete', pictogram: 'el-ahuehuete' },
                { stopId: 'f8578b', name: 'Hamburgo', pictogram: 'hamburgo' },
                { stopId: 'f85790', name: 'Reforma', pictogram: 'reforma' },
                { stopId: 'f85803', name: 'París', pictogram: 'paris' },
                { stopId: '0359b9', name: 'Amajac', pictogram: 'amajac' },
                { stopId: 'f8580e', name: 'El Caballito', pictogram: 'el-caballito' },
                { stopId: 'f8578a', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f857ee', name: 'Glorieta Violeta', pictogram: 'glorieta-violeta' },
                { stopId: 'f85769', name: 'Garibaldi / Lagunilla', pictogram: 'garibaldi-lagunilla' },
                { stopId: 'b315d3', name: 'Glorieta Cuitláhuac', pictogram: 'glorieta-cuitlahuac' },
                { stopId: 'f8575b', name: 'Tres Culturas', pictogram: 'tres-culturas' },
                { stopId: 'f857a2', name: 'Peralvillo', pictogram: 'peralvillo' },
                { stopId: 'f85748', name: 'Mercado Beethoven', pictogram: 'mercado-beethoven' },
                { stopId: 'f857dd', name: 'Misterios', pictogram: 'misterios' },
                { stopId: 'f8574d', name: 'Clave', pictogram: 'clave' },
                { stopId: 'f85807', name: 'Robles Domínguez', pictogram: 'robles-dominguez' },
                { stopId: 'f857a0', name: 'Excélsior', pictogram: 'excelsior' },
                { stopId: 'f857ab', name: 'Necaxa', pictogram: 'necaxa' },
                { stopId: 'f85860', name: 'Av. Talismán', pictogram: 'av-talisman' },
                { stopId: 'f85792', name: 'Garrido', pictogram: 'garrido' },
                { stopId: 'f857b3', name: 'Gustavo A. Madero', pictogram: 'gustavo-a-madero' },
                { stopId: 'f857fb', name: 'Indios Verdes', pictogram: 'indios-verdes' },
              ],
            },
            {
              destination: 'Campo Marte',
              // 19576 = L07h01-1 indios verdes - campo marte (full line)
              // 19578 = L07h02-1 hospital infantil - campo marte
              // 19909 = L07h10-1 garibaldi - campo marte
              // 26909 = L07h50-1 garrido - campo marte
              gtfsRouteIds: ['19576', '19578', '19909', '26909'],
              gtfsHeadsigns: ['Ida'],
              stops: [
                { stopId: 'f857fb', name: 'Indios Verdes', pictogram: 'indios-verdes' },
                { stopId: 'f857c1', name: 'De los Misterios', pictogram: 'de-los-misterios' },
                { stopId: 'f8576e', name: 'Garrido', pictogram: 'garrido' },
                { stopId: 'f8583c', name: 'Av. Talismán', pictogram: 'av-talisman' },
                { stopId: 'f85787', name: 'Necaxa', pictogram: 'necaxa' },
                { stopId: 'f85831', name: 'Excélsior', pictogram: 'excelsior' },
                { stopId: 'f857c4', name: 'Robles Domínguez', pictogram: 'robles-dominguez' },
                { stopId: 'f8584a', name: 'Clave', pictogram: 'clave' },
                { stopId: 'f85795', name: 'Misterios', pictogram: 'misterios' },
                { stopId: 'f8582d', name: 'Mercado Beethoven', pictogram: 'mercado-beethoven' },
                { stopId: 'f85784', name: 'Peralvillo', pictogram: 'peralvillo' },
                { stopId: 'f85858', name: 'Tres Culturas', pictogram: 'tres-culturas' },
                { stopId: 'b315cb', name: 'Glorieta Cuitláhuac Nte', pictogram: 'glorieta-cuitlahuac' },
                { stopId: 'b46d55', name: 'Glorieta Cuitláhuac Sur', pictogram: 'glorieta-cuitlahuac' },
                { stopId: 'f85800', name: 'Garibaldi / Lagunilla', pictogram: 'garibaldi-lagunilla' },
                { stopId: 'f8575e', name: 'Glorieta Violeta', pictogram: 'glorieta-violeta' },
                { stopId: 'f85833', name: 'Hidalgo', pictogram: 'hidalgo' },
                { stopId: 'f85785', name: 'El Caballito', pictogram: 'el-caballito' },
                { stopId: '59aee2', name: 'Amajac', pictogram: 'amajac' },
                { stopId: 'f857c5', name: 'París', pictogram: 'paris' },
                { stopId: 'f85754', name: 'Reforma', pictogram: 'reforma' },
                { stopId: 'f85743', name: 'Hamburgo', pictogram: 'hamburgo' },
                { stopId: '749a60', name: 'El Ahuehuete', pictogram: 'el-ahuehuete' },
                { stopId: 'f85780', name: 'El Ángel', pictogram: 'el-angel' },
                { stopId: 'f8580a', name: 'La Diana', pictogram: 'la-diana' },
                { stopId: 'f85751', name: 'Chapultepec', pictogram: 'chapultepec' },
                { stopId: 'f857e1', name: 'Gandhi', pictogram: 'gandhi' },
                { stopId: 'f85746', name: 'Antropología', pictogram: 'antropologia' },
                { stopId: 'f85838', name: 'Auditorio', pictogram: 'auditorio' },
                { stopId: 'f85783', name: 'Campo Marte', pictogram: 'campo-marte' },
              ],
            },
          ],
          // App LineColors.line7 — PANTONE 349 C (Sources/Theme/DesignTokens.swift).
          style: { colors: ['#046A38'] },
        },
      ],
    },
  ],
};
