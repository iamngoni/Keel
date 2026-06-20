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
        .preferredColorScheme(.dark)
        .task {
            await store.refresh()
        }
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
                    ContainerCommandCenter(store: store)
                    LogDrawer(store: store)
                        .frame(height: 270)
                case .images:
                    ImagesWorkspace(store: store)
                case .compose, .volumes, .networks, .logs, .settings:
                    ComingSoonWorkspace(section: store.selectedSection)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
