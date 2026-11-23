//
//  KeelNavigator.swift
//  Keel (fork of SideStore)
//
//  KEEL: lets Keel's SwiftUI screens open SideStore's UIKit screens
//  (classic My Apps, full settings, app icons) and switch tabs.
//

import SwiftUI
import UIKit

@MainActor
final class KeelNavigator: ObservableObject {
    weak var navigationController: UINavigationController?
    weak var root: KeelRoot?

    func push(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }

    func present(_ viewController: UIViewController) {
        guard let host = navigationController else { return }
        (host.presentedViewController ?? host).present(viewController, animated: true)
    }

    func showTab(_ tab: KeelRoot.Tab) { root?.select(tab) }
    func showClassicMyApps() { root?.presentClassicMyApps() }
    func showAdvancedSettings() { root?.presentAdvancedSettings() }

    var topViewController: UIViewController? {
        var top: UIViewController? = navigationController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Hosts a Keel SwiftUI screen inside a UIKit navigation controller with its own header (no bar).
@MainActor
func keelHostedScreen<V: View>(_ title: String, symbol: String, navigator: KeelNavigator, @ViewBuilder content: () -> V) -> UINavigationController {
    let host = UIHostingController(rootView: content().environmentObject(navigator))
    host.view.backgroundColor = KeelTheme.uiBackground
    host.title = title
    let nav = UINavigationController(rootViewController: host)
    nav.setNavigationBarHidden(true, animated: false)
    nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: nil)
    navigator.navigationController = nav
    return nav
}
