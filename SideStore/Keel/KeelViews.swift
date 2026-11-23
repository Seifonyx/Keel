//
//  KeelViews.swift
//  Keel (fork of SideStore)
//
//  KEEL: the Auto-update screen (settings, log, Shortcuts tip) and About Keel.
//  Opened from the button Keel adds to My Apps (KeelMyAppsHook).
//

import SwiftUI
import UIKit

// MARK: - My Apps hook

@MainActor
enum KeelMyAppsHook {
    /// Adds the Auto-update button to My Apps. One call from MyAppsViewController.viewDidLoad.
    static func install(on viewController: UIViewController) {
        let button = UIBarButtonItem(image: UIImage(systemName: "clock.arrow.circlepath"),
                                     primaryAction: UIAction { [weak viewController] _ in
                                         guard let viewController else { return }
                                         present(from: viewController)
                                     })
        button.accessibilityLabel = "Auto-update"
        var items = viewController.navigationItem.rightBarButtonItems ?? []
        items.append(button)
        viewController.navigationItem.rightBarButtonItems = items
    }

    static func present(from viewController: UIViewController) {
        let host = UIHostingController(rootView: NavigationView { KeelAutoUpdateView() }.navigationViewStyle(.stack))
        viewController.present(host, animated: true)
    }
}

// MARK: - Model

@MainActor
final class KeelAutoUpdateModel: ObservableObject {
    @Published var settings = KeelAutoUpdater.settings {
        didSet { KeelAutoUpdater.settings = settings }
    }
    @Published private(set) var entries: [KeelLogEntry] = []
    @Published private(set) var isRunning = false
    @Published var lastMessage: String?

    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(forName: KeelAutoUpdater.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() {
        entries = KeelAutoUpdater.log.entries()
        Task { self.isRunning = await KeelAutoUpdater.shared.isRunning }
    }

    func updateNow() {
        isRunning = true
        lastMessage = nil
        Task {
            let result = await KeelAutoUpdater.shared.run(trigger: .manual)
            self.lastMessage = result.summary
            self.reload()
        }
    }

    func clearLog() {
        KeelAutoUpdater.log.clear()
        reload()
    }
}

// MARK: - Auto-update screen

struct KeelAutoUpdateView: View {
    @StateObject private var model = KeelAutoUpdateModel()
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        List {
            Section(footer: Text("Keel checks your sources after each refresh and when you open it, and installs newer builds the same way the Update button does. Refreshing your apps is never held up by this.")) {
                Toggle("Auto-update apps", isOn: $model.settings.isEnabled)
                Toggle("Only on Wi-Fi", isOn: $model.settings.wifiOnly)
                Toggle("Also update Keel", isOn: $model.settings.includesKeelItself)
            }

            Section(footer: Text(model.lastMessage ?? "")) {
                SwiftUI.Button {
                    model.updateNow()
                } label: {
                    HStack {
                        Text("Update apps now")
                        Spacer()
                        if model.isRunning { ProgressView() }
                    }
                }
                .disabled(model.isRunning)
            }

            Section(header: Text("Recent")) {
                if model.entries.isEmpty {
                    Text("Nothing yet.").foregroundColor(.secondary)
                } else {
                    ForEach(model.entries) { entry in
                        KeelLogRow(entry: entry)
                    }
                }
            }

            Section(header: Text("Update every night"), footer: Text("iOS gives apps little background time, so a Shortcuts automation is the most reliable way to keep apps current. In Shortcuts, go to Automation, tap +, choose Time of Day (or Charger), pick Run Immediately, then add the Keel action “Update Apps”.")) {
                Link("Open Shortcuts", destination: URL(string: "shortcuts://")!)
            }

            Section {
                NavigationLink("About Keel") { KeelAboutView() }
                if !model.entries.isEmpty {
                    SwiftUI.Button("Clear log", role: .destructive) { model.clearLog() }
                }
            }
        }
        .navigationTitle("Auto-update")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                SwiftUI.Button("Done") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }
}

private struct KeelLogRow: View {
    let entry: KeelLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(entry.summary)
            }
            if entry.outcome == .failed, let message = entry.message {
                Text(message).font(.footnote).foregroundColor(.secondary)
            }
            Text("\(entry.date.formatted(date: .abbreviated, time: .shortened)) · \(entry.trigger.label)")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch entry.outcome {
        case .updated: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .skipped: return "pause.circle"
        case .nothingToDo: return "circle"
        }
    }

    private var color: Color {
        switch entry.outcome {
        case .updated: return .green
        case .failed: return .orange
        case .skipped, .nothingToDo: return .secondary
        }
    }
}

// MARK: - About

struct KeelAboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keel").font(.title2.bold())
                    Text(Bundle.Info.activeBundleVersion).foregroundColor(.secondary)
                    Text("Keel sideloads and refreshes your apps, and installs their updates by itself.")
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("Built on SideStore"), footer: Text("Keel is a fork of SideStore, which began as a fork of AltStore. Almost all of Keel is their work. Please don't send Keel problems to the SideStore or AltStore teams.")) {
                Link("SideStore", destination: KeelBrand.upstreamURL)
                Link("AltStore by Riley Testut", destination: KeelBrand.altStoreURL)
            }

            Section(header: Text("Licence"), footer: Text("Keel is free software under the GNU Affero General Public License v3.0, the same licence as SideStore. Its source code is available at the link above.")) {
                Link("Keel source code", destination: KeelBrand.repositoryURL)
                Link("Licence (AGPL-3.0)", destination: KeelBrand.licenseURL)
            }
        }
        .navigationTitle("About Keel")
    }
}
