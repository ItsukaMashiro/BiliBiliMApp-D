//
//  NJDetailPlayerAd.xm
//  BiliBiliTweak
//
//  Created by touchWorld on 2025/9/10.
//

// 详情页播放器广告

/*
 BBPlayerWidget // 所有组件都继承BBPlayerWidget
    BBPlayerWidget *superWidget;    // 父组件
    NSArray *subWidgets;            // 子组件
    - (void)willLayoutSubWidgets;   // 即将布局子组件
    - (void)didLayoutSubWidgets;    // 已经布局子组件
 
 
 BBPlayerContext    // 上下文
    BBPlayerControlWidgetService *controlWidgetService; // 控制组建服务
        Class rootWidgetClass; // 根组件类型：BBPlayerControlContainerRootWidget
   
 */

/*
 **************** 半屏-横屏视频 ****************
 
 BBPlayerControlContainerRootWidget //  控制根组件
    BBPlayerWidget *_leftBarWidget;    // 左边条组件：BBPlayerFullScreenLeftWidget
    BBPlayerBeyondBoundsWidget *_btmBarWidget;  // 底部条组件
    - (void)_setupSubWidgets;  // 设置子组件
 
 
 BBPlayerBeyondBoundsWidget // 底部条组件
    NSArray *subWidgets;    // 拥有的子组件
        BBPlayerHalfScreenBottomWidget // 半屏底部组件
 
 **************** 半屏底部组件 ****************
 
 BBPlayerHalfScreenBottomWidget // 半屏底部组件
    BBPlayerFlexContainerWidget *_leftControlWidget;    // 左边控制组件
        NSArray *subWidgets // 拥有的子组件
            BBPlayerPlayAndPauseWidget      // 播放和暂停
            BBPlayerSeekbarWidgetV2         // 时间滑动条
            BBPlayerTimeHintLabelWidget     // 时间提示标签
    BBPlayerFlexContainerWidget *_rightControlWidget;   // 右边控制组件
        NSArray *subWidgets // 拥有的子组件
            BBPlayerSwitchScreenWidget      //  全屏按钮
            BBPlayerBizGotoStoryWidget      //  横屏视频的竖屏全屏按钮
            BBPlayerGotoStoryWidget         //  横屏视频的竖屏全屏按钮(8.76.0)
 
 BBPlayerOperationTagWidget
    NSArray *_tagModels;
        BBPlayerCoreOperationTagModel
 
 BBPlayerCoreOperationTagModel
    @property (nonatomic) unsigned long long type;
        type:1      // UP主都在用的宝藏功能
        type:7      // 使用的BGM
 
 **************** 半屏底部组件 ****************
 
 */
/*
 **************** 全屏-横屏视频 ****************
 
 BBPlayerControlContainerRootWidget //  控制根组件
    BBPlayerWidget *_leftBarWidget;    // 左边条组件：BBPlayerFullScreenLeftWidget
    BBPlayerBeyondBoundsWidget *_btmBarWidget;  // 底部条组件
    - (void)_setupSubWidgets;  // 设置子组件
 
 **************** 全屏左边组件 ****************
 
 BBPlayerFullScreenLeftWidget   // 全屏左边组件（横屏）
    BBPlayerFlexContainerWidget *_topControlWidget  // 头部控制组件
        NSArray *subWidgets // 拥有的子组件
            BBPlayerOnlineCounterWidget     // 在线人数
            BBPlayerUpTagWidget             // up主头像
            BBPlayerOperationTagWidget      // 运营标签
 
    BBPlayerFlexContainerWidget *_bottomControlWidget;  // 底部控制组件
        NSArray *subWidgets // 拥有的子组件
            BBPlayerTimeWidget  // 时间组件, 00:00/37:30
 
 **************** 全屏左边组 ****************
 
 **************** 全屏底部组件 ****************
 
 BBPlayerBeyondBoundsWidget // 底部条组件
    NSArray *subWidgets;    // 拥有的子组件
        // 头部
        BBPlayerSeekbarWidgetV2 // 滑动条组件
        // 左边
        BBPlayerPlayAndPauseWidget              // 播放和暂停按钮组件
        BBPlayerFullScreenNextEpisodeWidget     // 全屏下一集组件
        BBPlayerDanmakuSwitchWidget             // 弹幕开关组件
        BBPlayerDanmakuSettingEntranceWidget    // 弹幕设置入口组件
        BBPlayerDanmakuEntranceWidget           // 发送弹幕组件
        // 右边
        BBPlayerVideoQualityWidget                      // 视频质量组件
        BBPlayerLossLessBtnWidget                       // 无损按钮组件
        BBPlayerDolbyBtnWidget                          // 杜比按钮组件
        BBPlayerPlaybackRateWidget                      // 播放速度组件
        BBPlayerFullScreenEpisodeBtnWidget              // 全屏剧集按钮组件
        BBPlayerCaptionWidget                           // 字幕组件
        BBPlayerAIAudioBtnWidget                        // 人工智能音频按钮组件
        BBPlayerInteractiveStoryListEntranceWidget      // 互动故事列表入口组件
 
 **************** 全屏底部组件 ****************
 */
/*
 **************** 半屏-竖屏视频 ****************
 
 */
/*
 **************** 全屏-竖屏视频 ****************
 
 */

/*
 当前播放速度可以从 BBPlayerObject => BBPlayerContext => BBPlayerPlayback => playbackRate
 */

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <objc/runtime.h>
#import "NJCommonDefine.h"

// MARK: - Picture in Picture danmaku

static const void *NJPiPDanmakuStateKey = &NJPiPDanmakuStateKey;
static NSHashTable<UIView *> *NJPiPDanmakuViews(void) {
    static NSHashTable<UIView *> *views;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        views = [NSHashTable weakObjectsHashTable];
    });
    return views;
}

static BOOL NJPiPDanmakuEnabled(void) {
    return NJ_MASTER_SWITCH_VALUE && NJ_PIP_DANMAKU_VALUE;
}

static void NJRegisterPiPDanmakuView(id view) {
    if (![view isKindOfClass:UIView.class]) {
        return;
    }
    BOOL isNewView = NO;
    @synchronized (NJPiPDanmakuViews()) {
        if (![NJPiPDanmakuViews() containsObject:view]) {
            [NJPiPDanmakuViews() addObject:view];
            isNewView = YES;
        }
    }
    if (isNewView) {
        NSLog(@"[NJPiPDanmaku] registered %@ (%p)", NSStringFromClass([view class]), view);
    }
}

static UIView *NJFindViewWithBackingLayer(UIView *view, CALayer *layer) {
    if (view.layer == layer) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *result = NJFindViewWithBackingLayer(subview, layer);
        if (result) {
            return result;
        }
    }
    return nil;
}

static UIView *NJViewWithBackingLayer(CALayer *layer) {
    id delegate = layer.delegate;
    if ([delegate isKindOfClass:UIView.class] && [(UIView *)delegate layer] == layer) {
        return delegate;
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        UIView *result = NJFindViewWithBackingLayer(window, layer);
        if (result) {
            return result;
        }
    }
    return nil;
}

static UIView *NJSourceViewForLayer(CALayer *layer) {
    UIView *backingView = NJViewWithBackingLayer(layer);
    if (backingView) {
        return backingView;
    }
    id delegate = layer.delegate;
    if ([delegate isKindOfClass:UIView.class]) {
        return delegate;
    }
    CALayer *candidate = layer.superlayer;
    while (candidate) {
        id candidateDelegate = candidate.delegate;
        if ([candidateDelegate isKindOfClass:UIView.class]) {
            return candidateDelegate;
        }
        candidate = candidate.superlayer;
    }
    return nil;
}

static CGFloat NJIntersectionArea(CGRect first, CGRect second) {
    CGRect intersection = CGRectIntersection(first, second);
    if (CGRectIsNull(intersection) || CGRectIsEmpty(intersection)) {
        return 0;
    }
    return CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
}

static UIView *NJFindPiPDanmakuView(UIView *sourceView) {
    if (!sourceView.window) {
        return nil;
    }
    CGRect sourceRect = [sourceView convertRect:sourceView.bounds toView:sourceView.window];
    UIView *bestView = nil;
    CGFloat bestScore = 0;
    NSArray<UIView *> *views;
    @synchronized (NJPiPDanmakuViews()) {
        views = NJPiPDanmakuViews().allObjects;
    }
    for (UIView *view in views) {
        if (!view.window || view.window != sourceView.window || view.hidden || view.alpha < 0.01) {
            continue;
        }
        CGRect viewRect = [view convertRect:view.bounds toView:view.window];
        CGFloat score = NJIntersectionArea(sourceRect, viewRect);
        if ([NSStringFromClass(view.class) containsString:@"DanmakuVoutView"]) {
            score *= 1.25;
        }
        if (score > bestScore) {
            bestScore = score;
            bestView = view;
        }
    }
    return bestScore > 1 ? bestView : nil;
}

static NSArray<NSLayoutConstraint *> *NJConstraintsForView(UIView *view, UIView *superview) {
    if (!view || !superview) {
        return @[];
    }
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in superview.constraints) {
        if (constraint.firstItem == view || constraint.secondItem == view) {
            [constraints addObject:constraint];
        }
    }
    return constraints.copy;
}

@interface NJPiPDanmakuHostView : UIView
@property (nonatomic, strong, nullable) UIView *videoView;
@property (nonatomic, strong, nullable) CALayer *videoLayer;
@property (nonatomic, strong, nullable) UIView *danmakuView;
@end

@implementation NJPiPDanmakuHostView

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (self.videoView.superview == self) {
        self.videoView.frame = self.bounds;
    }
    if (self.videoLayer.superlayer == self.layer) {
        self.videoLayer.frame = self.bounds;
    }
    if (self.danmakuView.superview == self) {
        self.danmakuView.frame = self.bounds;
    }
    [CATransaction commit];
}

@end

@interface NJPiPDanmakuContentViewController : AVPictureInPictureVideoCallViewController
@property (nonatomic, strong, readonly) NJPiPDanmakuHostView *hostView;
@end

@implementation NJPiPDanmakuContentViewController

- (void)loadView {
    NJPiPDanmakuHostView *hostView = [[NJPiPDanmakuHostView alloc] initWithFrame:CGRectMake(0, 0, 640, 360)];
    hostView.backgroundColor = UIColor.blackColor;
    hostView.clipsToBounds = YES;
    self.view = hostView;
}

- (NJPiPDanmakuHostView *)hostView {
    return (NJPiPDanmakuHostView *)self.view;
}

@end


@class NJPiPDanmakuDelegateProxy;

@interface NJPiPDanmakuState : NSObject
@property (nonatomic, weak) AVPictureInPictureController *controller;
@property (nonatomic, strong) CALayer *videoLayer;
@property (nonatomic, strong, nullable) UIView *videoView;
@property (nonatomic, strong) UIView *sourceView;
@property (nonatomic, strong, nullable) UIView *placeholderView;
@property (nonatomic, strong, nullable) UIView *danmakuView;
@property (nonatomic, strong) NJPiPDanmakuContentViewController *contentViewController;
@property (nonatomic, strong) NJPiPDanmakuDelegateProxy *delegateProxy;
@property (nonatomic, weak, nullable) UIView *videoOriginalSuperview;
@property (nonatomic, weak, nullable) CALayer *videoOriginalSuperlayer;
@property (nonatomic, assign) NSUInteger videoOriginalIndex;
@property (nonatomic, assign) CGRect videoOriginalFrame;
@property (nonatomic, assign) BOOL videoTranslatesAutoresizingMaskIntoConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *videoConstraints;
@property (nonatomic, weak, nullable) UIView *danmakuOriginalSuperview;
@property (nonatomic, assign) NSUInteger danmakuOriginalIndex;
@property (nonatomic, assign) CGRect danmakuOriginalFrame;
@property (nonatomic, assign) BOOL danmakuTranslatesAutoresizingMaskIntoConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *danmakuConstraints;
@property (nonatomic, assign, getter=isPresenting) BOOL presenting;
- (void)moveContentIntoPictureInPicture;
- (void)restoreContent;
@end

@interface NJPiPDanmakuDelegateProxy : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, weak) id<AVPictureInPictureControllerDelegate> downstream;
@property (nonatomic, weak) NJPiPDanmakuState *state;
@end

@implementation NJPiPDanmakuState

- (void)moveContentIntoPictureInPicture {
    if (self.isPresenting) {
        return;
    }
    self.presenting = YES;
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;

    UIView *latestDanmakuView = NJFindPiPDanmakuView(self.sourceView);
    if (latestDanmakuView) {
        self.danmakuView = latestDanmakuView;
    }
    NSLog(@"[NJPiPDanmaku] will start, source=%@ video=%@ danmaku=%@",
          NSStringFromClass(self.sourceView.class),
          NSStringFromClass(self.videoView.class),
          NSStringFromClass(self.danmakuView.class));

    if (self.videoView && self.videoView.superview) {
        self.videoOriginalSuperview = self.videoView.superview;
        self.videoOriginalIndex = [self.videoOriginalSuperview.subviews indexOfObject:self.videoView];
        self.videoOriginalFrame = self.videoView.frame;
        self.videoTranslatesAutoresizingMaskIntoConstraints = self.videoView.translatesAutoresizingMaskIntoConstraints;
        self.videoConstraints = NJConstraintsForView(self.videoView, self.videoOriginalSuperview);
        [NSLayoutConstraint deactivateConstraints:self.videoConstraints];
        [self.videoView removeFromSuperview];
        self.videoView.translatesAutoresizingMaskIntoConstraints = YES;
        [hostView insertSubview:self.videoView atIndex:0];
        hostView.videoView = self.videoView;
    } else if (self.videoLayer.superlayer) {
        self.videoOriginalSuperlayer = self.videoLayer.superlayer;
        self.videoOriginalIndex = [self.videoOriginalSuperlayer.sublayers indexOfObject:self.videoLayer];
        self.videoOriginalFrame = self.videoLayer.frame;
        [self.videoLayer removeFromSuperlayer];
        [hostView.layer insertSublayer:self.videoLayer atIndex:0];
        hostView.videoLayer = self.videoLayer;
    }

    BOOL danmakuMovesWithVideo = self.videoView && [self.danmakuView isDescendantOfView:self.videoView];
    if (self.danmakuView && !danmakuMovesWithVideo && self.danmakuView.superview) {
        self.danmakuOriginalSuperview = self.danmakuView.superview;
        self.danmakuOriginalIndex = [self.danmakuOriginalSuperview.subviews indexOfObject:self.danmakuView];
        self.danmakuOriginalFrame = self.danmakuView.frame;
        self.danmakuTranslatesAutoresizingMaskIntoConstraints = self.danmakuView.translatesAutoresizingMaskIntoConstraints;
        self.danmakuConstraints = NJConstraintsForView(self.danmakuView, self.danmakuOriginalSuperview);
        [NSLayoutConstraint deactivateConstraints:self.danmakuConstraints];
        [self.danmakuView removeFromSuperview];
        self.danmakuView.translatesAutoresizingMaskIntoConstraints = YES;
        [hostView addSubview:self.danmakuView];
        hostView.danmakuView = self.danmakuView;
    }
    [hostView setNeedsLayout];
    [hostView layoutIfNeeded];
}

- (void)restoreContent {
    if (!self.isPresenting) {
        [self.placeholderView removeFromSuperview];
        self.placeholderView = nil;
        return;
    }
    self.presenting = NO;
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;

    if (self.videoView && self.videoOriginalSuperview) {
        [self.videoView removeFromSuperview];
        NSUInteger index = MIN(self.videoOriginalIndex, self.videoOriginalSuperview.subviews.count);
        [self.videoOriginalSuperview insertSubview:self.videoView atIndex:index];
        self.videoView.translatesAutoresizingMaskIntoConstraints = self.videoTranslatesAutoresizingMaskIntoConstraints;
        self.videoView.frame = self.videoOriginalFrame;
        [NSLayoutConstraint activateConstraints:self.videoConstraints];
    } else if (self.videoOriginalSuperlayer) {
        [self.videoLayer removeFromSuperlayer];
        unsigned int index = (unsigned int)MIN(self.videoOriginalIndex, self.videoOriginalSuperlayer.sublayers.count);
        [self.videoOriginalSuperlayer insertSublayer:self.videoLayer atIndex:index];
        self.videoLayer.frame = self.videoOriginalFrame;
    }

    if (self.danmakuView && self.danmakuOriginalSuperview) {
        [self.danmakuView removeFromSuperview];
        NSUInteger index = MIN(self.danmakuOriginalIndex, self.danmakuOriginalSuperview.subviews.count);
        [self.danmakuOriginalSuperview insertSubview:self.danmakuView atIndex:index];
        self.danmakuView.translatesAutoresizingMaskIntoConstraints = self.danmakuTranslatesAutoresizingMaskIntoConstraints;
        self.danmakuView.frame = self.danmakuOriginalFrame;
        [NSLayoutConstraint activateConstraints:self.danmakuConstraints];
    }

    hostView.videoView = nil;
    hostView.videoLayer = nil;
    hostView.danmakuView = nil;
    [self.placeholderView removeFromSuperview];
    self.placeholderView = nil;
    [self.videoOriginalSuperview setNeedsLayout];
    [self.danmakuOriginalSuperview setNeedsLayout];
}

@end

@implementation NJPiPDanmakuDelegateProxy

- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [self.downstream respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    if ([self.downstream respondsToSelector:selector]) {
        return self.downstream;
    }
    return [super forwardingTargetForSelector:selector];
}

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)controller {
    [self.state moveContentIntoPictureInPicture];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerWillStartPictureInPicture:controller];
    }
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)controller {
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStartPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 failedToStartPictureInPictureWithError:(NSError *)error {
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureController:controller failedToStartPictureInPictureWithError:error];
    }
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)controller {
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerWillStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureController:controller
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:completionHandler];
    } else {
        completionHandler(YES);
    }
}

@end

static NJPiPDanmakuState *NJMakePiPDanmakuState(CALayer *videoLayer) API_AVAILABLE(ios(15.0)) {
    if (!NJPiPDanmakuEnabled() || !videoLayer) {
        return nil;
    }
    UIView *videoView = NJViewWithBackingLayer(videoLayer);
    UIView *sourceView = videoView ?: NJSourceViewForLayer(videoLayer);
    if (!sourceView) {
        return nil;
    }
    UIView *danmakuView = NJFindPiPDanmakuView(sourceView);

    NJPiPDanmakuState *state = [[NJPiPDanmakuState alloc] init];
    state.videoLayer = videoLayer;
    state.videoView = videoView;
    state.danmakuView = danmakuView;
    state.contentViewController = [[NJPiPDanmakuContentViewController alloc] init];
    CGSize contentSize = videoLayer.bounds.size;
    if (contentSize.width < 1 || contentSize.height < 1) {
        contentSize = CGSizeMake(640, 360);
    }
    state.contentViewController.preferredContentSize = contentSize;

    if (videoView.superview) {
        UIView *placeholder = [[UIView alloc] initWithFrame:videoView.frame];
        placeholder.backgroundColor = UIColor.clearColor;
        placeholder.userInteractionEnabled = NO;
        placeholder.autoresizingMask = videoView.autoresizingMask;
        NSUInteger index = [videoView.superview.subviews indexOfObject:videoView];
        [videoView.superview insertSubview:placeholder atIndex:index];
        state.placeholderView = placeholder;
        state.sourceView = placeholder;
    } else {
        state.sourceView = sourceView;
    }
    state.delegateProxy = [[NJPiPDanmakuDelegateProxy alloc] init];
    state.delegateProxy.state = state;
    NSLog(@"[NJPiPDanmaku] prepared controller, source=%@ video=%@ initialDanmaku=%@ window=%@",
          NSStringFromClass(sourceView.class),
          NSStringFromClass(videoView.class),
          NSStringFromClass(danmakuView.class),
          sourceView.window);
    return state;
}

%group App

static BOOL NJPiPDanmakuCreatingController = NO;

@interface BBPlayerDanmakuService : NSObject
- (UIView *)view;
@end

%hook BBPlayerDanmakuService

- (UIView *)view {
    UIView *view = %orig;
    NJRegisterPiPDanmakuView(view);
    return view;
}

%end

@interface BBPlayerDanmakuVoutView : UIView
@end

%hook BBPlayerDanmakuVoutView

- (void)didMoveToWindow {
    %orig;
    NJRegisterPiPDanmakuView(self);
}

%end

%hook AVPictureInPictureController

- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer {
    if (@available(iOS 15.0, *)) {
        if (!NJPiPDanmakuCreatingController) {
            NJPiPDanmakuState *state = NJMakePiPDanmakuState(playerLayer);
            if (state) {
                AVPictureInPictureControllerContentSource *source =
                    [[AVPictureInPictureControllerContentSource alloc]
                     initWithActiveVideoCallSourceView:state.sourceView
                     contentViewController:state.contentViewController];
                NJPiPDanmakuCreatingController = YES;
                AVPictureInPictureController *controller = [self initWithContentSource:source];
                NJPiPDanmakuCreatingController = NO;
                if (controller) {
                    state.controller = controller;
                    objc_setAssociatedObject(controller,
                                             NJPiPDanmakuStateKey,
                                             state,
                                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    controller.delegate = state.delegateProxy;
                    return controller;
                }
                [state restoreContent];
            }
        }
    }
    return %orig;
}

- (instancetype)initWithContentSource:(AVPictureInPictureControllerContentSource *)contentSource {
    if (@available(iOS 15.0, *)) {
        if (!NJPiPDanmakuCreatingController) {
            CALayer *videoLayer = contentSource.playerLayer ?: contentSource.sampleBufferDisplayLayer;
            NJPiPDanmakuState *state = NJMakePiPDanmakuState(videoLayer);
            if (state) {
                AVPictureInPictureControllerContentSource *source =
                    [[AVPictureInPictureControllerContentSource alloc]
                     initWithActiveVideoCallSourceView:state.sourceView
                     contentViewController:state.contentViewController];
                NJPiPDanmakuCreatingController = YES;
                AVPictureInPictureController *controller = [self initWithContentSource:source];
                NJPiPDanmakuCreatingController = NO;
                if (controller) {
                    state.controller = controller;
                    objc_setAssociatedObject(controller,
                                             NJPiPDanmakuStateKey,
                                             state,
                                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    controller.delegate = state.delegateProxy;
                    return controller;
                }
                [state restoreContent];
            }
        }
    }
    return %orig;
}

- (void)setDelegate:(id<AVPictureInPictureControllerDelegate>)delegate {
    NJPiPDanmakuState *state = objc_getAssociatedObject(self, NJPiPDanmakuStateKey);
    if (state && delegate != state.delegateProxy) {
        state.delegateProxy.downstream = delegate;
        %orig(state.delegateProxy);
        return;
    }
    %orig;
}

- (id<AVPictureInPictureControllerDelegate>)delegate {
    id<AVPictureInPictureControllerDelegate> delegate = %orig;
    NJPiPDanmakuState *state = objc_getAssociatedObject(self, NJPiPDanmakuStateKey);
    if (state && delegate == state.delegateProxy && state.delegateProxy.downstream) {
        return state.delegateProxy.downstream;
    }
    return delegate;
}

- (void)dealloc {
    NJPiPDanmakuState *state = objc_getAssociatedObject(self, NJPiPDanmakuStateKey);
    [state restoreContent];
    objc_setAssociatedObject(self, NJPiPDanmakuStateKey, nil, OBJC_ASSOCIATION_ASSIGN);
    %orig;
}

%end

@interface BBPlayerWidget : NSObject

@property (readonly, weak, nonatomic) BBPlayerWidget *superWidget;
@property (readonly, copy, nonatomic) NSArray *subWidgets;

@end

@interface BBPlayerUpTagWidget : NSObject

@end

// 全屏播放时的up主头像（经常误触点了关注😮‍💨）
%hook BBPlayerUpTagWidget

- (id)initWithContext:(id)context {
    return nil;
}

%end

@interface BBPlayerPortraitScreenBottomWidget : NSObject

// 全屏播放时的up主头像
- (id)upTagWidget;
// UP主都在用的宝藏功能
- (id)operationTagWidget;

@end

%hook BBPlayerPortraitScreenBottomWidget

// 处理_upTagWidget为nil时的奔溃问题；_secondControlWidget包含_upTagWidget。
- (void)setupFirstControlConstraints {
    BBPlayerWidget *upTagWidget = [self upTagWidget];
    if (upTagWidget) {
        %orig;
    }
}

// 处理_operationTagWidget为nil时的奔溃问题；_firstControlWidget包含_operationTagWidget。
- (void)setupSecondControlConstraints {
    BBPlayerWidget *operationTagWidget = [self operationTagWidget];
    if (operationTagWidget) {
        %orig;
    }
}


%end

// 横屏视频的竖屏全屏按钮
%hook BBPlayerBizGotoStoryWidget

- (id)initWithContext:(id)context {
    if (NJ_VERTICAL_SCREEN_MODE_VALUE) {
        return %orig;
    }
    return nil;
}

%end

// 横屏视频的竖屏全屏按钮(8.76.0)
%hook BBPlayerGotoStoryWidget

- (id)initWithContext:(id)context flexConfiguration:(id)configuration {
    if (NJ_VERTICAL_SCREEN_MODE_VALUE) {
        return %orig;
    }
    return nil;
}

%end

@interface BBPlayerCoreOperationTagModel : NSObject

@property (nonatomic) unsigned long long type;

@end


@interface BBPlayerOperationTagService : NSObject

@property (retain, nonatomic) NSArray *tagModels;
// 过滤类型
- (NSSet<NSNumber *> *)nj_filterTypes;

@end

%hook BBPlayerOperationTagService

- (NSArray *)tagModels {
    NSArray *origTagModels = %orig;
    NSMutableArray *items = [NSMutableArray array];
    for (BBPlayerCoreOperationTagModel *item in origTagModels) {
        if ([[self nj_filterTypes] containsObject:@(item.type)]) {
            continue;
        }
        [items addObject:item];
    }
    // 保存过滤后的数据
    [self setValue:items forKeyPath:@"_tagModels"];
    return items;
}

%new
- (NSSet<NSNumber *> *)nj_filterTypes {
    NSSet *filterSet = objc_getAssociatedObject(self, @selector(nj_filterTypes));
    if (!filterSet) {
        NSArray *types = @[
            @(1),      // UP主都在用的宝藏功能
        ];
        filterSet = [NSSet setWithArray:types];
        objc_setAssociatedObject(self, @selector(nj_filterTypes), filterSet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return filterSet;
}

%end

@interface BBPlayerFlexContainerWidget : BBPlayerWidget

@end

%hook BBPlayerFlexContainerWidget

- (void)didLayoutSubWidgets {
//    NSLog(@"%@:%@-%p-%s-subWidgets:%@", nj_logPrefix, NSStringFromClass([(id)self class]), self, __FUNCTION__, [self subWidgets]);
    %orig;
}

%end


// 移除投票/点赞+投币+收藏+关注/推荐视频/评分
@interface BAPICommunityServiceDmV1Command : NSObject

/// 弹幕命令，比如投票弹幕、关注弹幕
@property (retain, nonatomic) NSMutableArray *commandDmsArray;

@end

%hook BAPICommunityServiceDmV1Command

%end

/// 请求弹幕数据
@interface BAPICommunityServiceDmV1DmViewReply : NSObject

@property (retain, nonatomic) BAPICommunityServiceDmV1Command *command;
/// 活动，比如云视听小电视
@property (retain, nonatomic) NSMutableArray *activityMetaArray;

@end

%hook BAPICommunityServiceDmV1DmViewReply

- (id)initWithData:(id)data extensionRegistry:(id)registry error:(id *)error {
    BAPICommunityServiceDmV1DmViewReply *ret = %orig;
    // 移除所有弹幕命令，比如投票弹幕、关注弹幕
    [ret.command.commandDmsArray removeAllObjects];
    // 移除所有活动，比如云视听小电视
    [ret.activityMetaArray removeAllObjects];
    return ret;
}

%end

@interface BAPIAppViewuniteV1DmResource : NSObject

@property (retain, nonatomic) NSMutableArray *commandDmsArray;
/// 卡片，比如一键追番
@property (retain, nonatomic) NSMutableArray *cardsArray;

@end

@interface BAPIAppViewuniteV1ViewProgressReply : NSObject

@property (retain, nonatomic) BAPIAppViewuniteV1DmResource *dm;

@end

%hook BAPIAppViewuniteV1ViewProgressReply

- (id)initWithData:(id)data extensionRegistry:(id)registry error:(id *)error {
    BAPIAppViewuniteV1ViewProgressReply *ret = %orig;
    // 移除所有卡片，比如一键追番
    [ret.dm.cardsArray removeAllObjects];
    return ret;
}

%end
 
%end

%ctor {
    if (NJ_MASTER_SWITCH_VALUE) {
        %init(App);
    }
}
