//
//  Subscribe.swift
//  ShadowsocksX-NG
//
//  Created by 秦宇航 on 2017/6/15.
//  Copyright © 2017年 qiuyuzhou. All rights reserved.
//

import Foundation
import Alamofire

@objcMembers class Subscribe: NSObject{
    
    var subscribeFeed = ""
    var isActive = true
    var autoUpdateEnable = true
    var maxCount = 0 // -1 is not limited
    var groupName = ""
    var token = ""
    var cache = ""
    
    var profileMgr: ServerProfileManager!
    
    init(initUrlString:String, initGroupName: String, initToken: String, initMaxCount: Int, initActive: Bool, initAutoUpdate:Bool){
        super.init()
        subscribeFeed = initUrlString

        token = initToken
        
        isActive = initActive
        
        autoUpdateEnable = initAutoUpdate
    
        setMaxCount(initMaxCount: initMaxCount)
        setGroupName(newGroupName: initGroupName)
        profileMgr = ServerProfileManager.instance
    }
    func getFeed() -> String{
        return subscribeFeed
    }
    func setFeed(newFeed: String){
        subscribeFeed = newFeed
    }
    func diactivateSubscribe(){
        isActive = false
    }
    func activateSubscribe(){
        isActive = true
    }
    func enableAutoUpdate(){
        autoUpdateEnable = true
    }
    func disableAutoUpdate(){
        autoUpdateEnable = false
    }
    func getAutoUpdateEnable() -> Bool {
        return autoUpdateEnable
    }
    
    func setGroupName(newGroupName: String) {
        if newGroupName != "" {
            groupName = newGroupName
            return
        }
        if self.cache != "" {
            getSSRURLsFromRes(resString: cache)
            return
        }
    }
    func getGroupName() -> String {
        return groupName
    }
    func getMaxCount() -> Int {
        return maxCount
    }
    static func fromDictionary(_ data:[String:AnyObject]) -> Subscribe {
        var feed:String = ""
        var group:String = ""
        var token:String = ""
        var maxCount:Int = -1
        var isActive:Bool = true
        var autoUpdateEnable:Bool = true
        
        
        for (key, value) in data {
            switch key {
            case "feed":
                feed = value as! String
            case "group":
                group = value as! String
            case "token":
                token = value as! String
            case "maxCount":
                maxCount = value as! Int
            case "isActive":
                isActive = value as! Bool
            case "autoUpdateEnable":
                autoUpdateEnable = value as! Bool
            default:
                print("")
            }
        }
        return Subscribe(initUrlString: feed, initGroupName: group, initToken: token, initMaxCount: maxCount,initActive: isActive,initAutoUpdate: autoUpdateEnable)
    }
    static func toDictionary(_ data: Subscribe) -> [String: AnyObject] {
        var ret : [String: AnyObject] = [:]
        ret["feed"] = data.subscribeFeed as AnyObject
        ret["group"] = data.groupName as AnyObject
        ret["token"] = data.token as AnyObject
        ret["maxCount"] = data.maxCount as AnyObject
        ret["isActive"] = data.isActive as AnyObject
        ret["autoUpdateEnable"] = data.autoUpdateEnable as AnyObject
        return ret
    }
    fileprivate func sendRequest(url: String, options: Any, callback: @escaping (String) -> Void) {
        if url.isEmpty { return }
        let headers: HTTPHeaders = [
            "Cache-control": "no-cache",
            "token": self.token,
            "User-Agent": "ShadowsocksX-NG-R " + (getLocalInfo()["CFBundleShortVersionString"] as! String) + " Version " + (getLocalInfo()["CFBundleVersion"] as! String)
        ]
        
        Network.sharedSession.request(url, headers: headers).responseString{ response in
            do {
                let value = try response.result.get()
                callback(value)
            } catch {
                callback("")
                self.pushNotification(title: "请求失败", subtitle: "", info: "发送到\(url)的请求失败，请检查您的网络")
            }
        }
    }
    func setMaxCount(initMaxCount:Int) {
        func getMaxFromRes(resString: String) {
            let maxCountReg = "MAX=[0-9]+"
            let decodeRes = decode64(resString)!
            let range = decodeRes.range(of: maxCountReg, options: .regularExpression)
            if let r = range {
                self.maxCount = Int(decodeRes[r].replacingOccurrences(of: "MAX=", with: ""))!
            }
            else{
                self.maxCount = -1
            }
        }
        if initMaxCount != 0 { return self.maxCount = initMaxCount }
        if cache != "" { return getMaxFromRes(resString: cache) }
        sendRequest(url: self.subscribeFeed, options: "", callback: { resString in
            if resString == "" { return }// Also should hold if token is wrong feedback
            getMaxFromRes(resString: resString)
            self.cache = resString
        })
    }
    func updateServerFromFeed(handle: @escaping ()->()) {
        func updateServerHandler(resString: String) {
            let urls = self.getSSRURLsFromRes(resString: resString)
            // hold if user fill a maxCount larger then server return
            // Should push a notification about it and correct the user filled maxCount?
            let maxN = (self.maxCount > urls.count) ? urls.count : (self.maxCount == -1) ? urls.count: self.maxCount
            
            // 存一下原有group中的 profile ，为了计算下列数量
            let oldNodes = self.profileMgr.profiles.filter { $0.ssrGroup == self.getGroupName()}
            // 原有的 group 中的 profile 全部清除
            self.profileMgr.profiles = self.profileMgr.profiles.filter { $0.ssrGroup != self.getGroupName()}
            
            //更新对应4种情况：
            //1.节点原来存在，更新后被删除
            //2.节点原来不存在，更新后增加
            //3.节点原来存在，并且更新完之后啥也不用干（本地节点信息跟服务端已经一致）
            //4.节点原来存在，只更新内容（本地节点与服务端信息不一致，比如密码换了）
            var subCount = 0
            var addCount = 0
            var dupCount = 0
            var existCount = 0
            //这里处理后三种情况
            var newNodes = [ServerProfile]()
            for index in 0..<maxN {
                if let profileDict = ParseAppURLSchemes(URL(string: urls[index])) {
                    let profile = ServerProfile.fromDictionary(profileDict as [String : AnyObject])
                    newNodes.append(profile)
                    let (exists, duplicated) = ServerProfileManager.isDuplicatedOrExists(oldNodes, profile)
                    if duplicated {
                        dupCount += 1
                    } else if exists {
                        existCount += 1
                    } else {
                        addCount += 1
                    }
                } else {
                    print("\(index), \(urls[index]) ParseAppURLSchemes Error!")
                }
            }
            //这里处理第一种情况
            for item in oldNodes {
                if !newNodes.contains(where: { (s) -> Bool in
                    return item.isSame(profile: s)
                }) {
                    subCount += 1
                }
            }
            //将更新后的节点加回原来的数组
            for item in newNodes {
                self.profileMgr.profiles.append(item)
            }
            
            self.profileMgr.save()
            DispatchQueue.main.async {
                var message = "节点总数:\(maxN)"
                if dupCount > 0 {
                    message += " 无需更新:\(dupCount)"
                }
                if existCount > 0 {
                    message += " 更新:\(existCount)"
                }
                if addCount > 0 {
                    message += " 新增:\(addCount)"
                }
                if subCount > 0 {
                    message += " 删除:\(subCount)"
                }
                self.pushNotification(title: "成功更新订阅", subtitle: message, info: "更新来自\(self.subscribeFeed)的订阅")
                NotificationCenter.default.post(name: NOTIFY_UPDATE_MAINMENU, object: nil)
                handle()
            }
        }
        
        if !isActive {
            handle()
            return
        }
        
        sendRequest(url: self.subscribeFeed, options: "", callback: { resString in
            if resString == "" {
                handle()
                return
            }
            updateServerHandler(resString: resString)
            self.cache = resString
        })
    }
    
    @discardableResult func getSSRURLsFromRes(resString: String) -> [String] {
        let decodeRes = decode64(resString)!
        let ssrregexp = "ssr://([A-Za-z0-9_-]+)"
        let urls = splitor(url: decodeRes, regexp: ssrregexp)
        if urls.count > 0 {
            let profile = ServerProfile.fromDictionary(ParseAppURLSchemes(URL(string: urls[0])) as [String : AnyObject])
            self.groupName = profile.ssrGroup
        }
        return urls
    }
    
    func feedValidator() -> Bool{
        // is the right format
        // should be http or https reg
        // but we should not support http only feed
        // TODO refine the regular expression
        let feedRegExp = "http[s]?://[A-Za-z0-9-_/.=?]*"
        return subscribeFeed.range(of:feedRegExp, options: .regularExpression) != nil
    }
    fileprivate func pushNotification(title: String, subtitle: String, info: String){
        let userNote = NSUserNotification()
        userNote.title = title
        userNote.subtitle = subtitle
        userNote.informativeText = info
        userNote.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default
            .deliver(userNote);
    }
    class func isSame(source: Subscribe, target: Subscribe) -> Bool {
        return source.subscribeFeed == target.subscribeFeed && source.token == target.token && source.maxCount == target.maxCount
    }
    func isExist(_ target: Subscribe) -> Bool {
        return self.subscribeFeed == target.subscribeFeed
    }
}
