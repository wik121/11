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
        sampleLock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: Int(converted.frameLength)))
        sampleLock.unlock()
    }
}
