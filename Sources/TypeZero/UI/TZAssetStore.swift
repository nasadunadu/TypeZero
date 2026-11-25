import SwiftUI
import AppKit

/// Zero-overhead cached loader for TypeZero 2.0 studio CGI Liquid-Glass & 3D hardware PNG assets
/// bundled under `TypeZero.app/Contents/Resources/UIKitAssets/` (with automatic dev-tree fallback).
enum TZAssetStore {
    private static let lock = NSLock()
    private static var cache: [String: NSImage] = [:]

    static func nsImage(named name: String) -> NSImage? {
        lock.lock()
        if let cached = cache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let resolved: NSImage? = loadFromDisk(named: name)
        if let img = resolved {
            lock.lock()
            cache[name] = img
            lock.unlock()
        }
        return resolved
    }

    static func image(named name: String) -> Image? {
        guard let ns = nsImage(named: name) else { return nil }
        return Image(nsImage: ns)
    }

    private static func loadFromDisk(named name: String) -> NSImage? {
        // 1. Standard macOS .app bundle: Contents/Resources/UIKitAssets/<name>.png
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "UIKitAssets"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // 2. Fallback: flat resource inside Bundle.main
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // 3. Dev-tree fallback when launched via `swift run` outside .app bundle
        let cwd = FileManager.default.currentDirectoryPath
        let devPath = (cwd as NSString).appendingPathComponent("Resources/UIKitAssets/\(name).png")
        if FileManager.default.fileExists(atPath: devPath),
           let img = NSImage(contentsOfFile: devPath) {
            return img
        }
        return nil
    }
}
