import UIKit

/// Pulls a palette out of a photo.
enum SkyColorExtractor {

    /// Bumped whenever the algorithm changes. Stored on every entry so old
    /// captures can be recomputed from their kept photograph instead of being
    /// frozen at whatever the version that made them produced.
    static let version = 2

    /// Clusters closer than this are folded together. A flat overcast sky
    /// collapses to two or three colours, which is the truth about it; a clear
    /// sky spans zenith to horizon and keeps all six.
    static let mergeThreshold = 4.0

    /// Fraction of the frame a cluster must occupy before it can be the anchor,
    /// so a speck of roof or a lens flare cannot become the sky.
    static let minimumAnchorWeight = 0.15

    static let clusterCount = 6

    static func extract(from image: UIImage) -> SkyPalette? {
        guard let samples = sample(image), samples.count > 64 else { return nil }
        let merged = merge(kMeans(samples, k: clusterCount))
        guard !merged.isEmpty else { return nil }

        let anchorCandidates = merged.filter { $0.weight >= minimumAnchorWeight }
        guard let anchor = (anchorCandidates.isEmpty ? merged : anchorCandidates)
            .max(by: { $0.lab.l < $1.lab.l }) else { return nil }

        var total = 0.0
        var counted = 0
        for index in stride(from: 0, to: samples.count, by: 13) {
            let sample = samples[index]
            var nearest = Double.greatestFiniteMagnitude
            for cluster in merged {
                nearest = min(nearest, deltaE2000(sample.lab, cluster.lab))
            }
            total += nearest
            counted += 1
        }

        return SkyPalette(
            colors: merged.sorted { $0.meanY < $1.meanY }.map(\.rgb),
            anchor: anchor.rgb,
            anchorLab: anchor.lab,
            reconstructionError: counted > 0 ? total / Double(counted) : 0
        )
    }

    // MARK: - Sampling

    private struct Sample {
        let rgb: RGB
        let lab: Lab
        /// Vertical position in the frame, 0 at the top.
        let y: Double
    }

    private struct Cluster {
        var rgb: RGB
        var lab: Lab
        var weight: Double
        var meanY: Double
    }

    private static func sample(_ image: UIImage) -> [Sample]? {
        guard let cg = image.normalizedUp().cgImage else { return nil }

        let side = 64
        var buffer = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &buffer, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        var samples: [Sample] = []
        samples.reserveCapacity(side * side)
        for index in stride(from: 0, to: buffer.count, by: 4) {
            guard buffer[index + 3] > 127 else { continue }
            let pixel = index / 4
            // CGContext draws bottom-up, so flip to get frame coordinates.
            let row = side - 1 - (pixel / side)
            let rgb = RGB(
                r: Double(buffer[index]) / 255,
                g: Double(buffer[index + 1]) / 255,
                b: Double(buffer[index + 2]) / 255
            )
            samples.append(Sample(rgb: rgb, lab: Lab(rgb), y: Double(row) / Double(side - 1)))
        }
        return samples
    }

    // MARK: - Clustering

    /// k-means in Lab with a deterministic seed, so the same photo always
    /// yields the same palette. Random seeding would make results feel arbitrary.
    private static func kMeans(_ samples: [Sample], k: Int, iterations: Int = 14) -> [Cluster] {
        guard samples.count >= k else { return [] }

        let ordered = samples.sorted { $0.lab.l < $1.lab.l }
        var centroids: [Lab] = (0..<k).map { index in
            ordered[Int(Double(ordered.count - 1) * (Double(index) + 0.5) / Double(k))].lab
        }
        var assignment = [Int](repeating: 0, count: samples.count)

        for _ in 0..<iterations {
            for (index, sample) in samples.enumerated() {
                var best = 0
                var bestDistance = Double.greatestFiniteMagnitude
                for (candidate, centroid) in centroids.enumerated() {
                    let dl = sample.lab.l - centroid.l
                    let da = sample.lab.a - centroid.a
                    let db = sample.lab.b - centroid.b
                    let distance = dl * dl + da * da + db * db
                    if distance < bestDistance { bestDistance = distance; best = candidate }
                }
                assignment[index] = best
            }

            var sums = [(l: Double, a: Double, b: Double, n: Int)](
                repeating: (0, 0, 0, 0), count: k
            )
            for (index, sample) in samples.enumerated() {
                let slot = assignment[index]
                sums[slot].l += sample.lab.l
                sums[slot].a += sample.lab.a
                sums[slot].b += sample.lab.b
                sums[slot].n += 1
            }
            for slot in 0..<k where sums[slot].n > 0 {
                let n = Double(sums[slot].n)
                centroids[slot] = Lab(l: sums[slot].l / n, a: sums[slot].a / n, b: sums[slot].b / n)
            }
        }

        var sumR = [Double](repeating: 0, count: k)
        var sumG = [Double](repeating: 0, count: k)
        var sumB = [Double](repeating: 0, count: k)
        var sumY = [Double](repeating: 0, count: k)
        var counts = [Int](repeating: 0, count: k)

        for (index, sample) in samples.enumerated() {
            let slot = assignment[index]
            sumR[slot] += sample.rgb.r
            sumG[slot] += sample.rgb.g
            sumB[slot] += sample.rgb.b
            sumY[slot] += sample.y
            counts[slot] += 1
        }

        return (0..<k).compactMap { slot in
            guard counts[slot] > 0 else { return nil }
            let n = Double(counts[slot])
            return Cluster(
                rgb: RGB(r: sumR[slot] / n, g: sumG[slot] / n, b: sumB[slot] / n),
                lab: centroids[slot],
                weight: n / Double(samples.count),
                meanY: sumY[slot] / n
            )
        }
    }

    private static func merge(_ clusters: [Cluster]) -> [Cluster] {
        var result: [Cluster] = []
        for cluster in clusters.sorted(by: { $0.weight > $1.weight }) {
            if let hit = result.firstIndex(where: { deltaE2000($0.lab, cluster.lab) < mergeThreshold }) {
                let combined = result[hit].weight + cluster.weight
                let a = cluster.weight / combined
                let b = result[hit].weight / combined
                result[hit] = Cluster(
                    rgb: RGB(
                        r: cluster.rgb.r * a + result[hit].rgb.r * b,
                        g: cluster.rgb.g * a + result[hit].rgb.g * b,
                        b: cluster.rgb.b * a + result[hit].rgb.b * b
                    ),
                    lab: Lab(
                        l: cluster.lab.l * a + result[hit].lab.l * b,
                        a: cluster.lab.a * a + result[hit].lab.a * b,
                        b: cluster.lab.b * a + result[hit].lab.b * b
                    ),
                    weight: combined,
                    meanY: cluster.meanY * a + result[hit].meanY * b
                )
            } else {
                result.append(cluster)
            }
        }
        return result
    }
}

extension UIImage {
    /// Camera captures carry an orientation flag rather than rotated pixels.
    /// Without this the sky crop can land on the side of the frame.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
