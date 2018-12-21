//
//  UIButton+Swizzling.m
//  RuntimeDemo
//
//  Created by Mr_Han on 2018/12/21.
//  Copyright © 2018 Mr_Han. All rights reserved.
//  CSDN <https://blog.csdn.net/u010960265>
//  GitHub <https://github.com/HanQiGod>
//

#import "RSSwizzle.h"
#import "UIButton+Swizzling.h"

@implementation UIButton (Swizzling)

// 这里测试通过方法交换来实现按钮点击事件上报

+ (void)load {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        RSSwizzleInstanceMethod([self class],
                                @selector(sendAction:to:forEvent:),
                                RSSWReturnType(void),
                                RSSWArguments(SEL action, id target, UIEvent *event),
                                RSSWReplacement({
            
            NSString *name = NSStringFromClass([self class]);
            
            NSLog(@"UIButton+Swizzling：%@ 按钮被点击--上报", name);
            
            RSSWCallOriginal(action, target, event);
            
        }), RSSwizzleModeAlways, NULL);
        
    });
}

@end
