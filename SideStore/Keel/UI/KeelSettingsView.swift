//
//  KeelSettingsView.swift
//  Keel (fork of SideStore)
//
//  KEEL: the Settings tab, short on purpose: is everything working, updates,
//  sign-in, icon, and one way into SideStore's full settings (Advanced).
//

import SwiftUI
import UIKit

@MainActor
final class KeelStatusModel: ObservableObject {
    @Published var appleID: String?
    @Published var isConnected: Bool?
    @Published var hasPairingFile = false

    func refresh() async {
        appleID = Keychain.shared.appleIDEmailAddress
        hasPairingFile = PairingFileManager.shared.fetchPairingFile() != nil
        if case .success = await isMinimuxerReady() { isConnected = true } else { isConnected = false }
    }
}

struct KeelSettingsView: View {
    @EnvironmentObject private var navigator: KeelNavigator
    @StateObject private var status = KeelStatusModel()
    @ObservedObject private var watcher = KeelSettingsWatcher.shared
    @State private var showNightly = false
    @State private var showSignInFix = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings").font(KeelTheme.display(30, .bold, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)

                HStack(spacing: 8) {
                    tile("Apple ID", ok: status.appleID != nil, value: status.appleID != nil ? "Signed in" : "Signed out")
                    tile("VPN", ok: status.isConnected != false, value: status.isConnected == false ? "Off" : "Connected")
                    tile("Pairing", ok: status.hasPairingFile, value: status.hasPairingFile ? "Valid" : "Missing")
                }

                VStack(alignment: .leading, spacing: 8) {
                    KeelSectionLabel(text: "Updates")
                    VStack(spacing: 0) {
                        toggleRow("Install updates automatically", detail: "After renewals and when Keel opens", isOn: $watcher.settings.isEnabled)
                        divider
                        toggleRow("Only on Wi-Fi", detail: nil, isOn: $watcher.settings.wifiOnly)
                        divider
                        toggleRow("Also update Keel", detail: "Off keeps the Keel you know works", isOn: $watcher.settings.includesKeelItself)
                        divider
                        linkRow("Nightly update", value: "How to set up") { showNightly = true }
                    }
                    .keelCard(cornerRadius: 18)
                }

                VStack(alignment: .leading, spacing: 8) {
                    KeelSectionLabel(text: "Apple ID")
                    VStack(spacing: 0) {
                        linkRow(status.appleID ?? "Sign in", value: status.appleID == nil ? nil : "Account") { navigator.showAdvancedSettings() }
                        divider
                        linkRow("Trouble signing in?", value: KeelSignInFix.isApplied ? "Server fix on" : nil) { showSignInFix = true }
                    }
                    .keelCard(cornerRadius: 18)
                }

                VStack(spacing: 0) {
                    linkRow("App icon", value: UIApplication.shared.alternateIconName.map(Self.iconName) ?? "Keel") {
                        navigator.push(AltAppIconsViewController(collectionViewLayout: UICollectionViewFlowLayout()))
                    }
                    divider
                    linkRow("Advanced", detail: "Sign-in servers, pairing, certificates, logs", value: nil) { navigator.showAdvancedSettings() }
                    divider
                    linkRow("About Keel", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) {
                        let host = UIHostingController(rootView: KeelAboutView())
                        host.title = "About Keel"
                        navigator.push(host)
                    }
                }
                .keelCard(cornerRadius: 18)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 120)
        }
        .background(KeelTheme.background.ignoresSafeArea())
        .foregroundColor(KeelTheme.text)
        .task { await status.refresh() }
        .sheet(isPresented: $showNightly) { KeelNightlySheet() }
        .sheet(isPresented: $showSignInFix) {
            KeelProblemSheet(explanation: KeelExplanation(
                title: "Trouble signing in?",
                message: "Since 20 November Apple has been rejecting the sign-in method Keel uses by default. Keel can switch to a sign-in server that works today. Your Apple ID is still sent only to Apple; the server only helps Keel identify itself.",
                fix: .signInServer,
                technical: "Uses \(KeelSignInFix.serverURL) (remote anisette), pinned, with client info “Mac OS X”. Undo under Advanced → Anisette."))
            .environmentObject(navigator)
        }
    }

    private static func iconName(_ alternate: String) -> String {
        switch alternate {
        case "DarkIcon": return "Ink"
        case "SandyIcon": return "Terracotta"
        case "BlueIcon": return "Sea"
        case "SnowIcon": return "Paper"
        default: return alternate
        }
    }

    private var divider: some View { Rectangle().fill(KeelTheme.line).frame(height: 1).padding(.leading, 16) }

    private func tile(_ label: String, ok: Bool, value: String) -> some View {
        SwiftUI.Button { navigator.showAdvancedSettings() } label: {
            VStack(alignment: .leading, spacing: 8) {
                Circle().fill(ok ? KeelTheme.good : KeelTheme.warning).frame(width: 8, height: 8)
                Text(label).font(.system(size: 12)).foregroundColor(KeelTheme.muted)
                Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(KeelTheme.text).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .keelCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func toggleRow(_ title: String, detail: String?, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16))
                if let detail { Text(detail).font(.system(size: 13)).foregroundColor(KeelTheme.muted) }
            }
        }
        .tint(KeelTheme.accent)
        .padding(.horizontal, 16).padding(.vertical, 10).frame(minHeight: 54)
    }

    private func linkRow(_ title: String, detail: String? = nil, value: String?, action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16)).foregroundColor(KeelTheme.text).lineLimit(1)
                    if let detail { Text(detail).font(.system(size: 13)).foregroundColor(KeelTheme.muted) }
                }
                Spacer(minLength: 8)
                if let value { Text(value).font(.system(size: 15)).foregroundColor(KeelTheme.muted).lineLimit(1) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(KeelTheme.muted)
            }
            .padding(.horizontal, 16).padding(.vertical, 10).frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The one-time Shortcuts automation, step by step.
struct KeelNightlySheet: View {
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Update every night").font(KeelTheme.display(26, .bold))
                Text("iOS gives apps little background time, so a Shortcuts automation is the reliable way to keep apps current. You set it up once.")
                    .font(.system(size: 16)).foregroundColor(KeelTheme.text.opacity(0.85))
                VStack(alignment: .leading, spacing: 14) {
                    step(1, "Open Shortcuts, go to Automation and tap +.")
                    step(2, "Choose Time of Day (for example 03:00, daily) or Charger → Is Connected.")
                    step(3, "Choose Run Immediately.")
                    step(4, "Add the action Keel → Update Apps, then tap Done.")
                }
                .padding(18).keelCard()
                Text("Keel opens while it works, because installing needs the VPN. It sends a notification when it updated something.")
                    .font(.system(size: 14)).foregroundColor(KeelTheme.muted)
                KeelPrimaryButton(title: "Open Shortcuts") {
                    if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                }
            }
            .padding(24)
        }
        .background(KeelTheme.background.ignoresSafeArea())
        .foregroundColor(KeelTheme.text)
        .preferredColorScheme(.dark)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n)").font(KeelTheme.display(17, .bold)).foregroundColor(KeelTheme.accent).frame(width: 18)
            Text(text).font(.system(size: 15))
        }
    }
}
