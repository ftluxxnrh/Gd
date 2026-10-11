#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ==========================================
// 매직키보드 키 매핑 정의 (HID Usage Codes)
// ==========================================
#define KEY_RIGHT_OPTION    0xE6  // UIKeyboardHIDUsageKeyboardRightAlt (오른쪽 옵션키)
#define KEY_SPACE           0x2C  // UIKeyboardHIDUsageKeyboardSpacebar (스페이스바)
#define KEY_ESCAPE          0x29  // UIKeyboardHIDUsageKeyboardEscape (ESC)
#define KEY_ARROW_LEFT      0x50  // UIKeyboardHIDUsageKeyboardLeftArrow (왼쪽 화살표)
#define KEY_ARROW_RIGHT     0x4F  // UIKeyboardHIDUsageKeyboardRightArrow (오른쪽 화살표)

@implementation UIWindow (GDMagicKeyboardHook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        // pressesBegan 스위즐링 (키 누름)
        SEL originalSelectorBegan = @selector(pressesBegan:withEvent:);
        SEL swizzledSelectorBegan = @selector(gd_pressesBegan:withEvent:);
        Method originalMethodBegan = class_getInstanceMethod(class, originalSelectorBegan);
        Method swizzledMethodBegan = class_getInstanceMethod(class, swizzledSelectorBegan);
        method_exchangeImplementations(originalMethodBegan, swizzledMethodBegan);
        
        // pressesEnded 스위즐링 (키 뗌)
        SEL originalSelectorEnded = @selector(pressesEnded:withEvent:);
        SEL swizzledSelectorEnded = @selector(gd_pressesEnded:withEvent:);
        Method originalMethodEnded = class_getInstanceMethod(class, originalSelectorEnded);
        Method swizzledMethodEnded = class_getInstanceMethod(class, swizzledSelectorEnded);
        method_exchangeImplementations(originalMethodEnded, swizzledMethodEnded);
    });
}

// ------------------------------------------
// 1. 키를 눌렀을 때 (KeyDown)
// ------------------------------------------
- (void)gd_pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *press in presses) {
        NSInteger keyCode = press.key.keyCode;
        
        // [점프 액션] : 오른쪽 옵션키 OR 스페이스바
        if (keyCode == KEY_RIGHT_OPTION || keyCode == KEY_SPACE) {
            NSLog(@"[MagicHook] 점프 누름 (Key: 0x%lX)", (long)keyCode);
            [self gd_handleJump:YES];
            return;
        }
        
        // [메뉴 / 일시정지] : ESC 키
        if (keyCode == KEY_ESCAPE) {
            NSLog(@"[MagicHook] ESC (일시정지/메뉴) 누름");
            [self gd_handleEscape];
            return;
        }
        
        // [맵/페이지 넘기기] : 좌/우 화살표
        if (keyCode == KEY_ARROW_LEFT) {
            NSLog(@"[MagicHook] 이전 페이지 (◀)");
            [self gd_handlePageNavigation:NO]; // 이전
            return;
        }
        if (keyCode == KEY_ARROW_RIGHT) {
            NSLog(@"[MagicHook] 다음 페이지 (▶)");
            [self gd_handlePageNavigation:YES]; // 다음
            return;
        }
    }
    [self gd_pressesBegan:presses withEvent:event];
}

// ------------------------------------------
// 2. 키에서 손을 뗐을 때 (KeyUp)
// ------------------------------------------
- (void)gd_pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *press in presses) {
        NSInteger keyCode = press.key.keyCode;
        
        // [점프 해제] : 누르고 있던 점프 키에서 손을 뗌
        if (keyCode == KEY_RIGHT_OPTION || keyCode == KEY_SPACE) {
            NSLog(@"[MagicHook] 점프 뗌 (Key: 0x%lX)", (long)keyCode);
            [self gd_handleJump:NO];
            return;
        }
    }
    [self gd_pressesEnded:presses withEvent:event];
}

// ==========================================
// 지메 내부 동작 트리거 핸들러
// ==========================================

// 점프 핸들러 (isDown: YES=누름, NO=뗌)
- (void)gd_handleJump:(BOOL)isDown {
    // 진동 피드백 (반응 테스트용)
    if (isDown) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
    
    // 화면 중심점 가상 터치 디스패치 (인게임 점프 처리)
    UIView *targetView = self.rootViewController.view;
    CGPoint jumpPoint = CGPointMake(targetView.bounds.size.width / 2.0, targetView.bounds.size.height / 2.0);
    // TODO: 인게임 CCTouchDispatcher 또는 터치 뷰로 이벤트 주입
}

// ESC 핸들러 (좌상단 일시정지 버튼 위치 시뮬레이션)
- (void)gd_handleEscape {
    UIView *targetView = self.rootViewController.view;
    // 인게임의 좌상단 일시정지 버튼 좌표 대략 (x: 40, y: 40)
    CGPoint pausePoint = CGPointMake(40, 40);
    NSLog(@"[MagicHook] 일시정지 트리거 좌표: %@", NSStringFromCGPoint(pausePoint));
}

// 맵 페이지 넘기기 핸들러 (isNext: YES=다음페이지, NO=이전페이지)
- (void)gd_handlePageNavigation:(BOOL)isNext {
    UIView *targetView = self.rootViewController.view;
    CGFloat width = targetView.bounds.size.width;
    CGFloat height = targetView.bounds.size.height;
    
    // 맵 선택 화면 좌/우 화살표 버튼 위치
    CGPoint pagePoint = isNext ? CGPointMake(width - 40, height / 2.0) : CGPointMake(40, height / 2.0);
    NSLog(@"[MagicHook] 페이지 이동 트리거 좌표: %@", NSStringFromCGPoint(pagePoint));
}

@end
