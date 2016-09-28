//
//  GlobalFunction.swift
//  SwitchIM
//
//  Created by NuRi on 2/12/15.
//  Copyright (c) 2016 Suhwan Seo. All rights reserved.
//

import Foundation

func LOG(  body: Any! = "",
    function: String = #function,
    line: Int = #line)
{
#if DEBUG
    print("[\(function) : \(line)] \(body)")
#endif
}

extension String {    
    subscript (i: Int) -> String {
        return String(Array(self.characters)[i])
    }
    subscript (r: Range<Int>) -> String {
        let start = startIndex.advancedBy(r.startIndex)
        let end = startIndex.advancedBy(r.endIndex)
        return substringWithRange(Range(start..<end))
    }
}
