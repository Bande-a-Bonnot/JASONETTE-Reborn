#if os(iOS)
import AVFoundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MediaCapturePresentation: Identifiable {
    let id = UUIDv7.generate()
    let request: MediaCaptureRequest
    let sourceType: UIImagePickerController.SourceType
}

struct SharePresentation: Identifiable {
    let id = UUIDv7.generate()
    let request: ShareRequest
}

struct MediaCapturePicker: UIViewControllerRepresentable {
    let presentation: MediaCapturePresentation
    let onComplete: (Result<[String: Any], Error>) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = presentation.sourceType
        picker.allowsEditing = presentation.request.allowsEditing

        let requestedMediaType = presentation.request.mediaType == .video
            ? UTType.movie.identifier
            : UTType.image.identifier
        let availableMediaTypes = UIImagePickerController.availableMediaTypes(for: presentation.sourceType) ?? []
        if availableMediaTypes.contains(requestedMediaType) {
            picker.mediaTypes = [requestedMediaType]
        }

        if presentation.sourceType == .camera {
            picker.cameraCaptureMode = presentation.request.mediaType == .video ? .video : .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(request: presentation.request, onComplete: onComplete)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let request: MediaCaptureRequest
        let onComplete: (Result<[String: Any], Error>) -> Void

        init(request: MediaCaptureRequest, onComplete: @escaping (Result<[String: Any], Error>) -> Void) {
            self.request = request
            self.onComplete = onComplete
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(.failure(ActionDispatcher.ActionError.mediaCaptureCancelled))
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if request.mediaType == .video {
                guard let url = info[.mediaURL] as? URL else {
                    onComplete(.failure(ActionDispatcher.ActionError.mediaCaptureUnavailable))
                    return
                }
                onComplete(.success([
                    "file_url": url.absoluteString,
                    "media_type": "video"
                ]))
                return
            }

            let imageKey: UIImagePickerController.InfoKey = request.allowsEditing ? .editedImage : .originalImage
            let fallbackKey: UIImagePickerController.InfoKey = request.allowsEditing ? .originalImage : .editedImage
            guard let image = (info[imageKey] as? UIImage) ?? (info[fallbackKey] as? UIImage),
                  let data = image.jpegData(compressionQuality: 0.9) else {
                onComplete(.failure(ActionDispatcher.ActionError.mediaCaptureUnavailable))
                return
            }

            onComplete(.success([
                "data": data.base64EncodedString(),
                "media_type": "image",
                "content_type": "image/jpeg"
            ]))
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let presentation: SharePresentation
    let onComplete: (Result<Void, Error>) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems(from: presentation.request),
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, error in
            if let error {
                onComplete(.failure(error))
            } else {
                onComplete(.success(()))
            }
        }
        controller.popoverPresentationController?.sourceView = controller.view
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    private func activityItems(from request: ShareRequest) -> [Any] {
        request.items.compactMap { item in
            switch item.kind {
            case .text:
                return item.text
            case .url, .fileURL:
                return item.url
            case .imageData:
                guard let data = item.data else { return nil }
                return UIImage(data: data) ?? data
            }
        }
    }
}

@MainActor
extension JasonetteView {
    func installNativeActionHandlers() {
        viewModel.actionDispatcher.setMediaCaptureHandler { request in
            try await requestMediaCapture(request)
        }
        viewModel.actionDispatcher.setShareHandler { request in
            try await presentShareSheet(request)
        }
    }

    func requestMediaCapture(_ request: MediaCaptureRequest) async throws -> [String: Any] {
        let sourceType = try await sourceType(for: request)
        return try await withCheckedThrowingContinuation { continuation in
            mediaCaptureContinuation = continuation
            mediaCapturePresentation = MediaCapturePresentation(request: request, sourceType: sourceType)
        }
    }

    private func sourceType(for request: MediaCaptureRequest) async throws -> UIImagePickerController.SourceType {
        if request.source == .photoLibrary {
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
                throw ActionDispatcher.ActionError.mediaCaptureUnavailable
            }
            return .photoLibrary
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            #if targetEnvironment(simulator)
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
                throw ActionDispatcher.ActionError.mediaCaptureUnavailable
            }
            return .photoLibrary
            #else
            throw ActionDispatcher.ActionError.mediaCaptureUnavailable
            #endif
        }

        guard await cameraAccessAllowed() else {
            throw ActionDispatcher.ActionError.mediaCapturePermissionDenied
        }
        return .camera
    }

    private func cameraAccessAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func mediaCaptureDismissed() {
        guard let continuation = mediaCaptureContinuation else { return }
        mediaCaptureContinuation = nil
        continuation.resume(throwing: ActionDispatcher.ActionError.mediaCaptureCancelled)
    }

    func completeMediaCapture(_ result: Result<[String: Any], Error>) {
        guard let continuation = mediaCaptureContinuation else { return }
        mediaCaptureContinuation = nil
        mediaCapturePresentation = nil
        switch result {
        case .success(let payload):
            continuation.resume(returning: payload)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    func presentShareSheet(_ request: ShareRequest) async throws {
        try await withCheckedThrowingContinuation { continuation in
            shareContinuation = continuation
            sharePresentation = SharePresentation(request: request)
        }
    }

    func shareDismissed() {
        guard let continuation = shareContinuation else { return }
        shareContinuation = nil
        continuation.resume()
    }

    func completeShare(_ result: Result<Void, Error>) {
        guard let continuation = shareContinuation else { return }
        shareContinuation = nil
        sharePresentation = nil
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
#endif
