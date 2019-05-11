//
//  PreferencesWindowController.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/6.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController
    , NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var profilesTableView: NSTableView!
    
    @IBOutlet weak var profileBox: NSBox!
    
    @IBOutlet weak var hostTextField: NSTextField!
    @IBOutlet weak var portTextField: NSTextField!
    @IBOutlet weak var methodTextField: NSComboBox!
    
    @IBOutlet weak var ProtocolTextField: NSComboBox!
    @IBOutlet weak var ProtocolParamTextField: NSTextField!
    @IBOutlet weak var ObfsTextField: NSComboBox!
    @IBOutlet weak var ObfsParamTextField: NSTextField!
    
    @IBOutlet weak var duplicateProfileButton: NSButton!
    @IBOutlet weak var passwordTextField: NSTextField!
    @IBOutlet weak var remarkTextField: NSTextField!
    @IBOutlet weak var groupTextField: NSTextField!
    
    @IBOutlet weak var copyURLBtn: NSButton!
    
    @IBOutlet weak var removeButton: NSButton!
    let tableViewDragType: String = "ss.server.profile.data"
    
    var defaults: UserDefaults!
    var profileMgr: ServerProfileManager!
    
    var editingProfile: ServerProfile!


    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        defaults = UserDefaults.standard
        profileMgr = ServerProfileManager.instance
        
        methodTextField.addItems(withObjectValues: [
            "none",
            "table",
            "rc4",
            "rc4-md5-6",
            "rc4-md5",
            "aes-128-cfb",
            "aes-192-cfb",
            "aes-256-cfb",
            "aes-128-ctr",
            "aes-192-ctr",
            "aes-256-ctr",
            "bf-cfb",
            "camellia-128-cfb",
            "camellia-192-cfb",
            "camellia-256-cfb",
            "cast5-cfb",
            "des-cfb",
            "idea-cfb",
            "rc2-cfb",
            "seed-cfb",
            "salsa20",
            "chacha20",
            "chacha20-ietf",
            ])
        ProtocolTextField.addItems(withObjectValues: [
            "origin",
            "verify_deflate",
            "auth_sha1",
            "auth_sha1_v2",
            "auth_sha1_v4",
            "auth_aes128_sha1",
            "auth_aes128_md5",
            "auth_chain_a",
            "auth_chain_b",
            ])
        ObfsTextField.addItems(withObjectValues: [
            "plain",
            "http_simple",
            "tls_simple",
            "http_post",
            "tls1.2_ticket_auth",
            ])
        profilesTableView.reloadData()
        updateProfileBoxVisible()
    }
    
//    override func awakeFromNib() {
//        profilesTableView.registerForDraggedTypes(convertToNSPasteboardPasteboardTypeArray([tableViewDragType]))
//        profilesTableView.allowsMultipleSelection = true
//    }
    
    override func awakeFromNib() {
        profilesTableView.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: tableViewDragType)])
        profilesTableView.allowsMultipleSelection = true
    }

    
    @IBAction func addProfile(_ sender: NSButton) {
        if editingProfile != nil && !editingProfile.isValid(){
            shakeWindows()
            return
        }
        profilesTableView.beginUpdates()
        let profile = ServerProfile()
        profile.remark = "New Server".localized
        profileMgr.profiles.append(profile)
        
        let index = IndexSet(integer: profileMgr.profiles.count-1)
        profilesTableView.insertRows(at: index, withAnimation: .effectFade)
        
        self.profilesTableView.scrollRowToVisible(self.profileMgr.profiles.count-1)
        self.profilesTableView.selectRowIndexes(index, byExtendingSelection: false)
        profilesTableView.endUpdates()
        updateProfileBoxVisible()
    }
    
    @IBAction func removeProfile(_ sender: NSButton) {
        let index = Int(profilesTableView.selectedRowIndexes.first!)
        var deleteCount = 0
        if index >= 0 {
            profilesTableView.beginUpdates()
            for (_, toDeleteIndex) in profilesTableView.selectedRowIndexes.enumerated() {
                print(profileMgr.profiles.count)
                profileMgr.profiles.remove(at: toDeleteIndex - deleteCount)
                profilesTableView.removeRows(at: IndexSet(integer: toDeleteIndex - deleteCount), withAnimation: .effectFade)
                deleteCount += 1
            }
            profilesTableView.endUpdates()
        }
        self.profilesTableView.scrollRowToVisible(index-1)
        self.profilesTableView.selectRowIndexes(IndexSet(integer: index-1), byExtendingSelection: false)
        updateProfileBoxVisible()
        if profileMgr.profiles.count == 0 {
            defaults.set(true, forKey: "ShadowsocksOn")
            (NSApplication.shared.delegate as! AppDelegate).toggleRunning((NSApplication.shared.delegate as! AppDelegate).toggleRunningMenuItem)
        }
    }
    
    @IBAction func ok(_ sender: NSButton) {
        if editingProfile != nil {
            if !editingProfile.isValid() {
                // Done Shake window
                shakeWindows()
                return
            }
        }
        profileMgr.save()
        window?.performClose(nil)

        
        NotificationCenter.default
            .post(name: Notification.Name(rawValue: NOTIFY_SERVER_PROFILES_CHANGED), object: nil)
    }
    
    @IBAction func cancel(_ sender: NSButton) {
        window?.performClose(self)
    }
    
    @IBAction func duplicateProfile(_ sender: NSButton) {
        //读取当前profile，并且保存
        if editingProfile != nil && !editingProfile.isValid(){
            return
        }
        let oldProfileIndex = profilesTableView.selectedRow
        if  oldProfileIndex >= 0 {
            let oldProfile = profileMgr.profiles[oldProfileIndex]
            profilesTableView.beginUpdates()
            var newProfile = ServerProfile()
            let newUUID = newProfile.uuid
            newProfile = ServerProfile.fromDictionary(oldProfile.toDictionary())//here 因为UUID重复了
            newProfile.uuid = newUUID
            profileMgr.profiles.append(newProfile)
            let index = IndexSet(integer: profileMgr.profiles.count-1)
            profilesTableView.insertRows(at: index, withAnimation: .effectFade)
            self.profilesTableView.scrollRowToVisible(self.profileMgr.profiles.count-1)
            self.profilesTableView.selectRowIndexes(index, byExtendingSelection: false)
            profilesTableView.endUpdates()
            updateProfileBoxVisible()
            NotificationCenter.default
                .post(name: Notification.Name(rawValue: NOTIFY_SERVER_PROFILES_CHANGED), object: nil)
        }
    }
    
    @IBAction func copyCurrentProfileURL2Pasteboard(_ sender: NSButton) {
        let index = profilesTableView.selectedRow
        if  index >= 0 {
            let profile = profileMgr.profiles[index]
            let ssURL = profile.URL()
            if let url = ssURL {
                
                let pboard = NSPasteboard.general
                pboard.clearContents()
                //let rs = pboard.setString(String(describing: url), forType: convertToNSPasteboardPasteboardType(NSStringPboardType.rawValue))//writeObjects([url])
                let rs = pboard.writeObjects([url as NSPasteboardWriting])
                if rs {
                    NSLog("copy to pasteboard success")
                } else {
                    NSLog("copy to pasteboard failed")
                }
            }
        }
    }
    
    func updateProfileBoxVisible() {
        if profileMgr.profiles.count <= 0 {
            removeButton.isEnabled = false
        }else{
            removeButton.isEnabled = true
        }

        if profileMgr.profiles.isEmpty {
            profileBox.isHidden = true
        } else {
            profileBox.isHidden = false
        }
    }
    
    func bindProfile(_ index:Int) {
        NSLog("bind profile \(index)")
        if index >= 0 && index < profileMgr.profiles.count {
            editingProfile = profileMgr.profiles[index]
            
            hostTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "serverHost"
                , options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            portTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "serverPort"
                , options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
            methodTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "method"
                , options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            passwordTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "password"
                , options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
            remarkTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "remark"
                , options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
            ProtocolTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "ssrProtocol", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
            ProtocolParamTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "ssrProtocolParam", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
            ObfsTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "ssrObfs", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
            ObfsParamTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "ssrObfsParam", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            groupTextField.bind(NSBindingName(rawValue: "value"), to: editingProfile, withKeyPath: "ssrGroup", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
        } else {
            editingProfile = nil
            hostTextField.unbind(convertToNSBindingName("value"))
            portTextField.unbind(convertToNSBindingName("value"))
            
            methodTextField.unbind(convertToNSBindingName("value"))
            passwordTextField.unbind(convertToNSBindingName("value"))
            
            ProtocolTextField.unbind(convertToNSBindingName("value"))
            ProtocolParamTextField.unbind(convertToNSBindingName("value"))
            ObfsTextField.unbind(convertToNSBindingName("value"))
            ObfsParamTextField.unbind(convertToNSBindingName("value"))
            
            remarkTextField.unbind(convertToNSBindingName("value"))
            
        }
    }
    
    func getDataAtRow(_ index:Int) -> (String, Bool) {
        let profile = profileMgr.profiles[index]
        let isActive = (profileMgr.getActiveProfileId() == profile.uuid)
        if !profile.remark.isEmpty {
            return (profile.remark, isActive)
        } else {
            return (profile.serverHost, isActive)
        }
    }
    
    //--------------------------------------------------
    // MARK: For NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let mgr = profileMgr {
            return mgr.profiles.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView
        , objectValueFor tableColumn: NSTableColumn?
        , row: Int) -> Any? {
        
        let (title, isActive) = getDataAtRow(row)
        
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("main") {
            return title
        } else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("status") {
            if isActive {
                return NSImage(named: NSImage.Name("NSMenuOnStateTemplate"))
            } else {
                return nil
            }
        }

        
//        if convertFromNSUserInterfaceItemIdentifier(tableColumn?.identifier) == "main" {
//            return title
//        } else if convertFromNSUserInterfaceItemIdentifier(tableColumn?.identifier) == "status" {
//            if isActive {
//                return NSImage(named: "NSMenuOnStateTemplate")
//            } else {
//                return nil
//            }
//        }
        return ""
    }
    
    // MARK: Drag & Drop reorder rows
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: convertToNSPasteboardPasteboardType(tableViewDragType))
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int
        , proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return NSDragOperation()
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo
        , row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let mgr = profileMgr {
            var oldIndexes = [Int]()
//            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) {arg,arg,arg,
//                if let str = ($0.item as! NSPasteboardItem).string(forType: convertToNSPasteboardPasteboardType(self.tableViewDragType)), let index = Int(str) {
//                    oldIndexes.append(index)
//                }
//            }
            
            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:], using: {
                (draggingItem: NSDraggingItem, idx: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                if let str = (draggingItem.item as! NSPasteboardItem).string(forType: NSPasteboard.PasteboardType(rawValue: self.tableViewDragType)), let index = Int(str) {
                    oldIndexes.append(index)
                }
            })
            

            
            var oldIndexOffset = 0
            var newIndexOffset = 0
            
            // For simplicity, the code below uses `tableView.moveRowAtIndex` to move rows around directly.
            // You may want to move rows in your content array and then call `tableView.reloadData()` instead.
            tableView.beginUpdates()
            for oldIndex in oldIndexes {
                if oldIndex < row {
                    let o = mgr.profiles.remove(at: oldIndex + oldIndexOffset)
                    mgr.profiles.insert(o, at:row - 1)
                    tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                    oldIndexOffset -= 1
                } else {
                    let o = mgr.profiles.remove(at: oldIndex)
                    mgr.profiles.insert(o, at:row + newIndexOffset)
                    tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                    newIndexOffset += 1
                }
            }
            tableView.endUpdates()
        
            return true
        }
        return false
    }
    
    //--------------------------------------------------
    // For NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView
        , shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return false
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if row < 0 {
            editingProfile = nil
            return true
        }
        if editingProfile != nil {
            if !editingProfile.isValid() {
                return false
            }
        }
        
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if profilesTableView.selectedRow >= 0 {
            bindProfile(profilesTableView.selectedRow)
            if (profilesTableView.selectedRowIndexes.count > 1){
                duplicateProfileButton.isEnabled = false
            } else {
                duplicateProfileButton.isEnabled = true
            }
        } else {
            if !profileMgr.profiles.isEmpty {
                let index = IndexSet(integer: profileMgr.profiles.count - 1)
                profilesTableView.selectRowIndexes(index, byExtendingSelection: false)
            }
        }
    }

    func shakeWindows(){
        let numberOfShakes:Int = 8
        let durationOfShake:Float = 0.5
        let vigourOfShake:Float = 0.05

        let frame:CGRect = (window?.frame)!
        let shakeAnimation = CAKeyframeAnimation()

        let shakePath = CGMutablePath()
        
        shakePath.move(to: CGPoint(x:NSMinX(frame), y:NSMinY(frame)))

        for _ in 1...numberOfShakes{
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) - frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) + frame.size.width * CGFloat(vigourOfShake), y: NSMinY(frame)))
        }

        shakePath.closeSubpath()
        shakeAnimation.path = shakePath
        shakeAnimation.duration = CFTimeInterval(durationOfShake)
        window?.animations = ["frameOrigin":shakeAnimation]
        window?.animator().setFrameOrigin(window!.frame.origin)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSPasteboardPasteboardTypeArray(_ input: [String]) -> [NSPasteboard.PasteboardType] {
	return input.map { key in NSPasteboard.PasteboardType(key) }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSPasteboardPasteboardType(_ input: String) -> NSPasteboard.PasteboardType {
	return NSPasteboard.PasteboardType(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSBindingOptionDictionary(_ input: [String: Any]?) -> [NSBindingOption: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSBindingOption(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSBindingOption(_ input: NSBindingOption) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSBindingName(_ input: String) -> NSBindingName {
	return NSBindingName(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier) -> String {
	return input.rawValue
}
