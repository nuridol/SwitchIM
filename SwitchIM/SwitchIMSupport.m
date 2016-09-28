//
//  SwitchIMSupport.m
//  SwitchIM
//
//  Created by NuRi on 2/14/15.
//  Copyright (c) 2016 Suhwan Seo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import "SwitchIMSupport.h"

@implementation SwitchIMSupport
- (NSArray *)createInputSourceList:(CFDictionaryRef)properties flag:(Boolean) includeAllInstalled {
    NSArray *array = (__bridge NSArray *)(TISCreateInputSourceList(properties, includeAllInstalled));
    return array;
}
@end