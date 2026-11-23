//
//  KeelRoot.swift
//  Keel (fork of SideStore)
//
//  KEEL: Keel's tabs: Apps, Sources, Activity, Settings. Installed into
//  SideStore's TabBarController (one call at the end of its viewDidLoad).
//  SideStore's own screens stay alive and reachable:
//   - Sources is SideStore's screen, unchanged.
//   - My Apps (install from a file, App IDs, inactive apps) opens from Apps → menu,
//     and still handles "open .ipa with Keel" and install links.
//   - Settings opens from Settings → Advanced, and still handles "open error log".
//  The UIKit tab bar becomes Liquid Glass on its own when built with the iOS 26 SDK.
//

import SwiftUI
import UIKit

@MainActor
final class KeelRoot: NSObject {
    enum Tab: Int { case apps = 0, sources = 1, activity = 2, settings = 3 }

    private static var current: KeelRoot?
    private static let closeTag = 0x4B45454C

    private weak var tabBarController: UITabBarController?
    /// SideStore's screens, kept so their notification handlers keep working.
    private var classicMyApps: UINavigationController?
    private var classicSettings: UINavigationController?

    private let appsNavigator = KeelNavigator()
    private let activityNavigator = KeelNavigator()
    private let settingsNavigator = KeelNavigator()

    static func install(on tabBarController: UITabBarController) {
        let root = KeelRoot()
        root.tabBarController = tabBarController
        current = root
        root.build()
    }

    private func build() {
        guard let tabBarController, let upstream = tabBarController.viewControllers else { return }
        KeelTheme.registerFonts()

        func nav(rootOf type: AnyClass) -> UINavigationController? {
            upstream.compactMap { $0 as? UINavigationController }.first { $0.viewControllers.first?.isKind(of: type) == true }
        }
        let sources = nav(rootOf: SourcesViewController.self)
        classicMyApps = nav(rootOf: MyAppsViewController.self)
        classicSettings = nav(rootOf: SettingsViewController.self)
        // Load their views now so their deep-link observers and state are ready.
        _ = classicMyApps?.viewControllers.first?.view
        _ = classicSettings?.viewControllers.first?.view

        let context = DatabaseManager.shared.viewContext
        for navigator in [appsNavigator, activityNavigator, settingsNavigator] { navigator.root = self }

        let apps = keelHostedScreen("Apps", symbol: "square.grid.2x2", navigator: appsNavigator) {
            KeelAppsView().environment(\.managedObjectContext, context)
        }
        let activity = keelHostedScreen("Activity", symbol: "clock.arrow.circlepath", navigator: activityNavigator) {
            KeelActivityView()
        }
        let settings = keelHostedScreen("Settings", symbol: "slider.horizontal.3", navigator: settingsNavigator) {
            KeelSettingsView()
        }
        for nav in [apps, activity, settings] { nav.delegate = self }

        var tabs: [UIViewController] = [apps]
        if let sources {
            sources.tabBarItem = UITabBarItem(title: "Sources", image: UIImage(systemName: "square.stack.3d.up"), selectedImage: nil)
            tabs.append(sources)
        }
        tabs += [activity, settings]
        tabBarController.setViewControllers(tabs, animated: false)
        tabBarController.selectedIndex = Tab.apps.rawValue

        tabBarController.overrideUserInterfaceStyle = .dark
        tabBarController.view.tintColor = KeelTheme.uiAccent
        tabBarController.tabBar.tintColor = KeelTheme.uiAccent
        tabBarController.view.backgroundColor = KeelTheme.uiBackground
    }

    func select(_ tab: Tab) {
        guard let tabBarController, tab.rawValue < (tabBarController.viewControllers?.count ?? 0) else { return }
        tabBarController.selectedIndex = tab.rawValue
    }

    // MARK: SideStore's screens

    static func presentClassicMyApps() { current?.presentClassicMyApps() }
    static func presentAdvancedSettings() { current?.presentAdvancedSettings() }

    func presentClassicMyApps() { presentClassic(classicMyApps) }
    func presentAdvancedSettings() { presentClassic(classicSettings) }

    private func presentClassic(_ nav: UINavigationController?) {
        guard let nav, let tabBarController else { return }
        guard nav.presentingViewController == nil else { return } // already showing
        if let rootItem = nav.viewControllers.first?.navigationItem,
           !(rootItem.rightBarButtonItems ?? []).contains(where: { $0.tag == Self.closeTag }) {
            let close = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak nav] _ in nav?.dismiss(animated: true) })
            close.tag = Self.closeTag
            rootItem.rightBarButtonItems = [close] + (rootItem.rightBarButtonItems ?? [])
        }
        nav.overrideUserInterfaceStyle = .dark
        nav.modalPresentationStyle = .pageSheet
        var top: UIViewController = tabBarController
        while let presented = top.presentedViewController { top = presented }
        top.present(nav, animated: true)
    }
}

// Keel's own screens draw their own header; pushed UIKit screens (app icons, About) show the bar.
extension KeelRoot: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let isKeelRoot = viewController === navigationController.viewControllers.first
        navigationController.setNavigationBarHidden(isKeelRoot, animated: animated)
    }
}
