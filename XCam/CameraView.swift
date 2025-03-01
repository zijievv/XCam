import AVFoundation
import SwiftUI

@MainActor
@Observable
final class CameraViewModel {
    let cameraModel = CameraModel()
    var photoData: PhotoData?

    var image: Image? {
        photoData
            .flatMap(UIImage.init(data:))
            .map(Image.init(uiImage:))
    }

    func onShutterTap() {
        Task {
            do {
                let data = try await cameraModel.takePhoto()
                photoData = data
                await cameraModel.stopCapture()
            } catch {
                print("take photo error: \(error)")
            }
        }
    }
}

struct CameraView: View {
    @State private var viewModel: CameraViewModel = .init()

    var body: some View {
        Color.black
            .layoutPriority(1)
            .overlay {
                if let image = viewModel.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Viewfinder(session: viewModel.cameraModel.captureSession)
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                if viewModel.photoData == nil {
                    Button(action: viewModel.onShutterTap) {
                        Image(systemName: "button.programmable")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .shadow(radius: 1, y: 1)
                    }
                    .tint(.white)
                } else {
                    Button("Drop") {
                        Task {
                            await viewModel.cameraModel.startCapture()
                        }
                        viewModel.photoData = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .shadow(radius: 1, y: 1)
                    .frame(height: 60)
                }
            }
            .task {
                await viewModel.cameraModel.startCapture()
            }
            .onDisappear {
                Task {
                    await viewModel.cameraModel.stopCapture()
                }
            }
    }
}

#Preview {
    CameraView()
}
