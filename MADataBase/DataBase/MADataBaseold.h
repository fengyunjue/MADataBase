//
//  MADataBase.h
//  Sqlite3
//
//  Created by admin on 15/9/1.
//  Copyright (c) 2015年 kf5. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MADataBaseold : NSObject

+ (instancetype)shareDataBase;

/**
 *  插入数据
 */
- (BOOL)insertDataWithData:(NSObject *)data;
/**
 *  查询所有的数据
 */
- (NSMutableArray *)queryAllDataWithClass:(Class)aClass;
/**
 *  根据条件查询，如 id = 2
 */
- (NSArray *)queryDataWithClass:(Class)aClass SearchSqlStr:(NSString *)str;
/**
 *  开启数据库
 */
- (BOOL)openDataBase;
/**
 *  关闭数据库
 */
- (void)closeDataBase;

@end
