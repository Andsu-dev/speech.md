// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "speech-md",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "speech-md", targets: ["SpeechMD"])
    ],
    targets: [
        .executableTarget(
            name: "SpeechMD",
            path: "Sources/SpeechMD",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Speech"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
