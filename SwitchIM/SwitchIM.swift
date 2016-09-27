//
//  SwitchIM.swift
//  SwitchIM
//
//  Created by NuRi on 2/6/15.
//  Copyright (c) 2016 Suhwan Seo. All rights reserved.
//

import Foundation
import Cocoa
import Carbon
import AppKit

class SwitchIM {
    
    func getList() -> [InputSourceModel] {
        var inputSourceArray: [InputSourceModel] = []
        
        // get input source list
        let property1 = "\(kTISPropertyInputSourceIsSelectCapable)"
        let property2 = "\(kTISPropertyInputSourceCategory)"

        let dict : NSMutableDictionary = [property1: kCFBooleanTrue, property2: kTISCategoryKeyboardInputSource]
        //let dic : CFDictionary? = nil
//        let flag : DarwinBoolean = 0

        let list = TISCreateInputSourceList(dict, false).takeUnretainedValue() as NSArray
        
        //let support:SwitchIMSupport = SwitchIMSupport()
        //let list = support.createInputSourceList(dict, flag: flag)
        
        //let list = TISCreateASCIICapableInputSourceList().takeUnretainedValue() as NSArray
        
        // loop list
        for inputSource in list as! [TISInputSource] {
            //LOG(inputSource)
            
            let ptrType = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputSourceType)
            let type = unsafeBitCast(ptrType, CFStringRef.self)
            
            let ptrModeID = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputModeID)
            var modeID = "-"
            if (ptrModeID != nil) {
                modeID = unsafeBitCast(ptrModeID, CFStringRef.self) as String
            }

            let ptrID = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputSourceID)
            let ID = unsafeBitCast(ptrID, CFStringRef.self)
            
            let ptrName = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyLocalizedName)
            let name = unsafeBitCast(ptrName, CFStringRef.self)
            
            let ptrCategory = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputSourceCategory)
            let category = unsafeBitCast(ptrCategory, CFStringRef.self)

//            let ptrSelectable = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputSourceIsSelectCapable)
//            let selectable = unsafeBitCast(ptrSelectable, CFBooleanRef.self)
//            LOG("selecable: \(CFBooleanGetValue(selectable))")

//            let ptrEnable = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputSourceIsEnabled)
//            if (ptrEnable != nil) {
//                let enable = unsafeBitCast(ptrEnable, CFBooleanRef.self)
//                LOG("enable: \(CFBooleanGetValue(enable))")
//            }

            LOG("Type: \(type) ID: \(ID) modeID: \(modeID) Name: \(name) category: \(category)")
            
            if (type == kTISTypeKeyboardInputMode || type == kTISTypeKeyboardLayout) {
                LOG("match : input mode")
                LOG(inputSource)

                if (type == kTISTypeKeyboardInputMode) {
                    let infoString: String = "\(inputSource)"
                    if infoString.rangeOfString("Parent = ", options: .RegularExpressionSearch) != nil {
                        let parent: String = infoString.stringByReplacingOccurrencesOfString("^.*Parent = |\\)$", withString:"", options:NSStringCompareOptions.RegularExpressionSearch, range: nil)

                        LOG("check parent(\(parent))...")
                        // get input source list
                        let propertyID = "\(kTISPropertyInputSourceID)"
                        let parentDict : NSMutableDictionary = [propertyID: parent]
                        let parentList = TISCreateInputSourceList(parentDict, false)
                        if (parentList != nil) {
                            LOG("OK: parent is enabled")
                        }
                        else if ((ID as String).hasPrefix("org.youknowone.inputmethod.Gureum")) {
                            LOG("OK: parent is disabled but it's Gureum IM")
                            
                        }
                        else {
                            LOG("NG: parent is disabled. skip")
                            continue
                        }
                    }
                }
                
                let model = InputSourceModel(ID:ID as String, modeID:modeID, name:name as String, source:inputSource)
                inputSourceArray.append(model)
            }
            
        }
        return inputSourceArray
    }
    
    func changeInputSource(model:InputSourceModel, mouseClick:Bool=true) -> Bool {
        LOG("change to \(model._name)")
        //        let pre = TISCopyCurrentKeyboardInputSource()
        //        LOG(pre)
        
        let source:TISInputSourceRef = model._source
        //TISEnableInputSource(source)
        let status = TISSelectInputSource(source)

/*
        let layoutStatus = TISSetInputMethodKeyboardLayoutOverride(source)
        if (layoutStatus == Int32(paramErr)) {
            LOG("fail to TISSetInputMethodKeyboardLayoutOverride")
            //            println("source:\(model._name)")
            //            let layout = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()
            //            let layoutStatus2 = TISSetInputMethodKeyboardLayoutOverride()
            //            println(layoutStatus2)
            //            TISSelectInputSource(source)
        }
        
        let ptrModeID = TISGetInputSourceProperty(source as TISInputSource, kTISPropertyInputModeID)
        if (ptrModeID != nil) {
            let size: UInt32 = numericCast(sizeof(CFStringRef))
            let property: TSMDocumentPropertyTag = numericCast(kTSMDocumentInputModePropertyTag)
            let status = TSMSetDocumentProperty(TSMGetActiveDocument(), property, size, ptrModeID)
            LOG("TSMSetDocumentProperty status:\(status)")
        }
*/
        // changing input source was not working well,
        if mouseClick {
            //  do magic tricks with mouse click
            self.makeMouseEvent()
        }
        else {
            // do magic tricks with "select the previous input source shortcut"
            self.makeShortcutEvent()
        }
        
        if (status == noErr) {
            LOG(" - keyboard changed: \(model._name)")
            return true
        }
        LOG(" - keyboard change failed: \(model._name)")
        return false
    }
    
    func makeShortcutEvent() -> Void {
        // reference sources:
        // https://github.com/tekezo/Karabiner/blob/master/src/util/read-symbolichotkeys/read-symbolichotkeys/main.m
        
        // default KeyCode: 0x31, Flag: CONTROL_L
        var keyCode:CGKeyCode = CGKeyCode.init(0x31)
        var keyMask = CGEventFlags.MaskControl.rawValue
        
        repeat {
            // read "select the previous input source shortcut"
            let dict:NSDictionary? =  NSUserDefaults.standardUserDefaults().persistentDomainForName("com.apple.symbolichotkeys")
            
            if (dict == nil) {
                LOG("Error: com.apple.symbolichotkeys is not found.")
                break
            }
            
            let symbolichotkeys:NSDictionary? = dict!["AppleSymbolicHotKeys"] as? NSDictionary
            if (symbolichotkeys == nil) {
                LOG("Error: AppleSymbolicHotKeys is not found.")
                break
            }
            
            let symbolichotkey:NSDictionary? = symbolichotkeys!["60"] as? NSDictionary
            if (symbolichotkey == nil) {
                // No entry
                break
            }
            
            let value:NSDictionary? = symbolichotkey!["value"] as? NSDictionary
            if (value == nil) {
                LOG("Error: value is not found.")
                break
            }
            
            let parameters:NSArray? = value!["parameters"] as? NSArray
            if (parameters == nil) {
                LOG("Error: parameters is not found.")
                break
            }
            
            let key:Int = parameters![1] as! Int
            let modifiers = parameters![2] as! Int

            // reset key mask
            keyMask = 0x0
            if (modifiers > 0) {
                if (modifiers & 0x20000 != 0) {
                    keyMask = keyMask | CGEventFlags.MaskShift.rawValue
                }
                if (modifiers & 0x40000 != 0) {
                    keyMask = keyMask | CGEventFlags.MaskControl.rawValue
                }
                if (modifiers & 0x80000 != 0) {
                    keyMask = keyMask | CGEventFlags.MaskAlternate.rawValue
                }
                if (modifiers & 0x100000 != 0) {
                    keyMask = keyMask | CGEventFlags.MaskCommand.rawValue
                }
            }
            keyCode = CGKeyCode.init(key)
            LOG("previous input source shortcut: \(keyMask) + \(keyCode)")
        } while(false)

        let keyDown = CGEventCreateKeyboardEvent(nil, keyCode, true)
        let keyUp = CGEventCreateKeyboardEvent(nil, keyCode, false)
        
        let maskFlags = CGEventFlags(rawValue: keyMask)!
        CGEventSetFlags(keyDown, maskFlags)

        // call shortcut 2 times with 150ms delay
        for _ in 0...1 {
            LOG("change input source shortcut down")
            CGEventPost(CGEventTapLocation.CGHIDEventTap, keyDown)

            LOG("change input source shortcut up")
            CGEventPost(CGEventTapLocation.CGHIDEventTap, keyUp)
            NSThread.sleepForTimeInterval(0.15)
        }
    }
    
    func makeMouseEvent() -> Void {
        // mouse click simulation
        
        // remember original mouse location
        let event: CGEventRef? = CGEventCreate(nil)
        let currentLocation = CGEventGetLocation(event)
        LOG("mouse position:\(currentLocation)")
        
        // apple!
        let location = CGPointMake(26,12)
        
        let ptrClickDown = CGEventCreateMouseEvent(nil, CGEventType.LeftMouseDown, location, CGMouseButton.Left)
        let clickDown = unsafeBitCast(ptrClickDown, CGEventRef.self)
        
        let ptrClickUp = CGEventCreateMouseEvent(nil, CGEventType.LeftMouseUp, location, CGMouseButton.Left)
        let clickUp = unsafeBitCast(ptrClickUp, CGEventRef.self)
        
        CGEventPost(CGEventTapLocation.CGHIDEventTap, clickDown)
        CGEventPost(CGEventTapLocation.CGHIDEventTap, clickUp)
        CGEventPost(CGEventTapLocation.CGHIDEventTap, clickDown)
        CGEventPost(CGEventTapLocation.CGHIDEventTap, clickUp)
        
        // restore mouse location
        let ptrMove = CGEventCreateMouseEvent(nil, CGEventType.MouseMoved, currentLocation, CGMouseButton.Left)
        let move = unsafeBitCast(ptrMove, CGEventRef.self)
        CGEventPost(CGEventTapLocation.CGHIDEventTap, move)
    }
    
    
    func getIconImage(inputSource: TISInputSourceRef) -> NSImage! {
        var image:NSImage?
        
        let ptrIcon = TISGetInputSourceProperty(inputSource, kTISPropertyIconRef)
        if (ptrIcon != nil) {
            let icon: IconRef = unsafeBitCast(ptrIcon, IconRef.self)
            image = NSImage(iconRef: icon)
        }
        else {
            let ptrIconURL = TISGetInputSourceProperty(inputSource, kTISPropertyIconImageURL)
            let iconURL = unsafeBitCast(ptrIconURL, CFURLRef.self)
            let url:NSURL = iconURL
            //        LOG("URL:\(url)")
            
            var err: NSError?
            var imageData :NSData?
            do {
                imageData = try NSData(contentsOfURL: url,options: NSDataReadingOptions.DataReadingMappedIfSafe)
            } catch let error as NSError {
                err = error
                imageData = nil
                LOG(err)
            }

            if (imageData == nil)
            {
                //let reason : String? = err?.localizedFailureReason
                //LOG("Error reading from URL: \(err)")
                
                // retry with tiff
                LOG("retry with tiff icon")
                let parentDirectory = url.URLByDeletingLastPathComponent
                let fileNameWithExtension: NSString! = url.lastPathComponent
                let fileName = fileNameWithExtension.stringByDeletingPathExtension
                let fileExtension = "tiff"
                let newFileName = NSString(format:"%@.%@",fileName,fileExtension)
                let newURL: NSURL! = NSURL(string: newFileName as String, relativeToURL: parentDirectory)
                do {
                    imageData = try NSData(contentsOfURL: newURL,options: NSDataReadingOptions.DataReadingMappedIfSafe)
                } catch let error as NSError {
                    err = error
                    imageData = nil
                    LOG(err)
                }
            }
            image = NSImage(data: imageData!)
        }
        image?.size = NSSize(width: 16, height: 16)
        return image!
    }
    
    func getCurrentIconImage() -> NSImage! {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
        LOG(currentSource)
        return getIconImage(currentSource)
    }

    func getCurrentInputSource() -> TISInputSourceRef {
        let currentSource:TISInputSourceRef = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
        return currentSource
    }
    
    func getInputSourceShortcutCodename(inputSource:TISInputSourceRef) -> String {
        let ptrID = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputSourceID)
        let ID = unsafeBitCast(ptrID, CFStringRef.self)

        let ptrModeID = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputModeID)
        var modeID = "-"
        if (ptrModeID != nil) {
            modeID = unsafeBitCast(ptrModeID, CFStringRef.self) as String
        }
        let model:InputSourceModel = InputSourceModel(ID: ID as String, modeID: modeID, name: "", source: inputSource)

        return model.shortcutCodename()
    }
}

class InputSourceModel {
    var _ID:String = ""
    var _modeID:String = ""
    var _name:String = ""
    var _source:TISInputSourceRef
    
    init(ID:String, modeID:String, name:String, source:TISInputSourceRef) {
        _ID = ID
        _name = name
        _source = source
        _modeID = modeID
    }
    
    func description() -> String {
        return String("ID: \(_ID) ModeID: \(_modeID) Name: \(_name) InputSource: \(_source)")
    }

    func shortcutCodename() -> String {
        return self.shortcutCodename(_ID, modeID: _modeID)
    }
    
    func shortcutCodename(ID:String, modeID:String) -> String {
        let codename:String = (ID + "#" + modeID).stringByReplacingOccurrencesOfString(".", withString: "_", options: [], range: nil)
        return codename
    }
}
