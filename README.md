# iOS - 手把手带你一步一步实现KVO
![MacDown Screenshot](http://upload-images.jianshu.io/upload_images/1395887-268181e7dcae49b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
## 前言

**KVO** 

即：Key-Value Observing，它提供一种机制，当指定的对象的属性被修改后，则对象就会接受到通知。简单的说就是每次指定的被观察的对象的属性被修改后，KVO就会自动通知相应的观察者。

**用法&原理**
![MacDown Screenshot](http://upload-images.jianshu.io/upload_images/1678515-25dd827bb799279e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
 
 KVO实现原理很多博客都有很详细的介绍,这里我就不再重复的阐述了,推荐几篇博文供大家学习.

来自`sunnyxx`大神的博客: [objc kvo简单探索](http://blog.sunnyxx.com/2014/03/09/objc_kvo_secret/ "Title") 

来自`objc中国`的文章: [KVC 和 KVO](https://objccn.io/issue-7-3/ "Title")

## 正序

**实现KVO的思路**

在了解完KVO的原理过后,通过分析得出,大体上的实现思路是这样的:

* 当注册一个观察者时,首先要动态创建被监听对象的类的一个派生类(子类)
* 将原类的实例变量的isa指针指向新创建的派生类
* 为了"混淆视听",伪装生成了派生类,重写class方法,使其返回派生类的父类(也就是被监听对象的类)
* 重写派生类的setter方法,在里面通知被监听的值的改变

**具体核心代码实现(部分)**

添加观察者

```
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

```

动态创建派生类具体实现方法

```
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
    

```

重写setter方法

```
    // 构建 objc_super 的结构体
    struct objc_super superclass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    // 向父类发送set消息
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

```

移除观察者

```
  NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(TFKVOAssociatedObserverKey));
    TFObservationInfo *removeInfo;
    for (TFObservationInfo* info in observers) {
        if (info.observer == observer && [info.key isEqual:key]) {
            removeInfo = info;
            break;
        }
    }
    [observers removeObject:removeInfo];

```

**我的简书地址,欢迎关注**

[简书地址](http://www.jianshu.com/p/13a81c9c33a5 "Title")


## 尾言

就笔者而言,在实际开发中,很少使用KVO提供的API,虽然他很强大,但是还有一些不足.比如,你只能通过重写 `-observeValueForKeyPath:ofObject:change:context: `方法来获得通知,想要自定义方法或者使用block实现,都是不允许的.而且你还要处理父类的情况,例如父类同样监听同一个对象的同一个属性。虽然`context` 这个参数就是干这个的，也可以解决这个问题 -	 在 `-addObserver:forKeyPath:options:context:`传进去一个父类不知道的`context`,但是也是很麻烦的一件事,不是吗?

有不少人都觉得官方 KVO 不好使的。Mike Ash 的 
[Key-Value Observing Done Right](https://www.mikeash.com/pyblog/key-value-observing-done-right.html "Title"),以及获得不少分享讨论的[KVO Considered Harmful](http://khanlou.com/2013/12/kvo-considered-harmful/ "Title")都把KVO"批判"了一把。所以在实际开发中 KVO 使用的情景并不多，更多时候还是用 Delegate 或 NotificationCenter吧。

完结.

#### 如文中有不对的地方,还请及时回复修正,谢谢观赏!


