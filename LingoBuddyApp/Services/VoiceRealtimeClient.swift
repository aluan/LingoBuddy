@preconcurrency import AVFoundation
import Foundation

@MainActor
final class VoiceRealtimeClient: ObservableObject {
    private enum VoiceAudioError: LocalizedError {
        case invalidInputFormat(sampleRate: Double, channelCount: AVAudioChannelCount, route: String)
        case cannotCreateCaptureConverter

        var errorDescription: String? {
            switch self {
            case .invalidInputFormat(let sampleRate, let channelCount, let route):
                "Microphone input is not ready. sampleRate=\(sampleRate), channels=\(channelCount), route=\(route)"
            case .cannotCreateCaptureConverter:
                "Could not prepare microphone audio conversion."
            }
        }
    }

    @Published var voiceState: VoiceInteractionState = .thinking
    @Published var childTranscript = "Tap the mic to start your quest!"
    @Published var astraReply = "Hi! Ready for a dragon quest?"
    @Published var totalStars = 18
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var isInCall = false
    @Published var isStartingCall = false
    @Published var errorMessage: String?
    @Published var currentEndpoint = "Not connected"
    @Published var audioChunksSent = 0
    @Published var audioChunksReceived = 0
    @Published var inputLevel = 0.0

    private let endpoints = VoiceRealtimeClient.defaultEndpoints()
    private let captureFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!
    private let playbackGain: Float = 3.0

    private var task: URLSessionWebSocketTask?
    private var hasStartedSession = false
    private var endpointIndex = 0
    private let captureEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var captureConverter: AVAudioConverter?
    private var hasInputTap = false
    private var hasAttachedPlayer = false
    private var shouldStartAudioWhenReady = false

    private static func defaultEndpoints() -> [URL] {
        #if targetEnvironment(simulator)
        [
            URL(string: "ws://localhost:3002/voice/realtime")!,
            URL(string: "ws://10.200.193.137:3002/voice/realtime")!
        ]
        #else
        [
            URL(string: "ws://10.200.193.137:3002/voice/realtime")!
        ]
        #endif
    }

    private func connect() {
        guard task == nil else { return }
        errorMessage = nil
        endpointIndex = 0
        openWebSocket()
    }

    private func openWebSocket() {
        let endpoint = endpoints[endpointIndex]
        currentEndpoint = endpoint.absoluteString

        let socket = URLSession.shared.webSocketTask(with: endpoint)
        task = socket
        socket.resume()
        receiveNextMessage()
    }

    private func disconnect() {
        stopRecording(sendStop: false)
        stopPlayback()
        stopAudioSession()
        send(["type": "session.end"])
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        hasStartedSession = false
        isConnected = false
        isStartingCall = false
        currentEndpoint = "Disconnected"
    }

    func startCall() {
        guard !isInCall, !isStartingCall else { return }

        isInCall = true
        isStartingCall = true
        shouldStartAudioWhenReady = true
        audioChunksSent = 0
        audioChunksReceived = 0
        inputLevel = 0
        errorMessage = nil
        childTranscript = "Call started. You can speak naturally."
        astraReply = "Hi! I'm here."
        voiceState = .thinking

        if task == nil {
            connect()
        } else if isConnected {
            startSessionIfNeeded()
        }
    }

    func endCall() {
        guard isInCall || isStartingCall || task != nil else { return }

        isInCall = false
        isStartingCall = false
        shouldStartAudioWhenReady = false
        inputLevel = 0
        disconnect()
        voiceState = .thinking
        childTranscript = "Tap Start Call when you're ready."
        astraReply = "Great talking with you."
    }

    func cancelResponse() {
        stopPlayback()
        send(["type": "response.cancel"])
    }

    private func startSessionIfNeeded() {
        guard isInCall, !hasStartedSession else { return }
        hasStartedSession = true
        send(["type": "session.start"])
    }

    private func receiveNextMessage() {
        task?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let message):
                    self.handle(message)
                    if self.task != nil {
                        self.receiveNextMessage()
                    }

                case .failure(let error):
                    guard self.task != nil else { return }

                    if !self.isConnected, self.tryNextEndpoint() {
                        return
                    }

                    self.errorMessage = "Could not reach \(self.currentEndpoint): \(error.localizedDescription)"
                    self.isConnected = false
                    self.isStartingCall = false
                    self.task = nil
                }
            }
        }
    }

    private func tryNextEndpoint() -> Bool {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        hasStartedSession = false

        guard endpointIndex + 1 < endpoints.count else {
            return false
        }

        endpointIndex += 1
        openWebSocket()
        return true
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let value):
            text = value
        case .data(let data):
            text = String(decoding: data, as: UTF8.self)
        @unknown default:
            return
        }

        guard
            let data = text.data(using: .utf8),
            let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = event["type"] as? String
        else {
            return
        }

        switch type {
        case "state.changed":
            handleStateChanged(event["state"] as? String)

        case "transcript.delta":
            if let text = event["text"] as? String, !text.isEmpty {
                childTranscript = text
            }

        case "assistant.text.delta":
            if let text = event["text"] as? String {
                if event["isDelta"] as? Bool == true {
                    if !text.isEmpty {
                        astraReply += text
                    }
                } else {
                    astraReply = text
                }
            }

        case "assistant.audio.delta":
            if let audio = event["audio"] as? String {
                playAudioDelta(audio)
            }

        case "assistant.audio.stats":
            if let chunks = event["chunks"] as? Int {
                audioChunksReceived = chunks
            }

        case "reward.earned":
            if let stars = event["totalStars"] as? Int {
                totalStars = stars
            } else {
                totalStars += event["stars"] as? Int ?? 1
            }

        case "error":
            errorMessage = event["message"] as? String ?? "Realtime voice error"
            voiceState = .thinking
            stopRecording(sendStop: false)

        default:
            break
        }
    }

    private func handleStateChanged(_ state: String?) {
        switch state {
        case "connected":
            isConnected = true
            errorMessage = nil
            startSessionIfNeeded()

        case "listening":
            isStartingCall = false
            voiceState = .listening
            startLiveAudioIfNeeded()

        case "speaking":
            voiceState = .speaking

        case "thinking":
            voiceState = .thinking

        case "disconnected":
            isConnected = false
            isStartingCall = false
            isInCall = false
            shouldStartAudioWhenReady = false
            inputLevel = 0
            currentEndpoint = "Disconnected"
            voiceState = .thinking
            stopRecording(sendStop: false)

        default:
            break
        }
    }

    private func send(_ payload: [String: Any]) {
        guard let task else {
            errorMessage = "Voice connection is not ready"
            return
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }

        task.send(.string(text)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    private func startLiveAudioIfNeeded() {
        guard isInCall, shouldStartAudioWhenReady, !isRecording else { return }
        startRecording()
    }

    private func startRecording() {
        requestMicrophonePermission { [weak self] granted in
            guard let self else { return }

            guard granted else {
                self.errorMessage = "Microphone permission is needed for voice practice."
                self.isStartingCall = false
                self.isInCall = false
                return
            }

            do {
                try self.configureAudioSession()
                self.preparePlaybackNodes()
                try self.installInputTap()
                try self.startAudioEngine()
                self.isRecording = true
                self.isStartingCall = false
                self.voiceState = .listening
                self.childTranscript = "Listening live..."
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
                self.isStartingCall = false
                self.isInCall = false
                self.stopRecording(sendStop: false)
            }
        }
    }

    private func stopRecording(sendStop: Bool) {
        if hasInputTap {
            captureEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }

        captureConverter = nil
        inputLevel = 0

        if isRecording {
            isRecording = false
        }

        if sendStop {
            voiceState = .thinking
            send(["type": "audio.stop"])
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        try session.setPreferredSampleRate(captureFormat.sampleRate)
        try session.setPreferredIOBufferDuration(0.1)
        try session.setActive(true)
        try session.overrideOutputAudioPort(.speaker)
    }

    private func preparePlaybackNodes() {
        if !hasAttachedPlayer {
            captureEngine.attach(playerNode)
            captureEngine.connect(playerNode, to: captureEngine.mainMixerNode, format: playbackFormat)
            playerNode.volume = 1.0
            captureEngine.mainMixerNode.outputVolume = 1.0
            hasAttachedPlayer = true
        }
    }

    private func startAudioEngine() throws {
        if !captureEngine.isRunning {
            captureEngine.prepare()
            try captureEngine.start()
        }
    }

    private func startPlayerIfNeeded() {
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    private func installInputTap() throws {
        if hasInputTap {
            captureEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }

        let inputFormat = captureEngine.inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw VoiceAudioError.invalidInputFormat(
                sampleRate: inputFormat.sampleRate,
                channelCount: inputFormat.channelCount,
                route: currentAudioInputRoute()
            )
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: captureFormat) else {
            throw VoiceAudioError.cannotCreateCaptureConverter
        }

        captureConverter = converter

        captureEngine.inputNode.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            Task { @MainActor in
                guard self.isRecording, let chunk = self.convertInputBuffer(buffer) else { return }
                self.sendAudioChunk(chunk)
            }
        }

        hasInputTap = true
    }

    private func currentAudioInputRoute() -> String {
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
        guard !inputs.isEmpty else { return "none" }
        return inputs.map(\.portName).joined(separator: ", ")
    }

    private func convertInputBuffer(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let captureConverter else { return nil }

        let ratio = captureFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: captureFormat, frameCapacity: capacity) else {
            return nil
        }

        var didProvideInput = false
        var conversionError: NSError?

        captureConverter.convert(to: outputBuffer, error: &conversionError) { _, status in
            if didProvideInput {
                status.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            status.pointee = .haveData
            return buffer
        }

        guard conversionError == nil else { return nil }

        let byteCount = Int(outputBuffer.frameLength) * Int(captureFormat.streamDescription.pointee.mBytesPerFrame)
        guard byteCount > 0, let data = outputBuffer.audioBufferList.pointee.mBuffers.mData else {
            return nil
        }

        return Data(bytes: data, count: byteCount)
    }

    private func sendAudioChunk(_ data: Data) {
        audioChunksSent += 1
        inputLevel = pcmLevel(in: data)
        send([
            "type": "audio.append",
            "audio": data.base64EncodedString()
        ])
    }

    private func pcmLevel(in data: Data) -> Double {
        var sumSquares = 0.0
        var sampleCount = 0

        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for sample in samples {
                let normalized = Double(sample) / Double(Int16.max)
                sumSquares += normalized * normalized
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return 0 }
        return min(1, sqrt(sumSquares / Double(sampleCount)) * 8)
    }

    private func playAudioDelta(_ base64Audio: String) {
        guard let data = Data(base64Encoded: base64Audio), !data.isEmpty else { return }
        audioChunksReceived += 1

        do {
            if !isRecording {
                try configureAudioSession()
            }
            preparePlaybackNodes()
            try startAudioEngine()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(sampleCount)) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        guard let floatSamples = buffer.floatChannelData?[0] else {
            return
        }

        data.withUnsafeBytes { rawBuffer in
            for index in 0..<sampleCount {
                let byteOffset = index * MemoryLayout<Int16>.size
                let sample = Int16(littleEndian: rawBuffer.loadUnaligned(fromByteOffset: byteOffset, as: Int16.self))
                let amplified = Float(sample) / 32_768.0 * playbackGain
                floatSamples[index] = max(-1.0, min(1.0, amplified))
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        startPlayerIfNeeded()
    }

    private func stopPlayback() {
        if playerNode.isPlaying {
            playerNode.stop()
        }
    }

    private func stopAudioSession() {
        if captureEngine.isRunning {
            captureEngine.stop()
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                completion(true)
            case .denied:
                completion(false)
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        completion(granted)
                    }
                }
            @unknown default:
                completion(false)
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                completion(true)
            case .denied:
                completion(false)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        completion(granted)
                    }
                }
            @unknown default:
                completion(false)
            }
        }
    }
}
