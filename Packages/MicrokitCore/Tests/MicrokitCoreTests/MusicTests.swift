import Foundation
import Testing
@testable import MicrokitCore

struct MusicTests {
    static let sampleRate = 48_000.0

    static func sine(_ frequency: Double, count: Int, amplitude: Float = 0.5, phase: Int = 0) -> [Float] {
        (0..<count).map { amplitude * Float(sin(2 * .pi * frequency * Double($0 + phase) / sampleRate)) }
    }

    @Test func bassToneReadsAsBass() {
        let analyzer = SpectrumAnalyzer(sampleRate: Self.sampleRate)
        var features = AudioFeatures.silence
        for step in 0..<20 {
            analyzer.append(Self.sine(60, count: 512, phase: step * 512))
            analyzer.append(Self.sine(5000, count: 0))
            features = analyzer.analyze(time: Double(step) * 0.01)
        }
        #expect(features.bass > 0.8)
        #expect(features.level > 0.5)
        // The lowest band is loud, the highest quiet.
        #expect(features.bands.first! > features.bands.last!)
    }

    @Test func trebleToneShiftsSpectrumColorTowardBlue() {
        let analyzer = SpectrumAnalyzer(sampleRate: Self.sampleRate)
        var mapper = MusicColorMapper(style: .spectrum)
        var frame = MusicLightFrame(hue: 0, saturation: 0, brightness: 0)
        // Warm the peaks with a mix, then play treble only.
        for step in 0..<30 {
            let mixed = zip(Self.sine(60, count: 512, phase: step * 512), Self.sine(6000, count: 512, phase: step * 512)).map(+)
            analyzer.append(mixed)
            _ = mapper.frame(for: analyzer.analyze(time: Double(step) * 0.01))
        }
        for step in 30..<60 {
            analyzer.append(Self.sine(6000, count: 512, phase: step * 512))
            frame = mapper.frame(for: analyzer.analyze(time: Double(step) * 0.01))
        }
        #expect(frame.hue > 120) // toward blue (0.66 x 255 = 168)
    }

    @Test func silenceGivesNoLevelAndNoBeat() {
        let analyzer = SpectrumAnalyzer(sampleRate: Self.sampleRate)
        var features = AudioFeatures.silence
        for step in 0..<20 {
            analyzer.append([Float](repeating: 0, count: 512))
            features = analyzer.analyze(time: Double(step) * 0.01)
        }
        #expect(features.level == 0)
        #expect(features.isBeat == false)
        #expect(features.bands.allSatisfy { $0 == 0 })
    }

    @Test func kickDrumPatternProducesBeats() {
        let analyzer = SpectrumAnalyzer(sampleRate: Self.sampleRate)
        var beats = 0
        // 120 BPM: a loud 50 Hz hit every 0.5 s over a quiet hum, analyzed every ~10.7 ms.
        let hop = 512
        for step in 0..<400 {
            let time = Double(step * hop) / Self.sampleRate
            let isHit = time.truncatingRemainder(dividingBy: 0.5) < 0.06
            analyzer.append(Self.sine(50, count: hop, amplitude: isHit ? 0.9 : 0.05, phase: step * hop))
            if analyzer.analyze(time: time).isBeat { beats += 1 }
        }
        // About 8 hits in 4.3 s; allow some slack for the warm-up.
        #expect((5...10).contains(beats))
    }

    @Test func pulseUsesBaseHueAndNeverGoesDark() {
        var mapper = MusicColorMapper(style: .pulse, baseHue: 0.5, floor: 0.1)
        let quiet = mapper.frame(for: .silence)
        #expect(quiet.hue == 128)
        #expect(quiet.brightness >= 25)
        let loud = mapper.frame(for: AudioFeatures(bass: 1, level: 1, isBeat: true))
        #expect(loud.brightness > 200)
    }

    @Test func beatRainbowMovesHueOnBeats() {
        var mapper = MusicColorMapper(style: .beatRainbow)
        let first = mapper.frame(for: AudioFeatures(level: 0.5, isBeat: true))
        let second = mapper.frame(for: AudioFeatures(level: 0.5, isBeat: true))
        #expect(second.hue != first.hue)
    }

    @Test func microPadHasUnderglowAndBacklightTargets() throws {
        let targets = MusicTarget.targets(in: try Fixtures.creatorMicro().lightingPages)
        #expect(targets.map(\.title) == ["Underglow", "Backlight"])
        let underglow = targets[0]
        #expect(underglow.channel == 2)
        #expect(underglow.colorPath == [2, 4])
        #expect(underglow.brightnessPath == [2, 1])
        #expect(underglow.effectPath == [2, 2])
        #expect(underglow.solidEffect == 1)
        #expect(targets[1].colorPath == [3, 4])
    }
}
