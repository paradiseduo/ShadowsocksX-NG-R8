//
//  SettingsWindowController.swift
//  ShadowsocksX-NG
//
//  Created by ParadiseDuo on 2020/5/17.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Cocoa

class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate, NSTextFieldDelegate {

    @IBOutlet weak var toolbar: NSToolbar!
    @IBOutlet weak var tabView: NSTabView!
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var launchAtLoginButton: NSButton!
    @IBOutlet weak var delayTestMethod: NSComboBox!
    
    @IBOutlet var bypassProxyTextView: NSTextView!
    
    @IBOutlet weak var socks5Address: NSTextField!
    @IBOutlet weak var socks5Port: NSTextField!
    @IBOutlet weak var pacAddress: NSTextField!
    @IBOutlet weak var pacPort: NSTextField!
    @IBOutlet weak var timeout: NSTextField!
    
    @IBOutlet weak var httpAddress: NSTextField!
    @IBOutlet weak var httpPort: NSTextField!
    
    @IBOutlet var userRuleTestView: NSTextView!
    
    private var hardwareChanged = false
    private var advancedChanged = false
    private var httpChanged = false
    private var updateChanged = false
    
    var networkServices: NSArray!
    var selectedNetworkServices: NSMutableSet!
    
    override func windowDidLoad() {
        super.windowDidLoad()

        window?.delegate = self
        launchAtLoginButton.state = AppDelegate.getLauncherStatus() ? .on:.off
        
        let d = UserDefaults.standard
        delayTestMethod.stringValue = d.bool(forKey: USERDEFAULTS_TCP) ? "TCP":"ICMP"
        
        tableView.delegate = self
        tableView.dataSource = self
        
        bypassProxyTextView.delegate = self
        userRuleTestView.delegate = self
        
        socks5Address.delegate = self
        socks5Port.delegate = self
        pacAddress.delegate = self
        pacPort.delegate = self
        timeout.delegate = self
        
        httpAddress.delegate = self
        httpPort.delegate = self
        
        if let services = d.array(forKey: USERDEFAULTS_PROXY4_NETWORK_SERVICES) {
            selectedNetworkServices = NSMutableSet(array: services)
        } else {
            selectedNetworkServices = NSMutableSet()
        }
        networkServices = ProxyConfTool.networkServicesList() as NSArray?
        tableView.reloadData()
        
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: PACUserRuleFilePath) {
            let src = Bundle.main.path(forResource: "user-rule", ofType: "txt")
            try! fileMgr.copyItem(atPath: src!, toPath: PACUserRuleFilePath)
        }

        let str = try? String(contentsOfFile: PACUserRuleFilePath, encoding: String.Encoding.utf8)
        userRuleTestView.string = str ?? ""
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        window?.center()
    }
    
    func textDidChange(_ notification: Notification) {
        if let t = notification.object as? NSTextView {
            switch t {
            case bypassProxyTextView:
                hardwareChanged = true
                break
            case userRuleTestView:
                updateChanged = true
                break
            default:
                break
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        if let t = obj.object as? NSTextField {
            switch t {
            case socks5Address, socks5Port, pacAddress, pacAddress, timeout:
                advancedChanged = true
                break
            case httpPort, httpAddress:
                httpChanged = true
                break
            default:
                break
            }
        }
    }
    
    @IBAction func toolbarAction(_ sender: NSToolbarItem) {
        tabView.selectTabViewItem(withIdentifier: sender.itemIdentifier)
    }
    
    func windowWillClose(_ notification: Notification) {
        let d = UserDefaults.standard
               d.setValue(delayTestMethod.stringValue == "TCP" ? true:false, forKey: USERDEFAULTS_TCP)
               d.synchronize()
               
        AppDelegate.setLauncherStatus(open: launchAtLoginButton.state == .on ? true:false)
        NotificationCenter.default.post(name: NOTIFY_SETTING_UPDATE, object: nil)
    }
    
    // MARK: HardwareView functions
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if networkServices != nil {
            return networkServices.count
        }
        return 0;
    }
        
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let cell = tableColumn!.dataCell as! NSButtonCell
        
        let key = (networkServices[row] as AnyObject)["key"] as! String
        if selectedNetworkServices.contains(key) {
            cell.state = NSControl.StateValue(rawValue: 1)
        } else {
            cell.state = NSControl.StateValue(rawValue: 0)
        }
        let userDefinedName = (networkServices[row] as AnyObject)["userDefinedName"] as! String
        cell.title = userDefinedName
        return cell
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        let key = (networkServices[row] as AnyObject)["key"] as! String
        
        if (object! as AnyObject).intValue == 1 {
            selectedNetworkServices.add(key)
        } else {
            selectedNetworkServices.remove(key)
        }
        hardwareChanged = true
    }
    
    @IBAction func autoConfigureTap(_ sender: NSButton) {
        hardwareChanged = true
    }
    
    @IBAction func hardwareSave(_ sender: NSButton) {
        if hardwareChanged {
            ProxyConfHelper.disableProxy("hi")
            
            let defaults = UserDefaults.standard
            defaults.setValue(selectedNetworkServices.allObjects, forKeyPath: USERDEFAULTS_PROXY4_NETWORK_SERVICES)
            defaults.synchronize()
            
            NotificationCenter.default.post(name: NOTIFY_ADV_CONF_CHANGED, object: nil)
            hardwareChanged = false
        }
    }

    // MARK: Advanced functions
    
    @IBAction func advancedSaveTap(_ sender: NSButton) {
        if advancedChanged {
            ProxyConfHelper.disableProxy("hi")
            NotificationCenter.default.post(name: NOTIFY_ADV_CONF_CHANGED, object: nil)
            advancedChanged = false
        }
    }
    
    @IBAction func enableUdpReplayTap(_ sender: NSButton) {
        advancedChanged = true
    }
    
    @IBAction func enableVerboseModeTap(_ sender: NSButton) {
        advancedChanged = true
    }

    // MARK: HTTP functions
    
    @IBAction func httpSaveTap(_ sender: NSButton) {
        if httpChanged {
            NotificationCenter.default.post(name: NOTIFY_HTTP_CONF_CHANGED, object: nil)
            httpChanged = false
        }
    }
    
    @IBAction func httpProxyEnableTap(_ sender: NSButton) {
        httpChanged = true
    }
    
    @IBAction func followGlobalModeTap(_ sender: NSButton) {
        httpChanged = true
    }
    
    // MARK: Update functions
    @IBAction func saveUserRuleTap(_ sender: NSButton) {
        if updateChanged {
            if let str = userRuleTestView?.string {
                do {
                    try str.data(using: String.Encoding.utf8)?.write(to: URL(fileURLWithPath: PACUserRuleFilePath), options: .atomic)

                    if GeneratePACFile() {
                        // Popup a user notification
                        let notification = NSUserNotification()
                        notification.title = "PAC has been updated by User Rules.".localized
                        DispatchQueue.main.async {
                            NSUserNotificationCenter.default.deliver(notification)
                            NotificationCenter.default.post(name: NOTIFY_ADV_CONF_CHANGED, object: nil)
                        }
                    } else {
                        let notification = NSUserNotification()
                        notification.title = "It's failed to update PAC by User Rules.".localized
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                } catch {}
                updateChanged = false
            }
        }
    }
    
    @IBAction func updateACLTap(_ sender: NSButton) {
        sender.isEnabled = false
        UpdateACL {
            sender.isEnabled = true
        }
    }
    
    @IBAction func updatePACTap(_ sender: NSButton) {
        sender.isEnabled = false
        UpdatePACFromGFWList {
            sender.isEnabled = true
        }
    }
    
}
