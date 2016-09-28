//
//  TableViewController.swift
//  SwitchIM
//
//  Created by NuRi on 2/9/15.
//  Copyright (c) 2016 Suhwan Seo. All rights reserved.
//

import Foundation
import Cocoa
import AppKit
import MASShortcut
import ServiceManagement

class TableViewController: NSViewController,NSTableViewDataSource,NSTableViewDelegate {
    
    //@IBOutlet weak var window: NSWindow!
    @IBOutlet weak var myTableView: NSTableView!
    @IBOutlet weak var appDelegate: AppDelegate!
    @IBOutlet weak var iconTypeMatrix: NSMatrix!
    @IBOutlet weak var mouseClickButton: NSButton!
    @IBOutlet weak var autoLaunchButton: NSButton!

    var dataArray:[NSMutableDictionary]! = []
    //var inputSourceModels = [InputSourceModel]()

    override func viewDidLoad() {
        super.viewDidLoad()
        LOG("viewDidLoad")

        // Register default values
        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        defaults.registerDefaults([appDelegate.IconTypeAppDefaultKey as String: appDelegate.IconTypeApp, appDelegate.ClickTweakDefaultKey as String: false, appDelegate.OpenLoginDefaultKey as String: false])

        // Reload the table
        //self.tableView.reloadData()
        
        // initilize data
        self.initInputSourceData()
        
        // setup icon type radio button
        self.setUpIconTypeRadio()
        
        // setup checkbox
        self.setUpCheckbox()
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.

        }
    }
    
    func initInputSourceData() {
        LOG("initInputSourceData")
        // clean up
        dataArray.removeAll(keepCapacity: false)
        
        // get input source list
        var inputSourceModels = [InputSourceModel]()
        inputSourceModels = SwitchIM().getList()
        let inputSourceList = inputSourceModels
        
        for inputSource in inputSourceList as [InputSourceModel] {
            let icon:NSImage = SwitchIM().getIconImage(inputSource._source)
            
            // replace . to _ cause the key uses "." in format
            let shortcut = inputSource.shortcutCodename()
            dataArray.append(["InputSource": ["Icon": icon, "InputSourceModel": inputSource ] as NSMutableDictionary, "Shortcut": shortcut])
            // for debug
            LOG("shortcut codename: \(shortcut)")
            LOG(inputSource.description())
        }
    }
    
    func setUpIconTypeRadio() {
        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        let tag = defaults.valueForKey(appDelegate.IconTypeAppDefaultKey as String) as! Int
        iconTypeMatrix.selectCellWithTag(tag)
        LOG("loaded defaults key:\(appDelegate.IconTypeAppDefaultKey) value:\(tag)")
    }

    func setUpCheckbox() {
        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        // emulate mouse click
        let mouseFlag = defaults.valueForKey(appDelegate.ClickTweakDefaultKey as String) as! Bool
        if (!mouseFlag) {
            mouseClickButton.state = NSOffState
        }
        else {
            mouseClickButton.state = NSOnState
        }
        LOG("loaded defaults key:\(appDelegate.ClickTweakDefaultKey) value:\(mouseFlag)")

        // auto launch at login
        let launchFlag = defaults.valueForKey(appDelegate.OpenLoginDefaultKey as String) as! Bool
        if (!launchFlag) {
            autoLaunchButton.state = NSOffState
        }
        else {
            autoLaunchButton.state = NSOnState
        }
        
        LOG("loaded defaults key:\(appDelegate.OpenLoginDefaultKey) value:\(launchFlag)")
    }

    
    // table
    func numberOfRowsInTableView(tableView: NSTableView) -> Int
    {
        let numberOfRows:Int = dataArray.count
        LOG("table size:\(numberOfRows)")
        return numberOfRows
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        LOG("column identifier:\(tableColumn!.identifier)")
        let object = dataArray[row] as NSMutableDictionary
        let array = object["InputSource"] as! NSMutableDictionary
        let icon = array["Icon"] as! NSImage
        let model: InputSourceModel = array["InputSourceModel"] as! InputSourceModel
        let name = model._name as String
        let id = model._ID as String
        let shortcut: NSString = object["Shortcut"] as! NSString
        //let inputSource = model._source as TISInputSourceRef
        
        var cellView: NSTableCellView!
        if ((tableColumn!.identifier) == "InputSource")
        {
            cellView = tableView.makeViewWithIdentifier("InputSource", owner: self) as! NSTableCellView
            
            let textField = cellView.textField
            textField?.stringValue = name
            let imageView = cellView.imageView
            imageView?.image = icon
        }
        else {
            cellView = tableView.makeViewWithIdentifier("Shortcut", owner: self) as! NSTableCellView
            let shortcutView: MASShortcutView = cellView.nextKeyView as! MASShortcutView
            shortcutView.associatedUserDefaultsKey = shortcut as String
            MASShortcutBinder.sharedBinder().bindShortcutWithDefaultsKey(shortcut as String, toAction: { self.shortcutAction(id, model: model) })
            shortcutView.shortcutValueChange = {shortcutView in self.appDelegate.setupStatusItem() }
        }
        return cellView
        
    }
    
    func shortcutAction(id:String, model:InputSourceModel)
    {
        LOG("shortcut pressed: \(id)")
        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        let flag = defaults.valueForKey(appDelegate.ClickTweakDefaultKey as String) as! Bool
        SwitchIM().changeInputSource(model, mouseClick: flag)

        // reset status bar
        appDelegate.setupStatusItem()
    }
    
    @IBAction func selectIconAction(sender: AnyObject) {
        let matrix:NSMatrix = sender as! NSMatrix
        let tag = matrix.selectedTag()
        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(tag, forKey: appDelegate.IconTypeAppDefaultKey as String)
        LOG("saved defaults key:\(appDelegate.IconTypeAppDefaultKey) value:\(tag)")
        
        // reset status bar
        appDelegate.setupStatusItem()
    }

    @IBAction func mouseClickAction(sender: AnyObject) {
        let button:NSButton = sender as! NSButton
        var flag:Bool = true
        if (button.state == NSOffState) {
            flag = false
        }

        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(flag, forKey: appDelegate.ClickTweakDefaultKey as String)
        LOG("saved defaults key:\(appDelegate.ClickTweakDefaultKey) value:\(flag)")
    }

    @IBAction func autoLaunchAction(sender: AnyObject) {
        let button:NSButton = sender as! NSButton
        var autoLaunch:Bool = true
        if (button.state == NSOffState) {
            autoLaunch = false
        }
        
        let defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(autoLaunch, forKey: appDelegate.OpenLoginDefaultKey as String)
        LOG("saved defaults key:\(appDelegate.OpenLoginDefaultKey) value:\(autoLaunch)")
        
        // set auto launch status
        let appBundleIdentifier = "net.nuridol.mac.SwitchIM.SwitchIMHelper"
        if SMLoginItemSetEnabled(appBundleIdentifier, autoLaunch) {
            if autoLaunch {
                LOG("Successfully add login item.")
            } else {
                LOG("Successfully remove login item.")
            }
            
        } else {
            LOG("Failed to add login item.")
        }
        
    }
}

