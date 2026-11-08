import MediaPlayer
import Observation
import RunCore

/// Apple Music / system player now-playing logger. Metadata only, never audio
/// (brief §5). Spotify and other players are not visible to this connector;
/// they would be separate connectors later.
@MainActor
@Observable
final class MusicLogger {
    private(set) var authorization: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
    private(set) var nowPlaying: PlayingTrack?
    private(set) var isPlaying = false
    /// Set by the recorder for the duration of a run: (track, when).
    var onTrack: ((PlayingTrack, Date) -> Void)?

    static let sourceName = "apple_music"

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var observers: [NSObjectProtocol] = []
    private var isLogging = false

    var isAuthorized: Bool { authorization == .authorized }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func requestPermission() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorization = status
                if status == .authorized { self?.beginObserving() }
            }
        }
    }

    func beginObserving() {
        guard isAuthorized, observers.isEmpty else { return }
        player.beginGeneratingPlaybackNotifications()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
                                            object: player, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(center.addObserver(forName: .MPMusicPlayerControllerPlaybackStateDidChange,
                                            object: player, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        refresh()
    }

    func refresh() {
        isPlaying = player.playbackState == .playing
        guard let item = player.nowPlayingItem else {
            nowPlaying = nil
            return
        }
        // Whatever the library tag carries. BPM is usually untagged (0), so nil then.
        let storeID = item.playbackStoreID
        let np = PlayingTrack(title: item.title ?? "Unknown title",
                            artist: item.artist ?? "Unknown artist",
                            album: item.albumTitle,
                            isrc: nil,
                            trackID: storeID.isEmpty || storeID == "0" ? "persistent:\(item.persistentID)" : storeID,
                            genre: item.genre,
                            durationMs: item.playbackDuration > 0 ? Int(item.playbackDuration * 1000) : nil,
                            bpm: item.beatsPerMinute > 0 ? Double(item.beatsPerMinute) : nil)
        nowPlaying = np
        logIfNewlyPlaying(np)
    }

    /// The track logged last. A track is logged the first time it is actually
    /// playing during the run, so one paused at Start and played later is
    /// still logged, and pausing and resuming the same track is not a new entry.
    private var loggedKey: String?

    private func logIfNewlyPlaying(_ np: PlayingTrack) {
        guard isLogging, isPlaying else { return }
        let key = np.trackID ?? "\(np.title)|\(np.artist)"
        guard key != loggedKey else { return }
        loggedKey = key
        onTrack?(np, Date())
    }

    /// Logs whatever is playing right now, then every change until stopped.
    func startLogging() {
        isLogging = true
        loggedKey = nil
        beginObserving()
        refresh()
    }

    func stopLogging() {
        isLogging = false
    }
}
