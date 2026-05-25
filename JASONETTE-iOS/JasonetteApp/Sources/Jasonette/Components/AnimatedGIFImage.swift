import Foundation

#if os(iOS)
import ImageIO
import SwiftUI
import UIKit

/// UIKit-backed renderer for animated GIF URLs.
///
/// SwiftUI's `AsyncImage` decodes image data into a SwiftUI `Image`, which does
/// not preserve GIF animation. This wrapper downloads the bytes directly and
/// feeds an animated `UIImage` into `UIImageView` while keeping normal static
/// image rendering on the existing `AsyncImage` path.
struct AnimatedGIFImage: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        context.coordinator.load(url: url, into: imageView)
    }

    static func animatedImage(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return UIImage(data: data) }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        frames.reserveCapacity(frameCount)

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up))
            duration += frameDelay(at: index, source: source)
        }

        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: duration)
    }

    private static func frameDelay(at index: Int, source: CGImageSource) -> TimeInterval {
        let fallback: TimeInterval = 0.1
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return fallback }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? TimeInterval
        let delay = unclamped ?? clamped ?? fallback
        return delay < 0.02 ? fallback : delay
    }

    final class Coordinator {
        private var currentURL: URL?
        private var task: URLSessionDataTask?

        deinit { task?.cancel() }

        func load(url: URL, into imageView: UIImageView) {
            guard currentURL != url else { return }
            currentURL = url
            task?.cancel()
            imageView.image = nil
            imageView.stopAnimating()

            task = URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, _, _ in
                guard let self, let data, let image = AnimatedGIFImage.animatedImage(data: data) else { return }
                DispatchQueue.main.async {
                    guard self.currentURL == url else { return }
                    imageView?.image = image
                    imageView?.startAnimating()
                }
            }
            task?.resume()
        }
    }
}
#endif

extension URL {
    var isGIFImageURL: Bool {
        pathExtension.lowercased() == "gif"
    }
}
