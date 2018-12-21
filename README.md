# RuntimeDemo

### 简单的 Runtime 教程(适合新手入门)

### [详细查看博客](https://blog.csdn.net/u010960265/article/details/85159847)

> 本篇主要是从新手的角度出发，介绍 Runtime 的原理、常用方法、应用场景等。

### 一、Runtime 是什么

&#160;&#160;&#160;&#160;&#160;&#160;&#160;在 C 语言中，将代码转换为可执行程序，一般要经历三个步骤，即编译、链接、运行。在链接的时候，对象的类型、方法的实现就已经确定好了。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;而在 Objective-C 中，却将一些在编译和链接过程中的工作，放到了运行阶段。也就是说，就算是一个编译好的 .ipa 包，在程序没运行的时候，也不知道调用一个方法会发生什么。这也为后来大行其道的「热修复」提供了可能。因此我们称 Objective-C 为一门动态语言。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;这样的设计使 Objective-C 变得灵活，甚至可以让我们在程序运行的时候，去动态修改一个方法的实现。而实现这一切的基础就是 Runtime 。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;`简单来说， Runtime 是一个库，这个库使我们可以在程序运行时创建对象、检查对象，修改类和对象的方法。`

至于这个库是怎么实现的，请紧张刺激地往下看。

### 二、Runtime 是怎么工作的

&#160;&#160;&#160;&#160;&#160;&#160;&#160;要了解 Runtime 是怎么工作的，首先要知道类和对象在 Objective-C 中是怎么定义的。

> 注意：以下会用到 C 语言中结构体的内容，包括结构体的定义、为结构体定义别名等。如果你对这块不熟悉，建议先复习一下这块的语法。

#### 1.Class 和 Object

&#160;&#160;&#160;&#160;&#160;&#160;&#160;在 objc.h 中， Class 被定义为指向 objc_class 的指针，定义如下：

    typedef struct objc_class *Class;

&#160;&#160;&#160;&#160;&#160;&#160;&#160;而 objc_class 是一个结构体，在 runtime.h 中的定义如下：

    struct objc_class {
        Class isa;                                // 实现方法调用的关键
        Class super_class;                        // 父类
        const char * name;                        // 类名
        long version;                             // 类的版本信息，默认为0
        long info;                                // 类信息，供运行期使用的一些位标识
        long instance_size;                       // 该类的实例变量大小
        struct objc_ivar_list * ivars;            // 该类的成员变量链表
        struct objc_method_list ** methodLists;   // 方法定义的链表
        struct objc_cache * cache;                // 方法缓存
        struct objc_protocol_list * protocols;    // 协议链表
    };

> 为了方便理解，我这里去掉了一些声明，主要是和 Objective-C 语言版本相关， 这里可以暂时忽略。完整的定义可以自己去
> runtime.h 中查看。

> 提示：在 Xcode 中，使用快捷键 command + shift + o ，可以打开搜索窗口，输入 objc_class 即可看到头文件定义。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;可以看到，一个类保存了自身所有的成员变量（ ivars ）、所有的方法（ methodLists ）、所有实现的协议（ objc_protocol_list ）。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;比较重要的字段还有 isa 和 cache ，它们是什么东西，先不着急，我们来看下 Objective-C 中对象的定义。

    struct objc_object {
        Class isa;
    };
    
    typedef struct objc_object *id;

&#160;&#160;&#160;&#160;&#160;&#160;&#160;这里看到了我们熟悉的 id ，一般我们用它来实现类似于 C++ 中泛型的一些操作，该类型的对象可以转换为任意一种对象。在这里 id 被定义为一个指向 objc_object 的指针。说明 objc_object 就是我们平时常用的对象的定义，它只包含一个 isa 指针。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;也就是说，一个对象唯一保存的信息就是它的 Class 的地址。当我们调用一个对象的方法时，它会通过 isa 去找到对应的 objc_class，然后再在 objc_class 的 methodLists 中找到我们调用的方法，然后执行。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;再说说 cache ，因为调用方法的过程是个查找 methodLists 的过程，如果每次调用都去查找，效率会非常低。所以对于调用过的方法，会以 map 的方式保存在 cache 中，下次再调用就会快很多。

#### 2. Meta Class 元类

&#160;&#160;&#160;&#160;&#160;&#160;&#160;上一小节讲了 Objective-C 中类和对象的定义，也讲了调用对象方法的实现过程。但还留下了许多问题，比如调用一个对象的类方法的过程是怎么样的？还有 objc_class 中也有一个 isa 指针，它是干嘛用的？

&#160;&#160;&#160;&#160;&#160;&#160;&#160;现在划重点，在 Objective-C 中，`类也被设计为一个对象。`

&#160;&#160;&#160;&#160;&#160;&#160;&#160;其实观察 objc_class 和 objc_object 的定义，会发现两者其实本质相同（都包含 isa 指针），只是 objc_class 多了一些额外的字段。相应的，类也是一个对象，只是保存了一些字段。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;既然说类也是对象，那么类的类型是什么呢？这里就引出了另外一个概念 —— Meta Class（元类）。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;在 Objective-C 中，`每一个类都有对应的元类。`而在元类的 methodLists 中，保存了类的方法链表，即所谓的「类方法」。并且类的 isa 指针指向对应的元类。因此上面的问题答案就呼之欲出，调用一个对象的类方法的过程如下：

 - 通过对象的 isa 指针找到对应的类
 - 通过类的 isa 指针找到对应元类
 - 在元类的 methodLists 中，找到对应的方法，然后执行

&#160;&#160;&#160;&#160;&#160;&#160;&#160;注意：上面类方法的调用过程不考虑继承的情况，这里只是说明一下类方法的调用原理，完整的调用流程在后面会提到。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;这么说来元类也有一个 isa 指针，元类也应该是一个对象。的确是这样。那么元类的 isa 指向哪里呢？为了不让这种结构无限延伸下去， Objective-C 的设计者让所有的元类的 isa 指向基类（比如 NSObject ）的元类。而基类的元类的 isa 指向自己。这样就形成了一个完美的闭环。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;下面这张图可以清晰地表示出这种关系。
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181221141132410.jpg?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3UwMTA5NjAyNjU=,size_16,color_FFFFFF,t_70)


&#160;&#160;&#160;&#160;&#160;&#160;&#160;同时注意 super_class 的指向，基类的 super_class 指向 nil 。

#### 3. Method

&#160;&#160;&#160;&#160;&#160;&#160;&#160;上面讲到，「找到对应的方法，然后执行」，那么这个「执行」是怎样进行的呢？下面就来介绍一下 Objective-C 中的方法调用。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;先来看一下 Method 在头文件中的定义：

    typedef struct objc_method *Method;
    
    struct objc_method {
        SEL method_name;
        char * method_types;
        IMP method_imp;
    };

&#160;&#160;&#160;&#160;&#160;&#160;&#160;Method 被定义为一个 objc_method 指针，在 objc_method 结构体中，包含一个 SEL 和一个 IMP ，同样来看一下它们的定义：

    // SEL
    typedef struct objc_selector *SEL;
    
    // IMP
    typedef id (*IMP)(id, SEL, ...);

##### 3.1、先说一下 SEL 。 SEL 是一个指向 objc_selector 的指针，而 objc_selector 在头文件中找不到明确的定义。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;我们来测试以下代码：

    SEL sel = @selector(viewDidLoad);
    NSLog(@"%s", sel);          // 输出：viewDidLoad
    SEL sel1 = @selector(viewDidLoad1);
    NSLog(@"%s", sel1);         // 输出：viewDidLoad1

&#160;&#160;&#160;&#160;&#160;&#160;&#160;可以看到， SEL 不过是保存了方法名的一串字符。因此我们可以认为， SEL 就是一个保存方法名的字符串。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;由于一个 Method 只保存了方法的方法名，并最终要根据方法名来查找方法的实现，因此在 Objective-C 中不支持下面这种定义。

    - (void)setWidth:(int)width;
    - (void)setWidth:(double)width;

##### 3.2、再来说 IMP 。可以看到它是一个「函数指针」。简单来说，「函数指针」就是用来找到函数地址，然后执行函数。（「函数指针」了解一下）

&#160;&#160;&#160;&#160;&#160;&#160;&#160;这里要注意， IMP 指向的函数的前两个参数是默认参数， id 和 SEL 。这里的 SEL 好理解，就是函数名。而 id ，对于实例方法来说， self 保存了当前对象的地址；对于类方法来说， self 保存了当前对应类对象的地址。后面的省略号即是参数列表。

##### 3.3、到这里， Method 的结构就很明了了。 Method 建立了 SEL 和 IMP 的关联，当对一个对象发送消息时，会通过给出的 SEL 去找到 IMP ，然后执行。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;在 Objective-C 中，所有的方法调用，都会转化成向对象发送消息。发送消息主要是使用 objc_msgSend 函数。看一下头文件定义：

    id objc_msgSend(id self, SEL op, ...);

&#160;&#160;&#160;&#160;&#160;&#160;&#160;可以看到参数列表和 IMP 指向的函数参数列表是相对应的。 Runtime 会将方法调用做下面的转换，所以一般也称 Objective-C 中的调用方法为「发送消息」。

    [self doSomething];
    objc_msgSend(self, @selector(doSomething));

##### 3.4、上面看到 objc_msgSend 会默认传入 id 和 SEL 。这对应了两个隐含参数， self 和 _cmd 。这意味着我们可以在方法的实现过程中拿到它们，并使用它们。下面来看个例子：

    - (void)testCmd:(NSNumber *)num {
    
        NSLog(@"%ld", (long)num.integerValue);
    
        num = [NSNumber numberWithInteger:num.integerValue-1];
    
        if (num.integerValue > 0) {
            [self performSelector:_cmd withObject:num];
        }
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;尝试调用：

    [self testCmd:@(5)];

&#160;&#160;&#160;&#160;&#160;&#160;&#160;上面会按顺序输出 5, 4, 3, 2, 1 ，然后结束。即我们可以在方法内部用 _cmd 来调用方法自身。

##### 3.5、上面已经介绍了方法调用的大致过程，下面来讨论类之间继承的情况。重新回去看 objc_class 结构体的定义，当中包含一个指向父类的指针 super_class。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;即当向一个对象发送消息时，会去这个类的 methodLists 中查找相应的 SEL ，如果查不到，则通过 super_class 指针找到父类，再去父类的 methodLists 中查找，层层递进。最后仍然找不到，才走抛异常流程。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;下面的图演示了一个基本的消息发送框架：
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181221141234641.jpg?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3UwMTA5NjAyNjU=,size_16,color_FFFFFF,t_70)


##### 3.6、当一个方法找不到的时候，会走拦截调用和消息转发流程。我们可以重写 +resolveClassMethod: 和 +resolveInstanceMethod: 方法，在程序崩溃前做一些处理。通常的做法是动态添加一个方法，并返回 YES 告诉程序已经成功处理消息。如果这两个方法返回 NO ，这个流程会继续往下走，完整的流程如下图所示：
![在这里插入图片描述](https://img-blog.csdnimg.cn/20181221141300925.jpg?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3UwMTA5NjAyNjU=,size_16,color_FFFFFF,t_70)


#### 4. Category

&#160;&#160;&#160;&#160;&#160;&#160;&#160;我们来看一下 Category 在头文件中的定义：

    typedef struct objc_category *Category;
    
    struct objc_category {
        char * category_name;
        char * class_name;
        struct objc_method_list * instance_methods;
        struct objc_method_list * class_methods;
        struct objc_protocol_list * protocols;
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;Category 是一个指向 objc_category 结构体的指针，在 objc_category 中包含对象方法列表、类方法列表、协议列表。从这里我们也可以看出， Category 支持添加对象方法、类方法、协议，但不能保存成员变量。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;注意：在 Category 中是可以添加属性的，但不会生成对应的成员变量、 getter 和 setter 。因此，调用 Category 中声明的属性时会报错。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;`我们可以通过「关联对象」的方式来添加可用的属性。`具体操作如下：

##### 4.1、在 UIViewController+Tag.h 文件中声明 property 。

    @property (nonatomic, strong) NSString *tag;

##### 4.2、在 UIViewController+Tag.m 中实现 getter 和 setter 。记得添加头文件 #import。主要是用到 objc_setAssociatedObject 和 objc_getAssociatedObject 这两个方法。

    static void *tag = &tag;
    
    @implementation UIViewController (Tag)
    
    - (void)setTag:(NSString *)t {
    
        objc_setAssociatedObject(self, &tag, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    - (NSString *)tag {
    
        return objc_getAssociatedObject(self, &tag);
    }
    
    @end

##### 4.3、在子类中调用。

    // 子类 ViewController.m
    - (void)testCategroy {
    
        self.tag = @"TAG";
        NSLog(@"%@", self.tag);   // 这里输出：TAG
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;注意：当一个对象被释放后， Runtime 回去查找这个对象是否有关联的对象，有的话，会将它们释放掉。因此不需要我们手动去释放。

### 三、Runtime 的常规操作

&#160;&#160;&#160;&#160;&#160;&#160;&#160;上面简单介绍了 Runtime 的原理，接下来介绍下 Runtime 常用的操作。

#### 1. Method Swizzling 方法交换

&#160;&#160;&#160;&#160;&#160;&#160;&#160;首先来介绍一下被称为「黑魔法」的 Method Swizzling 。 Method Swizzling 使我们有办法在程序运行的时候，去修改一个方法的实现。包括原生类（比如 UIKit 中的类）的方法。首先来看下通常的写法：

    Method originalMethod = class_getInstanceMethod(class, (originalSelector));
    Method swizzledMethod = class_getInstanceMethod(class, (swizzledSelector));
    
    if (!class_addMethod((class),                                               
                         (originalSelector),                                 
                         method_getImplementation(swizzledMethod),  
                         method_getTypeEncoding(swizzledMethod))) {             
        method_exchangeImplementations(originalMethod, swizzledMethod);         
    } else {                                                                    
        class_replaceMethod((class),                                            
                            (swizzledSelector),                                 
                            method_getImplementation(originalMethod),           
                            method_getTypeEncoding(originalMethod));            
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;简单描述一下：先获取 originalMethod 和 swizzledMethod 。将 originalMethod 加到想要交换方法的类中（注意此时的 IMP 是 swizzledMethod 的 IMP ），如果加入成功，就用 originalMethod 的 IMP 替换掉 swizzledMethod 的 IMP ；如果加入失败，则直接交换 originalMethod 和 swizzledMethod 的 IMP 。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;那么问题来了，为什么不直接用 method_exchangeImplementations 来交换就好？

&#160;&#160;&#160;&#160;&#160;&#160;&#160;因为可能会影响父类中的方法。比如我们在一个子类中，去交换一个父类中的方法，而这个方法在子类中没有实现，这个时候父类的方法就指向了子类的实现，当这个方法被调用的时候就会出问题。所以先采取添加方法的方式，如果添加失败，证明子类已经实现了这个方法，直接用 method_exchangeImplementations 来交换；如果添加成功，则说明没有实现这个方法，采取先添加后替换的方式。这样就能保证不影响父类了。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;如果每次交换都写这么多就太麻烦了，我们可以定义成一个宏，使用起来更方便。

    #define SwizzleMethod(class, originalSelector, swizzledSelector) {              \    Method originalMethod = class_getInstanceMethod(class, (originalSelector)); \
        Method swizzledMethod = class_getInstanceMethod(class, (swizzledSelector)); \
        if (!class_addMethod((class),                                               \
                             (originalSelector),                                    \
                             method_getImplementation(swizzledMethod),              \
                             method_getTypeEncoding(swizzledMethod))) {             \
            method_exchangeImplementations(originalMethod, swizzledMethod);         \
        } else {                                                                    \
            class_replaceMethod((class),                                            \
                                (swizzledSelector),                                 \
                                method_getImplementation(originalMethod),           \
                                method_getTypeEncoding(originalMethod));            \
        }                                                                           \
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;在 +load 中调用：

    + (void)load {
    
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
    
            SwizzleMethod([self class], @selector(viewWillAppear:), @selector(AA_viewWillAppear:));        
        });
    }

> 注意：我们要保证方法只会被交换一次。因为 +load 方法原则上只会被调用一次，所以一般将 Method Swizzling 放在 +load 方法中执行。但 +load 方法也可能被其他类手动调用，这时候就有可能会被交换多次，所以这里用 dispatch_once_t 来保证只执行一次。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;那么上面的交换操作是否万无一失了呢？还远远不够。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;通常情况下上面的交换不会出什么问题，但考虑下面一种场景。（注： ViewController 继承自 UIViewController ）

&#160;&#160;&#160;&#160;&#160;&#160;&#160;修改 UIViewController 中的 viewWillAppear: ：

    // UIViewController (Swizzling)
    + (void)load {
    
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
    
            SwizzleMethod([self class], @selector(viewWillAppear:), @selector(AA_viewWillAppear:));        
        });
    }
    
    - (void)AA_viewWillAppear:(BOOL)animated {
    
        NSLog(@"UIViewController");
    
        [self AA_viewWillAppear:animated];
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;修改 ViewController 中的 viewWillAppear: （注： ViewController 没有重写该方法）：

    // ViewController (Swizzling)
    + (void)load {
    
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
    
            SwizzleMethod([self class], @selector(viewWillAppear:), @selector(BB_viewWillAppear:));        
        });
    
    
    }
    
    - (void)BB_viewWillAppear:(BOOL)animated {
    
        NSLog(@"ViewController");
    
        [self BB_viewWillAppear:animated];
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;这里父类和子类同时对 viewWillAppear: 方法进行交换，每次交换都加入一句输出语句。则当 ViewController 调用 viewWillAppear: 时，我们期望输出下面结果：

    ViewController
    UIViewController

&#160;&#160;&#160;&#160;&#160;&#160;&#160;大部分情况的确是这样，但也有可能只输出：

    ViewController

&#160;&#160;&#160;&#160;&#160;&#160;&#160;因为我们是在 +load 中做交换操作，而子类的 +load 却有可能先于父类执行。这样造成的结果是，子类先拷贝父类的 viewWillAppear: ，并进行交换，然后父类再进行交换。但这个时候父类的交换结果并不会影响子类，也无法将 NSLog(@"UIViewController") 写入子类的 viewWillAppear: 方法中，所以不会输出。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;这里解决这个问题的思路是：在子类的 swizzledMethod 中，动态地去查找父类替换后方法的实现。每次调用都会去父类重新查找，而不是拷贝写死在子类的新方法中。这样子类 viewWillAppear: 方法的执行结果就和 +load 的加载顺序无关了。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;至于怎么实现动态查找，这里推荐 RSSwizzle ，这个库不仅解决了上面提到的问题，还保证了 Method Swizzling 的线程安全，是一种更安全优雅的解决方案。简单使用举例：

    RSSwizzleInstanceMethod([self class],
                            @selector(viewWillAppear:),
                            RSSWReturnType(void),
                            RSSWArguments(BOOL animated),
                            RSSWReplacement({
    
        NSLog(@"ViewController");
    
        RSSWCallOriginal(animated);
    
    }), RSSwizzleModeAlways, NULL);

#### 2. 获取所有属性和方法

&#160;&#160;&#160;&#160;&#160;&#160;&#160;Runtime 中提供了一系列 API 来获取 Class 的成员变量（ Ivar ）、属性（ Property ）、方法（ Method ）、协议（ Protocol ）等。直接看代码：

    // 测试 打印属性列表
    - (void)testPrintPropertyList {
        unsigned int count;
    
        objc_property_t *propertyList = class_copyPropertyList([self class], &count);
        for (unsigned int i=0; i<count; i++) {
            const char *propertyName = property_getName(propertyList[i]);
            NSLog(@"property----="">%@", [NSString stringWithUTF8String:propertyName]);
        }
    
        free(propertyList);
    }
    </count; i++) {
    
    // 测试 打印方法列表
    - (void)testPrintMethodList {
        unsigned int count;
    
        Method *methodList = class_copyMethodList([self class], &count);
        for (unsigned int i=0; i<count; i++) {
            Method method = methodList[i];
            NSLog(@"method----="">%@", NSStringFromSelector(method_getName(method)));
        }
    
        free(methodList);
    }
    </count; i++) {
    
    // 测试 打印成员变量列表
    - (void)testPrintIvarList {
        unsigned int count;
    
        Ivar *ivarList = class_copyIvarList([self class], &count);
        for (unsigned int i=0; i<count; i++) {
            Ivar myIvar = ivarList[i];
            const char *ivarName = ivar_getName(myIvar);
            NSLog(@"ivar----="">%@", [NSString stringWithUTF8String:ivarName]);
        }
    
        free(ivarList);
    }
    </count; i++) {
    
    // 测试 打印协议列表
    - (void)testPrintProtocolList {
        unsigned int count;
    
        __unsafe_unretained Protocol **protocolList = class_copyProtocolList([self class], &count);
        for (unsigned int i=0; i<count; i++) {
            Protocol *myProtocal = protocolList[i];
            const char *protocolName = protocol_getName(myProtocal);
            NSLog(@"protocol----="">%@", [NSString stringWithUTF8String:protocolName]);
        }
    
        free(protocolList);
    }
    </count; i++) {

&#160;&#160;&#160;&#160;&#160;&#160;&#160;因为这里用到的是 C 语言风格的变量，所以要注意用 free 来释放。至于获取这些属性方法有什么用，在下面的「应用场景」中会提到。

### 四、Runtime 的应用场景

&#160;&#160;&#160;&#160;&#160;&#160;&#160;说了这么多， Runtime 到底有什么用，下面就来介绍一下常见的几种应用场景。
#### 1. AOP 面向切面编程

&#160;&#160;&#160;&#160;&#160;&#160;&#160;来看一下 百度百科 上对「AOP」的解释：

> 在软件业，AOP为Aspect Oriented Programming的缩写，意为：面向切面编程，通过预编译方式和运行期动态代理实现程序功能的统一维护的一种技术。AOP是OOP的延续，是软件开发中的一个热点，也是Spring框架中的一个重要内容，是函数式编程的一种衍生范型。利用AOP可以对业务逻辑的各个部分进行隔离，从而使得业务逻辑各部分之间的耦合度降低，提高程序的可重用性，同时提高了开发的效率。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;画重点，`对业务逻辑进行分离，降低耦合度。`

&#160;&#160;&#160;&#160;&#160;&#160;&#160;假设现在有这样一个需求，我们要对应用中所有按钮的点击事件进行上报，统计每个按钮被点击的次数。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;首先我们要明确，统计功能应该与业务无关，即统计代码不应该与业务代码耦合在一起。因此用上面「AOP」的思想来实现是合适的，而 Runtime 给我们提供了这样一条途径。因为当按钮点击时，会调用 sendAction:to:forEvent: 方法，所以我们可以使用 Method Swizzling 来修改该方法，在其中添加上报的逻辑。来看代码：

    // UIButton+Swizzling.m
    + (void)load {
    
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
    
            RSSwizzleInstanceMethod([self class],
                                    @selector(sendAction:to:forEvent:),
                                    RSSWReturnType(void),
                                    RSSWArguments(SEL action, id target, UIEvent *event),
                                    RSSWReplacement({
    
                NSString *name = NSStringFromClass([self class]);
    
                NSLog(@"UIButton+Swizzling：%@ 按钮被点击--上报", name);
    
                RSSWCallOriginal(action, target, event);
    
            }), RSSwizzleModeAlways, NULL);
    
        });
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;注意：尽管上面的需求也可以用继承一个基类的方式来实现，但是如果此时已经有很多类继承自 UIButton ，则修改起来会很麻烦，其次我们也不能保证后续的所有按钮都继承这个基类。另外上面提到，统计逻辑不应该和业务逻辑耦合，如果为了统计的需求去修改业务代码，也是不可取的（除非迫不得已）。因此上面利用 Method Swizzling 的方式更为合适，也更为简洁。

#### 2. 字典转模型

&#160;&#160;&#160;&#160;&#160;&#160;&#160;我们可以用 KVC 来实现字典转模型，方法是调用 setValuesForKeysWithDictionary: 。但这种方法要求 Model 的属性和 NSDictionary 的 key 一一对应，否则就会报错。这里可以用 Runtime 配合 KVC ，来实现更灵活的字典转模型。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;下面为 NSObject 添加一个分类，添加一个初始化方法，来看代码：

    // NSObject+JSONExtension.h
    - (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    
        self = [self init];
    
        if (self) {
            unsigned int count;
            objc_property_t *propertyList = class_copyPropertyList([self class], &count);
            for (unsigned int i=0; i<count; i++) {
                // 获取属性列表
                const char *propertyName = property_getName(propertyList[i]);
    
                NSString *name = [NSString stringWithUTF8String:propertyName];
                id value = [dictionary objectForKey:name];
                if (value) {
                    // 注意这里用到 KVC
                    [self setValue:value forKey:name];
                }
            }
            free(propertyList);
        }
    
        return self;
    }
    </count; i++) {

&#160;&#160;&#160;&#160;&#160;&#160;&#160;尝试调用：

    NSDictionary *info = @{@"title": @"标题", @"count": @(1), @"test": @"hello"};
    ObjectA *objectA = [[ObjectA alloc] initWithDictionary:info];
    NSLog(@"%@", objectA.title);     // 输出：标题
    NSLog(@"%ld", (long)objectA.count);         // 输出：1

> 注意：在实际的应用中，会有更多复杂的情况需要考虑，比如字典中包含数组、对象等。这里只是做个简单示例。

#### 3. 进行归解档

&#160;&#160;&#160;&#160;&#160;&#160;&#160;「归档」是将对象序列化存入沙盒文件的过程，会调用 encodeWithCoder: 来序列化。「解档」是将沙盒文件中的数据反序列化读入内存的过程，会调用 initWithCoder: 来反序列化。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;通常来说，归解档需要对实例对象的各个属性依次进行归档和解档，十分繁琐且易出错。这里我们参照「字典转模型」的例子，通过获取类的所有属性，实现自动归解档。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;触发对象归档可以调用 NSKeyedArchiver 的 + archiveRootObject:toFile: 方法；触发对象解档可以调用 NSKeyedUnarchiver 的 + unarchiveObjectWithFile: 方法。

> 注： xib 文件在载入的时候，也会触发 initWithCoder: 方法，可见读取 xib 文件也是一个解档的过程。

&#160;&#160;&#160;&#160;&#160;&#160;&#160;首先在 NSObject 的分类中添加两个方法：

    // NSObject+JSONExtension.m
    - (void)initAllPropertiesWithCoder:(NSCoder *)coder {
    
        unsigned int count;
        objc_property_t *propertyList = class_copyPropertyList([self class], &count);
        for (unsigned int i=0; i<count; i++) {
            const char *propertyName = property_getName(propertyList[i]);
            NSString *name = [NSString stringWithUTF8String:propertyName];
    
            id value = [coder decodeObjectForKey:name];
            [self setValue:value forKey:name];
        }
        free(propertyList);
    }
    
    - (void)encodeAllPropertiesWithCoder:(NSCoder *)coder {
    
        unsigned int count;
        objc_property_t *propertyList = class_copyPropertyList([self class], &count);
        for (unsigned int i=0; i<count; i++) {
            const char *propertyName = property_getName(propertyList[i]);
            NSString *name = [NSString stringWithUTF8String:propertyName];
    
            id value = [self valueForKey:name];
            [coder encodeObject:value forKey:name];
        }
        free(propertyList);
    }
    </count; i++) {
    </count; i++) {

&#160;&#160;&#160;&#160;&#160;&#160;&#160;在 NSObject 的子类中实现归解档方法：

    // ObjectA.m
    - (id)initWithCoder:(NSCoder *)aDecoder{
    
        self = [super init];
        if (self) {
            [self initAllPropertiesWithCoder:aDecoder];
        }
        return self;
    }
    
    -(void)encodeWithCoder:(NSCoder *)aCoder{
    
        [self encodeAllPropertiesWithCoder:aCoder];
    }

&#160;&#160;&#160;&#160;&#160;&#160;&#160;尝试调用：

    NSDictionary *info = @{@"title": @"标题11", @"count": @(11)};
    NSString *path = [NSString stringWithFormat:@"%@/objectA.plist", NSHomeDirectory()];
    
    // 归档
    ObjectA *objectA = [[ObjectA alloc] initWithDictionary:info];
    [NSKeyedArchiver archiveRootObject:objectA toFile:path];
    
    // 解档
    ObjectA *objectB = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    NSLog(@"%@", objectB.title);      // 输出：标题11
    NSLog(@"%ld", (long)objectB.count);       // 输出：11

> 注：上面的代码逻辑并不完善，只是做简单示例用。

#### 4. 逆向开发

&#160;&#160;&#160;&#160;&#160;&#160;&#160;在「逆向开发」中，会用到一个叫 class-dump 的工具。这个工具可以将已脱壳的 APP 的所有类的头文件导出，为分析 APP 做准备。这里也是利用 Runtime 的特性，将存储在mach-O文件中的 @interface 和 @protocol 信息提取出来，并生成对应的 .h 文件。

#### 5. 热修复

&#160;&#160;&#160;&#160;&#160;&#160;&#160;「热修复」是一种不需要发布新版本，通过动态下发修复文件来修复 Bug 的方式。比如 JSPatch，就是利用 Runtime 强大的动态能力，对出问题的代码段进行替换。

### 源码

&#160;&#160;&#160;&#160;&#160;&#160;&#160;请到 [GitHub](https://github.com/HanQiGod/RuntimeDemo) 上查看完整例子。







