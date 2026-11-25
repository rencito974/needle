import SwiftUI

struct Slot: Identifiable {
    let id = UUID()
    let track: Track
}

struct QueueSheet: View {
    @Environment(Player.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [Slot] = []
    @State private var changed = false
    @State private var upNext: [Track] = []

    var body: some View {
        NavigationStack {
            List {
                if let track = player.track {
                    Section("Now Playing") {
                        TrackRow(track: track, menu: false)
                    }
                }
                if !player.queued.isEmpty {
                    Section("Queued") {
                        ForEach(Array(player.queued.enumerated()), id: \.offset) { _, track in
                            TrackRow(track: track, menu: false)
                        }
                    }
                }
                if player.session != nil {
                    Section("Next") {
                        ForEach(draft) { slot in
                            TrackRow(track: slot.track, menu: false)
                        }
                        .onMove { from, to in
                            draft.move(fromOffsets: from, toOffset: to)
                            changed = true
                        }
                        .onDelete { offsets in
                            draft.remove(atOffsets: offsets)
                            changed = true
                        }
                    }
                } else if !upNext.isEmpty {
                    Section("Next") {
                        ForEach(Array(upNext.enumerated()), id: \.offset) { _, track in
                            TrackRow(track: track, menu: false)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if player.session != nil {
                        EditButton()
                        Button {
                            let order = Shuffle.deal(draft.map(\.track), avoiding: [])
                            draft = order.map { Slot(track: $0) }
                            changed = true
                        } label: {
                            Image(systemName: "shuffle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                draft = (player.session?.upcoming ?? []).map { Slot(track: $0) }
                if player.session == nil {
                    upNext = (try? await player.api.queue()) ?? []
                }
            }
            .onDisappear {
                if changed {
                    changed = false
                    player.replaceUpcoming(draft.map(\.track))
                }
            }
        }
    }
}

struct DeviceSheet: View {
    @Environment(Player.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var devices: [Device] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(devices, id: \.self) { device in
                    Button {
                        player.transfer(to: device)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: deviceIcon(device.type))
                                .frame(width: 28)
                            Text(device.name)
                                .lineLimit(1)
                            Spacer()
                            if device.isActive {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.amber)
                            }
                        }
                        .foregroundStyle(Color.primary)
                    }
                }
                Button {
                    player.openSpotify()
                } label: {
                    Label("Open Spotify on this iPhone", systemImage: "arrow.up.forward.app")
                }
            }
            .listStyle(.plain)
            .navigationTitle("Play On")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() async {
        devices = (try? await player.api.devices()) ?? []
    }
}
