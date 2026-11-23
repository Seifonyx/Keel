//
//  InstalledApp+Keel.swift
//  Keel (fork of SideStore)
//
//  KEEL: what Keel's screens and auto-updater need to know about an installed app.
//  Call on the app's managed object context queue.
//

import Foundation

extension InstalledApp {
    var keelIsKeel: Bool { bundleIdentifier == StoreApp.altstoreAppID }

    /// Newest version in its source as an update candidate; nil when it has no source.
    var keelCandidate: KeelUpdateCandidate? {
        guard let latest = storeApp?.latestSupportedVersion else { return nil }
        return KeelUpdateCandidate(
            bundleIdentifier: bundleIdentifier,
            name: name,
            installedVersion: version,
            installedStoreBuild: storeBuildVersion,
            installedBundleBuild: buildVersion,
            latestVersion: latest.version,
            latestBuild: latest.buildVersion,
            latestIsSupported: latest.isSupported,
            upstreamSaysUpdate: hasUpdate,
            isActive: isActive,
            isKeelItself: keelIsKeel)
    }

    /// The version that "Update" would install, when it is newer than the installed one.
    var keelAvailableUpdate: String? {
        guard let c = keelCandidate, c.latestIsSupported, KeelAutoUpdatePolicy.isNewer(c) else { return nil }
        return c.latestVersion
    }

    /// Whole days until the app expires (never negative) and the length of its signing period.
    var keelDaysLeft: (left: Int, total: Int) {
        let now = Date()
        let left = max(0, Int(ceil(expirationDate.timeIntervalSince(now) / 86_400)))
        let total = max(1, Int((expirationDate.timeIntervalSince(refreshedDate) / 86_400).rounded()))
        return (min(left, total), total)
    }
}
