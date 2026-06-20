import Foundation
import SwiftUI

struct DockerContainer: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let image: String
    let status: String
    let state: String
    let ports: String

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "Names"
        case image = "Image"
        case status = "Status"
        case state = "State"
        case ports = "Ports"
    }

    var isRunning: Bool {
        state.lowercased() == "running"
    }

    var shortID: String {
        String(id.prefix(12))
    }

    var projectName: String {
        DockerNameFormatter.projectName(for: name)
    }

    var serviceName: String {
        DockerNameFormatter.serviceName(for: name)
    }

    var badgeText: String {
        if status.localizedCaseInsensitiveContains("healthy") {
            return "Healthy"
        }
        if isRunning {
            return "Running"
        }
        return state.isEmpty ? "Stopped" : state.capitalized
    }

    var statusColor: Color {
        if status.localizedCaseInsensitiveContains("healthy") || isRunning {
            return KeelTheme.healthy
        }
        if state.localizedCaseInsensitiveContains("exited") {
            return KeelTheme.warning
        }
        return KeelTheme.textMuted
    }

    var displayPorts: String {
        let trimmed = ports.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }

    var portProtocolLabel: String {
        guard displayPorts != "-" else {
            return "No published ports"
        }
        if displayPorts.localizedCaseInsensitiveContains("udp") {
            return "TCP, UDP"
        }
        return "TCP"
    }
}

struct DockerImage: Identifiable, Decodable, Equatable {
    let repository: String
    let tag: String
    let id: String
    let createdSince: String
    let size: String

    enum CodingKeys: String, CodingKey {
        case repository = "Repository"
        case tag = "Tag"
        case id = "ID"
        case createdSince = "CreatedSince"
        case size = "Size"
    }

    var displayName: String {
        if repository == "<none>" {
            return id
        }
        return "\(repository):\(tag)"
    }
}

struct DockerDaemon: Equatable {
    let context: String
    let version: String
}

struct DockerContainerStats: Identifiable, Decodable, Equatable {
    let containerID: String
    let name: String
    let cpuPercentage: String
    let memoryUsage: String
    let memoryPercentage: String
    let networkIO: String
    let blockIO: String

    var id: String { containerID.isEmpty ? name : containerID }

    enum CodingKeys: String, CodingKey {
        case containerID = "ID"
        case name = "Name"
        case cpuPercentage = "CPUPerc"
        case memoryUsage = "MemUsage"
        case memoryPercentage = "MemPerc"
        case networkIO = "NetIO"
        case blockIO = "BlockIO"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        containerID = try container.decodeIfPresent(String.self, forKey: .containerID) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        cpuPercentage = try container.decodeIfPresent(String.self, forKey: .cpuPercentage) ?? "-"
        memoryUsage = try container.decodeIfPresent(String.self, forKey: .memoryUsage) ?? "-"
        memoryPercentage = try container.decodeIfPresent(String.self, forKey: .memoryPercentage) ?? "-"
        networkIO = try container.decodeIfPresent(String.self, forKey: .networkIO) ?? "-"
        blockIO = try container.decodeIfPresent(String.self, forKey: .blockIO) ?? "-"
    }

    var memorySummary: String {
        let used = memoryUsage.split(separator: "/").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return used?.isEmpty == false ? used! : memoryPercentage
    }

    var networkIOInbound: String {
        networkIO.split(separator: "/").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-"
    }

    var networkIOOutbound: String {
        let parts = networkIO.split(separator: "/")
        guard parts.count > 1 else { return "-" }
        return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DockerDiskUsage: Identifiable, Decodable, Equatable {
    let type: String
    let totalCount: String
    let active: String
    let size: String
    let reclaimable: String

    var id: String { type }

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case totalCount = "TotalCount"
        case active = "Active"
        case size = "Size"
        case reclaimable = "Reclaimable"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "Other"
        totalCount = try container.decodeIfPresent(String.self, forKey: .totalCount) ?? "0"
        active = try container.decodeIfPresent(String.self, forKey: .active) ?? "0"
        size = try container.decodeIfPresent(String.self, forKey: .size) ?? "-"
        reclaimable = try container.decodeIfPresent(String.self, forKey: .reclaimable) ?? "-"
    }

    var sizeBytes: Double {
        DockerSizeParser.bytes(from: size)
    }

    var reclaimableBytes: Double {
        DockerSizeParser.bytes(from: reclaimable)
    }
}

struct ContainerProjectGroup: Identifiable, Equatable {
    let name: String
    let containers: [DockerContainer]

    var id: String { name }

    var runningCount: Int {
        containers.filter(\.isRunning).count
    }

    var statusSummary: String {
        "\(runningCount)/\(containers.count) running"
    }
}

struct KeelEvent: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let subtitle: String?
    let color: Color
}

enum DockerNameFormatter {
    static func projectName(for name: String) -> String {
        let parts = split(name)
        guard parts.count > 1 else { return "standalone" }
        return parts[0]
    }

    static func serviceName(for name: String) -> String {
        let parts = split(name)
        guard parts.count > 1 else { return name }
        return parts.dropFirst().joined(separator: "-")
    }

    private static func split(_ name: String) -> [String] {
        name
            .split { character in
                character == "-" || character == "_" || character == "."
            }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}

enum DockerSizeParser {
    static func bytes(from value: String) -> Double {
        let token = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""

        let number = Double(token.filter { $0.isNumber || $0 == "." }) ?? 0
        let unit = token.filter { $0.isLetter }.lowercased()

        switch unit {
        case "b":
            return number
        case "kb":
            return number * 1_000
        case "mb":
            return number * 1_000_000
        case "gb":
            return number * 1_000_000_000
        case "tb":
            return number * 1_000_000_000_000
        case "kib":
            return number * 1_024
        case "mib":
            return number * 1_048_576
        case "gib":
            return number * 1_073_741_824
        case "tib":
            return number * 1_099_511_627_776
        default:
            return number
        }
    }
}
