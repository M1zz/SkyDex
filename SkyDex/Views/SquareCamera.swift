// AVFoundation's session types predate Sendable and are documented as safe to
// drive from a single serial queue, which is what happens below.
@preconcurrency import AVFoundation
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
    let onCapture: (Data, Date) -> Void
    let onPickFromLibrary: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = SkyCamera()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                viewfinder
                Spacer(minLength: 0)
                shutter
            }
        }
        .task { await camera.start() }
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
                CameraPreview(session: camera.session)
                grid
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .overlay(alignment: .bottom) {
                Text("하늘이 정사각형을 채우도록")
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

    private var shutter: some View {
        VStack(spacing: 18) {
            Button {
                camera.capture { data in
                    onCapture(data, .now)
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

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "skydex.camera.session")
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
        let session = self.session
        let output = self.output

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

                if session.outputs.isEmpty, session.canAddOutput(output) {
                    session.addOutput(output)
                }

                // The app is portrait only, so pinning the connection means the
                // captured file comes out upright with no orientation flag for
                // the crop and the colour sampler to trip over.
                if let connection = output.connection(with: .video),
                   connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
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

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        // Fill, not fit: the square shows the centre of the sensor's 4:3 frame,
        // which is exactly the region the capture is cropped to.
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if let connection = view.previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
