//
//  KeelSignInFix.swift
//  Keel (fork of SideStore)
//
//  KEEL: one tap for the Apple ID sign-in workaround from SideStore issues
//  #1745/#1765 (Apple changed its checks on 2026-11-20):
//    1. sign in through a remote anisette server instead of on-device,
//    2. use mac-ani.jkcoxson.com and stop rotating to other servers,
//    3. take that server's user agent, and send client info as "Mac OS X",
//    4. reset adi.pb so the next sign-in provisions afresh.
//  Same settings a person can set by hand under Advanced → Anisette.
//  needs proper testing on a device.
//

import Foundation

enum KeelSignInFix {
    static let serverName = "mac-ani (jkcoxson)"
    static let serverURL = "https://mac-ani.jkcoxson.com"
    static let clientInfo = "<MacBookPro13,3> <Mac OS X;26.6;25F84> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"

    /// True once the fix has been applied (and not undone by hand).
    static var isApplied: Bool {
        !UserDefaults.standard.useOnDeviceAnisette && UserDefaults.standard.menuAnisetteURL == serverURL
    }

    /// Applies the workaround. Returns a short note for the person.
    @discardableResult
    static func apply() async -> String {
        // 1 + 2: remote server, pinned.
        let servers = await AnisetteServersManager.shared.loadLocalServers()
        if !servers.contains(where: { $0.address == serverURL }) {
            await AnisetteServersManager.shared.saveLocalServers([AnisetteServerItem(name: serverName, address: serverURL)] + servers)
        }
        UserDefaults.standard.useOnDeviceAnisette = false
        UserDefaults.standard.menuAnisetteURL = serverURL
        UserDefaults.standard.disableAnisetteRotation = true

        // 3: the server's own headers, with client info that Apple accepts.
        var config = await AnisetteConfigManager.shared.loadConfig()
        var note = "Sign-in now goes through \(URL(string: serverURL)?.host ?? serverURL)."
        if let url = URL(string: serverURL)?.appendingPathComponent("v3").appendingPathComponent("client_info") {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                await AnisetteConfigManager.shared.saveServerHeaders(json)
                if let ua = json["user_agent"] ?? json["userAgent"] ?? json["User-Agent"], !ua.isEmpty {
                    config.userAgent = ua
                }
            } else {
                note += " Couldn't reach it just now; the sign-in will try again."
            }
        }
        config.clientInfo = clientInfo
        await AnisetteConfigManager.shared.saveConfig(config)

        // 4: fresh provisioning on the next sign-in.
        AnisetteConfigManager.shared.anisetteAdiBlob = nil
        return note
    }
}
