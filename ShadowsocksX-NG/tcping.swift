//
//  tcping.swift
//  tcping
//
//  Created by ParadiseDuo on 2020/3/26.
//  Copyright © 2020 ParadiseDuo. All rights reserved.
//

import Cocoa

class TcpCollection {
    
    fileprivate var list = [tcping]()
    
    func append(_ newElm: tcping) {
        list.append(newElm)
    }
    
    var count: Int {
        get {
            return list.count
        }
    }
    
    var first: tcping? {
        get {
            return list.first
        }
    }
    
    subscript(index:Int) -> tcping {
        get {
            return list[index]
        }
        set(newElm) {
            list.insert(newElm, at: index)
        }
    }
    
    func insert(_ newElm: tcping, index: Int)  {
        list.insert(newElm, at: index)
    }
    
    func averageSpeed() -> NSNumber {
        let successArr = list.filter { (p) -> Bool in
            return p.speed != TimeInterval.infinity
        }
        if successArr.count > 0 {
            let avge = successArr.reduce(0.0) { (result: Double, p: tcping) -> Double in return result+p.speed}/Double(successArr.count)
            return NSNumber(value: avge)
        }
        return NSNumber(value: Double.infinity)
    }
}

class tcping: NSObject, GCDAsyncSocketDelegate {
    var socket:GCDAsyncSocket?
    var startTime = Date()
    var speed = TimeInterval.infinity
    var domain = ""
    var host = ""
    var port:UInt16 = 80
    
    func connectSocket(domain: String, port: UInt16) {
        self.domain = domain
        self.port = port
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        if !self.socket!.isConnected {
            do {
                startTime = Date()
                try self.socket?.connect(toHost: domain, onPort: port, withTimeout: Tcping.timeout)
            } catch let error {
                print(error)
            }
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        self.host = host
        self.speed = Date().timeIntervalSince(startTime) * 1000
        sock.disconnect()
    }
}

class Tcping {
    static let timeout:TimeInterval = 0.9
    
    var count = 5
    var timer:Timer?
    var speedStringDomain = [String: TcpCollection]()
    var pings = [tcping]()
    
    static let instance = Tcping()
    
    func ping() {
        let SerMgr = ServerProfileManager.instance
        if SerMgr.profiles.count <= 0 {
            return
        }
        
        neverSpeedTestBefore = false
        count = 5
        self.timer = Timer.scheduledTimer(withTimeInterval: Tcping.timeout+0.1, repeats: true) { [weak self] (t) in
            guard let w = self else {return}
            if w.count > 0 {
                print("Tcping Residual times \(w.count)")
                for item in SerMgr.profiles {
                    let t = tcping()
                    w.pings.append(t)
                    t.connectSocket(domain: item.serverHost, port: item.serverPort)
                }
                w.count-=1
            } else {
                w.timer?.invalidate()
                w.timer = nil
                //对结果按照域名进行分组
                for item in w.pings {
                    var inserted = false
                    if let ts = w.speedStringDomain[item.domain] {
                        ts.append(item)
                        inserted = true
                    }
                    if !inserted {
                        let ts = TcpCollection()
                        ts.append(item)
                        w.speedStringDomain[item.domain] = ts
                    }
                }
                
                let nf = NumberFormatter()
                nf.numberStyle = .decimal
                nf.maximumFractionDigits = 3
                var fastID = 0
                var fastSpeed = Double.infinity
                //存数据与找出最快节点
                for i in 0..<SerMgr.profiles.count {
                    let speed = w.speedStringDomain[SerMgr.profiles[i].serverHost]!.averageSpeed()
                    if speed.doubleValue != Double.infinity {
                        SerMgr.profiles[i].latency = speed
                    }
                    if speed.doubleValue < fastSpeed {
                        fastSpeed = speed.doubleValue
                        fastID = i
                    }
                }
                
                //因为是个单例，数组不会释放，因此需要清空数据，以免下次测试混入前一次的数据
                w.pings.removeAll()
                w.speedStringDomain = [String: TcpCollection]()
                if fastSpeed != Double.infinity {
                    let ft = NumberFormatter.three(SerMgr.profiles[fastID].latency)
                    let notice = NSUserNotification()
                    notice.title = "TCP测试完成！最快\(ft)ms"
                    notice.subtitle = "最快的是\(SerMgr.profiles[fastID].serverHost) \(SerMgr.profiles[fastID].remark)"
                    
                    NSUserNotificationCenter.default.deliver(notice)
                    
                    UserDefaults.standard.setValue("\(ft)", forKey: USERDEFAULTS_FASTEST_NODE)
                    UserDefaults.standard.synchronize()
                    
                    DispatchQueue.main.async {
                        isTesting = false
                        NotificationCenter.default.post(name: NOTIFY_UPDATE_MAINMENU, object: nil)
                    }
                }
            }
        }

    }
}
