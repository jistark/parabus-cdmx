import Foundation

// MARK: - Orden de ruta Metrobús
//
// `GTFSStations` está ordenado alfabéticamente y (herencia del feed por
// servicios combinados) incluye estaciones de otros corredores. Este dataset
// curado define el orden geográfico terminal→terminal por línea, referenciando
// estaciones por nombre exacto de `GTFSStations`. Integridad verificada por
// MBRouteOrderTests (resolución única, terminales, distancia entre adyacentes).
// Fuente: secuencias de paradas (stop_times) del GTFS estático oficial de
// CDMX (datos.cdmx.gob.mx, feed feb 2026) para el viaje completo en dirección
// "ida", validado contra coordenadas y la red oficial Metrobús.

enum MBRouteOrder {

    /// Orden canónico (dirección "ida" del nombre de ruta, p. ej.
    /// Indios Verdes → El Caminero). La dirección inversa se deriva
    /// con `reversed()` en el planner.
    ///
    /// Donde la ida y la vuelta usan calles/plataformas distintas se modela
    /// la plataforma de la ida (p. ej. L2: Antonio Maceo sí, Parque Lira no;
    /// L4 Ruta Sur: Pino Suárez sí, Pino Suárez Sur no; L7: Glorieta
    /// Cuitláhuac Nte sí, Sur no).
    static let orderedNames: [String: [String]] = [
        "1": line1Order, "2": line2Order, "3": line3Order, "4": line4Order,
        "5": line5Order, "6": line6Order, "7": line7Order,
    ]

    private static let cachedStations: [String: [GTFSStation]] = {
        Dictionary(uniqueKeysWithValues: ["1", "2", "3", "4", "5", "6", "7"].map { line in
            let byName = Dictionary(
                GTFSStations.stations(for: line).map { ($0.name, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let resolved = (orderedNames[line] ?? []).compactMap { name -> GTFSStation? in
                if let station = byName[name] { return station }
                assertionFailure("MBRouteOrder: '\(name)' L\(line) sin resolver — ¿GTFS actualizado?")
                return nil
            }
            return (line, resolved)
        })
    }()

    static func orderedStations(for lineNumber: String) -> [GTFSStation] {
        cachedStations[lineNumber] ?? []
    }

    // MARK: - Línea 1 · Indios Verdes - El Caminero (norte → sur)

    private static let line1Order: [String] = [
        "Indios Verdes L1", "Dep. 18 Mzo. L1", "Euzkaro", "Potrero",
        "La Raza L1", "Circuito L1", "San Simón", "Manuel González",
        "Buenavista L1", "El Chopo", "Revolución", "Plaza de la República L1",
        "Reforma L1", "Hamburgo L1", "Insurgentes", "Durango",
        "Álvaro Obregón", "Sonora", "Campeche", "Chilpancingo",
        "Nuevo León L1", "La Piedad", "Polifórum", "Nápoles",
        "Colonia del Valle", "Ciudad de los Deportes", "Parque Hundido",
        "Félix Cuevas", "Río Churubusco", "Teatro de los Insurgentes",
        "José María Velasco", "Francia", "Olivo", "Altavista",
        "La Bombilla", "Dr. Gálvez", "Ciudad Universitaria", "CCU",
        "Perisur", "Villa Olímpica", "Corregidora", "Ayuntamiento",
        "Fuentes Brotantes", "Santa Úrsula", "La Joya", "El Caminero",
    ]

    // MARK: - Línea 2 · Tacubaya - Tepalcates (poniente → oriente)
    //
    // Ida por Eje 4 Sur. Vuelta-only fuera del orden: Parque Lira,
    // Río Frío, Gral. Antonio de León (y Alameda Tacubaya, servicio de apoyo).

    private static let line2Order: [String] = [
        "Tacubaya", "Antonio Maceo", "De la Salle", "Patriotismo",
        "Escandón", "Nuevo León L2", "Viaducto", "Amores", "Etiopía L2",
        "Doctor Vértiz", "Centro SCOP", "Álamos", "Xola", "Las Américas",
        "Andrés Molina Enríquez", "La Viga", "Coyuya", "Metro Coyuya L2",
        "Canela", "Tlacotal", "Goma", "Iztacalco", "UPIICSA", "El Rodeo",
        "Río Tecolutla", "Río Mayo", "Rojo Gómez", "Del Moral",
        "Leyes de Reforma", "CCH Oriente", "Const. de Apatzingán",
        "Canal de San Juan", "Nicolás Bravo", "Tepalcates",
    ]

    // MARK: - Línea 3 · Tenayuca - Pueblo Sta. Cruz Atoyac (norte → sur)
    //
    // Corredor completo incluida la extensión sur Etiopía → Pueblo Sta. Cruz
    // Atoyac (viaje B_03300L3000_0 del GTFS feb 2026). La Raza y Buenavista
    // son espuelas/terminales de servicios cortos que el mapa oficial
    // intercala en la secuencia; se incluyen en su posición.

    private static let line3Order: [String] = [
        "Tenayuca", "San José de la Escalera", "Progreso Nacional",
        "Tres Anegas", "Júpiter", "La Patera", "Poniente 146",
        "Montevideo L3", "Poniente 134", "Poniente 128",
        "Magdalena de las Salinas", "Coltongo", "Cuitláhuac",
        "Héroe de Nacozari", "Hospital la Raza", "La Raza L3",
        "Circuito L3", "Tolnáhuac", "Tlatelolco", "Ricardo Flores Magón",
        "Guerrero", "Buenavista L3 Sur", "Mina", "Hidalgo L3", "Juárez L3",
        "Balderas", "Cuauhtémoc", "Jardín Pushkin", "Hospital General",
        "Doctor Márquez", "Centro Médico", "Obrero Mundial", "Etiopía L3",
        "Luz Saviñón", "Eugenia", "División del Norte", "Miguel Laurent",
        "Pueblo Sta. Cruz Atoyac",
    ]

    // MARK: - Línea 4 · Buenavista - Aeropuerto T1 (Ruta Sur, ida oriente)
    //
    // Centro Histórico en par vial: la ida usa las plataformas sur-oriente
    // (Pino Suárez, Las Cruces, Mercado Sonora, Eduardo Molina); la vuelta
    // usa San Pablo/Pino Suárez Sur/Mercado Sonora Sur/20 de Noviembre/
    // Hospital Balbuena. El ramal aéreo continúa de San Lázaro a T1.

    private static let line4Order: [String] = [
        "Buenavista L4", "Alcaldía Cuauhtémoc", "México Tenochtitlan",
        "Plaza de la República L4", "Amajac L4", "Defensoría Pública",
        "Vocacional 5", "Juárez L4", "Mercados de San Juan", "Eje Central",
        "El Salvador", "Isabel la Católica", "Museo de la Ciudad",
        "Pino Suárez", "Las Cruces", "La Merced", "Mercado Sonora",
        "Cecilio Robelo", "Eduardo Molina", "Moctezuma L4",
        "San Lázaro L4 Ote", "Terminal 1 AICM",
    ]

    // MARK: - Línea 5 · Río de los Remedios - Preparatoria 1 (norte → sur)
    //
    // Corredor físico completo por Eje 3 Oriente hasta Xochimilco, en sentido
    // ida sur (viaje B_03300L5000_0 del GTFS feb 2026). En San Lázaro la ida
    // usa la plataforma Norte; "San Lázaro Sur L5" es la de la vuelta.

    private static let line5Order: [String] = [
        "Río de los Remedios", "314 Memorial New's Divine", "5 de Mayo",
        "Vasco de Quiroga", "El Coyol", "Preparatoria 3",
        "San Juan de Aragón L5", "Río de Guadalupe", "Talismán L5",
        "Victoria", "Oriente 101", "Río Santa Coleta", "Río Consulado",
        "Canal del Norte", "Deportivo Eduardo Molina", "Mercado Morelos",
        "Archivo General de la Nación L5", "San Lázaro Norte L5",
        "Moctezuma L5", "Venustiano Carranza", "Avenida del Taller",
        "Mixiuhca", "Hospital General Troncoso", "Metro Coyuya L5", "Recreo",
        "Oriente 116", "Colegio de Bachilleres 3", "Canal Apatlaco",
        "Apatlaco", "Aculco", "Churubusco Oriente", "Escuadrón 201",
        "Atanasio G. Sarabia", "Ermita-Iztapalapa", "Ganaderos",
        "Pueblo de los Reyes", "Barrio San Antonio", "Calzada Taxqueña",
        "Cafetales", "ESIME Culhuacán", "Manuela Sáenz", "La Virgen",
        "Tepetlapa", "Las Bombas", "Vista Hermosa", "Calzada del Hueso",
        "Cañaverales", "Muyuguarda", "Circuito Cuemanco", "DIF Xochimilco",
        "Preparatoria 1",
    ]

    // MARK: - Línea 6 · El Rosario - Villa de Aragón (poniente → oriente)
    //
    // Ida por Eje 5 Norte; el lazo oriente de San Juan de Aragón corre por
    // 482/414/416 Oriente. Vuelta-only fuera del orden: De los Misterios L6,
    // Hospital Infantil La Villa L6, 416 Poniente, Deportivo los Galeana,
    // Ampliación Providencia, Volcán de Fuego.

    private static let line6Order: [String] = [
        "El Rosario", "Colegio de Bachilleres 1", "De Las Culturas",
        "Ferrocarriles Nacionales", "UAM Azcapotzalco", "Tecnoparque",
        "Norte 59", "Norte 45", "Montevideo L6", "Lindavista - Vallejo",
        "Instituto del Petróleo", "San Bartolo",
        "Instituto Politécnico Nacional", "Riobamba", "Dep. 18 Mzo. L6",
        "La Villa", "Gustavo A. Madero L6", "Martín Carrera",
        "Hospital General La Villa", "San Juan de Aragón L6", "Gran Canal",
        "Casas Alemán", "Pueblo de San Juan de Aragón", "Loreto Fabela",
        "482", "414", "416 Oriente", "La Pradera",
        "Colegio de Bachilleres 9", "Francisco Morazán", "Villa de Aragón",
    ]

    // MARK: - Línea 7 · Indios Verdes - Campo Marte (norte → sur-poniente)
    //
    // Ida por Calzada de los Misterios y Reforma. Vuelta-only fuera del
    // orden: Gustavo A. Madero L7 y Hospital Infantil La Villa L7 (ramal por
    // Calzada de Guadalupe) y Glorieta Cuitláhuac Sur.

    private static let line7Order: [String] = [
        "Indios Verdes L7", "De los Misterios L7", "Garrido", "Av. Talismán",
        "Necaxa", "Excélsior", "Robles Domínguez", "Clave", "Misterios",
        "Mercado Beethoven", "Peralvillo", "Tres Culturas",
        "Glorieta Cuitláhuac Nte", "Garibaldi", "Glorieta de Violeta",
        "Hidalgo L7", "El Caballito", "Amajac L7", "París", "Reforma L7",
        "Hamburgo L7", "El Ahuehuete", "El Ángel", "La Diana", "Chapultepec",
        "Gandhi", "Antropología", "Auditorio", "Campo Marte",
    ]
}
