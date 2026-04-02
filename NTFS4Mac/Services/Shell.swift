import Foundation

// MARK: - Shell Command Execution

enum Shell {
    static func run(_ command: String, arguments: [String] = []) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func runWithSudo(_ command: String, arguments: [String]) async throws -> (stdout: String, exitCode: Int32) {
        // Build the full command string with proper shell escaping
        var parts = [command]
        for arg in arguments {
            // Simple escaping: if arg contains spaces or special chars, quote it
            if arg.contains(" ") || arg.contains("'") || arg.contains("\"") || arg.contains("$") {
                let escaped = arg
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                parts.append("\"\(escaped)\"")
            } else {
                parts.append(arg)
            }
        }
        let fullCommand = parts.joined(separator: " ")

        // Escape the command for AppleScript string
        let escapedForAppleScript = fullCommand.replacingOccurrences(of: "\"", with: "\\\"")

        // Use osascript to prompt for admin privileges in GUI
        let script = "do shell script \"\(escapedForAppleScript)\" with administrator privileges"

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return (String(data: stdoutData, encoding: .utf8) ?? "", process.terminationStatus)
    }

    static func runDiskutil(_ arguments: [String]) async throws -> String {
        try await run("/usr/sbin/diskutil", arguments: arguments)
    }
}
