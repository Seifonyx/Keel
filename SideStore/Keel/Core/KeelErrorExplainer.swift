//
//  KeelErrorExplainer.swift
//  Keel (fork of SideStore)
//
//  KEEL: turns error codes into a plain sentence and, where there is one, a fix.
//  Foundation-only so it can be unit tested (Keel/Tests).
//

import Foundation

public enum KeelFix: String, Equatable, Sendable {
    /// Switch Apple ID sign-in to a server that works today (see KeelSignInFix).
    case signInServer
    case turnOnVPN
    case replacePairingFile
    case signIn
    case retryLater
}

public struct KeelExplanation: Equatable, Sendable {
    public var title: String
    public var message: String
    public var fix: KeelFix?
    /// The original error text, for "Technical details".
    public var technical: String

    public init(title: String, message: String, fix: KeelFix?, technical: String) {
        self.title = title
        self.message = message
        self.fix = fix
        self.technical = technical
    }
}

public enum KeelErrorExplainer {

    public static func explain(_ error: Error) -> KeelExplanation {
        let ns = error as NSError
        var text = ns.localizedDescription
        if let reason = ns.localizedFailureReason, !reason.isEmpty, !text.contains(reason) { text += " " + reason }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError { text += " " + underlying.localizedDescription }
        return explain(domain: ns.domain, code: ns.code, text: text)
    }

    public static func explain(domain: String, code: Int, text: String) -> KeelExplanation {
        let t = text.lowercased()
        let technical = "\(text) (\(domain) \(code))"
        func has(_ needles: String...) -> Bool { needles.contains { t.contains($0.lowercased()) } }

        if has("-45063", "-45061", "-45062", "adi native", "adiprovisioning", "pending adi") {
            return KeelExplanation(
                title: "Apple didn't accept the sign-in",
                message: "Not your password. Apple changed its sign-in checks on 20 November and Keel's built-in sign-in method is affected. Switching to a sign-in server that works today usually fixes it.",
                fix: .signInServer, technical: technical)
        }
        if has("-22410") || (has("503") && has("apple", "gsa", "sign", "auth")) {
            return KeelExplanation(
                title: "Apple's sign-in service refused Keel",
                message: "Apple is rejecting the way Keel identifies itself right now. Switching to a sign-in server that works today usually fixes it.",
                fix: .signInServer, technical: technical)
        }
        if has("novpn", "no vpn", "vpn is not", "localdevvpn", "deviceendpointnotinitialized", "device endpoint", "unable to reach the device") {
            return KeelExplanation(
                title: "Keel can't reach your phone's services",
                message: "Keel installs and renews apps through LocalDevVPN. Turn the VPN on, then try again.",
                fix: .turnOnVPN, technical: technical)
        }
        if has("pairing") {
            return KeelExplanation(
                title: "The pairing file isn't working",
                message: "Keel needs a valid pairing file to talk to your phone. Make a new one on your computer and import it.",
                fix: .replacePairingFile, technical: technical)
        }
        if has("notauthenticated", "not authenticated", "not signed in", "sign in with your apple id", "session expired") {
            return KeelExplanation(
                title: "You're signed out",
                message: "Sign in with your Apple ID so Keel can sign your apps.",
                fix: .signIn, technical: technical)
        }
        if has("app id") && has("maximum", "limit", "10") {
            return KeelExplanation(
                title: "Weekly app ID limit reached",
                message: "A free Apple ID can create 10 app IDs every 7 days. Try again in a few days, or reuse an app you already have.",
                fix: .retryLater, technical: technical)
        }
        if has("maximum number of apps", "3 apps", "three apps", "active apps") {
            return KeelExplanation(
                title: "Too many apps for a free Apple ID",
                message: "A free Apple ID can have 3 sideloaded apps active at once, and Keel counts as one. Remove or deactivate an app first.",
                fix: nil, technical: technical)
        }
        if has("revoked", "certificate") && has("expired", "revoked", "invalid") {
            return KeelExplanation(
                title: "Keel's signing certificate stopped working",
                message: "Apple no longer accepts the certificate Keel signed with. Keel makes a new one when you refresh; your apps keep their data.",
                fix: nil, technical: technical)
        }
        if domain == "NSURLErrorDomain" && [-1009, -1020, -1018].contains(code) || has("offline", "internet connection appears") {
            return KeelExplanation(
                title: "You're offline",
                message: "Connect to the internet and try again.",
                fix: .retryLater, technical: technical)
        }
        if has("mismatched", "does not match", "doesn't match") && has("version", "build", "hash", "size") {
            return KeelExplanation(
                title: "The download didn't match its source",
                message: "Nothing was installed, so the app you have still works. This usually means the source was still publishing; it fixes itself on the next try.",
                fix: .retryLater, technical: technical)
        }
        return KeelExplanation(
            title: "Something went wrong",
            message: text.isEmpty ? "Keel couldn't finish. Try again." : text,
            fix: nil, technical: technical)
    }
}
