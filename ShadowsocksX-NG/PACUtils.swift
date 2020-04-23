//
//  PACUtils.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/9.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Foundation
import Alamofire

let OldErrorPACRulesDirPath = NSHomeDirectory() + "/.ShadowsocksX-NE/"

let PACRulesDirPath = NSHomeDirectory() + "/.ShadowsocksX-NG/"
let PACUserRuleFilePath = PACRulesDirPath + "user-rule.txt"
let PACFilePath = PACRulesDirPath + "gfwlist.js"
let GFWListFilePath = PACRulesDirPath + "gfwlist.txt"

let ACLWhiteListFilePath = PACRulesDirPath + "chn.acl"
let ACLBackCHNFilePath = PACRulesDirPath + "backchn.acl"
let ACLGFWListFilePath = PACRulesDirPath + "gfwlist.acl"

// Because of LocalSocks5.ListenPort may be changed
func SyncPac() {
    var needGenerate = false
    
    let nowSocks5Port = UserDefaults.standard.integer(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT)
    let oldSocks5Port = UserDefaults.standard.integer(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT_OLD)
    if nowSocks5Port != oldSocks5Port {
        needGenerate = true
        UserDefaults.standard.set(nowSocks5Port, forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT_OLD)
        UserDefaults.standard.synchronize()
    }
    
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: PACRulesDirPath) {
        needGenerate = true
    }
    
    if !fileMgr.fileExists(atPath: ACLWhiteListFilePath) && !fileMgr.fileExists(atPath: ACLBackCHNFilePath) {
        needGenerate = true
    }
    
    if needGenerate {
        if !GeneratePACFile() {
            NSLog("GeneratePACFile failed!")
        }
    }
}


func GeneratePACFile() -> Bool {
    let fileMgr = FileManager.default
    // Maker the dir if rulesDirPath is not exesited.
    if !fileMgr.fileExists(atPath: PACRulesDirPath) {
        if fileMgr.fileExists(atPath: OldErrorPACRulesDirPath) {
            try! fileMgr.moveItem(atPath: OldErrorPACRulesDirPath, toPath: PACRulesDirPath)
        } else {
            try! fileMgr.createDirectory(atPath: PACRulesDirPath
                , withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    // If gfwlist.txt is not exsited, copy from bundle
    if !fileMgr.fileExists(atPath: GFWListFilePath) {
        let src = Bundle.main.path(forResource: "gfwlist", ofType: "txt")
        try! fileMgr.copyItem(atPath: src!, toPath: GFWListFilePath)
    }
    
    // If user-rule.txt is not exsited, copy from bundle
    if !fileMgr.fileExists(atPath: PACUserRuleFilePath) {
        let src = Bundle.main.path(forResource: "user-rule", ofType: "txt")
        try! fileMgr.copyItem(atPath: src!, toPath: PACUserRuleFilePath)
    }
    
    // If chn.acl is not exsited, copy from bundle
    if !fileMgr.fileExists(atPath: ACLWhiteListFilePath) {
        let src = Bundle.main.path(forResource: "chn", ofType: "acl")
        try! fileMgr.copyItem(atPath: src!, toPath: ACLWhiteListFilePath)
    }
    
    // If backchn is not exsited, copy from bundle
    if !fileMgr.fileExists(atPath: ACLBackCHNFilePath) {
        let src = Bundle.main.path(forResource: "backchn", ofType: "acl")
        try! fileMgr.copyItem(atPath: src!, toPath: ACLBackCHNFilePath)

    }
    // If chn.acl
    if !fileMgr.fileExists(atPath: ACLGFWListFilePath) {
        let src = Bundle.main.path(forResource: "gfwlist", ofType: "acl")
        try! fileMgr.copyItem(atPath: src!, toPath: ACLGFWListFilePath)
        
    }
    
    let socks5Port = UserDefaults.standard.integer(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT)
    
    do {
        let gfwlist = try String(contentsOfFile: GFWListFilePath, encoding: String.Encoding.utf8)
        if let data = Data(base64Encoded: gfwlist, options: .ignoreUnknownCharacters) {
            let str = String(data: data, encoding: String.Encoding.utf8)
            var lines = str!.components(separatedBy: CharacterSet.newlines)
            
            do {
                let userRuleStr = try String(contentsOfFile: PACUserRuleFilePath, encoding: String.Encoding.utf8)
                let userRuleLines = userRuleStr.components(separatedBy: CharacterSet.newlines)
                
                lines = userRuleLines + lines.filter { (line) in
                    // 如果用户为相同的网址提供相同的规则，则忽略来自gwf的规则
                    var i = line.startIndex
                    while i < line.endIndex {
                        if line[i] == "@" || line[i] == "|" {
                            i = line.index(after: i)
                            continue
                        }
                        break
                    }
                    if i == line.startIndex {
                        return !userRuleLines.contains(line)
                    }
                    return !userRuleLines.contains(String(line[i...]))
                }
                ACLFromUserRule(userRuleLines: userRuleLines)
            } catch {
                NSLog("Not found user-rule.txt")
            }
            
            // Filter empty and comment lines
            lines = lines.filter({ (s: String) -> Bool in
                if s.isEmpty {
                    return false
                }
                let c = s[s.startIndex]
                if c == "!" || c == "[" {
                    return false
                }
                return true
            })
            
            do {
                // rule lines to json array
                let rulesJsonData: Data
                    = try JSONSerialization.data(withJSONObject: lines, options: .prettyPrinted)
                let rulesJsonStr = String(data: rulesJsonData, encoding: String.Encoding.utf8)
                
                // Get raw pac js
                let jsPath = Bundle.main.url(forResource: "abp", withExtension: "js")
                let jsData = try? Data(contentsOf: jsPath!)
                var jsStr = String(data: jsData!, encoding: String.Encoding.utf8)
                
                // Replace rules placeholder in pac js
                jsStr = jsStr!.replacingOccurrences(of: "__RULES__"
                    , with: rulesJsonStr!)
                // Replace __SOCKS5PORT__ palcholder in pac js
                let result = jsStr!.replacingOccurrences(of: "__SOCKS5PORT__"
                    , with: "\(socks5Port)")
                
                // Write the pac js to file.
                try result.data(using: String.Encoding.utf8)?
                    .write(to: URL(fileURLWithPath: PACFilePath), options: .atomic)
                
                return true
            } catch {
                
            }
        }
        
    } catch {
        NSLog("Not found gfwlist.txt")
    }
    return false
}

func UpdatePACFromGFWList() {
    // Make the dir if rulesDirPath is not exesited.
    if !FileManager.default.fileExists(atPath: PACRulesDirPath) {
        do {
            try FileManager.default.createDirectory(atPath: PACRulesDirPath
                , withIntermediateDirectories: true, attributes: nil)
        } catch {
        }
    }
    
    let url = UserDefaults.standard.string(forKey: USERDEFAULTS_GFW_LIST_URL)
    AF.request(url!)
        .responseString {
            response in
            do {
                let value = try response.result.get()
                try value.write(toFile: GFWListFilePath, atomically: true, encoding: String.Encoding.utf8)
                if GeneratePACFile() {
                    // Popup a user notification
                    let notification = NSUserNotification()
                    notification.title = "PAC has been updated by latest GFW List.".localized
                    NSUserNotificationCenter.default.deliver(notification)
                }
            } catch {
                // Popup a user notification
                let notification = NSUserNotification()
                notification.title = "Failed to download latest GFW List.".localized
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
}
func ACLFromUserRule(userRuleLines:[String]){
    do {
        var AutoACL = try String(contentsOfFile: ACLGFWListFilePath, encoding: String.Encoding.utf8)
        var WhiteACL = try String(contentsOfFile: ACLWhiteListFilePath, encoding: String.Encoding.utf8)
        let rule = userRuleLines.filter({ (s: String) -> Bool in
            if s.isEmpty {
                return false
            }
            let c = s[s.startIndex]
            if c == "!" || c == "[" {
                return false
            }
            return true
        })
        rule.forEach({ (s: String) -> Void in
            // add the @@ to whitelist and other to GFWList
            if (s.hasPrefix("@@")){
                let str = s.replacingOccurrences(of: "@@", with: "").components(separatedBy: ".").joined(separator:"\\.").replacingOccurrences(of: "*\\.", with: "^(.*\\.)?")
                if (!WhiteACL.contains(str)){
                    WhiteACL += (str + "$\n")

                }
            }
            if (s.hasPrefix("||")){
                let str = s.replacingOccurrences(of: "||", with: "").components(separatedBy: ".").joined(separator:"\\.").replacingOccurrences(of: "*\\.", with: "^(.*\\.)?")
                if (!AutoACL.contains(str)){
                    AutoACL += (str + "$\n")
                }
            }
        })
        // write file back to ACL
        try WhiteACL.data(using: String.Encoding.utf8)?
            .write(to: URL(fileURLWithPath: ACLWhiteListFilePath), options: .atomic)
        try AutoACL.data(using: String.Encoding.utf8)?
            .write(to: URL(fileURLWithPath: ACLGFWListFilePath), options: .atomic)
    } catch {
        
    }
}
func UpdateACL(){
    if !FileManager.default.fileExists(atPath: PACRulesDirPath) {
        do {
            try FileManager.default.createDirectory(atPath: PACRulesDirPath
                , withIntermediateDirectories: true, attributes: nil)
        } catch {
        }
    }
    let timeout = DispatchTime.now()+2
    let queue = DispatchQueue(label: "UpdateALCLists")
    let group = DispatchGroup()
    queue.async(group: group, qos: .default) {
        if let url = UserDefaults.standard.string(forKey: USERDEFAULTS_ACL_WHITE_LIST_URL) {
            group.enter()
            AF.request(url).responseString { response in
                do {
                    let value = try response.result.get()
                    try value.write(toFile: ACLWhiteListFilePath, atomically: true, encoding: String.Encoding.utf8)
                    if GeneratePACFile() {
                        // Popup a user notification
                        let notification = NSUserNotification()
                        notification.title = "White List update succeed.".localized
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                    group.leave()
                } catch {
                    // Popup a user notification
                    let notification = NSUserNotification()
                    notification.title = "Failed to download latest White List update succeed.".localized
                    NSUserNotificationCenter.default.deliver(notification)
                    group.leave()
                }
            }
            let _ = group.wait(timeout: timeout)
        }
    }
    queue.async(group: group, qos: .default) {
        if let IPURL = UserDefaults.standard.string(forKey: USERDEFAULTS_ACL_AUTO_LIST_URL) {
            group.enter()
            AF.request(IPURL).responseString { response in
                do {
                    let value = try response.result.get()
                    try value.write(toFile: ACLGFWListFilePath, atomically: true, encoding: String.Encoding.utf8)
                    if GeneratePACFile() {
                        // Popup a user notification
                        let notification = NSUserNotification()
                        notification.title = "Black List update succeed.".localized
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                    group.leave()
                } catch {
                    // Popup a user notification
                    let notification = NSUserNotification()
                    notification.title = "Failed to download latest Black List update succeed.".localized
                    NSUserNotificationCenter.default.deliver(notification)
                    group.leave()
                }
            }
            let _ = group.wait(timeout: timeout)
        }
    }
    queue.async(group: group, qos: .default) {
        if let backURL = UserDefaults.standard.string(forKey: USERDEFAULTS_ACL_PROXY_BACK_CHN_URL) {
            group.enter()
            AF.request(backURL).responseString { response in
                do {
                    let value = try response.result.get()
                    try value.write(toFile: ACLBackCHNFilePath, atomically: true, encoding: String.Encoding.utf8)
                    if GeneratePACFile() {
                        // Popup a user notification
                        let notification = NSUserNotification()
                        notification.title = "BackCHN List update succeed.".localized
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                    group.leave()
                }catch {
                    // Popup a user notification
                    let notification = NSUserNotification()
                    notification.title = "Failed to download latest BackCHN List update succeed.".localized
                    NSUserNotificationCenter.default.deliver(notification)
                    group.leave()
                }
            }
            let _ = group.wait(timeout: timeout)
        }
    }
}
