//
//  KeelBrand.swift
//  Keel (fork of SideStore)
//
//  KEEL: names and links that make this fork "Keel". Upstream files point here
//  instead of carrying literals, so merges from SideStore stay small.
//

import Foundation

enum KeelBrand {
    static let name = "Keel"
    /// Main URL scheme. keel://update runs the auto-updater when Keel opens.
    static let urlScheme = "keel"
    static let updateURL = URL(string: "keel://update")!

    static let repositoryURL = URL(string: "https://github.com/Seifonyx/Keel")!
    static let licenseURL = URL(string: "https://github.com/Seifonyx/Keel/blob/develop/LICENSE")!
    /// Keel's own source, published by CI next to the .ipa in the "keel-latest" release.
    /// It is Keel's built-in source, so Keel can update itself.
    static let sourceURL = URL(string: "https://github.com/Seifonyx/Keel/releases/download/keel-latest/keel-source.json")!
    static let ipaURL = URL(string: "https://github.com/Seifonyx/Keel/releases/download/keel-latest/Keel.ipa")!
    static let iconURL = URL(string: "https://raw.githubusercontent.com/Seifonyx/Keel/develop/Keel/Branding/icon-1024.png")!

    static let upstreamName = "SideStore"
    static let upstreamURL = URL(string: "https://github.com/SideStore/SideStore")!
    static let altStoreURL = URL(string: "https://github.com/altstoreio/AltStore")!
}
