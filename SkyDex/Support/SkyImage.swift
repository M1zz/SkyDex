import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Everything the mosaic needs a photo to be before it is stored.
///
/// The grid is built out of square tiles, so a photo is squared on the way in
/// rather than cropped at draw time — a tile should be the picture that was
/// framed, not a slice of it. Two sizes are kept: a small one the grid can
/// decode dozens of at once, and a larger one that is only read when a tile is
/// opened.
///
/// The work is done straight from the file bytes through ImageIO, never through
/// a full-size `UIImage`. Decoding a 12 MP camera frame and then shrinking it
/// costs about fifty megabytes of transient bitmap — and twice that when the
/// capture carries an orientation flag, because straightening it means drawing
/// the whole thing once more. `CGImageSourceCreateThumbnailAtIndex` decodes
/// directly at the size we asked for and applies the orientation as it goes, so
/// the full frame never exists in memory at all.
enum SkyImage {

    /// Roughly three times the widest tile on a phone, so a thumbnail never
    /// looks soft in the grid but still costs about twenty kilobytes.
    static let thumbnailSide: CGFloat = 360

    /// Enough to fill a phone screen in the detail view. Sky is mostly smooth
    /// gradient, so this compresses far below what the number suggests.
    static let photoSide: CGFloat = 1280

    struct Prepared {
        let square: UIImage
        let photo: Data
        let thumbnail: Data
    }

    static func prepare(data: Data) -> Prepared? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            return nil
        }

        // The decode is asked for a frame 4:3 of the target, because the centre
        // square of a 4:3 frame is only three quarters of its long side. Ask for
        // 1280 and the square that survives the crop is 960 and visibly soft.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int((photoSide * 4 / 3).rounded())
        ]

        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let square = UIImage(cgImage: decoded, scale: 1, orientation: .up).squared()
        return package(square)
    }

    /// For images that only ever exist as pixels. Both real sources hand over
    /// file bytes, so this is a safety net rather than a path anything takes.
    static func prepare(_ image: UIImage) -> Prepared? {
        package(image.squared().fitted(to: photoSide))
    }

    private static func package(_ square: UIImage) -> Prepared? {
        guard let photo = square.jpegData(compressionQuality: 0.8),
              let thumbnail = square.fitted(to: thumbnailSide).jpegData(compressionQuality: 0.75)
        else { return nil }
        return Prepared(square: square, photo: photo, thumbnail: thumbnail)
    }
}

extension UIImage {

    /// Centre crop to 1:1. This only rearranges an existing `CGImage`, so it
    /// costs nothing beyond the crop itself.
    func squared() -> UIImage {
        let up = orientedUp()
        guard let cg = up.cgImage else { return up }
        let side = min(cg.width, cg.height)
        let rect = CGRect(
            x: (cg.width - side) / 2,
            y: (cg.height - side) / 2,
            width: side,
            height: side
        )
        guard let cropped = cg.cropping(to: rect) else { return up }
        // Scale 1 so `size` reads in pixels from here on and `fitted(to:)` can
        // treat its argument as a pixel budget.
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    func fitted(to maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return self }
        let ratio = maxSide / longest
        let target = CGSize(
            width: (size.width * ratio).rounded(),
            height: (size.height * ratio).rounded()
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// A no-op for anything ImageIO handed over, since the orientation was
    /// applied during the decode. Kept for the `UIImage` safety net above.
    func orientedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// Decoding a JPEG on every SwiftUI body pass makes the grid stutter once there
/// are a few dozen tiles, so decoded thumbnails are held by entry id.
enum ThumbnailCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        return cache
    }()

    static func image(id: String, data: Data) -> UIImage? {
        let key = id as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func forget(id: String) {
        cache.removeObject(forKey: id as NSString)
    }
}
