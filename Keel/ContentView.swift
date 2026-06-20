//
//  ContentView.swift
//  Keel
//
//  Created by Ngonidzashe  Mangudya on 2026/06/20.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = DockerStore()

    var body: some View {
        NavigationSplitView {
            List(KeelSection.allCases, selection: $store.selectedSection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("Keel")
        } detail: {
            VStack(spacing: 0) {
                header
                Divider()

                if let errorMessage = store.errorMessage {
                    unavailableView(errorMessage)
                } else {
                    switch store.selectedSection {
                    case .containers:
                        containersView
                    case .images:
                        imagesView
                    }
                }
            }
            .frame(minWidth: 780, minHeight: 520)
        }
        .task {
            await store.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.02, green: 0.44, blue: 0.82), Color(red: 0.01, green: 0.66, blue: 0.74)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(store.selectedSection.rawValue)
                    .font(.title2.weight(.semibold))

                HStack(spacing: 8) {
                    Circle()
                        .fill(store.daemon == nil ? Color.secondary : Color.green)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await store.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isLoading)
        }
        .padding(20)
    }

    private var statusText: String {
        guard let daemon = store.daemon else {
            return store.isLoading ? "Checking Docker Engine" : "Docker Engine unavailable"
        }

        return "\(daemon.context) · Docker \(daemon.version)"
    }

    private var containersView: some View {
        List {
            ForEach(store.containers) { container in
                HStack(spacing: 14) {
                    statusPill(container.isRunning ? "Running" : container.state.capitalized, running: container.isRunning)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(container.name)
                            .font(.headline)
                        Text(container.image)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(container.status)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)

                    actionButtons(for: container)
                }
                .padding(.vertical, 7)
            }
        }
        .overlay {
            if store.isLoading && store.containers.isEmpty {
                ProgressView()
            } else if !store.isLoading && store.containers.isEmpty {
                emptyView("No containers", symbol: "shippingbox")
            }
        }
    }

    private var imagesView: some View {
        List {
            ForEach(store.images) { image in
                HStack(spacing: 14) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(.teal)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(image.displayName)
                            .font(.headline)
                        Text(image.id)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(image.createdSince)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text(image.size)
                        .font(.callout.monospacedDigit())
                        .frame(width: 88, alignment: .trailing)
                }
                .padding(.vertical, 7)
            }
        }
        .overlay {
            if store.isLoading && store.images.isEmpty {
                ProgressView()
            } else if !store.isLoading && store.images.isEmpty {
                emptyView("No images", symbol: "square.stack.3d.up")
            }
        }
    }

    private func actionButtons(for container: DockerContainer) -> some View {
        HStack(spacing: 6) {
            Button {
                container.isRunning ? store.stop(container) : store.start(container)
            } label: {
                Image(systemName: container.isRunning ? "stop.fill" : "play.fill")
            }
            .help(container.isRunning ? "Stop" : "Start")

            Button {
                store.restart(container)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Restart")
            .disabled(!container.isRunning)
        }
        .buttonStyle(.borderless)
        .disabled(store.actionInFlight?.contains(container.id) == true)
    }

    private func statusPill(_ text: String, running: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(running ? Color.green : Color.secondary)
            .frame(width: 82, alignment: .leading)
    }

    private func unavailableView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Docker Engine unavailable", systemImage: "xmark.octagon")
        } description: {
            Text(message)
        } actions: {
            Button("Refresh") {
                Task { await store.refresh() }
            }
        }
    }

    private func emptyView(_ title: String, symbol: String) -> some View {
        ContentUnavailableView(title, systemImage: symbol)
    }
}

#Preview {
    ContentView()
}
