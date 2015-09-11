//
//  ViewController.m
//  MADataBase
//
//  Created by admin on 15/9/11.
//  Copyright (c) 2015年 kf5. All rights reserved.
//

#import "ViewController.h"
#import <MJExtension.h>

#import "NSObject+MJKeyValue.h"
#import "MADataBase.h"

#import "Car.h"
#import "Book.h"
#import "Student.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self insertData];
    
    [[MADataBase shareDataBase]closeDataBase];
    
}
/**
 *  查询数据
 */
- (void)queryData
{
    [[MADataBase shareDataBase]deleteAllDataWithClass:[Teacher class]];
    NSArray *array = [[MADataBase shareDataBase]queryDataWithClass:[Student class] SearchSqlStr:@"mString = \"mString_0\""];
    NSLog(@"%@",array);
}
/**
 *  删除数据
 */
- (void)deleteAllData
{
    [[MADataBase shareDataBase]deleteAllDataWithClass:[Student class]];
}

/**
 *  查询数据
 */
- (void)insertData
{
    //    for (int i = 0; i < 10; i++) {
    //        Student *student = [[Student alloc]init];
    //        student.mBOOL = YES;
    //        student.mDouble = 1.23;
    //        student.mFloat = 1.234;
    //        student.mString = @"string";
    //        student.mInteger = 123;
    //        student.mUInteger = 321;
    ////        student.mArray = @[@"234",@"43543"];
    ////        student.mDictionary = @{@"key":@"value"};
    //        UIImage *image = [UIImage imageNamed:@"123"];
    //        student.mData = UIImagePNGRepresentation(image);
    //        student.mDate = [NSDate date];
    //
    //        Teacher *teacher = [[Teacher alloc]init];
    //        teacher.age = 28;
    //        teacher.name = @"张亮";
    //        teacher.sex = 1;
    //
    //        student.teacher = teacher;
    //
    //        [[MADataBase shareDataBase]insertDataWithData:student];
    //    }
    //    int i = 1;
    for (int i = 0; i < 100; i++) {
        Book *book = [[Book alloc]init];
        book.bookName = [NSString stringWithFormat:@"童话_%d",i];
        
        Car *car = [[Car alloc]init];
        car.color = [NSString stringWithFormat:@"红_%d",i];
        
        Teacher *teacher = [[Teacher alloc]init];
        teacher.name = [NSString stringWithFormat:@"张老师_%d",i];
        teacher.car = car;
        
        Student *student = [[Student alloc]init];
        //        student.mString = [NSString stringWithFormat:@"mString_%d",i];
        //        student.name = [NSString stringWithFormat:@"name_%d",i];
        student.book = book;
        Book *book2 = [[Book alloc]init];
        book2.bookName = [NSString stringWithFormat:@"新书_%d",i];
        student.book2 = book2;
        //        student.teacher = teacher;
        [[MADataBase shareDataBase]insertDataWithData:student];
    }
    
    
}

@end
