//
//  SwitchIMSupport.h
//  SwitchIM
//
//  Created by NuRi on 2/14/15.
//  Copyright (c) 2016 Suhwan Seo. All rights reserved.
//

#ifndef SwitchIM_SwitchIMSupport_h
#define SwitchIM_SwitchIMSupport_h

@interface SwitchIMSupport : NSObject {
    
}

- (NSArray *)createInputSourceList:(CFDictionaryRef)properties flag:(Boolean) includeAllInstalled;
@end

#endif
