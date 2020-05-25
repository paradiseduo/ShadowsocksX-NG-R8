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
        let d = UserDefaults.standard
        if let currentMode = d.string(forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE), let acl = d.string(forKey: USERDEFAULTS_ACL_FILE_NAME) {
            switch mode {
            case .PAC:
                if currentMode == "auto" { return }
            case .GLOBAL:
                if currentMode == "global" { return }
            case .ACLAUTO:
                if currentMode == "whiteList" && acl == "gfwlist.acl" { return }
            case .WHITELIST:
                if currentMode == "whiteList" && acl == "chn.acl" { return }
            case .MANUAL:
                if currentMode == "manual" { return }
            case .CHINA:
                if currentMode == "whiteList" && acl == "backchn.acl" { return }
            }
        }
        switch mode {
        case .PAC:
            d.setValue("auto", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            d.setValue("", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .GLOBAL:
            d.setValue("global", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            d.setValue("", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .ACLAUTO:
            d.setValue("whiteList", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            d.setValue("gfwlist.acl", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .WHITELIST:
            d.setValue("whiteList", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            d.setValue("chn.acl", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .MANUAL:
            d.setValue("manual", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            d.setValue("", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        case .CHINA:
            d.setValue("whiteList", forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
            d.setValue("backchn.acl", forKey: USERDEFAULTS_ACL_FILE_NAME)
            break
        }
        d.synchronize()
        SyncSSLocal { (suc) in
            MainMenuManager.applyConfig { (suc) in
                NotificationCenter.default.post(name: NOTIFY_UPDATE_RUNNING_MODE_MENU, object: nil)
            }
        }
    }
}
