//
//  NSObject+TFKVO.m
//  TFKvoDemo
//
//  Created by RaInVis on 2017/7/3.
//  Copyright © 2017年 RaInVis. All rights reserved.
//

#import "NSObject+TFKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString *const TFKVOClassPrefix = @"TF_KVOClassPrefix"; // 派生类的自定义前缀
NSString *const TFKVOAssociatedObserverKey = @"TFKVOAssociatedObserverKey"; // runtime绑定属性的key

@interface TFObservationInfo : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) TFObserveBlock block;

@end

@implementation TFObservationInfo

- (instancetype)initWithObserver:(NSObject *)observer Key:(NSString *)key block:(TFObserveBlock)block
{
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}

@end

@implementation NSObject (TFKVO)

#pragma mark - 添加观察者

- (void)tf_addObserver:(id)observer
                forKey:(NSString *)key
             withBlock:(TFObserveBlock)block
{
    
    NSString *noPropertyErrorMsg = [NSString stringWithFormat:@"需要监听的对象没有%@这个属性", key];
    NSAssert([self isExistInProperties:observer propertyName:key], noPropertyErrorMsg);
    
    SEL setterSelector = NSSelectorFromString([self methodSetterWithPropertyKey:key]);
    // 获取setKey 实例方法
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    NSString *noSetterErrorMsg = [NSString stringWithFormat:@"需要监听的对象没有实现%@这个属性的setter方法", key];
    NSAssert(setterMethod, noSetterErrorMsg);
    
    // 获取类&类名
    Class class = object_getClass(self);
    NSString *className = NSStringFromClass(class);
    
    // 判断是否已经生成KVO的派生类(前缀判断)
    if (![className hasPrefix:TFKVOClassPrefix]) {
        // 生成派生类
        class = [self creatNewClassWithInitialClass:className];
        // 设置对象的类为生成的派生类
        object_setClass(self, class);
    }
    // 判断是否已经实现重写了set方法
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        // 重写set方法添加监听
        class_addMethod(class, setterSelector, (IMP)kvo_setter, types);
    }
    // 动态给注册者绑定数组,数组里面包含KVO信息(观察的observer,key,block)
    TFObservationInfo *info = [[TFObservationInfo alloc] initWithObserver:observer Key:key block:block];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(TFKVOAssociatedObserverKey));
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge const void *)(TFKVOAssociatedObserverKey), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
    
}

- (void)tf_addObserver:(NSObject *)observer
                forKey:(NSString *)key
              forValue:(id)value
             withBlock:(TFObserveBlock)block
{
    [self tf_addObserver:observer forKey:key withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        
        if ([observer isKindOfClass:[UIColor class]]) {
            UIColor *color = value;
            UIColor *newColor = newValue;
            if (!CGColorEqualToColor(color.CGColor, newColor.CGColor) || !block) {
                return;
            }
        }else if ([observer isKindOfClass:[NSString class]]) {
            NSString *string = value;
            NSString *newString = newValue;
            if (![string isEqualToString:newString] || !block) {
                return;
            }
        }else{
            if (![value isEqual:newValue]) {
                return;
            }
        }
        block(observedObject, observedKey, oldValue, newValue);

    }];
}

// 移除观察者
- (void)tf_removeObserver:(NSObject *)observer forKey:(NSString *)key
{
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(TFKVOAssociatedObserverKey));
    TFObservationInfo *removeInfo;
    for (TFObservationInfo* info in observers) {
        if (info.observer == observer && [info.key isEqual:key]) {
            removeInfo = info;
            break;
        }
    }
    [observers removeObject:removeInfo];
}


// 判断监听的对象是否含有设置的属性
- (BOOL)isExistInProperties:(id)obsever propertyName:(NSString *)name
{
    // 获取当前类的所有属性
    unsigned int count;// 记录属性个数
    Class cls = [obsever class];
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    // 遍历
    for (int i = 0; i < count; i++) {
        // objc_property_t 属性类型
        objc_property_t property = properties[i];
        // 获取属性的名称 C语言字符串
        const char *cName = property_getName(property);
        // 转换为Objective C 字符串
        NSString *name = [NSString stringWithCString:cName encoding:NSUTF8StringEncoding];
        if ([name isEqualToString:name]) {
            return  YES;
        }
    }
    return NO;
}

// 创建派生类
- (Class)creatNewClassWithInitialClass:(NSString *)initialClassName
{
    NSString *KvoClassName = [TFKVOClassPrefix stringByAppendingString:initialClassName];
    Class cls = NSClassFromString(KvoClassName);
    if (cls) { // 如果已经存在新创建的派生类,直接返回
        return cls;
    }
    Class initialClass = object_getClass(self);
    // 动态创建类
    Class kvoClass = objc_allocateClassPair(initialClass, KvoClassName.UTF8String, 0);
    // 得到类的实例方法
    Method classMethod = class_getInstanceMethod(kvoClass, @selector(class));
    // 获取方法的Type字符串(包含参数类型和返回值类型)
    const char *types = method_getTypeEncoding(classMethod);
    // 重写class方法
    class_addMethod(kvoClass, @selector(class), (IMP)kvo_class, types);
    // 注册创建的类
    objc_registerClassPair(kvoClass);
    
    return kvoClass;
}
#pragma mark - tool methods

// 将传入的key转换为setKey
- (NSString *)methodSetterWithPropertyKey:(NSString *)key
{
    if (key.length <= 0) {
        return nil;
    }
    NSString *initial = [[key substringToIndex:1] uppercaseString];
    NSString *other = [key substringFromIndex:1];
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", initial, other];
    return setter;
}
// 通过set方法名获取get方法名
- (NSString *)methodGetterWithSetter:(NSString *)setter
{
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstLetter];
    return key;
}

// 判断实例变量是否含有传入的方法
- (BOOL)hasSelector:(SEL)selector
{
    Class class = object_getClass(self);
    unsigned int methodCount = 0;
    // copy出一份方法列表
    Method* methodList = class_copyMethodList(class, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL methodSelector = method_getName(methodList[i]);
        if (methodSelector == selector) {
            // copy出来的需要释放
            free(methodList);
            return YES;
        }
    }
    free(methodList);
    return NO;
}

#pragma mark - 重写方法

// 重写class方法将class返回的类指向原类的父类(苹果爸爸故意这样为了迷惑大众🐱生成派生类的秘密)
static Class kvo_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

// 重写set方法,实现监听
static void kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = [self methodGetterWithSetter:setterName];
    
    // 获取get 实例方法
    SEL getterSelector = NSSelectorFromString(getterName);
    Method getterMethod = class_getInstanceMethod([self class], getterSelector);
    NSString *noGetterErrorMsg = [NSString stringWithFormat:@"需要监听的对象没有实现getter方法"];
    NSAssert(getterMethod, noGetterErrorMsg);
    // 获取旧值
    id oldValue = [self valueForKey:getterName];
    // 构建 objc_super 的结构体
    struct objc_super superclass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    // 向父类发送set消息,这里需要注意的是 objc_msgSendSuper(&superclass, _cmd, newValue) 这样调用编辑器会报错
    // (1)第一种解决方案:
    // 在项目配置文件 -> Build Settings -> Enable Strict Checking of objc_msgSend Calls 这个字段设置为 NO(默认YES)
    // (2)第二种解决方案:采用如下写法
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    objc_msgSendSuperCasted(&superclass, _cmd, newValue);
    // 调用完后,获取绑定的info,调用block回调
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(TFKVOAssociatedObserverKey));
    for (TFObservationInfo *info in observers) {
        if ([info.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                info.block(self, getterName, oldValue, newValue);
            });
        }
    }
}


@end
