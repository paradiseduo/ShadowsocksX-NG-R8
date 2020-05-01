//
//  BGUtils.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/6.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Foundation

let SS_LOCAL_VERSION = "2.5.6.12.static"
let PRIVOXY_VERSION = "3.0.28.static"
let APP_SUPPORT_DIR = "/Library/Application Support/ShadowsocksX-NG-R8/"
let LAUNCH_AGENT_DIR = "/Library/LaunchAgents/"
let LAUNCH_AGENT_CONF_SSLOCAL_NAME = "com.qiuyuzhou.shadowsocksX-NG.local.plist"
let LAUNCH_AGENT_CONF_PRIVOXY_NAME = "com.qiuyuzhou.shadowsocksX-NG.http.plist"


func getFileSHA1Sum(_ filepath: String) -> String {
    let fileMgr = FileManager.default
    if fileMgr.fileExists(atPath: filepath) {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: filepath)) {
            return data.sha1()
        }
    }
    return ""
}

// Ref: https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
// Genarate the mac launch agent service plist

//  MARK: sslocal

func generateSSLocalLauchAgentPlist() -> Bool {
    let sslocalPath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/ss-local.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_SSLOCAL_NAME
    var ACLFileName = ""
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    let defaults = UserDefaults.standard
    let enableUdpRelay = defaults.bool(forKey: USERDEFAULTS_LOCAL_SOCKS5_ENABLE_UDP_RELAY)
    let enableVerboseMode = defaults.bool(forKey: USERDEFAULTS_LOCAL_SOCKS5_ENABLE_VERBOSE_MODE)
    let enabelWhiteListMode = defaults.string(forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
    
    var arguments = [sslocalPath, "-c", "ss-local-config.json", "--fast-open"]
    if enableUdpRelay {
        arguments.append("-u")
    }
    if enableVerboseMode {
        arguments.append("-v")
    }
    if enabelWhiteListMode == "whiteList" {
        ACLFileName = defaults.string(forKey: USERDEFAULTS_ACL_FILE_NAME)!
        let ACLPath = NSHomeDirectory() + "/.ShadowsocksX-NG/" + ACLFileName
        arguments.append("--acl")
        arguments.append(ACLPath)
    }
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dict: NSMutableDictionary = [
        "Label": "com.qiuyuzhou.shadowsocksX-NG.local",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "KeepAlive": true,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments,
        "EnvironmentVariables": ["DYLD_LIBRARY_PATH": NSHomeDirectory() + APP_SUPPORT_DIR]
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}

func ReloadConfSSLocal(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "reload_conf_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start ss-local succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("Start ss-local failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func StartSSLocal(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start ss-local succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("Start ss-local failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func StopSSLocal(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop ss-local succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("Stop ss-local failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func InstallSSLocal(finish: @escaping(_ success: Bool)->()) {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "ss-local-\(SS_LOCAL_VERSION)/ss-local") || !fileMgr.fileExists(atPath: appSupportDir + "libcrypto.1.0.0.dylib") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_ss_local.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install ss-local succeeded.")
            DispatchQueue.main.async {
                finish(true)
            }
        } else {
            NSLog("Install ss-local failed.")
            DispatchQueue.main.async {
                finish(false)
            }
        }
    } else {
        finish(true)
    }
}

func RemoveSSLocal(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "remove_ss_local.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Remove ss-local succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("Remove ss-local failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func writeSSLocalConfFile(_ conf:[String:AnyObject]) -> Bool {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-config.json"
        var data: Data = try JSONSerialization.data(withJSONObject: conf, options: .prettyPrinted)
        
        // https://github.com/shadowsocks/ShadowsocksX-NG/issues/1104
        // This is NSJSONSerialization.dataWithJSONObject that likes to insert additional backslashes.
        // Escaped forward slashes is also valid json.
        let s = String(data:data, encoding: .utf8)!
        data = s.replacingOccurrences(of: "\\/", with: "/").data(using: .utf8)!
        
        let oldSum = getFileSHA1Sum(filepath)
        try data.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = getFileSHA1Sum(filepath)
        
        if oldSum == newSum {
            return false
        }
        
        return true
    } catch {
        NSLog("Write ss-local file failed.")
    }
    return false
}

func removeSSLocalConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "ss-local-config.json"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

func SyncSSLocal(finish: @escaping(_ success: Bool)->()) {
    func Sync(_ suc: Bool){
        SyncPrivoxy {
            SyncPac()
            finish(suc)
        }
    }
    var changed: Bool = false
    changed = changed || generateSSLocalLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if mgr.getActiveProfileId() != "" {
        if mgr.getActiveProfile() != nil {
            changed = changed || writeSSLocalConfFile((mgr.getActiveProfile()?.toJsonConfig())!)
        }
        if UserDefaults.standard.bool(forKey: USERDEFAULTS_SHADOWSOCKS_ON) {
            StartSSLocal { (s) in
                if s {
                    ReloadConfSSLocal { (suc) in
                        Sync(suc)
                    }
                } else {
                    Sync(false)
                }
            }
        } else {
            Sync(true)
        }
    } else {
        StopSSLocal { (s) in
            removeSSLocalConfFile()
            Sync(true)
        }
    }
}

//  MARK: privoxy

func generatePrivoxyLauchAgentPlist() -> Bool {
    let privoxyPath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy"
    let logFilePath = NSHomeDirectory() + "/Library/Logs/privoxy.log"
    let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
    let plistFilepath = launchAgentDirPath + LAUNCH_AGENT_CONF_PRIVOXY_NAME
    
    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let oldSha1Sum = getFileSHA1Sum(plistFilepath)
    
    let arguments = [privoxyPath, "--no-daemon", "privoxy.config"]
    
    // For a complete listing of the keys, see the launchd.plist manual page.
    let dict: NSMutableDictionary = [
        "Label": "com.qiuyuzhou.shadowsocksX-NG.http",
        "WorkingDirectory": NSHomeDirectory() + APP_SUPPORT_DIR,
        "KeepAlive": true,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments,
        "EnvironmentVariables": ["DYLD_LIBRARY_PATH": NSHomeDirectory() + APP_SUPPORT_DIR]
    ]
    dict.write(toFile: plistFilepath, atomically: true)
    let Sha1Sum = getFileSHA1Sum(plistFilepath)
    if oldSha1Sum != Sha1Sum {
        return true
    } else {
        return false
    }
}


func ReloadConfPrivoxy(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "reload_conf_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("reload privoxy succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("reload privoxy failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func StartPrivoxy(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "start_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start privoxy succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("Start privoxy failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func StopPrivoxy(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "stop_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop privoxy succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("Stop privoxy failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func InstallPrivoxy(finish: @escaping(_ success: Bool)->()) {
    let fileMgr = FileManager.default
    let homeDir = NSHomeDirectory()
    let appSupportDir = homeDir+APP_SUPPORT_DIR
    if !fileMgr.fileExists(atPath: appSupportDir + "privoxy-\(PRIVOXY_VERSION)/privoxy") || !fileMgr.fileExists(atPath: appSupportDir + "libpcre.1.dylib") {
        let bundle = Bundle.main
        let installerPath = bundle.path(forResource: "install_privoxy.sh", ofType: nil)
        let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Install privoxy succeeded.")
            DispatchQueue.main.async {
                finish(true)
            }
        } else {
            NSLog("Install privoxy failed.")
            DispatchQueue.main.async {
                finish(false)
            }
        }
    } else {
        finish(true)
    }
}

func RemovePrivoxy(finish: @escaping(_ success: Bool)->()) {
    let bundle = Bundle.main
    let installerPath = bundle.path(forResource: "remove_privoxy.sh", ofType: nil)
    let task = Process.launchedProcess(launchPath: installerPath!, arguments: [""])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Remove privoxy succeeded.")
        DispatchQueue.main.async {
            finish(true)
        }
    } else {
        NSLog("Remove privoxy failed.")
        DispatchQueue.main.async {
            finish(false)
        }
    }
}

func writePrivoxyConfFile() -> Bool {
    do {
        let defaults = UserDefaults.standard
        let bundle = Bundle.main
        let examplePath = bundle.path(forResource: "privoxy.config.example", ofType: nil)
        var example = try String(contentsOfFile: examplePath!, encoding: .utf8)
        example = example.replacingOccurrences(of: "{http}", with: defaults.string(forKey: USERDEFAULTS_LOCAL_HTTP_LISTEN_ADDRESS)! + ":" + String(defaults.integer(forKey: USERDEFAULTS_LOCAL_HTTP_LISTEN_PORT)))
        example = example.replacingOccurrences(of: "{socks5}", with: defaults.string(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_ADDRESS)! + ":" + String(defaults.integer(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT)))
        let data = example.data(using: .utf8)
        
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        
        let oldSum = getFileSHA1Sum(filepath)
        try data?.write(to: URL(fileURLWithPath: filepath), options: .atomic)
        let newSum = getFileSHA1Sum(filepath)
        
        if oldSum == newSum {
            return false
        }
        
        return true
    } catch {
        NSLog("Write privoxy file failed.")
    }
    return false
}

func removePrivoxyConfFile() {
    do {
        let filepath = NSHomeDirectory() + APP_SUPPORT_DIR + "privoxy.config"
        try FileManager.default.removeItem(atPath: filepath)
    } catch {
        
    }
}

func SyncPrivoxy(finish: @escaping()->()) {
    var changed: Bool = false
    changed = changed || generatePrivoxyLauchAgentPlist()
    let mgr = ServerProfileManager.instance
    if mgr.getActiveProfileId() != "" {
        changed = changed || writePrivoxyConfFile()
        
        let on = UserDefaults.standard.bool(forKey: USERDEFAULTS_LOCAL_HTTP_ON)
        if on {
            ReloadConfPrivoxy { (success) in
                finish()
            }
        } else {
            StopPrivoxy { (success) in
                removePrivoxyConfFile()
                finish()
            }
        }
    } else {
        finish()
    }
}
