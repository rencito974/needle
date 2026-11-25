import SwiftUI

struct Slot: Identifiable {
    let id = UUID()
    let track: Track
}

struct QueuePanel: View {
    @Environment(Player.self) private var player
    @State private var draft: [Slot] = []
    @State private var changed = false
    @State private var upNext: [Track] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Playing Next")
                        .font(.headline)
                    if !source.isEmpty {
                        Text("From \(source)")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                pill("shuffle", on: player.session != nil || player.state?.shuffleState == true) {
                    if player.session != nil {
                        draft = Shuffle.deal(draft.map(\.track), avoiding: []).map { Slot(track: $0) }
                        changed = true
                    } else {
                        player.toggleShuffle()
                    }
                }
                pill(player.state?.repeatState == "track" ? "repeat.1" : "repeat", on: (player.state?.repeatState ?? "off") != "off") {
                    player.cycleRepeat()
                }
            }
            List {
                if !player.queued.isEmpty {
                    Section {
                        ForEach(Array(player.queued.enumerated()), id: \.offset) { _, track in
                            row(track)
                        }
                    } header: {
                        Text("Queued")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                if player.session != nil {
                    ForEach(draft) { slot in
                        row(slot.track)
                            .contextMenu {
                                Button(role: .destructive) {
                                    draft.removeAll { $0.id == slot.id }
                                    changed = true
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                            }
                    }
                    .onMove { from, to in
                        draft.move(fromOffsets: from, toOffset: to)
                        changed = true
                    }
                } else {
                    ForEach(Array(upNext.enumerated()), id: \.offset) { _, track in
                        row(track)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(player.session != nil ? .active : .inactive))
        }
        .padding(.top, 6)
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

    private var source: String {
        if let name = player.session?.name, !name.isEmpty {
            return name
        }
        return player.track?.album?.name ?? ""
    }

    private func row(_ track: Track) -> some View {
        HStack(spacing: 12) {
            TrackArt(track: track, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .lineLimit(1)
                Text(track.artistLine)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Color.white)
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Color.white.opacity(0.15))
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }

    private func pill(_ icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Color.black : Color.white)
                .frame(width: 46, height: 30)
                .background(on ? Color.white.opacity(0.9) : Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .foregroundStyle(Color.primary)
                    }
                }
                Button {
                    player.openSpotify()
                } label: {
                    Label("Open Spotify on This iPhone", systemImage: "arrow.up.forward.app")
                }
            }
            .navigationTitle("Play On")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() async {
        devices = (try? await player.api.devices()) ?? []
    }
}
