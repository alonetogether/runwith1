import Foundation

public enum Geo {
    public static let earthRadiusM = 6_371_000.0

    /// Great-circle distance in metres between two WGS84 coordinates.
    public static func haversineM(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let toRad = Double.pi / 180
        let dLat = (lat2 - lat1) * toRad
        let dLng = (lng2 - lng1) * toRad
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * toRad) * cos(lat2 * toRad) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusM * c
    }
}
