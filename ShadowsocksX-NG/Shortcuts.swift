//
//  Shortcuts.swift
//  ShadowsocksX-NG
//
//  Created by ParadiseDuo on 2020/5/12.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Foundation

class Shortcuts {
    static func bindShortcuts() {
        let binder = MASShortcutBinder.shared()
        binder?.bindShortcut(withDefaultsKey: "ToggleRunning", toAction: {
            NotificationCenter.default.post(name: NOTIFY_TOGGLE_RUNNING_SHORTCUT, object: nil)
        })
        binder?.bindShortcut(withDefaultsKey: "SwitchPACMode", toAction: {
            NotificationCenter.default.post(name: NOTIFY_SWITCH_PAC_MODE_SHORTCUT, object: nil)
        })
        binder?.bindShortcut(withDefaultsKey: "SwitchGlobalMode", toAction: {
            NotificationCenter.default.post(name: NOTIFY_SWITCH_GLOBAL_MODE_SHORTCUT, object: nil)
        })
        binder?.bindShortcut(withDefaultsKey: "SwitchWhiteListMode", toAction: {
            NotificationCenter.default.post(name: NOTIFY_SWITCH_WHITELIST_MODE_SHORTCUT, object: nil)
        })
        binder?.bindShortcut(withDefaultsKey: "SwitchManualMode", toAction: {
            NotificationCenter.default.post(name: NOTIFY_SWITCH_MANUAL_MODE_SHORTCUT, object: nil)
        })
        binder?.bindShortcut(withDefaultsKey: "SwitchACLAutoMode", toAction: {
            NotificationCenter.default.post(name: NOTIFY_SWITCH_ACL_AUTO_MODE_SHORTCUT, object: nil)
        })
        binder?.bindShortcut(withDefaultsKey: "SwitchChinaMode", toAction: {
            NotificationCenter.default.post(name: NOTIFY_SWITCH_CHINA_MODE_SHORTCUT, object: nil)
        })
    }
}
