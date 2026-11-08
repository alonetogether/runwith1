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
    /// Set by the recorder for the duration of a run: every look at the
    /// player (changes, play/pause, and a 2 s sample), with when it was taken.
    var onObservation: ((MusicObservation, Date) -> Void)?

    static let sourceName = "apple_music"
    /// Local player: positions are read directly, changes arrive as notifications.
    static let timing = MusicTiming(fidelity: .measured, method: "system_player_notifications_2s_sampling")
    private var sampler: Timer?

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
        let seenAt = Date()
        guard let item = player.nowPlayingItem else {
            nowPlaying = nil
            if isLogging { onObservation?(.nothingPlaying, seenAt) }
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
                            bpm: item.beatsPerMinute > 0 ? Double(item.beatsPerMinute) : nil,
                            albumID: item.albumPersistentID != 0 ? "persistent:\(item.albumPersistentID)" : nil,
                            artistID: item.artistPersistentID != 0 ? "persistent:\(item.artistPersistentID)" : nil)
        nowPlaying = np
        if let album = np.albumID {
            ArtworkCache.storeIfMissing(item.artwork, source: Self.sourceName, albumID: album)
        }
        guard isLogging else { return }
        // The builder decides what is a new entry; this only reports what it saw.
        let position = player.currentPlaybackTime
        let progress = position.isFinite && position >= 0 ? Int(position * 1000) : nil
        onObservation?(.track(np, progressMs: progress, playing: isPlaying), seenAt)
    }

    /// Reports the player now, on every change, and every 2 s until stopped.
    /// The sample keeps the position fresh: when the track changes, the old
    /// one's final position is already gone, and without it a skip and a
    /// completion look the same.
    func startLogging() {
        isLogging = true
        beginObserving()
        refresh()
        sampler?.invalidate()
        sampler = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopLogging() {
        isLogging = false
        sampler?.invalidate()
        sampler = nil
    }
}
