import AVFoundation
import RunCore

/// Short spoken cues (countdown, "one hundred to go", "finish") over whatever
/// is playing: other audio is ducked while a cue speaks, then restored.
@MainActor
final class Announcer: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func say(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt,
                                 options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.55
        utterance.volume = 1
        synth.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synth.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

/// What the runner set up before a sprint: the distance and the marked lines.
struct SprintPlan: Equatable {
    var targetM: Double
    var startLine: LinePoint
    /// A separate finish line; nil for a lap (finish = start) or a manual finish.
    var finishLine: LinePoint?
    /// Start and finish are the same line (a lap of a track).
    var lap: Bool
}
