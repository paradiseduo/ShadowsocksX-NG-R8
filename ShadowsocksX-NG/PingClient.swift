//
//  PingClient.swift
//  ShadowsocksX-R
//
//  Created by 称一称 on 16/9/5.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//


import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

public typealias SimplePingClientCallback = (String?)->()

var isTesting:Bool = false
var neverSpeedTestBefore:Bool = true

class PingServers:NSObject{
    
    func runCommand(cmd : String, args : String...) -> (output: [String], error: [String], exitCode: Int32) {
        
        var output : [String] = []
        var error : [String] = []
        
        let task = Process()
        task.launchPath = cmd
        task.arguments = args
        
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe
        
        task.launch()
        
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            output = string.components(separatedBy: "\n")
        }
        
        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: errdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            error = string.components(separatedBy: "\n")
        }
        
        task.waitUntilExit()
        let status = task.terminationStatus
        
        return (output, error, status)
    }
    
    func getlatencyFromString(result:String) -> Double?{
        var res = result
        if !result.contains("round-trip min/avg/max/stddev =") {
            return nil
        }
        res.removeSubrange(res.range(of: "round-trip min/avg/max/stddev = ")!)
        res = String(res.dropLast(3))
        res = res.components(separatedBy: "/")[1]
        let latency = Double(res)
        return latency
    }
    
    func ping(finish: @escaping ()->()){
        let SerMgr = ServerProfileManager.instance
        if SerMgr.profiles.count <= 0 {
            finish()
            return
        }
        
        neverSpeedTestBefore = false
        
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive)
        for i in 0..<SerMgr.profiles.count {
            group.enter()
            queue.async {
                if let outputString = self.runCommand(cmd: "/sbin/ping", args: "-c","5","-t","2",SerMgr.profiles[i].serverHost).output.last {
                    if let latency = self.getlatencyFromString(result: outputString) {
                        SerMgr.profiles[i].latency = NSNumber(value: latency)
                    }
                }
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) {
            var fastID = 0
            var fastTime = Double.infinity
            
            for k in 0..<SerMgr.profiles.count {
                let latency = SerMgr.profiles[k].latency.doubleValue
                if latency < fastTime {
                    fastTime = latency
                    fastID = k
                }
            }
            
            if fastTime != Double.infinity {
                let ft = NumberFormatter.three(SerMgr.profiles[fastID].latency)
                let notice = NSUserNotification()
                notice.title = "ICMP测试完成！最快\(ft)ms"
                notice.subtitle = "最快的是\(SerMgr.profiles[fastID].serverHost) \(SerMgr.profiles[fastID].remark)"
                
                NSUserNotificationCenter.default.deliver(notice)
                
                UserDefaults.standard.setValue("\(ft)", forKey: USERDEFAULTS_FASTEST_NODE)
                UserDefaults.standard.synchronize()
                
                DispatchQueue.main.async {
                    finish()
                }
            }
        }
    }
    
    deinit {
        print("&&&&& PingServers deinit &&&&&")
    }
}

class ConnectTestigManager {
    static let shared = ConnectTestigManager()
    
    private var tcping: Tcping?
    private var ping: PingServers?
    
    func start() {
        if !isTesting {
            isTesting = true
            if UserDefaults.standard.bool(forKey: USERDEFAULTS_TCP) {
                self.tcping = Tcping()
                self.tcping!.ping {
                    isTesting = false
                    NotificationCenter.default.post(name: NOTIFY_UPDATE_MAINMENU, object: nil)
                    self.tcping = nil
                }
            } else {
                self.ping = PingServers()
                self.ping!.ping {
                    isTesting = false
                    NotificationCenter.default.post(name: NOTIFY_UPDATE_MAINMENU, object: nil)
                    self.ping = nil
                }
            }
        }
    }
}
