import AVFoundation
import AVKit
import MediaPlayer
import SwiftUI

@Observable
final class Volume {
    var level: Float = 0.5
    @ObservationIgnored private var watch: NSKeyValueObservation?
    @ObservationIgnored weak var host: MPVolumeView?

    func begin() {
        guard watch == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        level = session.outputVolume
        watch = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            DispatchQueue.main.async {
                self?.level = value
            }
        }
    }

    func set(_ value: Float) {
        level = value
        let slider = host?.subviews.compactMap { $0 as? UISlider }.first
        slider?.value = value
    }
}

struct VolumeHost: UIViewRepresentable {
    let volume: Volume

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        view.alpha = 0.01
        volume.host = view
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        volume.host = view
    }
}

struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor.white.withAlphaComponent(0.65)
        picker.activeTintColor = UIColor.white
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {}
}

struct VolumeBar: View {
    @State private var volume = Volume()
    @State private var drag: Float?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption)
            GeometryReader { geo in
                let shown = CGFloat(drag ?? volume.level)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white.opacity(drag == nil ? 0.8 : 1))
                        .frame(width: geo.size.width * min(max(shown, 0), 1))
                }
                .frame(height: drag == nil ? 6 : 11)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let width = max(geo.size.width, 1)
                            let value = Float(min(max(gesture.location.x / width, 0), 1))
                            drag = value
                            volume.set(value)
                        }
                        .onEnded { _ in
                            drag = nil
                        }
                )
            }
            .frame(height: 24)
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
        }
        .foregroundStyle(Color.white.opacity(0.55))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: drag == nil)
        .background {
            VolumeHost(volume: volume)
                .frame(width: 4, height: 4)
                .allowsHitTesting(false)
        }
        .onAppear { volume.begin() }
    }
}
