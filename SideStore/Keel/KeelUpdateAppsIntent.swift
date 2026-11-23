//
//  KeelUpdateAppsIntent.swift
//  Keel (fork of SideStore)
//
//  KEEL: "Update apps" action for Shortcuts. Run it from a personal automation
//  (for example every night, or when the phone starts charging) so updates
//  don't depend on iOS handing out background time.
//

import AppIntents
import Foundation

@available(iOS 16, *)
struct KeelUpdateAppsIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Apps"
    static var description = IntentDescription("Checks your sources and installs newer builds of your apps with Keel.")

    /// Installing needs Keel's connection to the phone, which is most reliable
    /// with Keel open, so the Shortcut opens Keel while it works.
    static var openAppWhenRun = true

    static var parameterSummary: some ParameterSummary {
        Summary("Update apps with Keel")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // The run is its own task so it keeps going if Shortcuts stops waiting.
        let run = Task { await KeelAutoUpdater.shared.run(trigger: .shortcut) }
        let stillRunning = "Keel is still installing updates. The results will be in My Apps."
        let summary: String = await withCheckedContinuation { continuation in
            let once = KeelIntentOnce()
            Task {
                let text = await run.value.summary
                if once.claim() { continuation.resume(returning: text) }
            }
            Task {
                try? await Task.sleep(nanoseconds: 25 * 1_000_000_000)
                if once.claim() { continuation.resume(returning: stillRunning) }
            }
        }
        return .result(dialog: "\(summary)")
    }
}

private final class KeelIntentOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
