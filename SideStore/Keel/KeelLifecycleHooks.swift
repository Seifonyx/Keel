//
//  KeelLifecycleHooks.swift
//  Keel (fork of SideStore)
//
//  KEEL: the two places upstream code calls into Keel's auto-updater.
//

import UIKit

enum KeelLifecycleHooks {

    /// Called by AppDelegate once background refresh has completely finished.
    /// Refresh's own result is already final; this only decides when to tell iOS the
    /// background task is over, and it always does so within `hardLimit` seconds.
    static func runAfterBackgroundRefresh(then finish: @escaping () -> Void) {
        // Respect the Background Refresh switch: no background work when it's off.
        guard UserDefaults.standard.isBackgroundRefreshEnabled else { return finish() }

        let once = KeelFinishOnce(finish)
        let startBy: TimeInterval = 120   // don't start a new app's update after this
        let hardLimit: TimeInterval = 240 // finish the background task no matter what

        Task.detached(priority: .utility) {
            // Sources are fetched again: upstream fetches them alongside refresh, not before it.
            await KeelAutoUpdater.shared.run(trigger: .background,
                                             deadline: Date().addingTimeInterval(startBy))
            once.call()
        }
        Task.detached {
            try? await Task.sleep(nanoseconds: UInt64(hardLimit * 1_000_000_000))
            once.call()
        }
    }

    /// Called by SceneDelegate whenever Keel comes to the front (throttled inside the updater).
    static func appBecameActive() {
        Task.detached(priority: .utility) {
            // Give a keel://update link or the Shortcut action a moment to start their own run first.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await KeelAutoUpdater.shared.run(trigger: .appOpened)
        }
    }
}

private final class KeelFinishOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var action: (() -> Void)?

    init(_ action: @escaping () -> Void) { self.action = action }

    func call() {
        lock.lock()
        let action = self.action
        self.action = nil
        lock.unlock()
        action?()
    }
}
