import Foundation
import Logging
import OSLog

/// Shared swift-log logger instances.
/// Call `Log.bootstrap()` once at launch.
enum Log {
    static func bootstrap() {
        LoggingSystem.bootstrap { label in
            var handler = OSLogHandler(label: label)
            handler.logLevel = .info
            return handler
        }
    }

    static let scanner  = Logging.Logger(label: "com.wifilens.scanner")
    static let mcp      = Logging.Logger(label: "com.wifilens.mcp")
    static let location = Logging.Logger(label: "com.wifilens.location")
    static let app       = Logging.Logger(label: "com.wifilens.app")
    static let throughput = Logging.Logger(label: "com.wifilens.throughput")
    static let table      = Logging.Logger(label: "com.wifilens.table")
}

/// swif-tlog LogHandler that writes to Apple's unified logging (Console.app).
private struct OSLogHandler: LogHandler {
    let label: String
    var logLevel: Logging.Logger.Level = .info
    var metadata = Logging.Logger.Metadata()

    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(level: Logging.Logger.Level, message: Logging.Logger.Message,
             metadata: Logging.Logger.Metadata?, source: String,
             file: String, function: String, line: UInt) {
        let oslog = os.Logger(subsystem: "com.wifilens", category: label)
        switch level {
        case .trace, .debug: oslog.debug("\(message)")
        case .info:          oslog.info("\(message)")
        case .notice:        oslog.notice("\(message)")
        case .warning:       oslog.warning("\(message)")
        case .error:         oslog.error("\(message)")
        case .critical:      oslog.fault("\(message)")
        }
    }
}
