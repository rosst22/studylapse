import SwiftData
import SwiftUI

struct ActiveSessionView: View {
    @Environment(TimeLapseRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("frameInterval") private var frameInterval: Double = 4
    @AppStorage("useFrontCamera") private var useFrontCamera = true
    @AppStorage("lastSubject") private var lastSubject = ""

    @State private var subject = ""
    /// Screen goes black during a session to save battery. Auto-engages 30 s in.
    @State private var dimmed = false
    @State private var dimTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .padding(28)
        }
        .task {
            Trace.mark("ActiveSessionView .task fired")
            subject = lastSubject.isEmpty ? "Study" : lastSubject
            var config = CaptureConfiguration()
            config.frameInterval = frameInterval
            config.cameraPosition = useFrontCamera ? .front : .back
            recorder.config = config
            await recorder.prepare(interfaceOrientation: InterfaceOrientation.current)
        }
        .onDisappear { dimTask?.cancel() }
        // Tapping anywhere wakes the screen back up mid-session.
        .contentShape(Rectangle())
        .onTapGesture { if dimmed { undim() } }
    }

    @ViewBuilder private var content: some View {
        switch recorder.state {
        case .idle, .preparing:
            ProgressView().tint(.green)
        case .ready:
            framingScreen.onAppear { Trace.mark("framingScreen on screen") }
        default:
            recordingScreen.onAppear { Trace.mark("recordingScreen on screen") }
        }
    }

    // MARK: - Before the clock starts

    private var framingScreen: some View {
        VStack(spacing: 20) {
            if let previewLayer = recorder.previewLayer, recorder.mode.isEnabled {
                CameraPreview(previewLayer: previewLayer)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        // The camera takes a moment to hand over its first frame.
                        // Without this the preview is just a black box and the app
                        // looks hung.
                        if !recorder.previewLive {
                            VStack(spacing: 10) {
                                ProgressView().tint(.green)
                                Text("Starting camera…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if recorder.previewLive {
                            Text("Prop your phone up and frame your desk")
                                .font(.caption)
                                .padding(8)
                                .background(.black.opacity(0.5), in: Capsule())
                                .padding(10)
                        }
                    }
            } else if let reason = recorder.mode.reason {
                unavailableCard(reason)
            }

            TextField("Subject", text: $subject)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)

            Button {
                Trace.mark("tap Start session (framing) -> beginRecording")
                lastSubject = subject
                recorder.beginRecording(subject: subject)
                scheduleAutoDim()
            } label: {
                Label(recorder.mode.isEnabled ? "Start session" : "Start timer only",
                      systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(recorder.mode.isEnabled && !recorder.previewLive)

            Button("Cancel") {
                Task { await recorder.discard(); dismiss() }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func unavailableCard(_ reason: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(reason)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if recorder.mode == .cameraDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Running

    private var recordingScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            if !dimmed, recorder.mode.isEnabled, let previewLayer = recorder.previewLayer {
                CameraPreview(previewLayer: previewLayer)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .transition(.opacity)
            }

            Text(recorder.elapsed.clockLabel)
                .font(.system(size: 62, weight: .light, design: .monospaced))
                .foregroundStyle(.white.opacity(dimmed ? 0.5 : 0.9))
                .contentTransition(.numericText())

            Text(subject)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            statusLine

            Spacer()

            if !dimmed {
                HStack(spacing: 16) {
                    Text("\(recorder.frameCount) frames")
                    Text("~\(Int(recorder.estimatedBytes).byteLabel)")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)

                Button("Dim screen") { dim() }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            stopButton
                .opacity(dimmed ? 0.35 : 1)
        }
        .animation(.easeInOut(duration: 0.35), value: dimmed)
    }

    @ViewBuilder private var statusLine: some View {
        switch recorder.state {
        case .interrupted(let reason):
            VStack(spacing: 6) {
                Label(reason.shortLabel, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                if !dimmed {
                    Text(reason.explanation)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(.orange)
        case .recording where recorder.mode.isEnabled && !dimmed:
            Label("Recording — the green dot in the status bar is your lapse",
                  systemImage: "record.circle")
                .font(.caption)
                .foregroundStyle(.green.opacity(0.7))
                .multilineTextAlignment(.center)
        case .recording where !recorder.mode.isEnabled && !dimmed:
            Label("Timer only, no lapse", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    private var stopButton: some View {
        Button {
            dimTask?.cancel()
            Task {
                if let result = await recorder.stop() {
                    context.insert(StudySession(subject: subject, result: result))
                }
                dismiss()
            }
        } label: {
            Label("Stop", systemImage: "stop.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red.opacity(0.85))
        .disabled(recorder.state == .finishing)
    }

    // MARK: - Dimming

    private func scheduleAutoDim() {
        dimTask?.cancel()
        dimTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            dim()
        }
    }

    /// Black pixels, not system brightness. Forcing the device brightness down
    /// would leave the user stuck dim if we crashed before restoring it, and an
    /// OLED panel draws almost nothing for a black pixel anyway.
    private func dim() {
        withAnimation { dimmed = true }
        recorder.setPreviewVisible(false)   // sensor drops to ~1 fps
    }

    private func undim() {
        withAnimation { dimmed = false }
        recorder.setPreviewVisible(true)    // smooth viewfinder again
        scheduleAutoDim()
    }
}
