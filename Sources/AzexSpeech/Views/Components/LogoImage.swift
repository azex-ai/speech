import SwiftUI

/// Loads the AZEX logo from SPM Bundle.module resources.
struct LogoImage: View {
    var size: CGFloat = 32

    var body: some View {
        if let nsImage = loadLogo() {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            // Fallback: SF Symbol
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .frame(width: size, height: size)
                .foregroundStyle(.blue)
        }
    }

    private func loadLogo() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "azex-logo", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }
}
