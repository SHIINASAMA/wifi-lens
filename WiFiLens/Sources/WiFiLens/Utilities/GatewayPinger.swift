import Foundation

actor GatewayPinger {
    private var lastTask: Task<Double?, Never>?

    func ping(host: String) async -> Double? {
        lastTask?.cancel()
        let task = Task<Double?, Never> { [host] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", "1000", host]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else { return nil }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else { return nil }

                // Parse "time=XX.XXX ms" from ping output
                for line in output.components(separatedBy: "\n") {
                    if line.contains("time=") {
                        if let range = line.range(of: "time=") {
                            let rest = line[range.upperBound...]
                            let msStr = rest.components(separatedBy: " ").first ?? ""
                            return Double(msStr)
                        }
                    }
                }
                return nil
            } catch {
                return nil
            }
        }
        lastTask = task
        return await task.value
    }
}
