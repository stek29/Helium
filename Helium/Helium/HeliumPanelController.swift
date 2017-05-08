//
//  HeliumPanelController.swift
//  Helium
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//

import AppKit

let optionKeyCode: UInt16 = 58

class URLField: NSTextField {
	override func mouseDown(with event: NSEvent) {
		super.mouseDown(with: event)
		if let textEditor = currentEditor() {
			textEditor.selectAll(self)
		}
	}

	convenience init(string: String?) {
		self.init()

		if let string = string { self.stringValue = string }
		self.lineBreakMode = NSLineBreakMode.byTruncatingHead
		self.usesSingleLineMode = true
	}
}

class HeliumPanelController : NSWindowController {

    fileprivate var webViewController: WebViewController {
        get {
            return self.window?.contentViewController as! WebViewController
        }
    }

    fileprivate var mouseOver: Bool = false
    
    fileprivate var alpha: CGFloat = 0.6 { //default
        didSet {
            updateTranslucency()
        }
    }
    
    fileprivate var translucencyPreference: TranslucencyPreference = .always {
        didSet {
            updateTranslucency()
        }
    }
    
    fileprivate var translucencyEnabled: Bool = false {
        didSet {
            updateTranslucency()
        }
    }

    
    fileprivate  enum TranslucencyPreference {
        case always
        case mouseOver
        case mouseOutside
    }
    
    fileprivate var currentlyTranslucent: Bool = false {
        didSet {
            if !NSApplication.shared().isActive {
                panel.ignoresMouseEvents = currentlyTranslucent
            }
            if currentlyTranslucent {
                panel.animator().alphaValue = alpha
                panel.isOpaque = false
            }
            else {
                panel.isOpaque = true
                panel.animator().alphaValue = 1
            }
        }
    }
    
    
    fileprivate var panel: NSPanel! {
        get {
            return (self.window as! NSPanel)
        }
    }
    
    
    // MARK: Window lifecycle
    override func windowDidLoad() {
        panel.isFloatingPanel = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(HeliumPanelController.didBecomeActive), name: NSNotification.Name.NSApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HeliumPanelController.willResignActive), name: NSNotification.Name.NSApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HeliumPanelController.didUpdateTitle(_:)), name: Notification.Name(rawValue: "HeliumUpdateTitle"), object: nil)
        
        setFloatOverFullScreenApps()
        if let alpha = UserDefaults.standard.object(forKey: UserSetting.opacityPercentage.userDefaultsKey) {
            didUpdateAlpha(CGFloat(alpha as! Int))
        }
    }

    // MARK : Mouse events
    override func mouseEntered(with theEvent: NSEvent) {
        mouseOver = true
        updateTranslucency()
    }
    
    override func mouseExited(with theEvent: NSEvent) {
        mouseOver = false
        updateTranslucency()
    }
    
    // MARK : Translucency
    fileprivate func updateTranslucency() {
        currentlyTranslucent = shouldBeTranslucent()
    }
    
    fileprivate func shouldBeTranslucent() -> Bool {
        /* Implicit Arguments
         * - mouseOver
         * - translucencyPreference
         * - tranlucencyEnalbed
         */
        
        guard translucencyEnabled else { return false }
        
        switch translucencyPreference {
        case .always:
            return true
        case .mouseOver:
            return mouseOver
        case .mouseOutside:
            return !mouseOver
        }
    }
    
    
    fileprivate func setFloatOverFullScreenApps() {
        if UserDefaults.standard.bool(forKey: UserSetting.disabledFullScreenFloat.userDefaultsKey) {
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        } else {
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
    }
    
    //MARK: IBActions
    
    fileprivate func disabledAllMouseOverPreferences(_ allMenus: [NSMenuItem]) {
        // GROSS HARD CODED
        for x in allMenus.dropFirst(2) {
            x.state = NSOffState
        }
    }
    
    @IBAction fileprivate func alwaysPreferencePress(_ sender: NSMenuItem) {
        disabledAllMouseOverPreferences(sender.menu!.items)
        translucencyPreference = .always
        sender.state = NSOnState
    }
    
    @IBAction fileprivate func overPreferencePress(_ sender: NSMenuItem) {
        disabledAllMouseOverPreferences(sender.menu!.items)
        translucencyPreference = .mouseOver
        sender.state = NSOnState
    }
    
    @IBAction fileprivate func outsidePreferencePress(_ sender: NSMenuItem) {
        disabledAllMouseOverPreferences(sender.menu!.items)
        translucencyPreference = .mouseOutside
        sender.state = NSOnState
    }
    
    @IBAction fileprivate func translucencyPress(_ sender: NSMenuItem) {
        if sender.state == NSOnState {
            sender.state = NSOffState
            didDisableTranslucency()
        }
        else {
            sender.state = NSOnState
            didEnableTranslucency()
        }
    }
    
    @IBAction fileprivate func percentagePress(_ sender: NSMenuItem) {
        for button in sender.menu!.items{
            (button ).state = NSOffState
        }
        sender.state = NSOnState
        let value = sender.title.substring(to: sender.title.characters.index(sender.title.endIndex, offsetBy: -1))
        if let alpha = Int(value) {
             didUpdateAlpha(CGFloat(alpha))
             UserDefaults.standard.set(alpha, forKey: UserSetting.opacityPercentage.userDefaultsKey)
        }
    }
    
    @IBAction fileprivate func openLocationPress(_ sender: AnyObject) {
		didRequestUserUrl(
			currentURL: self.webViewController.currentURL,
			messageText: "Enter Destination URL",
			acceptTitle: "Load",
			cancelTitle: "Cancel",
			acceptHandler: { (newUrl: String) in
				self.webViewController.loadURL(text: newUrl)
			}
		)
    }

    @IBAction fileprivate func openFilePress(_ sender: AnyObject) {
        didRequestFile()
    }
    
    @IBAction fileprivate func floatOverFullScreenAppsToggled(_ sender: NSMenuItem) {
        sender.state = (sender.state == NSOnState) ? NSOffState : NSOnState
        UserDefaults.standard.set((sender.state == NSOffState), forKey: UserSetting.disabledFullScreenFloat.userDefaultsKey)
        
        setFloatOverFullScreenApps()
    }

    @IBAction fileprivate func hideTitle(_ sender: NSMenuItem) {
        if sender.state == NSOnState {
            sender.state = NSOffState
            panel.styleMask.remove(.titled)
        } else {
            sender.state = NSOnState
            // somehow removing .titled also removes .utitlityWindow, which is required
            panel.styleMask.update(with: [ .titled, .utilityWindow ])
            panel.title = self.webViewController.webView.title ?? "";
        }
    }

    @IBAction func setHomePage(_ sender: AnyObject){
		didRequestUserUrl(
			currentURL: UserDefaults.standard.string(forKey: UserSetting.homePageURL.userDefaultsKey),
			messageText: "Enter new Home Page URL",
			acceptTitle: "Set",
			cancelTitle: "Cancel",
			acceptHandler: { (newUrlConstant: String) in
				var newUrl = newUrlConstant

				if !(newUrl.lowercased().hasPrefix("http://") || newUrl.lowercased().hasPrefix("https://")) {
					newUrl = "http://" + newUrl
				}

				// Save to defaults and loads it
				UserDefaults.standard.set(newUrl, forKey: UserSetting.homePageURL.userDefaultsKey)
				self.webViewController.loadURL(text: newUrl)
		})
    }
    
    //MARK: Actual functionality
    @objc fileprivate func didUpdateTitle(_ notification: Notification) {
        if let title = notification.object as? String {
            panel.title = title
        }
    }
    
    fileprivate func didRequestFile() {
        let open = NSOpenPanel()
        open.allowsMultipleSelection = false
        open.canChooseFiles = true
        open.canChooseDirectories = false
        
        if open.runModal() == NSModalResponseOK {
            if let url = open.url {
				webViewController.loadURL(url: url)
            }
        }
    }

	func validateURL (_ stringURL : String) -> Bool {
		let urlRegEx = "(https?://)?((\\w|-)+)(([.]|[/])((\\w|-)+))+"
		let predicate = NSPredicate(format:"SELF MATCHES %@", argumentArray:[urlRegEx])

		return predicate.evaluate(with: stringURL)
	}

	/// Shows alert asking user to input URL
	/// And validate it
	fileprivate func didRequestUserUrl(currentURL: String?, messageText: String, acceptTitle: String, cancelTitle: String, acceptHandler: @escaping (String) -> Void) {
		// Create alert
		let alert = NSAlert()
		alert.alertStyle = NSAlertStyle.informational
		alert.messageText = messageText

		// Create urlField
		let urlField = URLField(string: currentURL)
		urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)

		// Add urlField and buttons to alert
		alert.accessoryView = urlField
		alert.addButton(withTitle: acceptTitle)
		alert.addButton(withTitle: cancelTitle)

		alert.beginSheetModal(for: self.window!, completionHandler: { response in
			// first button is accept
			if response == NSAlertFirstButtonReturn {
				let newUrl = (alert.accessoryView as! NSTextField).stringValue
				if self.validateURL(newUrl) {
					acceptHandler(newUrl)
				}
			}
		})

		// Set focus on urlField
		alert.accessoryView!.becomeFirstResponder()
	}

    @objc fileprivate func didBecomeActive() {
        panel.ignoresMouseEvents = false
    }
    
    @objc fileprivate func willResignActive() {
        if currentlyTranslucent {
            panel.ignoresMouseEvents = true
        }
    }
    
    fileprivate func didEnableTranslucency() {
        translucencyEnabled = true
    }
    
    fileprivate func didDisableTranslucency() {
        translucencyEnabled = false
    }
    
    fileprivate func didUpdateAlpha(_ newAlpha: CGFloat) {
        alpha = newAlpha / 100
    }
}
