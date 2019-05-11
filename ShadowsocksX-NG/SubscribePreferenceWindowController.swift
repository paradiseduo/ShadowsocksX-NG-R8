//
//  SubscribePreferenceWindowController.swift
//  ShadowsocksX-NG
//
//  Created by 秦宇航 on 2017/6/15.
//  Copyright © 2017年 qiuyuzhou. All rights reserved.
//

import Cocoa

class SubscribePreferenceWindowController: NSWindowController
    , NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var FeedLabel: NSTextField!
    @IBOutlet weak var OKButton: NSButton!

    @IBOutlet weak var FeedTextField: NSTextField!
    @IBOutlet weak var TokenTextField: NSTextField!
    @IBOutlet weak var GroupTextField: NSTextField!
    @IBOutlet weak var MaxCountTextField: NSTextField!
    @IBOutlet weak var SubscribeTableView: NSTableView!

    @IBOutlet weak var AddSubscribeBtn: NSButton!
    @IBOutlet weak var DeleteSubscribeBtn: NSButton!
    
    var sbMgr: SubscribeManager!
    var defaults: UserDefaults!
    let tableViewDragType: String = "subscribe.host"
    var editingSubscribe: Subscribe!
    
    override func windowDidLoad() {
        super.windowDidLoad()

        sbMgr = SubscribeManager.instance
        defaults = UserDefaults.standard
        SubscribeTableView.reloadData()
        updateSubscribeBoxVisible()
    }
    
    override func awakeFromNib() {
        SubscribeTableView.registerForDraggedTypes(convertToNSPasteboardPasteboardTypeArray([tableViewDragType]))
        SubscribeTableView.allowsMultipleSelection = true
    }
    
    @IBAction func onOk(_ sender: NSButton) {
        if editingSubscribe != nil {
            if !editingSubscribe.feedValidator() {
                // Done Shake window
                shakeWindows()
                return
            }
        }
        sbMgr.save()
        window?.performClose(self)
    }
    
    @IBAction func onAdd(_ sender: NSButton) {
        if editingSubscribe != nil && !editingSubscribe.feedValidator(){
            shakeWindows()
            return
        }
        SubscribeTableView.beginUpdates()
        let subscribe = Subscribe(initUrlString: "", initGroupName: "", initToken: "", initMaxCount: -1)
        sbMgr.subscribes.append(subscribe)
        
        let index = IndexSet(integer: sbMgr.subscribes.count-1)
        SubscribeTableView.insertRows(at: index, withAnimation: .effectFade)
        
        self.SubscribeTableView.scrollRowToVisible(self.sbMgr.subscribes.count-1)
        self.SubscribeTableView.selectRowIndexes(index, byExtendingSelection: false)
        SubscribeTableView.endUpdates()
        updateSubscribeBoxVisible()
    }
    
    @IBAction func onDelete(_ sender: NSButton) {
        let index = Int(SubscribeTableView.selectedRowIndexes.first!)
        var deleteCount = 0
        if index >= 0 {
            SubscribeTableView.beginUpdates()
            for (_, toDeleteIndex) in SubscribeTableView.selectedRowIndexes.enumerated() {
                _ = sbMgr.deleteSubscribe(atIndex: toDeleteIndex - deleteCount)
                SubscribeTableView.removeRows(at: IndexSet(integer: toDeleteIndex - deleteCount), withAnimation: .effectFade)
                deleteCount += 1
                if sbMgr.subscribes.count == 0 {
                    cleanField()
                }
            }
            SubscribeTableView.endUpdates()
        }
        self.SubscribeTableView.scrollRowToVisible(index - 1)
        self.SubscribeTableView.selectRowIndexes(IndexSet(integer: index - 1), byExtendingSelection: false)
        updateSubscribeBoxVisible()
    }
    
    func updateSubscribeBoxVisible() {
        if sbMgr.subscribes.count <= 0 {
            DeleteSubscribeBtn.isEnabled = false
            FeedTextField.isEnabled = false
            TokenTextField.isEnabled = false
            GroupTextField.isEnabled = false
            MaxCountTextField.isEnabled = false
        }else{
            DeleteSubscribeBtn.isEnabled = true
            FeedTextField.isEnabled = true
            TokenTextField.isEnabled = true
            GroupTextField.isEnabled = true
            MaxCountTextField.isEnabled = true
        }
    }
    
    func bindSubscribe(_ index:Int) {
        if index >= 0 && index < sbMgr.subscribes.count {
            editingSubscribe = sbMgr.subscribes[index]
            
            FeedTextField.bind(NSBindingName(rawValue: "value"), to: editingSubscribe, withKeyPath: "subscribeFeed", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            TokenTextField.bind(NSBindingName(rawValue: "value"), to: editingSubscribe, withKeyPath: "token", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            GroupTextField.bind(NSBindingName(rawValue: "value"), to: editingSubscribe, withKeyPath: "groupName", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            MaxCountTextField.bind(NSBindingName(rawValue: "value"), to: editingSubscribe, withKeyPath: "maxCount", options: convertToOptionalNSBindingOptionDictionary([convertFromNSBindingOption(NSBindingOption.continuouslyUpdatesValue): true]))
            
        } else {
            editingSubscribe = nil
            FeedTextField.unbind(convertToNSBindingName("value"))
            TokenTextField.unbind(convertToNSBindingName("value"))
            GroupTextField.unbind(convertToNSBindingName("value"))
            MaxCountTextField.unbind(convertToNSBindingName("value"))
        }
    }
    
    func getDataAtRow(_ index:Int) -> String {
        if sbMgr.subscribes[index].groupName != "" {
            return sbMgr.subscribes[index].groupName
        }
        return sbMgr.subscribes[index].subscribeFeed
    }
    
    // MARK: For NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let mgr = sbMgr {
            return mgr.subscribes.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView
        , objectValueFor tableColumn: NSTableColumn?
        , row: Int) -> Any? {
        
        let title = getDataAtRow(row)
        
//        if convertFromNSUserInterfaceItemIdentifier(tableColumn?.identifier) == "main" {
//            if title != "" {return title}
//            else {return "S"}
//        } else if convertFromNSUserInterfaceItemIdentifier(tableColumn?.identifier) == "status" {
//            return NSImage(named: "menu_icon")
//        }
        
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("main") {
            if title != "" {return title}
            else {return "S"}
        } else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("status") {

            return NSImage(named: NSImage.Name("menu_icon"))

        }

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
        if let mgr = sbMgr {
            var oldIndexes = [Int]()
//            info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) {,<#arg#>,<#arg#> ,<#arg#>,<#arg#> ,<#arg#>,<#arg#> ,<#arg#>,<#arg#> ,<#arg#>,<#arg#> ,<#arg#>,<#arg#> ,<#arg#>,<#arg#>
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
                    let o = mgr.subscribes.remove(at: oldIndex + oldIndexOffset)
                    mgr.subscribes.insert(o, at:row - 1)
                    tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                    oldIndexOffset -= 1
                } else {
                    let o = mgr.subscribes.remove(at: oldIndex)
                    mgr.subscribes.insert(o, at:row + newIndexOffset)
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
            editingSubscribe = nil
            return true
        }
//        if editingSubscribe != nil {
//            if !editingSubscribe.isValid() {
//                return false
//            }
//        }
        
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if SubscribeTableView.selectedRow >= 0 {
            bindSubscribe(SubscribeTableView.selectedRow)
            if (SubscribeTableView.selectedRowIndexes.count > 1){
//                duplicateProfileButton.isEnabled = false
            } else {
//                duplicateProfileButton.isEnabled = true
            }
        } else {
            if !sbMgr.subscribes.isEmpty {
                let index = IndexSet(integer: sbMgr.subscribes.count - 1)
                SubscribeTableView.selectRowIndexes(index, byExtendingSelection: false)
            }
        }
    }
    
    func cleanField(){
        FeedTextField.stringValue = ""
        TokenTextField.stringValue = ""
        GroupTextField.stringValue = ""
        MaxCountTextField.stringValue = ""
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSPasteboardPasteboardType(_ input: String) -> NSPasteboard.PasteboardType {
	return NSPasteboard.PasteboardType(rawValue: input)
}
