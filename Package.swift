// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeZero",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TypeZero", targets: ["TypeZero"])
    ],
    targets: [
        .target(
            name: "CSherpaOnnx",
            path: "Sources/CSherpaOnnx",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "TypeZero",
            dependencies: ["CSherpaOnnx"],
            path: "Sources/TypeZero",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-LVendor/sherpa-onnx-v1.13.8-osx-arm64-shared-no-tts-lib/lib",
                    "-lsherpa-onnx-c-api",
                    "-lonnxruntime",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ]),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("IOKit"),
                .linkedFramework("Speech"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreImage"),
                .linkedFramework("ImageIO")
            ]
        )
    ]
)
