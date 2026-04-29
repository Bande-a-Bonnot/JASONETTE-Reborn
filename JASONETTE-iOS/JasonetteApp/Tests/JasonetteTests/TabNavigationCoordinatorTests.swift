import XCTest
@testable import Jasonette

@MainActor
final class TabNavigationCoordinatorTests: XCTestCase {

    // MARK: UUIDv7

    func testUUIDv7HasVersionSevenAndRFC4122Variant() {
        let id = UUIDv7.generate().uuid
        XCTAssertEqual(id.6 & 0xF0, 0x70, "version nibble should be 7")
        XCTAssertEqual(id.8 & 0xC0, 0x80, "variant bits should be 10xx")
    }

    /// UUIDv7 is only time-ordered across millisecond boundaries; within the
    /// same millisecond the tail is random. The sleep here is deliberately
    /// >1ms to hit the cross-ms path — the within-ms path has no ordering
    /// guarantee and must not be tested.
    func testUUIDv7IsTimeOrderedAcrossMilliseconds() {
        let a = UUIDv7.generate()
        usleep(2_000) // 2ms — forces the ms counter to advance
        let b = UUIDv7.generate()
        XCTAssertLessThanOrEqual(a.uuidString, b.uuidString,
                                 "IDs minted in different ms must sort in generation order")
    }

    // MARK: TabDescriptor conversion

    func testDescriptorFromComponentWithDocumentURL() {
        let c = JasonComponent(); c.url = "https://example.com/tab1.json"
        let d = TabDescriptor(from: c)
        guard case .document(let url) = d?.target else {
            return XCTFail("expected .document, got \(String(describing: d?.target))")
        }
        XCTAssertEqual(url.absoluteString, "https://example.com/tab1.json")
    }

    func testDescriptorFromComponentWithHrefOverridesURL() {
        let c = JasonComponent()
        c.url = "https://example.com/ignored"
        var href = JasonHref(); href.url = "https://example.com/real"
        c.href = href
        let d = TabDescriptor(from: c)
        XCTAssertEqual(d?.selectableURL?.absoluteString, "https://example.com/real")
    }

    func testDescriptorResolvesRelativeURLAgainstBaseURL() {
        let c = JasonComponent(); c.url = "tabs/home.json"
        let baseURL = URL(string: "https://example.com/app/index.json")!
        let d = TabDescriptor(from: c, baseURL: baseURL)
        XCTAssertEqual(d?.selectableURL?.absoluteString, "https://example.com/app/tabs/home.json")
    }

    func testDescriptorResolvesRootRelativeURLAgainstBaseURL() {
        let c = JasonComponent(); c.url = "/tabs/home.json"
        let baseURL = URL(string: "https://example.com/app/index.json")!
        let d = TabDescriptor(from: c, baseURL: baseURL)
        XCTAssertEqual(d?.selectableURL?.absoluteString, "https://example.com/tabs/home.json")
    }

    func testDescriptorResolvesRelativeHrefURLAgainstBaseURL() {
        let c = JasonComponent()
        var href = JasonHref(); href.url = "tabs/real.json"
        c.href = href
        let baseURL = URL(string: "https://example.com/app/index.json")!
        let d = TabDescriptor(from: c, baseURL: baseURL)
        XCTAssertEqual(d?.selectableURL?.absoluteString, "https://example.com/app/tabs/real.json")
    }

    func testDescriptorResolvesDotSegmentsAgainstBaseURL() {
        let c = JasonComponent(); c.url = "../tabs/./home.json"
        let baseURL = URL(string: "https://example.com/app/v1/index.json")!
        let d = TabDescriptor(from: c, baseURL: baseURL)
        XCTAssertEqual(d?.selectableURL?.absoluteString, "https://example.com/app/tabs/home.json")
    }

    func testDescriptorResolvesProtocolRelativeURLAgainstBaseURL() {
        let c = JasonComponent(); c.url = "//cdn.example.com/tabs/home.json"
        let baseURL = URL(string: "https://example.com/app/index.json")!
        let d = TabDescriptor(from: c, baseURL: baseURL)
        XCTAssertEqual(d?.selectableURL?.absoluteString, "https://cdn.example.com/tabs/home.json")
    }

    func testDescriptorResolvesQueryOnlyURLAgainstBaseURL() {
        let c = JasonComponent(); c.url = "?tab=home#top"
        let baseURL = URL(string: "https://example.com/app/index.json")!
        let d = TabDescriptor(from: c, baseURL: baseURL)
        XCTAssertEqual(d?.selectableURL?.absoluteString, "https://example.com/app/index.json?tab=home#top")
    }

    func testDescriptorWithRelativeURLAndNoBaseReturnsNil() {
        let c = JasonComponent(); c.url = "tabs/home.json"
        XCTAssertNil(TabDescriptor(from: c))
    }

    func testDescriptorWithRelativeIconAndNoBaseDropsIcon() {
        let c = JasonComponent()
        c.url = "https://example.com/target.json"
        c.image = "icons/home.png"
        let d = TabDescriptor(from: c)
        XCTAssertNil(d?.label.iconURL)
    }

    func testDescriptorFromComponentWithViewWebIsNonSelectable() {
        let c = JasonComponent()
        var href = JasonHref()
        href.url = "https://example.com/page"
        href.view = "web"
        c.href = href
        let d = TabDescriptor(from: c)
        if case .web = d?.target {} else { return XCTFail("expected .web target") }
        XCTAssertFalse(d?.isSelectable ?? true)
        XCTAssertNil(d?.selectableURL)
    }

    /// Action-only tabs are rejected at descriptor construction until the
    /// shell's action dispatcher is plumbed through (see todos/026). Otherwise
    /// the tab would render in the bar and silently no-op on tap.
    func testDescriptorFromComponentWithActionOnlyReturnsNil() {
        let c = JasonComponent()
        let a = JasonAction(); a.type = "$reload"
        c.action = a
        XCTAssertNil(TabDescriptor(from: c))
    }

    func testDescriptorFromComponentWithNoTargetReturnsNil() {
        let c = JasonComponent(); c.text = "nothing"
        XCTAssertNil(TabDescriptor(from: c))
    }

    // MARK: TabShellState selection

    func testSelectChangesSelectedTabID() {
        let a = TabEntry(descriptor: doc("https://a"))
        let b = TabEntry(descriptor: doc("https://b"))
        let shell = TabShellState(tabs: [a, b], initialSelection: a.id)
        shell.select(b.id)
        XCTAssertEqual(shell.selectedTabID, b.id)
    }

    func testSelectIgnoresNonSelectableTarget() {
        let a = TabEntry(descriptor: doc("https://a"))
        let web = TabEntry(descriptor: .init(
            target: .web(URL(string: "https://safari")!),
            label: label()
        ))
        let shell = TabShellState(tabs: [a, web], initialSelection: a.id)
        shell.select(web.id)
        XCTAssertEqual(shell.selectedTabID, a.id, "selecting a web tab must not move selection")
    }

    func testSwitchToURLIfMatchesHits() {
        let a = TabEntry(descriptor: doc("https://a"))
        let b = TabEntry(descriptor: doc("https://b"))
        let shell = TabShellState(tabs: [a, b], initialSelection: a.id)
        XCTAssertTrue(shell.switchToURLIfMatches(URL(string: "https://b")!))
        XCTAssertEqual(shell.selectedTabID, b.id)
    }

    func testSwitchToURLIfMatchesMissesReturnsFalse() {
        let a = TabEntry(descriptor: doc("https://a"))
        let shell = TabShellState(tabs: [a], initialSelection: a.id)
        XCTAssertFalse(shell.switchToURLIfMatches(URL(string: "https://x")!))
        XCTAssertEqual(shell.selectedTabID, a.id)
    }

    // MARK: Coordinator bootstrap promotion

    func testCoordinatorStartsInSingleMode() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://x")!)
        guard case .single(let url, let doc) = c.mode else {
            return XCTFail("expected .single, got \(c.mode)")
        }
        XCTAssertEqual(url.absoluteString, "https://x")
        XCTAssertNil(doc)
    }

    func testCoordinatorStaysInSingleWhenNoTabs() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://x")!)
        c.bootstrapDidLoad(doc: makeDoc(tabs: []))
        guard case .single(_, let preloaded) = c.mode else {
            return XCTFail("expected .single")
        }
        XCTAssertNotNil(preloaded, "loaded doc should be preserved on .single")
    }

    func testCoordinatorPromotesToTabsWhenTabsDeclared() {
        let entry = URL(string: "https://a")!
        let c = JasonetteNavigationCoordinator(entryURL: entry)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://a"),
            tabItem(url: "https://b"),
        ]))
        guard case .tabs(let shell, _, let bootstrapURL) = c.mode else {
            return XCTFail("expected .tabs")
        }
        XCTAssertEqual(shell.tabs.count, 2)
        XCTAssertEqual(bootstrapURL, entry)
        XCTAssertEqual(shell.tabs[0].descriptor.selectableURL, URL(string: "https://a"))
    }

    func testCoordinatorResolvesRelativeTabTargetsAgainstDocumentURL() {
        let entry = URL(string: "https://example.com/app/index.json")!
        let documentURL = URL(string: "https://cdn.example.com/final/index.json")!
        let c = JasonetteNavigationCoordinator(entryURL: entry)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "index.json"),
            tabItem(url: "/settings.json"),
        ]), documentURL: documentURL)
        guard case .tabs(let shell, _, let bootstrapURL) = c.mode else {
            return XCTFail("expected .tabs")
        }
        XCTAssertEqual(bootstrapURL, documentURL)
        XCTAssertEqual(shell.tabs[0].descriptor.selectableURL?.absoluteString, "https://cdn.example.com/final/index.json")
        XCTAssertEqual(shell.tabs[1].descriptor.selectableURL?.absoluteString, "https://cdn.example.com/settings.json")
    }

    func testCoordinatorMatchesOriginalEntryURLAfterDocumentURLRedirect() {
        let entry = URL(string: "https://example.com/app/index.json")!
        let documentURL = URL(string: "https://cdn.example.com/final/index.json")!
        let c = JasonetteNavigationCoordinator(entryURL: entry)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://example.com/app/other.json"),
            tabItem(url: "https://example.com/app/index.json"),
        ]), documentURL: documentURL)
        guard case .tabs(let shell, _, let bootstrapURL) = c.mode else {
            return XCTFail("expected .tabs")
        }
        XCTAssertEqual(shell.selectedTabID, shell.tabs[1].id)
        XCTAssertEqual(bootstrapURL, entry)
    }

    func testCoordinatorPrefersFinalDocumentURLOverOriginalEntryURL() {
        let entry = URL(string: "https://example.com/app/index.json")!
        let documentURL = URL(string: "https://cdn.example.com/final/index.json")!
        let c = JasonetteNavigationCoordinator(entryURL: entry)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://example.com/app/index.json"),
            tabItem(url: "https://cdn.example.com/final/index.json"),
        ]), documentURL: documentURL)
        guard case .tabs(let shell, _, let bootstrapURL) = c.mode else {
            return XCTFail("expected .tabs")
        }
        XCTAssertEqual(shell.selectedTabID, shell.tabs[1].id)
        XCTAssertEqual(bootstrapURL, documentURL)
    }

    func testCoordinatorDedupesRelativeAndAbsoluteEquivalentURLs() {
        let entry = URL(string: "https://example.com/app/index.json")!
        let c = JasonetteNavigationCoordinator(entryURL: entry)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "tabs/home.json"),
            tabItem(url: "https://example.com/app/tabs/home.json"),
        ]))
        guard case .tabs(let shell, _, _) = c.mode else {
            return XCTFail("expected .tabs")
        }
        XCTAssertEqual(shell.tabs.count, 1)
    }

    func testCoordinatorSelectsMatchingTabOnPromotion() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://b")!)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://a"),
            tabItem(url: "https://b"),
        ]))
        guard case .tabs(let shell, _, _) = c.mode else {
            return XCTFail("bootstrap with selectable tabs must promote to .tabs")
        }
        XCTAssertEqual(shell.selectedTabID, shell.tabs[1].id)
    }

    func testCoordinatorDedupesByCanonicalTarget() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://a")!)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://a"),
            tabItem(url: "https://a"),
            tabItem(url: "https://b"),
        ]))
        guard case .tabs(let shell, _, _) = c.mode else {
            return XCTFail("bootstrap with duplicate tabs must still promote")
        }
        XCTAssertEqual(shell.tabs.count, 2, "duplicate URL should be dropped")
    }

    func testCoordinatorBootstrapIsIdempotent() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://a")!)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [tabItem(url: "https://a")]))
        guard case .tabs = c.mode else { return XCTFail("first call should promote") }
        // Second call with different tabs must not demote or re-promote.
        c.bootstrapDidLoad(doc: makeDoc(tabs: [tabItem(url: "https://z")]))
        guard case .tabs(let shell, _, _) = c.mode else {
            return XCTFail("second bootstrap must not demote — mode must stay .tabs")
        }
        XCTAssertEqual(shell.tabs.first?.descriptor.selectableURL, URL(string: "https://a"))
    }

    func testSwitchToURLIfTabInSingleModeReturnsFalse() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://x")!)
        XCTAssertFalse(c.switchToURLIfTab(URL(string: "https://x")!))
    }

    func testSwitchToURLIfTabInTabsModeMatches() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://a")!)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://a"),
            tabItem(url: "https://b"),
        ]))
        XCTAssertTrue(c.switchToURLIfTab(URL(string: "https://b")!))
        guard case .tabs(let shell, _, _) = c.mode else {
            return XCTFail("switchToURLIfTab requires .tabs mode")
        }
        XCTAssertEqual(shell.selectedTabID, shell.tabs[1].id)
    }

    // MARK: Helpers

    private func doc(_ url: String) -> TabDescriptor {
        .init(target: .document(URL(string: url)!), label: label())
    }
    private func label() -> TabLabelSpec {
        .init(text: nil, iconURL: nil, badge: nil, style: nil)
    }
    private func tabItem(url: String) -> JasonComponent {
        let c = JasonComponent(); c.url = url; return c
    }
    private func makeDoc(tabs: [JasonComponent]) -> JasonDocument {
        var body = JasonBody()
        var footer = JasonFooter()
        var t = JasonTabs()
        t.items = tabs
        footer.tabs = t
        body.footer = footer
        let root = JasonRoot(head: nil, body: body)
        return JasonDocument(jason: root)
    }

    // MARK: SceneStorage restore

    func testSelectByCanonicalKeyRestoresMatchingSelectableTab() {
        let a = doc("https://example.com/a.json")
        let b = doc("https://example.com/b.json")
        let tabs = [TabEntry(descriptor: a), TabEntry(descriptor: b)]
        let shell = TabShellState(tabs: tabs, initialSelection: tabs[0].id)

        let restored = shell.selectByCanonicalKey(b.target.canonicalKey)
        XCTAssertTrue(restored)
        XCTAssertEqual(shell.selectedTabID, tabs[1].id)
    }

    func testSelectByCanonicalKeyReturnsFalseForEmptyKey() {
        let a = doc("https://example.com/a.json")
        let tabs = [TabEntry(descriptor: a)]
        let shell = TabShellState(tabs: tabs, initialSelection: tabs[0].id)
        XCTAssertFalse(shell.selectByCanonicalKey(""))
        XCTAssertEqual(shell.selectedTabID, tabs[0].id)
    }

    func testSelectByCanonicalKeyReturnsFalseForStaleKey() {
        let a = doc("https://example.com/a.json")
        let tabs = [TabEntry(descriptor: a)]
        let shell = TabShellState(tabs: tabs, initialSelection: tabs[0].id)
        XCTAssertFalse(shell.selectByCanonicalKey("doc:https://gone.example.com"))
        XCTAssertEqual(shell.selectedTabID, tabs[0].id)
    }

    func testSelectByCanonicalKeyRejectsNonSelectableTab() {
        let a = doc("https://example.com/a.json")
        let webDesc = TabDescriptor(target: .web(URL(string: "https://example.com/w")!), label: label())
        let tabs = [TabEntry(descriptor: a), TabEntry(descriptor: webDesc)]
        let shell = TabShellState(tabs: tabs, initialSelection: tabs[0].id)
        XCTAssertFalse(shell.selectByCanonicalKey(webDesc.target.canonicalKey))
        XCTAssertEqual(shell.selectedTabID, tabs[0].id)
    }

    func testSelectedCanonicalKeyReflectsSelection() {
        let a = doc("https://example.com/a.json")
        let b = doc("https://example.com/b.json")
        let tabs = [TabEntry(descriptor: a), TabEntry(descriptor: b)]
        let shell = TabShellState(tabs: tabs, initialSelection: tabs[0].id)
        XCTAssertEqual(shell.selectedCanonicalKey, a.target.canonicalKey)
        shell.select(tabs[1].id)
        XCTAssertEqual(shell.selectedCanonicalKey, b.target.canonicalKey)
    }

    // MARK: Codex review round 2 regressions

    /// BLOCKER 2: footer with a non-document tab first (e.g. [web, document])
    /// must still boot into a selectable tab when the entry URL matches one.
    /// Otherwise the shell would boot into a `Color.clear` content area.
    func testPromotionInitialSelectionSkipsNonSelectableFirstTab() {
        let entry = URL(string: "https://example.com/doc")!
        let c = JasonetteNavigationCoordinator(entryURL: entry)
        let webItem = JasonComponent()
        var href = JasonHref(); href.url = "https://example.com/w"; href.view = "web"
        webItem.href = href
        c.bootstrapDidLoad(doc: makeDoc(tabs: [webItem, tabItem(url: "https://example.com/doc")]))
        guard case .tabs(let shell, _, _) = c.mode else { return XCTFail("expected .tabs") }
        let selected = shell.tabs.first(where: { $0.id == shell.selectedTabID })
        XCTAssertNotNil(selected)
        XCTAssertTrue(selected?.descriptor.isSelectable == true, "initial selection must be a document tab")
        XCTAssertEqual(selected?.descriptor.selectableURL, entry)
    }

    /// BLOCKER 2: footer with zero document tabs must NOT promote — there's
    /// nothing to display in the content area. Coordinator stays in `.single`
    /// and logs in debug.
    func testPromotionStaysInSingleWhenNoSelectableTabs() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://example.com/entry")!)
        let webItem = JasonComponent()
        var href = JasonHref(); href.url = "https://example.com/w"; href.view = "web"
        webItem.href = href
        c.bootstrapDidLoad(doc: makeDoc(tabs: [webItem]))
        guard case .single = c.mode else {
            return XCTFail("expected .single when no document tab exists")
        }
    }

    /// HIGH 5: a footer item with both a target `url` and an `image` must
    /// use the image as icon, not the target document URL. The old
    /// `imageURL` helper returned `url ?? image`, so an AsyncImage would
    /// have tried to render a JSON document as an image.
    func testDescriptorIconReadsImageFieldNotTargetURL() {
        let c = JasonComponent()
        c.url = "https://example.com/target.json"
        c.image = "https://example.com/icon.png"
        let d = TabDescriptor(from: c)
        XCTAssertEqual(d?.label.iconURL?.absoluteString, "https://example.com/icon.png",
                       "icon must come from `image`, not target URL")
    }

    func testDescriptorResolvesRelativeIconAgainstBaseURL() {
        let c = JasonComponent()
        c.url = "https://example.com/target.json"
        c.image = "icons/home.png"
        let baseURL = URL(string: "https://example.com/app/index.json")!
        let d = TabDescriptor(from: c, baseURL: baseURL)
        XCTAssertEqual(d?.label.iconURL?.absoluteString, "https://example.com/app/icons/home.png")
    }

    /// HIGH 4: document/web tabs must reject non-http(s) schemes. A tab
    /// advertising `file:///etc/passwd` must not be constructed.
    func testDescriptorRejectsDisallowedDocumentScheme() {
        let c = JasonComponent(); c.url = "file:///etc/passwd"
        XCTAssertNil(TabDescriptor(from: c))
    }

    func testDescriptorRejectsDisallowedWebScheme() {
        let c = JasonComponent()
        var href = JasonHref(); href.url = "javascript:alert(1)"; href.view = "web"
        c.href = href
        XCTAssertNil(TabDescriptor(from: c))
    }

    func testDescriptorRejectsDisallowedSchemeAfterBaseResolution() {
        let c = JasonComponent(); c.url = "tabs/home.json"
        let baseURL = URL(string: "file:///tmp/index.json")!
        XCTAssertNil(TabDescriptor(from: c, baseURL: baseURL))
    }

    /// HIGH 4: `view:"app"` has a wider allowlist (mailto/tel/sms) than
    /// document/web. `mailto:` must work, `javascript:` must not.
    func testDescriptorAppAcceptsMailtoRejectsJavascript() {
        let ok = JasonComponent()
        var mailHref = JasonHref(); mailHref.url = "mailto:a@b.c"; mailHref.view = "app"
        ok.href = mailHref
        XCTAssertNotNil(TabDescriptor(from: ok))

        let bad = JasonComponent()
        var jsHref = JasonHref(); jsHref.url = "javascript:alert(1)"; jsHref.view = "app"
        bad.href = jsHref
        XCTAssertNil(TabDescriptor(from: bad))
    }

    // MARK: URL normalization (`.standardized`) across comparison surfaces

    /// Two tab URLs that differ only in `.`/`..` path segments must dedupe
    /// against each other. `.standardized` resolves the segments before the
    /// `canonicalKey` comparison.
    func testCoordinatorDedupesByStandardizedPath() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://a")!)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://host.com/a"),
            tabItem(url: "https://host.com/x/../a"),  // standardizes to /a
        ]))
        guard case .tabs(let shell, _, _) = c.mode else {
            return XCTFail("expected .tabs")
        }
        XCTAssertEqual(shell.tabs.count, 1,
                       "`/x/../a` must dedupe against `/a` via standardization")
    }

    /// The bootstrap-entry-URL → tab match uses `.standardized`, so an entry
    /// URL with `.`/`..` still resolves to its declared tab.
    func testCoordinatorPromotionMatchesStandardizedEntryURL() {
        let entry = URL(string: "https://host.com/x/../home")!
        let c = JasonetteNavigationCoordinator(entryURL: entry)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://host.com/other"),
            tabItem(url: "https://host.com/home"),
        ]))
        guard case .tabs(let shell, _, _) = c.mode else { return XCTFail("expected .tabs") }
        XCTAssertEqual(shell.selectedTabID, shell.tabs[1].id,
                       "entry URL with `.`/`..` must match the standardized tab URL")
    }

    /// `transition: "switch"` must match declared tabs through the same
    /// normalization as dedup and selection.
    func testSwitchToURLIfMatchesHonorsStandardization() {
        let a = TabEntry(descriptor: doc("https://host.com/home"))
        let shell = TabShellState(tabs: [a], initialSelection: a.id)
        XCTAssertTrue(shell.switchToURLIfMatches(URL(string: "https://host.com/x/../home")!),
                      "switch href with `.`/`..` must hit the standardized tab target")
    }

    /// Trailing slashes are NOT absorbed by `.standardized`. Both dedup
    /// and selection still treat `/home` and `/home/` as distinct. This
    /// test locks that behavior in so a future "normalize trailing slashes"
    /// refactor has to update tests deliberately.
    func testTrailingSlashIsNotAbsorbedByStandardization() {
        let c = JasonetteNavigationCoordinator(entryURL: URL(string: "https://a")!)
        c.bootstrapDidLoad(doc: makeDoc(tabs: [
            tabItem(url: "https://host.com/home"),
            tabItem(url: "https://host.com/home/"),
        ]))
        guard case .tabs(let shell, _, _) = c.mode else { return XCTFail("expected .tabs") }
        XCTAssertEqual(shell.tabs.count, 2,
                       "trailing slash divergence is deliberately not normalized")
    }
}
