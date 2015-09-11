//
//  MADataBase.m
//  Sqlite3
//
//  Created by admin on 15/9/7.
//  Copyright (c) 2015年 kf5. All rights reserved.
//

#import "MADataBase.h"
#import <FMDB.h>
#import <MJExtension.h>
#import "MJProperty.h"
#import <objc/runtime.h>
#import "MJPropertyType+Item.h"

@implementation MADataBase
{
    FMDatabase *_dataBase;
}
static MADataBase *_instance;

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

+ (instancetype)shareDataBase
{
    if (_instance == nil) {
        _instance = [[self alloc]init];
    }
    return _instance;
}


- (BOOL)initDataBaseWithClass:(Class)aClass
{
    if ([self openDataBase]) {
        return [self createTableWithClass:aClass];
    }else{
        return NO;
    }
}

#pragma mark - 打开数据库
- (BOOL)openDataBase
{
    if (!_dataBase) {
        _dataBase = [FMDatabase databaseWithPath:[self dataFilePath]];
    }
    
    if (![_dataBase open]) {
        NSLog(@"打开数据库失败");
        return NO;
    }else{
        return YES;
    }
}

#pragma mark - 关闭数据库
- (void)closeDataBase
{
    [_dataBase close];
}

#pragma mark - 检验数据表是否存在
-(BOOL)checkTableNameWithClass:(Class)aClass{
    
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM sqlite_master where type=\'table\' and name=\'%@\';",[self tableNameWithClass:aClass]];
    
    FMResultSet *rs = [_dataBase executeQuery:sql];
    
    [rs next];
    
    if ([rs intForColumnIndex:0] == 1) {
        return YES;
    }else{
        return NO;
    }
}
#pragma mark - 创建表
- (BOOL)createTableWithClass:(Class)aClass
{
    if ([self checkTableNameWithClass:aClass]) {
        return YES;
    }
    
    // 1. 创建sql语句
    NSString *tableName = [self tableNameWithClass:aClass];
    
    NSMutableString *sql = [NSMutableString string];
    
    NSArray *properties = [aClass properties];
    [sql appendFormat:@"CREATE TABLE IF NOT EXISTS %@ (id INTEGER PRIMARY KEY AUTOINCREMENT,",tableName];

    for (int i = 0; i< properties.count; i++) {
        MJProperty *property = properties[i];
        if ([property.name isEqualToString:@"id"]) {
            continue;
        }
        if (property.type.dbType != nil) {
            if ([property.type.dbType isEqualToString:@"OBJECT"]) {
                if ([self createTableWithClass:property.type.typeClass]) {
                    [sql appendFormat:@"%@ INTEGER,",property.name];
                }
            }else{
                [sql appendFormat:@"%@ %@,",property.name,property.type.dbType];
            }
        }
    }

    [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];
    [sql appendString:@")"];

    
    NSLog(@"创建语句---%@",sql);
    
   return [_dataBase executeUpdate:sql];
}

#pragma mark - 插入数据
- (BOOL)insertDataWithData:(NSObject *)data
{
    if ([self initDataBaseWithClass:object_getClass(data)]) {
        return [self insertWithData:data mainClass:object_getClass(data)];
    }else{
        return 0;
    }
}
/**
 *  先将data的表为从表的数据插入完成
 */
- (int)insertWithData:(NSObject *)data mainClass:(Class)mainClass
{
    if (data == nil) return 0;
    
    // 1. 创建sql语句
    NSString *tableName = [self tableNameWithData:data];
    NSMutableString *sql = [NSMutableString string];
    
    NSArray *properties = [object_getClass(data) properties];
    [sql appendFormat:@"INSERT INTO %@ (",tableName];
    NSMutableString *valusStr = [NSMutableString stringWithString:@"VALUES("];
    
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:properties.count];
    
    for (int i = 0; i< properties.count; i++) {
        MJProperty *property = properties[i];
        if ([property.name isEqualToString:@"id"]) { continue;}
        if (property.type.dbType == nil) {continue;}
        if ([property.type.dbType isEqualToString:@"OBJECT"]){
            NSNumber *number = @([self insertWithData:[property valueForObject:data] mainClass:mainClass]);
            [values addObject:number];
        }else{
            if ([property.type.dbType isEqualToString:@"JSON"]) {
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[property valueForObject:data] options:NSJSONWritingPrettyPrinted error:NULL];
                [values addObject:jsonData];
            }else if ([property.type.dbType isEqualToString:@"URL"]){
                [values addObject:[property valueForObject:data]];
            }else{
                [values addObject:[property valueForObject:data]];
            }
        }
        [sql appendFormat:@"%@,",property.name];
        [valusStr appendString:@"?,"];
    }
    
    [sql replaceCharactersInRange:NSMakeRange(sql.length - 1, 1) withString:@")"];
    [valusStr replaceCharactersInRange:NSMakeRange(valusStr.length - 1, 1) withString:@")"];
    
    [sql appendString:valusStr];
    NSLog(@"插入语句---%@",sql);
    
    if (object_getClass(data) != mainClass) {
        int search_id = [self queryIDWithClass:object_getClass(data) Values:values];
        if (search_id){
            NSLog(@"存在该数据---%d",search_id);
            return search_id;
        }
    }

    
    if ([_dataBase executeUpdate:sql withArgumentsInArray:values]) {
        return (int)[_dataBase lastInsertRowId];
    }else{
        return 0;
    }
}

#pragma mark - 删除数据
#pragma mark 删除所有数据
- (BOOL)deleteAllDataWithClass:(Class)aClass
{
    return [self deleteDataWithClass:aClass SearchSqlStr:nil];
}
#pragma mark 按条件删除数据
- (BOOL)deleteDataWithClass:(Class)aClass SearchSqlStr:(NSString *)sqlStr
{
    if ([self initDataBaseWithClass:aClass]) {
        NSMutableString *sql = [NSMutableString string];
        if (sqlStr.length == 0) { // 没有附加条件,删除相关的表
            for (Class fClass in [self allClassWithMainClass:aClass]) {
                NSString *tableName = [self tableNameWithClass:fClass];
                [sql appendFormat:@"delete from %@;",tableName];
            }
        }else{
            NSString *tableName = [self tableNameWithClass:aClass];
            [sql appendFormat:@"delete from %@ WHERE %@;",tableName,sqlStr];
            
//            for (Class fClass in [self allClassWithMainClass:aClass]) {
//                for (MJProperty *property in [fClass properties]) {
//                    if ([property.type.dbType isEqualToString:@"OBJECT"]) {
//                        int count = [self queryDataCountWithClass:fClass foreignClass:property.type.typeClass foreignValue:]
//                    }
//                }
//                
//            }
            
        }
        [_dataBase executeUpdate:sql];
        
        [_dataBase executeQueryWithFormat:@"SELECT id FROM deleted"];
        FMResultSet *rs = [_dataBase executeQuery:sql];
       
        while ([rs next]) {
            for (int i = 0; i < [rs columnCount]; i++) {
                NSLog(@"%@---%@",[rs columnNameForIndex:i],[rs objectForColumnIndex:i]);
            }
//            NSNumber *number = [rs objectForColumnName:@"id"];
//            if (![number isEqual:[NSNull null]])
//                [array addObject:number];
        }
        [rs close];

        
        return YES;
    }
    return NO;
}
#pragma mark 删除单条数据
//- (BOOL)deleteDataWithClass:(Class)aClass SearchSqlStr:(NSString *)sqlStr
//{
//    if (self initDataBaseWithClass:<#(__unsafe_unretained Class)#>) {
//        <#statements#>
//    }
//    
//    return NO;
//}

#pragma mark - 查询数据
#pragma mark 查询所有数据
- (NSArray *)queryAllDataWithClass:(Class)aClass
{
    return [self queryDataWithClass:aClass SearchSqlStr:nil];
}
#pragma mark 查询外键的id是否存在于多条数据
/**
 *  查询外键的id存在在多少条数据中
 *
 *  @return 数量
 */
- (int)queryDataCountWithClass:(Class)aClass foreignClass:(Class)foreignClass foreignValue:(int)foreignValue
{
    NSMutableString *searchSql = [NSMutableString string];
    [searchSql appendFormat:@"%@ = \'%d\'",NSStringFromClass(foreignClass),foreignValue];
    NSMutableArray *array = [self queryIdCountWithClass:aClass SearchSqlStr:searchSql];
    return (int)array.count;
}

#pragma mark 全条件查询
/**
 *  全条件查询
 *
 *  @return 查询到的id值
 */
- (int)queryIDWithClass:(Class)aClass Values:(NSArray *)values
{
    NSMutableString *searchSql = [NSMutableString string];

    for (int i = 0; i < [aClass properties].count; i++) {
        
        MJProperty *property = [aClass properties][i];
        if ([property.name isEqualToString:@"id"]) { continue;}
        if (property.type.dbType == nil) {continue;}
        
        NSObject *value = values[i];
        
        if ([property.type.dbType isEqualToString:@"OBJECT"]) {
            [searchSql appendFormat:@" %@ = \'%@\' and",property.name,value];
        }else{
            [searchSql appendFormat:@" %@ = \'%@\' and",property.name,value];
        }
    }
    if (values.count > 0)
        [searchSql deleteCharactersInRange:NSMakeRange(searchSql.length - 3, 3)];
    // 2. 执行sql语句
    int search_id = 0;
    NSArray *array = [self queryIdCountWithClass:aClass SearchSqlStr:searchSql];
    if (array.count > 0) {
        search_id = ((NSNumber *)array[0]).intValue;
    }
    return search_id;

}

#pragma mark 普通查询
/**
 *  普通查询
 *
 *  @return id的数组
 */
- (NSMutableArray *)queryIdCountWithClass:(Class)aClass SearchSqlStr:(NSString *)str
{
    NSMutableArray *array = nil;
    
    if ([self initDataBaseWithClass:aClass]) {
        NSString *tableName = [self tableNameWithClass:aClass];
        // 1. 创建sql语句
        NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT * FROM %@ ",tableName];
        if (str.length > 0) {
            [sql appendFormat:@"WHERE %@",str];
        }
        // 2. 执行sql语句
        FMResultSet *rs = [_dataBase executeQuery:sql];
        while ([rs next]) {
            if (array == nil) {
                array = [NSMutableArray array];
            }
            NSNumber *number = [rs objectForColumnName:@"id"];
            if (![number isEqual:[NSNull null]])
                [array addObject:number];
        }
        [rs close];
    }
    
    return array;
}

#pragma mark 根据条件级联查询数据
- (NSMutableArray *)queryDataWithClass:(Class)aClass SearchSqlStr:(NSString *)str
{
    if ([self initDataBaseWithClass:aClass]) {
        
        NSString *tableName = [self tableNameWithClass:aClass];
        // 1. 创建sql语句
        NSMutableString *sql = [NSMutableString stringWithString:@"SELECT "];
        
        for (Class mainClass in [self allClassWithMainClass:aClass]) {
            for (MJProperty *property in [mainClass properties]) {
                NSString *str = nil;
                
                if ([property.type.dbType isEqualToString:@"OBJECT"]) {
                    str = [NSString stringWithFormat:@"%@.%@",[self tableNameWithClass:mainClass],property.name];
                }else{
                    str = [NSString stringWithFormat:@"%@.%@",[self tableNameWithClass:mainClass],property.name];
                }
                
                [sql appendFormat:@" %@ as \'%@\' ,",str,str];

            }
        }
        [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];

        [sql appendFormat:@" FROM %@ ",tableName];
        [sql appendString:[self foreignSQLWithMainClass:aClass]];
        
        if (str.length > 0) {
            [sql appendFormat:@" and %@",str];
        }
        NSLog(@"查询语句--%@",sql);
        
        // 2. 执行sql语句
        FMResultSet *rs = [_dataBase executeQuery:sql];
        NSMutableArray *array = nil;
        
        for (int i = 0; i < [rs columnCount]; i++) {
            NSLog(@"%@",[rs columnNameForIndex:i]);
        }
        while ([rs next]) {
            
            if (array == nil) {
                array = [NSMutableArray array];
            }
            
            [array addObject:[self columnWithClass:aClass ResultSet:rs]];
        }
        [rs close];
        
        return array;
        
    }
    return nil;
}

/**
 *  对查询结果进行赋值
 */
- (NSObject *)columnWithClass:(Class)aClass ResultSet:(FMResultSet *)rs{
    
    NSObject *object = [[aClass alloc]init];
    
    NSMutableArray *properties = [aClass properties];
    
    for (int i = 0 ; i < properties.count; i++) {
        MJProperty *property = properties[i];
        
        NSObject *value = nil;
        if ([property.type.dbType isEqualToString:@"OBJECT"]) {
            value = [self columnWithClass:property.type.typeClass ResultSet:rs];
        }else{
            id obj = [rs objectForColumnName:[NSString stringWithFormat:@"%@.%@",[self tableNameWithClass:aClass],property.name]];
            if ([obj isEqual:[NSNull null]]) {continue;}
            if([property.type.dbType isEqualToString:@"JSON"]){
                value = [NSJSONSerialization JSONObjectWithData:obj options:NSJSONReadingMutableContainers error:NULL];
            }else if([property.type.dbType isEqualToString:@"URL"]){
                value = [NSURL URLWithString:obj];
            }else if(property.type.typeClass == [NSDate class]){
                value = [NSDate dateWithTimeIntervalSince1970:((NSNumber *)obj).longLongValue];
            }else{
                value = obj;
            }
        }
        if (value && ![value isEqual:[NSNull null]]) {[object setValue:value forKey:property.name];}
    }
    return object;
}

/**
 *  查询外键关联关系
 */
- (NSString *)foreignSQLWithMainClass:(Class)aClass
{
    NSMutableString *sql = [NSMutableString string];
    
    for (MJProperty *property in [aClass properties]) {
        if ([property.type.dbType isEqualToString:@"OBJECT"]) {
            NSString *tableName = [self tableNameWithClass:aClass];
            NSString *foreignTableName = [self tableNameWithClass:property.type.typeClass];
            [sql appendFormat:@" LEFT JOIN %@ ON %@.%@ = %@.id ",foreignTableName,tableName,property.name,foreignTableName];
            if ([property.type.typeClass properties].count > 0) {
                [sql appendString:[self foreignSQLWithMainClass:property.type.typeClass]];
            }
        }
    }
    return sql;
}

/**
 *  获取所有的类
 */
- (NSMutableArray *)allClassWithMainClass:(Class)aClass
{
    NSMutableArray *allCalss = [self foreignClassWithMainClass:aClass];
    [allCalss insertObject:aClass atIndex:0];
    return allCalss;
}

/**
 *  获取所有关联的类
 */
- (NSMutableArray *)foreignClassWithMainClass:(Class)aClass
{
    NSMutableArray *foreigns = [NSMutableArray array];
    for (MJProperty *property in [aClass properties]) {
        if ([property.type.dbType isEqualToString:@"OBJECT"]) {
            [foreigns addObject:property.type.typeClass];
            if ([property.type.typeClass properties].count > 0) {
                [foreigns addObjectsFromArray:[self foreignClassWithMainClass:property.type.typeClass]];
            }
        }
    }
    return foreigns;
}

/**
 *  获取表名
 */
- (NSString *)tableNameWithData:(NSObject *)data
{
    NSString *className = [NSString stringWithUTF8String:object_getClassName(data)];
    return [NSString stringWithFormat:@"T_%@",className];
}
/**
 *  获取表名
 */
- (NSString *)tableNameWithClass:(Class)aClass
{
    return [NSString stringWithFormat:@"T_%@",NSStringFromClass(aClass)];
}

/**
 *  获取路径
 */
- (NSString *)dataFilePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingString:@"/database.db"];
}

@end
