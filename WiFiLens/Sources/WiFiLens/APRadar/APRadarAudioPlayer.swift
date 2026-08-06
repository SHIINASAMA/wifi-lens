import AVFoundation
import Foundation

/// Errors surfaced when the bundled pulse sound cannot be prepared.
enum APRadarAudioError: LocalizedError {
    case resourceNotFound
    case unavailable(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound:
            "AP Radar pulse sound resource is missing."
        case .unavailable(let underlying):
            "AP Radar audio could not be initialized: \(underlying.localizedDescription)"
        }
    }
}

/// Preloaded, single-shot audio playback for AP Radar pulses.
///
/// The bundled WAV is loaded and decoded once in `prepare()`; every pulse
/// reuses the same `AVAudioPlayer` instead of re-reading or re-decoding the
/// file.
@MainActor
final class APRadarAudioPlayer: APRadarAudioPlaying {
    private var player: AVAudioPlayer?

    func prepare() throws {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "ap-radar-pulse", withExtension: "wav") else {
            throw APRadarAudioError.resourceNotFound
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            self.player = player
        } catch {
            throw APRadarAudioError.unavailable(underlying: error)
        }
    }

    /// Plays one pulse from the start. Returns false when audio is not ready
    /// or the system refuses playback.
    @discardableResult
    func playPulse() -> Bool {
        guard let player else { return false }
        player.currentTime = 0
        return player.play()
    }

    /// Stops any in-flight playback immediately.
    func stop() {
        player?.stop()
    }
}

/// Protocol seam used by the view model so tests can substitute a spy.
@MainActor
protocol APRadarAudioPlaying: AnyObject {
    func prepare() throws
    @discardableResult
    func playPulse() -> Bool
    func stop()
}
