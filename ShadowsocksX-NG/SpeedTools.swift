//
//  SpeedTools.swift
//  ShadowsocksX-NG
//
//  Created by ParadiseDuo on 2020/5/1.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Foundation

class SpeedTools {
    static let KB:Float = 1
    static let MB:Float = KB*1024
    static let GB:Float = MB*1024
    static let TB:Float = GB*1024
    
    static var statusBarTextAttributes : [NSAttributedString.Key : Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.maximumLineHeight = 10
        paragraphStyle.paragraphSpacing = -7
        paragraphStyle.alignment = .right
        return [
            NSAttributedString.Key.font : NSFont.monospacedDigitSystemFont(ofSize: 9, weight: NSFont.Weight.medium),
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ] as [NSAttributedString.Key : Any]
    }
    
    static func formatRateData(_ data:Float) -> String {
        var result:Float
        var unit: String
        
        if data < SpeedTools.KB {
            result = 0
            return "0 KB/s"
        }
            
        else if data < SpeedTools.MB {
            result = data/SpeedTools.KB
            unit = " KB/s"
            return String(format: "%0.0f", result) + unit
        }
            
        else if data < SpeedTools.GB {
            result = data/SpeedTools.MB
            unit = " MB/s"
        }
            
        else if data < SpeedTools.TB {
            result = data/SpeedTools.GB
            unit = " GB/s"
        }
            
        else {
            result = 1023
            unit = " GB/s"
        }
        
        if result < 100 {
            return String(format: "%0.2f", result) + unit
        }
        else if result < 999 {
            return String(format: "%0.1f", result) + unit
        }
        else {
            return String(format: "%0.0f", result) + unit
        }
    }
    
    static func speedAttributedString(up: Double, down: Double) -> NSAttributedString {
        return NSAttributedString(string: "\n\(SpeedTools.formatRateData(Float(up))) ↑\n\(SpeedTools.formatRateData(Float(down))) ↓", attributes: SpeedTools.statusBarTextAttributes)
    }
}
