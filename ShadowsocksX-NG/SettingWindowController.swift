//
//  SettingWindowController.swift
//  ShadowsocksX-NG
//
//  Created by YouShaoduo on 2020/4/29.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Cocoa

class SettingWindowController: NSWindowController, NSWindowDelegate {
    
    @IBOutlet weak var launchAtLogin: NSButton!
    @IBOutlet weak var delayTestMethod: NSComboBox!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.delegate = self
        launchAtLogin.state = AppDelegate.getLauncherStatus() ? .on:.off
        
        let d = UserDefaults.standard
        delayTestMethod.stringValue = d.bool(forKey: USERDEFAULTS_TCP) ? "TCP":"ICMP"
    }
    
    func windowWillClose(_ notification: Notification) {
        let d = UserDefaults.standard
        d.setValue(delayTestMethod.stringValue == "TCP" ? true:false, forKey: USERDEFAULTS_TCP)
        d.synchronize()
        
        AppDelegate.setLauncherStatus(open: launchAtLogin.state == .on ? true:false)
        NotificationCenter.default.post(name: NOTIFY_SETTING_UPDATE, object: nil)
    }
}
