import UIKit
import FirebaseMessaging
import RevenueCat
import Firebase
import FirebaseAppCheck
import UserNotifications
import FBSDKCoreKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var floatingWindow: FloatingWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
     
          ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
          )
                  
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            print("App launched from shortcut")
            handleShortcutItem(shortcutItem, isFreshLaunch: true)
            return false
        }
        
        let defaultMargins: [String: CGFloat] = [
            "TopMargin": 0,
            "BottomMargin": 0,
            "LeftMargin": 0,
            "RightMargin": 0
        ]

        for (key, value) in defaultMargins {
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: "appl_ggRoolvjwYaxIOqdKiMfrOJSbnV")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Register for remote notifications
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self

            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }

        application.registerForRemoteNotifications()

        Messaging.messaging().delegate = self
        
        // Initialize App Check with App Attest provider
        let providerFactory = CustomAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        return true
    }
    
    func application(
      _ app: UIApplication,
      open url: URL,
      options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
      return ApplicationDelegate.shared.application(
        app,
        open: url,
        options: options
      )
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
            // App is about to terminate
            UserDefaults.standard.set(false, forKey: "ExternalDisplayEnabled")
            print("External Display Toggled OFF in applicationWillTerminate")
        }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        NotificationCenter.default.post(name: NSNotification.Name("AppDidEnterBackground"), object: nil)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        floatingWindow?.isHidden = true
        floatingWindow = nil
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        print("Shortcut action performed")
        handleShortcutItem(shortcutItem, isFreshLaunch: false)
        completionHandler(true)
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem, isFreshLaunch: Bool) {
        print("Handling shortcut: \(shortcutItem.type)")
        if shortcutItem.type == "com.teleprompterx.specialoffer" {
            if isFreshLaunch {
                ScriptsCollectionViewController.shouldPresentSpecialOffer = true
            } else {
                if let scriptsCollectionVC = findScriptsCollectionViewController() {
                    print("ScriptsCollectionViewController found in AppDelegate")
                    scriptsCollectionVC.presentSpecialOffer()
                } else {
                    print("ScriptsCollectionViewController not found in AppDelegate")
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
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // Handle incoming notification messages
    @available(iOS 10, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print(userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    @available(iOS 10, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print(userInfo)
        completionHandler()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}

class CustomAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")

        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
    }
}
