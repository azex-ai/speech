import SwiftUI

/// Shows download progress for the Paraformer-zh ASR model on first launch.
struct ModelDownloadView: View {
    @ObservedObject var manager: ModelManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Downloading Speech Model")
                .font(.headline)

            Text("Paraformer-zh (~217 MB)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if manager.isDownloading {
                ProgressView(value: manager.downloadProgress)
                    .progressViewStyle(.linear)

                Text("\(Int(manager.downloadProgress * 100))%")
                    .font(.system(.body, design: .monospaced).monospacedDigit())
                    .foregroundStyle(.secondary)

                Button("Cancel") {
                    manager.cancelDownload()
                }
                .buttonStyle(.bordered)
            }

            if let error = manager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task {
                        manager.error = nil
                        await manager.downloadModelIfNeeded()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 320)
        .padding(24)
    }
}
