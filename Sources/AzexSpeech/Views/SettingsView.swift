import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }

            VocabSettingsView()
                .tabItem { Label("Vocabulary", systemImage: "book") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Record", name: .toggleRecording)
            }

            Section("Domain") {
                // TODO: Domain selector (AI / Crypto / Both)
                Text("AI + Crypto")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct VocabSettingsView: View {
    @State private var vocabEntries: [(String, String)] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Personal Vocabulary")
                .font(.headline)

            Text("Words learned from your corrections. Edit or remove entries below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(Array(vocabEntries.enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(entry.0)
                            .foregroundStyle(.red)
                            .strikethrough()
                        Text("→")
                        Text(entry.1)
                            .bold()
                    }
                }
            }

            HStack {
                Button("Refresh Domain Vocab") {
                    // TODO: Pull latest from speech.azex.ai
                }
                Spacer()
                Text("\(vocabEntries.count) entries")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear { loadVocab() }
    }

    private func loadVocab() {
        let mgr = VocabManager()
        mgr.loadAll()
        vocabEntries = mgr.personalVocab.corrections.sorted { $0.key < $1.key }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Azex Speech")
                .font(.title2.bold())

            Text("Voice input for Crypto + AI professionals")
                .foregroundStyle(.secondary)

            Link("speech.azex.ai", destination: URL(string: "https://speech.azex.ai")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
