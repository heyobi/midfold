import Foundation

/// Turns a stream of hinge angles into wing flaps. One "pump" = close the phone a little, then open it again.
/// The flap fires when the closing stroke turns around, with a strength from the stroke's depth and its fastest
/// closing speed: a quick, deep pump is a strong flap, a shallow one a small hop. Light smoothing, hysteresis and
/// a minimum depth keep hand tremor and sensor jitter from flapping.
struct PumpDetector {
    /// 0.5 … 1.5, from Settings. Scales the strength of every flap.
    var sensitivity = 1.0
    var minDepth = 7.0          // degrees a stroke must close to count
    var hysteresis = 3.0        // degrees of movement that confirm a change of direction
    var cooldown = 0.10         // seconds between flaps
    var smoothing = 0.025       // seconds, low-pass time constant

    private(set) var smoothed: Double?
    private(set) var closing = false
    private var lastT: Double?
    private var top = 0.0
    private var bottom = 0.0
    private var peakSpeed = 0.0
    private var lastFlapT = -Double.infinity

    /// Feeds one sample (degrees, seconds). Returns a flap strength 0…1 when a pump completes.
    mutating func feed(angle: Double, at t: Double) -> Double? {
        guard let s = smoothed, let lt = lastT else {
            smoothed = angle; lastT = t; top = angle; bottom = angle
            return nil
        }
        let dt = t - lt
        guard dt > 0 else { return nil }
        let a = s + (angle - s) * min(1, dt / max(smoothing, 1e-3))
        let speed = (s - a) / dt           // positive while closing
        smoothed = a
        lastT = t
        if !closing {
            top = max(top, a)
            if top - a >= hysteresis {
                closing = true
                bottom = a
                peakSpeed = max(0, speed)
            }
        } else {
            bottom = min(bottom, a)
            peakSpeed = max(peakSpeed, speed)
            if a - bottom >= hysteresis {
                closing = false
                let depth = top - bottom
                top = a
                if depth >= minDepth && t - lastFlapT >= cooldown {
                    lastFlapT = t
                    return Self.strength(depth: depth, speed: peakSpeed, sensitivity: sensitivity)
                }
            }
        }
        return nil
    }

    static func strength(depth: Double, speed: Double, sensitivity: Double) -> Double {
        let s = 0.55 * min(1, depth / 70) + 0.45 * min(1, speed / 350)
        return min(1, max(0.12, s * sensitivity))
    }

    mutating func reset() {
        smoothed = nil; lastT = nil; closing = false; peakSpeed = 0
    }
}
