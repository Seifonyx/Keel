//
//  KeelAutoUpdater.swift
//  Keel (fork of SideStore)
//
//  KEEL: installs app updates from sources by itself.
//
//  Safety rules (see README "How auto-update stays safe"):
//  - It never runs inside the refresh step. It runs after refresh finished
//    (background), or on its own (app opened, Shortcut, keel://update).
//  - It uses the same AppManager.update() path as the Update button, one app
//    at a time. The new build is downloaded and signed before iOS installs it,
//    and iOS only replaces the app once the install succeeds, so a failed
//    update leaves the installed version working.
//  - Without a screen to show (background, Shortcut), anything that needs a
//    decision from you (for example new permissions) fails and is logged
//    instead of guessing. Use the Update button for those.
//  - Keel itself is skipped unless you turn it on, so a bad Keel build can't
//    replace the one that keeps your apps refreshed.
//  needs proper testing on a device.
//

import CoreData
import Network
import UIKit
import UserNotifications

actor KeelAutoUpdater {
    static let shared = KeelAutoUpdater()

    static let didChangeNotification = Notification.Name("KeelAutoUpdaterDidChange")

    static let log: KeelLogStore = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return KeelLogStore(fileURL: base.appendingPathComponent("Keel", isDirectory: true).appendingPathComponent("auto-update-log.json"))
    }()

    static var settings: KeelAutoUpdateSettings {
        get { KeelAutoUpdateSettings.load(from: .standard) }
        set { newValue.save(to: .standard) }
    }

    private(set) var isRunning = false
    private var lastAppOpenedRun: Date?

    /// Minimum gap between runs started by simply opening Keel.
    private let appOpenedThrottle: TimeInterval = 10 * 60

    struct RunResult: Sendable {
        var updated: [String] = []
        var failed: [String] = []
        var blockedReason: String?

        var summary: String {
            if let blockedReason { return blockedReason }
            if updated.isEmpty && failed.isEmpty { return "All apps are up to date." }
            var parts: [String] = []
            if !updated.isEmpty { parts.append("Updated \(updated.joined(separator: ", ")).") }
            if !failed.isEmpty { parts.append("Couldn't update \(failed.joined(separator: ", ")).") }
            return parts.joined(separator: " ")
        }
    }

    /// Checks every installed app's source and installs newer builds.
    ///
    /// - Parameters:
    ///   - fetchSources: false when the caller just fetched sources (background refresh does).
    ///   - deadline: no new update is started after this time (one already in progress finishes).
    @discardableResult
    func run(trigger: KeelTrigger, fetchSources: Bool = true, deadline: Date? = nil) async -> RunResult {
        var result = RunResult()

        if isRunning {
            result.blockedReason = "An update check is already running."
            return result
        }
        if trigger == .appOpened, let last = lastAppOpenedRun, Date().timeIntervalSince(last) < appOpenedThrottle {
            result.blockedReason = "Checked a few minutes ago."
            return result
        }

        let settings = Self.settings
        // Shortcut, link and "Update now" are explicit requests, so they run even when the switch is off.
        let explicit = trigger == .shortcut || trigger == .link || trigger == .manual
        let network = await Self.currentNetwork()
        if let reason = KeelAutoUpdatePolicy.blockReason(settings: settings, network: network, ignoreSwitch: explicit) {
            result.blockedReason = reason
            if settings.isEnabled || explicit {
                Self.log.append([KeelLogEntry(trigger: trigger, outcome: .skipped, message: reason)])
                await self.postChange()
            }
            return result
        }

        isRunning = true
        if trigger == .appOpened { lastAppOpenedRun = Date() }
        await self.postChange()
        defer { isRunning = false }

        var entries: [KeelLogEntry] = []
        do {
            // Let Keel finish starting up (database migration, then start) instead of racing it.
            guard await Self.waitUntil(timeout: 60, { DatabaseManager.shared.isStarted }) else {
                throw KeelAutoUpdateError.notReady("Keel was still starting up.")
            }

            if trigger == .background || trigger == .shortcut, UserDefaults.standard.enableEMPforWireguard {
                // Same as BackgroundRefreshAppsOperation: make sure the loopback proxy is up.
                try? await startEMProxy()
            }

            // Installing needs the connection to the phone (VPN + pairing file). Without it every
            // app would fail one by one, so stop early with one clear line instead.
            var connectionError: Error?
            let connected = await Self.waitUntil(timeout: 20) {
                switch await isMinimuxerReady() {
                case .success: return true
                case .failure(let error): connectionError = error; return false
                }
            }
            guard connected else {
                let detail = connectionError.map { " (\(Self.describe($0)))" } ?? ""
                throw KeelAutoUpdateError.notReady("Keel isn't connected to your phone yet. Check the VPN is on.\(detail)")
            }

            if fetchSources {
                await Self.fetchSourcesIgnoringErrors()
            }

            let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            let plan: [(candidate: KeelUpdateCandidate, app: InstalledApp)] = await context.perform {
                InstalledApp.fetchActiveApps(in: context).compactMap { app -> (candidate: KeelUpdateCandidate, app: InstalledApp)? in
                    guard let candidate = app.keelCandidate else { return nil }
                    return (candidate: candidate, app: app)
                }
            }

            let toUpdate = KeelAutoUpdatePolicy.ordered(plan.map(\.candidate))
                .filter { KeelAutoUpdatePolicy.decide($0, settings: settings) == .update }

            for candidate in toUpdate {
                if let deadline, Date() >= deadline {
                    entries.append(KeelLogEntry(trigger: trigger, outcome: .skipped, appName: candidate.name,
                                                bundleIdentifier: candidate.bundleIdentifier,
                                                message: "Ran out of background time before \(candidate.name). It will be tried next time."))
                    break
                }
                guard let app = plan.first(where: { $0.candidate.bundleIdentifier == candidate.bundleIdentifier })?.app else { continue }

                // Leave apps alone while you are already refreshing or updating them.
                let isBusy = await context.perform { AppManager.shared.refreshProgress(for: app) != nil }
                if isBusy {
                    entries.append(KeelLogEntry(trigger: trigger, outcome: .skipped, appName: candidate.name,
                                                bundleIdentifier: candidate.bundleIdentifier,
                                                message: "\(candidate.name) was busy, tried again next time."))
                    continue
                }

                let outcome = await Self.update(app, trigger: trigger)
                switch outcome {
                case .success:
                    result.updated.append(candidate.name)
                    entries.append(KeelLogEntry(trigger: trigger, outcome: .updated, appName: candidate.name,
                                                bundleIdentifier: candidate.bundleIdentifier,
                                                fromVersion: candidate.installedVersion, toVersion: candidate.latestVersion))
                case .failure(let error):
                    result.failed.append(candidate.name)
                    entries.append(KeelLogEntry(trigger: trigger, outcome: .failed, appName: candidate.name,
                                                bundleIdentifier: candidate.bundleIdentifier,
                                                fromVersion: candidate.installedVersion, toVersion: candidate.latestVersion,
                                                message: Self.describe(error)))
                }
            }

            if toUpdate.isEmpty {
                entries.append(KeelLogEntry(trigger: trigger, outcome: .nothingToDo))
            }
        } catch let error as KeelAutoUpdateError {
            // Nothing was touched; it will try again next time.
            result.blockedReason = error.localizedDescription
            entries.append(KeelLogEntry(trigger: trigger, outcome: .skipped, message: error.localizedDescription))
        } catch {
            entries.append(KeelLogEntry(trigger: trigger, outcome: .failed, message: Self.describe(error)))
        }

        Self.log.append(entries)
        await self.postChange()
        await Self.notify(result, trigger: trigger)
        return result
    }

    // MARK: - Helpers

    /// Polls `condition` every half second until it is true or `timeout` seconds pass.
    private static func waitUntil(timeout: TimeInterval, _ condition: () async -> Bool) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while true {
            if await condition() { return true }
            if Date() >= end { return false }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func postChange() async {
        await MainActor.run {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    private static func fetchSourcesIgnoringErrors() async {
        do {
            let (_, context) = try await AppManager.shared.fetchSources()
            try await context.performAsync { try context.save() }
        } catch let error as AppManager.FetchSourcesError {
            // Some sources failed; keep what did load, as My Apps does.
            try? await error.managedObjectContext?.performAsync { try error.managedObjectContext?.save() }
        } catch {
            debugLog("[Keel] Fetching sources failed, using what is cached: \(error)")
        }
    }

    /// Same call the Update button makes. A screen is only passed when you asked
    /// for the update yourself, so prompts can appear then and never in the background.
    private static func update(_ app: InstalledApp, trigger: KeelTrigger) async -> Result<Void, Error> {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let presenter: UIViewController? = (trigger == .manual || trigger == .link)
                    ? UIApplication.shared.topViewController() : nil
                AppManager.shared.update(app, presentingViewController: presenter) { result in
                    continuation.resume(returning: result.map { _ in () })
                }
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if let reason = nsError.localizedFailureReason, !reason.isEmpty {
            return "\(nsError.localizedDescription) \(reason)"
        }
        return nsError.localizedDescription
    }

    static func currentNetwork() async -> KeelNetworkState {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let once = KeelOnce()
            monitor.pathUpdateHandler = { path in
                guard once.claim() else { return }
                monitor.cancel()
                continuation.resume(returning: KeelNetworkState(
                    isConnected: path.status == .satisfied,
                    usesCellular: path.usesInterfaceType(.cellular),
                    isExpensive: path.isExpensive))
            }
            monitor.start(queue: DispatchQueue(label: "keel.network"))
        }
    }

    /// Tells you what happened when Keel worked without you watching.
    private static func notify(_ result: RunResult, trigger: KeelTrigger) async {
        guard trigger == .background || trigger == .shortcut else { return }
        guard !result.updated.isEmpty || !result.failed.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = result.failed.isEmpty ? "Apps updated" : "Some updates didn't install"
        content.body = result.summary
        let request = UNNotificationRequest(identifier: "keel-auto-update-\(UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// Resumes a continuation once, even if NWPathMonitor calls back again.
private final class KeelOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

enum KeelAutoUpdateError: LocalizedError {
    case notReady(String)

    var errorDescription: String? {
        switch self {
        case .notReady(let message): return message
        }
    }
}
