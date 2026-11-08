import Foundation

// GPX 1.1 export/import (brief §7). Export forces the Run object to validate
// against a real standard from day one. Import exists so recorded or
// synthetic tracks can be replayed through the cleaner in tests.

public enum GPX {
    static let namespace = "http://www.topografix.com/GPX/1/1"
    /// Custom extension namespace for provenance fields other tools can ignore.
    static let extNamespace = "urn:runwith:gpx:1"

    private static func isoFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    public static func export(_ run: Run, name: String? = nil) -> String {
        let iso = isoFormatter()
        let trackName = escape(name ?? "Run With \(iso.string(from: run.startedAt))")
        var out = ""
        out += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        out += "<gpx version=\"1.1\" creator=\"Run With\" xmlns=\"\(namespace)\" xmlns:rw=\"\(extNamespace)\" "
        out += "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" "
        out += "xsi:schemaLocation=\"\(namespace) http://www.topografix.com/GPX/1/1/gpx.xsd\">\n"
        out += "  <metadata>\n    <name>\(trackName)</name>\n    <time>\(iso.string(from: run.startedAt))</time>\n  </metadata>\n"
        out += "  <trk>\n    <name>\(trackName)</name>\n    <trkseg>\n"
        for p in run.geoPoints {
            guard let lat = p.lat, let lng = p.lng else { continue }
            let time = run.startedAt.addingTimeInterval(Double(p.t) / 1000)
            out += "      <trkpt lat=\"\(fmt(lat, 7))\" lon=\"\(fmt(lng, 7))\">\n"
            if let ele = p.elevationM { out += "        <ele>\(fmt(ele, 1))</ele>\n" }
            out += "        <time>\(iso.string(from: time))</time>\n"
            out += "        <extensions>\n"
            out += "          <rw:speed>\(fmt(p.speedMps, 3))</rw:speed>\n"
            out += "          <rw:distance>\(fmt(p.distanceM, 1))</rw:distance>\n"
            out += "          <rw:source>\(p.source.rawValue)</rw:source>\n"
            out += "          <rw:fidelity>\(p.fidelity.rawValue)</rw:fidelity>\n"
            if let c = p.cadenceSpm { out += "          <rw:cadence>\(fmt(c, 1))</rw:cadence>\n" }
            out += "        </extensions>\n"
            out += "      </trkpt>\n"
        }
        out += "    </trkseg>\n  </trk>\n</gpx>\n"
        return out
    }

    /// Parses trkpt lat/lon/ele/time into `LocationFix`es. GPX carries no
    /// accuracy, so the caller states what to assume.
    public static func parseFixes(_ data: Data, assumedAccuracyM: Double = 5) throws -> [LocationFix] {
        let parser = TrackParser(assumedAccuracyM: assumedAccuracyM)
        return try parser.parse(data)
    }

    private static func fmt(_ v: Double, _ decimals: Int) -> String {
        String(format: "%.\(decimals)f", v)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private final class TrackParser: NSObject, XMLParserDelegate {
    private let assumedAccuracyM: Double
    private var fixes: [LocationFix] = []
    private var curLat: Double?
    private var curLng: Double?
    private var curEle: Double?
    private var curTime: Date?
    private var text = ""
    private var error: Error?
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(assumedAccuracyM: Double) {
        self.assumedAccuracyM = assumedAccuracyM
    }

    func parse(_ data: Data) throws -> [LocationFix] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        if !parser.parse(), let e = parser.parserError { throw e }
        if let error { throw error }
        return fixes
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        if name == "trkpt" {
            curLat = attributes["lat"].flatMap(Double.init)
            curLng = attributes["lon"].flatMap(Double.init)
            curEle = nil
            curTime = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "ele":
            curEle = Double(value)
        case "time":
            curTime = iso.date(from: value) ?? isoFractional.date(from: value)
        case "trkpt":
            if let lat = curLat, let lng = curLng, let time = curTime {
                fixes.append(LocationFix(timestamp: time, lat: lat, lng: lng,
                                         horizontalAccuracyM: assumedAccuracyM, speedMps: nil,
                                         altitudeM: curEle, verticalAccuracyM: curEle == nil ? nil : assumedAccuracyM))
            }
        default:
            break
        }
        text = ""
    }
}
