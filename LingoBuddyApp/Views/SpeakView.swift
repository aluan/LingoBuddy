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
            "ear"
        case .thinking:
            "sparkles"
        case .speaking:
            "waveform"
        }
    }
}

struct SpeakView: View {
    let onBack: () -> Void
    @StateObject private var realtime = VoiceRealtimeClient()
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DesignImageBackground(imageName: "speak")

                Button(action: onBack) {
                    Circle().fill(Color.white.opacity(0.001))
                }
                .buttonStyle(.plain)
                .frame(width: proxy.size.width * 0.16, height: proxy.size.width * 0.16)
                .contentShape(Circle())
                .position(x: proxy.size.width * 0.09, y: proxy.size.height * 0.075)
                .accessibilityLabel("Back to home")

                Text("\(realtime.totalStars) stars")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.28, green: 0.15, blue: 0.07))
                    .shadow(color: .white.opacity(0.65), radius: 1, x: 0, y: 1)
                    .position(x: proxy.size.width * 0.73, y: proxy.size.height * 0.076)

                transcriptBubble(
                    label: "Child",
                    text: realtime.childTranscript,
                    accent: Color(red: 0.07, green: 0.42, blue: 0.74),
                    textColor: Color(red: 0.04, green: 0.35, blue: 0.66)
                )
                .frame(width: proxy.size.width * 0.68)
                .position(x: proxy.size.width * 0.55, y: proxy.size.height * 0.50)

                transcriptBubble(
                    label: "Astra",
                    text: realtime.astraReply,
                    accent: Color(red: 0.96, green: 0.35, blue: 0.16),
                    textColor: Color(red: 0.80, green: 0.22, blue: 0.06)
                )
                .frame(width: proxy.size.width * 0.72)
                .position(x: proxy.size.width * 0.57, y: proxy.size.height * 0.60)

                statusPill
                    .frame(width: proxy.size.width * 0.39, height: proxy.size.height * 0.052)
                    .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.706)

                Button(action: realtime.microphoneTapped) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.45), lineWidth: 3)
                            .scaleEffect(pulse ? 1.26 : 0.92)
                            .opacity(pulse ? 0.05 : 0.65)

                        Circle()
                            .fill(Color.white.opacity(0.001))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: proxy.size.width * 0.36, height: proxy.size.width * 0.36)
                .contentShape(Circle())
                .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.828)
                .accessibilityLabel("Microphone")
                .accessibilityHint("Tap to send a voice turn to Astra")

                if let error = realtime.errorMessage {
                    Text(error)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.78))
                        )
                        .frame(width: proxy.size.width * 0.74)
                        .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.94)
                }

                rewardTapTarget(in: proxy)
            }
            .onAppear {
                realtime.connect()
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
            .onDisappear {
                realtime.disconnect()
            }
        }
        .ignoresSafeArea()
    }

    private var statusPill: some View {
        HStack(spacing: 9) {
            Image(systemName: voiceState.icon)
                .font(.system(size: 22, weight: .bold))
            Text(voiceState.title)
                .font(.system(size: 27, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 2)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(statusColor)
                .shadow(color: statusColor.opacity(0.58), radius: 14, x: 0, y: 0)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: voiceState)
    }

    private var voiceState: VoiceInteractionState {
        realtime.voiceState
    }

    private var statusColor: Color {
        switch voiceState {
        case .listening:
            Color(red: 0.13, green: 0.65, blue: 0.30)
        case .thinking:
            Color(red: 0.94, green: 0.54, blue: 0.15)
        case .speaking:
            Color(red: 0.12, green: 0.53, blue: 0.90)
        }
    }

    private func rewardTapTarget(in proxy: GeometryProxy) -> some View {
        Button(action: {}) {
            Rectangle().fill(Color.white.opacity(0.001))
        }
        .buttonStyle(.plain)
        .frame(width: proxy.size.width * 0.22, height: proxy.size.height * 0.11)
        .contentShape(Rectangle())
        .position(x: proxy.size.width * 0.88, y: proxy.size.height * 0.87)
        .accessibilityLabel("Star rewards")
    }

    private func transcriptBubble(label: String, text: String, accent: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(accent)
                        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                )

            Text(text)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                )
        }
    }
}

#Preview {
    SpeakView(onBack: {})
}
