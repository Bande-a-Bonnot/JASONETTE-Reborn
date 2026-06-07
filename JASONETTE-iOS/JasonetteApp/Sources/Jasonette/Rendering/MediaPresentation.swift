#if os(iOS)
import AVFoundation
import AVKit
import Contacts
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MediaCapturePresentation: Identifiable {
    let id = UUIDv7.generate()
    let request: MediaCaptureRequest
    let sourceType: UIImagePickerController.SourceType
}

struct MediaPlaybackPresentation: Identifiable {
    let id = UUIDv7.generate()
    let request: MediaPlaybackRequest
}

struct SharePresentation: Identifiable {
    let id = UUIDv7.generate()
    let request: ShareRequest
}

struct VisionScanPresentation: Identifiable {
    let id = UUIDv7.generate()
    let request: VisionScanRequest
}

struct MediaPlaybackPlayer: UIViewControllerRepresentable {
    let presentation: MediaPlaybackPresentation

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: presentation.request.url)
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
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

struct VisionScannerView: UIViewControllerRepresentable {
    let presentation: VisionScanPresentation
    let onComplete: (Result<[String: Any], Error>) -> Void

    func makeUIViewController(context: Context) -> VisionScannerViewController {
        VisionScannerViewController(request: presentation.request, onComplete: onComplete)
    }

    func updateUIViewController(_ uiViewController: VisionScannerViewController, context: Context) {}
}

final class VisionScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let request: VisionScanRequest
    private let onComplete: (Result<[String: Any], Error>) -> Void
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.jasonette.vision-scanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasCompleted = false

    init(request: VisionScanRequest, onComplete: @escaping (Result<[String: Any], Error>) -> Void) {
        self.request = request
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            complete(.failure(ActionDispatcher.ActionError.visionScanUnavailable))
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()

            session.beginConfiguration()
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                complete(.failure(ActionDispatcher.ActionError.visionScanUnavailable))
                return
            }
            session.addInput(input)
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)

            let metadataTypes = Self.metadataObjectTypes(for: request, availableTypes: output.availableMetadataObjectTypes)
            guard !metadataTypes.isEmpty else {
                session.commitConfiguration()
                complete(.failure(ActionDispatcher.ActionError.visionScanUnavailable))
                return
            }
            output.metadataObjectTypes = metadataTypes
            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            previewLayer = layer
            view.layer.insertSublayer(layer, at: 0)
        } catch {
            complete(.failure(error))
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let value = object.stringValue,
              !value.isEmpty else { return }

        complete(.success([
            "content": value,
            "type": Self.jasonetteType(for: object.type),
            "raw_type": object.type.rawValue
        ]))
    }

    private func complete(_ result: Result<[String: Any], Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        onComplete(result)
    }

    private static func metadataObjectTypes(
        for request: VisionScanRequest,
        availableTypes: [AVMetadataObject.ObjectType]
    ) -> [AVMetadataObject.ObjectType] {
        let requested: [AVMetadataObject.ObjectType]
        switch request.kind {
        case "qrcode", "qr", "qr_code":
            requested = [.qr]
        case "barcode", "bar_code", "1d":
            requested = barcodeTypes.filter { $0 != .qr }
        default:
            requested = barcodeTypes
        }
        return requested.filter { availableTypes.contains($0) }
    }

    private static let barcodeTypes: [AVMetadataObject.ObjectType] = [
        .qr,
        .ean8,
        .ean13,
        .upce,
        .code39,
        .code39Mod43,
        .code93,
        .code128,
        .pdf417,
        .aztec,
        .dataMatrix,
        .interleaved2of5,
        .itf14
    ]

    private static func jasonetteType(for type: AVMetadataObject.ObjectType) -> String {
        switch type {
        case .qr:
            return "qrcode"
        case .ean8, .ean13, .upce, .code39, .code39Mod43, .code93, .code128, .interleaved2of5, .itf14:
            return "barcode"
        case .pdf417:
            return "pdf417"
        case .aztec:
            return "aztec"
        case .dataMatrix:
            return "datamatrix"
        default:
            return type.rawValue
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
        viewModel.actionDispatcher.setMediaPlaybackHandler { request in
            try await presentMediaPlayback(request)
        }
        viewModel.actionDispatcher.setShareHandler { request in
            try await presentShareSheet(request)
        }
        viewModel.actionDispatcher.setSnapshotHandler {
            try captureWindowSnapshot()
        }
        viewModel.actionDispatcher.setAddressBookHandler {
            try await requestAddressBook()
        }
        viewModel.actionDispatcher.setVisionScanHandler { request in
            try await presentVisionScan(request)
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

    func presentMediaPlayback(_ request: MediaPlaybackRequest) async throws {
        try await withCheckedThrowingContinuation { continuation in
            mediaPlaybackContinuation = continuation
            mediaPlaybackPresentation = MediaPlaybackPresentation(request: request)
        }
    }

    func mediaPlaybackDismissed() {
        guard let continuation = mediaPlaybackContinuation else { return }
        mediaPlaybackContinuation = nil
        continuation.resume()
    }

    func presentShareSheet(_ request: ShareRequest) async throws {
        try await withCheckedThrowingContinuation { continuation in
            shareContinuation = continuation
            sharePresentation = SharePresentation(request: request)
        }
    }

    func presentVisionScan(_ request: VisionScanRequest) async throws -> [String: Any] {
        guard AVCaptureDevice.default(for: .video) != nil else {
            throw ActionDispatcher.ActionError.visionScanUnavailable
        }
        guard await cameraAccessAllowed() else {
            throw ActionDispatcher.ActionError.visionScanPermissionDenied
        }
        return try await withCheckedThrowingContinuation { continuation in
            visionScanContinuation = continuation
            visionScanPresentation = VisionScanPresentation(request: request)
        }
    }

    func captureWindowSnapshot() throws -> SnapshotResult {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            throw ActionDispatcher.ActionError.snapshotUnavailable
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let data = image.pngData() else {
            throw ActionDispatcher.ActionError.snapshotUnavailable
        }
        return SnapshotResult(data: data, contentType: "image/png")
    }

    func requestAddressBook() async throws -> [[String: Any]] {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            break
        case .limited:
            break
        case .notDetermined:
            guard try await requestContactsAccess(store) else {
                throw ActionDispatcher.ActionError.addressBookPermissionDenied
            }
        case .denied, .restricted:
            throw ActionDispatcher.ActionError.addressBookPermissionDenied
        @unknown default:
            throw ActionDispatcher.ActionError.addressBookPermissionDenied
        }

        let request = CNContactFetchRequest(keysToFetch: AddressBookContactPayloadBuilder.keysToFetch)
        request.sortOrder = .givenName

        var contacts: [[String: Any]] = []
        try store.enumerateContacts(with: request) { contact, _ in
            guard !contact.phoneNumbers.isEmpty else { return }
            contacts.append(AddressBookContactPayloadBuilder.payload(for: contact))
        }
        return contacts
    }

    private func requestContactsAccess(_ store: CNContactStore) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
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

    func visionScanDismissed() {
        guard let continuation = visionScanContinuation else { return }
        visionScanContinuation = nil
        continuation.resume(throwing: ActionDispatcher.ActionError.visionScanCancelled)
    }

    func completeVisionScan(_ result: Result<[String: Any], Error>) {
        guard let continuation = visionScanContinuation else { return }
        visionScanContinuation = nil
        visionScanPresentation = nil
        switch result {
        case .success(let payload):
            continuation.resume(returning: payload)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
#endif
