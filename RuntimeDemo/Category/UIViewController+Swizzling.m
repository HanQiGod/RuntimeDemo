//
//  UIViewController+Swizzling.m
//  RuntimeDemo
//
//  Created by Mr_Han on 2018/12/21.
//  Copyright © 2018 Mr_Han. All rights reserved.
//  CSDN <https://blog.csdn.net/u010960265>
//  GitHub <https://github.com/HanQiGod>
//

#import <objc/runtime.h>
#import "macros.h"
#import "RSSwizzle.h"

#import "UIViewController+Swizzling.h"

// 这里是测试父类和子类同时进行方法交换的情况，同时测试自定义宏 SwizzleMethod ，和 RSSwizzle

@implementation UIViewController (Swizzling)

+ (void)load {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        SwizzleMethod([self class], @selector(viewWillAppear:), @selector(AA_viewWillAppear:));
        
        // 注释掉上面的 SwizzleMethod ，使用下面更优雅安全的 RSSwizzleInstanceMethod
        //        RSSwizzleInstanceMethod([self class], @selector(viewWillAppear:), RSSWReturnType(void), RSSWArguments(BOOL animated), RSSWReplacement({
        //
        //            NSLog(@"UIViewController");
        //
        //            RSSWCallOriginal(animated);
        //
        //        }), RSSwizzleModeAlways, NULL);
        
    });
}

- (void)AA_viewWillAppear:(BOOL)animated {
    
    NSLog(@"UIViewController");
    
    [self AA_viewWillAppear:animated];
}

@end
