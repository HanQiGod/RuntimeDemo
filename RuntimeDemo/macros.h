//
//  macros.h
//  RuntimeDemo
//
//  Created by Mr_Han on 2018/12/21.
//  Copyright © 2018 Mr_Han. All rights reserved.
//  CSDN <https://blog.csdn.net/u010960265>
//  GitHub <https://github.com/HanQiGod>
//

#ifndef macros_h
#define macros_h



/**
 *  Method swizzling
 */
#define SwizzleMethod(class, originalSelector, swizzledSelector) {              \
    Method originalMethod = class_getInstanceMethod(class, (originalSelector)); \
    Method swizzledMethod = class_getInstanceMethod(class, (swizzledSelector)); \
    if (!class_addMethod((class),                                               \
        (originalSelector),                                    \
        method_getImplementation(swizzledMethod),              \
        method_getTypeEncoding(swizzledMethod))) {             \
            method_exchangeImplementations(originalMethod, swizzledMethod);         \
    } else {                                                                    \
        class_replaceMethod((class),                                            \
        (swizzledSelector),                                 \
        method_getImplementation(originalMethod),           \
        method_getTypeEncoding(originalMethod));            \
    }                                                                           \
}




#endif /* macros_h */
