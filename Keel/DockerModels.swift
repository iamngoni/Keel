import Foundation

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
