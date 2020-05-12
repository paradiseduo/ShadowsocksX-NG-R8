//
//  ModeSwitch.swift
//  ShadowsocksX-NG
//
//  Created by ParadiseDuo on 2020/5/12.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Foundation


enum Mode {
    case PAC
    case GLOBAL
    case ACLAUTO
    case WHITELIST
    case MANUAL
    case CHINA
    
    static func switchTo(_ mode: Mode) {
        let defaults = UserDefaults.standard
        switch mode {
        case .PAC:
            defaults.setValue("auto", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            defaults.setValue("", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .GLOBAL:
            defaults.setValue("global", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            defaults.setValue("", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .ACLAUTO:
            defaults.setValue("whiteList", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            defaults.setValue("gfwlist.acl", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .WHITELIST:
            defaults.setValue("whiteList", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            defaults.setValue("chn.acl", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .MANUAL:
            defaults.setValue("manual", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            defaults.setValue("", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .CHINA:
            defaults.setValue("whiteList", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            defaults.setValue("backchn.acl", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        }
        defaults.synchronize()
        SyncSSLocal { (suc) in
            MainMenuManager.applyConfig { (suc) in
                NotificationCenter.default.post(name: NOTIFY_UPDATE_RUNNING_MODE_MENU, object: nil)
            }
        }
    }
}
