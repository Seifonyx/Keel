import XCTest
@testable import KeelCore

final class KeelAutoUpdatePolicyTests: XCTestCase {

    private func candidate(installedVersion: String = "0.1.187", installedStoreBuild: String? = "187",
                           installedBundleBuild: String? = "187",
                           latestVersion: String = "0.1.188", latestBuild: String? = "188",
                           supported: Bool = true, upstream: Bool = false,
                           active: Bool = true, keel: Bool = false) -> KeelUpdateCandidate {
        KeelUpdateCandidate(bundleIdentifier: keel ? "app.seifonyx.keel" : "app.setpoint.ios",
                            name: keel ? "Keel" : "Setpoint",
                            installedVersion: installedVersion, installedStoreBuild: installedStoreBuild,
                            installedBundleBuild: installedBundleBuild,
                            latestVersion: latestVersion, latestBuild: latestBuild,
                            latestIsSupported: supported, upstreamSaysUpdate: upstream,
                            isActive: active, isKeelItself: keel)
    }

    private let defaults = KeelAutoUpdateSettings()

    // MARK: Decisions

    func testHigherBuildUpdates() {
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(candidate(), settings: defaults), .update)
    }

    func testSameBuildIsUpToDate() {
        let c = candidate(latestVersion: "0.1.187", latestBuild: "187")
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(c, settings: defaults), .skip(.upToDate))
    }

    func testLowerBuildNeverDowngrades() {
        let c = candidate(latestVersion: "0.1.186", latestBuild: "186", upstream: true)
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(c, settings: defaults), .skip(.upToDate))
    }

    func testBuildsCompareAsNumbersNotText() {
        let c = candidate(installedVersion: "0.1.99", installedStoreBuild: "99", latestVersion: "0.1.100", latestBuild: "100")
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(c, settings: defaults), .update)
    }

    func testFallsBackToBundleBuildWhenStoreBuildMissing() {
        let c = candidate(installedStoreBuild: nil, installedBundleBuild: "187")
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(c, settings: defaults), .update)
    }

    func testSameBuildButNewerVersionUpdates() {
        let c = candidate(installedVersion: "1.0.0", installedStoreBuild: "5", latestVersion: "1.0.1", latestBuild: "5")
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(c, settings: defaults), .update)
    }

    func testNonNumericBuildsUseUpstreamLogic() {
        let yes = candidate(installedStoreBuild: "abc", installedBundleBuild: "abc", latestBuild: "def", upstream: true)
        let no = candidate(installedStoreBuild: "abc", installedBundleBuild: "abc", latestBuild: "def", upstream: false)
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(yes, settings: defaults), .update)
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(no, settings: defaults), .skip(.upToDate))
    }

    func testMissingLatestBuildUsesUpstreamLogic() {
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(candidate(latestBuild: nil, upstream: true), settings: defaults), .update)
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(candidate(latestBuild: "  ", upstream: false), settings: defaults), .skip(.upToDate))
    }

    func testInactiveAppsAreLeftAlone() {
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(candidate(active: false), settings: defaults), .skip(.notActive))
    }

    func testUnsupportedIOSIsSkipped() {
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(candidate(supported: false), settings: defaults), .skip(.needsNewerIOS))
    }

    func testKeelItselfIsSkippedByDefault() {
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(candidate(keel: true), settings: defaults), .skip(.keelItself))
        var settings = defaults
        settings.includesKeelItself = true
        XCTAssertEqual(KeelAutoUpdatePolicy.decide(candidate(keel: true), settings: settings), .update)
    }

    func testKeelIsInstalledLast() {
        let ordered = KeelAutoUpdatePolicy.ordered([candidate(keel: true), candidate(), candidate(keel: true)])
        XCTAssertEqual(ordered.map(\.isKeelItself), [false, true, true])
    }

    // MARK: Versions

    func testVersionComparison() {
        XCTAssertEqual(KeelAutoUpdatePolicy.compareVersions("0.1.10", "0.1.9"), .orderedDescending)
        XCTAssertEqual(KeelAutoUpdatePolicy.compareVersions("1.0", "1.0.0"), .orderedSame)
        XCTAssertEqual(KeelAutoUpdatePolicy.compareVersions("1.2", "1.10"), .orderedAscending)
    }

    // MARK: When a run may start

    private let wifi = KeelNetworkState(isConnected: true, usesCellular: false, isExpensive: false)
    private let cellular = KeelNetworkState(isConnected: true, usesCellular: true, isExpensive: true)
    private let hotspot = KeelNetworkState(isConnected: true, usesCellular: false, isExpensive: true)
    private let offline = KeelNetworkState(isConnected: false, usesCellular: false, isExpensive: false)

    func testDefaultsAllowCellular() {
        XCTAssertNil(KeelAutoUpdatePolicy.blockReason(settings: defaults, network: cellular, ignoreSwitch: false))
    }

    func testWifiOnlyBlocksCellularAndHotspot() {
        let settings = KeelAutoUpdateSettings(isEnabled: true, wifiOnly: true)
        XCTAssertNil(KeelAutoUpdatePolicy.blockReason(settings: settings, network: wifi, ignoreSwitch: false))
        XCTAssertNotNil(KeelAutoUpdatePolicy.blockReason(settings: settings, network: cellular, ignoreSwitch: false))
        XCTAssertNotNil(KeelAutoUpdatePolicy.blockReason(settings: settings, network: hotspot, ignoreSwitch: false))
        // Wi-Fi only applies to explicit runs too.
        XCTAssertNotNil(KeelAutoUpdatePolicy.blockReason(settings: settings, network: cellular, ignoreSwitch: true))
    }

    func testOffSwitchBlocksAutomaticRunsOnly() {
        let off = KeelAutoUpdateSettings(isEnabled: false)
        XCTAssertNotNil(KeelAutoUpdatePolicy.blockReason(settings: off, network: wifi, ignoreSwitch: false))
        XCTAssertNil(KeelAutoUpdatePolicy.blockReason(settings: off, network: wifi, ignoreSwitch: true))
    }

    func testOfflineBlocks() {
        XCTAssertNotNil(KeelAutoUpdatePolicy.blockReason(settings: defaults, network: offline, ignoreSwitch: true))
    }

    // MARK: Settings

    func testSettingsDefaultsAndRoundTrip() throws {
        let suite = "keel.tests.\(UUID().uuidString)"
        let ud = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { ud.removePersistentDomain(forName: suite) }

        XCTAssertEqual(KeelAutoUpdateSettings.load(from: ud), KeelAutoUpdateSettings(isEnabled: true, wifiOnly: false, includesKeelItself: false))
        KeelAutoUpdateSettings(isEnabled: false, wifiOnly: true, includesKeelItself: true).save(to: ud)
        XCTAssertEqual(KeelAutoUpdateSettings.load(from: ud), KeelAutoUpdateSettings(isEnabled: false, wifiOnly: true, includesKeelItself: true))
    }

    // MARK: Log

    func testLogKeepsUpdatesAndCollapsesQuietLines() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = KeelLogStore(fileURL: dir.appendingPathComponent("log.json"), limit: 5)

        let t0 = Date(timeIntervalSince1970: 1_000)
        store.append([KeelLogEntry(date: t0, trigger: .background, outcome: .updated, appName: "Setpoint", fromVersion: "0.1.1", toVersion: "0.1.2")])
        store.append([KeelLogEntry(date: t0.addingTimeInterval(10), trigger: .appOpened, outcome: .nothingToDo)])
        store.append([KeelLogEntry(date: t0.addingTimeInterval(20), trigger: .appOpened, outcome: .nothingToDo)])

        let entries = store.entries()
        XCTAssertEqual(entries.map(\.outcome), [.nothingToDo, .updated])
        XCTAssertEqual(entries.last?.summary, "Updated Setpoint 0.1.1 → 0.1.2")
    }

    func testLogLimit() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = KeelLogStore(fileURL: dir.appendingPathComponent("log.json"), limit: 3)
        for i in 0..<10 {
            store.append([KeelLogEntry(date: Date(timeIntervalSince1970: Double(i)), trigger: .manual, outcome: .updated, appName: "App \(i)")])
        }
        XCTAssertEqual(store.entries().map(\.appName), ["App 9", "App 8", "App 7"])
    }

    func testCorruptLogReadsAsEmpty() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("log.json")
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(KeelLogStore(fileURL: url).entries(), [])
    }
}
