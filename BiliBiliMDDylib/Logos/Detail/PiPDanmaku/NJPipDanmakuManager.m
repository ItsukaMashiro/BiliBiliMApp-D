//
//  NJPipDanmakuManager.m
//  BiliBiliTweak
//
//  Created by touchWorld on 2025/8/11.
//

#import "NJPipDanmakuManager.h"
#import <AVFoundation/AVFoundation.h>

/// 画中画窗口检查间隔
#define NJ_PIP_DANMAKU_CHECK_INTERVAL 0.25

/// 画中画窗口的 windowLevel（系统未公开 PiP 窗口的 level，1000 为 alert 级别，系统 PiP 窗口使用该级别）
#define NJ_PIP_WINDOW_LEVEL 1000

/// 弹幕视图类名关键字（小写）
#define NJ_PIP_DANMAKU_CLASS_NAME_KEYWORDS @[@"danmaku", @"damaku"]

/// 记录弹幕视图移动前的状态，用于恢复
@interface NJPipDanmakuContext : NSObject

@property (nonatomic, weak) UIView *parentView;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) BOOL userInteractionEnabled;
@property (nonatomic, assign) UIViewAutoresizing autoresizingMask;

@end

@implementation NJPipDanmakuContext
@end

@interface NJPipDanmakuManager ()

/// 检查定时器
@property (nonatomic, strong) NSTimer *timer;
/// 当前检测到的画中画窗口
@property (nonatomic, weak) UIWindow *pipWindow;
/// 当前移动的弹幕视图
@property (nonatomic, weak) UIView *danmakuView;
/// 弹幕视图移动前的状态
@property (nonatomic, strong) NJPipDanmakuContext *context;

@end

@implementation NJPipDanmakuManager

#pragma mark - Life Cycle Methods

NJ_SINGLETON_M(Manager)

- (BOOL)isPipDanmakuActive {
    return self.danmakuView != nil;
}

#pragma mark - Public Methods

- (void)startObserving {
    if (self.timer) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            return;
        }
        self.timer = [NSTimer scheduledTimerWithTimeInterval:NJ_PIP_DANMAKU_CHECK_INTERVAL
                                                      target:self
                                                    selector:@selector(checkPipWindow)
                                                    userInfo:nil
                                                     repeats:YES];
        [RunLoop mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
        NSLog(@"%@:画中画弹幕监听已启动", nj_logPrefix);
    });
}

- (void)stopObserving {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timer invalidate];
        self.timer = nil;
        [self deactivatePipDanmaku];
        NSLog(@"%@:画中画弹幕监听已停止", nj_logPrefix);
    });
}

#pragma mark - PiP 窗口检测

/// 检查画中画窗口
- (void)checkPipWindow {
    UIWindow *pipWindow = [self findPipWindow];
    if (pipWindow) {
        self.pipWindow = pipWindow;
        if (self.isPipDanmakuActive) {
            [self updateDanmakuViewFrame];
        } else {
            [self activatePipDanmaku];
        }
    } else {
        if (self.isPipDanmakuActive) {
            [self deactivatePipDanmaku];
        }
        self.pipWindow = nil;
    }
}

/// 查找画中画窗口
- (UIWindow *)findPipWindow {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isHidden) {
            continue;
        }
        if (window.windowLevel != NJ_PIP_WINDOW_LEVEL) {
            continue;
        }
        if (CGRectIsEmpty(window.bounds)) {
            continue;
        }
        // 必须包含视频层，防止误判普通 alert 窗口
        if ([self videoLayerInLayer:window.layer]) {
            return window;
        }
    }
    return nil;
}

#pragma mark - 激活 / 恢复

/// 激活画中画弹幕
- (void)activatePipDanmaku {
    if (!NJ_MASTER_SWITCH_VALUE || !NJ_PIP_DANMAKU_VALUE) {
        return;
    }
    UIWindow *pipWindow = self.pipWindow;
    UIView *danmakuView = [self findDanmakuView];
    if (!pipWindow || !danmakuView) {
        return;
    }
    CALayer *videoLayer = [self videoLayerInLayer:pipWindow.layer];
    if (!videoLayer) {
        return;
    }
    // 记录弹幕视图当前状态
    self.context = [self contextForView:danmakuView];
    self.danmakuView = danmakuView;
    // 将弹幕视图移动到画中画窗口
    [danmakuView removeFromSuperview];
    [pipWindow addSubview:danmakuView];
    // 对齐画中画窗口内的视频区域
    CGRect videoFrame = [pipWindow.layer convertRect:videoLayer.frame fromLayer:videoLayer];
    danmakuView.frame = videoFrame;
    danmakuView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    danmakuView.backgroundColor = [UIColor clearColor];
    danmakuView.userInteractionEnabled = NO;
    [danmakuView setNeedsLayout];
    [danmakuView layoutSublayersIfNeeded];
    NSLog(@"%@:画中画弹幕已激活，弹幕视图 %@-%p", nj_logPrefix, NSStringFromClass([danmakuView class]), danmakuView);
}

/// 恢复画中画弹幕
- (void)deactivatePipDanmaku {
    UIView *danmakuView = self.danmakuView;
    if (!danmakuView) {
        return;
    }
    self.danmakuView = nil;
    [self restoreDanmakuView:danmakuView context:self.context];
    self.context = nil;
    NSLog(@"%@:画中画弹幕已恢复，弹幕视图 %@-%p", nj_logPrefix, NSStringFromClass([danmakuView class]), danmakuView);
}

/// 恢复弹幕视图到原位置
- (void)restoreDanmakuView:(UIView *)danmakuView context:(NJPipDanmakuContext *)context {
    UIView *parentView = context.parentView;
    if (parentView && parentView.window) {
        [danmakuView removeFromSuperview];
        NSInteger index = context.index;
        if (index < 0 || index > (NSInteger)parentView.subviews.count) {
            index = (NSInteger)parentView.subviews.count;
        }
        [parentView insertSubview:danmakuView atIndex:index];
    } else {
        // 原父视图已销毁，重新定位到视频视图的上级视图
        UIView *videoView = [self findVideoView];
        UIView *container = videoView.superview;
        if (container && container.window) {
            [danmakuView removeFromSuperview];
            [container insertSubview:danmakuView aboveSubview:videoView];
        } else {
            // 兜底：挂到主窗口，防止弹幕视图随画中画窗口销毁
            [danmakuView removeFromSuperview];
            [[self appMainWindow] addSubview:danmakuView];
            NSLog(@"%@:弹幕视图原父视图已销毁，临时挂到主窗口", nj_logPrefix);
        }
    }
    // 还原属性
    danmakuView.frame = context.frame;
    danmakuView.transform = context.transform;
    danmakuView.backgroundColor = context.backgroundColor;
    danmakuView.userInteractionEnabled = context.userInteractionEnabled;
    danmakuView.autoresizingMask = context.autoresizingMask;
    [danmakuView setNeedsLayout];
}

/// 记录视图当前状态
- (NJPipDanmakuContext *)contextForView:(UIView *)view {
    NJPipDanmakuContext *context = [NJPipDanmakuContext new];
    context.parentView = view.superview;
    context.index = (NSInteger)[view.superview.subviews indexOfObject:view];
    context.frame = view.frame;
    context.transform = view.transform;
    context.backgroundColor = view.backgroundColor;
    context.userInteractionEnabled = view.userInteractionEnabled;
    context.autoresizingMask = view.autoresizingMask;
    return context;
}

/// 更新弹幕视图在画中画窗口内对齐视频区域
- (void)updateDanmakuViewFrame {
    UIView *danmakuView = self.danmakuView;
    UIWindow *pipWindow = self.pipWindow;
    if (!danmakuView || !pipWindow || danmakuView.superview != pipWindow) {
        return;
    }
    CALayer *videoLayer = [self videoLayerInLayer:pipWindow.layer];
    if (!videoLayer) {
        return;
    }
    CGRect videoFrame = [pipWindow.layer convertRect:videoLayer.frame fromLayer:videoLayer];
    if (!CGRectIsEmpty(videoFrame)) {
        danmakuView.frame = videoFrame;
        [danmakuView layoutSublayersIfNeeded];
    }
}

#pragma mark - 查找弹幕视图

/// 查找弹幕视图
- (UIView *)findDanmakuView {
    UIView *matchedView = [self findDanmakuViewByClassName];
    if (matchedView) {
        return matchedView;
    }
    UIView *videoView = [self findVideoView];
    if (!videoView) {
        return nil;
    }
    return [self findDanmakuViewByVideoView:videoView];
}

/// 通过类名关键字查找弹幕视图
- (UIView *)findDanmakuViewByClassName {
    UIView *matchedView = nil;
    CGFloat matchedArea = -1;
    for (UIWindow *window in [self appWindowsExceptPipWindow]) {
        NSMutableArray<UIView *> *matchedViews = [NSMutableArray array];
        [self collectDanmakuViewsInView:window into:matchedViews];
        for (UIView *view in matchedViews) {
            CGFloat area = CGRectGetWidth(view.bounds) * CGRectGetHeight(view.bounds);
            if (area > matchedArea) {
                matchedArea = area;
                matchedView = view;
            }
        }
    }
    return matchedView;
}

/// 收集视图树内所有弹幕视图
- (void)collectDanmakuViewsInView:(UIView *)view into:(NSMutableArray<UIView *> *)views {
    if ([self isDanmakuView:view]) {
        [views addObject:view];
    }
    for (UIView *subview in view.subviews) {
        [self collectDanmakuViewsInView:subview into:views];
    }
}

/// 判断视图是否为弹幕视图
- (BOOL)isDanmakuView:(UIView *)view {
    NSString *className = NSStringFromClass([view class]).lowercaseString;
    for (NSString *keyword in NJ_PIP_DANMAKU_CLASS_NAME_KEYWORDS) {
        if ([className containsString:keyword]) {
            return YES;
        }
    }
    return NO;
}

/// 通过视频视图的同级视图查找弹幕视图（兜底策略）
- (UIView *)findDanmakuViewByVideoView:(UIView *)videoView {
    UIView *container = videoView.superview;
    if (!container) {
        return nil;
    }
    UIView *fallbackView = nil;
    for (UIView *sibling in container.subviews) {
        if (sibling == videoView || [self videoLayerInLayer:sibling.layer]) {
            continue;
        }
        if ([self siblingCoversVideoView:sibling videoView:videoView]) {
            if (fallbackView) {
                NSLog(@"%@:同层级存在多个覆盖视频区域的视图，无法确定弹幕视图", nj_logPrefix);
                return nil;
            }
            fallbackView = sibling;
        }
    }
    if (fallbackView) {
        NSLog(@"%@:兜底策略定位到弹幕视图 %@-%p", nj_logPrefix, NSStringFromClass([fallbackView class]), fallbackView);
    }
    return fallbackView;
}

/// 判断同级视图是否覆盖视频视图区域
- (BOOL)siblingCoversVideoView:(UIView *)sibling videoView:(UIView *)videoView {
    CGRect siblingFrame = [sibling convertRect:sibling.bounds toView:videoView.superview];
    CGRect videoFrame = [videoView convertRect:videoView.bounds toView:videoView.superview];
    return CGRectIntersectsRect(siblingFrame, videoFrame);
}

#pragma mark - 查找视频视图 / 视频层

/// 查找包含视频层的视图（所有窗口）
- (UIView *)findVideoView {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        UIView *matchedView = [self findViewInView:window predicate:^BOOL(UIView *subview) {
            return [self videoLayerInLayer:subview.layer] != nil;
        }];
        if (matchedView) {
            return [self innermostVideoView:matchedView];
        }
    }
    return nil;
}

/// BFS 查找第一个满足条件的视图
- (UIView *)findViewInView:(UIView *)rootView predicate:(BOOL (^)(UIView *view))predicate {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:rootView];
    NSUInteger index = 0;
    while (index < queue.count) {
        UIView *current = queue[index];
        index += 1;
        if (predicate(current)) {
            return current;
        }
        [queue addObjectsFromArray:current.subviews];
    }
    return nil;
}

/// 下钻到包含视频层的最内层视图
- (UIView *)innermostVideoView:(UIView *)view {
    UIView *current = view;
    while (YES) {
        UIView *matched = [self findViewInView:current predicate:^BOOL(UIView *subview) {
            return [self videoLayerInLayer:subview.layer] != nil;
        }];
        if (matched) {
            current = matched;
        } else {
            break;
        }
    }
    return current;
}

/// 在图层树内查找视频层
- (CALayer *)videoLayerInLayer:(CALayer *)layer {
    if ([self isVideoLayer:layer]) {
        return layer;
    }
    NSArray<CALayer *> *sublayers = [layer.sublayers copy];
    for (CALayer *sublayer in sublayers) {
        CALayer *matched = [self videoLayerInLayer:sublayer];
        if (matched) {
            return matched;
        }
    }
    return nil;
}

/// 判断图层是否为视频层
- (BOOL)isVideoLayer:(CALayer *)layer {
    if ([layer isKindOfClass:AVPlayerLayer.class] || [layer isKindOfClass:AVSampleBufferDisplayLayer.class]) {
        return YES;
    }
    return NO;
}

#pragma mark - 窗口工具

/// 除画中画窗口外的所有窗口
- (NSArray<UIWindow *> *)appWindowsExceptPipWindow {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window != self.pipWindow && window.windowLevel != NJ_PIP_WINDOW_LEVEL) {
            [windows addObject:window];
        }
    }
    return windows;
}

/// 主窗口
- (UIWindow *)appMainWindow {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window != self.pipWindow && window.windowLevel != NJ_PIP_WINDOW_LEVEL && !window.isHidden) {
            return window;
        }
    }
    return [UIApplication sharedApplication].windows.lastObject;
}

@end
