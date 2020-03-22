//
//  AppDelegate.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/5.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    
    // MARK: Controllers
    var qrcodeWinCtrl: SWBQRCodeWindowController!
    var preferencesWinCtrl: PreferencesWindowController!
    var advPreferencesWinCtrl: AdvPreferencesWindowController!
    var proxyPreferencesWinCtrl: ProxyPreferencesNewController!
    var editUserRulesWinCtrl: UserRulesController!
    var httpPreferencesWinCtrl : HTTPPreferencesWindowController!
    var subscribePreferenceWinCtrl: SubscribePreferenceWindowController!
    var toastWindowCtrl: ToastWindowController!
    
    var launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController()
    
    // MARK: Outlets
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    
    @IBOutlet weak var runningStatusMenuItem: NSMenuItem!
    @IBOutlet weak var toggleRunningMenuItem: NSMenuItem!
    @IBOutlet weak var proxyMenuItem: NSMenuItem!
    @IBOutlet weak var autoModeMenuItem: NSMenuItem!
    @IBOutlet weak var globalModeMenuItem: NSMenuItem!
    @IBOutlet weak var manualModeMenuItem: NSMenuItem!
    @IBOutlet weak var whiteListModeMenuItem: NSMenuItem!
    @IBOutlet weak var ACLModeMenuItem: NSMenuItem!
    @IBOutlet weak var ACLAutoModeMenuItem: NSMenuItem!
    @IBOutlet weak var ACLBackChinaMenuItem: NSMenuItem!
    
    @IBOutlet weak var serversMenuItem: NSMenuItem!
    @IBOutlet var pingserverMenuItem: NSMenuItem!
    @IBOutlet var showQRCodeMenuItem: NSMenuItem!
    @IBOutlet var scanQRCodeMenuItem: NSMenuItem!
    @IBOutlet var showBunchJsonExampleFileItem: NSMenuItem!
    @IBOutlet var importBunchJsonFileItem: NSMenuItem!
    @IBOutlet var exportAllServerProfileItem: NSMenuItem!
    @IBOutlet var serversPreferencesMenuItem: NSMenuItem!
    
    @IBOutlet var copyHttpProxyExportCmdLineMenuItem: NSMenuItem!
    
    @IBOutlet weak var lanchAtLoginMenuItem: NSMenuItem!
    @IBOutlet weak var connectAtLaunchMenuItem: NSMenuItem!
    @IBOutlet weak var ShowNetworkSpeedItem: NSMenuItem!
    @IBOutlet weak var checkUpdateMenuItem: NSMenuItem!
    @IBOutlet weak var checkUpdateAtLaunchMenuItem: NSMenuItem!
    @IBOutlet var updateSubscribeAtLaunchMenuItem: NSMenuItem!
    @IBOutlet var manualUpdateSubscribeMenuItem: NSMenuItem!
    @IBOutlet var editSubscribeMenuItem: NSMenuItem!
    
    @IBOutlet weak var copyCommandLine: NSMenuItem!
    
    
    // MARK: Variables
    var statusItemView:StatusItemView!
    var statusItem: NSStatusItem?
    var speedMonitor:NetSpeedMonitor?
    var globalSubscribeFeed: Subscribe!
    
    var speedTimer:Timer?
    let repeatTimeinterval: TimeInterval = 1.0

    // MARK: Application function

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        NSUserNotificationCenter.default.delegate = self
        
        // Prepare ss-local
        InstallSSLocal()
        InstallPrivoxy()
        // Prepare defaults
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "ShadowsocksOn": true,
            "ShadowsocksRunningMode": "auto",
            "LocalSocks5.ListenPort": NSNumber(value: 1086 as UInt16),
            "LocalSocks5.ListenAddress": "127.0.0.1",
            "PacServer.ListenAddress": "127.0.0.1",
            "PacServer.ListenPort":NSNumber(value: 8090 as UInt16),
            "LocalSocks5.Timeout": NSNumber(value: 60 as UInt),
            "LocalSocks5.EnableUDPRelay": NSNumber(value: false as Bool),
            "LocalSocks5.EnableVerboseMode": NSNumber(value: false as Bool),
            "GFWListURL": "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt",
            "ACLWhiteListURL": "https://raw.githubusercontent.com/shadowsocks/shadowsocks-libev/master/acl/chn.acl",
            "ACLAutoListURL": "https://raw.githubusercontent.com/shadowsocks/shadowsocks-libev/master/acl/gfwlist.acl",
            "ACLProxyBackCHNURL":"https://raw.githubusercontent.com/shadowsocks/shadowsocks-libev/master/acl/server_block_chn.acl",
            "AutoConfigureNetworkServices": NSNumber(value: true as Bool),
            "LocalHTTP.ListenAddress": "127.0.0.1",
            "LocalHTTP.ListenPort": NSNumber(value: 1087 as UInt16),
            "LocalHTTPOn": true,
            "LocalHTTP.FollowGlobal": true,
            "AutoCheckUpdate": false,
            "ACLFileName": "chn.acl",
            "Subscribes": [],
            "AutoUpdateSubscribe":false,
        ])

        setUpMenu(defaults.bool(forKey: "enable_showSpeed"))
        
//        statusItem = NSStatusBar.system.statusItem(withLength: 20)
//        let image = NSImage(named: "menu_icon")
//        image?.isTemplate = true
//        statusItem?.image = image
//        statusItem?.menu = statusMenu

        let notifyCenter = NotificationCenter.default
        notifyCenter.addObserver(forName: NOTIFY_ADV_PROXY_CONF_CHANGED, object: nil, queue: nil
            , using: {
            (note) in
                self.applyConfig()
                self.updateCopyHttpProxyExportMenu()
            }
        )
        notifyCenter.addObserver(forName: NOTIFY_SERVER_PROFILES_CHANGED, object: nil, queue: nil
            , using: {
            (note) in
                let profileMgr = ServerProfileManager.instance
                if profileMgr.getActiveProfileId() == "" &&
                    profileMgr.profiles.count > 0{
                    if profileMgr.profiles[0].isValid(){
                        profileMgr.setActiveProfiledId(profileMgr.profiles[0].uuid)
                    }
                }
                self.updateServersMenu()
                self.updateMainMenu()
                self.updateRunningModeMenu()
                SyncSSLocal()
            }
        )
        notifyCenter.addObserver(forName: NOTIFY_ADV_CONF_CHANGED, object: nil, queue: nil
            , using: {
            (note) in
                SyncSSLocal()
                self.applyConfig()
            }
        )
        notifyCenter.addObserver(forName: NOTIFY_HTTP_CONF_CHANGED, object: nil, queue: nil
            , using: {
                (note) in
                SyncPrivoxy()
                self.applyConfig()
            }
        )
        notifyCenter.addObserver(forName: NOTIFY_FOUND_SS_URL, object: nil, queue: nil) {
            (note: Notification) in
            self.foundSSRURL(note)
        }
        
        // Handle ss url scheme
        NSAppleEventManager.shared().setEventHandler(self
            , andSelector: #selector(self.handleURLEvent)
            , forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        
        updateMainMenu()
        updateCopyHttpProxyExportMenu()
        updateServersMenu()
        updateRunningModeMenu()
        updateLaunchAtLoginMenu()
        
        ProxyConfHelper.install()
        applyConfig()
//        SyncSSLocal()

        if defaults.bool(forKey: "ConnectAtLaunch") && ServerProfileManager.instance.getActiveProfileId() != "" {
            defaults.set(false, forKey: "ShadowsocksOn")
            defaults.synchronize()
            toggleRunning(toggleRunningMenuItem)
        }
        
        DispatchQueue.global().async {
            // Version Check!
            if defaults.bool(forKey: "AutoCheckUpdate") {
                self.checkForUpdate(mustShowAlert: false)
            }
            if defaults.bool(forKey: "AutoUpdateSubscribe") {
                SubscribeManager.instance.updateAllServerFromSubscribe(auto: true)
            }
            DispatchQueue.main.async {

            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        self.stopSSR()
        //如果设置了开机启动软件，就不删了
        if launchAtLoginController.launchAtLogin == false {
            RemoveSSLocal()
            RemovePrivoxy()
        }
    }
    
    private func stopSSR() {
        StopSSLocal()
        StopPrivoxy()
        ProxyConfHelper.stopPACServer()
        ProxyConfHelper.disableProxy("hi")
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "ShadowsocksOn")
        defaults.synchronize()
    }
    
    func applyConfig() {
        let defaults = UserDefaults.standard
        let isOn = defaults.bool(forKey: "ShadowsocksOn")
        let mode = defaults.string(forKey: "ShadowsocksRunningMode")
        
        if isOn {
            StartSSLocal()
            StartPrivoxy()
            if mode == "auto" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.enablePACProxy("hi")
            } else if mode == "global" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.enableGlobalProxy()
            } else if mode == "manual" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.disableProxy("hi")
            } else if mode == "whiteList" {
                ProxyConfHelper.disableProxy("hi")
                ProxyConfHelper.enableWhiteListProxy()//新白名单基于GlobalMode
            }
        } else {
            self.stopSSR()
        }

    }
    
    // MARK: Mainmenu functions
    
    @IBAction func toggleRunning(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: "ShadowsocksOn"), forKey: "ShadowsocksOn")
        defaults.synchronize()
        updateMainMenu()
        SyncSSLocal()
        applyConfig()
    }

    @IBAction func updateGFWList(_ sender: NSMenuItem) {
        UpdatePACFromGFWList()
    }
    
    @IBAction func updateWhiteList(_ sender: NSMenuItem) {
        UpdateACL()
    }
    
    @IBAction func editUserRulesForPAC(_ sender: NSMenuItem) {
        if editUserRulesWinCtrl != nil {
            editUserRulesWinCtrl.close()
        }
        let ctrl = UserRulesController(windowNibName: "UserRulesController")
        editUserRulesWinCtrl = ctrl

        ctrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func editSubscribeFeed(_ sender: NSMenuItem) {
        if subscribePreferenceWinCtrl != nil {
            subscribePreferenceWinCtrl.close()
        }
        let ctrl = SubscribePreferenceWindowController(windowNibName: "SubscribePreferenceWindowController")
        subscribePreferenceWinCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func toggleLaunghAtLogin(_ sender: NSMenuItem) {
        //开机启动功能在Mac OS 10.11之后就失效了，因此这个选项其实是没有用的。。
        //要添加这个功能需要使用辅助应用，详情见：
        //https://hechen.xyz/post/autostartwhenlogin/
        launchAtLoginController.launchAtLogin = !launchAtLoginController.launchAtLogin;
        updateLaunchAtLoginMenu()
    }
    
    @IBAction func toggleConnectAtLaunch(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: "ConnectAtLaunch"), forKey: "ConnectAtLaunch")
        defaults.synchronize()
        updateMainMenu()
    }
    
    
    @IBAction func toggleCopyCommandLine(_ sender: NSMenuItem) {
        // Get the Http proxy config.
        let defaults = UserDefaults.standard
        let address = defaults.string(forKey: "LocalHTTP.ListenAddress")
        let port = defaults.integer(forKey: "LocalHTTP.ListenPort")
        
        if let a = address {
            let command = "export http_proxy=http://\(a):\(port);export https_proxy=http://\(a):\(port);"
            
            // Copy to paste board.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: NSPasteboard.PasteboardType.string)
            
            // Show a toast notification.
            self.makeToast("Export Command Copied.".localized)
        } else {
            self.makeToast("Export Command Copied Failed.".localized)
        }
    }
    
    // MARK: Server submenu function

    @IBAction func showQRCodeForCurrentServer(_ sender: NSMenuItem) {
        var errMsg: String?
        if let profile = ServerProfileManager.instance.getActiveProfile() {
            if profile.isValid() {
                // Show window
                DispatchQueue.global().async {
                    if self.qrcodeWinCtrl != nil{
                        self.qrcodeWinCtrl.close()
                    }
                    self.qrcodeWinCtrl = SWBQRCodeWindowController(windowNibName: "SWBQRCodeWindowController")
                    self.qrcodeWinCtrl.qrCode = profile.URL()!.absoluteString
                    self.qrcodeWinCtrl.title = profile.title()
                    DispatchQueue.main.async {
                        self.qrcodeWinCtrl.showWindow(self)
                        NSApp.activate(ignoringOtherApps: true)
                        self.qrcodeWinCtrl.window?.makeKeyAndOrderFront(nil)
                    }
                }
                return
            } else {
                errMsg = "Current server profile is not valid.".localized
            }
        } else {
            errMsg = "No current server profile.".localized
        }
        let userNote = NSUserNotification()
        userNote.title = errMsg
        userNote.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default
            .deliver(userNote);
    }
    
    @IBAction func scanQRCodeFromScreen(_ sender: NSMenuItem) {
        ScanQRCodeOnScreen()
    }
    
    @IBAction func importProfileURLFromPasteboard(_ sender: NSMenuItem) {
        let pb = NSPasteboard.general
        if #available(OSX 10.13, *) {
            if let text = pb.string(forType: NSPasteboard.PasteboardType.URL) {
                if let url = URL(string: text) {
                    NotificationCenter.default.post(
                        name: NOTIFY_FOUND_SS_URL, object: nil
                        , userInfo: [
                            "urls": [url],
                            "source": "pasteboard",
                            ])
                }
            }
        }
        if let text = pb.string(forType: NSPasteboard.PasteboardType.string) {
            var urls = text.components(separatedBy: CharacterSet(charactersIn: "\n,"))
                .map { String($0).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .map { URL(string: $0) }
                .filter { $0 != nil }
                .map { $0! }
            urls = urls.filter { $0.scheme == "ssr" || $0.scheme == "ss" }
            
            NotificationCenter.default.post(
                name: NOTIFY_FOUND_SS_URL, object: nil
                , userInfo: [
                    "urls": urls,
                    "source": "pasteboard",
                    ])
        }
    }
    
    @IBAction func showBunchJsonExampleFile(_ sender: NSMenuItem) {
        ServerProfileManager.showExampleConfigFile()
    }
    
    @IBAction func importBunchJsonFile(_ sender: NSMenuItem) {
        ServerProfileManager.instance.importConfigFile()
        //updateServersMenu()//not working
    }
    
    @IBAction func exportAllServerProfile(_ sender: NSMenuItem) {
        ServerProfileManager.instance.exportConfigFile()
    }
    
    @IBAction func updateSubscribe(_ sender: NSMenuItem) {
        SubscribeManager.instance.updateAllServerFromSubscribe(auto: false)
    }
    
    @IBAction func updateSubscribeAtLaunch(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: "AutoUpdateSubscribe"), forKey: "AutoUpdateSubscribe")
        defaults.synchronize()
        updateSubscribeAtLaunchMenuItem.state = NSControl.StateValue(rawValue: defaults.bool(forKey: "AutoUpdateSubscribe") ? 1 : 0)
    }
    
    
    // MARK: Proxy submenu function

    @IBAction func selectPACMode(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.setValue("auto", forKey: "ShadowsocksRunningMode")
        defaults.setValue("", forKey: "ACLFileName")
        defaults.synchronize()
        updateRunningModeMenu()
        SyncSSLocal()
        applyConfig()
    }
    
    @IBAction func selectGlobalMode(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.setValue("global", forKey: "ShadowsocksRunningMode")
        defaults.setValue("", forKey: "ACLFileName")
        defaults.synchronize()
        updateRunningModeMenu()
        SyncSSLocal()
        applyConfig()
    }
    
    @IBAction func selectManualMode(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.setValue("manual", forKey: "ShadowsocksRunningMode")
        defaults.setValue("", forKey: "ACLFileName")
        defaults.synchronize()
        updateRunningModeMenu()
        SyncSSLocal()
        applyConfig()
    }
    @IBAction func selectACLAutoMode(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.setValue("whiteList", forKey: "ShadowsocksRunningMode")
        defaults.setValue("gfwlist.acl", forKey: "ACLFileName")
        defaults.synchronize()
        updateRunningModeMenu()
        SyncSSLocal()
        applyConfig()
    }
    @IBAction func selectACLBackCHNMode(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.setValue("whiteList", forKey: "ShadowsocksRunningMode")
        defaults.setValue("backchn.acl", forKey: "ACLFileName")
        defaults.synchronize()
        updateRunningModeMenu()
        SyncSSLocal()
        applyConfig()
    }
    @IBAction func selectWhiteListMode(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.setValue("whiteList", forKey: "ShadowsocksRunningMode")
        defaults.setValue("chn.acl", forKey: "ACLFileName")
        defaults.synchronize()
        updateRunningModeMenu()
        SyncSSLocal()
        applyConfig()
    }

    @IBAction func editServerPreferences(_ sender: NSMenuItem) {
        if preferencesWinCtrl != nil {
            preferencesWinCtrl.close()
        }
        let ctrl = PreferencesWindowController(windowNibName: "PreferencesWindowController")
        preferencesWinCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func editAdvPreferences(_ sender: NSMenuItem) {
        if advPreferencesWinCtrl != nil {
            advPreferencesWinCtrl.close()
        }
        let ctrl = AdvPreferencesWindowController(windowNibName: "AdvPreferencesWindowController")
        advPreferencesWinCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func editHTTPPreferences(_ sender: NSMenuItem) {
        if httpPreferencesWinCtrl != nil {
            httpPreferencesWinCtrl.close()
        }
        let ctrl = HTTPPreferencesWindowController(windowNibName: "HTTPPreferencesWindowController")
        httpPreferencesWinCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func editProxyPreferences(_ sender: NSMenuItem) {
        if proxyPreferencesWinCtrl != nil {
            proxyPreferencesWinCtrl.close()
        }
        let ctrl = ProxyPreferencesNewController(windowNibName: "ProxyPreferencesNewController")
        proxyPreferencesWinCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func selectServer(_ sender: NSMenuItem) {
        let index = sender.tag
        let spMgr = ServerProfileManager.instance
        let newProfile = spMgr.profiles[index]
        if newProfile.uuid != spMgr.getActiveProfileId() {
            spMgr.setActiveProfiledId(newProfile.uuid)
            updateServersMenu()
            SyncSSLocal()
        }
        updateRunningModeMenu()
    }

    @IBAction func doPingTest(_ sender: AnyObject) {
        PingServers.instance.ping()
    }
    
    @IBAction func showSpeedTap(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        var enable = defaults.bool(forKey: "enable_showSpeed")
        enable = !enable
        setUpMenu(enable)
        defaults.set(enable, forKey: "enable_showSpeed")
        defaults.synchronize()
        updateMainMenu()
    }

    //https://git.codingcafe.org/Mirrors/shadowsocks/ShadowsocksX-NG/blob/d56b108eb8a8087337b2c9c9ccc6743f5f9944a9/ShadowsocksX-NG/AppDelegate.swift
    @IBAction func showLogs2(_ sender: NSMenuItem) {
        let ws = NSWorkspace.shared
        if let appUrl = ws.urlForApplication(withBundleIdentifier: "com.apple.Console") {
            try! ws.launchApplication(at: appUrl
                ,options: .default
                ,configuration: convertToNSWorkspaceLaunchConfigurationKeyDictionary([convertFromNSWorkspaceLaunchConfigurationKey(NSWorkspace.LaunchConfigurationKey.arguments): "~/Library/Logs/ss-local.log"]))
        }
    }
    @IBAction func showLogs(_ sender: NSMenuItem) {
        let ws = NSWorkspace.shared
        if let appUrl = ws.urlForApplication(withBundleIdentifier: "com.apple.Console") {
            try! ws.launchApplication(at: appUrl
                ,options: NSWorkspace.LaunchOptions.default
                ,configuration: [NSWorkspace.LaunchConfigurationKey.arguments: "~/Library/Logs/ss-local.log"])
        }
    }

    
    @IBAction func feedback(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: "https://github.com/paradiseduo/ShadowsocksX-NG-R8/issues")!)
    }
    
    @IBAction func checkForUpdate(_ sender: NSMenuItem) {
        checkForUpdate(mustShowAlert: true)
    }
    
    @IBAction func checkUpdatesAtLaunch(_ sender: NSMenuItem) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: "AutoCheckUpdate"), forKey: "AutoCheckUpdate")
        defaults.synchronize()
        checkUpdateAtLaunchMenuItem.state = NSControl.StateValue(rawValue: defaults.bool(forKey: "AutoCheckUpdate") ? 1 : 0)
    }
    
    @IBAction func showAbout(_ sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel(sender);
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func updateLaunchAtLoginMenu() {
        lanchAtLoginMenuItem.state = NSControl.StateValue(rawValue: launchAtLoginController.launchAtLogin ? 1 : 0)
    }
    
    // MARK: this function is use to update menu bar

    func updateRunningModeMenu() {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: "ShadowsocksRunningMode")
        var serverMenuText = "Servers".localized
        
        let mgr = ServerProfileManager.instance
        for p in mgr.profiles {
            if mgr.getActiveProfileId() == p.uuid {
                if !p.remark.isEmpty {
                    serverMenuText = p.remark
                } else {
                    serverMenuText = p.serverHost
                }
                if let latency = p.latency{
                    serverMenuText += "  - \(latency) ms"
                }
                else{
                    if !neverSpeedTestBefore {
                        serverMenuText += "  - failed"
                    }
                }
            }
        }

        serversMenuItem.title = serverMenuText
        autoModeMenuItem.state = convertToNSControlStateValue(0)
        globalModeMenuItem.state = convertToNSControlStateValue(0)
        manualModeMenuItem.state = convertToNSControlStateValue(0)
        whiteListModeMenuItem.state = convertToNSControlStateValue(0)
        ACLBackChinaMenuItem.state = convertToNSControlStateValue(0)
        ACLAutoModeMenuItem.state = convertToNSControlStateValue(0)
        ACLModeMenuItem.state = convertToNSControlStateValue(0)
        if mode == "auto" {
            autoModeMenuItem.state = convertToNSControlStateValue(1)
        } else if mode == "global" {
            globalModeMenuItem.state = convertToNSControlStateValue(1)
        } else if mode == "manual" {
            manualModeMenuItem.state = convertToNSControlStateValue(1)
        } else if mode == "whiteList" {
            let aclMode = defaults.string(forKey: "ACLFileName")!
            switch aclMode {
            case "backchn.acl":
                ACLModeMenuItem.state = convertToNSControlStateValue(1)
                ACLBackChinaMenuItem.state = convertToNSControlStateValue(1)
                ACLModeMenuItem.title = "Proxy Back China".localized
                break
            case "gfwlist.acl":
                ACLModeMenuItem.state = convertToNSControlStateValue(1)
                ACLAutoModeMenuItem.state = convertToNSControlStateValue(1)
                ACLModeMenuItem.title = "ACL Auto".localized
                break
            default:
                whiteListModeMenuItem.state = convertToNSControlStateValue(1)
            }
        }
        updateStatusItemUI()
    }
    
    func updateStatusItemUI() {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: "ShadowsocksRunningMode")
        if !defaults.bool(forKey: "ShadowsocksOn") {
            return
        }
        let titleWidth:CGFloat = 0//statusItem?.title!.size(withAttributes: [NSFontAttributeName: statusItem?.button!.font!]).width//这里不包含IP白名单模式等等，需要重新调整//PS还是给上游加上白名单模式？
        let imageWidth:CGFloat = 22
        //        statusItem?.length = titleWidth + imageWidth
        if statusItemView != nil {
            statusItemView.setIconWith(mode: mode)
        } else {
            statusItem?.length = titleWidth + imageWidth
        }
    }
    
    func updateMainMenu() {
        let defaults = UserDefaults.standard
        let isOn = defaults.bool(forKey: "ShadowsocksOn")
        if isOn {
            runningStatusMenuItem.title = "Shadowsocks: On".localized
            runningStatusMenuItem.image = NSImage(named: NSImage.statusAvailableName)
            toggleRunningMenuItem.title = "Turn Shadowsocks Off".localized
            //image = NSImage(named: "menu_icon")!
            copyCommandLine.isHidden = false
            updateStatusItemUI()
        } else {
            runningStatusMenuItem.title = "Shadowsocks: Off".localized
            runningStatusMenuItem.image = NSImage(named: NSImage.statusUnavailableName)
            toggleRunningMenuItem.title = "Turn Shadowsocks On".localized
            copyCommandLine.isHidden = true
            if statusItemView != nil {
                statusItemView.setIconWith(mode: "disabled")
            }
        }
        
        ShowNetworkSpeedItem.state          = NSControl.StateValue(rawValue: defaults.bool(forKey: "enable_showSpeed") ? 1 : 0)
        connectAtLaunchMenuItem.state       = NSControl.StateValue(rawValue: defaults.bool(forKey: "ConnectAtLaunch")  ? 1 : 0)
        checkUpdateAtLaunchMenuItem.state   = NSControl.StateValue(rawValue: defaults.bool(forKey: "AutoCheckUpdate")  ? 1 : 0)
    }
    
    func updateCopyHttpProxyExportMenu() {
        let defaults = UserDefaults.standard
        let isOn = defaults.bool(forKey: "LocalHTTPOn")
        copyHttpProxyExportCmdLineMenuItem.isHidden = !isOn
    }
    
    //TODO:https://git.codingcafe.org/Mirrors/shadowsocks/ShadowsocksX-NG/blob/master/ShadowsocksX-NG/AppDelegate.swift
    func updateServersMenu() {
        let mgr = ServerProfileManager.instance
        serversMenuItem.submenu?.removeAllItems()
        let showQRItem = showQRCodeMenuItem
        let scanQRItem = scanQRCodeMenuItem
        let preferencesItem = serversPreferencesMenuItem
        let showBunch = showBunchJsonExampleFileItem
        let importBuntch = importBunchJsonFileItem
        let exportAllServer = exportAllServerProfileItem
        let updateSubscribeItem = manualUpdateSubscribeMenuItem
        let autoUpdateSubscribeItem = updateSubscribeAtLaunchMenuItem
        let editSubscribeItem = editSubscribeMenuItem
        let copyHttpProxyExportCmdLineItem = copyHttpProxyExportCmdLineMenuItem
        //        let pingItem = pingserverMenuItem
        
        serversMenuItem.submenu?.addItem(editSubscribeItem!)
        serversMenuItem.submenu?.addItem(autoUpdateSubscribeItem!)
        autoUpdateSubscribeItem?.state = NSControl.StateValue(rawValue: UserDefaults.standard.bool(forKey: "AutoUpdateSubscribe") ? 1 : 0)
        serversMenuItem.submenu?.addItem(updateSubscribeItem!)
        serversMenuItem.submenu?.addItem(showQRItem!)
        serversMenuItem.submenu?.addItem(scanQRItem!)
        serversMenuItem.submenu?.addItem(copyHttpProxyExportCmdLineItem!)
        serversMenuItem.submenu?.addItem(showBunch!)
        serversMenuItem.submenu?.addItem(importBuntch!)
        serversMenuItem.submenu?.addItem(exportAllServer!)
        serversMenuItem.submenu?.addItem(NSMenuItem.separator())
        serversMenuItem.submenu?.addItem(preferencesItem!)
        //        serversMenuItem.submenu?.addItem(pingItem)
        
        if !mgr.profiles.isEmpty {
            serversMenuItem.submenu?.addItem(NSMenuItem.separator())
        }
        
        var i = 0
        var serverMenuItems = [NSMenuItem]()
        var fastTime = ""
        if let t = UserDefaults.standard.object(forKey: "FastestNode") as? String {
            fastTime = t
        }
        
        for p in mgr.profiles {
            let item = NSMenuItem()
            item.tag = i //+ kProfileMenuItemIndexBase
            item.title = p.title()
            if let latency = p.latency {
                item.title += "  - \(latency) ms"
                if latency == fastTime {
                    let dic = [NSAttributedString.Key.foregroundColor : NSColor.green]
                    let attStr = NSAttributedString(string: item.title, attributes: dic)
                    item.attributedTitle = attStr
                }
            }else{
                if !neverSpeedTestBefore {
                    item.title += "  - failed"
                    let dic = [NSAttributedString.Key.foregroundColor : NSColor.red]
                    let attStr = NSAttributedString(string: item.title, attributes: dic)
                    item.attributedTitle = attStr
                }
            }
            if mgr.getActiveProfileId() == p.uuid {
                item.state = convertToNSControlStateValue(1)
            }
            if !p.isValid() {
                item.isEnabled = false
            }
            
            item.action = #selector(AppDelegate.selectServer)
            
            if !p.ssrGroup.isEmpty {
                if((serversMenuItem.submenu?.item(withTitle: p.ssrGroup)) == nil){
                    let groupSubmenu = NSMenu()
                    let groupSubmenuItem = NSMenuItem()
                    groupSubmenuItem.title = p.ssrGroup
                    serversMenuItem.submenu?.addItem(groupSubmenuItem)
                    serversMenuItem.submenu?.setSubmenu(groupSubmenu, for: groupSubmenuItem)
                    if mgr.getActiveProfileId() == p.uuid {
                        item.state = convertToNSControlStateValue(1)
                        groupSubmenuItem.state = convertToNSControlStateValue(1)
                    }
                    groupSubmenuItem.submenu?.addItem(item)
                    i += 1
                    continue
                }
                else{
                    if mgr.getActiveProfileId() == p.uuid {
                        item.state = convertToNSControlStateValue(1)
                        serversMenuItem.submenu?.item(withTitle: p.ssrGroup)?.state = convertToNSControlStateValue(1)
                    }
                    serversMenuItem.submenu?.item(withTitle: p.ssrGroup)?.submenu?.addItem(item)
                    i += 1
                    continue
                }
            }
            
//            serversMenuItem.submenu?.addItem(item)
            serverMenuItems.append(item)
            i += 1
        }
        // 把没有分组的放到最下面，如果有100个服务器的时候对用户很有用
        for item in serverMenuItems {
            serversMenuItem.submenu?.addItem(item)
        }
    }
    
    func setUpMenu(_ showSpeed:Bool){
        // should not operate the system status bar
        // we can add sub menu like bittorrent sync
        if statusItem == nil{
            statusItem = NSStatusBar.system.statusItem(withLength: 85)
            let image = NSImage(named: "menu_icon")
            image?.isTemplate = true
            statusItem?.image = image
            statusItemView = StatusItemView(statusItem: statusItem!, menu: statusMenu)
            statusItem!.view = statusItemView
        }
        statusItemView.showSpeed = showSpeed
        if showSpeed{
            if speedMonitor == nil{
                speedMonitor = NetSpeedMonitor()
            }
            statusItem?.length = 85
            speedTimer = Timer.scheduledTimer(withTimeInterval: repeatTimeinterval, repeats: true, block: {[weak self] (timer) in
                guard let w = self else {return}
                w.speedMonitor?.downloadAndUploadSpeed({ (down, up) in
                    w.statusItemView.setRateData(up: Float(up), down: Float(down))
                })
            })
        }else{
            speedTimer?.invalidate()
            speedTimer = nil
            speedMonitor = nil
            statusItem?.length = 20
        }
    }
    
    func checkForUpdate(mustShowAlert: Bool) -> Void {
        let versionChecker = VersionChecker()
        DispatchQueue.global().async {
            let newVersion = versionChecker.checkNewVersion()
            DispatchQueue.main.async {
                if (mustShowAlert || newVersion["newVersion"] as! Bool){
                    let alertResult = versionChecker.showAlertView(Title: newVersion["Title"] as! String, SubTitle: newVersion["SubTitle"] as! String, ConfirmBtn: newVersion["ConfirmBtn"] as! String, CancelBtn: newVersion["CancelBtn"] as! String)
                    print(alertResult)
                    if (newVersion["newVersion"] as! Bool && alertResult == 1000){
                        NSWorkspace.shared.open(URL(string: "https://github.com/paradiseduo/ShadowsocksX-NG-R8/releases")!)
                    }
                }
            }
        }
    }
    
    // MARK:

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue {
            if URL(string: urlString) != nil {
                NotificationCenter.default.post(
                    name: NOTIFY_FOUND_SS_URL, object: nil
                    , userInfo: [
                        "urls": splitProfile(url: urlString, max: 5).map({ (item: String) -> URL in
                            return URL(string: item)!
                        }),
                        "source": "url",
                    ])
            }
        }
    }
    
    private func foundSSRURL(_ note: Notification) {
        if let userInfo = (note as NSNotification).userInfo {
            let urls: [URL] = userInfo["urls"] as! [URL]
            
            let mgr = ServerProfileManager.instance
            var isChanged = false
            
            for url in urls {
                let profielDict = ParseAppURLSchemes(url)//ParseSSURL(url)
                if let profielDict = profielDict {
                    let profile = ServerProfile.fromDictionary(profielDict as [String : AnyObject])
                    mgr.profiles.append(profile)
                    isChanged = true
                    
                    let userNote = NSUserNotification()
                    userNote.title = "Add Shadowsocks Server Profile".localized
                    if userInfo["source"] as! String == "qrcode" {
                        userNote.subtitle = "By scan QR Code".localized
                    } else if userInfo["source"] as! String == "url" {
                        userNote.subtitle = "By Handle SS URL".localized
                    }
                    userNote.informativeText = "Host: \(profile.serverHost)\n Port: \(profile.serverPort)\n Encription Method: \(profile.method)".localized
                    userNote.soundName = NSUserNotificationDefaultSoundName
                    
                    NSUserNotificationCenter.default.deliver(userNote);
                }else{
                    let userNote = NSUserNotification()
                    userNote.title = "Failed to Add Server Profile".localized
                    userNote.subtitle = "Address can not be recognized".localized
                    NSUserNotificationCenter.default.deliver(userNote);
                }
            }
            if isChanged {
                mgr.save()
                self.updateServersMenu()
            }
        }
    }
    
    //------------------------------------------------------------
    // MARK: NSUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: NSUserNotificationCenter
        , shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    func makeToast(_ message: String) {
        if toastWindowCtrl != nil {
            toastWindowCtrl.close()
        }
        
        toastWindowCtrl = ToastWindowController(windowNibName: NSNib.Name("ToastWindowController"))
        toastWindowCtrl.message = message
        toastWindowCtrl.showWindow(self)
        //NSApp.activate(ignoringOtherApps: true)
        //toastWindowCtrl.window?.makeKeyAndOrderFront(self)
        toastWindowCtrl.fadeInHud()
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSWorkspaceLaunchConfigurationKeyDictionary(_ input: [String: Any]) -> [NSWorkspace.LaunchConfigurationKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSWorkspace.LaunchConfigurationKey(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSWorkspaceLaunchConfigurationKey(_ input: NSWorkspace.LaunchConfigurationKey) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSControlStateValue(_ input: Int) -> NSControl.StateValue {
	return NSControl.StateValue(rawValue: input)
}
