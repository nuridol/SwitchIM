//
//  SwitchIMSupport.h
//  SwitchIM
//
//  Created by Seo, Suhwan | Sunny | ISDOD on 2/14/15.
//  Copyright (c) 2015 Suhwan Seo. All rights reserved.
//

#ifndef SwitchIM_SwitchIMSupport_h
#define SwitchIM_SwitchIMSupport_h

@interface SwitchIMSupport : NSObject {
    
}

- (NSArray *)createInputSourceList:(CFDictionaryRef)properties flag:(Boolean) includeAllInstalled;
@end

#endif
