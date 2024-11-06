import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }

        if let shortcutItem = connectionOptions.shortcutItem {
            print("Scene connected with shortcut")
            handleShortcutItem(shortcutItem, isFreshLaunch: true)
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        print("Shortcut action performed in scene")
        handleShortcutItem(shortcutItem, isFreshLaunch: false)
        completionHandler(true)
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem, isFreshLaunch: Bool) {
        print("Handling shortcut: \(shortcutItem.type) in SceneDelegate")
        if shortcutItem.type == "com.teleprompterx.specialoffer" {
            if isFreshLaunch {
                ScriptsCollectionViewController.shouldPresentSpecialOffer = true
            } else {
                if let scriptsCollectionVC = findScriptsCollectionViewController() {
                    print("ScriptsCollectionViewController found in SceneDelegate")
                    scriptsCollectionVC.presentSpecialOffer()
                } else {
                    print("ScriptsCollectionViewController not found in SceneDelegate")
                }
            }
        }
    }

    private func findScriptsCollectionViewController() -> ScriptsCollectionViewController? {
        if let rootViewController = window?.rootViewController {
            if let navController = rootViewController as? UINavigationController {
                return navController.viewControllers.first(where: { $0 is ScriptsCollectionViewController }) as? ScriptsCollectionViewController
            } else if let tabBarController = rootViewController as? UITabBarController {
                return tabBarController.viewControllers?.first(where: { $0 is ScriptsCollectionViewController }) as? ScriptsCollectionViewController
            } else if let scriptsCollectionVC = rootViewController as? ScriptsCollectionViewController {
                return scriptsCollectionVC
            }
        }
        return nil
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
}
