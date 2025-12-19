import Foundation

enum Log {
    static func info(_ msg: String) { print("[ClipForge] \(msg)") }
    static func warn(_ msg: String) { print("[ClipForge][WARN] \(msg)") }
    static func error(_ msg: String) { print("[ClipForge][ERROR] \(msg)") }
}
