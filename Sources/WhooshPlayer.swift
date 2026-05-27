import Foundation
import AVFoundation

@MainActor
final class WhooshPlayer {
    static let shared = WhooshPlayer()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var startTime: Date = .distantPast
    private var duration: Double = 2.5
    private var sampleRate: Double = 44100
    private var lpState1: Float = 0
    private var lpState2: Float = 0
    private var hpState: Float = 0
    private var hpPrev: Float = 0

    private init() { configure() }

    private func configure() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let elapsedStart = Date().timeIntervalSince(self.startTime)
            for frame in 0..<Int(frameCount) {
                let t = elapsedStart + Double(frame) / self.sampleRate
                let env = self.envelope(t: t)
                let raw = Float.random(in: -1...1)
                // 2-pole low-pass (smoothed) for the "shhhh" tone
                self.lpState1 = 0.80 * self.lpState1 + 0.20 * raw
                self.lpState2 = 0.80 * self.lpState2 + 0.20 * self.lpState1
                let lp = self.lpState2
                // Single-pole high-pass to drop sub-rumble
                let hp = lp - self.hpPrev + 0.97 * self.hpState
                self.hpState = hp
                self.hpPrev = lp
                let sample = hp * Float(env) * 0.55
                for buffer in abl {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
    }

    private func envelope(t: Double) -> Double {
        if t < 0 || t > duration { return 0 }
        // Bell curve peaking near the middle — simulates a flyby
        let x = (t / duration) * 2 - 1
        let bell = max(0, 1 - x * x)
        // Soften the edges further
        return bell * bell
    }

    func playWhoosh(duration: Double = 2.5) {
        self.duration = duration
        self.startTime = Date()
        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.4) { [weak self] in
            guard let self else { return }
            // Stop engine when the envelope is finished to save power.
            if Date().timeIntervalSince(self.startTime) >= self.duration {
                self.engine.stop()
            }
        }
    }
}
