//
//  UIViewController+Tag.m
//  RuntimeDemo
//
//  Created by Mr_Han on 2018/12/21.
//  Copyright © 2018 Mr_Han. All rights reserved.
//  CSDN <https://blog.csdn.net/u010960265>
//  GitHub <https://github.com/HanQiGod>
//

#import <objc/runtime.h>

#import "UIViewController+Tag.h"

static void *tag = &tag;

// 这里测试在分类中，利用 Runtime 来添加一个属性

@implementation UIViewController (Tag)

- (void)setTag:(NSString *)t {
    
    objc_setAssociatedObject(self, &tag, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)tag {
    
    return objc_getAssociatedObject(self, &tag);
}

@end
