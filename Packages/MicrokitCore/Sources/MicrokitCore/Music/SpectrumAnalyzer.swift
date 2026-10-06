import Accelerate

/// Turns a stream of mono samples into `AudioFeatures`: a windowed FFT over the newest
/// `size` samples, log-spaced bands, adaptive normalization, and bass beat detection.
/// Not thread-safe: feed and analyze it from one queue.
public final class SpectrumAnalyzer {
    public let size: Int
    public let sampleRate: Double
    public let bandCount: Int

    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private let window: [Float]
    private var ring: [Float]
    private var writeIndex = 0
    private var bandEdges: [Int] = []

    // Adaptive peaks so quiet and loud music both fill the range.
    private var bandPeaks: [Float]
    private var bassPeak: Float = 1e-6
    private var midPeak: Float = 1e-6
    private var treblePeak: Float = 1e-6
    private var levelPeak: Float = 1e-6
    private static let peakDecay: Float = 0.997
    private static let peakFloor: Float = 1e-4

    // Beat detection: bass energy against its recent average.
    private var bassHistory: [Float] = []
    private var lastBeatTime: Double = -1
    public var beatThreshold: Float = 1.4
    public var minimumBeatGap: Double = 0.18

    public init(size: Int = 1024, sampleRate: Double, bandCount: Int = 24) {
        precondition(size >= 64 && size & (size - 1) == 0, "FFT size must be a power of two")
        self.size = size
        self.sampleRate = sampleRate
        self.bandCount = bandCount
        log2n = vDSP_Length(log2(Double(size)))
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false)
        ring = Array(repeating: 0, count: size)
        bandPeaks = Array(repeating: 1e-6, count: bandCount)
        bandEdges = Self.logBandEdges(count: bandCount, size: size, sampleRate: sampleRate)
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }

    /// Adds mono samples to the ring buffer.
    public func append(_ samples: UnsafeBufferPointer<Float>) {
        for sample in samples {
            ring[writeIndex] = sample
            writeIndex = (writeIndex + 1) % size
        }
    }

    public func append(_ samples: [Float]) {
        samples.withUnsafeBufferPointer { append($0) }
    }

    /// Analyzes the newest `size` samples. `time` is in seconds and only needs to increase.
    public func analyze(time: Double) -> AudioFeatures {
        // Oldest to newest, windowed.
        var frame = Array(ring[writeIndex...] + ring[..<writeIndex])
        let rms = vDSP.rootMeanSquare(frame)
        vDSP.multiply(frame, window, result: &frame)

        let half = size / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                frame.withUnsafeBufferPointer { framePointer in
                    framePointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                split.imagp[0] = 0 // Nyquist is packed here; drop it.
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }

        var bands = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let lower = bandEdges[band], upper = max(bandEdges[band + 1], lower + 1)
            let energy = magnitudes[lower..<min(upper, half)].reduce(0, +) / Float(upper - lower)
            bandPeaks[band] = max(bandPeaks[band] * Self.peakDecay, energy, Self.peakFloor)
            bands[band] = min(energy / bandPeaks[band], 1)
        }

        let bassEnergy = energy(magnitudes, from: 20, to: 150)
        let midEnergy = energy(magnitudes, from: 150, to: 2000)
        let trebleEnergy = energy(magnitudes, from: 2000, to: 12000)
        bassPeak = max(bassPeak * Self.peakDecay, bassEnergy, Self.peakFloor)
        midPeak = max(midPeak * Self.peakDecay, midEnergy, Self.peakFloor)
        treblePeak = max(treblePeak * Self.peakDecay, trebleEnergy, Self.peakFloor)
        levelPeak = max(levelPeak * Self.peakDecay, rms, Self.peakFloor)

        let isSilent = rms < 1e-4
        let bass = isSilent ? 0 : min(bassEnergy / bassPeak, 1)

        // Beat: bass well above its recent average, not too soon after the last one.
        let average = bassHistory.isEmpty ? 0 : bassHistory.reduce(0, +) / Float(bassHistory.count)
        let isBeat = !isSilent && bassHistory.count >= 8 && bassEnergy > average * beatThreshold
            && bass > 0.3 && time - lastBeatTime >= minimumBeatGap
        if isBeat { lastBeatTime = time }
        bassHistory.append(bassEnergy)
        if bassHistory.count > 43 { bassHistory.removeFirst() }

        return AudioFeatures(
            bands: isSilent ? Array(repeating: 0, count: bandCount) : bands,
            bass: bass,
            mid: isSilent ? 0 : min(midEnergy / midPeak, 1),
            treble: isSilent ? 0 : min(trebleEnergy / treblePeak, 1),
            level: isSilent ? 0 : min(rms / levelPeak, 1),
            isBeat: isBeat
        )
    }

    private func energy(_ magnitudes: [Float], from low: Double, to high: Double) -> Float {
        let lower = max(1, bin(for: low)), upper = min(magnitudes.count, max(bin(for: high), lower + 1))
        return magnitudes[lower..<upper].reduce(0, +) / Float(upper - lower)
    }

    private func bin(for frequency: Double) -> Int {
        Int((frequency / sampleRate * Double(size)).rounded())
    }

    /// Bin edges for `count` bands spaced evenly in pitch from 40 Hz to 16 kHz.
    static func logBandEdges(count: Int, size: Int, sampleRate: Double) -> [Int] {
        let low = 40.0, high = min(16_000.0, sampleRate / 2 - 1)
        return (0...count).map { index in
            let frequency = low * pow(high / low, Double(index) / Double(count))
            return max(1, min(size / 2, Int((frequency / sampleRate * Double(size)).rounded())))
        }
    }
}
