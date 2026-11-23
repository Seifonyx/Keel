//
//  KeelTheme.swift
//  Keel (fork of SideStore)
//
//  KEEL: the "Instrument" look. Dark ink, warm cream text, terracotta accent,
//  Space Grotesk for headings (SIL OFL, bundled in Keel/Resources/Fonts),
//  and Liquid Glass on floating controls (iOS 26; frosted blur before that).
//

import CoreText
import SwiftUI
import UIKit

enum KeelTheme {
    static let background = Color(red: 0x14 / 255, green: 0x11 / 255, blue: 0x0E / 255)
    static let surface = Color(red: 0x1F / 255, green: 0x1A / 255, blue: 0x16 / 255)
    static let line = Color(red: 0x2E / 255, green: 0x27 / 255, blue: 0x21 / 255)
    static let text = Color(red: 0xF3 / 255, green: 0xEA / 255, blue: 0xDB / 255)
    static let muted = Color(red: 0xA8 / 255, green: 0x9C / 255, blue: 0x8F / 255)
    static let accent = Color(red: 0xE0 / 255, green: 0x78 / 255, blue: 0x4A / 255)
    static let good = Color(red: 0x7B / 255, green: 0xC4 / 255, blue: 0x9A / 255)
    static let warning = Color(red: 0xE8 / 255, green: 0xB0 / 255, blue: 0x5C / 255)

    static let uiBackground = UIColor(red: 0x14 / 255, green: 0x11 / 255, blue: 0x0E / 255, alpha: 1)
    static let uiAccent = UIColor(red: 0xE0 / 255, green: 0x78 / 255, blue: 0x4A / 255, alpha: 1)

    /// Space Grotesk at a weight, scaling with Dynamic Type; system font if the file is missing.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold, relativeTo style: Font.TextStyle = .title) -> Font {
        registerFonts()
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "SpaceGrotesk-Bold"
        case .semibold: name = "SpaceGrotesk-SemiBold"
        default: name = "SpaceGrotesk-Medium"
        }
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size, relativeTo: style)
        }
        return .system(size: size, weight: weight)
    }

    private static var didRegister = false
    static func registerFonts() {
        guard !didRegister else { return }
        didRegister = true
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] where url.lastPathComponent.hasPrefix("SpaceGrotesk") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension View {
    /// Liquid Glass on iOS 26, frosted material before. Use it for controls that float over content.
    @ViewBuilder
    func keelGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            let base: Glass = tint.map { Glass.regular.tint($0) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            self.background(tint.map { AnyShapeStyle($0.opacity(0.75)) } ?? AnyShapeStyle(.ultraThinMaterial), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    /// A solid Keel card (content, not glass).
    func keelCard(cornerRadius: CGFloat = 22) -> some View {
        self.background(KeelTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(KeelTheme.line, lineWidth: 1))
    }
}

/// The days-left dial on each app card.
struct KeelDial: View {
    let left: Int
    let total: Int
    var size: CGFloat = 60

    var body: some View {
        let progress = total > 0 ? Double(left) / Double(total) : 0
        ZStack {
            Circle().stroke(KeelTheme.line, lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(left <= 1 ? KeelTheme.warning : KeelTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(left)").font(KeelTheme.display(19, .semibold, relativeTo: .headline)).monospacedDigit()
                Text(left == 1 ? "day" : "days").font(.system(size: 10)).foregroundColor(KeelTheme.muted)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(left) of \(total) days left")
    }
}

/// A primary action: terracotta tinted glass.
struct KeelPrimaryButton: View {
    let title: String
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy { ProgressView().tint(.white) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keelGlass(in: Capsule(), tint: KeelTheme.accent, interactive: true)
        .disabled(isBusy)
    }
}

/// Small section label ("RECENT", "UPDATES").
struct KeelSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .kerning(0.9)
            .foregroundColor(KeelTheme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}
