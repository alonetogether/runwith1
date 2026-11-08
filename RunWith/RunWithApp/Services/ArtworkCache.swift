import MediaPlayer
import UIKit

/// Album art the device already has (Apple Music hands over an image, not a
/// link), kept in Caches, one file per album. Never written into a Run: the
/// run stores identifiers, and the picture is a local convenience the system
/// may purge. Spotify art is loaded from its `artwork_url` at display time.
enum ArtworkCache {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("artwork", isDirectory: true)
    }

    static func fileURL(source: String, albumID: String) -> URL {
        let safe = "\(source)_\(albumID)".map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" ? $0 : "_" }
        return directory.appendingPathComponent(String(safe) + ".jpg")
    }

    static func storeIfMissing(_ artwork: MPMediaItemArtwork?, source: String, albumID: String) {
        guard let artwork else { return }
        let url = fileURL(source: source, albumID: albumID)
        guard !FileManager.default.fileExists(atPath: url.path),
              let image = artwork.image(at: CGSize(width: 120, height: 120)),
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func image(source: String, albumID: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(source: source, albumID: albumID).path)
    }
}
