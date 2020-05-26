//
//  AppDelegate.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/5.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Cocoa
import ServiceManagement

let KILL_LAUNCHER = Notification.Name("ShadowsocksX_NG_R8_KILL_LAUNCHER")
let LAUNCHER_APPID = "com.qiuyuzhou.ShadowsocksX-NG.LaunchAtLoginHelper"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: Application function
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Handle ss url scheme
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleURLEvent), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == LAUNCHER_APPID }.isEmpty
        if isRunning {
            DistributedNotificationCenter.default().post(name: KILL_LAUNCHER, object: Bundle.main.bundleIdentifier!)
        }
    }
    
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue {
            if URL(string: urlString) != nil {
                NotificationCenter.default.post(name: NOTIFY_FOUND_SS_URL, object: nil, userInfo: [
                        "urls": splitProfile(url: urlString, max: 5).map({ (item: String) -> URL in
                            return URL(string: item)!
                        }),
                        "source": "url",
                    ])
            }
        }
    }
    
    static func stopSSR(finish: @escaping()->()) {
        StopSSLocal { (s) in
            StopPrivoxy { (ss) in
                ProxyConfHelper.stopPACServer()
                ProxyConfHelper.disableProxy("hi")
                let defaults = UserDefaults.standard
                defaults.set(false, forKey: USERDEFAULTS_SHADOWSOCKS_ON)
                defaults.synchronize()
                DispatchQueue.main.async {
                    finish()
                }
            }
        }
    }
    
    static func getLauncherStatus() -> Bool {
        let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]]
        let autoLaunchRegistered = jobs?.contains(where: { $0["Label"] as! String == LAUNCHER_APPID }) ?? false
        return autoLaunchRegistered
    }
    
    static func setLauncherStatus(open: Bool) {
        SMLoginItemSetEnabled(LAUNCHER_APPID as CFString, open)
    }
    
    static var isAboveMacOS153: Bool {
        if #available(macOS 10.15.3, *) {
            return true
        }
        return false
    }
}
