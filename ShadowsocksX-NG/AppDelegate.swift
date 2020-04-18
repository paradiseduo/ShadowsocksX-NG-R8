//
//  AppDelegate.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/5.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: Application function
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Handle ss url scheme
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleURLEvent), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
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
    
    static func stopSSR() {
        StopSSLocal()
        StopPrivoxy()
        ProxyConfHelper.stopPACServer()
        ProxyConfHelper.disableProxy("hi")
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "ShadowsocksOn")
        defaults.synchronize()
    }
}
