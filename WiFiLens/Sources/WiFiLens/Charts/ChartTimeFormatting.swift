import Foundation

func chartDurationLabel(_ seconds: TimeInterval, zeroText: String = "0s") -> String {
    if seconds < 1 { return zeroText }
    if seconds < 60 { return "\(Int(seconds))s" }
    let m = Int(seconds) / 60
    let s = Int(seconds) % 60
    if s == 0 { return "\(m)m" }
    return "\(m):\(String(format: "%02d", s))"
}
