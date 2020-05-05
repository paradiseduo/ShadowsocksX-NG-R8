//
//  Network.swift
//  ShadowsocksX-NG
//
//  Created by ParadiseDuo on 2020/4/27.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Cocoa
import Alamofire

class Network {
    private static let requestQueue = DispatchQueue(label: "Network")
    private static let sharedProxySession: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5
        if let a = UserDefaults.standard.string(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_ADDRESS), let p = UserDefaults.standard.value(forKey: USERDEFAULTS_LOCAL_SOCKS5_LISTEN_PORT) as? NSNumber {
            let proxyConfiguration: [AnyHashable : Any] = [kCFNetworkProxiesSOCKSEnable : true, kCFNetworkProxiesSOCKSProxy: a, kCFNetworkProxiesSOCKSPort: p.intValue]
            configuration.connectionProxyDictionary = proxyConfiguration
        }
        return Session(configuration: configuration, rootQueue: DispatchQueue.main, startRequestsImmediately: true, requestQueue: Network.requestQueue)
    }()
    
    private static let sharedSession: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5
        let proxyConfiguration: [AnyHashable : Any] = [kCFNetworkProxiesSOCKSEnable : false]
        configuration.connectionProxyDictionary = proxyConfiguration
        return Session(configuration: configuration, rootQueue: DispatchQueue.main, startRequestsImmediately: true, requestQueue: Network.requestQueue)
    }()
    
    static func session(useProxy: Bool) -> Session {
        if UserDefaults.standard.bool(forKey: USERDEFAULTS_SHADOWSOCKS_ON) {
            if useProxy {
                return sharedProxySession
            } else {
                return sharedSession
            }
        } else {
            return sharedSession
        }
    }
}
