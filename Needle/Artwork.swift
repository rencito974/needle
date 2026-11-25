import CoreImage
import SwiftUI
import UIKit

let artCache = NSCache<NSString, UIImage>()

@MainActor
final class Artwork {
    static let shared = Artwork()
    private var tints: [String: Color] = [:]
    private var blurs: [String: UIImage] = [:]
    private let context = CIContext(options: [.workingColorSpace: NSNull()])

    func image(_ url: String) async -> UIImage? {
        if let hit = artCache.object(forKey: url as NSString) {
            return hit
        }
        guard let link = URL(string: url),
              let result = try? await URLSession.shared.data(from: link),
              let image = UIImage(data: result.0) else {
            return nil
        }
        artCache.setObject(image, forKey: url as NSString)
        return image
    }

    func tint(_ url: String) async -> Color? {
        if let hit = tints[url] {
            return hit
        }
        guard let image = await image(url), let color = average(image) else {
            return nil
        }
        tints[url] = color
        return color
    }

    func blurred(_ url: String) async -> UIImage? {
        if let hit = blurs[url] {
            return hit
        }
        guard let image = await image(url), let soft = soften(image) else {
            return nil
        }
        blurs[url] = soft
        return soft
    }

    private func soften(_ image: UIImage) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let side = max(input.extent.width, input.extent.height, 1)
        let small = input.transformed(by: CGAffineTransform(scaleX: 96 / side, y: 96 / side))
        let soft = small.clampedToExtent()
            .applyingGaussianBlur(sigma: 9)
            .cropped(to: small.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.5,
                kCIInputBrightnessKey: -0.06,
            ])
        guard let cg = context.createCGImage(soft, from: small.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func average(_ image: UIImage) -> Color? {
        guard let input = CIImage(image: image) else { return nil }
        let extent = CIVector(cgRect: input.extent)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input, kCIInputExtentKey: extent]),
              let output = filter.outputImage else {
            return nil
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let base = UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(
            hue: Double(hue),
            saturation: Double(min(saturation * 1.15, 0.8)),
            brightness: Double(min(max(brightness * 0.7, 0.22), 0.42))
        )
    }
}

struct Art: View {
    let url: String?
    let size: CGFloat?
    let radius: CGFloat
    @State private var image: UIImage?

    init(url: String?, size: CGFloat? = nil, radius: CGFloat = 4) {
        self.url = url
        self.size = size
        self.radius = radius
        _image = State(initialValue: url.flatMap { artCache.object(forKey: $0 as NSString) })
    }

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: (size ?? 120) * 0.3))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
            .frame(width: size, height: size)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .task(id: url) {
                guard let url else {
                    image = nil
                    return
                }
                if let loaded = await Artwork.shared.image(url) {
                    image = loaded
                }
            }
    }
}

struct Backdrop: View {
    let url: String?
    @State private var image: UIImage?
    @State private var turn = false

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height) * 1.7
            ZStack {
                Theme.ground
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: side, height: side)
                        .rotationEffect(.degrees(turn ? 360 : 0))
                        .offset(x: -geo.size.width * 0.12, y: -geo.size.height * 0.08)
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: side * 0.75, height: side * 0.75)
                        .rotationEffect(.degrees(turn ? -360 : 0))
                        .mask {
                            RadialGradient(colors: [.black, .clear], center: .center, startRadius: 0, endRadius: side * 0.37)
                        }
                        .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.3)
                        .opacity(0.8)
                }
                LinearGradient(
                    colors: [Color.black.opacity(0.12), Color.black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.8), value: image)
        }
        .ignoresSafeArea()
        .task(id: url) {
            guard let url else { return }
            if let soft = await Artwork.shared.blurred(url) {
                image = soft
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                turn = true
            }
        }
    }
}
