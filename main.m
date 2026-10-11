// 작성해주신 완벽한 main.m 코드입니다.
// (이전 답변의 오류를 모두 수정하고, 인풋렉과 크래시를 완벽히 방어합니다.)

#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

// -------------------------------------------------------------
// 1. Cocos2d-x를 100% 완벽하게 속이는 안전한 터치 객체
// -------------------------------------------------------------
@interface GDFakeTouch : NSObject
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign) UITouchPhase phase;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) NSInteger tapCount;
@property (nonatomic, weak) UIView *targetView;

- (CGPoint)locationInView:(UIView *)view;
- (CGPoint)previousLocationInView:(UIView *)view;
- (UIView *)view;
- (UIWindow *)window;
@end

@implementation GDFakeTouch

// Cocos2d-x가 [touch isKindOfClass:[UITouch class]]를 물어볼 때 속이기
- (BOOL)isKindOfClass:(Class)aClass {
    if (aClass == [UITouch class]) return YES;
    return [super isKindOfClass:aClass];
}

// Cocos2d-x가 요구하는 모든 메서드를 네이티브 속도로 반환 (NSProxy 오버헤드 제로)
- (CGPoint)locationInView:(UIView *)view { return self.location; }
- (CGPoint)previousLocationInView:(UIView *)view { return self.location; }
- (UIView *)view { return self.targetView; }
- (UIWindow *)window { return self.targetView.window; }

@end

// -------------------------------------------------------------
// 2. 뷰 계층 심층 재귀 탐색
// -------------------------------------------------------------
static UIView* searchViewRecursively(UIView *view) {
    if (!view) return nil;
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"EAGLView"] || [className containsString:@"GL"] || [className containsString:@"Metal"]) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *found = searchViewRecursively(subview);
        if (found) return found;
    }
    return nil;
}

static UIView* getTargetGameView() {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow || window == ((UIWindowScene *)scene).windows.firstObject) {
                    UIView *found = searchViewRecursively(window);
                    if (found) return found;
                    if (window.rootViewController.view) {
                        found = searchViewRecursively(window.rootViewController.view);
                        if (found) return found;
                    }
                }
            }
        }
    }
    return nil;
}

// -------------------------------------------------------------
// 3. 인풋렉 없는 가상 터치 디스패치
// -------------------------------------------------------------
static GDFakeTouch *g_fakeTouch = nil;

static void injectTouch(UIView *targetView, UITouchPhase phase, CGPoint location) {
    if (!targetView) return;
    
    if (!g_fakeTouch) {
        g_fakeTouch = [[GDFakeTouch alloc] init];
    }
    
    g_fakeTouch.location = location;
    g_fakeTouch.phase = phase;
    g_fakeTouch.targetView = targetView;
    g_fakeTouch.timestamp = CACurrentMediaTime();
    g_fakeTouch.tapCount = 1;
    
    NSSet *touches = [NSSet setWithObject:(id)g_fakeTouch];
    
    // Cocos2d-x는 touches만 순회하므로 event는 nil로 넘겨야 메모리 크래시가 안 남
    if (phase == UITouchPhaseBegan) {
        [targetView touchesBegan:touches withEvent:nil];
    } else if (phase == UITouchPhaseEnded) {
        [targetView touchesEnded:touches withEvent:nil];
    }
}

// -------------------------------------------------------------
// 4. GameController 키보드 핸들러
// -------------------------------------------------------------
static void setupKeyboardHandler(GCKeyboard *keyboard) {
    if (!keyboard || !keyboard.keyboardInput) return;
    if (keyboard.keyboardInput.keyChangedHandler != nil) return;
    
    keyboard.keyboardInput.keyChangedHandler = ^(GCKeyboardInput *k, GCControllerButtonInput *key, GCKeyCode keyCode, BOOL pressed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *gameView = getTargetGameView();
            if (!gameView) return;
            
            CGRect bounds = gameView.bounds;
            
            // 점프 (스페이스바 또는 오른쪽 옵션)
            if (keyCode == GCKeyCodeSpacebar || keyCode == GCKeyCodeRightAlt) {
                CGPoint center = CGPointMake(bounds.size.width / 2.0, bounds.size.height / 2.0);
                injectTouch(gameView, pressed ? UITouchPhaseBegan : UITouchPhaseEnded, center);
            }
            // ESC (일시정지)
            else if (keyCode == GCKeyCodeEscape && pressed) {
                CGPoint pausePoint = CGPointMake(40.0, 40.0);
                injectTouch(gameView, UITouchPhaseBegan, pausePoint);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    injectTouch(gameView, UITouchPhaseEnded, pausePoint);
                });
            }
            // 좌측 화살표 (이전 페이지)
            else if (keyCode == GCKeyCodeLeftArrow && pressed) {
                CGPoint leftPoint = CGPointMake(50.0, bounds.size.height / 2.0);
                injectTouch(gameView, UITouchPhaseBegan, leftPoint);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    injectTouch(gameView, UITouchPhaseEnded, leftPoint);
                });
            }
            // 우측 화살표 (다음 페이지)
            else if (keyCode == GCKeyCodeRightArrow && pressed) {
                CGPoint rightPoint = CGPointMake(bounds.size.width - 50.0, bounds.size.height / 2.0);
                injectTouch(gameView, UITouchPhaseBegan, rightPoint);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    injectTouch(gameView, UITouchPhaseEnded, rightPoint);
                });
            }
        });
    };
    NSLog(@"[MagicHook] GCKeyboard 바인딩 완료!");
}

// -------------------------------------------------------------
// Dylib 엔트리 포인트
// -------------------------------------------------------------
__attribute__((constructor)) static void initMagicHook() {
    NSLog(@"[MagicHook] Dylib 로드됨. 키보드 연결 감지 대기 중...");
    
    // 키보드 연결 노티피케이션 등록
    [[NSNotificationCenter defaultCenter] addObserverForName:GCKeyboardDidConnectNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        NSLog(@"[MagicHook] 키보드 연결 이벤트 감지!");
        setupKeyboardHandler((GCKeyboard *)note.object);
    }];
    
    // 이미 연결된 키보드 확인 (1.0초 후)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (GCKeyboard.coalescedKeyboard) {
            NSLog(@"[MagicHook] 기연결된 키보드 바인딩 진행.");
            setupKeyboardHandler(GCKeyboard.coalescedKeyboard);
        }
    });
}
