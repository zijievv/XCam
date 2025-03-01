@preconcurrency import AVFoundation

typealias PhotoData = Data

@MainActor
final class CameraModel {
    let captureSession: AVCaptureSession = .init()
    private let photoOutput: AVCapturePhotoOutput = .init()
    private var device: AVCaptureDevice?
    private var photoCapture: PhotoCapture?

    init() {
        initialize()
    }

    func startCapture() async {
        let session = captureSession
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                continuation.resume()
            }
        }
    }

    func stopCapture() async {
        let session = captureSession
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                session.stopRunning()
                continuation.resume()
            }
        }
    }

    func takePhoto() async throws -> PhotoData {
        guard
            captureSession.isRunning,
            let connection = photoOutput.connection(with: .video),
            connection.isActive,
            connection.isEnabled
        else {
            throw Error.captureSessionIsNotRunning
        }
        guard photoCapture == nil else {
            throw Error.cameraIsBusy
        }
        defer {
            photoCapture = nil
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode =
            if let device, device.hasFlash, device.isFlashAvailable {
                .auto
            } else {
                .off
            }
        return try await withCheckedThrowingContinuation { continuation in
            let capture = PhotoCapture(continuation: continuation)
            photoOutput.capturePhoto(with: settings, delegate: capture)
            photoCapture = capture
        }
    }

    private func initialize() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("no video device")
            return
        }
        self.device = device
        do {
            let input = try AVCaptureDeviceInput(device: device)
            configureCaptureSession(input: input, output: photoOutput)
        } catch {
            print("\(#function) error: \(error)")
        }
    }

    private func configureCaptureSession(input: AVCaptureDeviceInput, output: AVCapturePhotoOutput) {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        guard
            captureSession.canAddInput(input),
            captureSession.canAddOutput(photoOutput)
        else {
            print("invalid i/o")
            return
        }
        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)
    }
}

extension CameraModel {
    enum Error: Swift.Error {
        case captureSessionIsNotRunning
        case cameraIsBusy
        case photoDataCannotBeFlattened
    }
}

final class PhotoCapture: NSObject {
    var continuation: CheckedContinuation<PhotoData, any Swift.Error>?

    init(continuation: CheckedContinuation<PhotoData, any Error>) {
        self.continuation = continuation
    }
}

extension PhotoCapture: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        guard let continuation else { return }
        defer { self.continuation = nil }
        if let error {
            continuation.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: CameraModel.Error.photoDataCannotBeFlattened)
        }
    }
}
