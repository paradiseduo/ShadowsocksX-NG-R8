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
    static let sharedSession: Session = {
         let configuration = URLSessionConfiguration.default
         configuration.timeoutIntervalForRequest = 6
        return Session(configuration: configuration)
    }()
}
