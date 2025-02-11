// ==================== 全局设置部分 ====================
// 声明各类和接口（可能是对目标 App 类的声明）
@interface AWENormalModeTabBarGeneralButton : UIButton
@end
// 声明目标 App 的各种 UI 组件类
// ...(其他接口声明同理)

// ==================== Hook 方法实现部分 ====================

// 1. 视频播放速率控制
%hook AWEAwemePlayVideoViewController
- (void)setIsAutoPlay:(BOOL)arg0 {
    // 从 NSUserDefaults 读取用户设置的默认播放速度
    float defaultSpeed = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYDefaultSpeed"];
    
    // 如果设置有效且不等于 1 倍速，则应用设置
    if (defaultSpeed > 0 && defaultSpeed != 1) {
        [self setVideoControllerPlaybackRate:defaultSpeed];
    }
    
    // 调用原始实现
    %orig(arg0);
}
%end

// 2. 隐藏 TabBar 加号按钮
%hook AWENormalModeTabBarGeneralPlusButton
+ (id)button {
    // 检查是否隐藏加号按钮
    BOOL isHiddenJia = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenJia"];
    if (isHiddenJia) {
        return nil; // 返回 nil 会阻止按钮创建
    }
    return %orig; // 调用原始实现
}
%end

// 3. 顶部栏透明度控制
%hook AWEFeedContainerContentView
- (void)setAlpha:(CGFloat)alpha {
    NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYtopbartransparent"];
    
    // 纯净模式处理
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnablePure"]) {
        %orig(0.0); // 强制设置完全透明
        
        // 创建定时器轮询查找目标 ViewController
        static dispatch_source_t timer = nil;
        static int attempts = 0;
        
        // ...(定时器配置略)
        
        // 递归查找目标 ViewController 并设置 pureMode 属性
        void (^tryFindAndSetPureMode)(void) = ^{
            // 通过 Runtime 动态获取类
            Class FeedTableVC = NSClassFromString(@"AWEFeedTableViewController");
            // 遍历视图层级查找目标 VC
            UIViewController *feedVC = [self findViewController:keyWindow.rootViewController ofClass:FeedTableVC];
            
            // 找到后通过 KVC 设置属性
            [feedVC setValue:@YES forKey:@"pureMode"];
        };
        // ...(定时器启动逻辑)
    }
    
    // 普通透明度设置
    if (transparentValue && transparentValue.length > 0) {
        CGFloat alphaValue = [transparentValue floatValue];
        %orig(alphaValue); // 应用用户设置的透明度
    } else {
        %orig(1.0); // 默认不透明
    }
}

// 新增的视图控制器查找方法（深度优先搜索）
%new
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass {
    // 递归检查当前控制器及其子控制器
    if (!vc) return nil;
    if ([vc isKindOfClass:targetClass]) return vc;
    
    // 检查子控制器
    for (UIViewController *childVC in vc.childViewControllers) {
        UIViewController *found = [self findViewController:childVC ofClass:targetClass];
        if (found) return found;
    }
    
    // 检查 presented 控制器
    return [self findViewController:vc.presentedViewController ofClass:targetClass];
}
%end

// 4. 弹幕颜色设置
%hook AWEDanmakuContentLabel
- (void)setTextColor:(UIColor *)textColor {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDanmuColor"]) {
        NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];
        
        // 随机颜色处理
        if ([danmuColor.lowercaseString containsString:@"random"]) {
            textColor = [UIColor colorWithRed:(arc4random_uniform(256))/255.0
                                      green:(arc4random_uniform(256))/255.0
                                       blue:(arc4random_uniform(256))/255.0
                                      alpha:CGColorGetAlpha(textColor.CGColor)];
        }
        // 十六进制颜色处理
        else if ([danmuColor hasPrefix:@"#"]) {
            textColor = [self colorFromHexString:danmuColor baseColor:textColor];
        }
    }
    %orig(textColor); // 调用原始设置方法
}

// 十六进制转 UIColor 方法
%new
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor {
    // 处理字符串格式
    hexString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    
    // 使用 NSScanner 解析十六进制
    unsigned int rgbValue = 0;
    [[NSScanner scannerWithString:hexString] scanHexInt:&rgbValue];
    
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0
                         green:((rgbValue & 0x00FF00) >> 8)/255.0
                          blue:(rgbValue & 0x0000FF)/255.0
                         alpha:CGColorGetAlpha(baseColor.CGColor)];
}
%end

// 5. 全局手势设置（长按呼出设置界面）
%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig(frame);
    if (window) {
        // 添加双指长按手势
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] 
            initWithTarget:self 
                    action:@selector(handleDoubleFingerLongPressGesture:)];
        gesture.numberOfTouchesRequired = 2;
        [window addGestureRecognizer:gesture];
    }
    return window;
}

// 手势响应方法
%new
- (void)handleDoubleFingerLongPressGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // 动态创建设置视图控制器
        UIViewController *settingVC = [[NSClassFromString(@"DYYYSettingViewController") alloc] init];
        
        // 配置模态展示样式
        settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
        
        // 添加关闭按钮
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
        // ...(布局约束代码略)
        
        // 展示设置界面
        [self.rootViewController presentViewController:settingVC animated:YES completion:nil];
    }
}
%end

// 6. 其他功能模块示例：
// ----------------------------
// 隐藏直播标记
%hook AWEFeedLiveMarkView
- (void)setHidden:(BOOL)hidden {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAvatarButton"]) {
        hidden = YES; // 强制隐藏
    }
    %orig(hidden);
}
%end

// 强制允许长视频下载
%hook AWELongVideoControlModel
- (bool)allowDownload {
    return YES; // 覆盖原始返回值
}
%end

// TabBar 按钮布局调整
%hook AWENormalModeTabBar
- (void)layoutSubviews {
    %orig;
    
    // 根据设置隐藏特定按钮
    NSMutableArray *visibleButtons = [NSMutableArray array];
    for (UIView *subview in self.subviews) {
        // 判断按钮类型并过滤
        NSString *label = subview.accessibilityLabel;
        BOOL shouldHide = [self shouldHideButtonWithLabel:label];
        
        if (!shouldHide) {
            [visibleButtons addObject:subview];
        } else {
            [subview removeFromSuperview];
        }
    }
    
    // 重新计算布局
    CGFloat buttonWidth = self.bounds.size.width / visibleButtons.count;
    [visibleButtons enumerateObjectsUsingBlock:^(UIView *button, NSUInteger idx, BOOL *stop) {
        button.frame = CGRectMake(idx * buttonWidth, button.frame.origin.y, buttonWidth, button.frame.size.height);
    }];
}
%end

// 7. 键盘外观控制
%hook UITextInputTraits
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        %orig(UIKeyboardAppearanceDark); // 强制深色键盘
    } else {
        %orig; // 保持原始设置
    }
}
%end

// 8. 自动播放下一视频
%hook AWEPlayInteractionProgressController
- (void)updateProgressSliderWithTime:(CGFloat)current totalDuration:(CGFloat)total {
    %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAutoPlay"]) {
        // 判断是否播放到结尾
        if (fabs(current - total) <= 0.3) {
            // 查找目标视图控制器
            Class targetClass = NSClassFromString(@"AWEFeedTableViewController");
            UIViewController *targetVC = [self findViewController:keyWindow.rootViewController ofClass:targetClass];
            
            // 执行滚动到下一个视频
            [targetVC performSelector:@selector(scrollToNextVideo)];
        }
    }
}
%end