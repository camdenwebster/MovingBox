//
//  AppDelegate.swift
//  MovingBox
//
//  Created by Camden Webster on 2/4/26.
//

import UIKit
import UserNotifications

enum AnalysisNotificationConstants {
    static let multiItemAnalysisReadyIdentifier = "multiItemAnalysisReady"
    static let multiItemAnalysisTappedNotificationName = "multiItemAnalysisReadyNotificationTapped"
}

extension Notification.Name {
    static let multiItemAnalysisReadyNotificationTapped = Notification.Name(
        AnalysisNotificationConstants.multiItemAnalysisTappedNotificationName
    )
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        if identifier == AnalysisNotificationConstants.multiItemAnalysisReadyIdentifier {
            NotificationCenter.default.post(
                name: .multiItemAnalysisReadyNotificationTapped,
                object: nil,
                userInfo: response.notification.request.content.userInfo
            )
        }
        completionHandler()
    }
}
