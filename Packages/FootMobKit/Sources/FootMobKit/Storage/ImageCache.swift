import Foundation
#if canImport(ImageIO)
import ImageIO
import UniformTypeIdentifiers
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Downloads and downsamples team logos and news thumbnails into shared storage.
///
/// Widgets and Live Activities can't load remote images, so the timeline provider calls
/// `prefetch` before handing entries to the view, and views read files synchronously.
public actor ImageCache {
    public static let shared = ImageCache()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public nonisolated static func fileURL(for remote: URL, maxPixel: Int) -> URL {
        let name = remote.absoluteString.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }
            .joined()
            .suffix(120)
        return SharedStorage.directory("Images").appendingPathComponent("\(name)-\(maxPixel).png")
    }

    /// Ensures every URL is cached locally. Failures are ignored; views fall back to monograms.
    public func prefetch(_ urls: [URL], maxPixel: Int = 120) async {
        let missing = Set(urls).filter {
            !FileManager.default.fileExists(atPath: Self.fileURL(for: $0, maxPixel: maxPixel).path)
        }
        await withTaskGroup(of: Void.self) { group in
            for url in missing {
                group.addTask { [session] in
                    guard let (data, _) = try? await session.data(from: url),
                          let png = Self.downsample(data, maxPixel: maxPixel) else { return }
                    try? png.write(to: Self.fileURL(for: url, maxPixel: maxPixel), options: .atomic)
                }
            }
        }
    }

    public func prefetchLogos(for teams: [Team]) async {
        await prefetch(teams.compactMap(\.logoURL), maxPixel: 120)
    }

    private nonisolated static func downsample(_ data: Data, maxPixel: Int) -> Data? {
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
        #else
        return data
        #endif
    }

    #if canImport(UIKit)
    /// Synchronous read for widget and Live Activity views.
    public nonisolated static func cachedImage(for remote: URL?, maxPixel: Int = 120) -> UIImage? {
        guard let remote else { return nil }
        return UIImage(contentsOfFile: fileURL(for: remote, maxPixel: maxPixel).path)
    }
    #endif
}
