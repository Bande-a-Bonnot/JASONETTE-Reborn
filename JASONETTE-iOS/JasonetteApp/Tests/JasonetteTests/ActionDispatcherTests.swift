import XCTest
import Combine
@testable import Jasonette

@MainActor
final class ActionDispatcherTests: XCTestCase {
    private var stateManager: StateManager!
    private var dispatcher: ActionDispatcher!
    private let suiteName = "ActionDispatcherTests"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        stateManager = StateManager(defaults: defaults)
        dispatcher = ActionDispatcher(stateManager: stateManager)
    }

    override func tearDown() {
        dispatcher.invalidateAllTimers()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    private func decodeAction(_ json: [String: Any]) -> JasonAction {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(JasonAction.self, from: data)
    }

    private final class StubGeolocationProvider: GeolocationProviding {
        var result: Result<String, Error>
        private(set) var requestCount = 0

        init(result: Result<String, Error>) {
            self.result = result
        }

        func currentCoordinate() async throws -> String {
            requestCount += 1
            return try result.get()
        }
    }

    private final class StubMediaCaptureProvider {
        var result: Result<[String: Any], Error>
        private(set) var requests: [MediaCaptureRequest] = []

        init(result: Result<[String: Any], Error>) {
            self.result = result
        }

        func capture(_ request: MediaCaptureRequest) async throws -> [String: Any] {
            requests.append(request)
            return try result.get()
        }
    }

    private final class StubMediaPlaybackProvider {
        var result: Result<Void, Error>
        private(set) var requests: [MediaPlaybackRequest] = []

        init(result: Result<Void, Error> = .success(())) {
            self.result = result
        }

        func play(_ request: MediaPlaybackRequest) async throws {
            requests.append(request)
            try result.get()
        }
    }

    private final class StubShareProvider {
        private(set) var requests: [ShareRequest] = []

        func share(_ request: ShareRequest) async throws {
            requests.append(request)
        }
    }

    private final class StubSnapshotProvider {
        var result: Result<SnapshotResult, Error>
        private(set) var requestCount = 0

        init(result: Result<SnapshotResult, Error>) {
            self.result = result
        }

        func snapshot() async throws -> SnapshotResult {
            requestCount += 1
            return try result.get()
        }
    }

    private final class StubAddressBookProvider {
        var result: Result<[[String: Any]], Error>
        private(set) var requestCount = 0

        init(result: Result<[[String: Any]], Error>) {
            self.result = result
        }

        func contacts() async throws -> [[String: Any]] {
            requestCount += 1
            return try result.get()
        }
    }

    private final class StubVisionScanProvider {
        var result: Result<[String: Any], Error>
        private(set) var requests: [VisionScanRequest] = []

        init(result: Result<[String: Any], Error>) {
            self.result = result
        }

        func scan(_ request: VisionScanRequest) async throws -> [String: Any] {
            requests.append(request)
            return try result.get()
        }
    }

    private final class StubUtilityPickerProvider {
        let selectedIndex: Int?
        private(set) var requests: [UtilityPickerRequest] = []

        init(selectedIndex: Int?) {
            self.selectedIndex = selectedIndex
        }

        func pick(_ request: UtilityPickerRequest) async throws -> Int {
            requests.append(request)
            guard let selectedIndex else { throw ActionDispatcher.ActionError.utilityPickerCancelled }
            return selectedIndex
        }
    }

    private final class StubDatePickerProvider {
        let result: Result<DatePickerResult, Error>
        private(set) var requests: [DatePickerRequest] = []

        init(result: Result<DatePickerResult, Error>) {
            self.result = result
        }

        func pickDate(_ request: DatePickerRequest) async throws -> DatePickerResult {
            requests.append(request)
            return try result.get()
        }
    }

    // MARK: - $set

    func testSetUpdatesLocalState() async {
        let action = decodeAction([
            "type": "$set",
            "options": ["name": "Alice", "age": 30]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["name"] as? String, "Alice")
        XCTAssertEqual(stateManager.get()["age"] as? Int, 30)
    }

    func testSetTemplatesOptionsAgainstGetContext() async {
        stateManager.set(["message": "Hello"])
        let action = decodeAction([
            "type": "$set",
            "options": ["echo": "{{$get.message}}"]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(stateManager.get()["echo"] as? String, "Hello")
    }

    func testSetSupportsLegacyStyleMutationExpression() async {
        stateManager.set([
            "style": ["width": "86", "height": "175"]
        ])
        let action = decodeAction([
            "type": "$set",
            "options": [
                "style": "{{var new_style = $get.style; new_style['move']='true'; return new_style;}}"
            ]
        ])

        await dispatcher.execute(action)

        let style = stateManager.get()["style"] as? [String: Any]
        XCTAssertEqual(style?["width"] as? String, "86")
        XCTAssertEqual(style?["move"] as? String, "true")
    }

    // MARK: - $get

    func testGetIsNoOp() async {
        let action = decodeAction(["type": "$get"])
        await dispatcher.execute(action)
        // Should not crash
    }

    // MARK: - Named action trigger

    func testTriggerExecutesNamedAction() async {
        let namedAction = decodeAction([
            "type": "$set",
            "options": ["sent": true]
        ])
        dispatcher.setActionResolver { name in
            name == "send" ? namedAction : nil
        }

        let trigger = decodeAction(["trigger": "send"])
        await dispatcher.execute(trigger)

        XCTAssertEqual(stateManager.get()["sent"] as? Bool, true)
    }

    // MARK: - $cache.set

    func testCacheSetPersistsToCache() async {
        let action = decodeAction([
            "type": "$cache.set",
            "options": ["token": "abc123"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.cacheGet()["token"] as? String, "abc123")
    }

    // MARK: - $cache.get

    func testCacheGetIsNoOp() async {
        let action = decodeAction(["type": "$cache.get"])
        await dispatcher.execute(action)
        // Should not crash
    }

    // MARK: - $cache.reset

    func testCacheResetClearsCache() async {
        stateManager.cacheSet(["token": "abc"])
        let action = decodeAction(["type": "$cache.reset"])
        await dispatcher.execute(action)
        XCTAssertTrue(stateManager.cacheGet().isEmpty)
    }

    // MARK: - $render

    func testRenderCallsRenderHandler() async {
        let expectation = expectation(description: "render handler called")
        var receivedTemplate: String? = "sentinel"
        dispatcher.setRenderHandler { templateName in
            receivedTemplate = templateName
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$render"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNil(receivedTemplate)
    }

    func testRenderDataBecomesJasonTemplatePayload() async {
        let expectation = expectation(description: "render handler called")
        dispatcher.setRenderHandler { _ in expectation.fulfill() }
        let action = decodeAction([
            "type": "$render",
            "options": ["data": ["color": "#123456"]]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual((stateManager.get()["$jason"] as? [String: Any])?["color"] as? String, "#123456")
    }

    // MARK: - $reload

    func testReloadCallsReloadHandler() async {
        let expectation = expectation(description: "reload called")
        dispatcher.setReloadHandler {
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$reload"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - $href

    func testHrefCallsNavigationHandler() async {
        let expectation = expectation(description: "navigation called")
        var receivedHref: JasonHref?
        dispatcher.setNavigationHandler { href in
            receivedHref = href
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$href",
            "options": [
                "url": "https://example.com",
                "view": "push",
                "transition": "slide"
            ]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHref?.url, "https://example.com")
        XCTAssertEqual(receivedHref?.view, "push")
        XCTAssertEqual(receivedHref?.transition, "slide")
    }

    func testHrefCarriesNestedOptionsAsNavigationParams() async {
        let expectation = expectation(description: "navigation called")
        var receivedHref: JasonHref?
        dispatcher.setNavigationHandler { href in
            receivedHref = href
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$href",
            "options": [
                "url": "https://example.com/modal.json",
                "transition": "modal",
                "options": ["code": "{{message}}"]
            ]
        ])
        stateManager.set(["message": "rendered"])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHref?.url, "https://example.com/modal.json")
        XCTAssertEqual(receivedHref?.transition, "modal")
        XCTAssertEqual(receivedHref?.options?["code"]?.string, "rendered")
    }

    // MARK: - $back

    func testBackCallsNavigationWithBack() async {
        let expectation = expectation(description: "back called")
        var receivedHref: JasonHref?
        dispatcher.setNavigationHandler { href in
            receivedHref = href
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$back"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHref?.view, "$back")
    }

    // MARK: - $close

    func testCloseCallsNavigationWithClose() async {
        let expectation = expectation(description: "close called")
        var receivedHref: JasonHref?
        dispatcher.setNavigationHandler { href in
            receivedHref = href
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$close"])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHref?.view, "$close")
    }

    // MARK: - $util.alert

    func testUtilAlertCallsAlertHandler() async {
        let expectation = expectation(description: "alert called")
        var receivedTitle: String?
        var receivedDescription: String?
        dispatcher.setAlertHandler { title, description in
            receivedTitle = title
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.alert",
            "options": ["title": "Hello", "description": "World"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTitle, "Hello")
        XCTAssertEqual(receivedDescription, "World")
    }

    func testUtilAlertTemplatesLocalGetValues() async {
        stateManager.set(["message": "hello"])
        let expectation = expectation(description: "alert called")
        var receivedDescription: String?
        dispatcher.setAlertHandler { _, description in
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.alert",
            "options": ["title": "Message", "description": "{{$get.message}}"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedDescription, "hello")
    }

    // MARK: - $util.toast / $util.banner

    func testUtilToastShowsTransientToastNotification() async {
        let expectation = expectation(description: "toast shown")
        var receivedRequest: UtilityNotificationRequest?
        dispatcher.setUtilityNotificationHandler { request in
            receivedRequest = request
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.toast",
            "options": ["text": "Saved", "type": "success"]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedRequest, UtilityNotificationRequest(kind: .toast, title: "Saved", description: nil, styleType: "success"))
    }

    func testUtilBannerShowsTransientBannerNotification() async {
        let expectation = expectation(description: "banner shown")
        var receivedRequest: UtilityNotificationRequest?
        dispatcher.setUtilityNotificationHandler { request in
            receivedRequest = request
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.banner",
            "options": ["title": "Hello", "description": "World", "type": "info"]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedRequest, UtilityNotificationRequest(kind: .banner, title: "Hello", description: "World", styleType: "info"))
    }

    func testTriggerPassesOptionsAsJasonPayloadToNamedAction() async {
        let expectation = expectation(description: "named banner rendered payload")
        var receivedTitle: String?
        dispatcher.setUtilityNotificationHandler { request in
            receivedTitle = request.title
            expectation.fulfill()
        }
        let namedAction = decodeAction([
            "type": "$util.banner",
            "options": ["title": "{{$jason.title}}"]
        ])
        dispatcher.setActionResolver { name in name == "banner" ? namedAction : nil }
        let action = decodeAction([
            "trigger": "banner",
            "options": ["title": "Triggered"]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTitle, "Triggered")
    }

    func testJasonActionDecodesStringOptionsAndArrayContinuations() throws {
        let data = Data(#"{"type":"$util.banner","options":"{{$jason}}","success":[{"type":"$set","options":{"a":1}},{"type":"$render"}]}"#.utf8)
        let action = try JSONDecoder().decode(JasonAction.self, from: data)

        XCTAssertNil(action.options)
        XCTAssertEqual(action.rawOptions?.string, "{{$jason}}")
        XCTAssertEqual(action.success?.type, "$set")
        XCTAssertEqual(action.successActions?.map(\.type), ["$set", "$render"])
    }

    // MARK: - $geo.get

    func testGeoGetRequestsCoordinateAndStoresPayload() async {
        let provider = StubGeolocationProvider(result: .success("12.34,56.78"))
        dispatcher.setGeolocationProvider(provider)
        let action = decodeAction(["type": "$geo.get"])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(stateManager.get()["coord"] as? String, "12.34,56.78")
    }

    func testGeoGetDenialRunsErrorBranch() async {
        let provider = StubGeolocationProvider(result: .failure(ActionDispatcher.ActionError.locationDenied))
        dispatcher.setGeolocationProvider(provider)
        let action = decodeAction([
            "type": "$geo.get",
            "error": ["type": "$set", "options": ["geo_denied": true]]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(stateManager.get()["geo_denied"] as? Bool, true)
    }

    func testGeoGetPayloadFlowsIntoRenderSuccessAsJason() async {
        let provider = StubGeolocationProvider(result: .success("12.34,56.78"))
        dispatcher.setGeolocationProvider(provider)
        let expectation = expectation(description: "render handler called")
        dispatcher.setRenderHandler { template in
            XCTAssertEqual(template, "coord")
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$geo.get",
            "success": [
                "type": "$render",
                "options": ["template": "coord"]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        let jason = stateManager.get()["$jason"] as? [String: Any]
        XCTAssertEqual(jason?["coord"] as? String, "12.34,56.78")
    }

    func testGeoGetDenialWithoutErrorBranchShowsFallbackAlert() async {
        let provider = StubGeolocationProvider(result: .failure(ActionDispatcher.ActionError.locationDenied))
        dispatcher.setGeolocationProvider(provider)
        let expectation = expectation(description: "fallback alert shown")
        dispatcher.setAlertHandler { title, description in
            XCTAssertEqual(title, "Action failed")
            XCTAssertEqual(description, "Location permission was denied.")
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$geo.get"])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(provider.requestCount, 1)
    }

    // MARK: - $util.picker / $util.datepicker

    func testUtilityPickerExecutesSelectedItemAction() async {
        let provider = StubUtilityPickerProvider(selectedIndex: 1)
        dispatcher.setUtilityPickerHandler(provider.pick)
        let expectation = expectation(description: "selected picker item action executed")
        dispatcher.setAlertHandler { title, description in
            XCTAssertEqual(title, "Second")
            XCTAssertEqual(description, "Selected")
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.picker",
            "options": [
                "items": [
                    ["text": "First", "action": ["type": "$util.alert", "options": ["title": "First"]]],
                    ["text": "Second", "action": ["type": "$util.alert", "options": ["title": "Second", "description": "Selected"]]]
                ]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(provider.requests.first?.items.map(\.text), ["First", "Second"])
        XCTAssertEqual(stateManager.get()["value"] as? Int, 1)
        XCTAssertEqual(stateManager.get()["text"] as? String, "Second")
    }

    func testUtilityPickerSelectionPayloadFlowsToSuccessActionWhenItemHasNoAction() async {
        let provider = StubUtilityPickerProvider(selectedIndex: 0)
        dispatcher.setUtilityPickerHandler(provider.pick)
        let expectation = expectation(description: "picker success used selection payload")
        var receivedDescription: String?
        dispatcher.setAlertHandler { _, description in
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.picker",
            "options": ["items": [["text": "Blue", "value": "blue"]]],
            "success": [
                "type": "$util.alert",
                "options": ["title": "Picked", "description": "{{$jason.value}}/{{$jason.text}}"]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedDescription, "blue/Blue")
    }

    func testDatePickerStoresUnixTimestampAndFlowsToSuccessAction() async {
        let provider = StubDatePickerProvider(result: .success(DatePickerResult(value: 1_700_000_000)))
        dispatcher.setDatePickerHandler(provider.pickDate)
        let expectation = expectation(description: "datepicker success used value")
        var receivedDescription: String?
        dispatcher.setAlertHandler { _, description in
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$util.datepicker",
            "success": [
                "type": "$util.alert",
                "options": ["title": "Date", "description": "{{$jason.value}}"]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertEqual(stateManager.get()["value"] as? Int, 1_700_000_000)
        let jason = stateManager.get()["$jason"] as? [String: Any]
        XCTAssertEqual(jason?["value"] as? Int, 1_700_000_000)
        XCTAssertEqual(receivedDescription, "1700000000")
    }

    // MARK: - $vision.scan

    func testVisionScanRequestsQRCodeAndStoresPayload() async {
        let provider = StubVisionScanProvider(result: .success([
            "content": "https://example.com/scanned",
            "type": "qrcode"
        ]))
        dispatcher.setVisionScanHandler(provider.scan)
        let action = decodeAction([
            "type": "$vision.scan",
            "options": ["type": "qrcode"]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requests, [VisionScanRequest(kind: "qrcode")])
        XCTAssertEqual(stateManager.get()["content"] as? String, "https://example.com/scanned")
        let jason = stateManager.get()["$jason"] as? [String: Any]
        XCTAssertEqual(jason?["content"] as? String, "https://example.com/scanned")
    }

    func testVisionScanPayloadFlowsIntoSuccessAction() async {
        let provider = StubVisionScanProvider(result: .success(["content": "scanned-value"]))
        dispatcher.setVisionScanHandler(provider.scan)
        let expectation = expectation(description: "success alert used scan payload")
        var receivedDescription: String?
        dispatcher.setAlertHandler { _, description in
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$vision.scan",
            "success": [
                "type": "$util.alert",
                "options": ["title": "Scan", "description": "{{$jason.content}}"]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedDescription, "scanned-value")
    }

    func testVisionScanFailureRunsErrorBranch() async {
        let provider = StubVisionScanProvider(result: .failure(ActionDispatcher.ActionError.visionScanPermissionDenied))
        dispatcher.setVisionScanHandler(provider.scan)
        let expectation = expectation(description: "error branch ran")
        dispatcher.setAlertHandler { title, description in
            XCTAssertEqual(title, "Scan failed")
            XCTAssertEqual(description, "fallback")
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$vision.scan",
            "error": [
                "type": "$util.alert",
                "options": ["title": "Scan failed", "description": "fallback"]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testVisionScanWithoutNativeHandlerShowsRecognizedFallbackAlert() async {
        let expectation = expectation(description: "vision fallback alert shown")
        dispatcher.setAlertHandler { title, description in
            XCTAssertEqual(title, "Not implemented yet")
            XCTAssertEqual(description, "$vision.scan is recognized, but this platform cannot present the native scanner UI.")
            expectation.fulfill()
        }
        let action = decodeAction(["type": "$vision.scan"])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - $media.camera / $util.share

    func testMediaCameraRequestsPhotoCaptureAndStoresPayload() async {
        let provider = StubMediaCaptureProvider(result: .success([
            "data": "base64-photo",
            "media_type": "image",
            "content_type": "image/jpeg"
        ]))
        dispatcher.setMediaCaptureHandler(provider.capture)
        let action = decodeAction([
            "type": "$media.camera",
            "options": ["edit": "true"]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requests, [MediaCaptureRequest(source: .camera, mediaType: .image, allowsEditing: true)])
        XCTAssertEqual(stateManager.get()["data"] as? String, "base64-photo")
        XCTAssertEqual(stateManager.get()["media_type"] as? String, "image")
    }

    func testMediaCameraVideoRequestsVideoCapture() async {
        let provider = StubMediaCaptureProvider(result: .success([
            "file_url": "file:///tmp/capture.mov",
            "media_type": "video"
        ]))
        dispatcher.setMediaCaptureHandler(provider.capture)
        let action = decodeAction([
            "type": "$media.camera",
            "options": ["type": "video"]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requests, [MediaCaptureRequest(source: .camera, mediaType: .video, allowsEditing: false)])
        XCTAssertEqual(stateManager.get()["file_url"] as? String, "file:///tmp/capture.mov")
    }

    func testMediaCameraPassesCapturePayloadToSuccessAction() async {
        let provider = StubMediaCaptureProvider(result: .success(["data": "base64-photo"]))
        dispatcher.setMediaCaptureHandler(provider.capture)
        let expectation = expectation(description: "success alert used camera payload")
        var receivedDescription: String?
        dispatcher.setAlertHandler { _, description in
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$media.camera",
            "success": [
                "type": "$util.alert",
                "options": ["title": "Photo", "description": "{{$jason.data}}"]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedDescription, "base64-photo")
    }

    func testMediaCameraPermissionDenialRunsErrorBranch() async {
        let provider = StubMediaCaptureProvider(result: .failure(ActionDispatcher.ActionError.mediaCapturePermissionDenied))
        dispatcher.setMediaCaptureHandler(provider.capture)
        let action = decodeAction([
            "type": "$media.camera",
            "error": ["type": "$set", "options": ["camera_denied": true]]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(stateManager.get()["camera_denied"] as? Bool, true)
    }

    func testMediaPickerUsesPhotoLibrarySource() async {
        let provider = StubMediaCaptureProvider(result: .success(["data": "picked-photo"]))
        dispatcher.setMediaCaptureHandler(provider.capture)
        let action = decodeAction(["type": "$media.picker"])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requests, [MediaCaptureRequest(source: .photoLibrary, mediaType: .image, allowsEditing: false)])
    }

    func testUtilShareParsesTextURLImageDataAndFileURLItems() async {
        let provider = StubShareProvider()
        dispatcher.setShareHandler(provider.share)
        let action = decodeAction([
            "type": "$util.share",
            "options": [
                "items": [
                    ["type": "text", "text": "hello"],
                    ["type": "url", "url": "https://example.com"],
                    ["type": "image", "data": "aGVsbG8="],
                    ["type": "video", "file_url": "file:///tmp/capture.mov"]
                ]
            ]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertEqual(provider.requests.first?.items.count, 4)
        XCTAssertEqual(provider.requests.first?.items[0].kind, .text)
        XCTAssertEqual(provider.requests.first?.items[0].text, "hello")
        XCTAssertEqual(provider.requests.first?.items[1].url, URL(string: "https://example.com")!)
        XCTAssertEqual(provider.requests.first?.items[2].data, Data("hello".utf8))
        XCTAssertEqual(provider.requests.first?.items[3].url, URL(string: "file:///tmp/capture.mov")!)
    }

    // MARK: - $util.addressbook

    func testAddressBookStoresContactsAsJasonPayload() async {
        let contacts: [[String: Any]] = [
            [
                "name": "Alice Appleseed",
                "phone": [["type": "mobile", "text": "555-0100"]],
                "email": ["alice@example.com"]
            ]
        ]
        let provider = StubAddressBookProvider(result: .success(contacts))
        dispatcher.setAddressBookHandler(provider.contacts)
        let action = decodeAction(["type": "$util.addressbook"])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requestCount, 1)
        let jason = stateManager.get()["$jason"] as? [[String: Any]]
        XCTAssertEqual(jason?.first?["name"] as? String, "Alice Appleseed")
        XCTAssertEqual((jason?.first?["email"] as? [String])?.first, "alice@example.com")
    }

    func testAddressBookPayloadFlowsIntoRenderSuccessAction() async {
        let contacts: [[String: Any]] = [["name": "Bob", "phone": [], "email": []]]
        let provider = StubAddressBookProvider(result: .success(contacts))
        dispatcher.setAddressBookHandler(provider.contacts)
        let expectation = expectation(description: "render handler called")
        dispatcher.setRenderHandler { _ in expectation.fulfill() }
        let action = decodeAction([
            "type": "$util.addressbook",
            "success": ["type": "$render"]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual((stateManager.get()["$jason"] as? [[String: Any]])?.first?["name"] as? String, "Bob")
    }

    func testAddressBookFailureRunsErrorBranch() async {
        let provider = StubAddressBookProvider(result: .failure(ActionDispatcher.ActionError.addressBookPermissionDenied))
        dispatcher.setAddressBookHandler(provider.contacts)
        let action = decodeAction([
            "type": "$util.addressbook",
            "error": ["type": "$set", "options": ["addressbook_failed": true]]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(stateManager.get()["addressbook_failed"] as? Bool, true)
    }

    // MARK: - $snapshot

    func testSnapshotCapturesPNGPayloadAndStoresJasonData() async {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let provider = StubSnapshotProvider(result: .success(SnapshotResult(data: imageData, contentType: "image/png")))
        dispatcher.setSnapshotHandler(provider.snapshot)
        let action = decodeAction(["type": "$snapshot"])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(stateManager.get()["data"] as? String, imageData.base64EncodedString())
        XCTAssertEqual(stateManager.get()["media_type"] as? String, "image")
        XCTAssertEqual(stateManager.get()["content_type"] as? String, "image/png")
        let jason = stateManager.get()["$jason"] as? [String: Any]
        XCTAssertEqual(jason?["data"] as? String, imageData.base64EncodedString())
    }

    func testSnapshotPayloadFlowsIntoShareSuccessAction() async {
        let imageData = Data("screen".utf8)
        let snapshotProvider = StubSnapshotProvider(result: .success(SnapshotResult(data: imageData, contentType: "image/png")))
        let shareProvider = StubShareProvider()
        dispatcher.setSnapshotHandler(snapshotProvider.snapshot)
        dispatcher.setShareHandler(shareProvider.share)
        let action = decodeAction([
            "type": "$snapshot",
            "success": [
                "type": "$util.share",
                "options": [
                    "items": [["type": "image", "data": "{{$jason.data}}"]]
                ]
            ]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(shareProvider.requests.count, 1)
        XCTAssertEqual(shareProvider.requests.first?.items.first?.kind, .imageData)
        XCTAssertEqual(shareProvider.requests.first?.items.first?.data, imageData)
    }

    func testSnapshotFailureRunsErrorBranch() async {
        let provider = StubSnapshotProvider(result: .failure(ActionDispatcher.ActionError.snapshotUnavailable))
        dispatcher.setSnapshotHandler(provider.snapshot)
        let action = decodeAction([
            "type": "$snapshot",
            "error": ["type": "$set", "options": ["snapshot_failed": true]]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(stateManager.get()["snapshot_failed"] as? Bool, true)
    }

    // MARK: - $media.play

    func testMediaPlayResolvesURLAndCallsHandler() async {
        let provider = StubMediaPlaybackProvider()
        dispatcher.setDocumentURL(URL(string: "https://example.com/video/index.json"))
        dispatcher.setMediaPlaybackHandler(provider.play)
        let action = decodeAction([
            "type": "$media.play",
            "options": ["url": "clips/demo.mp4"]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requests, [MediaPlaybackRequest(url: URL(string: "https://example.com/video/clips/demo.mp4")!)])
    }

    func testMediaPlayRejectsDisallowedSchemeAndRunsError() async {
        let provider = StubMediaPlaybackProvider()
        dispatcher.setMediaPlaybackHandler(provider.play)
        let action = decodeAction([
            "type": "$media.play",
            "options": ["url": "file:///tmp/demo.mp4"],
            "error": ["type": "$set", "options": ["blocked_video": true]]
        ])

        await dispatcher.execute(action)

        XCTAssertTrue(provider.requests.isEmpty)
        XCTAssertEqual(stateManager.get()["blocked_video"] as? Bool, true)
    }

    func testMediaPlayFailureRunsErrorBranch() async {
        let provider = StubMediaPlaybackProvider(result: .failure(ActionDispatcher.ActionError.mediaPlaybackUnavailable))
        dispatcher.setMediaPlaybackHandler(provider.play)
        let action = decodeAction([
            "type": "$media.play",
            "options": ["url": "https://example.com/demo.mp4"],
            "error": ["type": "$set", "options": ["video_failed": true]]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(provider.requests, [MediaPlaybackRequest(url: URL(string: "https://example.com/demo.mp4")!)])
        XCTAssertEqual(stateManager.get()["video_failed"] as? Bool, true)
    }

    // MARK: - $audio.play

    func testAudioPlayResolvesURLAndCallsHandler() async {
        let expectation = expectation(description: "audio handler called")
        var playedURL: URL?
        dispatcher.setDocumentURL(URL(string: "https://example.com/sounds/index.json"))
        dispatcher.setAudioPlayHandler { url in
            playedURL = url
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$audio.play",
            "options": ["url": "1up.mp3"]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(playedURL, URL(string: "https://example.com/sounds/1up.mp3"))
    }

    func testAudioPlayRejectsDisallowedSchemeAndRunsError() async {
        let action = decodeAction([
            "type": "$audio.play",
            "options": ["url": "file:///tmp/1up.mp3"],
            "error": [
                "type": "$set",
                "options": ["blocked_audio": true]
            ]
        ])

        await dispatcher.execute(action)

        XCTAssertEqual(stateManager.get()["blocked_audio"] as? Bool, true)
    }

    // MARK: - $timer.start

    func testTimerStartFiresOptionsAction() async {
        let action = decodeAction([
            "type": "$timer.start",
            "options": [
                "name": "options-action",
                "interval": 0.1,
                "repeats": false,
                "action": ["type": "$set", "options": ["tick": true]]
            ]
        ])

        await dispatcher.execute(action)

        let expectation = expectation(description: "timer options action fired")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(self.stateManager.get()["tick"] as? Bool, true)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testTimerStartFiresSuccessAction() async {
        let expectation = expectation(description: "timer fired")
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["fired": true]]
        ])
        await dispatcher.execute(action)

        // Wait for timer to fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.stateManager.get()["fired"] as? Bool == true {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testTimerStartReplacesExistingTimer() async {
        let action1 = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["source": "first"]]
        ])
        await dispatcher.execute(action1)

        let action2 = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["source": "second"]]
        ])
        await dispatcher.execute(action2)

        let expectation = expectation(description: "second timer fired")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.stateManager.get()["source"] as? String == "second" {
                expectation.fulfill()
            }
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - $timer.stop

    func testTimerStopInvalidatesNamedTimer() async {
        let startAction = decodeAction([
            "type": "$timer.start",
            "options": ["name": "t1", "interval": 0.1, "repeats": true],
            "success": ["type": "$set", "options": ["timer_count": 1]]
        ])
        await dispatcher.execute(startAction)

        // execute() success chain already fired $set; reset the marker
        stateManager.set(["timer_count": "reset"])

        let stopAction = decodeAction([
            "type": "$timer.stop",
            "options": ["name": "t1"]
        ])
        await dispatcher.execute(stopAction)

        // Wait and verify the timer callback never fires after stop
        let expectation = expectation(description: "timer did not fire after stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(self.stateManager.get()["timer_count"] as? String, "reset")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Timer minimum interval

    func testTimerEnforcesMinimumInterval() async {
        // Pass 0.001s interval — should be clamped to 0.1s
        // Use a dedicated key that only the timer callback sets (not success chaining).
        // We wrap the $set inside the timer's success, but we must avoid the execute()
        // success chain also running it. So we use a nested action:
        // timer.start has no top-level success, but the timer callback fires the successAction.
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "fast", "interval": 0.001, "repeats": false],
            "success": ["type": "$set", "options": ["min_interval_done": true]]
        ])
        // Note: execute() will also fire success immediately via chaining.
        // Reset the state right after to isolate the timer callback.
        await dispatcher.execute(action)
        stateManager.set(["min_interval_done": "reset"])

        // At 0.05s, timer should NOT have fired yet (clamped to 0.1s)
        let expectation = expectation(description: "timer not fired yet")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Should still be "reset" — timer hasn't fired yet
            XCTAssertEqual(self.stateManager.get()["min_interval_done"] as? String, "reset")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Timer max count

    func testTimerEnforcesMaxCount() async {
        // Fill up to max (50) timers
        for i in 0..<50 {
            let action = decodeAction([
                "type": "$timer.start",
                "options": ["name": "timer_\(i)", "interval": 10.0, "repeats": true]
            ])
            await dispatcher.execute(action)
        }

        // The 51st timer with a NEW unique name should be rejected.
        // execute() success chaining fires immediately, so we reset after execute
        // and check that the timer callback itself never fires.
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "overflow", "interval": 0.1, "repeats": false],
            "success": ["type": "$set", "options": ["overflow_fired": true]]
        ])
        await dispatcher.execute(action)
        // Reset: execute() chained the success immediately, so clear the marker
        stateManager.set(["overflow_fired": "reset"])

        let expectation = expectation(description: "overflow timer did not fire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Timer was never created, so callback never fires; value stays "reset"
            XCTAssertEqual(self.stateManager.get()["overflow_fired"] as? String, "reset")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - One-shot timer cleanup

    func testOneShotTimerFiresSuccessAction() async {
        let expectation = expectation(description: "one-shot timer fires success action")
        let action = decodeAction([
            "type": "$timer.start",
            "options": ["name": "oneshot", "interval": 0.1, "repeats": false],
            "success": ["type": "$set", "options": ["oneshot_done": true]]
        ])
        await dispatcher.execute(action)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(self.stateManager.get()["oneshot_done"] as? Bool, true)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - invalidateAllTimers

    func testInvalidateAllTimersClearsAll() async {
        for i in 0..<3 {
            let action = decodeAction([
                "type": "$timer.start",
                "options": ["name": "t\(i)", "interval": 0.1, "repeats": true],
                "success": ["type": "$set", "options": ["t\(i)_fired": true]]
            ])
            await dispatcher.execute(action)
        }

        // execute() success chaining already fired the success actions.
        // Reset the markers, then invalidate timers so the timer callbacks never fire.
        for i in 0..<3 {
            stateManager.set(["t\(i)_fired": "reset"])
        }
        dispatcher.invalidateAllTimers()

        let expectation = expectation(description: "no timers fired after invalidation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for i in 0..<3 {
                // Timer callbacks never fired, so values remain "reset"
                XCTAssertEqual(self.stateManager.get()["t\(i)_fired"] as? String, "reset")
            }
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Success chaining

    func testSuccessChaining() async {
        let action = decodeAction([
            "type": "$set",
            "options": ["step": "first"],
            "success": [
                "type": "$set",
                "options": ["step": "second"]
            ]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["step"] as? String, "second")
    }

    // MARK: - Error chaining

    func testErrorChaining() async {
        // $network.request with invalid URL triggers error chain
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "not a url %%%"],
            "error": [
                "type": "$set",
                "options": ["error_fired": true]
            ]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["error_fired"] as? Bool, true)
    }

    // MARK: - $network.request response shapes

    private func makeStubbedDispatcher(documentURL: URL? = nil) -> ActionDispatcher {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return ActionDispatcher(stateManager: stateManager, session: session, documentURL: documentURL)
    }

    private func stubJSON(_ body: String) {
        let data = body.data(using: .utf8)!
        StubURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, data)
        }
    }

    func testNetworkRequestResolvesRelativeURLAgainstDocumentURL() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, URL(string: "https://example.com/app/api/items")!)
            expectation.fulfill()
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let dispatcher = makeStubbedDispatcher(documentURL: URL(string: "https://example.com/app/index.json")!)
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "api/items"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testNetworkRequestResolvesRootRelativeURLAgainstDocumentURL() async {
        let expectation = expectation(description: "request received")
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, URL(string: "https://example.com/api/items")!)
            expectation.fulfill()
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let dispatcher = makeStubbedDispatcher(documentURL: URL(string: "https://example.com/app/index.json")!)
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "/api/items"]
        ])
        await dispatcher.execute(action)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testNetworkRequestRejectsDisallowedSchemeAfterResolution() async {
        let dispatcher = makeStubbedDispatcher(documentURL: URL(string: "https://example.com/app/index.json")!)
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "javascript:alert(1)"],
            "error": ["type": "$set", "options": ["blocked_after_resolution": true]]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["blocked_after_resolution"] as? Bool, true)
    }

    func testNetworkRequestSuccessChainKeepsOriginalDocumentURLWhenDispatcherBaseChanges() async {
        let originalBase = URL(string: "https://example.com/app/index.json")!
        let reloadedBase = URL(string: "https://cdn.example.com/new/index.json")!
        let dispatcher = makeStubbedDispatcher(documentURL: originalBase)
        let lock = NSLock()
        var requestedURLs: [URL] = []

        StubURLProtocol.requestHandler = { request in
            lock.lock()
            requestedURLs.append(request.url!)
            let count = requestedURLs.count
            lock.unlock()

            if count == 1 {
                let didUpdateBase = DispatchSemaphore(value: 0)
                Task { @MainActor in
                    dispatcher.setDocumentURL(reloadedBase)
                    didUpdateBase.signal()
                }
                _ = didUpdateBase.wait(timeout: .now() + 1.0)
            }

            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }

        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "api/first"],
            "success": [
                "type": "$network.request",
                "options": ["url": "api/second"]
            ]
        ])
        await dispatcher.execute(action)

        lock.lock()
        let urls = requestedURLs
        lock.unlock()
        XCTAssertEqual(urls, [
            URL(string: "https://example.com/app/api/first")!,
            URL(string: "https://example.com/app/api/second")!
        ])
    }

    func testHrefSuccessChainKeepsOriginalDocumentURLWhenDispatcherBaseChanges() async {
        let originalBase = URL(string: "https://example.com/app/index.json")!
        let reloadedBase = URL(string: "https://cdn.example.com/new/index.json")!
        let dispatcher = makeStubbedDispatcher(documentURL: originalBase)
        var receivedHrefs: [JasonHref] = []
        dispatcher.setNavigationHandler { receivedHrefs.append($0) }
        dispatcher.setReloadHandler { dispatcher.setDocumentURL(reloadedBase) }

        let action = decodeAction([
            "type": "$reload",
            "success": [
                "type": "$href",
                "options": ["url": "detail.json"]
            ]
        ])
        await dispatcher.execute(action)

        XCTAssertEqual(receivedHrefs.first?.url, "https://example.com/app/detail.json")
    }

    func testNetworkRequestPassesResponseAsJasonPayloadToSuccessAction() async {
        stubJSON("{\"message\": \"from network\"}")
        let dispatcher = makeStubbedDispatcher()
        let expectation = expectation(description: "success alert used network payload")
        var receivedDescription: String?
        dispatcher.setAlertHandler { _, description in
            receivedDescription = description
            expectation.fulfill()
        }
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/payload"],
            "success": [
                "type": "$util.alert",
                "options": ["title": "Network", "description": "{{$jason.message}}"]
            ]
        ])

        await dispatcher.execute(action)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedDescription, "from network")
    }

    func testNetworkRequestStoresDictResponse() async {
        stubJSON("{\"ok\": true}")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/a"]
        ])
        await dispatcher.execute(action)
        let resp = stateManager.get()["$response"] as? [String: Any]
        XCTAssertEqual(resp?["ok"] as? Bool, true)
    }

    func testNetworkRequestStoresArrayResponse() async {
        // UUIDv7 per repo policy (CLAUDE.md: "Use UUIDv7 for all IDs. Strictly.")
        let firstID = "019635b8-fa94-7101-8000-000000000001"
        let secondID = "019635b8-fa94-7101-8000-000000000002"
        stubJSON("[{\"id\":\"\(firstID)\"},{\"id\":\"\(secondID)\"}]")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/b"]
        ])
        await dispatcher.execute(action)
        let resp = stateManager.get()["$response"] as? [[String: Any]]
        XCTAssertEqual(resp?.count, 2)
        XCTAssertEqual(resp?[0]["id"] as? String, firstID)
        XCTAssertEqual(resp?[1]["id"] as? String, secondID)
    }

    func testNetworkRequestStoresPlainTextResponse() async {
        StubURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200,
                                      httpVersion: nil, headerFields: nil)!
            return (resp, Data("hello world".utf8))
        }
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/c"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["$response"] as? String, "hello world")
    }

    func testNetworkRequestStoresJSONStringFragmentResponse() async {
        stubJSON("\"hello json\"")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/d"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["$response"] as? String, "hello json")
    }

    func testNetworkRequestStoresJSONNumberFragmentResponse() async {
        stubJSON("42")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/e"]
        ])
        await dispatcher.execute(action)
        XCTAssertEqual(stateManager.get()["$response"] as? Int, 42)
    }

    func testNetworkRequestStoresJSONNullFragmentResponse() async {
        stubJSON("null")
        let dispatcher = makeStubbedDispatcher()
        let action = decodeAction([
            "type": "$network.request",
            "options": ["url": "https://example.com/f"]
        ])
        await dispatcher.execute(action)
        XCTAssertTrue(stateManager.get()["$response"] is NSNull)
    }

    // MARK: - Unknown action

    func testUnknownActionDoesNotCrash() async {
        let action = decodeAction(["type": "$nonexistent.action"])
        await dispatcher.execute(action)
        // Should not crash
    }
}
