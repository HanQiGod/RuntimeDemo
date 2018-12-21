//
//  ObjectModel.m
//  RuntimeDemo
//
//  Created by Mr_Han on 2018/12/21.
//  Copyright © 2018 Mr_Han. All rights reserved.
//  CSDN <https://blog.csdn.net/u010960265>
//  GitHub <https://github.com/HanQiGod>
//

#import "NSObject+JSONExtension.h"

#import "ObjectModel.h"

@interface ObjectModel ()

@property (nonatomic, readwrite) NSString *title;
@property (nonatomic, readwrite) NSInteger count;

@end

@implementation ObjectModel

- (id)initWithCoder:(NSCoder *)aDecoder{
    
    self = [super init];
    if (self) {
        // 调用封装好的自动归档方法
        [self initAllPropertiesWithCoder:aDecoder];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder{
    
    // 调用封装好的自动解档方法
    [self encodeAllPropertiesWithCoder:aCoder];
}

@end
