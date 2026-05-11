import Foundation
import AVFoundation
import SpeechEngineToB

enum DoubaoVoiceOption: String, CaseIterable, Identifiable {
    case tim = "en_male_tim_uranus_bigtts"
    case dacey = "en_female_dacey_uranus_bigtts"
    case stokie = "en_female_stokie_uranus_bigtts"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tim:
            "Tim"
        case .dacey:
            "Dacey"
        case .stokie:
            "Stokie"
        }
    }

    var description: String {
        switch self {
        case .tim:
            "Male · American English"
        case .dacey, .stokie:
            "Female · American English"
        }
    }
}

@MainActor
final class DoubaoVoiceClient: NSObject, ObservableObject {
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
    @Published var selectedVoice: DoubaoVoiceOption {
        didSet {
            UserDefaults.standard.set(selectedVoice.rawValue, forKey: Self.selectedVoiceKey)
            updateVoiceConfigIfNeeded()
        }
    }

    @Published var videoContext: String?

    private static let selectedVoiceKey = "DoubaoVoiceClient.selectedVoice"

    private var speechEngine: SpeechEngine?
    private var sessionId: String?
    private var conversationId: String?
    private var currentTranscript = ""
    private var currentReply = ""
    private var currentTranscriptSaved = false

    private let config: DoubaoConfig.Type = DoubaoConfig.self
    private lazy var dialogStore = LocalDialogStore(dialogId: config.dialogId)

    override init() {
        let savedVoiceId = UserDefaults.standard.string(forKey: Self.selectedVoiceKey)
        self.selectedVoice = savedVoiceId.flatMap(DoubaoVoiceOption.init(rawValue:)) ?? .dacey
        super.init()
    }

    private func debugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] [DoubaoVoice] \(message)")
    }

    func startCall(videoContext: String? = nil) {
        guard !isInCall, !isStartingCall else { return }

        self.videoContext = videoContext

        isInCall = true
        isStartingCall = true
        audioChunksSent = 0
        audioChunksReceived = 0
        inputLevel = 0
        errorMessage = nil
        childTranscript = "Call started. You can speak naturally."
        astraReply = "Hi! I'm here."
        voiceState = .thinking
        currentTranscript = ""
        currentReply = ""
        currentTranscriptSaved = false

        sessionId = nil
        conversationId = nil
        initializeEngine()
    }

    func endCall() {
        guard isInCall || isStartingCall else { return }

        isInCall = false
        isStartingCall = false
        inputLevel = 0
        voiceState = .thinking
        childTranscript = "Tap Start Call when you're ready."
        astraReply = "Great talking with you."

        if let engine = speechEngine {
            _ = engine.send(SEDirectiveStopEngine)
        }

        uninitializeEngine()
        sessionId = nil
        conversationId = nil
    }

    func cancelResponse() {
        // Doubao SDK doesn't have a direct cancel response directive
        // We can stop and restart the engine if needed
        debugLog("Cancel response requested")
    }

    private func initializeEngine() {
        debugLog("Initializing Doubao engine...")

        let engine = SpeechEngine()
        guard engine.createEngine(with: self) else {
            let errorDetail = "Failed to create speech engine"
            debugLog("ERROR: \(errorDetail)")
            errorMessage = errorDetail
            isStartingCall = false
            isInCall = false
            return
        }
        debugLog("Speech engine created successfully")

        speechEngine = engine

        // Configure engine parameters
        engine.setStringParam(SE_DIALOG_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
        engine.setStringParam(config.appId, forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine.setStringParam(config.appKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
        engine.setStringParam(config.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
        engine.setStringParam(config.resourceId, forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
        engine.setStringParam(config.address, forKey: SE_PARAMS_KEY_DIALOG_ADDRESS_STRING)
        engine.setStringParam(config.uri, forKey: SE_PARAMS_KEY_DIALOG_URI_STRING)

        // Enable AEC (Acoustic Echo Cancellation)
        engine.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)

        // Extract AEC model from bundle
        if let aecModelPath = extractAECModel() {
            engine.setStringParam(aecModelPath, forKey: SE_PARAMS_KEY_AEC_MODEL_PATH_STRING)
        }

        // Use device microphone
        engine.setStringParam(SE_RECORDER_TYPE_RECORDER, forKey: SE_PARAMS_KEY_RECORDER_TYPE_STRING)

        // Enable built-in player
        engine.setBoolParam(true, forKey: SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL)

        // Debug settings
        let debugPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
        engine.setStringParam(debugPath, forKey: SE_PARAMS_KEY_DEBUG_PATH_STRING)
        engine.setStringParam(SE_LOG_LEVEL_INFO, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)

        // Initialize engine
        debugLog("Calling engine.initEngine()...")
        let result = engine.initEngine()
        if result != SENoError {
            let errorDetail = "Failed to initialize engine: error code \(result.rawValue)"
            debugLog("ERROR: \(errorDetail)")
            errorMessage = errorDetail
            isStartingCall = false
            isInCall = false
            speechEngine = nil
            return
        }

        debugLog("Engine initialized successfully")
        currentEndpoint = "Doubao Cloud"
        isConnected = true

        // Start the dialog engine
        startEngine()
    }

    private func startEngine() {
        guard let engine = speechEngine else {
            debugLog("ERROR: speechEngine is nil")
            return
        }

        guard let startJson = makeStartEngineConfig() else {
            let errorDetail = "Failed to build start engine config"
            debugLog("ERROR: \(errorDetail)")
            errorMessage = errorDetail
            isStartingCall = false
            isInCall = false
            return
        }

        debugLog("Starting engine with config: \(startJson)")
        let result = engine.send(SEDirectiveStartEngine, data: startJson)

        if result == SERecCheckEnvironmentFailed {
            let errorDetail = "Microphone permission denied"
            debugLog("ERROR: \(errorDetail)")
            errorMessage = errorDetail
            isStartingCall = false
            isInCall = false
        } else if result != SENoError {
            let errorDetail = "Failed to start engine: error code \(result.rawValue)"
            debugLog("ERROR: \(errorDetail)")
            errorMessage = errorDetail
            isStartingCall = false
            isInCall = false
        } else {
            debugLog("Engine start command sent successfully")
        }
    }



    private func makeTTSConfig() -> [String: Any] {
        [
            "tts": [
                "speaker": selectedVoice.rawValue
            ]
        ]
    }

    private func updateVoiceConfigIfNeeded() {
        guard isInCall || isStartingCall, let engine = speechEngine else { return }
        let payload = makeTTSConfig()
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            debugLog("Failed to build voice update config")
            return
        }

        debugLog("Updating voice config: \(json)")
        let result = engine.send(SEDirectiveEventUpdateConfig, data: json)
        if result != SENoError {
            debugLog("Failed to update voice config: error code \(result.rawValue)")
        }
    }

    private func makeStartEngineConfig() -> String? {
        // StartEngine data follows Volcengine Dialog StartSession parameters.
        // Uranus BigTTS speakers below are O2.0-only voices.
        var dialogContext = dialogStore.recentContext(maxQAPairs: 20)
        debugLog("Loaded \(dialogContext.count) local dialog context messages for dialog_id=\(config.dialogId)")

        // Inject video content context if available
        if let videoContext = videoContext {
            let systemMessage: [String: Any] = [
                "role": "system",
                "text": "Video content: \(videoContext)"
            ]
            dialogContext.insert(systemMessage, at: 0)
            debugLog("Injected video context (\(videoContext.count) chars)")
        }

        let payload: [String: Any] = [
            "dialog": [
                "bot_name": config.botName,
                "system_role": config.systemRole,
                "speaking_style": config.speakingStyle,
                "dialog_id": config.dialogId,
                "character_manifest": config.systemRole,
                "dialog_context": dialogContext,
                "extra": [
                    "model": config.model
                ]
            ],
            "tts": makeTTSConfig()["tts"] as Any
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    private func uninitializeEngine() {
        if let engine = speechEngine {
            debugLog("Destroying engine")
            engine.destroy()
            speechEngine = nil
        }
        isConnected = false
        currentEndpoint = "Disconnected"
    }

    private func extractAECModel() -> String? {
        guard let bundlePath = Bundle.main.path(forResource: "aec", ofType: "model") else {
            debugLog("AEC model not found in bundle")
            return nil
        }

        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let destinationPath = (documentsPath as NSString).appendingPathComponent("aec.model")

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destinationPath) {
            do {
                try fileManager.copyItem(atPath: bundlePath, toPath: destinationPath)
                debugLog("AEC model copied to: \(destinationPath)")
            } catch {
                debugLog("Failed to copy AEC model: \(error.localizedDescription)")
                return nil
            }
        }

        return destinationPath
    }
}

// MARK: - SpeechEngineDelegate
extension DoubaoVoiceClient: SpeechEngineDelegate {
    nonisolated func onMessage(with type: SEMessageType, andData data: Data) {
        Task { @MainActor in
            handleMessage(type: type, data: data)
        }
    }

    private func handleMessage(type: SEMessageType, data: Data?) {
        let dataString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        switch type {
        case SEEngineStart:
            debugLog("Engine started")
            isStartingCall = false
            isRecording = true
            voiceState = .listening
            childTranscript = "Listening live..."

        case SEEngineStop:
            debugLog("Engine stopped")
            isRecording = false
            voiceState = .thinking

        case SEEngineError:
            debugLog("Engine error: \(dataString)")
            errorMessage = dataString
            voiceState = .thinking

        case SEEventASRResponse:
            handleASRResponse(data: data)

        case SEEventASREnded:
            debugLog("ASR ended")
            voiceState = .thinking
            saveCurrentTranscriptIfNeeded()

        case SEEventChatResponse:
            handleChatResponse(data: data)

        case SEEventChatEnded:
            debugLog("Chat ended")
            voiceState = .listening
            saveCurrentReplyIfNeeded()
            currentReply = ""
            currentTranscript = ""
            currentTranscriptSaved = false

        case SEEventASRInfo:
            debugLog("ASR info: \(dataString)")

        default:
            debugLog("Unhandled message type: \(type.rawValue)")
        }
    }


    private func saveCurrentTranscriptIfNeeded() {
        let text = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !currentTranscriptSaved else { return }
        dialogStore.append(role: LocalDialogStore.userRole, text: text)
        currentTranscriptSaved = true
        debugLog("Saved user transcript locally for dialog_id=\(config.dialogId)")
    }

    private func saveCurrentReplyIfNeeded() {
        let text = currentReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        dialogStore.append(role: LocalDialogStore.assistantRole, text: text)
        debugLog("Saved assistant reply locally for dialog_id=\(config.dialogId)")
    }

    private func handleASRResponse(data: Data?) {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let firstResult = results.first,
              let text = firstResult["text"] as? String else {
            return
        }

        if text != currentTranscript {
            currentTranscriptSaved = false
        }
        currentTranscript = text
        childTranscript = text
        audioChunksSent += 1
        debugLog("ASR: \(text)")
    }

    private func handleChatResponse(data: Data?) {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String else {
            return
        }

        voiceState = .speaking
        currentReply += content
        astraReply = currentReply
        audioChunksReceived += 1
        debugLog("Chat response: \(content)")
    }
}
