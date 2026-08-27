import SwiftUI

struct SettingsView: View {
    @AppStorage("frameInterval") private var frameInterval: Double = 4
    @AppStorage("useFrontCamera") private var useFrontCamera = true
    @Environment(\.dismiss) private var dismiss

    private var config: CaptureConfiguration {
        var c = CaptureConfiguration()
        c.frameInterval = frameInterval
        return c
    }

    private let twoHours: TimeInterval = 7200

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Frame every", selection: $frameInterval) {
                        Text("2 seconds").tag(2.0)
                        Text("3 seconds").tag(3.0)
                        Text("4 seconds").tag(4.0)
                        Text("5 seconds").tag(5.0)
                    }
                } header: {
                    Text("Time lapse")
                } footer: {
                    Text("Shorter intervals give a smoother lapse and a bigger file. "
                         + "Storage tracks the length of the finished video, not the "
                         + "length of your session.")
                }

                Section("A 2-hour session would be") {
                    row("Speed", String(format: "%.0f×", config.speedUpFactor))
                    row("Frames", "\(config.frameCount(forStudyDuration: twoHours))")
                    row("Video length",
                        config.outputDuration(forStudyDuration: twoHours).studyDurationLabel)
                    row("Estimated size",
                        Int(config.estimatedBytes(forStudyDuration: twoHours)).byteLabel)
                }

                Section("Camera") {
                    Picker("Use", selection: $useFrontCamera) {
                        Text("Front").tag(true)
                        Text("Back").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Label("Everything stays on this phone. StudyLapse has no account, "
                          + "no server, and never uploads your video.",
                          systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
