import SwiftUI

/// Shown only if the bundled ASR model is missing (should not happen in production builds).
struct ModelMissingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("语音模型缺失")
                .font(.headline)

            Text("请重新安装 Azex Speech 以恢复语音识别功能。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 320)
        .padding(24)
    }
}
