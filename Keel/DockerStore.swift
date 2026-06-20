import Combine
import Foundation

enum KeelSection: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case images = "Images"
    case compose = "Compose"
    case volumes = "Volumes"
    case networks = "Networks"
    case logs = "Logs"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .containers:
            return "cube"
        case .images:
            return "square.stack.3d.up"
        case .compose:
            return "chevron.left.forwardslash.chevron.right"
        case .volumes:
            return "externaldrive"
        case .networks:
            return "point.3.connected.trianglepath.dotted"
        case .logs:
            return "doc.text"
        case .settings:
            return "gearshape"
        }
    }
}

@MainActor
final class DockerStore: ObservableObject {
    @Published var selectedSection: KeelSection = .containers
    @Published var searchText = ""
    @Published var containers: [DockerContainer] = []
    @Published var images: [DockerImage] = []
    @Published var volumes: [DockerVolume] = []
    @Published var networks: [DockerNetwork] = []
    @Published var statsByContainerID: [String: DockerContainerStats] = [:]
    @Published var diskUsage: [DockerDiskUsage] = []
    @Published var daemon: DockerDaemon?
    @Published var errorMessage: String?
    @Published var logErrorMessage: String?
    @Published var logOutput = ""
    @Published var isLogPaused = false
    @Published var selectedContainerID: String?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var isLoadingLogs = false
    @Published var actionInFlight: String?
    @Published var pendingConfirmation: DockerConfirmation?

    private var client: DockerClient?

    var filteredContainers: [DockerContainer] {
        let query = normalizedSearch
        guard !query.isEmpty else { return containers }

        return containers.filter { container in
            [
                container.name,
                container.image,
                container.status,
                container.state,
                container.ports,
                container.projectName,
                container.serviceName
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var filteredImages: [DockerImage] {
        let query = normalizedSearch
        guard !query.isEmpty else { return images }

        return images.filter { image in
            [
                image.repository,
                image.tag,
                image.id,
                image.createdSince,
                image.size
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var filteredVolumes: [DockerVolume] {
        let query = normalizedSearch
        guard !query.isEmpty else { return volumes }

        return volumes.filter { volume in
            [
                volume.name,
                volume.driver,
                volume.scope,
                volume.mountpoint,
                volume.labels
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var filteredNetworks: [DockerNetwork] {
        let query = normalizedSearch
        guard !query.isEmpty else { return networks }

        return networks.filter { network in
            [
                network.id,
                network.name,
                network.driver,
                network.scope,
                network.labels
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var containerGroups: [ContainerProjectGroup] {
        Dictionary(grouping: filteredContainers, by: \.projectName)
            .map { key, containers in
                ContainerProjectGroup(
                    name: key,
                    containers: containers.sorted { lhs, rhs in
                        if lhs.isRunning != rhs.isRunning {
                            return lhs.isRunning && !rhs.isRunning
                        }
                        return lhs.serviceName.localizedStandardCompare(rhs.serviceName) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                if lhs.name == "standalone" { return false }
                if rhs.name == "standalone" { return true }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var selectedContainer: DockerContainer? {
        guard let selectedContainerID else { return containers.first }
        return containers.first { $0.id == selectedContainerID } ?? containers.first
    }

    var selectedStats: DockerContainerStats? {
        guard let selectedContainer else { return nil }
        return stats(for: selectedContainer)
    }

    var reclaimableDiskRatio: Double {
        let total = diskUsage.reduce(0) { $0 + $1.sizeBytes }
        guard total > 0 else { return 0.18 }
        let reclaimable = diskUsage.reduce(0) { $0 + $1.reclaimableBytes }
        return max(0.02, min(reclaimable / total, 1))
    }

    var lastUpdatedText: String {
        guard let lastUpdated else { return "Not checked" }
        let elapsed = max(0, Int(Date().timeIntervalSince(lastUpdated)))

        if elapsed < 5 {
            return "just now"
        }
        if elapsed < 60 {
            return "\(elapsed)s ago"
        }

        let minutes = elapsed / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }

        return "\(minutes / 60)h ago"
    }

    var recentEvents: [KeelEvent] {
        var events: [KeelEvent] = []

        for container in containers.prefix(4) {
            events.append(
                KeelEvent(
                    symbol: container.isRunning ? "checkmark.circle" : "pause.circle",
                    title: "Container \(container.serviceName) \(container.isRunning ? "running" : container.state)",
                    subtitle: container.projectName,
                    color: container.statusColor
                )
            )
        }

        if let daemon {
            events.append(
                KeelEvent(
                    symbol: "server.rack",
                    title: "Engine \(daemon.version)",
                    subtitle: daemon.context,
                    color: KeelTheme.accent
                )
            )
        }

        return Array(events.prefix(6))
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let client = try DockerClient()
            self.client = client

            async let daemonTask = client.daemon()
            async let containersTask = client.containers()
            async let imagesTask = client.images()
            async let statsTask = client.stats()
            async let diskTask = client.diskUsage()
            async let volumesTask = client.volumes()
            async let networksTask = client.networks()

            daemon = try await daemonTask
            containers = try await containersTask
            images = try await imagesTask
            volumes = (try? await volumesTask) ?? []
            networks = (try? await networksTask) ?? []
            statsByContainerID = indexStats((try? await statsTask) ?? [])
            diskUsage = (try? await diskTask) ?? []
            lastUpdated = Date()

            keepContainerSelectionValid()
            await loadLogsForSelection()
        } catch {
            daemon = nil
            containers = []
            images = []
            volumes = []
            networks = []
            statsByContainerID = [:]
            diskUsage = []
            selectedContainerID = nil
            logOutput = ""
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func select(_ container: DockerContainer) {
        selectedContainerID = container.id
        Task {
            await loadLogsForSelection()
        }
    }

    func stats(for container: DockerContainer) -> DockerContainerStats? {
        statsByContainerID[container.id]
            ?? statsByContainerID[container.shortID]
            ?? statsByContainerID[container.name]
    }

    func clearLogs() {
        logOutput = ""
        logErrorMessage = nil
    }

    func toggleLogPause() {
        isLogPaused.toggle()
    }

    func reloadSelectedLogs() {
        Task {
            await loadLogsForSelection(force: true)
        }
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

    func startGroup(_ group: ContainerProjectGroup) {
        runAction("start-group-\(group.id)") { client in
            for container in group.containers where !container.isRunning {
                try await client.start(container: container)
            }
        }
    }

    func stopGroup(_ group: ContainerProjectGroup) {
        runAction("stop-group-\(group.id)") { client in
            for container in group.containers where container.isRunning {
                try await client.stop(container: container)
            }
        }
    }

    func restartGroup(_ group: ContainerProjectGroup) {
        runAction("restart-group-\(group.id)") { client in
            for container in group.containers where container.isRunning {
                try await client.restart(container: container)
            }
        }
    }

    func confirmDelete(container: DockerContainer, force: Bool = false) {
        pendingConfirmation = DockerConfirmation(target: .container(container, force: force))
    }

    func confirmDelete(image: DockerImage, force: Bool = false) {
        pendingConfirmation = DockerConfirmation(target: .image(image, force: force))
    }

    func confirmDelete(volume: DockerVolume) {
        pendingConfirmation = DockerConfirmation(target: .volume(volume))
    }

    func confirmDelete(network: DockerNetwork) {
        pendingConfirmation = DockerConfirmation(target: .network(network))
    }

    func confirmPruneSystem() {
        pendingConfirmation = DockerConfirmation(target: .pruneSystem)
    }

    func performPendingConfirmation() {
        guard let pendingConfirmation else { return }
        self.pendingConfirmation = nil

        switch pendingConfirmation.target {
        case let .container(container, force):
            runAction("remove-\(container.id)") { client in
                try await client.remove(container: container, force: force)
            }
        case let .image(image, force):
            runAction("remove-image-\(image.id)") { client in
                try await client.remove(image: image, force: force)
            }
        case let .volume(volume):
            runAction("remove-volume-\(volume.name)") { client in
                try await client.remove(volume: volume)
            }
        case let .network(network):
            runAction("remove-network-\(network.name)") { client in
                try await client.remove(network: network)
            }
        case .pruneSystem:
            runAction("system-prune") { client in
                try await client.pruneSystem()
            }
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func keepContainerSelectionValid() {
        if let selectedContainerID, containers.contains(where: { $0.id == selectedContainerID }) {
            return
        }

        selectedContainerID = containers.first(where: \.isRunning)?.id ?? containers.first?.id
    }

    private func loadLogsForSelection(force: Bool = false) async {
        guard force || !isLogPaused else {
            return
        }

        guard let client, let selectedContainer else {
            logOutput = ""
            return
        }

        isLoadingLogs = true
        logErrorMessage = nil

        do {
            let output = try await client.logs(container: selectedContainer)
            logOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logErrorMessage = error.localizedDescription
            logOutput = ""
        }

        isLoadingLogs = false
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

    private func indexStats(_ stats: [DockerContainerStats]) -> [String: DockerContainerStats] {
        var indexed: [String: DockerContainerStats] = [:]

        for stat in stats {
            if !stat.containerID.isEmpty {
                indexed[stat.containerID] = stat
            }
            if !stat.name.isEmpty {
                indexed[stat.name] = stat
            }
        }

        return indexed
    }
}
