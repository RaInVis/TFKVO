//
//  ViewController.m
//  TFKvoDemo
//
//  Created by RaInVis on 2017/7/4.
//  Copyright © 2017年 RaInVis. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+TFKVO.h"

@interface ViewController ()

@property (nonatomic, copy) NSString *aaa; //!< <#注释#>
@property (nonatomic, copy) NSString *bbb; //!< <#注释#>


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self tf_addObserver:self forKey:@"bbb" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"newValue:%@", newValue);
    }];
    
    // 监听属性为指定值的时候才回调
    [self tf_addObserver:self forKey:@"aaa" forValue:@"aaa:1" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"newValue:%@", newValue);
        
    }];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    int x = arc4random() % 3;
    int y = arc4random() % 1000;
    NSString *aaa = [NSString stringWithFormat:@"aaa:%zi", x];
    NSString *bbb = [NSString stringWithFormat:@"bbb:%zi", y];
    self.aaa = aaa;
    self.bbb = bbb;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [self tf_removeObserver:self forKey:@"aaa"];
    [self tf_removeObserver:self forKey:@"bbb"];
    
}


@end
