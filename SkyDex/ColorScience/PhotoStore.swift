import UIKit

/// Keeps the sky itself, not the whole photograph.
///
/// The extracted colours are a reduction; the picture is the evidence. Keeping
/// it means the palette can be recomputed whenever the extractor improves —
/// without it, every entry stays frozen at the algorithm that made it.
///
/// What gets kept is the sky third, resized so a file is small enough to hold
/// for years. Clustering runs on a 64px thumbnail anyway, so 640px leaves ten
/// times the resolution colour accuracy needs.
///
///     original 4032px q90   801KB · 1 year 285MB · 10 years 2.8GB
///     640px q75              39KB · 1 year  14MB · 10 years 0.13GB
///
/// Re-encoding also drops EXIF, which matters less for size than for location:
/// camera files carry GPS coordinates, and keeping originals would quietly
/// break the promise that no coordinate is ever stored.
enum PhotoStore {

    static let maxEdge: CGFloat = 640
    static let quality: CGFloat = 0.75

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("Skies", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Crops the sky third, resizes, strips metadata, writes to disk.
    /// Returns the filename to store on the entry.
    @discardableResult
    static func save(_ image: UIImage) -> String? {
        guard let prepared = skyCrop(image),
              let data = prepared.jpegData(compressionQuality: quality) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    static func delete(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    static func totalBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return files.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }

    /// The upper third of the frame, where sky lives in a handheld shot.
    static func skyCrop(_ image: UIImage) -> UIImage? {
        let upright = image.normalizedUp()
        guard let cg = upright.cgImage else { return nil }

        let cropHeight = max(1, cg.height / 3)
        guard let top = cg.cropping(
            to: CGRect(x: 0, y: 0, width: cg.width, height: cropHeight)
        ) else { return nil }

        let cropped = UIImage(cgImage: top)
        let scale = min(1, maxEdge / max(cropped.size.width, cropped.size.height))
        let target = CGSize(
            width: (cropped.size.width * scale).rounded(),
            height: (cropped.size.height * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
