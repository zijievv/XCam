import AVFoundation
import SwiftUI

struct Viewfinder: UIViewRepresentable {
    let session: AVCaptureSession

    init(session: AVCaptureSession) {
        self.session = session
    }

    func makeUIView(context: Context) -> some UIView {
        let view = ViewfinderView()
        view.backgroundColor = .clear
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: some UIView, context: Context) {
    }

    private final class ViewfinderView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
