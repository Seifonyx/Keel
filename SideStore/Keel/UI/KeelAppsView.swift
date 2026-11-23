//
//  KeelAppsView.swift
//  Keel (fork of SideStore)
//
//  KEEL: the Apps tab. One card per app with its days-left dial, whether it is
//  up to date, and an Update button when a newer build is ready; then Recent.
//  SideStore's full My Apps (install from file, App IDs, inactive apps…) is one
//  tap away in the menu.
//

import CoreData
import SwiftUI
import UIKit

@MainActor
final class KeelAppsModel: ObservableObject {
    @Published var isConnected: Bool?
    @Published var recent: [KeelLogEntry] = []
    @Published var busy: Set<String> = []
    @Published var problem: KeelExplanation?
    @Published var notice: String?

    private var observer: NSObjectProtocol?

    init() {
        reloadLog()
        observer = NotificationCenter.default.addObserver(forName: KeelAutoUpdater.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reloadLog() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reloadLog() {
        recent = Array(KeelAutoUpdater.log.entries().filter { $0.outcome != .nothingToDo }.prefix(3))
    }

    func checkConnection() async {
        if case .success = await isMinimuxerReady() { isConnected = true } else { isConnected = false }
    }

    func update(_ app: InstalledApp, presenter: UIViewController?) {
        let id = app.bundleIdentifier
        guard !busy.contains(id) else { return }
        busy.insert(id)
        let name = app.name
        let from = app.version
        let to = app.keelAvailableUpdate
        AppManager.shared.update(app, presentingViewController: presenter) { result in
            Task { @MainActor in
                self.busy.remove(id)
                switch result {
                case .success:
                    KeelAutoUpdater.log.append([KeelLogEntry(trigger: .manual, outcome: .updated, appName: name, bundleIdentifier: id, fromVersion: from, toVersion: to)])
                case .failure(let error):
                    if (error as NSError).code == NSUserCancelledError { return }
                    KeelAutoUpdater.log.append([KeelLogEntry(trigger: .manual, outcome: .failed, appName: name, bundleIdentifier: id, fromVersion: from, toVersion: to, message: (error as NSError).localizedDescription)])
                    self.problem = KeelErrorExplainer.explain(error)
                }
                self.reloadLog()
            }
        }
    }

    func refresh(_ apps: [InstalledApp], presenter: UIViewController?) {
        let ids = Set(apps.map(\.bundleIdentifier))
        busy.formUnion(ids)
        let group = AppManager.shared.refresh(apps, presentingViewController: presenter)
        group.completionHandler = { results in
            Task { @MainActor in
                self.busy.subtract(ids)
                let failures = results.values.compactMap { result -> Error? in
                    if case .failure(let error) = result { return error } else { return nil }
                }
                if let first = failures.first {
                    self.problem = KeelErrorExplainer.explain(first)
                } else {
                    self.notice = apps.count == 1 ? "Renewed for another 7 days." : "Renewed \(apps.count) apps."
                }
            }
        }
    }

    func checkForUpdates() async {
        do {
            let (_, context) = try await AppManager.shared.fetchSources()
            try await context.performAsync { try context.save() }
        } catch let error as AppManager.FetchSourcesError {
            try? await error.managedObjectContext?.performAsync { try error.managedObjectContext?.save() }
        } catch {
            problem = KeelErrorExplainer.explain(error)
        }
    }

    /// "updated 03:00" / "updated Tue" from Keel's log, else when it was last renewed.
    func subtitle(for app: InstalledApp) -> String {
        let formatter = DateFormatter()
        func when(_ date: Date) -> String {
            if Calendar.current.isDateInToday(date) { formatter.dateFormat = "HH:mm" } else { formatter.dateFormat = "EEE" }
            return formatter.string(from: date)
        }
        if let last = KeelAutoUpdater.log.entries().first(where: { $0.bundleIdentifier == app.bundleIdentifier && $0.outcome == .updated }) {
            return "\(app.version) · updated \(when(last.date))"
        }
        return "\(app.version) · renewed \(when(app.refreshedDate))"
    }
}

struct KeelAppsView: View {
    @EnvironmentObject private var navigator: KeelNavigator
    @StateObject private var model = KeelAppsModel()
    @FetchRequest private var apps: FetchedResults<InstalledApp>
    @ObservedObject private var settingsWatcher = KeelSettingsWatcher.shared

    init() {
        let request = InstalledApp.activeAppsFetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        _apps = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if apps.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(apps, id: \.objectID) { app in
                            KeelAppCard(app: app, model: model, navigator: navigator)
                        }
                    }
                }
                if let notice = model.notice {
                    Text(notice).font(.system(size: 14)).foregroundColor(KeelTheme.good)
                }
                recent
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120) // room to scroll past the floating tab bar
        }
        .background(KeelTheme.background.ignoresSafeArea())
        .foregroundColor(KeelTheme.text)
        .refreshable { await model.checkForUpdates() }
        .task { await model.checkConnection() }
        .sheet(item: Binding(get: { model.problem.map(KeelProblemItem.init) }, set: { model.problem = $0?.explanation })) { item in
            KeelProblemSheet(explanation: item.explanation)
                .environmentObject(navigator)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text("Apps").font(KeelTheme.display(30, .bold, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                Spacer()
                connectionChip
                Menu {
                    Button { Task { await KeelAutoUpdater.shared.run(trigger: .manual) } } label: { Label("Install updates now", systemImage: "arrow.down.circle") }
                    Button { model.refresh(Array(apps), presenter: navigator.topViewController) } label: { Label("Renew all apps now", systemImage: "arrow.triangle.2.circlepath") }
                    Divider()
                    Button { navigator.showClassicMyApps() } label: { Label("Install from a file…", systemImage: "doc.badge.plus") }
                    Button { navigator.showClassicMyApps() } label: { Label("All app tools", systemImage: "wrench.and.screwdriver") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .keelGlass(in: Circle(), interactive: true)
                }
                .accessibilityLabel("More")
            }
            Text(summary).font(.system(size: 14)).foregroundColor(KeelTheme.muted)
        }
    }

    private var summary: String {
        let count = apps.count == 1 ? "1 app" : "\(apps.count) apps"
        return settingsWatcher.settings.isEnabled ? "\(count) · renewed and updated automatically" : "\(count) · renewed automatically · auto-update off"
    }

    private var connectionChip: some View {
        HStack(spacing: 8) {
            Circle().fill(model.isConnected == false ? KeelTheme.warning : KeelTheme.good).frame(width: 8, height: 8)
            Text(model.isConnected == false ? "VPN off" : "Connected").font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 13).frame(minHeight: 34)
        .keelGlass(in: Capsule())
        .opacity(model.isConnected == nil ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No apps yet").font(KeelTheme.display(20))
            Text("Add a source, then install an app from it. Keel keeps it renewed and up to date.").font(.system(size: 15)).foregroundColor(KeelTheme.muted)
            KeelPrimaryButton(title: "Go to Sources") { navigator.showTab(.sources) }
        }
        .padding(18).keelCard()
    }

    @ViewBuilder
    private var recent: some View {
        if !model.recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    KeelSectionLabel(text: "Recent")
                    Spacer()
                    Button("See all") { navigator.showTab(.activity) }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(KeelTheme.accent)
                        .frame(minHeight: 44)
                }
                ForEach(model.recent) { entry in KeelLogLine(entry: entry) }
            }
            .padding(.top, 6)
            .overlay(Rectangle().fill(KeelTheme.line).frame(height: 1), alignment: .top)
        }
    }
}

private struct KeelProblemItem: Identifiable {
    let explanation: KeelExplanation
    var id: String { explanation.technical }
}

struct KeelAppCard: View {
    @ObservedObject var app: InstalledApp
    @ObservedObject var model: KeelAppsModel
    let navigator: KeelNavigator
    @State private var icon: UIImage?

    var body: some View {
        let days = app.keelDaysLeft
        let update = app.keelAvailableUpdate
        let isBusy = model.busy.contains(app.bundleIdentifier)
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Group {
                    if let icon { Image(uiImage: icon).resizable() } else { KeelTheme.line }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name).font(KeelTheme.display(19, .semibold, relativeTo: .headline)).lineLimit(1)
                    Text(model.subtitle(for: app)).font(.system(size: 13)).foregroundColor(KeelTheme.muted).lineLimit(1)
                    statusLine(update: update, isBusy: isBusy)
                }
                Spacer(minLength: 0)
                KeelDial(left: days.left, total: days.total)
            }
            if let update, !isBusy {
                KeelPrimaryButton(title: "Update to \(update)") {
                    model.update(app, presenter: navigator.topViewController)
                }
            }
        }
        .padding(16)
        .keelCard()
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .contextMenu {
            if !app.keelIsKeel {
                Button { UIApplication.shared.open(app.openAppURL) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
            }
            Button { model.refresh([app], presenter: navigator.topViewController) } label: { Label("Renew now", systemImage: "arrow.triangle.2.circlepath") }
            if update != nil {
                Button { model.update(app, presenter: navigator.topViewController) } label: { Label("Update", systemImage: "arrow.down.circle") }
            }
            Button { navigator.showClassicMyApps() } label: { Label("More options…", systemImage: "ellipsis.circle") }
        }
        .task(id: app.objectID) { icon = try? await app.loadIcon() }
    }

    @ViewBuilder
    private func statusLine(update: String?, isBusy: Bool) -> some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView().scaleEffect(0.6).frame(width: 10, height: 10)
                Text("Working…").foregroundColor(KeelTheme.muted)
            } else if let update {
                Circle().fill(KeelTheme.accent).frame(width: 6, height: 6)
                Text("\(update) ready").foregroundColor(KeelTheme.accent)
            } else if app.storeApp == nil {
                Circle().fill(KeelTheme.muted).frame(width: 6, height: 6)
                Text("Installed from a file").foregroundColor(KeelTheme.muted)
            } else {
                Circle().fill(KeelTheme.good).frame(width: 6, height: 6)
                Text("Up to date").foregroundColor(KeelTheme.good)
            }
        }
        .font(.system(size: 12, weight: .semibold))
    }
}

/// One line of Keel's log: "03:00  Setpoint 0.1.187 → 0.1.188 · nightly Shortcut".
struct KeelLogLine: View {
    let entry: KeelLogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.when(entry.date)).foregroundColor(KeelTheme.muted).monospacedDigit().frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                (Text(line).foregroundColor(entry.outcome == .failed ? KeelTheme.warning : KeelTheme.text)
                 + Text(" · \(entry.trigger.label.lowercased())").foregroundColor(KeelTheme.muted))
                if entry.outcome == .failed, let message = entry.message {
                    Text(KeelErrorExplainer.explain(domain: "", code: 0, text: message).title).foregroundColor(KeelTheme.muted).font(.system(size: 13))
                }
            }
        }
        .font(.system(size: 14))
        .accessibilityElement(children: .combine)
    }

    private var line: String {
        switch entry.outcome {
        case .updated:
            if let from = entry.fromVersion, let to = entry.toVersion { return "\(entry.appName ?? "App") \(from) → \(to)" }
            return "Updated \(entry.appName ?? "an app")"
        default:
            return entry.summary
        }
    }

    static func when(_ date: Date) -> String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(date) { f.dateFormat = "HH:mm" }
        else if let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day, days < 7 { f.dateFormat = "EEE" }
        else { f.dateFormat = "d MMM" }
        return f.string(from: date)
    }
}

/// Watches the auto-update settings so screens can show "auto-update off".
@MainActor
final class KeelSettingsWatcher: ObservableObject {
    static let shared = KeelSettingsWatcher()
    @Published var settings = KeelAutoUpdater.settings {
        didSet { KeelAutoUpdater.settings = settings }
    }
}
