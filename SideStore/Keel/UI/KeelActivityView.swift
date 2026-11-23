//
//  KeelActivityView.swift
//  Keel (fork of SideStore)
//
//  KEEL: the Activity tab: everything Keel did, newest first, grouped by day,
//  with failures explained in plain words.
//

import SwiftUI

struct KeelActivityDay: Identifiable {
    var title: String
    var entries: [KeelLogEntry]
    var id: String { title }
}

@MainActor
final class KeelActivityModel: ObservableObject {
    @Published private(set) var days: [KeelActivityDay] = []
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
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        var groups: [KeelActivityDay] = []
        for entry in KeelAutoUpdater.log.entries() {
            let title: String
            if calendar.isDateInToday(entry.date) { title = "Today" }
            else if calendar.isDateInYesterday(entry.date) { title = "Yesterday" }
            else { title = formatter.string(from: entry.date) }
            if groups.last?.title == title { groups[groups.count - 1].entries.append(entry) }
            else { groups.append(KeelActivityDay(title: title, entries: [entry])) }
        }
        days = groups
    }

    func clear() {
        KeelAutoUpdater.log.clear()
        reload()
    }
}

struct KeelActivityView: View {
    @EnvironmentObject private var navigator: KeelNavigator
    @StateObject private var model = KeelActivityModel()
    @State private var selected: KeelLogEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Activity").font(KeelTheme.display(30, .bold, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if !model.days.isEmpty {
                        Menu {
                            SwiftUI.Button(role: .destructive) { model.clear() } label: { Label("Clear activity", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold))
                                .frame(width: 44, height: 44).keelGlass(in: Circle(), interactive: true)
                        }
                        .accessibilityLabel("More")
                    }
                }

                if model.days.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nothing yet").font(KeelTheme.display(20))
                        Text("Updates and renewals appear here as Keel does them.").font(.system(size: 15)).foregroundColor(KeelTheme.muted)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading).keelCard()
                }

                ForEach(model.days) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        KeelSectionLabel(text: day.title)
                        VStack(spacing: 0) {
                            ForEach(day.entries) { entry in
                                SwiftUI.Button { if entry.outcome == .failed { selected = entry } } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: Self.symbol(entry.outcome))
                                            .foregroundColor(Self.color(entry.outcome))
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(entry.outcome == .failed ? failedTitle(entry) : entry.summary)
                                                .font(.system(size: 15)).foregroundColor(KeelTheme.text)
                                                .multilineTextAlignment(.leading)
                                            Text("\(KeelLogLine.when(entry.date)) · \(entry.trigger.label)")
                                                .font(.system(size: 12)).foregroundColor(KeelTheme.muted)
                                        }
                                        Spacer(minLength: 0)
                                        if entry.outcome == .failed {
                                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(KeelTheme.muted)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(entry.outcome != .failed)
                                if entry.id != day.entries.last?.id {
                                    Rectangle().fill(KeelTheme.line).frame(height: 1).padding(.leading, 50)
                                }
                            }
                        }
                        .keelCard(cornerRadius: 18)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 120)
        }
        .background(KeelTheme.background.ignoresSafeArea())
        .foregroundColor(KeelTheme.text)
        .sheet(item: $selected) { entry in
            KeelProblemSheet(explanation: KeelErrorExplainer.explain(domain: "", code: 0, text: entry.message ?? entry.summary))
                .environmentObject(navigator)
        }
    }

    private func failedTitle(_ entry: KeelLogEntry) -> String {
        let reason = KeelErrorExplainer.explain(domain: "", code: 0, text: entry.message ?? "").title
        if let name = entry.appName { return "Couldn't update \(name): \(reason.lowercased())" }
        return reason
    }

    static func symbol(_ outcome: KeelLogEntry.Outcome) -> String {
        switch outcome {
        case .updated: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .skipped: return "pause.circle"
        case .nothingToDo: return "circle"
        }
    }

    static func color(_ outcome: KeelLogEntry.Outcome) -> Color {
        switch outcome {
        case .updated: return KeelTheme.good
        case .failed: return KeelTheme.warning
        case .skipped, .nothingToDo: return KeelTheme.muted
        }
    }
}

/// A problem in plain words, with its fix as the main button and the code under "Technical details".
struct KeelProblemSheet: View {
    let explanation: KeelExplanation
    @EnvironmentObject private var navigator: KeelNavigator
    @Environment(\.presentationMode) private var presentationMode
    @State private var fixing = false
    @State private var fixNote: String?
    @State private var showDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "exclamationmark.circle").font(.system(size: 30)).foregroundColor(KeelTheme.accent)
                Text(explanation.title).font(KeelTheme.display(24, .bold))
                Text(explanation.message).font(.system(size: 16)).foregroundColor(KeelTheme.text.opacity(0.85))
                if let fixNote {
                    Text(fixNote).font(.system(size: 15)).foregroundColor(KeelTheme.good)
                }
                if let fix = explanation.fix, fixNote == nil {
                    KeelPrimaryButton(title: Self.fixTitle(fix), isBusy: fixing) { perform(fix) }
                }
                SwiftUI.Button { withAnimation { showDetails.toggle() } } label: {
                    HStack { Text("Technical details"); Image(systemName: showDetails ? "chevron.up" : "chevron.down") }
                        .font(.system(size: 13)).foregroundColor(KeelTheme.muted).frame(minHeight: 44)
                }
                if showDetails {
                    Text(explanation.technical).font(.system(size: 12, design: .monospaced)).foregroundColor(KeelTheme.muted).textSelection(.enabled)
                }
            }
            .padding(24)
        }
        .background(KeelTheme.background.ignoresSafeArea())
        .foregroundColor(KeelTheme.text)
        .preferredColorScheme(.dark)
    }

    static func fixTitle(_ fix: KeelFix) -> String {
        switch fix {
        case .signInServer: return "Switch sign-in server"
        case .turnOnVPN: return "Open LocalDevVPN"
        case .replacePairingFile: return "Import a pairing file"
        case .signIn: return "Sign in"
        case .retryLater: return "OK"
        }
    }

    private func perform(_ fix: KeelFix) {
        switch fix {
        case .signInServer:
            fixing = true
            Task {
                let note = await KeelSignInFix.apply()
                fixing = false
                fixNote = note + " Close Keel completely, open it again, and sign in."
            }
        case .turnOnVPN:
            if let url = URL(string: "localdevvpn://") { UIApplication.shared.open(url) }
        case .replacePairingFile, .signIn:
            presentationMode.wrappedValue.dismiss()
            navigator.showAdvancedSettings()
        case .retryLater:
            presentationMode.wrappedValue.dismiss()
        }
    }
}
