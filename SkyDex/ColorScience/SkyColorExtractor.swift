import UIKit

/// Pulls the dominant sky colour out of a photo.
///
/// This never refuses. It used to return nil when it could not find a
/// convincing sky, and that nil became a rejected capture — which is exactly
/// the friction the app no longer wants. A photo is always stored, so this
/// always has to name a colour for it, falling back through progressively
/// dumber answers rather than giving up.
enum SkyColorExtractor {

    struct Cluster {
        let rgb: RGB
        let lab: Lab
        let weight: Double
    }

    /// Fraction of the frame a cluster must occupy before it is considered
    /// sky rather than a speck of roof, wire, or lens flare.
    static let minimumClusterWeight = 0.15

    /// The colour to file a photo under. Best answer first: the brightest
    /// cluster large enough to be sky, then the brightest cluster of any size,
    /// then the plain average, then mid grey for an image with no pixels to
    /// read at all.
    static func skyColor(from image: UIImage) -> (rgb: RGB, lab: Lab) {
        guard let samples = sample(image), !samples.isEmpty else {
            let grey = RGB(r: 0.5, g: 0.5, b: 0.5)
            return (grey, Lab(grey))
        }

        let clusters = samples.count > 32 ? kMeans(samples, k: 3) : []
        if let best = clusters.filter({ $0.weight >= minimumClusterWeight }).max(by: { $0.lab.l < $1.lab.l }) {
            return (best.rgb, best.lab)
        }
        if let best = clusters.max(by: { $0.lab.l < $1.lab.l }) {
            return (best.rgb, best.lab)
        }

        let n = Double(samples.count)
        let rgb = RGB(
            r: samples.reduce(0) { $0 + $1.rgb.r } / n,
            g: samples.reduce(0) { $0 + $1.rgb.g } / n,
            b: samples.reduce(0) { $0 + $1.rgb.b } / n
        )
        return (rgb, Lab(rgb))
    }

    // MARK: - Sampling

    private struct Sample {
        let rgb: RGB
        let lab: Lab
    }

    private static func sample(_ image: UIImage) -> [Sample]? {
        guard let cg = normalized(image).cgImage else { return nil }

        // Sky lives in the upper third of a handheld frame. Cropping first
        // keeps buildings and pavement out of the clustering entirely.
        let cropHeight = max(1, cg.height / 3)
        let cropRect = CGRect(x: 0, y: 0, width: cg.width, height: cropHeight)
        guard let top = cg.cropping(to: cropRect) else { return nil }

        let side = 64
        var buffer = [UInt8](repeating: 0, count: side * side * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &buffer,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(top, in: CGRect(x: 0, y: 0, width: side, height: side))

        var samples: [Sample] = []
        samples.reserveCapacity(side * side)

        for index in stride(from: 0, to: buffer.count, by: 4) {
            guard buffer[index + 3] > 127 else { continue }
            let rgb = RGB(
                r: Double(buffer[index]) / 255.0,
                g: Double(buffer[index + 1]) / 255.0,
                b: Double(buffer[index + 2]) / 255.0
            )
            samples.append(Sample(rgb: rgb, lab: Lab(rgb)))
        }
        return samples
    }

    /// Camera captures carry an orientation flag rather than rotated pixels.
    /// Without this the "upper third" crop can land on the side of the frame.
    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    // MARK: - Clustering

    /// k-means in Lab space with a deterministic seed, so the same photo always
    /// yields the same colour. Random seeding would make matches feel arbitrary.
    private static func kMeans(_ samples: [Sample], k: Int, iterations: Int = 12) -> [Cluster] {
        guard samples.count >= k else { return [] }

        let ordered = samples.sorted { $0.lab.l < $1.lab.l }
        var centroids: [Lab] = (0..<k).map { index in
            let position = (Double(index) + 0.5) / Double(k)
            let slot = Int(Double(ordered.count - 1) * position)
            return ordered[slot].lab
        }

        var assignment = [Int](repeating: 0, count: samples.count)

        for _ in 0..<iterations {
            for (index, sample) in samples.enumerated() {
                var bestIndex = 0
                var bestDistance = Double.greatestFiniteMagnitude
                for (candidateIndex, centroid) in centroids.enumerated() {
                    let dl = sample.lab.l - centroid.l
                    let da = sample.lab.a - centroid.a
                    let db = sample.lab.b - centroid.b
                    let distance = dl * dl + da * da + db * db
                    if distance < bestDistance {
                        bestDistance = distance
                        bestIndex = candidateIndex
                    }
                }
                assignment[index] = bestIndex
            }

            var sumL = [Double](repeating: 0, count: k)
            var sumA = [Double](repeating: 0, count: k)
            var sumB = [Double](repeating: 0, count: k)
            var counts = [Int](repeating: 0, count: k)

            for (index, sample) in samples.enumerated() {
                let slot = assignment[index]
                sumL[slot] += sample.lab.l
                sumA[slot] += sample.lab.a
                sumB[slot] += sample.lab.b
                counts[slot] += 1
            }

            for slot in 0..<k where counts[slot] > 0 {
                let n = Double(counts[slot])
                centroids[slot] = Lab(l: sumL[slot] / n, a: sumA[slot] / n, b: sumB[slot] / n)
            }
        }

        // Average the sRGB values alongside, so the dot can be filled with the
        // colour the user actually saw rather than a round-tripped conversion.
        var sumR = [Double](repeating: 0, count: k)
        var sumG = [Double](repeating: 0, count: k)
        var sumB2 = [Double](repeating: 0, count: k)
        var counts = [Int](repeating: 0, count: k)

        for (index, sample) in samples.enumerated() {
            let slot = assignment[index]
            sumR[slot] += sample.rgb.r
            sumG[slot] += sample.rgb.g
            sumB2[slot] += sample.rgb.b
            counts[slot] += 1
        }

        return (0..<k).compactMap { slot in
            guard counts[slot] > 0 else { return nil }
            let n = Double(counts[slot])
            let rgb = RGB(r: sumR[slot] / n, g: sumG[slot] / n, b: sumB2[slot] / n)
            return Cluster(
                rgb: rgb,
                lab: centroids[slot],
                weight: n / Double(samples.count)
            )
        }
    }
}
