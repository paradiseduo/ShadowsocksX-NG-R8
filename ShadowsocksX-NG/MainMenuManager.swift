//
//  MainMenuManager.swift
//  ShadowsocksX-NG
//
//  Created by ParadiseDuo on 2020/4/18.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Cocoa

class MainMenuManager: NSObject, NSUserNotificationCenterDelegate {
    // MARK: Controllers
    var qrcodeWinCtrl: SWBQRCodeWindowController!
    var preferencesWinCtrl: PreferencesWindowController!
    var subscribePreferenceWinCtrl: SubscribePreferenceWindowController!
    var toastWindowCtrl: ToastWindowController!
    var settingWindowCtrl: SettingsWindowController!
    
    // MARK: Outlets
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var speedMenu: NSMenu!
    
    @IBOutlet weak var runningStatusMenuItem: NSMenuItem!
    @IBOutlet weak var toggleRunningMenuItem: NSMenuItem!
    @IBOutlet weak var autoModeMenuItem: NSMenuItem!
    @IBOutlet weak var globalModeMenuItem: NSMenuItem!
    @IBOutlet weak var manualModeMenuItem: NSMenuItem!
    @IBOutlet weak var whiteListModeMenuItem: NSMenuItem!
    @IBOutlet weak var ACLModeMenuItem: NSMenuItem!
    @IBOutlet weak var ACLAutoModeMenuItem: NSMenuItem!
    @IBOutlet weak var ACLBackChinaMenuItem: NSMenuItem!
    
    @IBOutlet weak var serversMenuItem: NSMenuItem!
    @IBOutlet var connectionDelayTestMenuItem: NSMenuItem!
    @IBOutlet var serversPreferencesMenuItem: NSMenuItem!
    @IBOutlet weak var copyHttpProxyExportCmdLineMenuItem: NSMenuItem!
            
    @IBOutlet weak var fixedWidth: NSMenuItem!
    
    // MARK: Variables
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var speedItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var speedMonitor:NetSpeedMonitor?
    var globalSubscribeFeed: Subscribe!
    
    var speedTimer:Timer?
    let repeatTimeinterval: TimeInterval = 2.0
    
    override func awakeFromNib() {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleURLEvent), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        
        NSUserNotificationCenter.default.delegate = self
        // Prepare ss-local
        InstallSSLocal { (s) in
            InstallPrivoxy { (ss) in
                ProxyConfHelper.install()
            }
        }
        
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            USERDEFAULTS_SHADOWSOCKS_ON: true,
            USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE: "auto",
            USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT: NSNumber(value: 1086 as UInt16),
            USERDEFAULTS_LOCAL_SOCKS5_LISTEN_ADDRESS: "127.0.0.1",
            USERDEFAULTS_PAC_SERVER_LISTEN_ADDRESS: "127.0.0.1",
            USERDEFAULTS_PAC_SERVER_LISTEN_PORT:NSNumber(value: 8090 as UInt16),
            USERDEFAULTS_LOCAL_SOCKS5_TIMEOUT: NSNumber(value: 60 as UInt),
            USERDEFAULTS_LOCAL_SOCKS5_ENABLE_UDP_RELAY: NSNumber(value: false as Bool),
            USERDEFAULTS_LOCAL_SOCKS5_ENABLE_VERBOSE_MODE: NSNumber(value: false as Bool),
            USERDEFAULTS_GFW_LIST_URL: "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt",
            USERDEFAULTS_ACL_WHITE_LIST_URL: "https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/banAD.acl",
            USERDEFAULTS_ACL_AUTO_LIST_URL: "https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/gfwlist-banAD.acl",
            USERDEFAULTS_ACL_PROXY_BACK_CHN_URL:"https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/backcn-banAD.acl",
            USERDEFAULTS_AUTO_CONFIGURE_NETWORK_SERVICES: NSNumber(value: true as Bool),
            USERDEFAULTS_LOCAL_HTTP_LISTEN_ADDRESS: "127.0.0.1",
            USERDEFAULTS_LOCAL_HTTP_LISTEN_PORT: NSNumber(value: 1087 as UInt16),
            USERDEFAULTS_LOCAL_HTTP_ON: true,
            USERDEFAULTS_LOCAL_HTTP_FOLLOW_GLOBAL: true,
            USERDEFAULTS_AUTO_CHECK_UPDATE: false,
            USERDEFAULTS_ACL_FILE_NAME: "chn.acl",
            USERDEFAULTS_SUBSCRIBES: [],
            USERDEFAULTS_AUTO_UPDATE_SUBSCRIBE:false,
            USERDEFAULTS_AUTO_UPDATE_SUBSCRIBE_WITH_PROXY:false,
            USERDEFAULTS_SPEED_TEST_AFTER_SUBSCRIPTION:true,
            USERDEFAULTS_FIXED_NETWORK_SPEED_VIEW_WIDTH:false,
            USERDEFAULTS_REMOVE_NODE_AFTER_DELETE_SUBSCRIPTION:false,
            USERDEFAULTS_SERVERS_LIST_SHOW_SERVER_AND_PORT:true,
            USERDEFAULTS_PROXY_EXCEPTIONS: "127.0.0.1,localhost,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,timestamp.apple.com"
        ])
        
        let notifyCenter = NotificationCenter.default
        notifyCenter.addObserver(forName: NOTIFY_SERVER_PROFILES_CHANGED, object: nil, queue: nil) { (noti) in
            let profileMgr = ServerProfileManager.instance
            if profileMgr.getActiveProfileId() == "" && profileMgr.profiles.count > 0 {
                if profileMgr.profiles[0].isValid(){
                    profileMgr.setActiveProfiledId(profileMgr.profiles[0].uuid)
                }
            }
            if profileMgr.profiles.count == 0 {
                //调用开关按钮自动翻转状态，因此这里传true
                UserDefaults.standard.set(true, forKey: USERDEFAULTS_SHADOWSOCKS_ON)
                UserDefaults.standard.synchronize()
                self.toggle { (suc) in
                    self.refresh()
                }
            } else {
                SyncSSLocal { (suce) in
                    self.refresh()
                }
            }
        }
        notifyCenter.addObserver(forName: NOTIFY_ADV_CONF_CHANGED, object: nil, queue: nil) { (noti) in
            Network.refreshProxySession()
            SyncSSLocal { (suce) in
                MainMenuManager.applyConfig { (s) in
                    self.refresh()
                }
            }
        }
        notifyCenter.addObserver(forName: NOTIFY_HTTP_CONF_CHANGED, object: nil, queue: nil) { (noti) in
            SyncPrivoxy {
                MainMenuManager.applyConfig { (s) in
                    self.refresh()
                }
            }
        }
        notifyCenter.addObserver(forName: NOTIFY_FOUND_SS_URL, object: nil, queue: nil) { (noti: Notification) in
            self.foundSSRURL(noti)
        }
        notifyCenter.addObserver(forName: NOTIFY_UPDATE_MAINMENU, object: nil, queue: OperationQueue.main) { (noti) in
            self.refresh()
        }
        notifyCenter.addObserver(forName: NOTIFY_SETTING_UPDATE, object: nil, queue: OperationQueue.main) { (noti) in
            self.setUpMenu(UserDefaults.standard.bool(forKey: USERDEFAULTS_ENABLE_SHOW_SPEED))
            self.refresh()
        }
        notifyCenter.addObserver(forName: NOTIFY_TOGGLE_RUNNING_SHORTCUT, object: nil, queue: OperationQueue.main) { (noti) in
            self.toggle { (suc) in
                self.refresh()
            }
        }
        notifyCenter.addObserver(forName: NOTIFY_UPDATE_RUNNING_MODE_MENU, object: nil, queue: OperationQueue.main) { (noti) in
            self.updateRunningModeMenu()
        }
        notifyCenter.addObserver(forName: NOTIFY_SWITCH_PAC_MODE_SHORTCUT, object: nil, queue: OperationQueue.main) { (noti) in
            Mode.switchTo(.PAC)
        }
        notifyCenter.addObserver(forName: NOTIFY_SWITCH_GLOBAL_MODE_SHORTCUT, object: nil, queue: OperationQueue.main) { (noti) in
            Mode.switchTo(.GLOBAL)
        }
        notifyCenter.addObserver(forName: NOTIFY_SWITCH_WHITELIST_MODE_SHORTCUT, object: nil, queue: OperationQueue.main) { (noti) in
            Mode.switchTo(.WHITELIST)
        }
        notifyCenter.addObserver(forName: NOTIFY_SWITCH_MANUAL_MODE_SHORTCUT, object: nil, queue: OperationQueue.main) { (noti) in
            Mode.switchTo(.MANUAL)
        }
        notifyCenter.addObserver(forName: NOTIFY_SWITCH_ACL_AUTO_MODE_SHORTCUT, object: nil, queue: OperationQueue.main) { (noti) in
            Mode.switchTo(.ACLAUTO)
        }
        notifyCenter.addObserver(forName: NOTIFY_SWITCH_CHINA_MODE_SHORTCUT, object: nil, queue: OperationQueue.main) { (noti) in
            Mode.switchTo(.CHINA)
        }
        
        DispatchQueue.main.async {
            self.statusItem.image = NSImage(named: "menu_icon")
            self.statusItem.image?.isTemplate = true
            self.statusItem.menu = self.statusMenu
            
            self.setUpMenu(defaults.bool(forKey: USERDEFAULTS_ENABLE_SHOW_SPEED))
            self.refresh()
            
            Shortcuts.bindShortcuts()
            
            if defaults.bool(forKey: USERDEFAULTS_CONNECT_AT_LAUNCH) && ServerProfileManager.instance.getActiveProfileId() != "" {
                defaults.set(false, forKey: USERDEFAULTS_SHADOWSOCKS_ON)
                defaults.synchronize()
                self.toggle { (suc) in
                    self.updateSubAndVersion()
                }
            } else {
                self.updateSubAndVersion()
            }
        }
    }
    
    private func refresh() {
        DispatchQueue.main.async {
            self.updateMainMenu()
            self.updateServersMenu()
            self.updateRunningModeMenu()
        }
    }
    
    @objc private func updateSubAndVersion() {
        DispatchQueue.global().async {
            // Version Check!
            if UserDefaults.standard.bool(forKey: USERDEFAULTS_AUTO_CHECK_UPDATE) {
                self.checkForUpdate(mustShowAlert: false)
            }
            if UserDefaults.standard.bool(forKey: USERDEFAULTS_AUTO_UPDATE_SUBSCRIBE) {
                SubscribeManager.instance.updateAllServerFromSubscribe(auto: true, useProxy: UserDefaults.standard.bool(forKey: USERDEFAULTS_AUTO_UPDATE_SUBSCRIBE_WITH_PROXY))
            }
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
    
    // MARK: Mainmenu functions
    
    @IBAction func toggleRunning(_ sender: NSMenuItem) {
        if ServerProfileManager.instance.profiles.count == 0 {
            ServerProfileManager.noService()
            return
        }
        self.toggle { (s) in
            self.updateMainMenu()
        }
    }
    
    private func toggle(finish: @escaping(_ success: Bool)->()) {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: USERDEFAULTS_SHADOWSOCKS_ON), forKey: USERDEFAULTS_SHADOWSOCKS_ON)
        defaults.synchronize()
        MainMenuManager.applyConfig { (suc) in
            SyncSSLocal { (s) in
                DispatchQueue.main.async {
                    finish(true)
                }
            }
        }
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
    
    @IBAction func toggleCopyCommandLine(_ sender: NSMenuItem) {
        // Get the Http proxy config.
        let d = UserDefaults.standard
        let address = d.string(forKey: USERDEFAULTS_LOCAL_HTTP_LISTEN_ADDRESS)
        let port = d.integer(forKey: USERDEFAULTS_LOCAL_HTTP_LISTEN_PORT)
        let s5address = d.string(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_ADDRESS)
        let s5port = d.integer(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT)
        
        var command = "export ALL_PROXY=socks5://\(s5address ?? "127.0.0.1"):\(s5port);export no_proxy=localhost;"
        
        if d.bool(forKey: USERDEFAULTS_LOCAL_HTTP_ON) {
            if let a = address {
                command = "export http_proxy=http://\(a):\(port);export https_proxy=http://\(a):\(port);"
            } else {
                makeToast("Export Command Copied Failed.".localized)
            }
        }
        // Copy to paste board.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: NSPasteboard.PasteboardType.string)
        // Show a toast notification.
        makeToast("Export Command Copied.".localized)
    }
    
    // MARK: Server submenu function

    @IBAction func showQRCodeForCurrentServer(_ sender: NSMenuItem) {
        var errMsg: String?
        if let profile = ServerProfileManager.instance.getActiveProfile() {
            if profile.isValid() {
                // Show window
                DispatchQueue.main.async {
                    if self.qrcodeWinCtrl != nil{
                        self.qrcodeWinCtrl.close()
                    }
                    self.qrcodeWinCtrl = SWBQRCodeWindowController(windowNibName: "SWBQRCodeWindowController")
                    self.qrcodeWinCtrl.qrCode = profile.getSSRURL()!.absoluteString
                    self.qrcodeWinCtrl.title = profile.title()
                    self.qrcodeWinCtrl.showWindow(self)
                    NSApp.activate(ignoringOtherApps: true)
                    self.qrcodeWinCtrl.window?.makeKeyAndOrderFront(nil)
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
        
        NSUserNotificationCenter.default.deliver(userNote);
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
    }
    
    @IBAction func exportAllServerProfile(_ sender: NSMenuItem) {
        ServerProfileManager.instance.exportConfigFile()
        NSApp.becomeFirstResponder()
    }
    
    @IBAction func updateSubscribeWithProxy(_ sender: NSMenuItem) {
        SubscribeManager.instance.updateAllServerFromSubscribe(auto: false, useProxy: true)
    }
    
    @IBAction func updateSubscribeWithoutProxy(_ sender: NSMenuItem) {
        SubscribeManager.instance.updateAllServerFromSubscribe(auto: false, useProxy: false)
    }
    
    // MARK: Proxy submenu function

    @IBAction func selectPACMode(_ sender: NSMenuItem) {
        Mode.switchTo(.PAC)
    }
    
    @IBAction func selectGlobalMode(_ sender: NSMenuItem) {
        Mode.switchTo(.GLOBAL)
    }
    
    @IBAction func selectManualMode(_ sender: NSMenuItem) {
        Mode.switchTo(.MANUAL)
    }
    
    @IBAction func selectACLAutoMode(_ sender: NSMenuItem) {
        Mode.switchTo(.ACLAUTO)
    }
    
    @IBAction func selectACLBackCHNMode(_ sender: NSMenuItem) {
        Mode.switchTo(.CHINA)
    }
    
    @IBAction func selectWhiteListMode(_ sender: NSMenuItem) {
        Mode.switchTo(.WHITELIST)
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
    
    @objc func selectServer(_ sender: NSMenuItem) {
        let index = sender.tag
        let spMgr = ServerProfileManager.instance
        let newProfile = spMgr.profiles[index]
        if newProfile.uuid != spMgr.getActiveProfileId() {
            spMgr.setActiveProfiledId(newProfile.uuid)
            SyncSSLocal { (suce) in
                self.updateServersMenu()
                self.updateRunningModeMenu()
            }
        } else {
            self.updateRunningModeMenu()
        }
    }

    @IBAction func connectionDelayTest(_ sender: NSMenuItem) {
        ConnectTestigManager.shared.start()
    }

    @IBAction func showLogs(_ sender: NSMenuItem) {
        let ws = NSWorkspace.shared
        if let appUrl = ws.urlForApplication(withBundleIdentifier: "com.apple.Console") {
            try! ws.launchApplication(at: appUrl
                ,options: NSWorkspace.LaunchOptions.default
                ,configuration: [NSWorkspace.LaunchConfigurationKey.arguments: "~/Library/Logs/ss-local.log"])
        }
    }

    @IBAction func tapSetting(_ sender: NSMenuItem) {
        if settingWindowCtrl != nil {
            settingWindowCtrl.close()
        }
        let ctrl = SettingsWindowController(windowNibName: "SettingsWindowController")
        settingWindowCtrl = ctrl
        
        ctrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        ctrl.window?.makeKeyAndOrderFront(self)
    }
    
    @IBAction func feedback(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(URL(string: "https://github.com/paradiseduo/ShadowsocksX-NG-R8/issues")!)
    }
    
    @IBAction func checkForUpdate(_ sender: NSMenuItem) {
        checkForUpdate(mustShowAlert: true)
    }
    
    @IBAction func showAbout(_ sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel(sender);
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func updateRunningModeMenu() {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
        var serverMenuText = "Servers".localized
        
        let mgr = ServerProfileManager.instance
        for p in mgr.profiles {
            if mgr.getActiveProfileId() == p.uuid {
                if !p.remark.isEmpty {
                    serverMenuText = p.remark
                } else {
                    serverMenuText = p.serverHost
                }
                if p.latency.doubleValue != Double.infinity {
                    serverMenuText += "  - \(NumberFormatter.three(p.latency)) ms"
                }
                else{
                    if !neverSpeedTestBefore {
                        serverMenuText += "  - failed"
                    }
                }
            }
        }

        serversMenuItem.title = serverMenuText
        autoModeMenuItem.state = NSControl.StateValue(rawValue: 0)
        globalModeMenuItem.state = NSControl.StateValue(rawValue: 0)
        manualModeMenuItem.state = NSControl.StateValue(rawValue: 0)
        whiteListModeMenuItem.state = NSControl.StateValue(rawValue: 0)
        ACLBackChinaMenuItem.state = NSControl.StateValue(rawValue: 0)
        ACLAutoModeMenuItem.state = NSControl.StateValue(rawValue: 0)
        ACLModeMenuItem.state = NSControl.StateValue(rawValue: 0)
        if mode == "auto" {
            autoModeMenuItem.state = NSControl.StateValue(rawValue: 1)
        } else if mode == "global" {
            globalModeMenuItem.state = NSControl.StateValue(rawValue: 1)
        } else if mode == "manual" {
            manualModeMenuItem.state = NSControl.StateValue(rawValue: 1)
        } else if mode == "whiteList" {
            let aclMode = defaults.string(forKey: USERDEFAULTS_ACL_FILE_NAME)!
            switch aclMode {
            case "backchn.acl":
                ACLModeMenuItem.state = NSControl.StateValue(rawValue: 1)
                ACLBackChinaMenuItem.state = NSControl.StateValue(rawValue: 1)
                ACLModeMenuItem.title = "Proxy Back China".localized
                break
            case "gfwlist.acl":
                ACLModeMenuItem.state = NSControl.StateValue(rawValue: 1)
                ACLAutoModeMenuItem.state = NSControl.StateValue(rawValue: 1)
                ACLModeMenuItem.title = "ACL Auto".localized
                break
            default:
                whiteListModeMenuItem.state = NSControl.StateValue(rawValue: 1)
            }
        }
        updateStatusItemUI()
    }
    
    func updateStatusItemUI() {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
        if defaults.bool(forKey: USERDEFAULTS_SHADOWSOCKS_ON) {
            if mode == "auto" {
                statusItem.image = NSImage(named: "menu_icon_pac")!
            } else if mode == "global" {
                statusItem.image = NSImage(named: "menu_icon_global")!
            } else if mode == "manual" {
                statusItem.image = NSImage(named: "menu_icon_manual")!
            } else if mode == "whiteList" {
                if UserDefaults.standard.string(forKey: USERDEFAULTS_ACL_FILE_NAME)! == "chn.acl" {
                    statusItem.image = NSImage(named: "menu_icon_white")!
                } else {
                    statusItem.image = NSImage(named: "menu_icon_acl")!
                }
            } else {
                statusItem.image = NSImage(named: "menu_icon")!
            }
        } else {
            statusItem.image = NSImage(named: "menu_icon_disabled")!
        }
        statusItem.image?.isTemplate = true
    }
    
    func updateMainMenu() {
        let defaults = UserDefaults.standard
        let isOn = defaults.bool(forKey: USERDEFAULTS_SHADOWSOCKS_ON)
        if isOn {
            runningStatusMenuItem.title = "Shadowsocks: On".localized
            runningStatusMenuItem.image = NSImage(named: NSImage.statusAvailableName)
            toggleRunningMenuItem.title = "Turn Shadowsocks Off".localized
            if ServerProfileManager.instance.profiles.count > 0 {
                copyHttpProxyExportCmdLineMenuItem.isHidden = false
            }
        } else {
            runningStatusMenuItem.title = "Shadowsocks: Off".localized
            runningStatusMenuItem.image = NSImage(named: NSImage.statusUnavailableName)
            toggleRunningMenuItem.title = "Turn Shadowsocks On".localized
            copyHttpProxyExportCmdLineMenuItem.isHidden = true
        }
        updateStatusItemUI()
    }
    
    //TODO:https://git.codingcafe.org/Mirrors/shadowsocks/ShadowsocksX-NG/blob/master/ShadowsocksX-NG/AppDelegate.swift
    func updateServersMenu() {
        let mgr = ServerProfileManager.instance
        serversMenuItem.submenu?.removeAllItems()
       
        let preferencesItem = serversPreferencesMenuItem
        serversMenuItem.submenu?.addItem(preferencesItem!)
        
        if !mgr.profiles.isEmpty {
            serversMenuItem.submenu?.addItem(NSMenuItem.separator())
        }
        
        if !neverSpeedTestBefore {
            if UserDefaults.standard.bool(forKey: USERDEFAULTS_ASCENDING_DELAY) {
                mgr.profiles = mgr.profiles.sorted { (p1, p2) -> Bool in
                    return p1.latency.doubleValue <= p2.latency.doubleValue
                }
            } else {
                mgr.reload()
            }
        }
        self.serverMenuItemNormal(mgr)
    }
    
    private func serverMenuItemNormal(_ mgr: ServerProfileManager) {
        var fastTime = ""
        var i = 0
        if let t = UserDefaults.standard.object(forKey: USERDEFAULTS_FASTEST_NODE) as? String {
            fastTime = t
        }
        for p in mgr.profiles {
            let item = NSMenuItem(title: p.title(), action: #selector(MainMenuManager.selectServer), keyEquivalent: "")
            item.tag = i //+ kProfileMenuItemIndexBase
            item.target = self
            
            let latency = p.latency
            let nf = NumberFormatter.three(latency)
            if latency.doubleValue != Double.infinity {
                item.title += "  - \(nf)ms"
                if nf == fastTime {
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
                item.state = NSControl.StateValue(rawValue: 1)
            }
            if !p.isValid() {
                item.isEnabled = false
            }
            
            if !p.ssrGroup.isEmpty {
                if((serversMenuItem.submenu?.item(withTitle: p.ssrGroup)) == nil){
                    let groupSubmenu = NSMenu()
                    let groupSubmenuItem = NSMenuItem()
                    groupSubmenuItem.title = p.ssrGroup
                    serversMenuItem.submenu?.addItem(groupSubmenuItem)
                    serversMenuItem.submenu?.setSubmenu(groupSubmenu, for: groupSubmenuItem)
                    if mgr.getActiveProfileId() == p.uuid {
                        groupSubmenuItem.state = NSControl.StateValue(rawValue: 1)
                    }
                    groupSubmenuItem.submenu?.addItem(item)
                    i += 1
                    continue
                }
                else{
                    if mgr.getActiveProfileId() == p.uuid {
                        serversMenuItem.submenu?.item(withTitle: p.ssrGroup)?.state = NSControl.StateValue(rawValue: 1)
                    }
                    serversMenuItem.submenu?.item(withTitle: p.ssrGroup)?.submenu?.addItem(item)
                    i += 1
                    continue
                }
            }
            
            serversMenuItem.submenu?.addItem(item)
            i += 1
        }
        serversMenuItem.submenu?.minimumWidth = 0
    }
    
    func setUpMenu(_ showSpeed:Bool){
        if showSpeed{
            speedItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            speedItem.menu = speedMenu
            if UserDefaults.standard.bool(forKey: USERDEFAULTS_FIXED_NETWORK_SPEED_VIEW_WIDTH) {
                self.fixedSpeedItemWidth(true)
                self.fixedWidth.state = NSControl.StateValue.on
            } else {
                self.fixedSpeedItemWidth(false)
                self.fixedWidth.state = NSControl.StateValue.off
            }
            if let b = speedItem.button {
                b.attributedTitle = SpeedTools.speedAttributedString(up: 0.0, down: 0.0)
            }
            if speedMonitor == nil{
                speedMonitor = NetSpeedMonitor()
            }
            if speedTimer == nil {
                speedTimer = Timer(timeInterval: repeatTimeinterval, repeats: true) {[weak self] (timer) in
                    guard let w = self else {return}
                    w.speedMonitor?.timeInterval(w.repeatTimeinterval, downloadAndUploadSpeed: { (down, up) in
                        if let b = w.speedItem.button {
                            b.attributedTitle = SpeedTools.speedAttributedString(up: up, down: down)
                        }
                    })
                }
                RunLoop.main.add(speedTimer!, forMode: RunLoop.Mode.common)
            }
        }else{
            speedItem.attributedTitle = NSAttributedString(string: "")
            NSStatusBar.system.removeStatusItem(speedItem)
            speedTimer?.invalidate()
            speedTimer = nil
            speedMonitor = nil
        }
    }
    
    func checkForUpdate(mustShowAlert: Bool) -> Void {
        let versionChecker = VersionChecker()
        DispatchQueue.global().async {
            let newVersion = versionChecker.checkNewVersion()
            DispatchQueue.main.async {
                if (mustShowAlert || newVersion["newVersion"] as! Bool){
                    let alertResult = versionChecker.showAlertView(Title: newVersion["Title"] as! String, SubTitle: newVersion["SubTitle"] as! String, ConfirmBtn: newVersion["ConfirmBtn"] as! String, CancelBtn: newVersion["CancelBtn"] as! String)
                    if (newVersion["newVersion"] as! Bool && alertResult == 1000){
                        NSWorkspace.shared.open(URL(string: "https://github.com/paradiseduo/ShadowsocksX-NG-R8/releases")!)
                    }
                }
            }
        }
    }
    
    private func foundSSRURL(_ note: Notification) {
        func failedNotification() {
            let userNote = NSUserNotification()
            userNote.title = "Failed to Add Server Profile".localized
            userNote.subtitle = "Address can not be recognized".localized
            NSUserNotificationCenter.default.deliver(userNote)
        }
        func successNotification(userInfo:[AnyHashable : Any], text: String) {
            let userNote = NSUserNotification()
            userNote.title = "Add Shadowsocks Server Profile".localized
            if userInfo["source"] as! String == "qrcode" {
                userNote.subtitle = "By scan QR Code".localized
            } else if userInfo["source"] as! String == "url" {
                userNote.subtitle = "By Handle SS URL".localized
            }
            userNote.informativeText = text
            userNote.soundName = NSUserNotificationDefaultSoundName
            
            NSUserNotificationCenter.default.deliver(userNote)
        }
        if let userInfo = (note as NSNotification).userInfo {
            let urls: [URL] = userInfo["urls"] as! [URL]
            
            let mgr = ServerProfileManager.instance
            var isChanged = false
            if urls.count == 0 {
                failedNotification()
                return
            }
            var sarray = [ServerProfile]()
            for url in urls {
                let profielDict = ParseAppURLSchemes(url)//ParseSSURL(url)
                if let profielDict = profielDict {
                    let profile = ServerProfile.fromDictionary(profielDict as [String : AnyObject])
                    sarray.append(profile)
                }else{
                    failedNotification()
                }
            }
            var repeatCount = 0
            for profile in sarray {
                let (exists, duplicated, index) = ServerProfileManager.isDuplicatedOrExists(mgr.profiles, profile)
                if exists && duplicated {
                    repeatCount += 1
                    continue
                } else if exists && !duplicated {
                    isChanged = true
                    mgr.profiles[index] = profile
                } else {
                    isChanged = true
                    mgr.profiles.append(profile)
                }
                successNotification(userInfo: userInfo, text: "Host: \(profile.serverHost)\n Port: \(profile.serverPort)\n Encription Method: \(profile.method)".localized)
            }
            if isChanged {
                mgr.save()
                self.updateServersMenu()
            } else {
                if repeatCount > 0 {
                    successNotification(userInfo: userInfo, text: "\(repeatCount)"+"repeated".localized)
                }
            }
        }
    }
    
    static func applyConfig(finish: @escaping(_ success: Bool)->()) {
        let defaults = UserDefaults.standard
        let isOn = defaults.bool(forKey: USERDEFAULTS_SHADOWSOCKS_ON)
        let mode = defaults.string(forKey: USERDEFAULTS_SHADOWSOCKS_RUNNING_MODE)
        
        if isOn {
            StartSSLocal { (s) in
                if s {
                    StartPrivoxy { (ss) in
                        if ss {
                            if mode == "auto" {
                                ProxyConfHelper.disableProxy("hi")
                                ProxyConfHelper.enablePACProxy("hi")
                            } else if mode == "global" {
                                ProxyConfHelper.disableProxy("hi")
                                ProxyConfHelper.enableGlobalProxy()
                            } else if mode == "manual" {
                                ProxyConfHelper.disableProxy("hi")
                            } else if mode == "whiteList" {
                                ProxyConfHelper.disableProxy("hi")
                                ProxyConfHelper.enableWhiteListProxy()//新白名单基于GlobalMode
                            }
                            finish(true)
                        } else {
                            finish(false)
                        }
                    }
                } else {
                    finish(false)
                }
            }
        } else {
            AppDelegate.stopSSR {
                finish(true)
            }
        }
    }
    
    @IBAction func quitApp(_ sender: NSMenuItem) {
        AppDelegate.stopSSR {
            //如果设置了开机启动软件，就不删了
            if AppDelegate.getLauncherStatus() == false {
                RemoveSSLocal { (s) in
                    RemovePrivoxy { (ss) in
                        NSApplication.shared.terminate(self)
                    }
                }
            } else {
                NSApplication.shared.terminate(self)
            }
        }
    }
    //------------------------------------------------------------
    // MARK: NSUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    func makeToast(_ message: String) {
        if toastWindowCtrl != nil {
            toastWindowCtrl.close()
        }
        
        toastWindowCtrl = ToastWindowController(windowNibName: NSNib.Name("ToastWindowController"))
        toastWindowCtrl.message = message
        toastWindowCtrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.becomeFirstResponder()
        toastWindowCtrl.window?.makeKeyAndOrderFront(self)
        toastWindowCtrl.fadeInHud()
    }
    
    //------------------------------------------------------------
    // MARK: Speed Item Actions
    
    @IBAction func fixedWidth(_ sender: NSMenuItem) {
        sender.state = (sender.state == .on ? .off:.on)
        let b = sender.state == .on ? true:false
        UserDefaults.standard.setValue(b, forKey: USERDEFAULTS_FIXED_NETWORK_SPEED_VIEW_WIDTH)
        UserDefaults.standard.synchronize()
        self.fixedSpeedItemWidth(b)
    }
    
    @IBAction func closeSpeedItem(_ sender: NSMenuItem) {
        UserDefaults.standard.setValue(false, forKey: USERDEFAULTS_ENABLE_SHOW_SPEED)
        UserDefaults.standard.synchronize()
        self.setUpMenu(false)
    }
    
    private func fixedSpeedItemWidth(_ fixed: Bool) {
        if fixed {
            speedItem.length = 70
        } else {
            speedItem.length = NSStatusItem.variableLength
        }
    }
}
