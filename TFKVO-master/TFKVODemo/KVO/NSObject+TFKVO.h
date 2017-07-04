//
//  NSObject+TFKVO.h
//  TFKvoDemo
//
//  Created by RaInVis on 2017/7/3.
//  Copyright © 2017年 RaInVis. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^TFObserveBlock)(id observedObject, NSString *observedKey, id oldValue, id newValue);

@interface NSObject (TFKVO)

/**
 添加观察者
 
 @param observer 需要观察的对象
 @param key 需要观察的属性
 @param block 状态改变后的block
 */
- (void)tf_addObserver:(NSObject *)observer
                forKey:(NSString *)key
             withBlock:(TFObserveBlock)block;

/**
 添加观察者
 
 @param observer 需要观察的对象
 @param key 需要观察的属性
 @param value 观察的属性为指定的value才回调
 @param block 状态改变后的block
 */
- (void)tf_addObserver:(NSObject *)observer
                forKey:(NSString *)key
              forValue:(id)value
             withBlock:(TFObserveBlock)block;


/**
 移除观察者
 
 @param observer 需要移除的对象
 @param key 需要移除观察的属性
 */
- (void)tf_removeObserver:(NSObject *)observer forKey:(NSString *)key;


@end
