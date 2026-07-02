import AVFoundation

/// Records microphone audio and delivers it as 16 kHz mono Float32 samples —
/// the exact format Whisper models expect.
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private let sampleLock = NSLock()

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    var isRecording: Bool { engine.isRunning }

    /// Auto-stop on silence: once the user has spoken and then stays quiet for
    /// this long, `onAutoStop` fires (on the main queue). Set to nil to disable.
    var autoStopAfterSilence: TimeInterval?
    var onAutoStop: (() -> Void)?

    private var heardVoice = false
    private var autoStopFired = false
    private var silentSampleCount = 0
    /// RMS energy above this counts as speech; below it counts as silence.
    private let voiceRMSThreshold: Float = 0.015

    /// Asks the OS for microphone access (shows the system prompt on first run).
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            #if os(iOS)
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
            #else
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
            #endif
        }
    }

    func start() throws {
        sampleLock.lock()
        samples.removeAll()
        heardVoice = false
        autoStopFired = false
        silentSampleCount = 0
        sampleLock.unlock()

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    /// Stops recording and returns everything captured since `start()`.
    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

        sampleLock.lock()
        defer { sampleLock.unlock() }
        return samples
    }

    /// Converts whatever format the mic delivers (usually 44.1/48 kHz stereo)
    /// down to 16 kHz mono and appends it to the buffer.
    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        converter.convert(to: converted, error: nil) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        guard let channelData = converted.floatChannelData else { return }
        let frames = Int(converted.frameLength)
        let buffer = UnsafeBufferPointer(start: channelData[0], count: frames)

        sampleLock.lock()
        samples.append(contentsOf: buffer)
        sampleLock.unlock()

        detectSilence(in: buffer)
    }

    /// Tiny energy-based voice activity detection: tracks how long the user
    /// has been quiet after speaking, and fires `onAutoStop` once.
    private func detectSilence(in buffer: UnsafeBufferPointer<Float>) {
        guard let limit = autoStopAfterSilence, !autoStopFired, !buffer.isEmpty else { return }

        let meanSquare = buffer.reduce(Float(0)) { $0 + $1 * $1 } / Float(buffer.count)
        let rms = meanSquare.squareRoot()

        if rms > voiceRMSThreshold {
            heardVoice = true
            silentSampleCount = 0
        } else if heardVoice {
            silentSampleCount += buffer.count
            if Double(silentSampleCount) / targetFormat.sampleRate >= limit {
                autoStopFired = true
                DispatchQueue.main.async { [weak self] in
                    self?.onAutoStop?()
                }
            }
        }
    }
}
