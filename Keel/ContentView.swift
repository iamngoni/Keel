//
//  ContentView.swift
//  Keel
//
//  Created by Ngonidzashe  Mangudya on 2026/06/20.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = DockerStore()
    @State private var logDrawerHeight: CGFloat = 270
    @State private var dragStartLogHeight: CGFloat?

    var body: some View {
        HStack(spacing: 0) {
            KeelIconRail(selection: $store.selectedSection)

            Divider()
                .overlay(KeelTheme.border)

            VStack(spacing: 0) {
                KeelCommandBar(store: store)

                Divider()
                    .overlay(KeelTheme.border)

                HStack(spacing: 0) {
                    workspace

                    Divider()
                        .overlay(KeelTheme.border)

                    EngineStatusRail(store: store)
                        .frame(width: 276)
                }
            }
        }
        .frame(minWidth: 1240, minHeight: 760)
        .background(KeelTheme.windowBackground)
        .background(KeelWindowChrome())
        .preferredColorScheme(.dark)
        .confirmationDialog(
            store.pendingConfirmation?.title ?? "",
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            if store.pendingConfirmation != nil {
                Button(store.pendingConfirmation?.confirmTitle ?? "Delete", role: .destructive) {
                    store.performPendingConfirmation()
                }
            }

            Button("Cancel", role: .cancel) {
                store.pendingConfirmation = nil
            }
        } message: {
            if let confirmation = store.pendingConfirmation {
                Text(confirmation.message)
            }
        }
        .task {
            await store.refresh()
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { store.pendingConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    store.pendingConfirmation = nil
                }
            }
        )
    }

    @ViewBuilder
    private var workspace: some View {
        VStack(spacing: 0) {
            if let errorMessage = store.errorMessage {
                DockerUnavailableView(message: errorMessage) {
                    Task { await store.refresh() }
                }
            } else {
                switch store.selectedSection {
                case .containers:
                    containersWorkspace
                case .images:
                    ImagesWorkspace(store: store)
                case .compose:
                    ComposeWorkspace(store: store)
                case .volumes:
                    VolumesWorkspace(store: store)
                case .networks:
                    NetworksWorkspace(store: store)
                case .logs:
                    LogsWorkspace(store: store)
                case .settings:
                    SettingsWorkspace(store: store)
                }
            }
        }
    }

    private var containersWorkspace: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ContainerCommandCenter(store: store)
                    .frame(maxHeight: .infinity)

                LogResizeHandle()
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if dragStartLogHeight == nil {
                                    dragStartLogHeight = logDrawerHeight
                                }

                                let startHeight = dragStartLogHeight ?? logDrawerHeight
                                let maxHeight = max(220, proxy.size.height - 220)
                                logDrawerHeight = min(max(startHeight - value.translation.height, 160), maxHeight)
                            }
                            .onEnded { _ in
                                dragStartLogHeight = nil
                            }
                    )

                LogDrawer(
                    store: store,
                    openFullLogs: { store.selectedSection = .logs }
                )
                .frame(height: logDrawerHeight)
            }
        }
    }
}

#Preview {
    ContentView()
}
