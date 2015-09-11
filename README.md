# MADataBase
---------------
##可以使对象直接转化为sqlite3的数据库表  
####创建类的时候不能出现类似两个类相互包含的情况.

####插入对象方法
    [[MADataBase shareDataBase]insertDataWithData:student];
####删除对象方法
    [[MADataBase shareDataBase]deleteAllDataWithClass:[Student class]];
####查询对象方法
    NSArray *array = [[MADataBase shareDataBase]queryDataWithClass:[Student class] 
             SearchSqlStr:@"mString = \"mString_0\""];//searchSqlStr是附加查询条件,置空查询全部数据
####关闭方法
    [[MADataBase shareDataBase]closeDataBase]; // 不需要打开方法, 在使用插入等方法时，将自动打开数据库
    
#代码尚未完成，有很多不足，仅供参考！
