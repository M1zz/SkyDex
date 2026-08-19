// AVFoundation's session types predate Sendable and are documented as safe to
// drive from a single serial queue, which is what happens below.
@preconcurrency import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit
import SwiftData
import SwiftUI
import UIKit

/// A 1:1 viewfinder.
///
/// `UIImagePickerController` cannot show a square preview, so with it you frame
/// the sky against edges that were never going to be kept and then find out
/// afterwards what the crop took. Here the preview is square and the file is
/// the same square: what you frame is what lands in the mosaic.
struct SquareCameraView: View {
    /// The captured file's bytes, not a `UIImage` — the import path decodes
    /// straight to the size it needs and never materialises the full frame.
    ///
    /// The third value is the sky the shot was framed under, if one was picked.
    /// The bytes are the ones the sensor gave: what gets collected is the sky as
    /// it was, and the borrowed colour travels alongside so the card that opens
    /// next can put it straight back on.
    let onCapture: (Data, Date, String?) -> Void
    let onPickFromLibrary: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = SkyCamera()

    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var collected: [SkyEntry]
    @State private var chips: [SkyEntry] = []

    /// The sky the viewfinder is wearing.
    @State private var lens: SkyEntry?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                viewfinder
                borrowing
                Spacer(minLength: 0)
                shutter
            }
        }
        .task { await camera.start() }
        .task { chips = SkyEntry.palette(from: collected) }
        .onChange(of: collected.count) { _, _ in chips = SkyEntry.palette(from: collected) }
        .onChange(of: lens?.hex) { _, _ in camera.borrow(lens?.lab) }
        .onDisappear { camera.stop() }
        .statusBarHidden()
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Button {
                camera.flip()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .opacity(camera.state == .running ? 1 : 0)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var viewfinder: some View {
        switch camera.state {
        case .running:
            ZStack {
                FilteredPreview(renderer: camera.renderer)
                grid
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .overlay(alignment: .bottom) {
                Text(lens == nil ? "하늘이 정사각형을 채우도록" : "그 하늘 아래에서 보는 중")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.black.opacity(0.35), in: Capsule())
                    .padding(.bottom, 14)
            }

        case .denied:
            message(
                icon: "camera.metering.unknown",
                title: "카메라 권한이 꺼져 있어요",
                detail: "설정에서 카메라를 켜면 하늘을 바로 찍을 수 있어요.",
                actionTitle: "설정 열기"
            ) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }

        case .unavailable:
            message(
                icon: "camera.badge.ellipsis",
                title: "카메라를 쓸 수 없어요",
                detail: "시뮬레이터에는 카메라가 없습니다. 사진에서 골라도 정사각형으로 잘려 들어갑니다.",
                actionTitle: "사진에서 고르기"
            ) {
                dismiss()
                onPickFromLibrary()
            }

        case .idle:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    /// Thirds, faint. A horizon that sits on a line is the difference between a
    /// tile of sky and a tile of roof.
    private var grid: some View {
        GeometryReader { geo in
            Path { path in
                for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                    path.move(to: CGPoint(x: geo.size.width * fraction, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width * fraction, y: geo.size.height))
                    path.move(to: CGPoint(x: 0, y: geo.size.height * fraction))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * fraction))
                }
            }
            .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    /// The skies you have collected, along the bottom of the viewfinder.
    ///
    /// Picking one puts it on the glass: the sky in front of you is moved onto
    /// that colour, live, while everything that is not sky stays where it is.
    /// It is the same table the card uses, built the same way, so a colour sits
    /// in the same place in both.
    ///
    /// **The shutter is not filtered.** What the sensor gave is what gets
    /// collected — the colour that goes on the board, into the palette and out
    /// to the widget has to be the sky that was actually over you, or every
    /// screen in this app quietly starts lying. The card opens straight after
    /// with the borrowed sky already picked, so the picture you were looking at
    /// is the picture in front of you and one tap from the share sheet.
    @ViewBuilder
    private var borrowing: some View {
        if camera.state == .running, !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        lens = nil
                    } label: {
                        chip(fill: AnyShapeStyle(.white.opacity(0.12)), picked: lens == nil)
                            .overlay {
                                Image(systemName: "circle.slash")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("필터 없이")

                    ForEach(chips) { sky in
                        Button {
                            lens = lens?.uuid == sky.uuid ? nil : sky
                        } label: {
                            chip(fill: AnyShapeStyle(Color(sky.rgb)), picked: lens?.uuid == sky.uuid)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(sky.capturedAt, format: .dateTime.month().day().hour().minute()))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .sensoryFeedback(.selection, trigger: lens?.uuid)
        }
    }

    private func chip(fill: AnyShapeStyle, picked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fill)
            .frame(width: 44, height: 44)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white, lineWidth: picked ? 2.5 : 0)
            }
    }

    private var shutter: some View {
        VStack(spacing: 18) {
            Button {
                camera.capture { data in
                    onCapture(data, .now, lens?.hex)
                    dismiss()
                }
            } label: {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 3).frame(width: 74, height: 74)
                    Circle().fill(.white).frame(width: 60, height: 60)
                }
            }
            .disabled(camera.state != .running || camera.isBusy)
            .opacity(camera.state == .running ? 1 : 0.3)

            Button("사진에서 고르기") {
                dismiss()
                onPickFromLibrary()
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 28)
        .padding(.top, 16)
    }

    private func message(
        icon: String,
        title: String,
        detail: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Session

@MainActor
final class SkyCamera: ObservableObject {
    enum State { case idle, running, denied, unavailable }

    @Published private(set) var state: State = .idle
    @Published private(set) var isBusy = false

    let session = AVCaptureSession()

    /// What the glass shows. Frames go through Core Image on their way here, so
    /// the preview is a rendered picture rather than a layer the system draws —
    /// which is the whole reason this is not an `AVCaptureVideoPreviewLayer`
    /// any more. On iOS a preview layer cannot be filtered: `CALayer`'s
    /// `compositingFilter` and `filters` are quietly ignored, so anything laid
    /// over it is a coloured sheet on top of the picture rather than a change to
    /// the picture.
    let renderer = PreviewRenderer()

    private lazy var frames = FrameFilter(renderer: renderer)

    private let output = AVCapturePhotoOutput()
    private let video = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "skydex.camera.session")
    private let frameQueue = DispatchQueue(label: "skydex.camera.frames")
    private var position: AVCaptureDevice.Position = .back
    /// `capturePhoto` does not retain its delegate, so it has to be held here
    /// until the callback lands.
    private var pending: PhotoDelegate?

    func start() async {
        guard state != .running else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .denied
                return
            }
        default:
            state = .denied
            return
        }

        guard await configure(for: position) else {
            state = .unavailable
            return
        }

        // Wait for the session to actually be running before the shutter is
        // enabled. Reporting `.running` while `startRunning()` is still queued
        // leaves a window where a fast tap reaches `capturePhoto` with no
        // active connection, and that raises an Objective-C exception Swift
        // cannot catch.
        let started = await withCheckedContinuation { continuation in
            queue.async { [session] in
                if !session.isRunning { session.startRunning() }
                continuation.resume(returning: session.isRunning)
            }
        }
        state = started ? .running : .unavailable
    }

    /// Put a collected sky on the glass, or take it off.
    func borrow(_ sky: Lab?) {
        frames.borrow(sky)
    }

    func stop() {
        let session = self.session
        queue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func flip() {
        guard state == .running, !isBusy else { return }
        let target: AVCaptureDevice.Position = position == .back ? .front : .back
        Task {
            if await configure(for: target) {
                position = target
            } else {
                // Reconfiguring removes the old input first, so a failed swap
                // would otherwise leave the session running with no camera
                // attached at all.
                _ = await configure(for: position)
            }
        }
    }

    func capture(_ completion: @escaping (Data) -> Void) {
        guard state == .running, !isBusy else { return }
        isBusy = true

        let delegate = PhotoDelegate { [weak self] data in
            guard let self else { return }
            self.isBusy = false
            self.pending = nil
            guard let data else { return }
            // The centre square of this 4:3 frame is exactly what the preview
            // showed; `SkyImage` takes that crop as it decodes.
            completion(data)
        }
        pending = delegate

        let settings = AVCapturePhotoSettings()
        let output = self.output
        let session = self.session
        queue.async { [weak self] in
            // Checked on the session queue, where the answer cannot go stale
            // between the check and the call. A backgrounded or interrupted
            // session drops its connection without telling us first.
            guard session.isRunning,
                  let connection = output.connection(with: .video),
                  connection.isActive, connection.isEnabled else {
                DispatchQueue.main.async {
                    self?.isBusy = false
                    self?.pending = nil
                }
                return
            }
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configure(for position: AVCaptureDevice.Position) async -> Bool {
        // Everything the session queue touches is pulled out here, so nothing
        // main-actor isolated is read from inside the closure.
        let session = self.session
        let output = self.output
        let video = video
        let frames = frames
        let frameQueue = frameQueue

        return await withCheckedContinuation { continuation in
            queue.async {
                session.beginConfiguration()
                defer { session.commitConfiguration() }

                for input in session.inputs { session.removeInput(input) }

                guard let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: position
                ), let input = try? AVCaptureDeviceInput(device: device),
                    session.canAddInput(input) else {
                    continuation.resume(returning: false)
                    return
                }

                session.sessionPreset = .photo
                session.addInput(input)

                if !session.outputs.contains(output), session.canAddOutput(output) {
                    session.addOutput(output)
                }

                if !session.outputs.contains(video), session.canAddOutput(video) {
                    // BGRA, because that is what Core Image reads without a
                    // conversion pass in front of every frame.
                    video.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    // The photo preset exists so the *file* is full size. Its
                    // video stream is twelve megapixels of the same picture
                    // thirty times a second, which this app cannot afford to
                    // touch — it has been killed once already for holding too
                    // many pixels. Preview-sized buffers are the same frame at
                    // the size the glass is going to show it at.
                    video.automaticallyConfiguresOutputBufferDimensions = false
                    video.deliversPreviewSizedOutputBuffers = true
                    video.alwaysDiscardsLateVideoFrames = true
                    video.setSampleBufferDelegate(frames, queue: frameQueue)
                    session.addOutput(video)
                }

                // The app is portrait only, so pinning the connection means the
                // captured file comes out upright with no orientation flag for
                // the crop and the colour sampler to trip over.
                for connection in [output.connection(with: .video), video.connection(with: .video)] {
                    guard let connection else { continue }
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                }

                // The preview layer used to mirror the front camera for free.
                // Rendering the frames by hand means saying so: a viewfinder
                // that does not mirror is a viewfinder you cannot aim.
                if let connection = video.connection(with: .video),
                   connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = position == .front
                }

                continuation.resume(returning: true)
            }
        }
    }
}

/// Hops to the main queue before doing anything with what it was handed, so
/// the immutable closure it carries is the only state crossing queues.
private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async { self.completion(data) }
    }
}

/// The viewfinder, drawn by us.
///
/// `MTKView` rather than a `UIImageView` fed from a `CIContext`: a filtered
/// frame that has to come back to the CPU as a `CGImage` before it can be shown
/// costs a full readback thirty times a second, and the picture arrives late
/// enough that the viewfinder feels like a video call.
private struct FilteredPreview: UIViewRepresentable {
    let renderer: PreviewRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        // Core Image writes straight into the drawable, which it cannot do to a
        // framebuffer the system has marked write-only.
        view.framebufferOnly = false
        // Drawn when a frame arrives rather than on a clock. A viewfinder that
        // redraws sixty times a second to show the same thirty frames is heat.
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.delegate = renderer
        view.isOpaque = true
        view.backgroundColor = .black
        renderer.attach(view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {}
}

/// Holds the latest frame and puts it on the glass.
final class PreviewRenderer: NSObject, MTKViewDelegate {
    let device = MTLCreateSystemDefaultDevice()

    private lazy var commands = device?.makeCommandQueue()
    private lazy var context: CIContext? = device.map { CIContext(mtlDevice: $0, options: [.name: "skydex.viewfinder"]) }
    private let space = CGColorSpace(name: CGColorSpace.sRGB)

    /// Written on the video queue, read on the render thread.
    private let lock = NSLock()
    private var latest: CIImage?

    private weak var view: MTKView?

    func attach(_ view: MTKView) {
        self.view = view
    }

    func show(_ image: CIImage) {
        lock.lock()
        latest = image
        lock.unlock()
        DispatchQueue.main.async { [weak view] in view?.setNeedsDisplay() }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        lock.lock()
        let image = latest
        lock.unlock()

        guard let image,
              let context,
              let space,
              let drawable = view.currentDrawable,
              let buffer = commands?.makeCommandBuffer()
        else { return }

        let size = view.drawableSize
        guard size.width > 0, image.extent.width > 0 else { return }

        // The frame is square and so is the view, so one scale does both axes.
        //
        // No flip. Core Image counts from the bottom of an image and a Metal
        // texture is presented from the top, so turning the frame over on the
        // way in looks like the obviously correct thing to do — and it puts the
        // roofline along the top of the viewfinder. `render(_:to:)` has already
        // reconciled the two conventions.
        let scale = size.width / image.extent.width
        let fitted = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        context.render(
            fitted,
            to: drawable.texture,
            commandBuffer: buffer,
            bounds: CGRect(origin: .zero, size: size),
            colorSpace: space
        )
        buffer.present(drawable)
        buffer.commit()
    }
}

/// Squares every frame, and moves the sky in it onto a borrowed colour.
///
/// The table is the same one the card uses (`SkyRecolor`), which is the point of
/// baking the whole transform into a cube: it is built once, off this queue, and
/// after that a frame costs one lookup whatever the colours are doing.
///
/// Two things have to be watched rather than assumed. The colour of the sky in
/// front of you is not the colour of the sky in the photograph you are borrowing
/// *from* — it is whatever the camera is pointed at right now, so it is measured
/// from the live frame, with the same extractor the still path uses. And it
/// moves: a cloud crosses, you turn towards the sun. So it is re-measured a
/// couple of times a second and the table rebuilt when the answer has drifted
/// far enough to see, never on the frame's own queue.
final class FrameFilter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Re-measure roughly twice a second.
    private static let framesBetweenSamples = 15

    /// A drift smaller than this is not worth a new table.
    private static let driftWorthRebuilding = 3.0

    private let renderer: PreviewRenderer
    private let context = CIContext(options: [.name: "skydex.viewfinder.sample"])
    private let building = DispatchQueue(label: "skydex.camera.lut", qos: .userInitiated)
    private let space = CGColorSpace(name: CGColorSpace.sRGB)

    private let lock = NSLock()
    private var wanted: Lab?
    private var cube: Data?
    private var builtFrom: Lab?
    private var builtTo: Lab?
    private var isBuilding = false
    private var since = 0

    init(renderer: PreviewRenderer) {
        self.renderer = renderer
    }

    func borrow(_ sky: Lab?) {
        lock.lock()
        wanted = sky
        if sky == nil {
            cube = nil
            builtTo = nil
            builtFrom = nil
        }
        since = Self.framesBetweenSamples
        lock.unlock()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        handle(CIImage(cvPixelBuffer: buffer))
    }

    /// One frame, from wherever. Split out from the delegate method because a
    /// simulator has no camera, and the only way to see this path run before it
    /// reaches a device is to hand it a picture.
    func handle(_ incoming: CIImage) {
        let frame = squared(incoming)

        lock.lock()
        let target = wanted
        let table = cube
        lock.unlock()

        guard let target else {
            renderer.show(frame)
            return
        }

        rebuildIfNeeded(from: frame, to: target)

        guard let table, let space else {
            // Until the first table is ready the viewfinder shows the sky as it
            // is. A frozen frame or a black square would be worse than a beat of
            // the truth.
            renderer.show(frame)
            return
        }

        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = frame
        filter.cubeDimension = Float(SkyRecolor.cubeSide)
        filter.cubeData = table
        filter.colorSpace = space
        renderer.show(filter.outputImage ?? frame)
    }

    /// The centre square, sitting at the origin.
    private func squared(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let side = min(extent.width, extent.height)
        let crop = CGRect(
            x: extent.origin.x + (extent.width - side) / 2,
            y: extent.origin.y + (extent.height - side) / 2,
            width: side,
            height: side
        )
        return image
            .cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.origin.x, y: -crop.origin.y))
    }

    private func rebuildIfNeeded(from frame: CIImage, to target: Lab) {
        lock.lock()
        let have = builtTo
        let hadSource = builtFrom
        let busy = isBuilding
        since += 1
        let due = since >= Self.framesBetweenSamples
        if due { since = 0 }
        lock.unlock()

        guard !busy else { return }
        let changed = have.map { deltaE2000($0, target) > 0.5 } ?? true
        guard changed || due else { return }

        guard let source = measure(frame) else { return }
        if !changed, let hadSource, deltaE2000(hadSource, source) < Self.driftWorthRebuilding { return }

        lock.lock()
        isBuilding = true
        lock.unlock()

        building.async { [weak self] in
            let table = SkyRecolor.cube(from: source, to: target, strength: 1)
            guard let self else { return }
            self.lock.lock()
            self.cube = table
            self.builtFrom = source
            self.builtTo = target
            self.isBuilding = false
            self.lock.unlock()
        }
    }

    /// What colour the sky in front of the lens is, asked of a small copy.
    ///
    /// The same `SkyColorExtractor` the shutter uses, so the glass and the file
    /// agree about which colour is being moved. It downsamples to sixty-four
    /// square regardless, and this hands it a quarter-size frame rather than a
    /// full one — a readback thirty times a second would cost more than the
    /// filter does.
    private func measure(_ frame: CIImage) -> Lab? {
        let side = 240.0
        guard frame.extent.width > 0 else { return nil }
        let scale = side / frame.extent.width
        let small = frame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(small, from: CGRect(x: 0, y: 0, width: side, height: side)) else {
            return nil
        }
        return SkyColorExtractor.skyColor(from: UIImage(cgImage: cg, scale: 1, orientation: .up)).lab
    }
}

