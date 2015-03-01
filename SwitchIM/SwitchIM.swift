//
//  SwitchIM.swift
//  SwitchIM
//
//  Created by NuRi on 2/6/15.
//  Copyright (c) 2015 Suhwan Seo. All rights reserved.
//

import Foundation
import Cocoa
import Carbon
import AppKit

class SwitchIM {
    
    func getList() -> [InputSourceModel] {
        var inputSourceArray: [InputSourceModel] = []
        
        // get input source list
        var property1 = "\(kTISPropertyInputSourceIsSelectCapable)"
        var property2 = "\(kTISPropertyInputSourceCategory)"

        var dict : NSMutableDictionary = [property1: kCFBooleanTrue, property2: kTISCategoryKeyboardInputSource]
        //let dic : CFDictionary? = nil
        let flag : Boolean = 0

        let list = TISCreateInputSourceList(dict, 0).takeUnretainedValue() as NSArray
        
        //let support:SwitchIMSupport = SwitchIMSupport()
        //let list = support.createInputSourceList(dict, flag: flag)
        
        //let list = TISCreateASCIICapableInputSourceList().takeUnretainedValue() as NSArray
        
        // loop list
        for inputSource in list as [TISInputSource] {
            //LOG(inputSource)
            
            let ptrType = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputSourceType)
            let type = unsafeBitCast(ptrType, CFStringRef.self)
            
            let ptrModeID = TISGetInputSourceProperty(inputSource as TISInputSource, kTISPropertyInputModeID)
            var modeID = "-"
            if (ptrModeID != nil) {
                modeID = unsafeBitCast(ptrModeID, CFStringRef.self)
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
                    var infoString: String = "\(inputSource)"
                    if let range = infoString.rangeOfString("Parent = ", options: .RegularExpressionSearch) {
                        var parent: String = infoString.stringByReplacingOccurrencesOfString("^.*Parent = |\\)$", withString:"", options:NSStringCompareOptions.RegularExpressionSearch, range: nil)

                        LOG("check parent(\(parent))...")
                        // get input source list
                        var propertyID = "\(kTISPropertyInputSourceID)"
                        var parentDict : NSMutableDictionary = [propertyID: parent]
                        let parentList = TISCreateInputSourceList(parentDict, 0)
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
                
                let model = InputSourceModel(ID:ID, modeID:modeID, name:name, source:inputSource)
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
        // changing input source was not working well. do magic tricks with mouse click
        if mouseClick {
            self.makeMouseEvent()
        }
        
        if (status == noErr) {
            LOG(" - keyboard changed: \(model._name)")
            return true
        }
        LOG(" - keyboard change failed: \(model._name)")
        return false
    }
    
    func makeMouseEvent() -> Void {
        // mouse click simulation
        
        // remember original mouse location
        let event: CGEventRef = CGEventCreate(nil).takeRetainedValue()
        let currentLocation = CGEventGetLocation(event)
        LOG("mouse position:\(currentLocation)")
        
        // apple!
        let location = CGPointMake(26,12)
        
        let ptrClickDown = CGEventCreateMouseEvent(nil, kCGEventLeftMouseDown, location, numericCast(kCGMouseButtonLeft))
        let clickDown = unsafeBitCast(ptrClickDown, CGEventRef.self)
        
        let ptrClickUp = CGEventCreateMouseEvent(nil, kCGEventLeftMouseUp, location, numericCast(kCGMouseButtonLeft))
        let clickUp = unsafeBitCast(ptrClickUp, CGEventRef.self)
        
        CGEventPost(numericCast(kCGHIDEventTap), clickDown)
        CGEventPost(numericCast(kCGHIDEventTap), clickUp)
        CGEventPost(numericCast(kCGHIDEventTap), clickDown)
        CGEventPost(numericCast(kCGHIDEventTap), clickUp)
        
        // restore mouse location
        let ptrMove = CGEventCreateMouseEvent(nil, kCGEventMouseMoved, currentLocation, numericCast(kCGMouseButtonLeft))
        let move = unsafeBitCast(ptrMove, CGEventRef.self)
        CGEventPost(numericCast(kCGHIDEventTap), move)
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
            var imageData :NSData? = NSData(contentsOfURL: url,options: NSDataReadingOptions.DataReadingMappedIfSafe, error: &err)
            if (imageData == nil)
            {
                //let reason : String? = err?.localizedFailureReason
                //LOG("Error reading from URL: \(err)")
                
                // retry with tiff
                LOG("retry with tiff icon")
                let parentDirectory = url.URLByDeletingLastPathComponent?
                let fileNameWithExtension: NSString! = url.lastPathComponent
                let fileName = fileNameWithExtension.stringByDeletingPathExtension
                let fileExtension = "tiff"
                let newFileName = NSString(format:"%@.%@",fileName,fileExtension)
                let newURL: NSURL! = NSURL(string: newFileName, relativeToURL: parentDirectory)
                imageData = NSData(contentsOfURL: newURL,options: NSDataReadingOptions.DataReadingMappedIfSafe, error: &err)
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
            modeID = unsafeBitCast(ptrModeID, CFStringRef.self)
        }
        let model:InputSourceModel = InputSourceModel(ID: ID, modeID: modeID, name: "", source: inputSource)

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
        let codename:String = (ID + "#" + modeID).stringByReplacingOccurrencesOfString(".", withString: "_", options: nil, range: nil)
        return codename
    }
}
