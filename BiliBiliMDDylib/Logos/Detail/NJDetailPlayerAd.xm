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
#import <os/log.h>
#import "NJCommonDefine.h"

// MARK: - Picture in Picture danmaku

static const void *NJPiPDanmakuStateKey = &NJPiPDanmakuStateKey;
static os_log_t NJPiPDanmakuLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.njbilibili.pip", "danmaku");
    });
    return log;
}

static const char *NJPiPClassName(id object) {
    return object ? NSStringFromClass([object class]).UTF8String : "(nil)";
}

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

// Keep only a weak reference: the player owns this view.  This gives the PiP
// controller a stable foreground reference without retaining an old player
// hierarchy after the user changes videos.
static __weak UIView *NJPiPLastAttachedDanmakuView;
static void NJPrewarmTrackedPiPControllersWithSourceView(UIView *sourceView);

static void NJRememberAttachedPiPDanmakuView(UIView *view) {
    if (view.window && !view.hidden && view.alpha >= 0.01 && !CGRectIsEmpty(view.bounds)) {
        NJPiPLastAttachedDanmakuView = view;
    }
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
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                         "[NJPiPDanmaku] registered class=%{public}s view=%p",
                         NJPiPClassName(view), view);
    }
    UIView *danmakuView = (UIView *)view;
    if (danmakuView.window) {
        NJRememberAttachedPiPDanmakuView(danmakuView);
        NJPrewarmTrackedPiPControllersWithSourceView(danmakuView);
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

static BOOL NJIsPiPDanmakuRenderingView(UIView *view) {
    for (Class candidate = view.class; candidate && candidate != UIView.class; candidate = class_getSuperclass(candidate)) {
        NSString *name = NSStringFromClass(candidate).lowercaseString;
        if ([name containsString:@"danmakuvout"] ||
            [name containsString:@"danmuvout"] ||
            [name containsString:@"danmakurender"] ||
            [name containsString:@"danmurender"]) {
            return YES;
        }
    }
    return NO;
}

static void NJCollectPiPDanmakuRenderingViews(UIView *rootView, NSMutableArray<UIView *> *result) {
    if (NJIsPiPDanmakuRenderingView(rootView)) {
        [result addObject:rootView];
    }
    for (UIView *subview in rootView.subviews) {
        NJCollectPiPDanmakuRenderingViews(subview, result);
    }
}

static UIView *NJFindPiPDanmakuView(UIView *sourceView) {
    if (!sourceView.window) {
        return nil;
    }
    CGRect sourceRect = [sourceView convertRect:sourceView.bounds toView:sourceView.window];
    UIView *bestView = nil;
    UIView *bestVoutView = nil;
    CGFloat bestScore = 0;
    CGFloat bestVoutScore = 0;
    NSMutableOrderedSet<UIView *> *candidateViews = [NSMutableOrderedSet orderedSet];
    @synchronized (NJPiPDanmakuViews()) {
        [candidateViews addObjectsFromArray:NJPiPDanmakuViews().allObjects];
    }
    // Logos hooks may be initialized before Bilibili registers a late-loaded class.
    // Resolve the actual rendering view from the live hierarchy at PiP presentation
    // time as a fallback. This walk only runs at PiP start, not once per frame.
    NSMutableArray<UIView *> *hierarchyViews = [NSMutableArray array];
    NJCollectPiPDanmakuRenderingViews(sourceView.window, hierarchyViews);
    [candidateViews addObjectsFromArray:hierarchyViews];

    for (UIView *view in candidateViews) {
        if (!view.window || view.window != sourceView.window || view.hidden || view.alpha < 0.01) {
            continue;
        }
        CGRect viewRect = [view convertRect:view.bounds toView:view.window];
        CGFloat score = NJIntersectionArea(sourceRect, viewRect);
        if (NJIsPiPDanmakuRenderingView(view)) {
            if (score > bestVoutScore) {
                bestVoutScore = score;
                bestVoutView = view;
            }
        }
        if (score > bestScore) {
            bestScore = score;
            bestView = view;
        }
    }
    if (bestVoutScore > 1) {
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                         "[NJPiPDanmaku] selected live danmaku class=%{public}s view=%p overlap=%.1f",
                         NJPiPClassName(bestVoutView), bestVoutView, bestVoutScore);
        return bestVoutView;
    }
    return bestScore > 1 ? bestView : nil;
}

static UIView *NJFindVisiblePiPDanmakuView(void) {
    NSMutableOrderedSet<UIView *> *candidateViews = [NSMutableOrderedSet orderedSet];
    @synchronized (NJPiPDanmakuViews()) {
        [candidateViews addObjectsFromArray:NJPiPDanmakuViews().allObjects];
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        NSMutableArray<UIView *> *hierarchyViews = [NSMutableArray array];
        NJCollectPiPDanmakuRenderingViews(window, hierarchyViews);
        [candidateViews addObjectsFromArray:hierarchyViews];
    }

    UIView *bestView = nil;
    UIView *bestVoutView = nil;
    CGFloat bestScore = 0;
    CGFloat bestVoutScore = 0;
    for (UIView *view in candidateViews) {
        UIWindow *window = view.window;
        if (!window || window.hidden || view.hidden || view.alpha < 0.01 ||
            CGRectIsEmpty(view.bounds)) {
            continue;
        }
        CGRect viewRect = [view convertRect:view.bounds toView:window];
        CGFloat score = NJIntersectionArea(viewRect, window.bounds);
        if (score <= 1) {
            continue;
        }
        if (NJIsPiPDanmakuRenderingView(view) && score > bestVoutScore) {
            bestVoutScore = score;
            bestVoutView = view;
        }
        if (score > bestScore) {
            bestScore = score;
            bestView = view;
        }
    }

    UIView *selectedView = bestVoutView ?: bestView;
    if (selectedView) {
        CGRect frame = [selectedView convertRect:selectedView.bounds
                                           toView:selectedView.window];
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                         "[NJPiPDanmaku] selected application danmaku class=%{public}s view=%p window=%p frame=(%.1f,%.1f %.1fx%.1f) candidates=%lu",
                         NJPiPClassName(selectedView),
                         selectedView,
                         selectedView.window,
                         frame.origin.x,
                         frame.origin.y,
                         frame.size.width,
                         frame.size.height,
                         (unsigned long)candidateViews.count);
    }
    return selectedView;
}

static UIView *NJPiPPreferredPrewarmSourceView(void) {
    UIView *rememberedView = NJPiPLastAttachedDanmakuView;
    if (rememberedView.window && !rememberedView.hidden &&
        rememberedView.alpha >= 0.01 && !CGRectIsEmpty(rememberedView.bounds)) {
        return rememberedView;
    }
    return NJFindVisiblePiPDanmakuView();
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
@property (nonatomic, strong, nullable) CALayer *videoLayer;
@property (nonatomic, strong, nullable) UIView *videoView;
@property (nonatomic, strong, nullable) UIView *danmakuView;
@end

@implementation NJPiPDanmakuHostView

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (self.videoLayer.superlayer == self.layer) {
        self.videoLayer.frame = self.bounds;
    }
    if (self.videoView.superview == self) {
        self.videoView.frame = self.bounds;
    }
    if (self.danmakuView.superview == self) {
        self.danmakuView.frame = self.bounds;
    }
    [CATransaction commit];
}

@end

@protocol NJPiPDanmakuPresentationState <NSObject>
- (void)moveContentIntoPictureInPicture;
- (void)restoreContent;
@end

@interface NJPiPDanmakuContentViewController : AVPictureInPictureVideoCallViewController
@property (nonatomic, strong, readonly) NJPiPDanmakuHostView *hostView;
@property (nonatomic, weak) id<NJPiPDanmakuPresentationState> presentationState;
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] content viewWillAppear window=%p", self.view.window);
    [self.presentationState moveContentIntoPictureInPicture];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] content viewDidDisappear window=%p", self.view.window);
    [self.presentationState restoreContent];
}

@end


@class NJPiPDanmakuDelegateProxy;

@interface NJPiPDanmakuState : NSObject <NJPiPDanmakuPresentationState>
@property (nonatomic, weak) AVPictureInPictureController *controller;
@property (nonatomic, strong) AVPlayerLayer *videoLayer;
@property (nonatomic, strong, nullable) UIView *videoView;
@property (nonatomic, strong) UIView *sourceView;
@property (nonatomic, strong) UIView *activeVideoCallSourceView;
@property (nonatomic, strong) AVPictureInPictureControllerContentSource *customContentSource;
@property (nonatomic, strong, nullable) AVPictureInPictureControllerContentSource *adoptedContentSource;
@property (nonatomic, strong, nullable) AVPlayerLayer *pictureInPictureVideoLayer;
@property (nonatomic, strong, nullable) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;
@property (nonatomic, strong, nullable) UIView *sampleBufferView;
@property (nonatomic, weak, nullable) UIView *sampleBufferOriginalSuperview;
@property (nonatomic, assign) NSUInteger sampleBufferOriginalIndex;
@property (nonatomic, assign) CGRect sampleBufferOriginalFrame;
@property (nonatomic, assign) BOOL sampleBufferTranslatesAutoresizingMaskIntoConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *sampleBufferConstraints;
@property (nonatomic, weak, nullable) CALayer *sampleBufferOriginalSuperlayer;
@property (nonatomic, assign) NSUInteger sampleBufferOriginalLayerIndex;
@property (nonatomic, assign) CGRect sampleBufferOriginalLayerFrame;
@property (nonatomic, strong, nullable) UIView *danmakuView;
@property (nonatomic, strong) NJPiPDanmakuContentViewController *contentViewController;
@property (nonatomic, strong) NJPiPDanmakuDelegateProxy *delegateProxy;
@property (nonatomic, weak, nullable) UIView *danmakuOriginalSuperview;
@property (nonatomic, assign) NSUInteger danmakuOriginalIndex;
@property (nonatomic, assign) CGRect danmakuOriginalFrame;
@property (nonatomic, assign) BOOL danmakuTranslatesAutoresizingMaskIntoConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *danmakuConstraints;
@property (nonatomic, assign, getter=isPresenting) BOOL presenting;
- (void)moveContentIntoPictureInPicture;
- (BOOL)adoptContentSourceDuringPictureInPicture:(AVPictureInPictureControllerContentSource *)contentSource;
- (void)restoreContent;
@end

@interface NJPiPDanmakuDelegateProxy : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, weak) id<AVPictureInPictureControllerDelegate> downstream;
@property (nonatomic, weak) NJPiPDanmakuState *state;
@end

@implementation NJPiPDanmakuState

- (void)removePictureInPicturePlayerLayer {
    if (!self.pictureInPictureVideoLayer) {
        return;
    }
    self.pictureInPictureVideoLayer.player = nil;
    [self.pictureInPictureVideoLayer removeFromSuperlayer];
    self.pictureInPictureVideoLayer = nil;
}

- (void)restoreSampleBufferContent {
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;
    if (self.sampleBufferView) {
        [self.sampleBufferView removeFromSuperview];
        if (self.sampleBufferOriginalSuperview) {
            NSUInteger index = MIN(self.sampleBufferOriginalIndex,
                                   self.sampleBufferOriginalSuperview.subviews.count);
            [self.sampleBufferOriginalSuperview insertSubview:self.sampleBufferView atIndex:index];
            self.sampleBufferView.translatesAutoresizingMaskIntoConstraints =
                self.sampleBufferTranslatesAutoresizingMaskIntoConstraints;
            self.sampleBufferView.frame = self.sampleBufferOriginalFrame;
            [NSLayoutConstraint activateConstraints:self.sampleBufferConstraints];
        }
    } else if (self.sampleBufferDisplayLayer) {
        [self.sampleBufferDisplayLayer removeFromSuperlayer];
        if (self.sampleBufferOriginalSuperlayer) {
            NSUInteger index = MIN(self.sampleBufferOriginalLayerIndex,
                                   self.sampleBufferOriginalSuperlayer.sublayers.count);
            [self.sampleBufferOriginalSuperlayer insertSublayer:self.sampleBufferDisplayLayer
                                                        atIndex:(unsigned)index];
            self.sampleBufferDisplayLayer.frame = self.sampleBufferOriginalLayerFrame;
        }
    }
    hostView.videoView = nil;
    if (hostView.videoLayer == self.sampleBufferDisplayLayer) {
        hostView.videoLayer = nil;
    }
    self.sampleBufferDisplayLayer = nil;
    self.sampleBufferView = nil;
    self.sampleBufferOriginalSuperview = nil;
    self.sampleBufferConstraints = @[];
    self.sampleBufferOriginalSuperlayer = nil;
}

- (void)attachPlayer:(AVPlayer *)player videoGravity:(AVLayerVideoGravity)videoGravity {
    if (!player) {
        return;
    }
    [self restoreSampleBufferContent];
    [self removePictureInPicturePlayerLayer];
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;
    AVPlayerLayer *pictureInPictureVideoLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    pictureInPictureVideoLayer.videoGravity = videoGravity ?: AVLayerVideoGravityResizeAspect;
    pictureInPictureVideoLayer.frame = hostView.bounds;
    [hostView.layer insertSublayer:pictureInPictureVideoLayer atIndex:0];
    hostView.videoLayer = pictureInPictureVideoLayer;
    self.pictureInPictureVideoLayer = pictureInPictureVideoLayer;
}

- (BOOL)adoptContentSourceDuringPictureInPicture:(AVPictureInPictureControllerContentSource *)contentSource {
    if (!contentSource || contentSource == self.customContentSource || !self.isPresenting) {
        return NO;
    }

    AVSampleBufferDisplayLayer *sampleBufferLayer = contentSource.sampleBufferDisplayLayer;
    AVPlayerLayer *playerLayer = contentSource.playerLayer;
    self.adoptedContentSource = contentSource;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] intercept contentSource replacement sample=%p playerLayer=%p active=%d",
                     sampleBufferLayer, playerLayer, self.controller.pictureInPictureActive);

    if (sampleBufferLayer) {
        [self removePictureInPicturePlayerLayer];
        [self restoreSampleBufferContent];
        self.sampleBufferDisplayLayer = sampleBufferLayer;
        NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;
        UIView *sampleBufferView = NJViewWithBackingLayer(sampleBufferLayer);
        if (sampleBufferView && sampleBufferView != hostView) {
            self.sampleBufferView = sampleBufferView;
            self.sampleBufferOriginalSuperview = sampleBufferView.superview;
            self.sampleBufferOriginalIndex = sampleBufferView.superview ?
                [sampleBufferView.superview.subviews indexOfObject:sampleBufferView] : 0;
            self.sampleBufferOriginalFrame = sampleBufferView.frame;
            self.sampleBufferTranslatesAutoresizingMaskIntoConstraints =
                sampleBufferView.translatesAutoresizingMaskIntoConstraints;
            self.sampleBufferConstraints = NJConstraintsForView(sampleBufferView, sampleBufferView.superview);
            [NSLayoutConstraint deactivateConstraints:self.sampleBufferConstraints];
            [sampleBufferView removeFromSuperview];
            sampleBufferView.translatesAutoresizingMaskIntoConstraints = YES;
            [hostView insertSubview:sampleBufferView atIndex:0];
            hostView.videoView = sampleBufferView;
            hostView.videoLayer = nil;
        } else {
            CALayer *originalSuperlayer = sampleBufferLayer.superlayer;
            self.sampleBufferOriginalSuperlayer = originalSuperlayer;
            self.sampleBufferOriginalLayerIndex = [originalSuperlayer.sublayers indexOfObject:sampleBufferLayer];
            self.sampleBufferOriginalLayerFrame = sampleBufferLayer.frame;
            [sampleBufferLayer removeFromSuperlayer];
            [hostView.layer insertSublayer:sampleBufferLayer atIndex:0];
            hostView.videoLayer = sampleBufferLayer;
            hostView.videoView = nil;
        }
        [hostView setNeedsLayout];
        [hostView layoutIfNeeded];
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                         "[NJPiPDanmaku] adopted sample-buffer renderer layer=%p view=%{public}s",
                         sampleBufferLayer, NJPiPClassName(sampleBufferView));
        return YES;
    }

    if (playerLayer.player) {
        [self attachPlayer:playerLayer.player videoGravity:playerLayer.videoGravity];
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                         "[NJPiPDanmaku] adopted replacement AVPlayer player=%p item=%p",
                         playerLayer.player, playerLayer.player.currentItem);
        return YES;
    }

    // Replacing the active video-call source makes AVKit stop the current PiP
    // session. Preserve our source even when the replacement is not renderable.
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] blocked unsupported contentSource replacement");
    return YES;
}

- (void)moveContentIntoPictureInPicture {
    if (self.isPresenting) {
        return;
    }
    self.presenting = YES;
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;
    if (self.activeVideoCallSourceView.superview && self.sourceView.window) {
        self.activeVideoCallSourceView.frame =
            [self.sourceView convertRect:self.sourceView.bounds toView:self.activeVideoCallSourceView.superview];
    }

    UIView *latestDanmakuView = NJFindPiPDanmakuView(self.sourceView);
    if (latestDanmakuView) {
        self.danmakuView = latestDanmakuView;
    }
    AVPlayer *player = self.videoLayer.player;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] willStart source=%{public}s video=%{public}s danmaku=%{public}s player=%p item=%p originalSuperlayer=%p",
                     NJPiPClassName(self.sourceView),
                     NJPiPClassName(self.videoView),
                     NJPiPClassName(self.danmakuView),
                     player,
                     player.currentItem,
                     self.videoLayer.superlayer);

    // Keep Bilibili's original view and AVPlayerLayer attached. Removing either one
    // invalidates its video output pipeline. A second presentation layer uses the
    // same AVPlayer, so this adds no second player, network stream, or CPU frame copy.
    if (player) {
        [self attachPlayer:player videoGravity:self.videoLayer.videoGravity];
    } else {
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                         "[NJPiPDanmaku] willStart has no AVPlayer; leaving original renderer untouched");
    }

    BOOL danmakuContainsVideo = self.danmakuView &&
        (self.danmakuView == self.sourceView ||
         [self.sourceView isDescendantOfView:self.danmakuView] ||
         (self.videoView && [self.videoView isDescendantOfView:self.danmakuView]));
    if (self.danmakuView && !danmakuContainsVideo && self.danmakuView.superview) {
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
    } else if (danmakuContainsVideo) {
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                         "[NJPiPDanmaku] refusing to move danmaku container because it contains the video source class=%{public}s",
                         NJPiPClassName(self.danmakuView));
    } else {
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                         "[NJPiPDanmaku] no movable danmaku view found");
    }
    [hostView setNeedsLayout];
    [hostView layoutIfNeeded];
}

- (void)restoreContent {
    if (!self.isPresenting) {
        return;
    }
    self.presenting = NO;
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;

    [self removePictureInPicturePlayerLayer];
    [self restoreSampleBufferContent];

    if (self.danmakuView && self.danmakuOriginalSuperview) {
        [self.danmakuView removeFromSuperview];
        NSUInteger index = MIN(self.danmakuOriginalIndex, self.danmakuOriginalSuperview.subviews.count);
        [self.danmakuOriginalSuperview insertSubview:self.danmakuView atIndex:index];
        self.danmakuView.translatesAutoresizingMaskIntoConstraints = self.danmakuTranslatesAutoresizingMaskIntoConstraints;
        self.danmakuView.frame = self.danmakuOriginalFrame;
        [NSLayoutConstraint activateConstraints:self.danmakuConstraints];
    }

    hostView.videoLayer = nil;
    hostView.videoView = nil;
    hostView.danmakuView = nil;
    [self.danmakuOriginalSuperview setNeedsLayout];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] restored original hierarchy originalVideoSuperlayer=%p player=%p item=%p",
                     self.videoLayer.superlayer,
                     self.videoLayer.player,
                     self.videoLayer.player.currentItem);
}

- (void)dealloc {
    [self.activeVideoCallSourceView removeFromSuperview];
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
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] didStart active=%d possible=%d pipLayerReady=%d danmakuAttached=%d",
                     controller.pictureInPictureActive,
                     controller.pictureInPicturePossible,
                     self.state.pictureInPictureVideoLayer.readyForDisplay,
                     self.state.danmakuView.superview == self.state.contentViewController.hostView);
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStartPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 failedToStartPictureInPictureWithError:(NSError *)error {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] failedToStart domain=%{public}s code=%ld description=%{public}s",
                     error.domain.UTF8String,
                     (long)error.code,
                     error.localizedDescription.UTF8String);
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureController:controller failedToStartPictureInPictureWithError:error];
    }
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)controller {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] willStop active=%d possible=%d",
                     controller.pictureInPictureActive,
                     controller.pictureInPicturePossible);
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerWillStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT, "[NJPiPDanmaku] didStop");
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

static NJPiPDanmakuState *NJMakePiPDanmakuState(AVPlayerLayer *videoLayer) API_AVAILABLE(ios(15.0)) {
    if (!NJPiPDanmakuEnabled() ||
        ![videoLayer isKindOfClass:AVPlayerLayer.class] ||
        !videoLayer.player) {
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
    state.contentViewController.presentationState = state;
    CGSize contentSize = videoLayer.bounds.size;
    if (contentSize.width < 1 || contentSize.height < 1) {
        contentSize = CGSizeMake(640, 360);
    }
    state.contentViewController.preferredContentSize = contentSize;

    state.sourceView = sourceView;
    CGRect activeSourceFrame = [sourceView convertRect:sourceView.bounds toView:sourceView.window];
    UIView *activeSourceView = [[UIView alloc] initWithFrame:activeSourceFrame];
    activeSourceView.backgroundColor = UIColor.clearColor;
    activeSourceView.userInteractionEnabled = NO;
    activeSourceView.accessibilityElementsHidden = YES;
    activeSourceView.opaque = NO;
    [sourceView.window addSubview:activeSourceView];
    state.activeVideoCallSourceView = activeSourceView;
    state.delegateProxy = [[NJPiPDanmakuDelegateProxy alloc] init];
    state.delegateProxy.state = state;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] prepared source=%{public}s video=%{public}s initialDanmaku=%{public}s window=%p player=%p item=%p",
                     NJPiPClassName(sourceView),
                     NJPiPClassName(videoView),
                     NJPiPClassName(danmakuView),
                     sourceView.window,
                     videoLayer.player,
                     videoLayer.player.currentItem);
    return state;
}

// The player-layer source Bilibili creates first is only a transition object: its
// AVPlayer has no currentItem.  Converting that object to a video-call PiP source
// makes AVKit validate an empty renderer and abort the transition.  Wait until
// Bilibili supplies its real AVSampleBufferDisplayLayer, keep that source attached,
// and mirror the already-decoded CMSampleBuffers into the video-call controller.

static const void *NJPiPMirrorStateKey = &NJPiPMirrorStateKey;
static const void *NJPiPMirrorStateBoxKey = &NJPiPMirrorStateBoxKey;
static const void *NJPiPFallbackPlayerLayerKey = &NJPiPFallbackPlayerLayerKey;
static const void *NJPiPFallbackSourceViewKey = &NJPiPFallbackSourceViewKey;
static const void *NJPiPPrewarmedAnchorViewKey = &NJPiPPrewarmedAnchorViewKey;
static const void *NJPiPPrewarmedDanmakuViewKey = &NJPiPPrewarmedDanmakuViewKey;
static __thread NSUInteger NJPiPMirrorEnqueueDepth = 0;

// Bilibili replaces its native player-layer source with the real sample-buffer
// source after the app has begun moving to the background.  At that point all
// player views report window == nil, which is too late to create the active
// video-call source AVKit requires.  Keep a transparent sibling in the real
// window while the app is still foregrounded and reuse it for that replacement.
static void NJPrewarmPiPMirrorInput(AVPictureInPictureController *controller,
                                    UIView *fallbackSourceView) {
    if (!controller || !NJPiPDanmakuEnabled()) {
        return;
    }
    UIView *danmakuView = NJPiPPreferredPrewarmSourceView();
    if (!danmakuView && NJIsPiPDanmakuRenderingView(fallbackSourceView)) {
        danmakuView = fallbackSourceView;
    }
    UIView *referenceView = fallbackSourceView;
    if (!referenceView.window) {
        referenceView = danmakuView;
    }
    UIWindow *window = referenceView.window;
    if (!window) {
        return;
    }

    UIView *anchorView = objc_getAssociatedObject(controller, NJPiPPrewarmedAnchorViewKey);
    if (!anchorView || anchorView.window != window) {
        [anchorView removeFromSuperview];
        CGRect frame = [referenceView convertRect:referenceView.bounds toView:window];
        anchorView = [[UIView alloc] initWithFrame:frame];
        anchorView.backgroundColor = UIColor.clearColor;
        anchorView.userInteractionEnabled = NO;
        anchorView.accessibilityElementsHidden = YES;
        anchorView.opaque = NO;
        [window addSubview:anchorView];
        objc_setAssociatedObject(controller,
                                 NJPiPPrewarmedAnchorViewKey,
                                 anchorView,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        anchorView.frame = [referenceView convertRect:referenceView.bounds toView:window];
    }
    if (danmakuView) {
        objc_setAssociatedObject(controller,
                                 NJPiPPrewarmedDanmakuViewKey,
                                 danmakuView,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] prewarmed anchor=%p window=%p source=%{public}s danmaku=%{public}s",
                     anchorView,
                     window,
                     NJPiPClassName(referenceView),
                     NJPiPClassName(danmakuView));
}

static NSHashTable<AVPictureInPictureController *> *NJPiPTrackedControllers(void) {
    static NSHashTable<AVPictureInPictureController *> *controllers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controllers = [NSHashTable weakObjectsHashTable];
    });
    return controllers;
}

static void NJPrewarmTrackedPiPControllersWithSourceView(UIView *sourceView) {
    NSHashTable<AVPictureInPictureController *> *controllers = NJPiPTrackedControllers();
    NSArray<AVPictureInPictureController *> *snapshot;
    @synchronized (controllers) {
        snapshot = controllers.allObjects;
    }
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] prewarming controllers=%lu source=%{public}s attached=%d",
                     (unsigned long)snapshot.count,
                     NJPiPClassName(sourceView),
                     sourceView.window != nil);
    for (AVPictureInPictureController *controller in snapshot) {
        UIView *fallbackSourceView = objc_getAssociatedObject(controller,
                                                               NJPiPFallbackSourceViewKey);
        if (!fallbackSourceView.window) {
            fallbackSourceView = sourceView.window ? sourceView : NJPiPPreferredPrewarmSourceView();
        }
        NJPrewarmPiPMirrorInput(controller, fallbackSourceView);
    }
}

static void NJPrewarmTrackedPiPControllers(void) {
    NJPrewarmTrackedPiPControllersWithSourceView(nil);
}

static void NJInstallPiPPrewarmObserver(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationWillResignActiveNotification
            object:nil
            queue:NSOperationQueue.mainQueue
            usingBlock:^(__unused NSNotification *notification) {
                // UIKit delivers this notification while the app's player views
                // are still attached to their window, before automatic PiP makes
                // Bilibili replace its content source.
                os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                                 "[NJPiPDanmaku] app will resign active");
                NJPrewarmTrackedPiPControllers();
            }];
    });
}

static void NJTrackPiPController(AVPictureInPictureController *controller) {
    if (!controller || !NJPiPDanmakuEnabled()) {
        return;
    }
    NJInstallPiPPrewarmObserver();
    NSHashTable<AVPictureInPictureController *> *controllers = NJPiPTrackedControllers();
    @synchronized (controllers) {
        [controllers addObject:controller];
    }
    // The controller and the danmaku view are constructed independently by
    // Bilibili.  If the view is already attached, make the AVKit anchor now;
    // waiting for the background notification is too late on iOS 26.
    NJPrewarmPiPMirrorInput(controller, NJPiPPreferredPrewarmSourceView());
}

@interface NJPiPSampleBufferView : UIView
@property (nonatomic, readonly) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;
@end

@implementation NJPiPSampleBufferView

+ (Class)layerClass {
    return AVSampleBufferDisplayLayer.class;
}

- (AVSampleBufferDisplayLayer *)sampleBufferDisplayLayer {
    return (AVSampleBufferDisplayLayer *)self.layer;
}

@end


@class NJPiPMirrorState;

@interface NJPiPMirrorStateBox : NSObject
@property (nonatomic, weak) NJPiPMirrorState *state;
@end

@implementation NJPiPMirrorStateBox
@end


@interface NJPiPMirrorDelegateProxy : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, weak) id<AVPictureInPictureControllerDelegate> downstream;
@property (nonatomic, weak) NJPiPMirrorState *state;
@end


@interface NJPiPMirrorState : NSObject <NJPiPDanmakuPresentationState>
@property (nonatomic, weak) AVPictureInPictureController *controller;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *sourceDisplayLayer;
@property (nonatomic, strong) UIView *sourceView;
@property (nonatomic, weak, nullable) UIView *referenceSourceView;
@property (nonatomic, strong) UIView *activeVideoCallSourceView;
@property (nonatomic, strong, nullable) id sourceVideoRenderer;
@property (nonatomic, strong) NJPiPSampleBufferView *mirrorView;
@property (nonatomic, strong, nullable) id mirrorVideoRenderer;
@property (nonatomic, strong) NJPiPDanmakuContentViewController *contentViewController;
@property (nonatomic, strong) AVPictureInPictureControllerContentSource *customContentSource;
@property (nonatomic, strong) NJPiPMirrorDelegateProxy *delegateProxy;
@property (nonatomic, strong, nullable) UIView *danmakuView;
@property (nonatomic, weak, nullable) UIView *danmakuOriginalSuperview;
@property (nonatomic, assign) NSUInteger danmakuOriginalIndex;
@property (nonatomic, assign) CGRect danmakuOriginalFrame;
@property (nonatomic, assign) BOOL danmakuTranslatesAutoresizingMaskIntoConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *danmakuConstraints;
@property (atomic, assign, getter=isPresenting) BOOL presenting;
@property (atomic, assign) NSUInteger mirroredFrameCount;
- (void)enqueueMirroredSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)invalidate;
@end

static id NJPiPSampleBufferRenderer(AVSampleBufferDisplayLayer *layer) {
    if (!layer || ![layer respondsToSelector:NSSelectorFromString(@"sampleBufferRenderer")]) {
        return nil;
    }
    @try {
        return [layer valueForKey:@"sampleBufferRenderer"];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void NJAssociatePiPMirrorObject(id object, NJPiPMirrorState *state) {
    if (!object) {
        return;
    }
    NJPiPMirrorStateBox *box = [[NJPiPMirrorStateBox alloc] init];
    box.state = state;
    objc_setAssociatedObject(object,
                             NJPiPMirrorStateBoxKey,
                             box,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NJPiPMirrorState *NJPiPMirrorStateForObject(id object) {
    NJPiPMirrorStateBox *box = objc_getAssociatedObject(object, NJPiPMirrorStateBoxKey);
    return box.state;
}

static void NJRemovePiPMirrorAssociation(id object, NJPiPMirrorState *state) {
    if (!object) {
        return;
    }
    NJPiPMirrorStateBox *box = objc_getAssociatedObject(object, NJPiPMirrorStateBoxKey);
    if (box.state == state) {
        objc_setAssociatedObject(object,
                                 NJPiPMirrorStateBoxKey,
                                 nil,
                                 OBJC_ASSOCIATION_ASSIGN);
    }
}

@implementation NJPiPMirrorState

- (void)moveContentIntoPictureInPicture {
    if (self.isPresenting) {
        return;
    }
    self.presenting = YES;

    UIView *sourceView = self.sourceView;
    UIView *referenceSourceView = self.referenceSourceView;
    if (referenceSourceView.window &&
        self.activeVideoCallSourceView.superview == referenceSourceView.window) {
        self.activeVideoCallSourceView.frame =
            [referenceSourceView convertRect:referenceSourceView.bounds
                                      toView:referenceSourceView.window];
    }
    // Keep the foreground renderer captured when the sample-buffer content source
    // was created.  The transparent active-video-call anchor intentionally has no
    // player descendants, so searching beneath it always returns nil.
    UIView *latestDanmakuView = self.danmakuView;
    if (!latestDanmakuView || !latestDanmakuView.superview) {
        latestDanmakuView = NJFindPiPDanmakuView(referenceSourceView);
        if (!latestDanmakuView) {
            latestDanmakuView = NJFindVisiblePiPDanmakuView();
        }
    }
    if (latestDanmakuView) {
        self.danmakuView = latestDanmakuView;
    }

    BOOL danmakuContainsVideo = self.danmakuView &&
        (self.danmakuView == sourceView ||
         [sourceView isDescendantOfView:self.danmakuView]);
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;
    if (self.danmakuView && !danmakuContainsVideo && self.danmakuView.superview) {
        self.danmakuOriginalSuperview = self.danmakuView.superview;
        self.danmakuOriginalIndex = [self.danmakuOriginalSuperview.subviews indexOfObject:self.danmakuView];
        self.danmakuOriginalFrame = self.danmakuView.frame;
        self.danmakuTranslatesAutoresizingMaskIntoConstraints =
            self.danmakuView.translatesAutoresizingMaskIntoConstraints;
        self.danmakuConstraints = NJConstraintsForView(self.danmakuView,
                                                       self.danmakuOriginalSuperview);
        [NSLayoutConstraint deactivateConstraints:self.danmakuConstraints];
        [self.danmakuView removeFromSuperview];
        self.danmakuView.translatesAutoresizingMaskIntoConstraints = YES;
        [hostView addSubview:self.danmakuView];
        hostView.danmakuView = self.danmakuView;
    }

    [hostView setNeedsLayout];
    [hostView layoutIfNeeded];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] presenting sample mirror source=%{public}s layer=%p danmaku=%{public}s attached=%d",
                     NJPiPClassName(sourceView),
                     self.sourceDisplayLayer,
                     NJPiPClassName(self.danmakuView),
                     self.danmakuView.superview == hostView);
}

- (void)enqueueMirroredSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self.isPresenting || !sampleBuffer) {
        return;
    }
    AVSampleBufferDisplayLayer *mirrorLayer = self.mirrorView.sampleBufferDisplayLayer;
    if (mirrorLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
        [mirrorLayer flushAndRemoveImage];
    }
    [mirrorLayer enqueueSampleBuffer:sampleBuffer];
    self.mirroredFrameCount += 1;
    if (self.mirroredFrameCount == 1) {
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                         "[NJPiPDanmaku] first sample mirrored pts=%.3f ready=%d",
                         CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)),
                         mirrorLayer.readyForDisplay);
    }
}

- (void)restoreContent {
    if (!self.isPresenting && !self.danmakuOriginalSuperview) {
        return;
    }
    self.presenting = NO;
    NJPiPDanmakuHostView *hostView = self.contentViewController.hostView;
    if (self.danmakuView && self.danmakuOriginalSuperview) {
        [self.danmakuView removeFromSuperview];
        NSUInteger index = MIN(self.danmakuOriginalIndex,
                               self.danmakuOriginalSuperview.subviews.count);
        [self.danmakuOriginalSuperview insertSubview:self.danmakuView atIndex:index];
        self.danmakuView.translatesAutoresizingMaskIntoConstraints =
            self.danmakuTranslatesAutoresizingMaskIntoConstraints;
        self.danmakuView.frame = self.danmakuOriginalFrame;
        [NSLayoutConstraint activateConstraints:self.danmakuConstraints];
        [self.danmakuOriginalSuperview setNeedsLayout];
    }
    hostView.danmakuView = nil;
    self.danmakuOriginalSuperview = nil;
    self.danmakuConstraints = @[];
    [self.mirrorView.sampleBufferDisplayLayer flushAndRemoveImage];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] restored danmaku hierarchy mirroredFrames=%lu",
                     (unsigned long)self.mirroredFrameCount);
    self.mirroredFrameCount = 0;
}

- (void)invalidate {
    [self restoreContent];
    NJRemovePiPMirrorAssociation(self.sourceDisplayLayer, self);
    NJRemovePiPMirrorAssociation(self.sourceVideoRenderer, self);
    [self.activeVideoCallSourceView removeFromSuperview];
}

- (void)dealloc {
    [self invalidate];
}

@end


@implementation NJPiPMirrorDelegateProxy

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
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] didStart mirror active=%d possible=%d ready=%d frames=%lu",
                     controller.pictureInPictureActive,
                     controller.pictureInPicturePossible,
                     self.state.mirrorView.sampleBufferDisplayLayer.readyForDisplay,
                     (unsigned long)self.state.mirroredFrameCount);
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStartPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 failedToStartPictureInPictureWithError:(NSError *)error {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] failed mirror start domain=%{public}s code=%ld description=%{public}s",
                     error.domain.UTF8String,
                     (long)error.code,
                     error.localizedDescription.UTF8String);
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureController:controller
                 failedToStartPictureInPictureWithError:error];
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

static NJPiPMirrorState *NJMakePiPMirrorState(
    AVPictureInPictureControllerContentSource *contentSource,
    UIView *fallbackSourceView,
    UIView *prewarmedAnchorView,
    UIView *prewarmedDanmakuView) API_AVAILABLE(ios(15.0)) {
    if (!NJPiPDanmakuEnabled()) {
        return nil;
    }
    AVSampleBufferDisplayLayer *sourceLayer = contentSource.sampleBufferDisplayLayer;
    if (![sourceLayer isKindOfClass:AVSampleBufferDisplayLayer.class]) {
        return nil;
    }
    // The sample-buffer source and the danmaku renderer are siblings in Bilibili's
    // player hierarchy.  In the normal case the source view is still attached, so
    // do not make finding the renderer conditional on the source lookup failing:
    // the old condition accidentally searched the freshly-created transparent
    // anchor instead, which can never contain Bilibili's danmaku view.
    UIView *visibleDanmakuView = NJFindVisiblePiPDanmakuView();
    UIView *directSourceView = NJViewWithBackingLayer(sourceLayer) ?: NJSourceViewForLayer(sourceLayer);
    UIView *referenceSourceView = directSourceView;
    if ((!referenceSourceView || !referenceSourceView.window) && fallbackSourceView.window) {
        referenceSourceView = fallbackSourceView;
    }
    if ((!referenceSourceView || !referenceSourceView.window) && prewarmedAnchorView.window) {
        referenceSourceView = prewarmedAnchorView;
    }
    if (!referenceSourceView || !referenceSourceView.window) {
        referenceSourceView = visibleDanmakuView;
    }
    if (!referenceSourceView || !referenceSourceView.window) {
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                         "[NJPiPDanmaku] preserve native source: no visible sample, fallback, or danmaku source layer=%p fallback=%{public}s window=%p",
                         sourceLayer,
                         NJPiPClassName(fallbackSourceView),
                         fallbackSourceView.window);
        return nil;
    }

    CGRect activeSourceFrame = [referenceSourceView convertRect:referenceSourceView.bounds
                                                          toView:referenceSourceView.window];
    UIView *activeSourceView = prewarmedAnchorView;
    if (!activeSourceView || activeSourceView.window != referenceSourceView.window) {
        activeSourceView = [[UIView alloc] initWithFrame:activeSourceFrame];
        activeSourceView.backgroundColor = UIColor.clearColor;
        activeSourceView.userInteractionEnabled = NO;
        activeSourceView.accessibilityElementsHidden = YES;
        activeSourceView.opaque = NO;
        [referenceSourceView.window addSubview:activeSourceView];
    } else {
        activeSourceView.frame = activeSourceFrame;
    }

    NJPiPMirrorState *state = [[NJPiPMirrorState alloc] init];
    state.sourceDisplayLayer = sourceLayer;
    // The transparent anchor remains in the app window while the original player
    // hierarchy is transitioning to the background.  It is also deliberately not
    // an ancestor of the danmaku renderer, so that renderer can safely be moved
    // into the hosted PiP view without taking the video hierarchy with it.
    state.sourceView = activeSourceView;
    state.referenceSourceView = referenceSourceView;
    state.activeVideoCallSourceView = activeSourceView;
    state.sourceVideoRenderer = NJPiPSampleBufferRenderer(sourceLayer);
    // Keep the frontmost real renderer.  The anchor intentionally has no player
    // subviews, so looking below it would always yield nil.
    state.danmakuView = visibleDanmakuView ?: prewarmedDanmakuView ?: NJFindPiPDanmakuView(referenceSourceView);
    state.contentViewController = [[NJPiPDanmakuContentViewController alloc] init];
    state.contentViewController.presentationState = state;

    CGSize contentSize = sourceLayer.bounds.size;
    if (contentSize.width < 1 || contentSize.height < 1) {
        contentSize = referenceSourceView.bounds.size;
    }
    if (contentSize.width < 1 || contentSize.height < 1) {
        contentSize = CGSizeMake(640, 360);
    }
    state.contentViewController.preferredContentSize = contentSize;

    NJPiPDanmakuHostView *hostView = state.contentViewController.hostView;
    state.mirrorView = [[NJPiPSampleBufferView alloc] initWithFrame:hostView.bounds];
    state.mirrorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    state.mirrorView.sampleBufferDisplayLayer.videoGravity =
        sourceLayer.videoGravity ?: AVLayerVideoGravityResizeAspect;
    state.mirrorView.sampleBufferDisplayLayer.controlTimebase = sourceLayer.controlTimebase;
    [hostView addSubview:state.mirrorView];
    hostView.videoView = state.mirrorView;
    state.mirrorVideoRenderer = NJPiPSampleBufferRenderer(state.mirrorView.sampleBufferDisplayLayer);

    state.customContentSource = [[AVPictureInPictureControllerContentSource alloc]
        initWithActiveVideoCallSourceView:activeSourceView
        contentViewController:state.contentViewController];
    state.delegateProxy = [[NJPiPMirrorDelegateProxy alloc] init];
    state.delegateProxy.state = state;
    NJAssociatePiPMirrorObject(sourceLayer, state);
    NJAssociatePiPMirrorObject(state.sourceVideoRenderer, state);
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] prepared real sample anchor=%p reference=%{public}s direct=%{public}s fallback=%{public}s layer=%p renderer=%p danmaku=%{public}s frame=(%.1f,%.1f %.1fx%.1f) size=%.0fx%.0f",
                     activeSourceView,
                     NJPiPClassName(referenceSourceView),
                     NJPiPClassName(directSourceView),
                     NJPiPClassName(fallbackSourceView),
                     sourceLayer,
                     state.sourceVideoRenderer,
                     NJPiPClassName(state.danmakuView),
                     activeSourceFrame.origin.x,
                     activeSourceFrame.origin.y,
                     activeSourceFrame.size.width,
                     activeSourceFrame.size.height,
                     contentSize.width,
                     contentSize.height);
    return state;
}

%group App

@interface BBPlayerDanmakuService : NSObject
- (instancetype)initWithContext:(id)context;
- (void)serviceOnStart;
- (void)serviceOnStop;
- (void)loadDMViewWithContextExtra:(id)contextExtra completeBlock:(id)completeBlock;
- (UIView *)view;
- (double)currentTime;
- (double)playbackRate;
@end

%hook BBPlayerDanmakuService

- (instancetype)initWithContext:(id)context {
    id result = %orig;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService init self=%p result=%p context=%p contextClass=%{public}s thread=%{public}s",
                     self, result, context, NJPiPClassName(context), NSThread.currentThread.description.UTF8String);
    return result;
}

- (void)serviceOnStart {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService start self=%p view=%p time=%.3f rate=%.3f",
                     self, [self view], [self currentTime], [self playbackRate]);
    %orig;

    // The service creates its renderer asynchronously.  Reading `view` before
    // serviceOnStart/loadDMView returns consistently produces nil on 8.76, so
    // sample the public accessor after the current run loop and during the
    // short loading window.  The hooked getter performs registration/prewarm.
    for (NSNumber *delay in @[@0.0, @0.2, @0.8]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIView *view = [self view];
            os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                             "[NJPiPTrace] DanmakuService delayed view self=%p delay=%.1f view=%p class=%{public}s window=%p",
                             self, delay.doubleValue, view, NJPiPClassName(view), view.window);
        });
    }
}

- (void)serviceOnStop {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService stop self=%p view=%p time=%.3f",
                     self, [self view], [self currentTime]);
    %orig;
}

- (void)loadDMViewWithContextExtra:(id)contextExtra completeBlock:(id)completeBlock {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService loadDMView self=%p extra=%p extraClass=%{public}s completion=%p",
                     self, contextExtra, NJPiPClassName(contextExtra), completeBlock);
    %orig;

    for (NSNumber *delay in @[@0.0, @0.2, @0.8]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIView *view = [self view];
            os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                             "[NJPiPTrace] DanmakuService post-load view self=%p delay=%.1f view=%p class=%{public}s window=%p",
                             self, delay.doubleValue, view, NJPiPClassName(view), view.window);
        });
    }
}

- (UIView *)view {
    UIView *view = %orig;
    NJRegisterPiPDanmakuView(view);
    if (view.window && !view.hidden && view.alpha >= 0.01 &&
        !CGRectIsEmpty(view.bounds)) {
        NJRememberAttachedPiPDanmakuView(view);
        NJPrewarmTrackedPiPControllersWithSourceView(view);
    }
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService view self=%p view=%p class=%{public}s window=%p hidden=%d alpha=%.2f frame=(%.1f,%.1f %.1fx%.1f)",
                     self,
                     view,
                     NJPiPClassName(view),
                     view.window,
                     view.hidden,
                     view.alpha,
                     view.frame.origin.x,
                     view.frame.origin.y,
                     view.frame.size.width,
                     view.frame.size.height);
    return view;
}

%end

@interface BBSBPiPManager : NSObject
- (BOOL)needsBindingPlayerContainer;
- (void)prepareToStart;
- (void)stopPreparing;
- (void)start;
- (void)stop;
- (void)stopWithReason:(NSInteger)reason;
- (NSInteger)pictureInPictureStatus;
- (void)setPictureInPictureStatus:(NSInteger)status;
- (void)bindGraftData:(id)graftData shareId:(id)shareId dataSource:(id)dataSource completion:(id)completion;
- (void)bindGraftData:(id)graftData ugcDataSourceAdapter:(id)adapter completion:(id)completion;
@end

%hook BBSBPiPManager

- (instancetype)init {
    id result = %orig;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager init self=%p result=%p class=%{public}s",
                     self, result, NJPiPClassName(result));
    return result;
}

- (BOOL)needsBindingPlayerContainer {
    BOOL result = %orig;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager needsBinding self=%p result=%d status=%ld",
                     self, result, (long)[self pictureInPictureStatus]);
    return result;
}

- (void)bindGraftData:(id)graftData shareId:(id)shareId dataSource:(id)dataSource completion:(id)completion {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager bind shared self=%p graft=%p(%{public}s) share=%p source=%p(%{public}s) completion=%p",
                     self, graftData, NJPiPClassName(graftData), shareId,
                     dataSource, NJPiPClassName(dataSource), completion);
    %orig;
}

- (void)bindGraftData:(id)graftData ugcDataSourceAdapter:(id)adapter completion:(id)completion {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager bind UGC self=%p graft=%p(%{public}s) adapter=%p(%{public}s) completion=%p",
                     self, graftData, NJPiPClassName(graftData),
                     adapter, NJPiPClassName(adapter), completion);
    %orig;
}

- (void)prepareToStart {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager prepare self=%p status=%ld needsBinding=%d",
                     self, (long)[self pictureInPictureStatus], [self needsBindingPlayerContainer]);
    %orig;
}

- (void)stopPreparing {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stopPreparing self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    %orig;
}

- (void)start {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager start self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    %orig;
}

- (void)stop {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stop self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    %orig;
}

- (void)stopWithReason:(NSInteger)reason {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stopWithReason self=%p reason=%ld status=%ld",
                     self, (long)reason, (long)[self pictureInPictureStatus]);
    %orig;
}

- (void)setPictureInPictureStatus:(NSInteger)status {
    NSInteger oldStatus = [self pictureInPictureStatus];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager status self=%p old=%ld new=%ld",
                     self, (long)oldStatus, (long)status);
    %orig;
}

- (void)dealloc {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager dealloc self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    %orig;
}

%end

@interface _TtC18BBPictureInPicture15PlayerContainer : NSObject
- (void)director_didPrepared;
- (void)director_didComplete;
@end

%hook _TtC18BBPictureInPicture15PlayerContainer

- (instancetype)init {
    id result = %orig;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer init self=%p result=%p class=%{public}s",
                     self, result, NJPiPClassName(result));
    return result;
}

- (void)director_didPrepared {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer prepared self=%p thread=%{public}s",
                     self, NSThread.currentThread.description.UTF8String);
    %orig;
}

- (void)director_didComplete {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer complete self=%p",
                     self);
    %orig;
}

- (void)dealloc {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer dealloc self=%p", self);
    %orig;
}

%end

@interface BBPlayerDanmakuVoutView : UIView
@end

%hook BBPlayerDanmakuVoutView

- (void)didMoveToWindow {
    %orig;
    NJRegisterPiPDanmakuView(self);
    if (self.window) {
        NJRememberAttachedPiPDanmakuView(self);
        NJPrewarmTrackedPiPControllersWithSourceView(self);
    }
}

%end

// Bilibili 8.89 can enqueue through either the display layer compatibility API
// or its iOS 17+ renderer.  A thread-local depth guard ensures one mirror enqueue
// when AVSampleBufferDisplayLayer forwards internally to AVSampleBufferVideoRenderer.
%hook AVSampleBufferDisplayLayer

- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NJPiPMirrorState *state = NJPiPMirrorStateForObject(self);
    if (!state || NJPiPMirrorEnqueueDepth > 0) {
        %orig;
        return;
    }
    NJPiPMirrorEnqueueDepth += 1;
    %orig;
    NJPiPMirrorEnqueueDepth -= 1;
    [state enqueueMirroredSampleBuffer:sampleBuffer];
}

%end

@interface AVSampleBufferVideoRenderer (NJPiPMirroring)
- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

%hook AVSampleBufferVideoRenderer

- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    NJPiPMirrorState *state = NJPiPMirrorStateForObject(self);
    if (!state || NJPiPMirrorEnqueueDepth > 0) {
        %orig;
        return;
    }
    NJPiPMirrorEnqueueDepth += 1;
    %orig;
    NJPiPMirrorEnqueueDepth -= 1;
    [state enqueueMirroredSampleBuffer:sampleBuffer];
}

%end

%hook AVPictureInPictureController

- (instancetype)initWithPlayerLayer:(AVPlayerLayer *)playerLayer {
    // This is a nil-currentItem transition source in Bilibili.  Leaving it native
    // is essential: the app replaces it with a sample-buffer source when PiP starts.
    AVPictureInPictureController *controller = %orig;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] controller player-layer init class=%{public}s controller=%p enabled=%d",
                     NJPiPClassName(controller), controller, NJPiPDanmakuEnabled());
    if (controller && NJPiPDanmakuEnabled() && [playerLayer isKindOfClass:AVPlayerLayer.class]) {
        NJTrackPiPController(controller);
        objc_setAssociatedObject(controller,
                                 NJPiPFallbackPlayerLayerKey,
                                 playerLayer,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *sourceView = NJViewWithBackingLayer(playerLayer) ?: NJSourceViewForLayer(playerLayer);
        if (!sourceView.window) {
            sourceView = NJFindVisiblePiPDanmakuView();
        }
        if (sourceView.window) {
            objc_setAssociatedObject(controller,
                                     NJPiPFallbackSourceViewKey,
                                     sourceView,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NJPrewarmPiPMirrorInput(controller, sourceView);
        }
        CGRect sourceFrame = sourceView ? sourceView.frame : CGRectZero;
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                         "[NJPiPDanmaku] remembered native player source=%{public}s view=%p window=%p frame=(%.1f,%.1f %.1fx%.1f) player=%p item=%p",
                         NJPiPClassName(sourceView),
                         sourceView,
                         sourceView.window,
                         sourceFrame.origin.x,
                         sourceFrame.origin.y,
                         sourceFrame.size.width,
                         sourceFrame.size.height,
                         playerLayer.player,
                         playerLayer.player.currentItem);
    }
    return controller;
}

- (void)startPictureInPicture {
    UIView *fallbackSourceView = objc_getAssociatedObject(self, NJPiPFallbackSourceViewKey);
    if (!fallbackSourceView.window) {
        AVPlayerLayer *fallbackPlayerLayer = objc_getAssociatedObject(self,
                                                                       NJPiPFallbackPlayerLayerKey);
        fallbackSourceView = NJViewWithBackingLayer(fallbackPlayerLayer) ?:
                             NJSourceViewForLayer(fallbackPlayerLayer);
    }
    NJPrewarmPiPMirrorInput(self, fallbackSourceView);
    %orig;
}

- (instancetype)initWithContentSource:(AVPictureInPictureControllerContentSource *)contentSource {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] controller content-source init class=%{public}s source=%{public}s enabled=%d",
                     NJPiPClassName(self), NJPiPClassName(contentSource), NJPiPDanmakuEnabled());
    if (@available(iOS 15.0, *)) {
        NJPiPMirrorState *state = NJMakePiPMirrorState(contentSource, nil, nil, nil);
        if (state) {
            AVPictureInPictureController *controller = %orig(state.customContentSource);
            if (controller) {
                NJTrackPiPController(controller);
                state.controller = controller;
                objc_setAssociatedObject(controller,
                                         NJPiPMirrorStateKey,
                                         state,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                controller.delegate = state.delegateProxy;
                return controller;
            }
            [state invalidate];
            return nil;
        }
    }
    AVPictureInPictureController *controller = %orig;
    NJTrackPiPController(controller);
    return controller;
}

- (void)setContentSource:(AVPictureInPictureControllerContentSource *)contentSource {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] controller set source class=%{public}s source=%{public}s enabled=%d",
                     NJPiPClassName(self), NJPiPClassName(contentSource), NJPiPDanmakuEnabled());
    NJPiPMirrorState *oldState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    if (contentSource == oldState.customContentSource) {
        %orig;
        return;
    }

    id<AVPictureInPictureControllerDelegate> downstream = self.delegate;
    [oldState invalidate];
    objc_setAssociatedObject(self, NJPiPMirrorStateKey, nil, OBJC_ASSOCIATION_ASSIGN);

    if (@available(iOS 15.0, *)) {
        AVPlayerLayer *fallbackPlayerLayer = objc_getAssociatedObject(self,
                                                                       NJPiPFallbackPlayerLayerKey);
        UIView *fallbackSourceView = objc_getAssociatedObject(self,
                                                               NJPiPFallbackSourceViewKey);
        if (!fallbackSourceView.window) {
            fallbackSourceView = NJViewWithBackingLayer(fallbackPlayerLayer) ?:
                                 NJSourceViewForLayer(fallbackPlayerLayer);
        }
        if (!fallbackSourceView.window) {
            fallbackSourceView = NJFindVisiblePiPDanmakuView();
        }
        UIView *prewarmedAnchorView = objc_getAssociatedObject(self,
                                                                NJPiPPrewarmedAnchorViewKey);
        UIView *prewarmedDanmakuView = objc_getAssociatedObject(self,
                                                                 NJPiPPrewarmedDanmakuViewKey);
        NJPiPMirrorState *newState = NJMakePiPMirrorState(contentSource,
                                                          fallbackSourceView,
                                                          prewarmedAnchorView,
                                                          prewarmedDanmakuView);
        if (newState) {
            newState.controller = self;
            newState.delegateProxy.downstream = downstream;
            objc_setAssociatedObject(self,
                                     NJPiPMirrorStateKey,
                                     newState,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            %orig(newState.customContentSource);
            self.delegate = newState.delegateProxy;
            return;
        }
    }
    // nil, player-layer, or an unrecognized source remains completely native.
    %orig;
    if (oldState && downstream) {
        self.delegate = downstream;
    }
}

- (void)setDelegate:(id<AVPictureInPictureControllerDelegate>)delegate {
    NJPiPMirrorState *mirrorState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    if (mirrorState && delegate != mirrorState.delegateProxy) {
        mirrorState.delegateProxy.downstream = delegate;
        %orig(mirrorState.delegateProxy);
        return;
    }
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
    NJPiPMirrorState *mirrorState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    if (mirrorState && delegate == mirrorState.delegateProxy && mirrorState.delegateProxy.downstream) {
        return mirrorState.delegateProxy.downstream;
    }
    NJPiPDanmakuState *state = objc_getAssociatedObject(self, NJPiPDanmakuStateKey);
    if (state && delegate == state.delegateProxy && state.delegateProxy.downstream) {
        return state.delegateProxy.downstream;
    }
    return delegate;
}

- (void)dealloc {
    NJPiPMirrorState *mirrorState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    [mirrorState invalidate];
    objc_setAssociatedObject(self, NJPiPMirrorStateKey, nil, OBJC_ASSOCIATION_ASSIGN);
    NJPiPDanmakuState *state = objc_getAssociatedObject(self, NJPiPDanmakuStateKey);
    [state restoreContent];
    objc_setAssociatedObject(self, NJPiPDanmakuStateKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, NJPiPFallbackPlayerLayerKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, NJPiPFallbackSourceViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
    UIView *prewarmedAnchorView = objc_getAssociatedObject(self, NJPiPPrewarmedAnchorViewKey);
    [prewarmedAnchorView removeFromSuperview];
    objc_setAssociatedObject(self, NJPiPPrewarmedAnchorViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, NJPiPPrewarmedDanmakuViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
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
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] module loaded master=%d pip=%d",
                     NJ_MASTER_SWITCH_VALUE, NJ_PIP_DANMAKU_VALUE);
    if (NJ_MASTER_SWITCH_VALUE) {
        %init(App);
    }
}
