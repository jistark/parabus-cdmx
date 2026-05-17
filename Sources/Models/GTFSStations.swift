import Foundation
import CoreLocation

// MARK: - GTFS Stations (Generated from GTFS Static Feed)
// Source: Metrobus CDMX Open Data - December 2024

enum GTFSStations {
    static func stations(for lineNumber: String) -> [GTFSStation] {
        switch lineNumber {
        case "1": return line1Stations
        case "2": return line2Stations
        case "3": return line3Stations
        case "4": return line4Stations
        case "5": return line5Stations
        case "6": return line6Stations
        case "7": return line7Stations
        default: return []
        }
    }

    static let allLines: [(number: String, name: String, route: String)] = [
        ("1", "Linea 1", "Indios Verdes - El Caminero"),
        ("2", "Linea 2", "Tacubaya - Tepalcates"),
        ("3", "Linea 3", "Tenayuca - Etiopia"),
        ("4", "Linea 4", "Buenavista - Aeropuerto T1"),
        ("5", "Linea 5", "San Lazaro - Rio de los Remedios"),
        ("6", "Linea 6", "El Rosario - Villa de Aragon"),
        ("7", "Linea 7", "Indios Verdes - Campo Marte")
    ]

    static func search(_ query: String) -> [GTFSStation] {
        guard !query.isEmpty else { return [] }
        let normalizedQuery = query.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        var results: [GTFSStation] = []
        for lineNumber in ["1", "2", "3", "4", "5", "6", "7"] {
            results.append(contentsOf: stations(for: lineNumber).filter {
                $0.name.lowercased().folding(options: .diacriticInsensitive, locale: .current).contains(normalizedQuery)
            })
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.name).inserted }
    }

    static func nearestStation(to coordinate: CLLocationCoordinate2D, inLine lineNumber: String? = nil) -> GTFSStation? {
        let stationsToSearch = lineNumber.map { stations(for: $0) } ?? ["1","2","3","4","5","6","7"].flatMap { stations(for: $0) }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return stationsToSearch.min { 
            location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <
            location.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
    }

    // MARK: - Line 1

    static let line1Stations: [GTFSStation] = [
        GTFSStation(id: "fa07a6", name: "Altavista", lineNumber: "1", latitude: 19.35077189255606, longitude: -99.18638186734991),
        GTFSStation(id: "f857d3", name: "Amores", lineNumber: "1", latitude: 19.396836, longitude: -99.163711),
        GTFSStation(id: "f85812", name: "Andrés Molina Enríquez", lineNumber: "1", latitude: 19.39763143662469, longitude: -99.12970792326716),
        GTFSStation(id: "fa079c", name: "Ayuntamiento", lineNumber: "1", latitude: 19.29264531575584, longitude: -99.17763856633142),
        GTFSStation(id: "697b10", name: "Balderas", lineNumber: "1", latitude: 19.42803123052508, longitude: -99.14870111486628),
        GTFSStation(id: "fa0784", name: "Buenavista L1", lineNumber: "1", latitude: 19.44688277988337, longitude: -99.1531684711489),
        GTFSStation(id: "697b0c", name: "Buenavista L3 Norte", lineNumber: "1", latitude: 19.446309437532836, longitude: -99.15198659224484),
        GTFSStation(id: "f85805", name: "Buenavista L3 Sur", lineNumber: "1", latitude: 19.445757954690002, longitude: -99.15214240550996),
        GTFSStation(id: "e88cba", name: "C.C Universitario", lineNumber: "1", latitude: 19.315140227263598, longitude: -99.18754220008852),
        GTFSStation(id: "f85818", name: "CCH Oriente", lineNumber: "1", latitude: 19.38333134036536, longitude: -99.06074842216212),
        GTFSStation(id: "fa07a7", name: "CCU", lineNumber: "1", latitude: 19.315140125715647, longitude: -99.18753716164709),
        GTFSStation(id: "fa078f", name: "Campeche", lineNumber: "1", latitude: 19.409778514779635, longitude: -99.16727274656297),
        GTFSStation(id: "f85791", name: "Canal de San Juan", lineNumber: "1", latitude: 19.39670924431783, longitude: -99.05653241568166),
        GTFSStation(id: "f857df", name: "Canela", lineNumber: "1", latitude: 19.39782631717387, longitude: -99.10943817787135),
        GTFSStation(id: "697b15", name: "Centro Médico", lineNumber: "1", latitude: 19.40731720822523, longitude: -99.15506623342795),
        GTFSStation(id: "f85851", name: "Centro SCOP", lineNumber: "1", latitude: 19.39527340571535, longitude: -99.146698332653),
        GTFSStation(id: "fa0790", name: "Chilpancingo", lineNumber: "1", latitude: 19.40668064654693, longitude: -99.16823652746277),
        GTFSStation(id: "fa0781", name: "Circuito L1", lineNumber: "1", latitude: 19.46262217936452, longitude: -99.14386723712764),
        GTFSStation(id: "fa07ac", name: "Ciudad Universitaria", lineNumber: "1", latitude: 19.32290957807005, longitude: -99.18853534896722),
        GTFSStation(id: "fa079a", name: "Ciudad de los Deportes", lineNumber: "1", latitude: 19.38227, longitude: -99.17628),
        GTFSStation(id: "fa0798", name: "Colonia del Valle", lineNumber: "1", latitude: 19.38571354863733, longitude: -99.17506613534312),
        GTFSStation(id: "f857fa", name: "Const. de Apatzingán", lineNumber: "1", latitude: 19.3890344498816, longitude: -99.05981096041994),
        GTFSStation(id: "fa079f", name: "Corregidora", lineNumber: "1", latitude: 19.29410519454726, longitude: -99.1811098140218),
        GTFSStation(id: "f85779", name: "Coyuya", lineNumber: "1", latitude: 19.39825356928997, longitude: -99.11670793250475),
        GTFSStation(id: "697b11", name: "Cuauhtémoc", lineNumber: "1", latitude: 19.42495471505716, longitude: -99.15368419092368),
        GTFSStation(id: "f857aa", name: "Del Moral", lineNumber: "1", latitude: 19.38419192549233, longitude: -99.07091038657421),
        GTFSStation(id: "fa07aa", name: "Dep. 18 Mzo. L1", lineNumber: "1", latitude: 19.48644922699015, longitude: -99.1245180831272),
        GTFSStation(id: "697b1a", name: "División del Norte", lineNumber: "1", latitude: 19.380478630856697, longitude: -99.15881842374803),
        GTFSStation(id: "697b14", name: "Doctor Márquez", lineNumber: "1", latitude: 19.41111860298619, longitude: -99.15478142701357),
        GTFSStation(id: "f857c2", name: "Doctor Vértiz", lineNumber: "1", latitude: 19.39558311097358, longitude: -99.15169123419294),
        GTFSStation(id: "1d6ab9", name: "Dr. Gálvez", lineNumber: "1", latitude: 19.34064390505222, longitude: -99.19011885723874),
        GTFSStation(id: "fa078c", name: "Durango", lineNumber: "1", latitude: 19.42006350418963, longitude: -99.1640519168265),
        GTFSStation(id: "fa0791", name: "El Caminero", lineNumber: "1", latitude: 19.27895727527269, longitude: -99.16940432340827),
        GTFSStation(id: "fa0785", name: "El Chopo", lineNumber: "1", latitude: 19.44325475566636, longitude: -99.15447392309511),
        GTFSStation(id: "f857dc", name: "El Rodeo", lineNumber: "1", latitude: 19.39164014341617, longitude: -99.08710117144095),
        GTFSStation(id: "f8577d", name: "Etiopía L2", lineNumber: "1", latitude: 19.39580386172431, longitude: -99.15484310065293),
        GTFSStation(id: "697b17", name: "Etiopía L3", lineNumber: "1", latitude: 19.39699601797086, longitude: -99.15585251940153),
        GTFSStation(id: "697b19", name: "Eugenia", lineNumber: "1", latitude: 19.38580262042498, longitude: -99.15719174119745),
        GTFSStation(id: "fa07ab", name: "Euzkaro", lineNumber: "1", latitude: 19.48266224994973, longitude: -99.12762383746852),
        GTFSStation(id: "fa07a2", name: "Francia", lineNumber: "1", latitude: 19.35830456967379, longitude: -99.18395139276464),
        GTFSStation(id: "fa0797", name: "Fuentes Brotantes", lineNumber: "1", latitude: 19.288058811090515, longitude: -99.17459785938263),
        GTFSStation(id: "09619f", name: "Félix Cuevas", lineNumber: "1", latitude: 19.37365907774236, longitude: -99.17896845364422),
        GTFSStation(id: "f8585d", name: "Goma", lineNumber: "1", latitude: 19.39686113826173, longitude: -99.10006103636684),
        GTFSStation(id: "f85749", name: "Gral. Antonio de León", lineNumber: "1", latitude: 19.38538109479915, longitude: -99.05174036704837),
        GTFSStation(id: "697b0b", name: "Guerrero", lineNumber: "1", latitude: 19.44607193952419, longitude: -99.14726821197756),
        GTFSStation(id: "fa0789", name: "Hamburgo L1", lineNumber: "1", latitude: 19.42770768007352, longitude: -99.16119486267793),
        GTFSStation(id: "697b0e", name: "Hidalgo L3", lineNumber: "1", latitude: 19.43599239734298, longitude: -99.14726910536872),
        GTFSStation(id: "697b13", name: "Hospital General", lineNumber: "1", latitude: 19.41443657880767, longitude: -99.15452357668178),
        GTFSStation(id: "319cb7", name: "Indios Verdes L1", lineNumber: "1", latitude: 19.497112801806296, longitude: -99.11919960721684),
        GTFSStation(id: "fa078a", name: "Insurgentes", lineNumber: "1", latitude: 19.42410906772833, longitude: -99.16333142064485),
        GTFSStation(id: "f857ef", name: "Iztacalco", lineNumber: "1", latitude: 19.39651781414634, longitude: -99.0959403573965),
        GTFSStation(id: "697b12", name: "Jardín Pushkin", lineNumber: "1", latitude: 19.42045615138886, longitude: -99.1540355829869),
        GTFSStation(id: "fa07a1", name: "José María Velasco", lineNumber: "1", latitude: 19.36176208219084, longitude: -99.18289663563067),
        GTFSStation(id: "697b0f", name: "Juárez L3", lineNumber: "1", latitude: 19.43161579927953, longitude: -99.14795204658719),
        GTFSStation(id: "fa07a8", name: "La Bombilla", lineNumber: "1", latitude: 19.34689513084349, longitude: -99.1877655336048),
        GTFSStation(id: "fa0793", name: "La Joya", lineNumber: "1", latitude: 19.28035536452082, longitude: -99.1700111751622),
        GTFSStation(id: "fa0794", name: "La Piedad", lineNumber: "1", latitude: 19.39776384658177, longitude: -99.1711536312679),
        GTFSStation(id: "e88c44", name: "La Raza L1", lineNumber: "1", latitude: 19.46893328071212, longitude: -99.138741821136),
        GTFSStation(id: "f85758", name: "La Viga", lineNumber: "1", latitude: 19.3980344618875, longitude: -99.12457248839455),
        GTFSStation(id: "f85809", name: "Las Américas", lineNumber: "1", latitude: 19.39341912299042, longitude: -99.13427728280912),
        GTFSStation(id: "f85762", name: "Leyes de Reforma", lineNumber: "1", latitude: 19.38342985116283, longitude: -99.06579952074638),
        GTFSStation(id: "697b18", name: "Luz Saviñón", lineNumber: "1", latitude: 19.391494852300905, longitude: -99.1563642024994),
        GTFSStation(id: "fa0783", name: "Manuel González", lineNumber: "1", latitude: 19.45671978369895, longitude: -99.14946703223335),
        GTFSStation(id: "f857be", name: "Metro Coyuya L2", lineNumber: "1", latitude: 19.398335, longitude: -99.113125),
        GTFSStation(id: "697b27", name: "Miguel Laurent", lineNumber: "1", latitude: 19.374901922322366, longitude: -99.16020780801774),
        GTFSStation(id: "697b0d", name: "Mina", lineNumber: "1", latitude: 19.44061027832123, longitude: -99.14849891099419),
        GTFSStation(id: "f85846", name: "Nicolás Bravo", lineNumber: "1", latitude: 19.39350347486558, longitude: -99.050926196446),
        GTFSStation(id: "fa0792", name: "Nuevo León L1", lineNumber: "1", latitude: 19.40204269480295, longitude: -99.16975234012803),
        GTFSStation(id: "fa0796", name: "Nápoles", lineNumber: "1", latitude: 19.3896222909298, longitude: -99.1737990029131),
        GTFSStation(id: "697b16", name: "Obrero Mundial", lineNumber: "1", latitude: 19.40111877560081, longitude: -99.15555617790422),
        GTFSStation(id: "fa07a3", name: "Olivo", lineNumber: "1", latitude: 19.35464537755246, longitude: -99.18513616213698),
        GTFSStation(id: "fa079b", name: "Parque Hundido", lineNumber: "1", latitude: 19.37946791221312, longitude: -99.17708587836776),
        GTFSStation(id: "fa07a5", name: "Perisur", lineNumber: "1", latitude: 19.30406, longitude: -99.18624),
        GTFSStation(id: "fa0787", name: "Plaza de la República L1", lineNumber: "1", latitude: 19.43597072042957, longitude: -99.15739044966492),
        GTFSStation(id: "fa0795", name: "Polifórum", lineNumber: "1", latitude: 19.39321394751125, longitude: -99.17270136797299),
        GTFSStation(id: "fa077f", name: "Potrero", lineNumber: "1", latitude: 19.47660808499176, longitude: -99.13265208566766),
        GTFSStation(id: "697b28", name: "Pueblo Sta. Cruz Atoyac", lineNumber: "1", latitude: 19.37176683765246, longitude: -99.1609561443329),
        GTFSStation(id: "fa0788", name: "Reforma L1", lineNumber: "1", latitude: 19.43279916313105, longitude: -99.15879315610292),
        GTFSStation(id: "fa0786", name: "Revolución", lineNumber: "1", latitude: 19.44023228356688, longitude: -99.1555152075447),
        GTFSStation(id: "697b0a", name: "Ricardo Flores Magón", lineNumber: "1", latitude: 19.45187, longitude: -99.145988),
        GTFSStation(id: "f8579f", name: "Rojo Gómez", lineNumber: "1", latitude: 19.38448509710503, longitude: -99.07638129244677),
        GTFSStation(id: "fa079e", name: "Río Churubusco", lineNumber: "1", latitude: 19.3689094354125, longitude: -99.18051144595017),
        GTFSStation(id: "f85854", name: "Río Frío", lineNumber: "1", latitude: 19.38762676791664, longitude: -99.07427191426662),
        GTFSStation(id: "f85825", name: "Río Mayo", lineNumber: "1", latitude: 19.38689466145514, longitude: -99.07997445243926),
        GTFSStation(id: "f8574c", name: "Río Tecolutla", lineNumber: "1", latitude: 19.38898881345624, longitude: -99.08310869219636),
        GTFSStation(id: "fa0782", name: "San Simón", lineNumber: "1", latitude: 19.45951903848959, longitude: -99.14643816862963),
        GTFSStation(id: "fa0799", name: "Santa Úrsula", lineNumber: "1", latitude: 19.283208086102178, longitude: -99.1753649711609),
        GTFSStation(id: "fa078e", name: "Sonora", lineNumber: "1", latitude: 19.41341136250927, longitude: -99.16610369884101),
        GTFSStation(id: "fa07a0", name: "Teatro de los Insurgentes", lineNumber: "1", latitude: 19.36490532773127, longitude: -99.18180902259563),
        GTFSStation(id: "f85822", name: "Tepalcates", lineNumber: "1", latitude: 19.39081533747767, longitude: -99.04749482316643),
        GTFSStation(id: "f857b4", name: "Tlacotal", lineNumber: "1", latitude: 19.39719954556777, longitude: -99.10394772701466),
        GTFSStation(id: "697b09", name: "Tlatelolco", lineNumber: "1", latitude: 19.45549884507741, longitude: -99.14504122737199),
        GTFSStation(id: "f85862", name: "UPIICSA", lineNumber: "1", latitude: 19.39388378792517, longitude: -99.09037307831852),
        GTFSStation(id: "f8575c", name: "Viaducto", lineNumber: "1", latitude: 19.4013539708559, longitude: -99.16814444643246),
        GTFSStation(id: "fa07a4", name: "Villa Olímpica", lineNumber: "1", latitude: 19.29914752169245, longitude: -99.18548736821604),
        GTFSStation(id: "f857b1", name: "Xola", lineNumber: "1", latitude: 19.39431958195676, longitude: -99.1401695213952),
        GTFSStation(id: "f85782", name: "Álamos", lineNumber: "1", latitude: 19.39472362659874, longitude: -99.14292840265595),
        GTFSStation(id: "fa078d", name: "Álvaro Obregón", lineNumber: "1", latitude: 19.41653448382856, longitude: -99.16509146537012)
    ]

    // MARK: - Line 2

    static let line2Stations: [GTFSStation] = [
        GTFSStation(id: "ba0966", name: "Alameda Tacubaya", lineNumber: "2", latitude: 19.40152620146037, longitude: -99.18588459491731),
        GTFSStation(id: "f857d3", name: "Amores", lineNumber: "2", latitude: 19.396836, longitude: -99.163711),
        GTFSStation(id: "f85812", name: "Andrés Molina Enríquez", lineNumber: "2", latitude: 19.39763143662469, longitude: -99.12970792326716),
        GTFSStation(id: "f8578e", name: "Antonio Maceo", lineNumber: "2", latitude: 19.404867, longitude: -99.185856),
        GTFSStation(id: "f85818", name: "CCH Oriente", lineNumber: "2", latitude: 19.38333134036536, longitude: -99.06074842216212),
        GTFSStation(id: "f85791", name: "Canal de San Juan", lineNumber: "2", latitude: 19.39670924431783, longitude: -99.05653241568166),
        GTFSStation(id: "f857df", name: "Canela", lineNumber: "2", latitude: 19.39782631717387, longitude: -99.10943817787135),
        GTFSStation(id: "f85851", name: "Centro SCOP", lineNumber: "2", latitude: 19.39527340571535, longitude: -99.146698332653),
        GTFSStation(id: "f85751", name: "Chapultepec", lineNumber: "2", latitude: 19.42404736609939, longitude: -99.17422532408303),
        GTFSStation(id: "fa0798", name: "Colonia del Valle", lineNumber: "2", latitude: 19.38571354863733, longitude: -99.17506613534312),
        GTFSStation(id: "f857fa", name: "Const. de Apatzingán", lineNumber: "2", latitude: 19.3890344498816, longitude: -99.05981096041994),
        GTFSStation(id: "f85779", name: "Coyuya", lineNumber: "2", latitude: 19.39825356928997, longitude: -99.11670793250475),
        GTFSStation(id: "f85843", name: "De la Salle", lineNumber: "2", latitude: 19.407667, longitude: -99.183564),
        GTFSStation(id: "0b47bb", name: "De la Salle L72", lineNumber: "2", latitude: 19.409120773710264, longitude: -99.18348401784898),
        GTFSStation(id: "f857aa", name: "Del Moral", lineNumber: "2", latitude: 19.38419192549233, longitude: -99.07091038657421),
        GTFSStation(id: "f857c2", name: "Doctor Vértiz", lineNumber: "2", latitude: 19.39558311097358, longitude: -99.15169123419294),
        GTFSStation(id: "749a60", name: "El Ahuehuete", lineNumber: "2", latitude: 19.42842709003128, longitude: -99.16486729350108),
        GTFSStation(id: "f85785", name: "El Caballito", lineNumber: "2", latitude: 19.43598752723021, longitude: -99.14911712743891),
        GTFSStation(id: "f857dc", name: "El Rodeo", lineNumber: "2", latitude: 19.39164014341617, longitude: -99.08710117144095),
        GTFSStation(id: "f85780", name: "El Ángel", lineNumber: "2", latitude: 19.42662910664687, longitude: -99.16865225057253),
        GTFSStation(id: "f8584e", name: "Escandón", lineNumber: "2", latitude: 19.404509, longitude: -99.173932),
        GTFSStation(id: "f8577d", name: "Etiopía L2", lineNumber: "2", latitude: 19.39580386172431, longitude: -99.15484310065293),
        GTFSStation(id: "697b17", name: "Etiopía L3", lineNumber: "2", latitude: 19.39699601797086, longitude: -99.15585251940153),
        GTFSStation(id: "f85800", name: "Garibaldi", lineNumber: "2", latitude: 19.44423650585254, longitude: -99.13961973294639),
        GTFSStation(id: "b46d55", name: "Glorieta Cuitláhuac Sur", lineNumber: "2", latitude: 19.44744881725725, longitude: -99.1357418260385),
        GTFSStation(id: "f8583d", name: "Glorieta de Colón L7", lineNumber: "2", latitude: 19.43397457789296, longitude: -99.1526677741595),
        GTFSStation(id: "f8575e", name: "Glorieta de Violeta", lineNumber: "2", latitude: 19.44153753371875, longitude: -99.14223668378563),
        GTFSStation(id: "f8585d", name: "Goma", lineNumber: "2", latitude: 19.39686113826173, longitude: -99.10006103636684),
        GTFSStation(id: "f85749", name: "Gral. Antonio de León", lineNumber: "2", latitude: 19.38538109479915, longitude: -99.05174036704837),
        GTFSStation(id: "f85743", name: "Hamburgo L7", lineNumber: "2", latitude: 19.42995356797701, longitude: -99.16159558715809),
        GTFSStation(id: "f85833", name: "Hidalgo L7", lineNumber: "2", latitude: 19.43772942933604, longitude: -99.14643753385796),
        GTFSStation(id: "f857ef", name: "Iztacalco", lineNumber: "2", latitude: 19.39651781414634, longitude: -99.0959403573965),
        GTFSStation(id: "f8580a", name: "La Diana", lineNumber: "2", latitude: 19.4255894802327, longitude: -99.1709642675253),
        GTFSStation(id: "fa0794", name: "La Piedad", lineNumber: "2", latitude: 19.39776384658177, longitude: -99.1711536312679),
        GTFSStation(id: "f85758", name: "La Viga", lineNumber: "2", latitude: 19.3980344618875, longitude: -99.12457248839455),
        GTFSStation(id: "f85809", name: "Las Américas", lineNumber: "2", latitude: 19.39341912299042, longitude: -99.13427728280912),
        GTFSStation(id: "f85762", name: "Leyes de Reforma", lineNumber: "2", latitude: 19.38342985116283, longitude: -99.06579952074638),
        GTFSStation(id: "f857be", name: "Metro Coyuya L2", lineNumber: "2", latitude: 19.398335, longitude: -99.113125),
        GTFSStation(id: "f85846", name: "Nicolás Bravo", lineNumber: "2", latitude: 19.39350347486558, longitude: -99.050926196446),
        GTFSStation(id: "fa0792", name: "Nuevo León L1", lineNumber: "2", latitude: 19.40204269480295, longitude: -99.16975234012803),
        GTFSStation(id: "f857c8", name: "Nuevo León L2", lineNumber: "2", latitude: 19.403537, longitude: -99.170581),
        GTFSStation(id: "fa0796", name: "Nápoles", lineNumber: "2", latitude: 19.3896222909298, longitude: -99.1737990029131),
        GTFSStation(id: "f857d6", name: "Parque Lira", lineNumber: "2", latitude: 19.40779267114004, longitude: -99.18911880979248),
        GTFSStation(id: "f857c5", name: "París", lineNumber: "2", latitude: 19.43256639378335, longitude: -99.15611023333271),
        GTFSStation(id: "f857bd", name: "Patriotismo", lineNumber: "2", latitude: 19.405482, longitude: -99.177268),
        GTFSStation(id: "fa0795", name: "Polifórum", lineNumber: "2", latitude: 19.39321394751125, longitude: -99.17270136797299),
        GTFSStation(id: "f85754", name: "Reforma L7", lineNumber: "2", latitude: 19.43139462535771, longitude: -99.15878777412368),
        GTFSStation(id: "f8579f", name: "Rojo Gómez", lineNumber: "2", latitude: 19.38448509710503, longitude: -99.07638129244677),
        GTFSStation(id: "f85854", name: "Río Frío", lineNumber: "2", latitude: 19.38762676791664, longitude: -99.07427191426662),
        GTFSStation(id: "f85825", name: "Río Mayo", lineNumber: "2", latitude: 19.38689466145514, longitude: -99.07997445243926),
        GTFSStation(id: "f8574c", name: "Río Tecolutla", lineNumber: "2", latitude: 19.38898881345624, longitude: -99.08310869219636),
        GTFSStation(id: "f857b2", name: "Tacubaya", lineNumber: "2", latitude: 19.401935753664333, longitude: -99.18702244952318),
        GTFSStation(id: "f85822", name: "Tepalcates", lineNumber: "2", latitude: 19.39081533747767, longitude: -99.04749482316643),
        GTFSStation(id: "f857b4", name: "Tlacotal", lineNumber: "2", latitude: 19.39719954556777, longitude: -99.10394772701466),
        GTFSStation(id: "f85862", name: "UPIICSA", lineNumber: "2", latitude: 19.39388378792517, longitude: -99.09037307831852),
        GTFSStation(id: "f8575c", name: "Viaducto", lineNumber: "2", latitude: 19.4013539708559, longitude: -99.16814444643246),
        GTFSStation(id: "f857b1", name: "Xola", lineNumber: "2", latitude: 19.39431958195676, longitude: -99.1401695213952),
        GTFSStation(id: "f85782", name: "Álamos", lineNumber: "2", latitude: 19.39472362659874, longitude: -99.14292840265595)
    ]

    // MARK: - Line 3

    static let line3Stations: [GTFSStation] = [
        GTFSStation(id: "697b10", name: "Balderas", lineNumber: "3", latitude: 19.42803123052508, longitude: -99.14870111486628),
        GTFSStation(id: "697b0c", name: "Buenavista L3 Norte", lineNumber: "3", latitude: 19.446309437532836, longitude: -99.15198659224484),
        GTFSStation(id: "f85805", name: "Buenavista L3 Sur", lineNumber: "3", latitude: 19.445757954690002, longitude: -99.15214240550996),
        GTFSStation(id: "697b15", name: "Centro Médico", lineNumber: "3", latitude: 19.40731720822523, longitude: -99.15506623342795),
        GTFSStation(id: "697b07", name: "Circuito L3", lineNumber: "3", latitude: 19.463362816288605, longitude: -99.14416015148164),
        GTFSStation(id: "f857e4", name: "Coltongo", lineNumber: "3", latitude: 19.479880968185544, longitude: -99.14843291044237),
        GTFSStation(id: "697b11", name: "Cuauhtémoc", lineNumber: "3", latitude: 19.42495471505716, longitude: -99.15368419092368),
        GTFSStation(id: "f857e3", name: "Cuitláhuac", lineNumber: "3", latitude: 19.473953643809892, longitude: -99.14620399475098),
        GTFSStation(id: "697b1a", name: "División del Norte", lineNumber: "3", latitude: 19.380478630856697, longitude: -99.15881842374803),
        GTFSStation(id: "697b14", name: "Doctor Márquez", lineNumber: "3", latitude: 19.41111860298619, longitude: -99.15478142701357),
        GTFSStation(id: "697b17", name: "Etiopía L3", lineNumber: "3", latitude: 19.39699601797086, longitude: -99.15585251940153),
        GTFSStation(id: "697b19", name: "Eugenia", lineNumber: "3", latitude: 19.38580262042498, longitude: -99.15719174119745),
        GTFSStation(id: "697b0b", name: "Guerrero", lineNumber: "3", latitude: 19.44607193952419, longitude: -99.14726821197756),
        GTFSStation(id: "697b0e", name: "Hidalgo L3", lineNumber: "3", latitude: 19.43599239734298, longitude: -99.14726910536872),
        GTFSStation(id: "697b13", name: "Hospital General", lineNumber: "3", latitude: 19.41443657880767, longitude: -99.15452357668178),
        GTFSStation(id: "697b06", name: "Hospital la Raza", lineNumber: "3", latitude: 19.4679596580588, longitude: -99.14390852670995),
        GTFSStation(id: "f85753", name: "Héroe de Nacozari", lineNumber: "3", latitude: 19.47121961572696, longitude: -99.14505615056318),
        GTFSStation(id: "697b12", name: "Jardín Pushkin", lineNumber: "3", latitude: 19.42045615138886, longitude: -99.1540355829869),
        GTFSStation(id: "697b0f", name: "Juárez L3", lineNumber: "3", latitude: 19.43161579927953, longitude: -99.14795204658719),
        GTFSStation(id: "f857cc", name: "Júpiter", lineNumber: "3", latitude: 19.50869086278045, longitude: -99.15921429944574),
        GTFSStation(id: "f85839", name: "La Patera", lineNumber: "3", latitude: 19.50371069154075, longitude: -99.15722099367268),
        GTFSStation(id: "542ae9", name: "La Raza L3", lineNumber: "3", latitude: 19.46728943839173, longitude: -99.1409392869112),
        GTFSStation(id: "697b18", name: "Luz Saviñón", lineNumber: "3", latitude: 19.391494852300905, longitude: -99.1563642024994),
        GTFSStation(id: "f857a9", name: "Magdalena de las Salinas", lineNumber: "3", latitude: 19.483958, longitude: -99.149988),
        GTFSStation(id: "697b27", name: "Miguel Laurent", lineNumber: "3", latitude: 19.374901922322366, longitude: -99.16020780801774),
        GTFSStation(id: "697b0d", name: "Mina", lineNumber: "3", latitude: 19.44061027832123, longitude: -99.14849891099419),
        GTFSStation(id: "f857f3", name: "Montevideo L3", lineNumber: "3", latitude: 19.49615621230987, longitude: -99.15441578090893),
        GTFSStation(id: "697b16", name: "Obrero Mundial", lineNumber: "3", latitude: 19.40111877560081, longitude: -99.15555617790422),
        GTFSStation(id: "f857e6", name: "Poniente 128", lineNumber: "3", latitude: 19.489451723062494, longitude: -99.15203511714937),
        GTFSStation(id: "f8576f", name: "Poniente 134", lineNumber: "3", latitude: 19.492544081187123, longitude: -99.15321797132493),
        GTFSStation(id: "f857a1", name: "Poniente 146", lineNumber: "3", latitude: 19.50003918814673, longitude: -99.15585362780902),
        GTFSStation(id: "697b1d", name: "Progreso Nacional", lineNumber: "3", latitude: 19.51973102531605, longitude: -99.16375755812645),
        GTFSStation(id: "697b28", name: "Pueblo Sta. Cruz Atoyac", lineNumber: "3", latitude: 19.37176683765246, longitude: -99.1609561443329),
        GTFSStation(id: "697b0a", name: "Ricardo Flores Magón", lineNumber: "3", latitude: 19.45187, longitude: -99.145988),
        GTFSStation(id: "697b1c", name: "San José de la Escalera", lineNumber: "3", latitude: 19.52284551981924, longitude: -99.16553223742903),
        GTFSStation(id: "697b1b", name: "Tenayuca", lineNumber: "3", latitude: 19.528580256615665, longitude: -99.17009498309568),
        GTFSStation(id: "697b09", name: "Tlatelolco", lineNumber: "3", latitude: 19.45549884507741, longitude: -99.14504122737199),
        GTFSStation(id: "697b08", name: "Tolnáhuac", lineNumber: "3", latitude: 19.459812, longitude: -99.144138),
        GTFSStation(id: "697b1e", name: "Tres Anegas", lineNumber: "3", latitude: 19.51553462321563, longitude: -99.16193811033368)
    ]

    // MARK: - Line 4

    static let line4Stations: [GTFSStation] = [
        GTFSStation(id: "0c8439", name: "20 de Noviembre", lineNumber: "4", latitude: 19.429322293658252, longitude: -99.13431912552662),
        GTFSStation(id: "f8576d", name: "Alameda Ote", lineNumber: "4", latitude: 19.43076917615918, longitude: -99.05329763889314),
        GTFSStation(id: "f85848", name: "Alcaldía Cuauhtémoc", lineNumber: "4", latitude: 19.44264202839022, longitude: -99.15244122399686),
        GTFSStation(id: "605459", name: "Amajac L4", lineNumber: "4", latitude: 19.43383193025979, longitude: -99.15350496899691),
        GTFSStation(id: "f8577e", name: "Archivo General de la Nación L4", lineNumber: "4", latitude: 19.43544931937878, longitude: -99.11503985836133),
        GTFSStation(id: "f85837", name: "Bellas Artes", lineNumber: "4", latitude: 19.43634420642639, longitude: -99.1417623615778),
        GTFSStation(id: "f85824", name: "Buenavista L4", lineNumber: "4", latitude: 19.444814144304186, longitude: -99.15234348157216),
        GTFSStation(id: "f857b5", name: "Calle 6", lineNumber: "4", latitude: 19.42111460450559, longitude: -99.05823243898395),
        GTFSStation(id: "52920d", name: "Calle 6 (ret)", lineNumber: "4", latitude: 19.4207102532135, longitude: -99.05833846680133),
        GTFSStation(id: "f857b6", name: "Cecilio Robelo", lineNumber: "4", latitude: 19.42521243215105, longitude: -99.11983707591222),
        GTFSStation(id: "f85853", name: "Defensoría Pública", lineNumber: "4", latitude: 19.43337237650243, longitude: -99.15095560601901),
        GTFSStation(id: "f85852", name: "Eduardo Molina", lineNumber: "4", latitude: 19.42710898228862, longitude: -99.1155036140757),
        GTFSStation(id: "f8585b", name: "Eje Central", lineNumber: "4", latitude: 19.43040239487294, longitude: -99.14199297520497),
        GTFSStation(id: "f857e0", name: "El Salvador", lineNumber: "4", latitude: 19.429912154556657, longitude: -99.13856771740578),
        GTFSStation(id: "f85819", name: "Ferrocarril de Cintura", lineNumber: "4", latitude: 19.43609460222703, longitude: -99.12101701347626),
        GTFSStation(id: "f857fe", name: "Hidalgo L4", lineNumber: "4", latitude: 19.43733106081757, longitude: -99.14617726339026),
        GTFSStation(id: "b51170", name: "Hidalgo L4 E4", lineNumber: "4", latitude: 19.43739364834678, longitude: -99.14737343788148),
        GTFSStation(id: "f8582e", name: "Hospital Balbuena", lineNumber: "4", latitude: 19.42495641558283, longitude: -99.11475777626038),
        GTFSStation(id: "f857bc", name: "Isabel la Católica", lineNumber: "4", latitude: 19.4296932240978, longitude: -99.13697212746823),
        GTFSStation(id: "f857a8", name: "Juárez L4", lineNumber: "4", latitude: 19.43131325113527, longitude: -99.14829795870675),
        GTFSStation(id: "f85826", name: "La Merced", lineNumber: "4", latitude: 19.42551525423997, longitude: -99.12583078555878),
        GTFSStation(id: "f85766", name: "Las Cruces", lineNumber: "4", latitude: 19.4261255177746, longitude: -99.1298433777156),
        GTFSStation(id: "f857f2", name: "Mercado Sonora", lineNumber: "4", latitude: 19.42318936847668, longitude: -99.12342373346489),
        GTFSStation(id: "f85855", name: "Mercado Sonora Sur", lineNumber: "4", latitude: 19.42304905491438, longitude: -99.12647608102476),
        GTFSStation(id: "f857a6", name: "Mercados de San Juan", lineNumber: "4", latitude: 19.43081012718926, longitude: -99.14485271341727),
        GTFSStation(id: "f85810", name: "Mixcalco", lineNumber: "4", latitude: 19.43638874460046, longitude: -99.12364270645341),
        GTFSStation(id: "f8575d", name: "Moctezuma L4", lineNumber: "4", latitude: 19.42692317971025, longitude: -99.11182127679389),
        GTFSStation(id: "f85804", name: "Morelos", lineNumber: "4", latitude: 19.43581957366211, longitude: -99.11845579848658),
        GTFSStation(id: "f85756", name: "Museo San Carlos", lineNumber: "4", latitude: 19.43816830883542, longitude: -99.15030679248939),
        GTFSStation(id: "f857a3", name: "Museo de la Ciudad", lineNumber: "4", latitude: 19.42908847279102, longitude: -99.13272327093695),
        GTFSStation(id: "f857b7", name: "México Tenochtitlan", lineNumber: "4", latitude: 19.438900717911, longitude: -99.15328501597787),
        GTFSStation(id: "e9eed2", name: "Pantitlán", lineNumber: "4", latitude: 19.41711665692743, longitude: -99.0741678984773),
        GTFSStation(id: "f8577f", name: "Pino Suárez", lineNumber: "4", latitude: 19.42649257082538, longitude: -99.1326527704502),
        GTFSStation(id: "80cd40", name: "Pino Suárez Sur", lineNumber: "4", latitude: 19.4261060641545, longitude: -99.13392505946568),
        GTFSStation(id: "f85788", name: "Plaza de la República L4", lineNumber: "4", latitude: 19.43676089227536, longitude: -99.15416343718616),
        GTFSStation(id: "f857c0", name: "República de Argentina", lineNumber: "4", latitude: 19.43741414300866, longitude: -99.13148919519912),
        GTFSStation(id: "f85829", name: "República de Chile", lineNumber: "4", latitude: 19.43794863320294, longitude: -99.13531940895568),
        GTFSStation(id: "f85863", name: "San Lázaro L4 Ote", lineNumber: "4", latitude: 19.430488721403638, longitude: -99.11507985325706),
        GTFSStation(id: "f857d8", name: "San Lázaro L4 Pte", lineNumber: "4", latitude: 19.4305717391065, longitude: -99.11551448754211),
        GTFSStation(id: "b50ecd", name: "San Pablo", lineNumber: "4", latitude: 19.42533412257415, longitude: -99.13074089506867),
        GTFSStation(id: "f8578d", name: "Teatro Blanquita", lineNumber: "4", latitude: 19.43866066882829, longitude: -99.14010855045186),
        GTFSStation(id: "f85771", name: "Teatro del Pueblo", lineNumber: "4", latitude: 19.43684268841996, longitude: -99.12721494676526),
        GTFSStation(id: "f85770", name: "Terminal 1 AICM", lineNumber: "4", latitude: 19.43555227960734, longitude: -99.08328205347063),
        GTFSStation(id: "f857c3", name: "Terminal 2 AICM", lineNumber: "4", latitude: 19.42075, longitude: -99.07834),
        GTFSStation(id: "f8577a", name: "Vocacional 5", lineNumber: "4", latitude: 19.4315880176397, longitude: -99.15016276518435)
    ]

    // MARK: - Line 5

    static let line5Stations: [GTFSStation] = [
        GTFSStation(id: "078bbb", name: "314 Memorial New's Divine", lineNumber: "5", latitude: 19.500538931132954, longitude: -99.08845335245135),
        GTFSStation(id: "405dd7", name: "5 de Mayo", lineNumber: "5", latitude: 19.496981499237922, longitude: -99.08995270729065),
        GTFSStation(id: "25e233", name: "Aculco", lineNumber: "5", latitude: 19.37466562527648, longitude: -99.10780695925321),
        GTFSStation(id: "40f471", name: "Apatlaco", lineNumber: "5", latitude: 19.37830005600095, longitude: -99.10905517335338),
        GTFSStation(id: "f8580d", name: "Archivo General de la Nación L5", lineNumber: "5", latitude: 19.437044, longitude: -99.114475),
        GTFSStation(id: "f8581d", name: "Atanasio G. Sarabia", lineNumber: "5", latitude: 19.36121360528121, longitude: -99.11033997955424),
        GTFSStation(id: "f8580b", name: "Avenida del Taller", lineNumber: "5", latitude: 19.41259082641491, longitude: -99.11279134212441),
        GTFSStation(id: "f857c9", name: "Barrio San Antonio", lineNumber: "5", latitude: 19.34306244864715, longitude: -99.11244034767152),
        GTFSStation(id: "f8584f", name: "Cafetales", lineNumber: "5", latitude: 19.33393993789333, longitude: -99.1130847862855),
        GTFSStation(id: "f8582b", name: "Calzada Taxqueña", lineNumber: "5", latitude: 19.3386548846335, longitude: -99.11293345965639),
        GTFSStation(id: "f85844", name: "Calzada del Hueso", lineNumber: "5", latitude: 19.30136718287264, longitude: -99.11347565552525),
        GTFSStation(id: "2db7b5", name: "Canal Apatlaco", lineNumber: "5", latitude: 19.382867144532945, longitude: -99.1108337044716),
        GTFSStation(id: "f85841", name: "Canal del Norte", lineNumber: "5", latitude: 19.449551722331528, longitude: -99.1104394197464),
        GTFSStation(id: "f85827", name: "Cañaverales", lineNumber: "5", latitude: 19.295663729437415, longitude: -99.11447882652284),
        GTFSStation(id: "2db7c3", name: "Churubusco Oriente", lineNumber: "5", latitude: 19.3715996525542, longitude: -99.10773758942223),
        GTFSStation(id: "f85755", name: "Circuito Cuemanco", lineNumber: "5", latitude: 19.281266236817235, longitude: -99.11672383546832),
        GTFSStation(id: "25e227", name: "Colegio de Bachilleres 3", lineNumber: "5", latitude: 19.38626261956645, longitude: -99.11157667636873),
        GTFSStation(id: "f857e5", name: "DIF Xochimilco", lineNumber: "5", latitude: 19.276941, longitude: -99.118419),
        GTFSStation(id: "f85781", name: "Deportivo Eduardo Molina", lineNumber: "5", latitude: 19.444739, longitude: -99.1122),
        GTFSStation(id: "f85820", name: "ESIME Culhuacán", lineNumber: "5", latitude: 19.329185458249384, longitude: -99.11354273557664),
        GTFSStation(id: "405e23", name: "El Coyol", lineNumber: "5", latitude: 19.48746681775229, longitude: -99.09398943185809),
        GTFSStation(id: "f857d4", name: "Ermita-Iztapalapa", lineNumber: "5", latitude: 19.35669502918896, longitude: -99.11128372286947),
        GTFSStation(id: "f857bb", name: "Escuadrón 201", lineNumber: "5", latitude: 19.366043065031867, longitude: -99.10920292139055),
        GTFSStation(id: "40f477", name: "Ganaderos", lineNumber: "5", latitude: 19.35058848387328, longitude: -99.11075660798332),
        GTFSStation(id: "f85747", name: "Hospital General Troncoso", lineNumber: "5", latitude: 19.40571073731026, longitude: -99.11357273352769),
        GTFSStation(id: "f8576b", name: "La Virgen", lineNumber: "5", latitude: 19.32056281851342, longitude: -99.11351641089671),
        GTFSStation(id: "f85768", name: "Las Bombas", lineNumber: "5", latitude: 19.31175208539649, longitude: -99.11071672556673),
        GTFSStation(id: "f857d7", name: "Manuela Sáenz", lineNumber: "5", latitude: 19.324219522471914, longitude: -99.11397457122804),
        GTFSStation(id: "f85802", name: "Mercado Morelos", lineNumber: "5", latitude: 19.441197, longitude: -99.11353),
        GTFSStation(id: "2db7a4", name: "Metro Coyuya L5", lineNumber: "5", latitude: 19.39923750658907, longitude: -99.11344095049589),
        GTFSStation(id: "f85752", name: "Mixiuhca", lineNumber: "5", latitude: 19.40810448063398, longitude: -99.11324457756353),
        GTFSStation(id: "f857b0", name: "Moctezuma L5", lineNumber: "5", latitude: 19.42576400502085, longitude: -99.11138950983884),
        GTFSStation(id: "f857ba", name: "Muyuguarda", lineNumber: "5", latitude: 19.28500560533537, longitude: -99.1155517101288),
        GTFSStation(id: "405e42", name: "Oriente 101", lineNumber: "5", latitude: 19.46082627614275, longitude: -99.10540491342546),
        GTFSStation(id: "40f461", name: "Oriente 116", lineNumber: "5", latitude: 19.390234881259808, longitude: -99.11256641149522),
        GTFSStation(id: "f857da", name: "Preparatoria 1", lineNumber: "5", latitude: 19.273470758768216, longitude: -99.12054598331451),
        GTFSStation(id: "c98cf8", name: "Preparatoria 3", lineNumber: "5", latitude: 19.483317402063772, longitude: -99.09581601619722),
        GTFSStation(id: "f857f6", name: "Pueblo de los Reyes", lineNumber: "5", latitude: 19.348045526479225, longitude: -99.11132454872133),
        GTFSStation(id: "405e4f", name: "Recreo", lineNumber: "5", latitude: 19.39381995397841, longitude: -99.11355882883075),
        GTFSStation(id: "25e216", name: "Río Consulado", lineNumber: "5", latitude: 19.453590722786963, longitude: -99.10833120346071),
        GTFSStation(id: "dd52c3", name: "Río Santa Coleta", lineNumber: "5", latitude: 19.455995865643047, longitude: -99.10739511251451),
        GTFSStation(id: "2db784", name: "Río de Guadalupe", lineNumber: "5", latitude: 19.475956415894355, longitude: -99.09893810749055),
        GTFSStation(id: "f85794", name: "Río de los Remedios", lineNumber: "5", latitude: 19.507095255392926, longitude: -99.08594052810977),
        GTFSStation(id: "25e1ff", name: "San Juan de Aragón L5", lineNumber: "5", latitude: 19.479853152749996, longitude: -99.09727782011034),
        GTFSStation(id: "f8579c", name: "San Lázaro Norte L5", lineNumber: "5", latitude: 19.43121594141721, longitude: -99.11515242426117),
        GTFSStation(id: "f85760", name: "San Lázaro Sur L5", lineNumber: "5", latitude: 19.43037834048882, longitude: -99.11533134204778),
        GTFSStation(id: "c98d0a", name: "Talismán L5", lineNumber: "5", latitude: 19.470931737560875, longitude: -99.1011402010918),
        GTFSStation(id: "f85836", name: "Tepetlapa", lineNumber: "5", latitude: 19.316188158106197, longitude: -99.11163028924663),
        GTFSStation(id: "c98cea", name: "Vasco de Quiroga", lineNumber: "5", latitude: 19.49321665493636, longitude: -99.09156471490863),
        GTFSStation(id: "f857a5", name: "Venustiano Carranza", lineNumber: "5", latitude: 19.41872745676672, longitude: -99.11214699343756),
        GTFSStation(id: "25e20b", name: "Victoria", lineNumber: "5", latitude: 19.46719808467222, longitude: -99.10268880978849),
        GTFSStation(id: "f8585a", name: "Vista Hermosa", lineNumber: "5", latitude: 19.306566691558544, longitude: -99.11189851986266)
    ]

    // MARK: - Line 6

    static let line6Stations: [GTFSStation] = [
        GTFSStation(id: "f857f1", name: "414", lineNumber: "6", latitude: 19.46836192099835, longitude: -99.07161503265114),
        GTFSStation(id: "f857ce", name: "416 Oriente", lineNumber: "6", latitude: 19.47106083272982, longitude: -99.07092862579692),
        GTFSStation(id: "f85806", name: "416 Poniente", lineNumber: "6", latitude: 19.4724713707306, longitude: -99.0794027464215),
        GTFSStation(id: "f8577b", name: "482", lineNumber: "6", latitude: 19.46688044841875, longitude: -99.07562037747935),
        GTFSStation(id: "f85757", name: "Ampliación Providencia", lineNumber: "6", latitude: 19.47980574028463, longitude: -99.0752573857366),
        GTFSStation(id: "f857fd", name: "Casas Alemán", lineNumber: "6", latitude: 19.47422035185774, longitude: -99.0883446948742),
        GTFSStation(id: "f8575f", name: "Colegio de Bachilleres 1", lineNumber: "6", latitude: 19.5115585384633, longitude: -99.19729620587957),
        GTFSStation(id: "f8585f", name: "Colegio de Bachilleres 9", lineNumber: "6", latitude: 19.4697695512927, longitude: -99.06486888101176),
        GTFSStation(id: "f85816", name: "De Las Culturas", lineNumber: "6", latitude: 19.51087684218516, longitude: -99.19268009410874),
        GTFSStation(id: "f8579d", name: "De los Misterios L6", lineNumber: "6", latitude: 19.48709536774331, longitude: -99.11798604802378),
        GTFSStation(id: "f857cf", name: "Dep. 18 Mzo. L6", lineNumber: "6", latitude: 19.486493320266753, longitude: -99.12228405475616),
        GTFSStation(id: "f857e7", name: "Deportivo los Galeana", lineNumber: "6", latitude: 19.4786245680706, longitude: -99.07798975266768),
        GTFSStation(id: "f857cb", name: "El Rosario", lineNumber: "6", latitude: 19.507206060826725, longitude: -99.1995370388031),
        GTFSStation(id: "f857f8", name: "Ferrocarriles Nacionales", lineNumber: "6", latitude: 19.50487858685309, longitude: -99.18879344579429),
        GTFSStation(id: "f8583b", name: "Francisco Morazán", lineNumber: "6", latitude: 19.4669759456913, longitude: -99.06181046443874),
        GTFSStation(id: "f85789", name: "Gran Canal", lineNumber: "6", latitude: 19.47699305175776, longitude: -99.0927986205793),
        GTFSStation(id: "f85776", name: "Gustavo A. Madero L6", lineNumber: "6", latitude: 19.48381020629003, longitude: -99.11221179986907),
        GTFSStation(id: "f85778", name: "Hospital General La Villa", lineNumber: "6", latitude: 19.48028459853183, longitude: -99.10118809388028),
        GTFSStation(id: "f857f4", name: "Hospital Infantil La Villa L6", lineNumber: "6", latitude: 19.48805527433594, longitude: -99.11475284998424),
        GTFSStation(id: "f857c7", name: "Instituto Politécnico Nacional", lineNumber: "6", latitude: 19.49039966973826, longitude: -99.13270661839263),
        GTFSStation(id: "f8579b", name: "Instituto del Petróleo", lineNumber: "6", latitude: 19.493120426408, longitude: -99.14518007013932),
        GTFSStation(id: "f85786", name: "La Pradera", lineNumber: "6", latitude: 19.47309234223951, longitude: -99.06868963967442),
        GTFSStation(id: "f8574a", name: "La Villa", lineNumber: "6", latitude: 19.48538679588978, longitude: -99.11961923523324),
        GTFSStation(id: "f857cd", name: "Lindavista - Vallejo", lineNumber: "6", latitude: 19.49383965743074, longitude: -99.14814729049552),
        GTFSStation(id: "f85849", name: "Loreto Fabela", lineNumber: "6", latitude: 19.4672977345385, longitude: -99.08093376225192),
        GTFSStation(id: "f85828", name: "Martín Carrera", lineNumber: "6", latitude: 19.48199187801027, longitude: -99.10537962971588),
        GTFSStation(id: "bfc9a0", name: "Montevideo L6", lineNumber: "6", latitude: 19.49486140385348, longitude: -99.15306176315282),
        GTFSStation(id: "f85772", name: "Norte 45", lineNumber: "6", latitude: 19.49643830173505, longitude: -99.1599112622329),
        GTFSStation(id: "f85813", name: "Norte 59", lineNumber: "6", latitude: 19.49761176458131, longitude: -99.16563234198806),
        GTFSStation(id: "f857b8", name: "Pueblo de San Juan de Aragón", lineNumber: "6", latitude: 19.47106893633869, longitude: -99.0864483538664),
        GTFSStation(id: "f857f9", name: "Riobamba", lineNumber: "6", latitude: 19.48863235378676, longitude: -99.127932685765),
        GTFSStation(id: "f8581e", name: "San Bartolo", lineNumber: "6", latitude: 19.49193756664191, longitude: -99.13911487710753),
        GTFSStation(id: "f85821", name: "San Juan de Aragón L6", lineNumber: "6", latitude: 19.47869542400452, longitude: -99.09721891185188),
        GTFSStation(id: "f85799", name: "Tecnoparque", lineNumber: "6", latitude: 19.50247870799058, longitude: -99.1789631534656),
        GTFSStation(id: "f8581f", name: "UAM Azcapotzalco", lineNumber: "6", latitude: 19.50396096719146, longitude: -99.1838580942578),
        GTFSStation(id: "f857d9", name: "Villa de Aragón", lineNumber: "6", latitude: 19.46495633358672, longitude: -99.0596044614896),
        GTFSStation(id: "f8580f", name: "Volcán de Fuego", lineNumber: "6", latitude: 19.47707526470618, longitude: -99.07262158696162)
    ]

    // MARK: - Line 7

    static let line7Stations: [GTFSStation] = [
        GTFSStation(id: "59aee2", name: "Amajac L7", lineNumber: "7", latitude: 19.43341099204709, longitude: -99.15433896624667),
        GTFSStation(id: "f85746", name: "Antropología", lineNumber: "7", latitude: 19.4247146195983, longitude: -99.18433425390691),
        GTFSStation(id: "f85838", name: "Auditorio", lineNumber: "7", latitude: 19.42630298441012, longitude: -99.19468150478026),
        GTFSStation(id: "f8583c", name: "Av. Talismán", lineNumber: "7", latitude: 19.47908069711129, longitude: -99.1209256469118),
        GTFSStation(id: "f85783", name: "Campo Marte", lineNumber: "7", latitude: 19.427038112725555, longitude: -99.19942208052352),
        GTFSStation(id: "f85751", name: "Chapultepec", lineNumber: "7", latitude: 19.42404736609939, longitude: -99.17422532408303),
        GTFSStation(id: "f8584a", name: "Clave", lineNumber: "7", latitude: 19.46488002944004, longitude: -99.1262639400496),
        GTFSStation(id: "f857c1", name: "De los Misterios L7", lineNumber: "7", latitude: 19.487148293692538, longitude: -99.11790728223045),
        GTFSStation(id: "749a60", name: "El Ahuehuete", lineNumber: "7", latitude: 19.42842709003128, longitude: -99.16486729350108),
        GTFSStation(id: "f85785", name: "El Caballito", lineNumber: "7", latitude: 19.43598752723021, longitude: -99.14911712743891),
        GTFSStation(id: "f85780", name: "El Ángel", lineNumber: "7", latitude: 19.42662910664687, longitude: -99.16865225057253),
        GTFSStation(id: "f85831", name: "Excélsior", lineNumber: "7", latitude: 19.472163, longitude: -99.123487),
        GTFSStation(id: "f857e1", name: "Gandhi", lineNumber: "7", latitude: 19.42407365689417, longitude: -99.1800952806228),
        GTFSStation(id: "f85800", name: "Garibaldi", lineNumber: "7", latitude: 19.44423650585254, longitude: -99.13961973294639),
        GTFSStation(id: "f8576e", name: "Garrido", lineNumber: "7", latitude: 19.48334381404806, longitude: -99.11930974316489),
        GTFSStation(id: "b315cb", name: "Glorieta Cuitláhuac Nte", lineNumber: "7", latitude: 19.44921043641418, longitude: -99.13409682333013),
        GTFSStation(id: "b46d55", name: "Glorieta Cuitláhuac Sur", lineNumber: "7", latitude: 19.44744881725725, longitude: -99.1357418260385),
        GTFSStation(id: "f8575e", name: "Glorieta de Violeta", lineNumber: "7", latitude: 19.44153753371875, longitude: -99.14223668378563),
        GTFSStation(id: "f857b3", name: "Gustavo A. Madero L7", lineNumber: "7", latitude: 19.48365291144993, longitude: -99.11387753581162),
        GTFSStation(id: "f85743", name: "Hamburgo L7", lineNumber: "7", latitude: 19.42995356797701, longitude: -99.16159558715809),
        GTFSStation(id: "f85833", name: "Hidalgo L7", lineNumber: "7", latitude: 19.43772942933604, longitude: -99.14643753385796),
        GTFSStation(id: "f8578f", name: "Hospital Infantil La Villa L7", lineNumber: "7", latitude: 19.487251676336573, longitude: -99.11379524856724),
        GTFSStation(id: "f857fb", name: "Indios Verdes L7", lineNumber: "7", latitude: 19.493247049086236, longitude: -99.1209780575117),
        GTFSStation(id: "f8580a", name: "La Diana", lineNumber: "7", latitude: 19.4255894802327, longitude: -99.1709642675253),
        GTFSStation(id: "f8582d", name: "Mercado Beethoven", lineNumber: "7", latitude: 19.45760857324631, longitude: -99.12904435428398),
        GTFSStation(id: "f85795", name: "Misterios", lineNumber: "7", latitude: 19.46252558654364, longitude: -99.12715567292256),
        GTFSStation(id: "f85787", name: "Necaxa", lineNumber: "7", latitude: 19.4755833535742, longitude: -99.1222281914489),
        GTFSStation(id: "f857c5", name: "París", lineNumber: "7", latitude: 19.43256639378335, longitude: -99.15611023333271),
        GTFSStation(id: "f85784", name: "Peralvillo", lineNumber: "7", latitude: 19.45374215771039, longitude: -99.13062880709771),
        GTFSStation(id: "f85754", name: "Reforma L7", lineNumber: "7", latitude: 19.43139462535771, longitude: -99.15878777412368),
        GTFSStation(id: "f857c4", name: "Robles Domínguez", lineNumber: "7", latitude: 19.468559433136587, longitude: -99.12507562024805),
        GTFSStation(id: "f85858", name: "Tres Culturas", lineNumber: "7", latitude: 19.45088155847964, longitude: -99.13277779993668)
    ]

}

struct GTFSStation: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let lineNumber: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var displayName: String { name }
    var lineDisplayName: String { "Linea \(lineNumber)" }
    
    func toCommuteStation() -> CommuteStation {
        CommuteStation(id: id, name: name, lineNumber: lineNumber, latitude: latitude, longitude: longitude)
    }
}

