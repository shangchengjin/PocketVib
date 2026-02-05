//  SceneDelegate.swift
//  PocketVib_Collector

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        let cameraViewController = ViewController()
        window.rootViewController = cameraViewController
        
        window.makeKeyAndVisible()
    }
}
