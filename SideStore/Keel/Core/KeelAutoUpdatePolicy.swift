//
//  KeelAutoUpdatePolicy.swift
//  Keel (fork of SideStore)
//
//  KEEL: Foundation-only rules for automatic updates. Kept free of UIKit,
//  CoreData and SideStore types so it can be unit tested on its own
//  (see Keel/Tests). Licensed under the AGPL-3.0 like the rest of SideStore.
//

import Foundation

/// What Keel knows about one installed app and its newest version in a source.
public struct KeelUpdateCandidate: Equatable, Sendable {
    public var bundleIdentifier: String
    public var name: String

    public var installedVersion: String
    /// The source's buildVersion recorded when the app was installed (InstalledApp.storeBuildVersion).
    public var installedStoreBuild: String?
    /// CFBundleVersion of the installed app (InstalledApp.buildVersion).
    public var installedBundleBuild: String?

    public var latestVersion: String
    public var latestBuild: String?
    /// False when the source says the newest version needs a newer iOS.
    public var latestIsSupported: Bool
    /// SideStore's own "Update" badge logic (InstalledApp.hasUpdate).
    public var upstreamSaysUpdate: Bool

    public var isActive: Bool
    public var isKeelItself: Bool

    public init(bundleIdentifier: String, name: String,
                installedVersion: String, installedStoreBuild: String?, installedBundleBuild: String?,
                latestVersion: String, latestBuild: String?, latestIsSupported: Bool,
                upstreamSaysUpdate: Bool, isActive: Bool, isKeelItself: Bool) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.installedVersion = installedVersion
        self.installedStoreBuild = installedStoreBuild
        self.installedBundleBuild = installedBundleBuild
        self.latestVersion = latestVersion
        self.latestBuild = latestBuild
        self.latestIsSupported = latestIsSupported
        self.upstreamSaysUpdate = upstreamSaysUpdate
        self.isActive = isActive
        self.isKeelItself = isKeelItself
    }
}

public enum KeelUpdateDecision: Equatable, Sendable {
    case update
    case skip(KeelSkipReason)
}

public enum KeelSkipReason: String, Codable, Equatable, Sendable {
    case upToDate
    case notActive
    case needsNewerIOS
    case keelItself
}

public struct KeelAutoUpdateSettings: Equatable, Sendable {
    public var isEnabled: Bool
    public var wifiOnly: Bool
    public var includesKeelItself: Bool

    public init(isEnabled: Bool = true, wifiOnly: Bool = false, includesKeelItself: Bool = false) {
        self.isEnabled = isEnabled
        self.wifiOnly = wifiOnly
        self.includesKeelItself = includesKeelItself
    }

    public static let enabledKey = "keel.autoUpdate.enabled"
    public static let wifiOnlyKey = "keel.autoUpdate.wifiOnly"
    public static let includesKeelKey = "keel.autoUpdate.includesKeel"

    /// Defaults: auto-update on, Wi-Fi only off, Keel itself off.
    public static func load(from defaults: UserDefaults) -> KeelAutoUpdateSettings {
        defaults.register(defaults: [enabledKey: true, wifiOnlyKey: false, includesKeelKey: false])
        return KeelAutoUpdateSettings(isEnabled: defaults.bool(forKey: enabledKey),
                                      wifiOnly: defaults.bool(forKey: wifiOnlyKey),
                                      includesKeelItself: defaults.bool(forKey: includesKeelKey))
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(isEnabled, forKey: Self.enabledKey)
        defaults.set(wifiOnly, forKey: Self.wifiOnlyKey)
        defaults.set(includesKeelItself, forKey: Self.includesKeelKey)
    }
}

/// How the device is connected right now (filled in from NWPath on the phone).
public struct KeelNetworkState: Equatable, Sendable {
    public var isConnected: Bool
    public var usesCellular: Bool
    /// NWPath.isExpensive: cellular or a personal hotspot.
    public var isExpensive: Bool

    public init(isConnected: Bool, usesCellular: Bool, isExpensive: Bool) {
        self.isConnected = isConnected
        self.usesCellular = usesCellular
        self.isExpensive = isExpensive
    }
}

public enum KeelAutoUpdatePolicy {

    /// Whether a run may start at all. Returns nil when it may, or the reason it may not.
    public static func blockReason(settings: KeelAutoUpdateSettings,
                                   network: KeelNetworkState,
                                   ignoreSwitch: Bool) -> String? {
        if !settings.isEnabled && !ignoreSwitch {
            return "Auto-update is off."
        }
        if !network.isConnected {
            return "No internet connection."
        }
        if settings.wifiOnly && (network.usesCellular || network.isExpensive) {
            return "Waiting for Wi-Fi."
        }
        return nil
    }

    public static func decide(_ c: KeelUpdateCandidate, settings: KeelAutoUpdateSettings) -> KeelUpdateDecision {
        guard c.isActive else { return .skip(.notActive) }
        guard c.latestIsSupported else { return .skip(.needsNewerIOS) }

        let newer = isNewer(c)
        guard newer else { return .skip(.upToDate) }

        if c.isKeelItself && !settings.includesKeelItself {
            return .skip(.keelItself)
        }
        return .update
    }

    /// True when the source's newest version is newer than what is installed.
    ///
    /// Sources like Setpoint's bump `buildVersion` (a CI run number) on every
    /// release, so when both builds are whole numbers they decide. Otherwise
    /// Keel trusts SideStore's own Update-badge logic.
    public static func isNewer(_ c: KeelUpdateCandidate) -> Bool {
        let installedBuild = Int(trimmed(c.installedStoreBuild) ?? "") ?? Int(trimmed(c.installedBundleBuild) ?? "")
        if let latest = Int(trimmed(c.latestBuild) ?? ""), let installed = installedBuild {
            if latest != installed { return latest > installed }
            // Same build number: only newer if the version string moved forward.
            return compareVersions(c.latestVersion, c.installedVersion) == .orderedDescending
        }
        return c.upstreamSaysUpdate
    }

    /// Numeric, dot-separated comparison ("0.1.10" > "0.1.9"). Non-numeric parts compare as text.
    public static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let pa = a.split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "+" }).map(String.init)
        let pb = b.split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "+" }).map(String.init)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : "0"
            let y = i < pb.count ? pb[i] : "0"
            if let xi = Int(x), let yi = Int(y) {
                if xi != yi { return xi < yi ? .orderedAscending : .orderedDescending }
            } else if x != y {
                return x < y ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    /// Order the apps to update: everything else first, Keel itself last
    /// (installing Keel closes it, which would stop the remaining updates).
    public static func ordered(_ candidates: [KeelUpdateCandidate]) -> [KeelUpdateCandidate] {
        candidates.filter { !$0.isKeelItself } + candidates.filter { $0.isKeelItself }
    }

    private static func trimmed(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }
}

// MARK: - Log

public enum KeelTrigger: String, Codable, Sendable {
    case background
    case appOpened
    case shortcut
    case link
    case manual

    public var label: String {
        switch self {
        case .background: return "Background refresh"
        case .appOpened: return "App opened"
        case .shortcut: return "Shortcut"
        case .link: return "Update link"
        case .manual: return "Update now"
        }
    }
}

public struct KeelLogEntry: Codable, Equatable, Identifiable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case updated
        case failed
        case skipped
        case nothingToDo
    }

    public var id: UUID
    public var date: Date
    public var trigger: KeelTrigger
    public var outcome: Outcome
    public var appName: String?
    public var bundleIdentifier: String?
    public var fromVersion: String?
    public var toVersion: String?
    public var message: String?

    public init(id: UUID = UUID(), date: Date = Date(), trigger: KeelTrigger, outcome: Outcome,
                appName: String? = nil, bundleIdentifier: String? = nil,
                fromVersion: String? = nil, toVersion: String? = nil, message: String? = nil) {
        self.id = id
        self.date = date
        self.trigger = trigger
        self.outcome = outcome
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.message = message
    }

    /// One plain line for the list, e.g. "Updated Setpoint 0.1.187 → 0.1.188".
    public var summary: String {
        let name = appName ?? "App"
        switch outcome {
        case .updated:
            if let from = fromVersion, let to = toVersion { return "Updated \(name) \(from) → \(to)" }
            return "Updated \(name)"
        case .failed:
            return "Couldn't update \(name)"
        case .skipped:
            return message ?? "Skipped"
        case .nothingToDo:
            return "All apps up to date"
        }
    }
}

/// A small JSON file holding the most recent log entries (newest first).
public final class KeelLogStore: @unchecked Sendable {
    public let fileURL: URL
    public let limit: Int
    private let lock = NSLock()

    public init(fileURL: URL, limit: Int = 100) {
        self.fileURL = fileURL
        self.limit = limit
    }

    public func entries() -> [KeelLogEntry] {
        lock.lock(); defer { lock.unlock() }
        return readUnlocked()
    }

    public func append(_ newEntries: [KeelLogEntry]) {
        guard !newEntries.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        var all = newEntries.sorted { $0.date > $1.date } + readUnlocked()
        // Collapse repeated "nothing to do"/"skipped" lines so real updates stay visible.
        var seenQuiet = false
        all = all.filter { entry in
            guard entry.outcome == .nothingToDo || entry.outcome == .skipped else { return true }
            defer { seenQuiet = true }
            return !seenQuiet
        }
        if all.count > limit { all = Array(all.prefix(limit)) }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(all).write(to: fileURL, options: .atomic)
        } catch {
            // Logging must never break an update; ignore write failures.
        }
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func readUnlocked() -> [KeelLogEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([KeelLogEntry].self, from: data)) ?? []
    }
}
