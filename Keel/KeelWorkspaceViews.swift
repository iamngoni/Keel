import AppKit
import SwiftUI

struct KeelIconRail: View {
    @Binding var selection: KeelSection

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)
                .padding(.top, 28)

            Spacer(minLength: 8)

            VStack(spacing: 14) {
                ForEach(KeelSection.allCases) { section in
                    railButton(section)
                }
            }

            Spacer()
        }
        .frame(width: 78)
        .background(KeelTheme.railBackground)
    }

    private func railButton(_ section: KeelSection) -> some View {
        Button {
            selection = section
        } label: {
            ZStack(alignment: .leading) {
                if selection == section {
                    Capsule()
                        .fill(KeelTheme.accent)
                        .frame(width: 4, height: 28)
                        .offset(x: -14)
                }

                Image(systemName: section.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selection == section ? .white : KeelTheme.textMuted)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection == section ? Color.white.opacity(0.11) : Color.clear)
                    )
            }
        }
        .buttonStyle(.plain)
        .help(section.rawValue)
    }
}

struct KeelCommandBar: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(KeelTheme.textMuted)

                TextField("Search containers, images, compose projects", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)

                Text("Cmd K")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(KeelTheme.textSubtle)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(KeelTheme.border, lineWidth: 1)
                    )
            )

            Spacer(minLength: 16)

            ContextChip(daemon: store.daemon)
            EngineChip(version: store.daemon?.version)

            KeelIconButton(systemName: "arrow.clockwise", help: "Refresh", isDisabled: store.isLoading) {
                Task { await store.refresh() }
            }

            KeelIconButton(systemName: "terminal", help: "Open Terminal") {
                KeelSystemActions.openTerminal()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.07))
    }
}

struct ContextChip: View {
    let daemon: DockerDaemon?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(daemon == nil ? KeelTheme.warning : KeelTheme.healthy)
                .frame(width: 8, height: 8)
            Text(daemon?.context ?? "offline")
                .font(.callout.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(KeelTheme.border, lineWidth: 1)
                )
        )
    }
}

struct EngineChip: View {
    let version: String?

    var body: some View {
        HStack(spacing: 7) {
            Text("Engine")
                .font(.caption.weight(.medium))
                .foregroundStyle(KeelTheme.textMuted)
            Text(version ?? "-")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(KeelTheme.border, lineWidth: 1)
                )
        )
    }
}

struct ContainerCommandCenter: View {
    @ObservedObject var store: DockerStore

    private var groups: [ContainerProjectGroup] {
        store.containerGroups
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if store.isLoading && store.containers.isEmpty {
                    ProgressView()
                        .padding(.top, 80)
                } else if groups.isEmpty {
                    EmptyWorkspaceState(title: "No containers", subtitle: "No Docker containers match the current search.", symbol: "shippingbox")
                        .padding(.top, 80)
                } else {
                    ForEach(groups) { group in
                        ContainerGroupSection(group: group, store: store)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.black.opacity(0.05))
    }
}

struct ContainerGroupSection: View {
    let group: ContainerProjectGroup
    @ObservedObject var store: DockerStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KeelTheme.textMuted)
                Image(systemName: "shippingbox")
                    .foregroundStyle(.white.opacity(0.78))
                Text(group.name)
                    .font(.headline)
                Text(group.statusSummary)
                    .font(.caption)
                    .foregroundStyle(KeelTheme.textSubtle)
                    .lineLimit(1)
                Text("\(group.containers.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                Spacer()

                Menu {
                    Button("Start stopped containers") {
                        store.startGroup(group)
                    }
                    Button("Stop running containers") {
                        store.stopGroup(group)
                    }
                    Button("Restart running containers") {
                        store.restartGroup(group)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KeelTheme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                }
                .menuStyle(.borderlessButton)
                .help("Project actions")
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color.white.opacity(0.035))

            ForEach(group.containers) { container in
                ContainerLaneRow(
                    container: container,
                    stats: store.stats(for: container),
                    isSelected: store.selectedContainerID == container.id,
                    isBusy: store.actionInFlight?.contains(container.id) == true,
                    select: { store.select(container) },
                    startStop: { container.isRunning ? store.stop(container) : store.start(container) },
                    restart: { store.restart(container) },
                    delete: { store.confirmDelete(container: container) },
                    forceDelete: { store.confirmDelete(container: container, force: true) }
                )

                if container.id != group.containers.last?.id {
                    Divider()
                        .overlay(KeelTheme.subtleBorder)
                        .padding(.leading, 14)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(KeelTheme.border, lineWidth: 1)
        )
        .padding(.bottom, 12)
    }
}

struct ContainerLaneRow: View {
    let container: DockerContainer
    let stats: DockerContainerStats?
    let isSelected: Bool
    let isBusy: Bool
    let select: () -> Void
    let startStop: () -> Void
    let restart: () -> Void
    let delete: () -> Void
    let forceDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(container.statusColor)
                    .frame(width: 9, height: 9)
                    .shadow(color: container.statusColor.opacity(0.4), radius: 4)

                Image(systemName: "cube.transparent")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(KeelTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(container.serviceName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(container.shortID)
                        .font(.caption.monospaced())
                        .foregroundStyle(KeelTheme.textSubtle)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 150, maxWidth: 190, alignment: .leading)

            Text(container.image)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatusBadge(text: container.badgeText, color: container.statusColor)
                .frame(width: 86, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.displayPorts)
                    .font(.callout.monospacedDigit())
                    .lineLimit(1)
                Text(container.portProtocolLabel)
                    .font(.caption)
                    .foregroundStyle(KeelTheme.textSubtle)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)

            MetricCell(label: "CPU", value: stats?.cpuPercentage ?? "-", seed: container.id)
                .frame(width: 92, alignment: .leading)

            MetricCell(label: "MEM", value: stats?.memorySummary ?? "-", seed: container.name, color: KeelTheme.accent.opacity(0.78))
                .frame(width: 116, alignment: .leading)

            HStack(spacing: 8) {
                KeelIconButton(
                    systemName: container.isRunning ? "stop.fill" : "play.fill",
                    help: container.isRunning ? "Stop" : "Start",
                    isDisabled: isBusy,
                    action: startStop
                )

                KeelIconButton(
                    systemName: "arrow.clockwise",
                    help: "Restart",
                    isDisabled: isBusy || !container.isRunning,
                    action: restart
                )

                Menu {
                    Button(container.isRunning ? "Stop" : "Start", action: startStop)
                    Button("Restart", action: restart)
                        .disabled(!container.isRunning)
                    Divider()
                    Button("Delete", role: .destructive, action: delete)
                        .disabled(container.isRunning)
                    Button("Force Delete", role: .destructive, action: forceDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KeelTheme.textMuted)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(KeelTheme.subtleBorder, lineWidth: 1)
                        )
                }
                .menuStyle(.borderlessButton)
                .help("More actions")
            }
            .frame(width: 112, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .background(isSelected ? KeelTheme.selectedBackground : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .contextMenu {
            Button(container.isRunning ? "Stop" : "Start", action: startStop)
            Button("Restart", action: restart)
                .disabled(!container.isRunning)
            Divider()
            Button("Delete", role: .destructive, action: delete)
                .disabled(container.isRunning)
            Button("Force Delete", role: .destructive, action: forceDelete)
        }
    }
}

struct MetricCell: View {
    let label: String
    let value: String
    let seed: String
    var color = KeelTheme.accent

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(KeelTheme.textSubtle)
            }

            MetricSparkline(seed: seed, color: color)
        }
    }
}

struct LogResizeHandle: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(KeelTheme.border)
                .frame(height: 1)

            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 34, height: 4)
        }
        .frame(height: 12)
        .background(KeelTheme.panelBackground.opacity(0.84))
        .contentShape(Rectangle())
        .help("Drag to resize logs")
    }
}

struct LogDrawer: View {
    @ObservedObject var store: DockerStore
    let openFullLogs: () -> Void
    @State private var selectedLevel = "All"
    @State private var filterText = ""
    private let levels = ["All", "Info", "Warn", "Error"]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(KeelTheme.border)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(store.selectedContainer?.serviceName ?? "Logs")
                        .font(.headline)
                        .lineLimit(1)

                    if let selected = store.selectedContainer {
                        Text(selected.shortID)
                            .font(.caption.monospaced())
                            .foregroundStyle(KeelTheme.textSubtle)
                        Circle()
                            .fill(selected.statusColor)
                            .frame(width: 7, height: 7)
                        Text(selected.badgeText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(KeelTheme.textMuted)
                    }

                    Spacer()

                    Picker("", selection: $selectedLevel) {
                        ForEach(levels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 208)

                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(KeelTheme.textSubtle)
                        TextField("Filter logs...", text: $filterText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: 210, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(KeelTheme.border, lineWidth: 1)
                            )
                    )

                    StatusBadge(
                        text: store.isLogPaused ? "Paused" : (store.isLoadingLogs ? "Loading" : "Live"),
                        color: store.isLogPaused ? KeelTheme.textMuted : (store.isLoadingLogs ? KeelTheme.warning : KeelTheme.healthy)
                    )

                    KeelIconButton(systemName: store.isLogPaused ? "play.fill" : "pause.fill", help: store.isLogPaused ? "Resume logs" : "Pause logs") {
                        store.toggleLogPause()
                    }
                    KeelIconButton(systemName: "trash", help: "Clear visible logs") {
                        store.clearLogs()
                    }
                    KeelIconButton(systemName: "arrow.up.left.and.arrow.down.right", help: "Open full logs") {
                        openFullLogs()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ScrollView {
                    Text(logText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(KeelTheme.subtleBorder, lineWidth: 1)
                        )
                )
                .padding([.horizontal, .bottom], 16)
            }
        }
        .background(KeelTheme.panelBackground.opacity(0.84))
    }

    private var logText: String {
        if let error = store.logErrorMessage {
            return error
        }

        let base = store.logOutput.isEmpty ? "Select a running container to view recent logs." : store.logOutput
        let lines = base.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        return lines
            .filter { line in
                let levelMatch: Bool
                switch selectedLevel {
                case "Info":
                    levelMatch = line.localizedCaseInsensitiveContains("info")
                case "Warn":
                    levelMatch = line.localizedCaseInsensitiveContains("warn")
                case "Error":
                    levelMatch = line.localizedCaseInsensitiveContains("error")
                default:
                    levelMatch = true
                }

                let searchMatch = filterText.isEmpty || line.localizedCaseInsensitiveContains(filterText)
                return levelMatch && searchMatch
            }
            .joined(separator: "\n")
    }
}

struct EngineStatusRail: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                engineHeader

                Divider()
                    .overlay(KeelTheme.border)
                    .padding(.vertical, 18)

                resources

                Divider()
                    .overlay(KeelTheme.border)
                    .padding(.vertical, 18)

                network

                Divider()
                    .overlay(KeelTheme.border)
                    .padding(.vertical, 18)

                recentEvents

                VStack(spacing: 8) {
                    RailActionButton(title: "Refresh stats", symbol: "chart.xyaxis.line") {
                        Task { await store.refresh() }
                    }

                    RailActionButton(title: "Prune unused", symbol: "trash") {
                        store.confirmPruneSystem()
                    }
                }
                .padding(.top, 18)
            }
            .padding(18)
        }
        .background(Color.black.opacity(0.09))
    }

    private var engineHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Engine")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.daemon == nil ? KeelTheme.warning : KeelTheme.healthy)
                        .frame(width: 7, height: 7)
                    Text(store.daemon == nil ? "Offline" : "Healthy")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(store.daemon == nil ? KeelTheme.warning : KeelTheme.healthy)
                }
            }

            InfoLine(title: store.daemon?.context ?? "No context", subtitle: "docker context")
            InfoLine(title: store.daemon?.version ?? "-", subtitle: "Engine version")
            InfoLine(title: store.lastUpdatedText, subtitle: "Last checked")
        }
    }

    private var resources: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Resources")
                .font(.headline)

            HStack(spacing: 16) {
                DiskRing(progress: store.reclaimableDiskRatio)
                    .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.diskUsage.prefix(4)) { usage in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color(for: usage.type))
                                .frame(width: 7, height: 7)
                            Text(usage.type)
                                .font(.caption)
                                .foregroundStyle(KeelTheme.textMuted)
                            Spacer()
                            Text(usage.size)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    if store.diskUsage.isEmpty {
                        Text("No disk data")
                            .font(.caption)
                            .foregroundStyle(KeelTheme.textSubtle)
                    }
                }
            }
        }
    }

    private var network: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Network")
                    .font(.headline)
                Spacer()
                Text("Live")
                    .font(.caption)
                    .foregroundStyle(KeelTheme.textSubtle)
            }

            InfoLine(title: store.selectedStats?.networkIOInbound ?? "-", subtitle: "Inbound")
            MetricSparkline(seed: "network-in-\(store.selectedContainerID ?? "none")")
                .frame(maxWidth: .infinity, alignment: .trailing)

            InfoLine(title: store.selectedStats?.networkIOOutbound ?? "-", subtitle: "Outbound")
            MetricSparkline(seed: "network-out-\(store.selectedContainerID ?? "none")", color: KeelTheme.purple)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var recentEvents: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent events")
                    .font(.headline)
                Spacer()
                Button("View logs") {
                    store.selectedSection = .logs
                }
                .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(KeelTheme.textMuted)
            }

            ForEach(store.recentEvents) { event in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: event.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(event.color)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        if let subtitle = event.subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(KeelTheme.textSubtle)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    private func color(for type: String) -> Color {
        switch type.lowercased() {
        case let value where value.contains("image"):
            return KeelTheme.accent
        case let value where value.contains("container"):
            return KeelTheme.blue
        case let value where value.contains("volume"):
            return KeelTheme.purple
        default:
            return KeelTheme.warning
        }
    }
}

struct RailActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: symbol)
            }
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(KeelTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct InfoLine: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(KeelTheme.textSubtle)
                .lineLimit(1)
        }
    }
}

struct DiskRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 9)
            Circle()
                .trim(from: 0, to: max(0.05, min(progress, 1)))
                .stroke(
                    AngularGradient(colors: [KeelTheme.accent, KeelTheme.blue, KeelTheme.accent], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(Int(progress * 100))%")
                    .font(.headline.monospacedDigit())
                Text("freeable")
                    .font(.caption2)
                    .foregroundStyle(KeelTheme.textSubtle)
            }
        }
    }
}

struct ImagesWorkspace: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.filteredImages.isEmpty {
                    EmptyWorkspaceState(title: "No images", subtitle: "No Docker images match the current search.", symbol: "square.stack.3d.up")
                        .padding(.top, 80)
                } else {
                    ForEach(store.filteredImages) { image in
                        HStack(spacing: 14) {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundStyle(KeelTheme.accent)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(image.displayName)
                                    .font(.callout.weight(.semibold))
                                    .lineLimit(1)
                                Text(image.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(KeelTheme.textSubtle)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(image.createdSince)
                                .font(.caption)
                                .foregroundStyle(KeelTheme.textMuted)
                            Text(image.size)
                                .font(.caption.monospacedDigit())
                                .frame(width: 84, alignment: .trailing)

                            ResourceMenu {
                                Button("Delete Image", role: .destructive) {
                                    store.confirmDelete(image: image)
                                }
                                Button("Force Delete Image", role: .destructive) {
                                    store.confirmDelete(image: image, force: true)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(KeelTheme.panelBackground.opacity(0.76))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(KeelTheme.border, lineWidth: 1)
                                )
                        )
                        .contextMenu {
                            Button("Delete Image", role: .destructive) {
                                store.confirmDelete(image: image)
                            }
                            Button("Force Delete Image", role: .destructive) {
                                store.confirmDelete(image: image, force: true)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct ComposeWorkspace: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if store.containerGroups.isEmpty {
                    EmptyWorkspaceState(title: "No compose projects", subtitle: "No grouped Docker containers were found.", symbol: "chevron.left.forwardslash.chevron.right")
                        .padding(.top, 80)
                } else {
                    ForEach(store.containerGroups) { group in
                        KeelPanel {
                            HStack(spacing: 14) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .foregroundStyle(KeelTheme.accent)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.name)
                                        .font(.headline)
                                    Text(group.statusSummary)
                                        .font(.caption)
                                        .foregroundStyle(KeelTheme.textMuted)
                                }

                                Spacer()

                                Text("\(group.containers.count) containers")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(KeelTheme.textMuted)

                                KeelIconButton(systemName: "play.fill", help: "Start stopped containers") {
                                    store.startGroup(group)
                                }
                                KeelIconButton(systemName: "stop.fill", help: "Stop running containers") {
                                    store.stopGroup(group)
                                }
                                KeelIconButton(systemName: "arrow.clockwise", help: "Restart running containers") {
                                    store.restartGroup(group)
                                }
                            }
                            .padding(14)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct VolumesWorkspace: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.filteredVolumes.isEmpty {
                    EmptyWorkspaceState(title: "No volumes", subtitle: "No Docker volumes match the current search.", symbol: "externaldrive")
                        .padding(.top, 80)
                } else {
                    ForEach(store.filteredVolumes) { volume in
                        ResourceRow(
                            symbol: "externaldrive",
                            title: volume.displayName,
                            subtitle: volume.name,
                            metadata: [
                                ("Driver", volume.driver),
                                ("Scope", volume.scope),
                                ("Size", volume.size)
                            ]
                        ) {
                            Button("Delete Volume", role: .destructive) {
                                store.confirmDelete(volume: volume)
                            }
                        }
                        .contextMenu {
                            Button("Delete Volume", role: .destructive) {
                                store.confirmDelete(volume: volume)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct NetworksWorkspace: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.filteredNetworks.isEmpty {
                    EmptyWorkspaceState(title: "No networks", subtitle: "No Docker networks match the current search.", symbol: "point.3.connected.trianglepath.dotted")
                        .padding(.top, 80)
                } else {
                    ForEach(store.filteredNetworks) { network in
                        ResourceRow(
                            symbol: "point.3.connected.trianglepath.dotted",
                            title: network.name,
                            subtitle: network.shortID,
                            metadata: [
                                ("Driver", network.driver),
                                ("Scope", network.scope),
                                ("IPv4", network.ipv4),
                                ("Internal", network.internalNetwork)
                            ]
                        ) {
                            Button("Delete Network", role: .destructive) {
                                store.confirmDelete(network: network)
                            }
                            .disabled(network.isBuiltin)
                        }
                        .contextMenu {
                            Button("Delete Network", role: .destructive) {
                                store.confirmDelete(network: network)
                            }
                            .disabled(network.isBuiltin)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct LogsWorkspace: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(store.selectedContainer?.name ?? "Logs")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                KeelIconButton(systemName: store.isLogPaused ? "play.fill" : "pause.fill", help: store.isLogPaused ? "Resume logs" : "Pause logs") {
                    store.toggleLogPause()
                }
                KeelIconButton(systemName: "arrow.clockwise", help: "Reload logs") {
                    store.reloadSelectedLogs()
                }
                KeelIconButton(systemName: "trash", help: "Clear logs") {
                    store.clearLogs()
                }
            }
            .padding(16)

            Divider()
                .overlay(KeelTheme.border)

            ScrollView {
                Text(store.logErrorMessage ?? (store.logOutput.isEmpty ? "Select a container to view logs." : store.logOutput))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(16)
            }
        }
    }
}

struct SettingsWorkspace: View {
    @ObservedObject var store: DockerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsRow(title: "Docker context", value: store.daemon?.context ?? "Unavailable", symbol: "server.rack")
                SettingsRow(title: "Engine version", value: store.daemon?.version ?? "Unavailable", symbol: "cpu")
                SettingsRow(title: "Containers", value: "\(store.containers.count)", symbol: "cube")
                SettingsRow(title: "Images", value: "\(store.images.count)", symbol: "square.stack.3d.up")
                SettingsRow(title: "Volumes", value: "\(store.volumes.count)", symbol: "externaldrive")
                SettingsRow(title: "Networks", value: "\(store.networks.count)", symbol: "point.3.connected.trianglepath.dotted")

                HStack(spacing: 10) {
                    Button("Refresh Docker Data") {
                        Task { await store.refresh() }
                    }

                    Button("Open Terminal") {
                        KeelSystemActions.openTerminal()
                    }

                    Button("Prune Unused Docker Data", role: .destructive) {
                        store.confirmPruneSystem()
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(18)
        }
    }
}

struct ResourceRow<MenuContent: View>: View {
    let symbol: String
    let title: String
    let subtitle: String
    let metadata: [(String, String)]
    let menuContent: MenuContent

    init(
        symbol: String,
        title: String,
        subtitle: String,
        metadata: [(String, String)],
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.metadata = metadata
        self.menuContent = menuContent()
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(KeelTheme.accent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(KeelTheme.textSubtle)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            ForEach(metadata, id: \.0) { item in
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.1)
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                    Text(item.0)
                        .font(.caption2)
                        .foregroundStyle(KeelTheme.textSubtle)
                        .lineLimit(1)
                }
                .frame(width: 96, alignment: .trailing)
            }

            ResourceMenu {
                menuContent
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(KeelTheme.panelBackground.opacity(0.76))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(KeelTheme.border, lineWidth: 1)
                )
        )
    }
}

struct ResourceMenu<MenuContent: View>: View {
    let content: MenuContent

    init(@ViewBuilder content: () -> MenuContent) {
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KeelTheme.textMuted)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(KeelTheme.subtleBorder, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        KeelPanel {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .foregroundStyle(KeelTheme.accent)
                    .frame(width: 28)
                Text(title)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(KeelTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(14)
        }
    }
}

struct DockerUnavailableView: View {
    let message: String
    let refresh: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(KeelTheme.warning)
            Text("Docker Engine unavailable")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(KeelTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            HStack(spacing: 10) {
                Button("Refresh", action: refresh)
                Button("Get OrbStack") {
                    KeelSystemActions.openURL("https://orbstack.dev")
                }
                Button("Get Docker Desktop") {
                    KeelSystemActions.openURL("https://www.docker.com/products/docker-desktop/")
                }
                Button("Colima setup") {
                    KeelSystemActions.openURL("https://github.com/abiosoft/colima")
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyWorkspaceState: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(KeelTheme.accent)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(KeelTheme.textMuted)
        }
    }
}
