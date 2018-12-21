//
//  NSObject+JSONExtension.h
//  RuntimeDemo
//
//  Created by Mr_Han on 2018/12/21.
//  Copyright © 2018 Mr_Han. All rights reserved.
//  CSDN <https://blog.csdn.net/u010960265>
//  GitHub <https://github.com/HanQiGod>
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (JSONExtension)

// 通过字典来初始化模型
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

// 解档所有属性
- (void)initAllPropertiesWithCoder:(NSCoder *)coder;

// 归档所有属性
- (void)encodeAllPropertiesWithCoder:(NSCoder *)coder;

@end

NS_ASSUME_NONNULL_END
