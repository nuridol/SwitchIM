//
//  GlobalFunction.swift
//  SwitchIM
//
//  Created by NuRi on 2/12/15.
//  Copyright (c) 2015 Suhwan Seo. All rights reserved.
//

import Foundation

func LOG(  _ body: Any! = "",
    function: String = __FUNCTION__,
    line: Int = __LINE__)
{
#if DEBUG
    println("[\(function) : \(line)] \(body)")
#endif
}

extension String {    
    subscript (i: Int) -> String {
        return String(Array(self)[i])
    }
    subscript (r: Range<Int>) -> String {
        var start = advance(startIndex, r.startIndex)
        var end = advance(startIndex, r.endIndex)
        return substringWithRange(Range(start: start, end: end))
    }
}
