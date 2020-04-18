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
    
    init(initUrlString:String, initGroupName: String, initToken: String, initMaxCount: Int,initActive: Bool,initAutoUpdate:Bool){
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
        func getGroupNameFromRes(resString: String) {
            let decodeRes = decode64(resString)!
            let ssrregexp = "ssr://([A-Za-z0-9_-]+)"
            let urls = splitor(url: decodeRes, regexp: ssrregexp)
            if urls.count > 0 {
                let profile = ServerProfile.fromDictionary(ParseAppURLSchemes(URL(string: urls[0])) as [String : AnyObject])
                self.groupName = profile.ssrGroup
            }
        }
        if newGroupName != "" { return groupName = newGroupName }
        if self.cache != "" { return getGroupNameFromRes(resString: cache) }
        sendRequest(url: self.subscribeFeed, options: "", callback: { resString in
            if resString == "" { return self.groupName = "New Subscribe" }
            getGroupNameFromRes(resString: resString)
            self.cache = resString
        })
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
        return Subscribe.init(initUrlString: feed, initGroupName: group, initToken: token, initMaxCount: maxCount,initActive: isActive,initAutoUpdate: autoUpdateEnable)
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
            //            "Authorization": "Basic U2hhZG93c29ja1gtTkctUg==",
            //            "Accept": "application/json",
            "Cache-control": "no-cache",
            "token": self.token,
            "User-Agent": "ShadowsocksX-NG-R " + (getLocalInfo()["CFBundleShortVersionString"] as! String) + " Version " + (getLocalInfo()["CFBundleVersion"] as! String)
        ]
        
        AF.request(url, headers: headers)
            .responseString{
                response in
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
    func updateServerFromFeed(handle: @escaping ()->Void){
        func updateServerHandler(resString: String) {
            let decodeRes = decode64(resString)!
            let ssrregexp = "ssr://([A-Za-z0-9_-]+)"
            let urls = splitor(url: decodeRes, regexp: ssrregexp)
            // hold if user fill a maxCount larger then server return
            // Should push a notification about it and correct the user filled maxCOunt?
            let maxN = (self.maxCount > urls.count) ? urls.count : (self.maxCount == -1) ? urls.count: self.maxCount
            // TODO change the loop into random pick
            var profiles = [ServerProfile]()
            for index in 0..<maxN {
                if let profileDict = ParseAppURLSchemes(URL(string: urls[index])) {
                    let profile = ServerProfile.fromDictionary(profileDict as [String : AnyObject])
                    profiles.append(profile)
                }
            }
            // clear and add
            let clearOldGroup = true
            let group = profiles.first?.ssrGroup
            let groupSame = profiles.allSatisfy({ $0.ssrGroup == group })
            var cleanCount = 0
            if groupSame && clearOldGroup {
                // 原有的 group 中的 profile 全部清除
                let activeProfile = self.profileMgr.getActiveProfile()
                cleanCount = self.profileMgr.profiles.filter { $0.ssrGroup == group }.count
                self.profileMgr.profiles = self.profileMgr.profiles.filter { $0.ssrGroup != group || $0 == activeProfile}
            }
            
            var successCount = 0
            var dupCount = 0
            var existCount = 0
            for profile in profiles {
                let (dupResult, _) = self.profileMgr.isDuplicated(profile: profile)
                let (existResult, existIndex) = self.profileMgr.isExisted(profile: profile)
                if dupResult {
                    dupCount += 1
                    continue
                }
                if existResult {
                    self.profileMgr.profiles.replaceSubrange((existIndex..<existIndex + 1), with: [profile])
                    existCount += 1
                    continue
                }
                self.profileMgr.profiles.append(profile)
                successCount += 1
            }
            self.profileMgr.save()
            DispatchQueue.main.async {
                self.pushNotification(title: "成功更新订阅", subtitle: "总数:\(maxN) 成功:\(successCount) 清除:\(cleanCount) 重复:\(dupCount) 已存在:\(existCount)", info: "更新来自\(self.subscribeFeed)的订阅")
                NotificationCenter.default.post(name: NOTIFY_UPDATE_MAINMENU, object: nil)
                handle()
            }
        }
        
        if (!isActive){ return }

        sendRequest(url: self.subscribeFeed, options: "", callback: { resString in
            if resString == "" { return }
            updateServerHandler(resString: resString)
            self.cache = resString
        })
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
