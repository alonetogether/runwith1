import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import RunCore
import Security
import UIKit

/// Spotify connector: what the user's Spotify account is playing, by polling
/// the Web API's currently-playing endpoint. Metadata only, never audio
/// (brief §5). Works for free and Premium accounts, on whatever device
/// Spotify is playing on.
///
/// Sign-in is Authorization Code with PKCE through `ASWebAuthenticationSession`,
/// so no client secret ships in the app. The only configuration is the client
/// ID of a Spotify developer app, read from Info.plist (`SpotifyClientID`),
/// with `runwith://spotify` registered there as a redirect URI.
@MainActor
@Observable
final class SpotifyService: NSObject {
    static let sourceName = "spotify"
    static let redirectURI = "runwith://spotify"
    static let callbackScheme = "runwith"
    static let scopes = "user-read-currently-playing user-read-playback-state"

    private(set) var isConnected = false
    private(set) var isConnecting = false
    private(set) var nowPlaying: PlayingTrack?
    private(set) var isPlaying = false
    private(set) var lastError: String?
    /// Set by the recorder for the duration of a run: every poll's answer,
    /// with the moment it was received.
    var onObservation: ((MusicObservation, Date) -> Void)?
    /// Polled every 10 s; start and end are estimated from the reported position.
    static let timing = MusicTiming(fidelity: .estimated, method: "spotify_poll_10s_progress")
    /// Artist id → first listed genre, so each artist costs one lookup per launch.
    private var genreCache: [String: String?] = [:]

    let clientID: String
    var isConfigured: Bool { !clientID.isEmpty }

    private var tokens: Tokens? {
        didSet { isConnected = tokens != nil }
    }
    private var session: ASWebAuthenticationSession?
    private var pollTask: Task<Void, Never>?
    private var isLogging = false

    override init() {
        clientID = (Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        super.init()
        tokens = Keychain.load()
        isConnected = tokens != nil
    }

    // MARK: Sign-in

    func connect() {
        guard isConfigured, !isConnecting else { return }
        isConnecting = true
        lastError = nil
        let verifier = PKCE.verifier()
        var parts = URLComponents(string: "https://accounts.spotify.com/authorize")!
        parts.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: PKCE.challenge(for: verifier)),
            .init(name: "scope", value: Self.scopes),
        ]
        let session = ASWebAuthenticationSession(url: parts.url!, callbackURLScheme: Self.callbackScheme) { [weak self] url, error in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isConnecting = false; self.session = nil }
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    self.lastError = cancelled ? nil : error.localizedDescription
                    return
                }
                guard let url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value else {
                    self.lastError = self.items(from: url)?.first(where: { $0.name == "error" })?.value ?? "No code returned."
                    return
                }
                await self.exchange(code: code, verifier: verifier)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.session = session
        session.start()
    }

    private func items(from url: URL?) -> [URLQueryItem]? {
        url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
    }

    func disconnect() {
        stopObserving()
        tokens = nil
        Keychain.clear()
        nowPlaying = nil
        isPlaying = false
    }

    private func exchange(code: String, verifier: String) async {
        do {
            let t = try await tokenRequest([
                "grant_type": "authorization_code", "code": code,
                "redirect_uri": Self.redirectURI, "client_id": clientID, "code_verifier": verifier,
            ])
            tokens = t
            Keychain.save(t)
            beginObserving()
        } catch {
            lastError = "Spotify sign-in failed: \(error.localizedDescription)"
        }
    }

    private func refreshIfNeeded() async throws -> String {
        guard let t = tokens else { throw SpotifyError.notConnected }
        if t.expiresAt.timeIntervalSinceNow > 60 { return t.accessToken }
        do {
            var fresh = try await tokenRequest([
                "grant_type": "refresh_token", "refresh_token": t.refreshToken, "client_id": clientID,
            ])
            if fresh.refreshToken.isEmpty { fresh.refreshToken = t.refreshToken }
            tokens = fresh
            Keychain.save(fresh)
            return fresh.accessToken
        } catch SpotifyError.http(let status, _) where status == 400 || status == 401 {
            // The refresh token was revoked (password change, app removed). Sign-in again.
            disconnect()
            lastError = "Spotify signed out. Connect again."
            throw SpotifyError.notConnected
        }
    }

    private func tokenRequest(_ form: [String: String]) async throws -> Tokens {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = form.map { "\($0.key)=\(Self.formEncode($0.value))" }.joined(separator: "&").data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw SpotifyError.http(status, String(data: data, encoding: .utf8) ?? "") }
        let body = try JSONDecoder().decode(TokenResponse.self, from: data)
        return Tokens(accessToken: body.access_token, refreshToken: body.refresh_token ?? "",
                      expiresAt: Date().addingTimeInterval(TimeInterval(body.expires_in)))
    }

    private static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    // MARK: Polling

    /// Polls while connected: every 20 s on the gear check, every 10 s during a run.
    func beginObserving() {
        guard isConnected, pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollOnce()
                let interval: UInt64 = self.isLogging ? 10 : 20
                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
            }
        }
    }

    func stopObserving() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Logs whatever is playing right now, then every change until stopped.
    func startLogging() {
        isLogging = true
        beginObserving()
        Task { await pollOnce() }
    }

    /// One last look when the run ends, so a track that came on since the
    /// last 10 s poll (a final-spurt song) is still logged. Bounded: the run
    /// is saved after at most a few seconds whatever the network does.
    func finalPoll() async {
        guard isLogging else { return }
        await pollOnce(timeout: 3)
    }

    func stopLogging() {
        isLogging = false
    }

    private func pollOnce(timeout: TimeInterval = 15) async {
        guard isConnected else { return }
        do {
            let token = try await refreshIfNeeded()
            var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing?additional_types=track,episode")!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = timeout
            let (data, resp) = try await URLSession.shared.data(for: req)
            // Stamped on receipt: the genre lookup below must not age the position.
            let seenAt = Date()
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 204 {               // nothing playing
                isPlaying = false
                nowPlaying = nil
                lastError = nil
                if isLogging { onObservation?(.nothingPlaying, seenAt) }
                return
            }
            guard status == 200 else { throw SpotifyError.http(status, "") }
            let body = try JSONDecoder().decode(CurrentlyPlaying.self, from: data)
            isPlaying = body.is_playing
            lastError = nil
            guard let item = body.item else {   // an ad, or a private session
                nowPlaying = nil
                if isLogging { onObservation?(.unknown, seenAt) }
                return
            }
            var np = PlayingTrack(title: item.name,
                                artist: item.artists?.map(\.name).joined(separator: ", ") ?? item.show?.name ?? "Unknown artist",
                                album: item.album?.name ?? item.show?.name,
                                isrc: item.external_ids?.isrc,
                                trackID: item.id,
                                genre: nil,
                                durationMs: item.duration_ms,
                                bpm: nil,   // Spotify closed audio features to new apps; BPM comes from elsewhere later
                                artworkURL: Self.artwork(item.album?.images ?? item.show?.images),
                                albumID: item.album?.id ?? item.show?.id,
                                artistID: item.artists?.first?.id)
            let isNewTrack = np.trackID != nowPlaying?.trackID
            if isNewTrack, let artistID = item.artists?.first?.id {
                np.genre = await genre(forArtist: artistID, token: token)
            } else {
                np.genre = nowPlaying?.genre
            }
            nowPlaying = np
            // The builder decides what is a new entry; this only reports what it saw.
            if isLogging {
                onObservation?(.track(np, progressMs: body.progress_ms, playing: body.is_playing), seenAt)
            }
        } catch SpotifyError.notConnected {
            return
        } catch {
            // Transient network trouble mid-run: keep the last known track, say so on the gear check.
            lastError = "Spotify unreachable: \(error.localizedDescription)"
        }
    }

    /// Spotify keeps genre on the artist, not the track. One call per artist, cached.
    private func genre(forArtist id: String, token: String) async -> String? {
        if let cached = genreCache[id] { return cached }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/artists/\(id)")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let artist = try? JSONDecoder().decode(Artist.self, from: data) else { return nil }
        let genre = artist.genres?.first
        genreCache[id] = genre
        return genre
    }

    // MARK: Types

    struct Tokens: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int
    }

    private struct CurrentlyPlaying: Decodable {
        struct Item: Decodable {
            struct Named: Decodable { let id: String?; let name: String }
            struct Image: Decodable { let url: String; let width: Int?; let height: Int? }
            struct Album: Decodable { let id: String?; let name: String; let images: [Image]? }
            struct ExternalIDs: Decodable { let isrc: String? }
            let id: String?
            let name: String
            let artists: [Named]?
            let album: Album?
            let show: Album?
            let duration_ms: Int?
            let external_ids: ExternalIDs?
        }
        let is_playing: Bool
        let progress_ms: Int?
        let item: Item?
    }

    /// The smallest cover that is still sharp as a list thumbnail (Spotify
    /// usually offers 640, 300 and 64 px). A pointer, never the image.
    private static func artwork(_ images: [CurrentlyPlaying.Item.Image]?) -> String? {
        guard let images, !images.isEmpty else { return nil }
        let usable = images.filter { ($0.width ?? 0) >= 120 }.min { ($0.width ?? 0) < ($1.width ?? 0) }
        return (usable ?? images.first)?.url
    }

    private struct Artist: Decodable {
        let genres: [String]?
    }

    enum SpotifyError: LocalizedError {
        case notConnected
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConnected: return "Not connected to Spotify."
            case .http(let status, let body):
                return body.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(body.prefix(120))"
            }
        }
    }
}

extension SpotifyService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }
}

// MARK: - PKCE

private enum PKCE {
    static func verifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Keychain

/// Tokens live in the keychain, readable after first unlock so a run that
/// outlasts a lock can still refresh them.
private enum Keychain {
    private static let service = "app.runwith.capture.spotify"
    private static let account = "tokens"

    static func save(_ tokens: SpotifyService.Tokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        clear()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data,
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func load() -> SpotifyService.Tokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(SpotifyService.Tokens.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
