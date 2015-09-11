 //
//  MADataBase.m
//  Sqlite3
//
//  Created by admin on 15/9/1.
//  Copyright (c) 2015年 kf5. All rights reserved.
//

#import "MADataBaseold.h"

#import "NSObject+MJProperty.h"
#import "MJProperty.h"
#import <objc/runtime.h>
#import <sqlite3.h>
#import "MJPropertyType+Item.h"

typedef enum{
    MASqlTypeInsert = 0,
    MASqlTypeCreate,
    MASqlTypeUpdata,
    MASqlTypeQuery
} MASqlType;

@interface MADataBaseold(){
    sqlite3 *_database;
    sqlite3_stmt *_statement;    //句柄
    char *_errorMsg;
    NSMutableDictionary *_valueDict;
}

@end

@implementation MADataBaseold

static MADataBaseold *_instance;

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
        if ([self checkTableNameWithClass:aClass]) {
            return YES;
        }else{
            return [self createTableWithClass:aClass];
        }
    }else{
        return NO;
    }
}

#pragma mark - 打开数据库
- (BOOL)openDataBase
{
    if (sqlite3_open([[self dataFilePath]UTF8String], &_database) != SQLITE_OK) {
        sqlite3_close(_database);
        NSLog(@"-----打开数据库失败-----");
        return NO;
    }else{
        NSLog(@"打开数据库成功");
        return YES;
    }
}
#pragma mark - 关闭数据库
- (void)closeDataBase
{
    sqlite3_close(_database);
}
#pragma mark - 检验数据表是否存在
-(BOOL)checkTableNameWithClass:(Class)aClass{
    
    char *err;
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM sqlite_master where type='table' and name='%@';",[self tableNameWithClass:aClass]];
    if(sqlite3_exec(_database, [sql UTF8String], NULL, NULL, &err) == 1){
        return YES;
    }else{
        return NO;
    }
    
}

#pragma mark - 创建表
- (BOOL)createTableWithClass:(Class)aClass
{
    // 1. 创建sql语句
    NSString *tableName = [self tableNameWithClass:aClass];

    NSMutableString *sql = [NSMutableString string];
    
    NSArray *properties = [aClass properties];
    [sql appendFormat:@"CREATE TABLE IF NOT EXISTS %@ (id INTEGER PRIMARY KEY AUTOINCREMENT,",tableName];
    
    NSMutableArray *foreignTableNames = [NSMutableArray array];
    for (int i = 0; i< properties.count; i++) {
        MJProperty *property = properties[i];
        if ([property.name isEqualToString:@"id"]) {
            continue;
        }
        if (property.type.dbType != nil) {
            if ([property.type.dbType isEqualToString:@"OBJECT"]) {
                if ([self createTableWithClass:property.type.typeClass]) {
                    NSString *foreignTableName = [self tableNameWithClass:property.type.typeClass];
                    [sql appendFormat:@"%@_id INTEGER,",foreignTableName];
                    [foreignTableNames addObject:foreignTableName];
                }
            }else{
                [sql appendFormat:@"%@ %@,",property.name,property.type.dbType];
            }
        }
    }
    if (foreignTableNames.count == 0) {
        [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];
        [sql appendString:@")"];
    }else{
        NSMutableString *foreignSql = [NSMutableString string];
        for (NSString *foreignTableName in foreignTableNames) {
          [foreignSql appendFormat:@"FOREIGN KEY(%@_id) REFERENCES %@(id),",foreignTableName,foreignTableName];
        }
        
        [sql appendString:foreignSql];
        
        [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];
        
        [sql appendString:@"ON DELETE CASCADE ON UPDATE CASCADE)"];
    }

    NSLog(@"创建语句---%@",sql);

    // 2. 执行sql语句
    if (sqlite3_exec(_database, [sql UTF8String], NULL, NULL, &_errorMsg) != SQLITE_OK) {
        sqlite3_close(_database);
        NSLog(@"-----数据库建表失败-----%@",[NSString stringWithUTF8String:_errorMsg]);
        return NO;
    }else{
        NSLog(@"数据库建表成功");
        return YES;
    }
}

- (long long)insertWithData:(NSObject *)data
{
    // 1. 创建sql语句
    NSString *tableName = [self tableNameWithData:data];
    NSMutableString *sql = [NSMutableString string];
    
    NSArray *properties = [object_getClass(data) properties];
    [sql appendFormat:@"INSERT INTO %@ (",tableName];
    NSMutableString *valusStr = [NSMutableString stringWithString:@"VALUES("];
    
    NSMutableArray *foreignNumberIds = [NSMutableArray array];
    
    for (int i = 0; i< properties.count; i++) {
        MJProperty *property = properties[i];
        if ([property.name isEqualToString:@"id"]) { continue;}
        if (property.type.dbType == nil) {continue;}
        if ([property.type.dbType isEqualToString:@"OBJECT"]) {
            NSObject *foreignObject = [property valueForObject:data];
            long long numberId = [self insertWithData:foreignObject];
            [foreignNumberIds addObject:@(numberId)];
            [sql appendFormat:@"%@_id,",[self tableNameWithData:foreignObject]];
        }else{
            [sql appendFormat:@"%@,",property.name];
        }
        [valusStr appendString:@"?,"];
    }
    
    [sql replaceCharactersInRange:NSMakeRange(sql.length - 1, 1) withString:@")"];
    [valusStr replaceCharactersInRange:NSMakeRange(valusStr.length - 1, 1) withString:@")"];
    
    [sql appendString:valusStr];
    NSLog(@"插入语句---%@",sql);
    
    // 2. 检验sql语句
    if(sqlite3_prepare_v2(_database, [sql UTF8String], -1, &_statement, nil) == SQLITE_OK){
        [self sqlite3_bindWithData:data foreignNumberIds:foreignNumberIds];
    }
    
    // 3. 执行sql语句
    if (sqlite3_step(_statement) != SQLITE_DONE) {
        NSLog(@"插入数据失败");
        return 0;
    }else{
        long numberId = sqlite3_last_insert_rowid(_database);
        NSLog(@"插入数据成功");
        sqlite3_finalize(_statement);
        return numberId;
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

#pragma mark - 查询数据


#pragma mark 查询所有数据
- (NSArray *)queryAllDataWithClass:(Class)aClass
{
    return [self queryDataWithClass:aClass SearchSqlStr:nil];
}

#pragma mark 根据id查询数据
- (NSMutableArray *)queryDataWithClass:(Class)aClass SearchSqlStr:(NSString *)str
{
    if ([self initDataBaseWithClass:aClass]) {
 
        NSString *tableName = [self tableNameWithClass:aClass];
        // 1. 创建sql语句
        NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT * FROM %@",tableName];

        NSMutableArray *foreignClassList = [self foreignClassWithMainClass:aClass];
        for (Class foreignClass in foreignClassList) {
            [sql appendFormat:@",%@",[self tableNameWithClass:foreignClass]];
        }
        if (foreignClassList.count > 0){
            [sql appendString:@" WHERE "];
            
            [sql appendString:[self foreignSQLWithMainClass:aClass]];
            
            [sql deleteCharactersInRange:NSMakeRange(sql.length - 4, 4)];
        }
        if (str.length > 0) {
            [sql appendFormat:@" and %@",str];
        }
        
        
        NSLog(@"查询语句--%@",sql);
        // 2. 执行sql语句
        if(sqlite3_prepare_v2(_database, [sql UTF8String], -1, &_statement, NULL) == SQLITE_OK){
            NSMutableArray *array = [NSMutableArray array];
            [foreignClassList insertObject:aClass atIndex:0];
            
            while (sqlite3_step(_statement) == SQLITE_ROW) {
                int count = sqlite3_column_count(_statement);
                for (int i = 0; i <count ; i++) {
                    NSString *keyName = [NSString stringWithUTF8String:sqlite3_column_name(_statement, i)];
                    NSLog(@"%@",keyName);
                }
                [array addObject:[self sqlite3_columnWithClass:aClass foreigns:foreignClassList]];
            }
            return array;
        }
    }
    return nil;
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
            [sql appendFormat:@" %@.%@_id = %@.id and",tableName,foreignTableName,foreignTableName];
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
 *  查询
 */
- (NSObject *)sqlite3_columnWithClass:(Class)aClass foreigns:(NSArray *)foreigns
{
    NSObject *object = [[aClass alloc]init];
    
    NSMutableArray *properties = [aClass properties];
    int colIndex = 0;
    for (Class foreignClass in foreigns) {
        if (![foreignClass isEqual:aClass]) {
            colIndex += [foreignClass properties].count;
        }else{
            break;
        }
    }
    
    for (int i = 0 ; i < properties.count; i++,colIndex++) {
        NSString *keyName = [NSString stringWithUTF8String:sqlite3_column_name(_statement, colIndex)];
        MJProperty *property = properties[i];
        
        if ([property.name isEqualToString:@"id"]) {
            [properties removeObject:property];
            i--;
            continue;
        }
        
        if ([property.type.dbType isEqualToString:@"OBJECT"]) {
            NSObject *foreign = [self sqlite3_columnWithClass:property.type.typeClass foreigns:foreigns];
            [object setValue:foreign forKey:property.name];
        }else {
            
            if ([keyName isEqualToString:property.name]){
                if ([property.type.dbType isEqualToString:@"TEXT"]) {
                    
                    char *cha = (char *)sqlite3_column_text(_statement, colIndex);
                    NSString *chaStr = [NSString stringWithUTF8String:cha];
                    [object setValue:chaStr forKey:property.name];
                    
                }else if([property.type.code isEqualToString:@"NSDate"]){
                    
                    double number = sqlite3_column_double(_statement, colIndex);
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:number];
                    [object setValue:date forKey:property.name];
                    
                }else if ([property.type.dbType isEqualToString:@"INTEGER"]){
                    
                    int number = sqlite3_column_int(_statement, colIndex);
                    [object setValue:@(number) forKey:property.name];
                    
                }else if ([property.type.dbType isEqualToString:@"REAL"]){
                    
                    double intt = sqlite3_column_double(_statement, colIndex);
                    [object setValue:@(intt) forKey:property.name];
            
                }else if ([property.type.dbType isEqualToString:@"BLOB"]){
                    
                    const void *op = sqlite3_column_blob(_statement, colIndex);
                    int size = sqlite3_column_bytes(_statement,colIndex);
                    NSData *data = [[NSData alloc]initWithBytes:op length:size];
                    [object setValue:data forKey:property.name];
                    
                }else{
                    [properties removeObject:property];
                    i--;
                    continue;
                }
            }else{
                i--;
            }
        }
        
    }
    return object;
}
/**
 *  插入
 */
- (void)sqlite3_bindWithData:(NSObject *)data foreignNumberIds:(NSMutableArray *)foreignNumberIds
{
    NSMutableArray *properties = [NSMutableArray arrayWithArray:[object_getClass(data) properties]];
    for (int i = 1; i < properties.count + 1; i++) {
        MJProperty *property = properties[i - 1];
        if ([property.name isEqualToString:@"id"]) {
            [properties removeObject:property];
            i--;
            continue;
        }
        if([property.type.code isEqualToString:@"NSDate"]){
            NSDate *date = [property valueForObject:data];
             sqlite3_bind_double(_statement, i,[date timeIntervalSince1970]);
        }else if ([property.type.dbType isEqualToString:@"TEXT"]) {
            sqlite3_bind_text(_statement, i, [[property valueForObject:data] UTF8String], -1, NULL);
        }else if ([property.type.dbType isEqualToString:@"INTEGER"]){
            NSNumber *number = [property valueForObject:data];
            sqlite3_bind_int(_statement, i, number.intValue);
        }else if ([property.type.dbType isEqualToString:@"REAL"]){
            NSNumber *number = [property valueForObject:data];
            sqlite3_bind_double(_statement, i, number.floatValue);
        }else if ([property.type.dbType isEqualToString:@"BLOB"]){
            NSData *number = [property valueForObject:data];
            sqlite3_bind_blob(_statement, i, [number bytes], (int)[number length], NULL);
        }else if([property.type.dbType isEqualToString:@"OBJECT"]){
            NSNumber *numberId = foreignNumberIds[0];
            sqlite3_bind_int64(_statement, i, numberId.longLongValue);
            [foreignNumberIds removeObjectAtIndex:0];
        }else{
            [properties removeObject:property];
            i--;
            continue;
        }
    }
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
