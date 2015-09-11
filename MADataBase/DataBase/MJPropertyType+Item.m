//
//  MJPropertyType+Item.m
//  MADataBase
//
//  Created by admin on 15/9/11.
//  Copyright (c) 2015年 kf5. All rights reserved.
//

#import "MJPropertyType+Item.h"

@implementation MJPropertyType (Item)

/**
 *  转换类型
 */
- (NSString *)dbType
{
    if ([self.code isEqualToString:@"NSString"]) {
        return @"TEXT";
    }else if ([self.code isEqualToString:@"i"]||[self.code isEqualToString:@"B"]||[self.code isEqualToString:@"q"]||[self.code isEqualToString:@"Q"]){
        return @"INTEGER";
    }else if([self.code isEqualToString:@"d"]||[self.code isEqualToString:@"f"]||[self.code isEqualToString:@"NSDate"]){
        return @"REAL";
    }else if([self.code isEqualToString:@"NSData"]){
        return @"BLOB";
    }else if([self.code isEqualToString:@"NSArray"]||[self.code isEqualToString:@"NSDictionary"]){
        return nil;
    }else if(self.typeClass != nil && !self.isFromFoundation){
        return @"OBJECT";
    }else{
        return nil;
    }
}

@end
