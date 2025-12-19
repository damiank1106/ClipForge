import Foundation
import CoreGraphics

struct Keyframe<T: Codable & Equatable>: Codable, Equatable {
    var time: Double
    var value: T
}

struct KeyframedDouble: Codable, Equatable {
    var keyframes: [Keyframe<Double>]

    func value(at time: Double) -> Double {
        guard !keyframes.isEmpty else { return 0 }
        if keyframes.count == 1 { return keyframes[0].value }
        let sorted = keyframes.sorted { $0.time < $1.time }
        if time <= sorted[0].time { return sorted[0].value }
        if time >= sorted.last!.time { return sorted.last!.value }
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i], b = sorted[i + 1]
            if time >= a.time && time <= b.time {
                let t = (time - a.time) / max(0.0001, (b.time - a.time))
                return a.value + (b.value - a.value) * t
            }
        }
        return sorted.last!.value
    }
}

struct KeyframedTransform: Codable, Equatable {
    var keyframes: [Keyframe<CGAffineTransformCodable>]

    func value(at time: Double) -> CGAffineTransformCodable {
        guard !keyframes.isEmpty else { return .identity }
        if keyframes.count == 1 { return keyframes[0].value }
        let sorted = keyframes.sorted { $0.time < $1.time }
        if time <= sorted[0].time { return sorted[0].value }
        if time >= sorted.last!.time { return sorted.last!.value }
        // Linear interpolate components (simple, good for a starter)
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i], b = sorted[i + 1]
            if time >= a.time && time <= b.time {
                let t = (time - a.time) / max(0.0001, (b.time - a.time))
                return CGAffineTransformCodable.lerp(a.value, b.value, t: t)
            }
        }
        return sorted.last!.value
    }
}

/// Codable wrapper for CGAffineTransform
struct CGAffineTransformCodable: Codable, Equatable {
    var a: Double
    var b: Double
    var c: Double
    var d: Double
    var tx: Double
    var ty: Double

    static let identity = CGAffineTransformCodable(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    var cg: CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }

    static func lerp(_ x: CGAffineTransformCodable, _ y: CGAffineTransformCodable, t: Double) -> CGAffineTransformCodable {
        func L(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return .init(a: L(x.a,y.a), b: L(x.b,y.b), c: L(x.c,y.c), d: L(x.d,y.d), tx: L(x.tx,y.tx), ty: L(x.ty,y.ty))
    }
}
