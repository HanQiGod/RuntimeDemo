//
//  NSObject+JSONExtension.m
//  RuntimeDemo
//
//  Created by Mr_Han on 2018/12/21.
//  Copyright © 2018 Mr_Han. All rights reserved.
//  CSDN <https://blog.csdn.net/u010960265>
//  GitHub <https://github.com/HanQiGod>
//

#import <objc/runtime.h>

#import "NSObject+JSONExtension.h"

@implementation NSObject (JSONExtension)

// 这里测试利用 Runtime 来实现字典转模型
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    
    self = [self init];
    
    if (self) {
        unsigned int count;
        objc_property_t *propertyList = class_copyPropertyList([self class], &count);
        for (unsigned int i=0; i<count; i++) {
            // 获取属性列表
            const char *propertyName = property_getName(propertyList[i]);
            
            NSString *name = [NSString stringWithUTF8String:propertyName];
            id value = [dictionary objectForKey:name];
            if (value) {
                // 注意这里用到 KVC
                [self setValue:value forKey:name];
            }
        }
        free(propertyList);
    }
    
    return self;
}

// 这里测试利用 Runtime 来实现自动归解档
- (void)initAllPropertiesWithCoder:(NSCoder *)coder {
    
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList([self class], &count);
    for (unsigned int i=0; i<count; i++) {
        const char *propertyName = property_getName(propertyList[i]);
        NSString *name = [NSString stringWithUTF8String:propertyName];
        
        id value = [coder decodeObjectForKey:name];
        [self setValue:value forKey:name];
    }
    free(propertyList);
}

- (void)encodeAllPropertiesWithCoder:(NSCoder *)coder {
    
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList([self class], &count);
    for (unsigned int i=0; i<count; i++) {
        const char *propertyName = property_getName(propertyList[i]);
        NSString *name = [NSString stringWithUTF8String:propertyName];
        
        id value = [self valueForKey:name];
        [coder encodeObject:value forKey:name];
    }
    free(propertyList);
}


@end
