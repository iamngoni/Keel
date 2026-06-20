import Foundation

enum DockerClientError: LocalizedError {
    case dockerExecutableMissing
    case commandFailed(command: String, code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .dockerExecutableMissing:
            return "Docker CLI not found. Install Docker Desktop, OrbStack, Colima, or another Docker Engine provider."
        case let .commandFailed(command, code, message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "\(command) failed with exit code \(code)." : trimmed
        }
    }
}

final class DockerClient {
    private let executableURL: URL
    private let decoder = JSONDecoder()

    init() throws {
        guard let executableURL = Self.findDockerExecutable() else {
            throw DockerClientError.dockerExecutableMissing
        }
        self.executableURL = executableURL
    }

    func daemon() async throws -> DockerDaemon {
        async let context = run(["context", "show"])
        async let version = run(["version", "--format", "{{.Server.Version}}"])
        return try await DockerDaemon(
            context: context.trimmingCharacters(in: .whitespacesAndNewlines),
            version: version.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func containers() async throws -> [DockerContainer] {
        let output = try await run(["ps", "-a", "--format", "{{json .}}"])
        return try decodeLineDelimitedJSON(output, as: DockerContainer.self)
    }

    func images() async throws -> [DockerImage] {
        let output = try await run(["images", "--format", "{{json .}}"])
        return try decodeLineDelimitedJSON(output, as: DockerImage.self)
    }

    func start(container: DockerContainer) async throws {
        _ = try await run(["start", container.id])
    }

    func stop(container: DockerContainer) async throws {
        _ = try await run(["stop", container.id])
    }

    func restart(container: DockerContainer) async throws {
        _ = try await run(["restart", container.id])
    }

    private func decodeLineDelimitedJSON<T: Decodable>(_ output: String, as type: T.Type) throws -> [T] {
        try output
            .split(whereSeparator: \.isNewline)
            .map { line in
                try decoder.decode(T.self, from: Data(line.utf8))
            }
    }

    private func run(_ arguments: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = self.executableURL
            process.arguments = arguments

            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw DockerClientError.commandFailed(
                    command: "docker \(arguments.joined(separator: " "))",
                    code: process.terminationStatus,
                    message: error.isEmpty ? output : error
                )
            }

            return output
        }.value
    }

    private static func findDockerExecutable() -> URL? {
        let candidates = [
            ProcessInfo.processInfo.environment["DOCKER_CLI"],
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker"
        ].compactMap { $0 }

        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
        for entry in pathEntries {
            let url = URL(fileURLWithPath: String(entry)).appendingPathComponent("docker")
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
