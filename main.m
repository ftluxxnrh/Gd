#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define KEY_RIGHT_OPTION    0xE6  // 오른쪽 옵션
#define KEY_SPACE           0x2C  // 스페이스바
#define KEY_ESCAPE          0x29  // ESC
#define KEY_ARROW_LEFT      0x50  // 왼쪽 화살표
#define KEY_ARROW_RIGHT     0x4F  // 오른쪽 화살표

// 지메 엔진(Cocos2d)에 꽂아넣을 가상 터치 객체
@interface GDFakeTouch : UITouch
@property (nonatomic, assign) CGPoint customLocation;
@property (nonatomic, assign) UITouchPhase customPhase;
@end

@implementation GDFakeTouch
- (CGPoint)locationInView:(UIView *)view { return self.customLocation; }
- (CGPoint)previousLocationInView:(UIView *)view { return self.customLocation; }
- (UITouchPhase)phase { return self.customPhase; }
@end

static GDFakeTouch *g_jumpTouch = nil;

@implementation UIResponder (GDMagicKeyboardHook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [UIResponder class];
        
        SEL origBegan = @selector(pressesBegan:withEvent:);
        SEL swizBegan = @selector(gd_pressesBegan:withEvent:);
        method_exchangeImplementations(class_getInstanceMethod(class, origBegan),
                                       class_getInstanceMethod(class, swizBegan));
        
        SEL origEnded = @selector(pressesEnded:withEvent:);
        SEL swizEnded = @selector(gd_pressesEnded:withEvent:);
        method_exchangeImplementations(class_getInstanceMethod(class, origEnded),
                                       class_getInstanceMethod(class, swizEnded));
    });
}

// ------------------------------------------
// 키 누름 (KeyDown)
// ------------------------------------------
- (void)gd_pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    // UIWindow 레벨에서 딱 1번만 가로챔 (하위 뷰들의 중복 호출 방지)
    if ([self isKindOfClass:[UIWindow class]]) {
        UIWindow *window = (UIWindow *)self;
        for (UIPress *press in presses) {
            NSInteger code = press.key.keyCode;
            
            // 1. 점프 누름 (우측 옵션 OR 스페이스바)
            if (code == KEY_RIGHT_OPTION || code == KEY_SPACE) {
                [self gd_dispatchTouchOnWindow:window phase:UITouchPhaseBegan isJump:YES point:CGPointZero];
                return;
            }
            
            // 2. ESC (일시정지 / 뒤로가기) -> 좌상단 버튼 터치 (40, 40)
            if (code == KEY_ESCAPE) {
                [self gd_dispatchClickOnWindow:window point:CGPointMake(40, 40)];
                return;
            }
            
            // 3. 화살표 (이전/다음 페이지)
            if (code == KEY_ARROW_LEFT) {
                CGPoint leftPoint = CGPointMake(40, window.bounds.size.height / 2.0);
                [self gd_dispatchClickOnWindow:window point:leftPoint];
                return;
            }
            if (code == KEY_ARROW_RIGHT) {
                CGPoint rightPoint = CGPointMake(window.bounds.size.width - 40, window.bounds.size.height / 2.0);
                [self gd_dispatchClickOnWindow:window point:rightPoint];
                return;
            }
        }
    }
    [self gd_pressesBegan:presses withEvent:event];
}

// ------------------------------------------
// 키 뗌 (KeyUp)
// ------------------------------------------
- (void)gd_pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if ([self isKindOfClass:[UIWindow class]]) {
        UIWindow *window = (UIWindow *)self;
        for (UIPress *press in presses) {
            NSInteger code = press.key.keyCode;
            // 점프 키에서 손을 뗐을 때 (홀드 해제)
            if (code == KEY_RIGHT_OPTION || code == KEY_SPACE) {
                [self gd_dispatchTouchOnWindow:window phase:UITouchPhaseEnded isJump:YES point:CGPointZero];
                return;
            }
        }
    }
    [self gd_pressesEnded:presses withEvent:event];
}

// ------------------------------------------
// 가상 터치 이벤트 주입 헬퍼
// ------------------------------------------
- (UIView *)gd_findTargetView:(UIWindow *)window {
    UIView *rootView = window.rootViewController.view;
    return rootView ? rootView : window;
}

- (void)gd_dispatchTouchOnWindow:(UIWindow *)window phase:(UITouchPhase)phase isJump:(BOOL)isJump point:(CGPoint)point {
    UIView *targetView = [self gd_findTargetView:window];
    
    if (isJump) {
        if (phase == UITouchPhaseBegan) {
            if (!g_jumpTouch) {
                g_jumpTouch = [[GDFakeTouch alloc] init];
            }
            // 화면 정중앙 터치 좌표
            g_jumpTouch.customLocation = CGPointMake(targetView.bounds.size.width / 2.0, targetView.bounds.size.height / 2.0);
            g_jumpTouch.customPhase = UITouchPhaseBegan;
            [targetView touchesBegan:[NSSet setWithObject:g_jumpTouch] withEvent:nil];
        } else if (phase == UITouchPhaseEnded) {
            if (g_jumpTouch) {
                g_jumpTouch.customPhase = UITouchPhaseEnded;
                [targetView touchesEnded:[NSSet setWithObject:g_jumpTouch] withEvent:nil];
            }
        }
    }
}

// 클릭(누르고 바로 떼기) 시뮬레이션 (ESC 및 화살표용)
- (void)gd_dispatchClickOnWindow:(UIWindow *)window point:(CGPoint)point {
    UIView *targetView = [self gd_findTargetView:window];
    GDFakeTouch *clickTouch = [[GDFakeTouch alloc] init];
    clickTouch.customLocation = point;
    
    clickTouch.customPhase = UITouchPhaseBegan;
    [targetView touchesBegan:[NSSet setWithObject:clickTouch] withEvent:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        clickTouch.customPhase = UITouchPhaseEnded;
        [targetView touchesEnded:[NSSet setWithObject:clickTouch] withEvent:nil];
    });
}

@end#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define KEY_RIGHT_OPTION    0xE6  // 오른쪽 옵션
#define KEY_SPACE           0x2C  // 스페이스바
#define KEY_ESCAPE          0x29  // ESC
#define KEY_ARROW_LEFT      0x50  // 왼쪽 화살표
#define KEY_ARROW_RIGHT     0x4F  // 오른쪽 화살표

// 지메 엔진(Cocos2d)에 꽂아넣을 가상 터치 객체
@interface GDFakeTouch : UITouch
@property (nonatomic, assign) CGPoint customLocation;
@property (nonatomic, assign) UITouchPhase customPhase;
@end

@implementation GDFakeTouch
- (CGPoint)locationInView:(UIView *)view { return self.customLocation; }
- (CGPoint)previousLocationInView:(UIView *)view { return self.customLocation; }
- (UITouchPhase)phase { return self.customPhase; }
@end

static GDFakeTouch *g_jumpTouch = nil;

@implementation UIResponder (GDMagicKeyboardHook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [UIResponder class];
        
        SEL origBegan = @selector(pressesBegan:withEvent:);
        SEL swizBegan = @selector(gd_pressesBegan:withEvent:);
        method_exchangeImplementations(class_getInstanceMethod(class, origBegan),
                                       class_getInstanceMethod(class, swizBegan));
        
        SEL origEnded = @selector(pressesEnded:withEvent:);
        SEL swizEnded = @selector(gd_pressesEnded:withEvent:);
        method_exchangeImplementations(class_getInstanceMethod(class, origEnded),
                                       class_getInstanceMethod(class, swizEnded));
    });
}

// ------------------------------------------
// 키 누름 (KeyDown)
// ------------------------------------------
- (void)gd_pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    // UIWindow 레벨에서 딱 1번만 가로챔 (하위 뷰들의 중복 호출 방지)
    if ([self isKindOfClass:[UIWindow class]]) {
        UIWindow *window = (UIWindow *)self;
        for (UIPress *press in presses) {
            NSInteger code = press.key.keyCode;
            
            // 1. 점프 누름 (우측 옵션 OR 스페이스바)
            if (code == KEY_RIGHT_OPTION || code == KEY_SPACE) {
                [self gd_dispatchTouchOnWindow:window phase:UITouchPhaseBegan isJump:YES point:CGPointZero];
                return;
            }
            
            // 2. ESC (일시정지 / 뒤로가기) -> 좌상단 버튼 터치 (40, 40)
            if (code == KEY_ESCAPE) {
                [self gd_dispatchClickOnWindow:window point:CGPointMake(40, 40)];
                return;
            }
            
            // 3. 화살표 (이전/다음 페이지)
            if (code == KEY_ARROW_LEFT) {
                CGPoint leftPoint = CGPointMake(40, window.bounds.size.height / 2.0);
                [self gd_dispatchClickOnWindow:window point:leftPoint];
                return;
            }
            if (code == KEY_ARROW_RIGHT) {
                CGPoint rightPoint = CGPointMake(window.bounds.size.width - 40, window.bounds.size.height / 2.0);
                [self gd_dispatchClickOnWindow:window point:rightPoint];
                return;
            }
        }
    }
    [self gd_pressesBegan:presses withEvent:event];
}

// ------------------------------------------
// 키 뗌 (KeyUp)
// ------------------------------------------
- (void)gd_pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if ([self isKindOfClass:[UIWindow class]]) {
        UIWindow *window = (UIWindow *)self;
        for (UIPress *press in presses) {
            NSInteger code = press.key.keyCode;
            // 점프 키에서 손을 뗐을 때 (홀드 해제)
            if (code == KEY_RIGHT_OPTION || code == KEY_SPACE) {
                [self gd_dispatchTouchOnWindow:window phase:UITouchPhaseEnded isJump:YES point:CGPointZero];
                return;
            }
        }
    }
    [self gd_pressesEnded:presses withEvent:event];
}

// ------------------------------------------
// 가상 터치 이벤트 주입 헬퍼
// ------------------------------------------
- (UIView *)gd_findTargetView:(UIWindow *)window {
    UIView *rootView = window.rootViewController.view;
    return rootView ? rootView : window;
}

- (void)gd_dispatchTouchOnWindow:(UIWindow *)window phase:(UITouchPhase)phase isJump:(BOOL)isJump point:(CGPoint)point {
    UIView *targetView = [self gd_findTargetView:window];
    
    if (isJump) {
        if (phase == UITouchPhaseBegan) {
            if (!g_jumpTouch) {
                g_jumpTouch = [[GDFakeTouch alloc] init];
            }
            // 화면 정중앙 터치 좌표
            g_jumpTouch.customLocation = CGPointMake(targetView.bounds.size.width / 2.0, targetView.bounds.size.height / 2.0);
            g_jumpTouch.customPhase = UITouchPhaseBegan;
            [targetView touchesBegan:[NSSet setWithObject:g_jumpTouch] withEvent:nil];
        } else if (phase == UITouchPhaseEnded) {
            if (g_jumpTouch) {
                g_jumpTouch.customPhase = UITouchPhaseEnded;
                [targetView touchesEnded:[NSSet setWithObject:g_jumpTouch] withEvent:nil];
            }
        }
    }
}

// 클릭(누르고 바로 떼기) 시뮬레이션 (ESC 및 화살표용)
- (void)gd_dispatchClickOnWindow:(UIWindow *)window point:(CGPoint)point {
    UIView *targetView = [self gd_findTargetView:window];
    GDFakeTouch *clickTouch = [[GDFakeTouch alloc] init];
    clickTouch.customLocation = point;
    
    clickTouch.customPhase = UITouchPhaseBegan;
    [targetView touchesBegan:[NSSet setWithObject:clickTouch] withEvent:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        clickTouch.customPhase = UITouchPhaseEnded;
        [targetView touchesEnded:[NSSet setWithObject:clickTouch] withEvent:nil];
    });
}

@end
