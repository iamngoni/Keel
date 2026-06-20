import Combine
import Foundation

enum KeelSection: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .containers:
            "shippingbox"
        case .images:
            "square.stack.3d.up"
        }
    }
}

@MainActor
final class DockerStore: ObservableObject {
    @Published var selectedSection: KeelSection = .containers
    @Published var containers: [DockerContainer] = []
    @Published var images: [DockerImage] = []
    @Published var daemon: DockerDaemon?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var actionInFlight: String?

    private var client: DockerClient?

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let client = try DockerClient()
            self.client = client

            async let daemon = client.daemon()
            async let containers = client.containers()
            async let images = client.images()

            self.daemon = try await daemon
            self.containers = try await containers
            self.images = try await images
        } catch {
            daemon = nil
            containers = []
            images = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func start(_ container: DockerContainer) {
        runAction("start-\(container.id)") { client in
            try await client.start(container: container)
        }
    }

    func stop(_ container: DockerContainer) {
        runAction("stop-\(container.id)") { client in
            try await client.stop(container: container)
        }
    }

    func restart(_ container: DockerContainer) {
        runAction("restart-\(container.id)") { client in
            try await client.restart(container: container)
        }
    }

    private func runAction(_ id: String, operation: @escaping (DockerClient) async throws -> Void) {
        Task {
            guard let client else {
                await refresh()
                return
            }

            actionInFlight = id
            errorMessage = nil

            do {
                try await operation(client)
                await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }

            actionInFlight = nil
        }
    }
}
