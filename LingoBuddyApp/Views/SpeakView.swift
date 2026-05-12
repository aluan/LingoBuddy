import SwiftUI

enum VoiceInteractionState: CaseIterable {
    case listening
    case thinking
    case speaking

    var title: String {
        switch self {
        case .listening:
            "Listening"
        case .thinking:
            "Thinking"
        case .speaking:
            "Speaking"
        }
    }

    var icon: String {
        switch self {
        case .listening:
            "phone.fill"
        case .thinking:
            "phone.connection.fill"
        case .speaking:
            "waveform"
        }
    }
}

struct SpeakView: View {
    let onBack: () -> Void
    @StateObject private var realtime = DoubaoVoiceClient()

    private let pageGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.99, blue: 0.96),
            Color(red: 0.82, green: 0.94, blue: 0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            pageGradient.ignoresSafeArea()

            VStack(spacing: 18) {
                topBar

                statusCard

                voicePicker

                ScrollView {
                    VStack(spacing: 12) {
                        transcriptBubble(
                            label: "You",
                            text: realtime.childTranscript,
                            icon: "person.fill",
                            tint: Color(red: 0.10, green: 0.45, blue: 0.74),
                            lineLimit: 3
                        )

                        transcriptBubble(
                            label: "Astra",
                            text: realtime.astraReply,
                            icon: "sparkles",
                            tint: Color(red: 0.86, green: 0.38, blue: 0.18),
                            lineLimit: nil
                        )
                    }
                    .padding(.vertical, 2)
                }

                callControls

                Text(statusHint)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                connectionDebug

                if realtime.isInCall {
                    audioDebug
                }

                if let error = realtime.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.72, green: 0.12, blue: 0.10))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.91, blue: 0.89))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 26)
        }
        .onDisappear {
            realtime.endCall()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.white.opacity(0.78)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to home")

            VStack(alignment: .leading, spacing: 2) {
                Text("Talk with Astra")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Live voice call")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("\(realtime.totalStars)", systemImage: "star.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.73, green: 0.41, blue: 0.05))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color(red: 1.0, green: 0.92, blue: 0.75)))
                .accessibilityLabel("\(realtime.totalStars) stars")
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: voiceState.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(statusColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(statusColor.opacity(0.13)))

            VStack(alignment: .leading, spacing: 3) {
                Text(voiceState.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text(statusDescription)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.78))
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.84), value: voiceState)
    }


    private var voicePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Astra Voice", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Spacer()

                Text(realtime.selectedVoice.description)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Picker("Astra Voice", selection: $realtime.selectedVoice) {
                ForEach(DoubaoVoiceOption.allCases) { voice in
                    Text(voice.displayName).tag(voice)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.70))
        )
        .accessibilityElement(children: .contain)
        .accessibilityHint("Choose Astra's American English voice. During a call, the new voice is applied immediately.")
    }

    private var callControls: some View {
        HStack(spacing: 14) {
            Button(action: { realtime.startCall() }) {
                Label("Start Call", systemImage: "phone.fill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.13, green: 0.53, blue: 0.45))
                    )
            }
            .buttonStyle(.plain)
            .disabled(realtime.isInCall || realtime.isStartingCall)
            .opacity(realtime.isInCall || realtime.isStartingCall ? 0.42 : 1)
            .accessibilityLabel("Start call")

            Button(action: realtime.endCall) {
                Label("End Call", systemImage: "phone.down.fill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.78, green: 0.16, blue: 0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!realtime.isInCall && !realtime.isStartingCall)
            .opacity(!realtime.isInCall && !realtime.isStartingCall ? 0.42 : 1)
            .accessibilityLabel("End call")
        }
    }

    private var connectionDebug: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(realtime.isConnected ? Color(red: 0.13, green: 0.53, blue: 0.45) : Color(red: 0.86, green: 0.52, blue: 0.14))
                .frame(width: 8, height: 8)

            Text(realtime.currentEndpoint)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.56))
        )
        .accessibilityLabel("Voice server \(realtime.currentEndpoint)")
    }

    private var audioDebug: some View {
        HStack(spacing: 10) {
            Text("Audio in \(realtime.audioChunksSent) / out \(realtime.audioChunksReceived)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(Color(red: 0.13, green: 0.53, blue: 0.45))
                        .frame(width: max(6, proxy.size.width * realtime.inputLevel))
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.56))
        )
        .accessibilityLabel("Sent \(realtime.audioChunksSent) audio chunks and received \(realtime.audioChunksReceived)")
    }

    private var voiceState: VoiceInteractionState {
        realtime.voiceState
    }

    private var statusColor: Color {
        switch voiceState {
        case .listening:
            Color(red: 0.13, green: 0.53, blue: 0.45)
        case .thinking:
            Color(red: 0.86, green: 0.52, blue: 0.14)
        case .speaking:
            Color(red: 0.12, green: 0.45, blue: 0.78)
        }
    }

    private var statusDescription: String {
        switch voiceState {
        case .listening:
            realtime.isInCall ? "Astra can hear you now." : "Ready when you are."
        case .thinking:
            realtime.isStartingCall ? "Connecting the call." : "Astra is preparing a reply."
        case .speaking:
            "Listen, then answer back."
        }
    }

    private var statusHint: String {
        if realtime.isStartingCall {
            return "Starting live call..."
        }

        if realtime.isInCall {
            return realtime.isRecording ? "Live call is on" : "Call connected, preparing microphone"
        }

        return "Tap Start Call to begin"
    }

    private func transcriptBubble(label: String, text: String, icon: String, tint: Color, lineLimit: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)

            Text(text)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    SpeakView(onBack: {})
}
