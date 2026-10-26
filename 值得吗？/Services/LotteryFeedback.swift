import AVFoundation
import UIKit
import os

/// All audio route, decoding and playback work stays on one background queue.
/// The player is queue-confined; the generation lock cancels pending playback.
private nonisolated final class RecordedLotteryAudio: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.worthit.lottery-audio", qos: .userInitiated)
    private let generation = OSAllocatedUnfairLock(initialState: 0)
    private var player: AVAudioPlayer?

    func start() {
        let ticket = generation.withLock { value in value += 1; return value }
        queue.async { [self] in
            guard generation.withLock({ $0 == ticket }) else { return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                if player == nil, let url = Bundle.main.url(forResource: "lottery-shake", withExtension: "m4a") {
                    player = try AVAudioPlayer(contentsOf: url)
                    player?.volume = 0.75
                    player?.prepareToPlay()
                }
                guard generation.withLock({ $0 == ticket }) else { return }
                player?.currentTime = 0
                player?.play()
            } catch {
                // Drawing and haptics still work if an audio route is unavailable.
            }
        }
    }

    func stop() {
        generation.withLock { $0 += 1 }
        queue.async { [self] in
            player?.stop()
            player?.currentTime = 0
        }
    }
}

/// Ambient playback respects Silent Mode and other audio; Taptic feedback stays on main.
@MainActor
final class LotteryFeedback {
    static let duration: Double = 1.35
    private let audio = RecordedLotteryAudio()
    private var pulses: Task<Void, Never>?
    private let impact = UIImpactFeedbackGenerator(style: .soft)

    func start() {
        stop()
        audio.start()
        impact.prepare()
        pulses = Task { [weak self] in
            let beats: [(Double, CGFloat)] = [(0, 0.45), (0.14, 0.7), (0.31, 0.5), (0.48, 0.8), (0.69, 0.55), (0.88, 0.7), (1.10, 0.4)]
            var previous = 0.0
            for (time, intensity) in beats {
                do { try await Task.sleep(for: .seconds(time - previous)) } catch { return }
                guard !Task.isCancelled, let self else { return }
                self.impact.impactOccurred(intensity: intensity)
                self.impact.prepare()
                previous = time
            }
        }
    }

    func complete() {
        stop()
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
    }

    func stop() {
        pulses?.cancel()
        pulses = nil
        audio.stop()
    }
}
