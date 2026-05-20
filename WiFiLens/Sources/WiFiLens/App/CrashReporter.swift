import Foundation

/// Lightweight crash reporter — writes stack traces to disk for review on the next launch.
enum CrashReporter {
    private static let logDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/WiFiLens")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let crashLogURL = logDir.appendingPathComponent("crash.log")

    static func consumeCrashLog() -> String? {
        guard let data = try? Data(contentsOf: crashLogURL),
              let text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }
        try? FileManager.default.removeItem(at: crashLogURL)
        return text
    }

    static func register() {
        NSSetUncaughtExceptionHandler(exceptionHandler)
        signal(SIGILL,  crashHandler)
        signal(SIGTRAP, crashHandler)
        signal(SIGABRT, crashHandler)
        signal(SIGBUS,  crashHandler)
        signal(SIGSEGV, crashHandler)
    }

    fileprivate static func write(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(ts)] \(message)\n"
        try? entry.data(using: .utf8)?.write(to: crashLogURL, options: .atomic)
    }
}

// MARK: - C function pointers (must not capture context)

private func crashHandler(_ sig: Int32) {
    let name = switch sig {
    case SIGILL:  "SIGILL"
    case SIGTRAP: "SIGTRAP"
    case SIGABRT: "SIGABRT"
    case SIGBUS:  "SIGBUS"
    case SIGSEGV: "SIGSEGV"
    default:      "SIGNAL(\(sig))"
    }
    let trace = Thread.callStackSymbols.joined(separator: "\n")
    CrashReporter.write("Signal \(name):\n\(trace)")
    signal(sig, SIG_DFL)
    kill(getpid(), sig)
}

private func exceptionHandler(_ exception: NSException) {
    let trace = exception.callStackSymbols.joined(separator: "\n")
    let msg = "NSException: \(exception.name.rawValue)\n\(exception.reason ?? "")\n\(trace)"
    CrashReporter.write(msg)
}
