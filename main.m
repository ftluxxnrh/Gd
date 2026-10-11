#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import <objc/runtime.h>
#import <objc/message.h>

// CCEAGLView 동적 탐색 함수
static UIView* findEAGLView() {
    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
    if (!window) return nil;
    
    for (UIView *subview in window.subviews) {
        // GD의 OpenGL 뷰는 보통 CCEAGLView 또는 EAGLView 클래스명을 가집니다.
        if ([NSStringFromClass([subview class]) containsString:@"EAGLView"]) {
            return subview;
        }
    }
    return window; // 못 찾을 경우 최상위 뷰에 전달
}

// 인풋렉 없는 터치 합성 및 주입 함수
static void injectTouch(UIView *targetView, UITouchPhase phase, CGPoint location) {
    if (!targetView) return;
    
    Class touchClass = NSClassFromString(@"UITouch");
    
    // 1. NS_UNAVAILABLE 우회: alloc 호출
    id touch = ((id (*)(Class, SEL))objc_msgSend)(touchClass, sel_registerName("alloc"));
    
    // 2. Private Initializer 호출: _initInView:
    SEL initSel = sel_registerName("_initInView:");
    if ([touch respondsToSelector:initSel]) {
        touch = ((id (*)(id, SEL, UIView *))objc_msgSend)(touch, initSel, targetView);
    } else {
        return; // iOS 버전에 따라 셀렉터가 다를 수 있음 (기본적으로 iOS 14~17 지원)
    }

    // 3. 터치 속성 설정 (Private Setter 직접 호출)
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(touch, sel_registerName("setPhase:"), phase);
    ((void (*)(id, SEL, CGPoint))objc_msgSend)(touch, sel_registerName("setLocationInWindow:"), location);
    ((void (*)(id, SEL, CGPoint))objc_msgSend)(touch, sel_registerName("setPreviousLocationInWindow:"), location);
    ((void (*)(id, SEL, double))objc_msgSend)(touch, sel_registerName("setTimestamp:"), CACurrentMediaTime());
    
    // Window 설정
    Ivar windowIvar = class_getInstanceVariable(touchClass, "_window");
    if (windowIvar) {
        object_setIvar(touch, windowIvar, targetView.window);
    }

    // 4. 유효한 UIEvent 확보
    UIEvent *event = ((UIEvent *(*)(id, SEL))objc_msgSend)(UIApplication.sharedApplication, sel_registerName("_touchesEvent"));
    NSSet *touches = [NSSet setWithObject:touch];

    // 5. Cocos2d-x 뷰에 직접 전달 (Hit-test 우회로 0ms 지연 달성)
    if (phase == UITouchPhaseBegan) {
        [targetView touchesBegan:touches withEvent:event];
    } else if (phase == UITouchPhaseEnded) {
        [targetView touchesEnded:touches withEvent:event];
    }
}

// Dylib 엔트리 포인트
__attribute__((constructor)) static void initMagicHook() {
    // 앱 실행 후 UI가 로드될 시간을 약간 줌
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // GCKeyboard를 이용한 전역 하드웨어 키 후킹
        GCKeyboard *keyboard = GCKeyboard.coalescedKeyboard;
        if (!keyboard) {
            NSLog(@"[MagicHook] GCKeyboard를 찾을 수 없습니다.");
            return;
        }
        
        keyboard.keyboardInput.keyChangedHandler = ^(GCKeyboardInput *keyboard, GCControllerButtonInput *key, GCKeyCode keyCode, BOOL pressed) {
            
            // 메인 스레드에서 UIKit 작업 수행 (크래시 방지)
            dispatch_async(dispatch_get_main_queue(), ^{
                UIView *glView = findEAGLView();
                if (!glView) return;
                
                CGRect bounds = glView.bounds;
                
                if (keyCode == GCKeyCodeSpacebar || keyCode == GCKeyCodeRightAlt) {
                    // 점프: 화면 중앙 하단 터치
                    CGPoint jumpPoint = CGPointMake(bounds.size.width / 2.0, bounds.size.height - 100.0);
                    injectTouch(glView, pressed ? UITouchPhaseBegan : UITouchPhaseEnded, jumpPoint);
                    
                } else if (keyCode == GCKeyCodeEscape) {
                    // 일시정지: 화면 좌측 상단 터치 (GD Pause 버튼 위치)
                    if (pressed) {
                        CGPoint pausePoint = CGPointMake(40.0, 40.0);
                        injectTouch(glView, UITouchPhaseBegan, pausePoint);
                        // 뗌 이벤트는 약간의 딜레이 후 주입 (인식률 향상)
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            injectTouch(glView, UITouchPhaseEnded, pausePoint);
                        });
                    }
                    
                } else if (keyCode == GCKeyCodeLeftArrow) {
                    // 페이지 왼쪽 넘기기
                    if (pressed) {
                        CGPoint leftPoint = CGPointMake(50.0, bounds.size.height / 2.0);
                        injectTouch(glView, UITouchPhaseBegan, leftPoint);
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            injectTouch(glView, UITouchPhaseEnded, leftPoint);
                        });
                    }
                    
                } else if (keyCode == GCKeyCodeRightArrow) {
                    // 페이지 오른쪽 넘기기
                    if (pressed) {
                        CGPoint rightPoint = CGPointMake(bounds.size.width - 50.0, bounds.size.height / 2.0);
                        injectTouch(glView, UITouchPhaseBegan, rightPoint);
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            injectTouch(glView, UITouchPhaseEnded, rightPoint);
                        });
                    }
                }
            });
        };
        
        NSLog(@"[MagicHook] Successfully initialized GCKeyboard hook.");
    });
}
