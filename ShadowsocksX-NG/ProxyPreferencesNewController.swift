//
//  ProxyPreferencesNewController.swift
//  ShadowsocksX-NG
//
//  Created by Youssef on 2020/3/9.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Cocoa

class ProxyPreferencesNewController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var autoConfigCheckBox: NSButton!
    @IBOutlet weak var tableVIew: NSTableView!
    
    var networkServices: NSArray!
    var selectedNetworkServices: NSMutableSet!
    
    var autoConfigureNetworkServices: Bool = true
    
    override func windowDidLoad() {
        super.windowDidLoad()

        let defaults = UserDefaults.standard
        self.autoConfigCheckBox.state = NSControl.StateValue(rawValue: NSNumber(value: defaults.bool(forKey: "AutoConfigureNetworkServices")).intValue)
        self.autoConfigureNetworkServices = defaults.bool(forKey: "AutoConfigureNetworkServices")
        
        if let services = defaults.array(forKey: "Proxy4NetworkServices") {
            selectedNetworkServices = NSMutableSet(array: services)
        } else {
            selectedNetworkServices = NSMutableSet()
        }
        
        networkServices = ProxyConfTool.networkServicesList() as NSArray?
        tableVIew.delegate = self
        tableVIew.dataSource = self
        tableVIew.reloadData()
    }
    
    
    @IBAction func ok(_ sender: NSButton) {
        ProxyConfHelper.disableProxy("hi")
        
        let defaults = UserDefaults.standard
        defaults.setValue(selectedNetworkServices.allObjects, forKeyPath: "Proxy4NetworkServices")
        defaults.setValue(autoConfigureNetworkServices, forKey: "AutoConfigureNetworkServices")
        
        defaults.synchronize()
        
        window?.performClose(self)
        
        NotificationCenter.default
            .post(name: Notification.Name(rawValue: NOTIFY_ADV_PROXY_CONF_CHANGED), object: nil)
    }
    
    @IBAction func cancel(_ sender: NSButton) {
        window?.performClose(self)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if networkServices != nil {
            return networkServices.count
        }
        return 0;
    }
        
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?
        , row: Int) -> Any? {
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
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?
        , for tableColumn: NSTableColumn?, row: Int) {
        let key = (networkServices[row] as AnyObject)["key"] as! String
        
        if (object! as AnyObject).intValue == 1 {
            selectedNetworkServices.add(key)
        } else {
            selectedNetworkServices.remove(key)
        }
    }
}
