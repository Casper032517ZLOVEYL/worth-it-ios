import SwiftUI

@main
struct WorthItApp: App {
    @UIApplicationDelegateAdaptor(WeChatAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onOpenURL { _ = WeChatAuthService.shared.handle(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { _ = WeChatAuthService.shared.handle(activity: $0) }
        }
    }
}
