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

typedef enum{
    MASqlTypeInsert = 0,
    MASqlTypeCreate,
    MASqlTypeUpdata,
    MASqlTypeQuery
} MASqlType;

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
    
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM sqlite_master where type='table' and name='%@';",[self tableNameWithClass:aClass]];
    
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

/**
 *  先将data的表为从表的数据插入完成
 */
- (long long)insertWithData:(NSObject *)data
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
            NSNumber *number = @([self insertWithData:[property valueForObject:data]]);
            NSObject *obj = [property valueForObject:data];
            NSLog(@"-------%@---%@",obj,property.name);
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
    
    if ([_dataBase executeUpdate:sql withArgumentsInArray:values]) {
        return [_dataBase lastInsertRowId];
    }else{
        return 0;
    }
}

#pragma mark - 插入数据
- (BOOL)insertDataWithData:(NSObject *)data
{
    if ([self initDataBaseWithClass:object_getClass(data)]) {
        return [self insertWithData:data];
    }else{
        return 0;
    }
}
- (BOOL)deleteAllDataWithClass:(Class)aClass
{
    if ([self initDataBaseWithClass:aClass]) {
        NSString *tableName = [self tableNameWithClass:aClass];
        // 1.创建sql语句
        NSMutableString *sql = [NSMutableString stringWithFormat:@"delete from %@",tableName];
        
        return [_dataBase executeUpdate:sql];
        
    }
    return NO;
}
#pragma mark - 查询数据
#pragma mark 查询所有数据
- (NSArray *)queryAllDataWithClass:(Class)aClass
{
    return [self queryDataWithClass:aClass SearchSqlStr:nil];
}

#pragma mark 根据条件查询数据
- (NSMutableArray *)queryDataWithClass:(Class)aClass SearchSqlStr:(NSString *)str
{
    if ([self initDataBaseWithClass:aClass]) {
        
        NSString *tableName = [self tableNameWithClass:aClass];
        // 1. 创建sql语句
        NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT "];
        NSMutableArray *allCalss = [self foreignClassWithMainClass:aClass];
        [allCalss insertObject:aClass atIndex:0];
        
        for (Class mainClass in allCalss) {
            for (MJProperty *property in [mainClass properties]) {
                NSString *str = [NSString stringWithFormat:@"%@.%@",[self tableNameWithClass:mainClass],property.name];
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
 *  查询
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
 *  外键关联关系
 */
- (NSString *)foreignSQLWithMainClass:(Class)aClass
{
    NSMutableString *sql = [NSMutableString string];
    
    for (MJProperty *property in [aClass properties]) {
        if ([property.type.dbType isEqualToString:@"OBJECT"]) {
            NSString *tableName = [self tableNameWithClass:aClass];
            NSString *foreignTableName = [self tableNameWithClass:property.type.typeClass];
            [sql appendFormat:@" LEFT JOIN %@ ON %@.%@_id = %@.id ",foreignTableName,tableName,foreignTableName,foreignTableName];
            if ([property.type.typeClass properties].count > 0) {
                [sql appendString:[self foreignSQLWithMainClass:property.type.typeClass]];
            }
        }
    }
    return sql;
}

/**
 *  获取所有参与的类
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
    NSString *className = [NSString stringWithUTF8String:class_getName(aClass)];
    return [NSString stringWithFormat:@"T_%@",className];
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
