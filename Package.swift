// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AzexSpeech",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AzexSpeech", targets: ["AzexSpeech"])
    ],
    dependencies: [
        // Global hotkeys
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        // C module wrapping sherpa-onnx static library
        .target(
            name: "CSherpaOnnx",
            path: "Sources/CSherpaOnnx",
            publicHeadersPath: "include",
            linkerSettings: [
                // unsafeFlags required: SPM binaryTarget doesn't support static .a xcframeworks.
                // This prevents AzexSpeech from being used as an SPM dependency by other packages.
                .unsafeFlags([
                    "-L\(Context.packageDirectory)/Frameworks/sherpa-onnx.xcframework/macos-arm64_x86_64",
                    "-L\(Context.packageDirectory)/Frameworks",
                ]),
                .linkedLibrary("sherpa-onnx"),
                .linkedLibrary("onnxruntime"),
                .linkedLibrary("c++"),
            ]
        ),
        .executableTarget(
            name: "AzexSpeech",
            dependencies: [
                "KeyboardShortcuts",
                "CSherpaOnnx",
            ],
            path: "Sources/AzexSpeech",
            resources: [
                .copy("../../Resources/domain-ai.json"),
                .copy("../../Resources/domain-crypto.json"),
                .copy("../../Resources/azex-logo.png"),
                .copy("../../Resources/calibration-ai.txt"),
                .copy("../../Resources/calibration-crypto.txt"),
                .copy("../../Resources/calibration-both.txt"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "\(Context.packageDirectory)/Frameworks",
                ]),
            ]
        ),
    ]
)
