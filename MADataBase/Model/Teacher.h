//
//  Teacher.h
//  Sqlite3
//
//  Created by admin on 15/9/2.
//  Copyright (c) 2015年 kf5. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Car.h"

@interface Teacher : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) Car *car;

//@property (nonatomic, assign) int age;
//@property (nonatomic, assign) BOOL sex;

@end
