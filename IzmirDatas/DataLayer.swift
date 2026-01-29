import Foundation

enum DatasetKey: String, CaseIterable {
    case vehiclePositions = "hatta-ait-otobuslerin-anlik-konum-bilgileri"
    case routes = "eshot-otobus-hat-listesi"
    case stops = "eshot-otobus-duraklari"
    case timetable = "otobus-hareket-saatleri"
}

struct Route: Identifiable, Codable, Hashable {
    var id: String { number }
    let number: String
    let name: String
    let from: String?
    let to: String?
}

struct Stop: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let passingRouteNumbers: [String]
}

struct VehiclePosition: Identifiable, Codable, Hashable {
    let id: String
    let latitude: Double
    let longitude: Double
    let routeNumber: String?
    let lastUpdated: Date?
}

enum ServiceDay: String, Codable, CaseIterable {
    case weekday
    case saturday
    case sunday
}

enum Direction: String, Codable, CaseIterable {
    case outbound
    case inbound
}

struct TimetableEntry: Identifiable, Codable, Hashable {
    let id: String
    let routeNumber: String
    let stopId: String?
    let serviceDay: ServiceDay
    let direction: Direction
    let time: String
    let sequence: Int?
    let wheelchairAccessible: Bool?
    let bikeRack: Bool?
    let electric: Bool?
}

enum DataLayerError: Error, LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case ckanNoResource(dataset: String)
    case cannotDecode

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Geçersiz URL."
        case .httpStatus(let code): "HTTP hata kodu: \(code)"
        case .ckanNoResource(let dataset): "Veri seti için indirilebilir kaynak bulunamadı: \(dataset)"
        case .cannotDecode: "Yanıt çözümlenemedi."
        }
    }
}

final class APIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else { throw DataLayerError.httpStatus(http.statusCode) }
        return data
    }
}

struct CKANPackageShowResponse: Decodable {
    struct Result: Decodable {
        struct Resource: Decodable {
            let url: String
            let format: String?
            let name: String?
        }

        let resources: [Resource]
    }

    let success: Bool
    let result: Result
}

final class CKANResolver {
    private let apiClient: APIClient
    private var resolvedResourceURLByDataset: [String: URL] = [:]

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func resolveBestResourceURL(datasetID: String, preferredFormats: [String] = ["JSON", "CSV", "API"]) async throws -> URL {
        if let url = resolvedResourceURLByDataset[datasetID] {
            return url
        }

        guard var components = URLComponents(string: "https://acikveri.bizizmir.com/api/3/action/package_show") else {
            throw DataLayerError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "id", value: datasetID)]
        guard let url = components.url else { throw DataLayerError.invalidURL }

        let data = try await apiClient.get(url: url)
        let decoded = try JSONDecoder().decode(CKANPackageShowResponse.self, from: data)

        let preferred = preferredFormats.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        let resources = decoded.result.resources

        func score(_ r: CKANPackageShowResponse.Result.Resource) -> Int {
            let format = (r.format ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if let idx = preferred.firstIndex(of: format) { return 100 - idx }
            if format.contains("JSON") { return 80 }
            if format.contains("CSV") { return 70 }
            if format.contains("API") { return 60 }
            return 0
        }

        guard let best = resources.max(by: { score($0) < score($1) }) else {
            throw DataLayerError.ckanNoResource(dataset: datasetID)
        }

        guard let bestURL = URL(string: best.url) else { throw DataLayerError.invalidURL }
        resolvedResourceURLByDataset[datasetID] = bestURL
        return bestURL
    }
}

struct CSVTable {
    let headers: [String]
    let rows: [[String: String]]
}

enum CSVParser {
    static func parse(data: Data, encoding: String.Encoding = .utf8) throws -> CSVTable {
        guard let string = String(data: data, encoding: encoding) else { throw DataLayerError.cannotDecode }
        let lines = splitCSVLines(string)
        guard let headerLine = lines.first else { return CSVTable(headers: [], rows: []) }

        let headers = parseCSVLine(headerLine)
        var rows: [[String: String]] = []
        rows.reserveCapacity(max(0, lines.count - 1))

        for line in lines.dropFirst() {
            let values = parseCSVLine(line)
            guard !values.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { continue }
            var row: [String: String] = [:]
            for (idx, header) in headers.enumerated() {
                row[header] = idx < values.count ? values[idx] : ""
            }
            rows.append(row)
        }

        return CSVTable(headers: headers, rows: rows)
    }

    private static func splitCSVLines(_ input: String) -> [String] {
        input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let ch = iterator.next() {
            if ch == "\"" {
                if inQuotes {
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else if next == "," || next == ";" {
                            inQuotes = false
                            result.append(current)
                            current = ""
                        } else {
                            inQuotes = false
                            current.append(next)
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
                continue
            }

            if !inQuotes && (ch == "," || ch == ";") {
                result.append(current)
                current = ""
                continue
            }

            current.append(ch)
        }

        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

enum KeyNormalizer {
    static func normalize(_ input: String) -> String {
        let lowered = input.lowercased()
        let folded = lowered.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let cleaned = folded
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ü", with: "u")
        let allowed = cleaned.map { ch -> Character in
            if ch.isLetter || ch.isNumber { return ch }
            return "_"
        }
        return String(allowed).replacingOccurrences(of: "__", with: "_")
    }
}

final class DatasetsRepository {
    private let apiClient: APIClient
    private let resolver: CKANResolver
    private let persistence: PersistenceController

    init(apiClient: APIClient = APIClient(), persistence: PersistenceController = .shared) {
        self.apiClient = apiClient
        self.resolver = CKANResolver(apiClient: apiClient)
        self.persistence = persistence
    }

    func fetchRoutes(forceRefresh: Bool = false) async throws -> [Route] {
        let key = DatasetKey.routes.rawValue
        if !forceRefresh, let cached = try loadCached([Route].self, datasetKey: key, ttl: 24 * 60 * 60) {
            return cached
        }

        let url = try await resolver.resolveBestResourceURL(datasetID: key, preferredFormats: ["CSV", "JSON"])
        let data = try await apiClient.get(url: url)

        let routes = try decodeRoutes(data: data, url: url)
        try saveCached(routes, datasetKey: key)
        return routes.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
    }

    func fetchStops(forceRefresh: Bool = false) async throws -> [Stop] {
        let key = DatasetKey.stops.rawValue
        if !forceRefresh, let cached = try loadCached([Stop].self, datasetKey: key, ttl: 12 * 60 * 60) {
            return cached
        }

        let url = try await resolver.resolveBestResourceURL(datasetID: key, preferredFormats: ["CSV", "JSON"])
        let data = try await apiClient.get(url: url)

        let stops = try decodeStops(data: data, url: url)
        try saveCached(stops, datasetKey: key)
        return stops
    }

    func fetchTimetable(forceRefresh: Bool = false) async throws -> [TimetableEntry] {
        let key = DatasetKey.timetable.rawValue
        if !forceRefresh, let cached = try loadCached([TimetableEntry].self, datasetKey: key, ttl: 12 * 60 * 60) {
            return cached
        }

        let url = try await resolver.resolveBestResourceURL(datasetID: key, preferredFormats: ["CSV", "JSON"])
        let data = try await apiClient.get(url: url)

        let entries = try decodeTimetable(data: data, url: url)
        try saveCached(entries, datasetKey: key)
        return entries
    }

    func fetchVehiclePositions() async throws -> [VehiclePosition] {
        let key = DatasetKey.vehiclePositions.rawValue
        let url = try await resolver.resolveBestResourceURL(datasetID: key, preferredFormats: ["JSON", "CSV", "API"])
        let data = try await apiClient.get(url: url)
        return try decodeVehiclePositions(data: data, url: url)
    }

    private func loadCached<T: Decodable>(_ type: T.Type, datasetKey: String, ttl: TimeInterval) throws -> T? {
        guard let cached = try persistence.loadDatasetPayload(datasetKey: datasetKey) else { return nil }
        guard Date().timeIntervalSince(cached.lastUpdated) <= ttl else { return nil }
        return try JSONDecoder().decode(T.self, from: cached.payload)
    }

    private func saveCached<T: Encodable>(_ value: T, datasetKey: String) throws {
        let data = try JSONEncoder().encode(value)
        try persistence.saveDatasetPayload(datasetKey: datasetKey, payload: data, lastUpdated: Date())
    }

    private func decodeRoutes(data: Data, url: URL) throws -> [Route] {
        if url.pathExtension.lowercased() == "json" {
            return try JSONDecoder().decode([Route].self, from: data)
        }

        let table = try CSVParser.parse(data: data)
        return table.rows.compactMap { row in
            let normalized = Dictionary(uniqueKeysWithValues: row.map { (KeyNormalizer.normalize($0.key), $0.value) })
            let number = firstNonEmpty(normalized, keys: ["hat_no", "hatnumarasi", "hat_numarasi", "hat", "line", "line_no"])
            let name = firstNonEmpty(normalized, keys: ["hat_adi", "hatadi", "hat_adi_aciklama", "ad", "name"])
            if number.isEmpty || name.isEmpty { return nil }
            let from = firstNonEmpty(normalized, keys: ["baslangic", "baslangic_noktasi", "kalkis", "from"])
            let to = firstNonEmpty(normalized, keys: ["bitis", "bitis_noktasi", "varis", "to"])
            return Route(number: number, name: name, from: from.isEmpty ? nil : from, to: to.isEmpty ? nil : to)
        }
    }

    private func decodeStops(data: Data, url: URL) throws -> [Stop] {
        if url.pathExtension.lowercased() == "json" {
            return try JSONDecoder().decode([Stop].self, from: data)
        }

        let table = try CSVParser.parse(data: data)
        return table.rows.compactMap { row in
            let normalized = Dictionary(uniqueKeysWithValues: row.map { (KeyNormalizer.normalize($0.key), $0.value) })
            let id = firstNonEmpty(normalized, keys: ["durak_id", "durakno", "durak_kodu", "id", "stop_id", "stopcode"])
            let name = firstNonEmpty(normalized, keys: ["durak_adi", "durakadi", "ad", "name", "stop_name"])
            let latString = firstNonEmpty(normalized, keys: ["enlem", "lat", "latitude", "y"])
            let lonString = firstNonEmpty(normalized, keys: ["boylam", "lon", "lng", "longitude", "x"])

            guard
                let lat = Double(latString.replacingOccurrences(of: ",", with: ".")),
                let lon = Double(lonString.replacingOccurrences(of: ",", with: "."))
            else { return nil }

            let routesString = firstNonEmpty(normalized, keys: ["hatlar", "hat_numaralari", "duraktan_gecen_hatlar", "passing_routes", "routes"])
            let passing = routesString
                .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "|" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if id.isEmpty || name.isEmpty { return nil }
            return Stop(id: id, name: name, latitude: lat, longitude: lon, passingRouteNumbers: passing)
        }
    }

    private func decodeTimetable(data: Data, url: URL) throws -> [TimetableEntry] {
        if url.pathExtension.lowercased() == "json" {
            return try JSONDecoder().decode([TimetableEntry].self, from: data)
        }

        let table = try CSVParser.parse(data: data)
        return table.rows.compactMap { row in
            let normalized = Dictionary(uniqueKeysWithValues: row.map { (KeyNormalizer.normalize($0.key), $0.value) })
            let routeNumber = firstNonEmpty(normalized, keys: ["hat_no", "hatnumarasi", "hat_numarasi", "hat", "line", "line_no"])
            if routeNumber.isEmpty { return nil }

            let dayRaw = firstNonEmpty(normalized, keys: ["calisma_gunu", "gun", "gun_tipi", "day_type", "workday"])
            let serviceDay = parseServiceDay(dayRaw)

            let directionRaw = firstNonEmpty(normalized, keys: ["yon", "guzergah", "gidis_donus", "direction"])
            let direction = parseDirection(directionRaw)

            let time = firstNonEmpty(normalized, keys: ["saat", "hareket_saati", "time", "departure_time"])
            if time.isEmpty { return nil }

            let stopId = firstNonEmpty(normalized, keys: ["durak_id", "durakno", "durak_kodu", "stop_id"])
            let sequence = Int(firstNonEmpty(normalized, keys: ["sefer_sira_no", "sira", "sequence", "order"]))

            let wheelchair = parseBool(firstNonEmpty(normalized, keys: ["engelli_aparati", "wheelchair", "accessible"]))
            let bike = parseBool(firstNonEmpty(normalized, keys: ["bisiklet_aparati", "bike", "bikerack"]))
            let electric = parseBool(firstNonEmpty(normalized, keys: ["elektrikli", "electric"]))

            return TimetableEntry(
                id: "\(routeNumber)|\(stopId)|\(serviceDay.rawValue)|\(direction.rawValue)|\(time)|\(sequence ?? -1)",
                routeNumber: routeNumber,
                stopId: stopId.isEmpty ? nil : stopId,
                serviceDay: serviceDay,
                direction: direction,
                time: time,
                sequence: sequence,
                wheelchairAccessible: wheelchair,
                bikeRack: bike,
                electric: electric
            )
        }
    }

    private func decodeVehiclePositions(data: Data, url: URL) throws -> [VehiclePosition] {
        if url.pathExtension.lowercased() == "json" {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode([VehiclePosition].self, from: data) {
                return decoded
            }
        }

        let table = try CSVParser.parse(data: data)
        return table.rows.compactMap { row in
            let normalized = Dictionary(uniqueKeysWithValues: row.map { (KeyNormalizer.normalize($0.key), $0.value) })
            let id = firstNonEmpty(normalized, keys: ["arac_id", "aracid", "vehicle_id", "id", "plaka"])
            let latString = firstNonEmpty(normalized, keys: ["enlem", "lat", "latitude", "y"])
            let lonString = firstNonEmpty(normalized, keys: ["boylam", "lon", "lng", "longitude", "x"])
            guard
                let lat = Double(latString.replacingOccurrences(of: ",", with: ".")),
                let lon = Double(lonString.replacingOccurrences(of: ",", with: "."))
            else { return nil }

            let routeNumber = firstNonEmpty(normalized, keys: ["hat_no", "hat", "line", "route", "route_no"])
            let timestampString = firstNonEmpty(normalized, keys: ["tarih", "zaman", "timestamp", "last_updated", "son_guncelleme"])
            let lastUpdated = parseDate(timestampString)
            let finalID = id.isEmpty ? "\(lat)|\(lon)|\(timestampString)" : id

            return VehiclePosition(id: finalID, latitude: lat, longitude: lon, routeNumber: routeNumber.isEmpty ? nil : routeNumber, lastUpdated: lastUpdated)
        }
    }

    private func firstNonEmpty(_ row: [String: String], keys: [String]) -> String {
        for key in keys {
            if let value = row[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private func parseServiceDay(_ value: String) -> ServiceDay {
        let v = KeyNormalizer.normalize(value)
        if v.contains("cumartesi") || v.contains("saturday") { return .saturday }
        if v.contains("pazar") || v.contains("sunday") { return .sunday }
        return .weekday
    }

    private func parseDirection(_ value: String) -> Direction {
        let v = KeyNormalizer.normalize(value)
        if v.contains("donus") || v.contains("inbound") || v.contains("return") { return .inbound }
        return .outbound
    }

    private func parseBool(_ value: String) -> Bool? {
        let v = KeyNormalizer.normalize(value)
        if v.isEmpty { return nil }
        if ["1", "true", "evet", "var", "yes"].contains(v) { return true }
        if ["0", "false", "hayir", "yok", "no"].contains(v) { return false }
        return nil
    }

    private func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: trimmed) { return d }

        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: trimmed) { return d }
        }
        return nil
    }
}
