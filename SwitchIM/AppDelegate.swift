//
//  AppDelegate.swift
//  SwitchIM
//
//  Created by NuRi on 2/9/15.
//  Copyright (c) 2016 Suhwan Seo. All rights reserved.
//

import Cocoa
import MASShortcut


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusBarMenu: NSMenu!
    @IBOutlet weak var tableViewController: TableViewController!

    @IBOutlet weak var quitMenu: NSMenuItem!

    var statusBar = NSStatusBar.systemStatusBar()
    var statusBarItem : NSStatusItem!
    
    let IconTypeAppDefaultKey: NSString = "iconType"
    let ClickTweakDefaultKey: NSString = "clickTweak"
    let OpenLoginDefaultKey: NSString = "openLogin"
    let IconTypeApp: Int = 1
    let IconTypeLang: Int = 2
    
    var currentInputSourceID:NSString = ""

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        LOG("applicationDidFinishLaunching start")
        // add observer
        NSDistributedNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AppDelegate.textInputSourceDidChange(_:)), name: kTISNotifySelectedKeyboardInputSourceChanged as String?, object: "SwitchIM")

        NSDistributedNotificationCenter.defaultCenter().addObserver(self, selector: #selector(AppDelegate.textInputSourceDidEnable(_:)), name: kTISNotifyEnabledKeyboardInputSourcesChanged as String?, object: "SwitchIM")

        //statusBar items
        setupStatusItem()

        LOG("applicationDidFinishLaunching end")
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        self.statusBar.removeStatusItem(self.statusBarItem)
        NSDistributedNotificationCenter.defaultCenter().removeObserver(self)
    }

    func textInputSourceDidEnable(notification:NSNotification) {
        dispatch_async_main {
            LOG("text input source enabled notification")
            self.tableViewController.initInputSourceData()
            self.tableView.reloadData()
            self.setupStatusItem()
        }
    }
    
    func textInputSourceDidChange(notification:NSNotification) {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
        let ptrID = TISGetInputSourceProperty(currentSource as TISInputSource, kTISPropertyInputSourceID)
        let ID = unsafeBitCast(ptrID, CFStringRef.self)

        if (currentInputSourceID == ID) {
            return
        }
        currentInputSourceID = ID
        
        dispatch_async_main {
            LOG("text input source change notification")
            self.setupStatusItem()
        }
    }
    
    func setupStatusItem() -> Void {
        if (statusBarItem == nil) {
            // * swift bug
            // -1 instead of NSVariableStatusItemLength and
            // -2 instead of NSSquareStatusItemLength
            statusBarItem = statusBar.statusItemWithLength(-1)
            statusBarItem.menu = statusBarMenu
            statusBarItem.highlightMode = true
            statusBarItem.toolTip = "SwitchIM"
        }

        // icon type
        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        let iconType: Int = defaults.objectForKey(IconTypeAppDefaultKey as String) as! Int
        
        LOG("Icon type: \(iconType)")
        
        if (iconType == IconTypeApp) {
            // TEST - Start
            // let osxMode:String? = defaults.objectForKey("AppleInterfaceStyle") as! String?
            // if (osxMode == "Dark") {
            //     statusBarItem.image = NSImage(named: "StatusBarIconDark")
            // }
            // TEST -end

            statusBarItem.image = NSImage(named: "StatusBarIcon")
            statusBarItem.title = ""
            // for dark mode support
            statusBarItem.image!.template = true
            LOG("status bar icon: app icon")
        }
        else if (iconType == IconTypeLang) {
            statusBarItem.title = ""
            statusBarItem.image = SwitchIM().getCurrentIconImage()
            LOG("status bar icon: language icon")
        }
        else {
            LOG("status bar icon: Text")
            statusBarItem.image = nil
            statusBarItem.title = "IM"
        }

        // add menu item with input source
        LOG(tableViewController.dataArray.count)
        
        // remove inputSource menu
        let menu: NSMenu! = statusBarItem.menu
        let inputSourceTag:Int = 99
        var menuItem:NSMenuItem? = menu.itemWithTag(inputSourceTag)
        while (menuItem != nil) {
            menu.removeItem(menuItem!)
            menuItem = menu.itemWithTag(inputSourceTag)
        }
        
        var menuIndex:Int = 0
        let currentSource:TISInputSourceRef = SwitchIM().getCurrentInputSource()
        let currentShortcut:String = SwitchIM().getInputSourceShortcutCodename(currentSource)

        let shortcutColumnIndex = tableView.columnWithIdentifier("Shortcut")
        
        for dataDic: NSMutableDictionary in tableViewController.dataArray {
          let array = dataDic["InputSource"] as! NSMutableDictionary
            //LOG((inputSourceArray["InputSourceModel"] as InputSourceModel).description())
            let icon = array["Icon"] as! NSImage
            let model: InputSourceModel = array["InputSourceModel"] as! InputSourceModel
            let name = model._name as String
            //let id = model._ID as String
            //let inputSource:TISInputSourceRef = model._source as TISInputSourceRef
            let shortcut: NSString = dataDic["Shortcut"] as! NSString
            LOG("-- \(name)")
            let checked:Bool = (currentShortcut == shortcut)

            // add new menu
            let menuItem: NSMenuItem = NSMenuItem(title: name, action: #selector(AppDelegate.inputSourceMenuAction(_:)), keyEquivalent: "")
            menuItem.tag = inputSourceTag
            menuItem.image = icon
            if checked {
                LOG("## checked lang menu")
                menuItem.state = NSOnState
            }
            menuItem.representedObject = menuIndex
            
            // test
            //            cellView = tableView.makeViewWithIdentifier("Shortcut", owner: self) as NSTableCellView
            //let shortcutView: MASShortcutView = cellView.nextKeyView as MASShortcutView

            let shortcutColumn:NSView? = tableView.viewAtColumn(shortcutColumnIndex, row: menuIndex, makeIfNecessary: false) as NSView?
            if (shortcutColumn != nil) {
                let shortcutView:MASShortcutView = shortcutColumn!.nextKeyView as! MASShortcutView
                let masShortcut:MASShortcut? = shortcutView.shortcutValue
                
                if (masShortcut != nil) {
                    let shortcutString:String = "\(masShortcut!.modifierFlagsString)\(masShortcut!.keyCodeString)"
                    LOG("shortcut key: " + shortcutString)
                    menuItem.keyEquivalent = masShortcut!.keyCodeStringForKeyEquivalent
                    menuItem.keyEquivalentModifierMask = numericCast(masShortcut!.modifierFlags)
                }
            }

            menu.insertItem(menuItem, atIndex: menuIndex)
            menuIndex = menuIndex + 1
        }
    }
    
    func dispatch_async_main(block: () -> ()) {
        dispatch_async(dispatch_get_main_queue(), block)
    }

    @IBAction func inputSourceMenuAction(sender: NSMenuItem) {
        LOG("selected: input source menu \(sender.title) index: \(sender.representedObject)")
        if (sender.representedObject != nil) {
            let index:Int = sender.representedObject as! Int
            let dataDic: NSMutableDictionary = tableViewController.dataArray[index]
            let array: NSMutableDictionary = dataDic["InputSource"] as! NSMutableDictionary
            let model: InputSourceModel = array["InputSourceModel"] as! InputSourceModel
            let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
            let flag = defaults.valueForKey(ClickTweakDefaultKey as String) as! Bool

            SwitchIM().changeInputSource(model, mouseClick: flag)
        }
        self.setupStatusItem()

    }
    
    @IBAction func quitAction(sender: NSMenuItem) {
        LOG("selected: quit menu")
        NSApplication.sharedApplication().terminate(self)
    }

    @IBAction func aboutAction(sender: AnyObject) {
        LOG("selected: about menu")
        NSApp.activateIgnoringOtherApps(true)
        NSApp.orderFrontStandardAboutPanel(self)
    }

    @IBAction func preferenceAction(sender: NSMenuItem) {
        LOG("selected: preferences menu")
        NSApp.activateIgnoringOtherApps(true)
        window.makeKeyAndOrderFront(self)

        
    }
}

