//
//  MenuItemBaseView.swift
//  ShadowsocksX-NG
//
//  Created by ParadiseDuo on 2020/5/16.
//  Copyright © 2020 qiuyuzhou. All rights reserved.
//

import Cocoa

class ProxyMenuItem: NSMenuItem {
    let proxy: ServerProfile
    
    init(proxy: ServerProfile, action:Selector?) {
        self.proxy = proxy
        super.init(title: proxy.title(), action: action, keyEquivalent: "")
        if neverSpeedTestBefore {
            attributedTitle = self.getAttributedTitle(name: proxy.title(), delay: nil)
        } else {
            view = ProxyItemView(proxy: proxy)
        }
        self.updateSelected(proxy.uuid == ServerProfileManager.instance.getActiveProfileId())
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didClick() {
        if let action = action {
            _ = target?.perform(action, with: self)
        }
        menu?.cancelTracking()
    }
    
    private func updateSelected(_ selected: Bool) {
        if let v = view as? ProxyItemView {
            v.update(selected: selected)
        } else {
            state = selected ? .on : .off
        }
    }
    
    func getAttributedTitle(name: String, delay: String?) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: 65+ServerProfileManager.instance.maxProxyNameLength, options: [:]),
        ]
        let proxyName = name.replacingOccurrences(of: "\t", with: " ")
        let str: String
        if let delay = delay {
            str = "\(proxyName)\t\(delay)"
        } else {
            str = proxyName.appending(" ")
        }

        let attributed = NSMutableAttributedString(
            string: str,
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraph,
                NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 14),
            ]
        )

        let hackAttr = [NSAttributedString.Key.font: NSFont.menuBarFont(ofSize: 15)]
        attributed.addAttributes(hackAttr, range: NSRange(name.utf16.count..<name.utf16.count + 1))

        if delay != nil {
            let delayAttr = [NSAttributedString.Key.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)]
            attributed.addAttributes(delayAttr, range: NSRange(name.utf16.count + 1..<str.utf16.count))
        }
        return attributed
    }
}

class MenuItemBaseView: NSView {
    private let autolayout: Bool

    // MARK: Public

    var isHighlighted: Bool = false

    let effectView: NSVisualEffectView = {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.state = .active
        effectView.isEmphasized = true
        effectView.blendingMode = .behindWindow
        return effectView
    }()

    var cells: [NSCell?] {
        assertionFailure("Please override")
        return []
    }

    var labels: [NSTextField] {
        return []
    }

    static let labelFont = NSFont.menuBarFont(ofSize: 0)

    init(frame frameRect: NSRect = NSRect(x: 0, y: 0, width: 0, height: 20), autolayout: Bool) {
        self.autolayout = autolayout
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setNeedsDisplay() {
        needsDisplay = true
    }

    func didClickView() {
        assertionFailure("Please override this method")
    }

    // MARK: Private

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 20).isActive = true
        // background
        addSubview(effectView)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        if autolayout {
            effectView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            effectView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            effectView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
    }

    // MARK: Override

    override func layout() {
        super.layout()
        if !autolayout {
            effectView.frame = bounds
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        labels.forEach { $0.textColor = (enclosingMenuItem?.isEnabled ?? true) ? NSColor.labelColor : NSColor.placeholderTextColor }
        let highlighted = isHighlighted && (enclosingMenuItem?.isEnabled ?? false)
        effectView.material = highlighted ? .selection : .popover
        cells.forEach { $0?.backgroundStyle = isHighlighted ? .emphasized : .normal }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let newWindow = newWindow, !newWindow.isKeyWindow {
            newWindow.becomeKey()
        }
        updateTrackingAreas()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard autolayout else { return }
        if #available(macOS 10.15, *) {} else {
            if let view = superview {
                view.autoresizingMask = [.width]
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
    }

    override func mouseUp(with event: NSEvent) {
        DispatchQueue.main.async {
            self.didClickView()
        }
    }
}


class ProxyItemView: MenuItemBaseView {
    let nameLabel: NSTextField
    let delayLabel: NSTextField
    var imageView: NSImageView?

    static let fixedPlaceHolderWidth: CGFloat = 20 + 50 + 25

    init(proxy: ServerProfile) {
        nameLabel = VibrancyTextField(labelWithString: proxy.title())
        delayLabel = VibrancyTextField(labelWithString: "\(proxy.latency.intValue)").setup(allowsVibrancy: false)
        let cell = PaddedNSTextFieldCell()
        cell.widthPadding = 2
        cell.heightPadding = 1
        delayLabel.cell = cell
        super.init(autolayout: false)
        effectView.addSubview(nameLabel)
        effectView.addSubview(delayLabel)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        delayLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = type(of: self).labelFont
        delayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        nameLabel.alignment = .left
        delayLabel.alignment = .right

        delayLabel.wantsLayer = true
        delayLabel.layer?.cornerRadius = 2
        delayLabel.textColor = NSColor.white
        if proxy.latency.doubleValue == Double.infinity {
            update(str: "failed", value: proxy.latency.intValue)
        } else {
            update(str: "\(proxy.latency.intValue)ms", value: proxy.latency.intValue)
        }
    }

    override func layout() {
        super.layout()
        nameLabel.sizeToFit()
        delayLabel.sizeToFit()
        imageView?.frame = CGRect(x: 5, y: bounds.height / 2 - 6, width: 12, height: 12)
        nameLabel.frame = CGRect(x: 18,
                                 y: (bounds.height - nameLabel.bounds.height) / 2,
                                 width: nameLabel.bounds.width,
                                 height: nameLabel.bounds.height)
        delayLabel.frame = CGRect(x: bounds.width - delayLabel.bounds.width - 8,
                                  y: (bounds.height - delayLabel.bounds.height) / 2,
                                  width: delayLabel.bounds.width,
                                  height: delayLabel.bounds.height)
    }

    func update(str: String?, value: Int?) {
        delayLabel.stringValue = str ?? ""
        needsLayout = true

        guard let delay = value, str != nil else {
            delayLabel.layer?.backgroundColor = NSColor.clear.cgColor
            return
        }
        if 0 < delay && delay < 150 {
            delayLabel.layer?.backgroundColor = CGColor.good
        } else if 150 < delay && delay < 1000 {
            delayLabel.layer?.backgroundColor = CGColor.meduim
        } else {
            delayLabel.layer?.backgroundColor = CGColor.fail
        }
    }

    func update(selected: Bool) {
        if selected {
            if imageView == nil {
                imageView = NSImageView(image: NSImage(named: NSImage.menuOnStateTemplateName)!)
                imageView?.translatesAutoresizingMaskIntoConstraints = false
                effectView.addSubview(imageView!)
            }
        } else {
            imageView?.removeFromSuperview()
            imageView = nil
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didClickView() {
        (enclosingMenuItem as? ProxyMenuItem)?.didClick()
    }

    override var cells: [NSCell?] {
        return [nameLabel.cell, imageView?.cell]
    }
}

extension CGColor {
    static let good = CGColor(red: 30.0 / 255, green: 181.0 / 255, blue: 30.0 / 255, alpha: 1)
    static let meduim = CGColor(red: 1, green: 135.0 / 255, blue: 0, alpha: 1)
    static let fail = CGColor(red: 218.0 / 255, green: 0.0, blue: 3.0 / 255, alpha: 1)
}

extension NSColor {
    static let good = NSColor(cgColor: CGColor.good)!
    static let meduim = NSColor(cgColor: CGColor.meduim)!
    static let fail = NSColor(cgColor: CGColor.fail)!
}

class VibrancyTextField: NSTextField {
    private var _allowsVibrancy = true
    override var allowsVibrancy: Bool {
        return _allowsVibrancy
    }

    func setup(allowsVibrancy: Bool) -> Self {
        _allowsVibrancy = allowsVibrancy
        return self
    }
}

class PaddedNSTextFieldCell: NSTextFieldCell {
    var widthPadding: CGFloat = 0
    var heightPadding: CGFloat = 0

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.width += (widthPadding * 2)
        size.height += (heightPadding * 2)
        return size
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        return rect.insetBy(dx: widthPadding, dy: heightPadding)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let rect = cellFrame.insetBy(dx: widthPadding, dy: heightPadding)
        super.drawInterior(withFrame: rect, in: controlView)
    }
}
