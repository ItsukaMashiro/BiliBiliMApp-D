#line 1 "BiliBiliMDDylib/Logos/Detail/NJDetailPlayerAd.xm"


























































































































#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <objc/runtime.h>
#import <os/log.h>
#import <CoreMedia/CoreMedia.h>
#import "NJCommonDefine.h"

#if __has_include("NJBuildStamp.h")
#import "NJBuildStamp.h"
#endif
#ifndef NJ_PI_P_BUILD_SHA
#define NJ_PI_P_BUILD_SHA "local"
#endif
#ifndef NJ_PI_P_TARGET_APP_URL
#define NJ_PI_P_TARGET_APP_URL "unknown"
#endif








#ifndef NJ_PIP_GPU_COMPOSITE_ENABLED
#define NJ_PIP_GPU_COMPOSITE_ENABLED 0
#endif



































#ifndef NJ_PIP_MIXED_OFFSCREEN_ENABLED
#define NJ_PIP_MIXED_OFFSCREEN_ENABLED 0
#endif








#ifndef NJ_PIP_LAN_LOG_URL
#define NJ_PIP_LAN_LOG_URL "http://10.0.0.241:8099/njlog"
#endif
#ifndef NJ_PIP_LAN_LOG_UPLOAD_ENABLED
#define NJ_PIP_LAN_LOG_UPLOAD_ENABLED 1
#endif



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



static dispatch_queue_t NJPiPDiagQueue(void) {
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.njbilibili.pip.diag", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static NSString *NJPiPDiagFilePath(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:@"NJPiPDiagnostics.ndjson"];
}

static NSMutableData *NJPiPDiagBuffer(void) {
    static NSMutableData *buffer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        buffer = [NSMutableData data];
    });
    return buffer;
}

static void NJPiPDiagFlushLocked(void);
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED



static void NJPiMxFlushNow(void);


static void NJPiMxForgetCapturedViews(const char *why);
static id NJPiMCapturedView(void);
#endif
#if NJ_PIP_LAN_LOG_UPLOAD_ENABLED


static void NJPiPLanUploadBuffer(NSData *payload);
static void NJPiPLanUploadProbeFile(void);
#endif

static void NJPiPDiagAppendLineLocked(NSString *message) {
    NSMutableData *buffer = NJPiPDiagBuffer();
    long long nowMs = (long long)llround([NSDate date].timeIntervalSince1970 * 1000.0);
    [buffer appendData:[[NSString stringWithFormat:@"{\"t\":%lld,\"m\":\"%@\"}\n", nowMs, message]
        dataUsingEncoding:NSUTF8StringEncoding]];
    if (buffer.length >= 16 * 1024) {
        NJPiPDiagFlushLocked();
    }
}

static void NJPiPDiagFlushLocked(void) {
    NSMutableData *buffer = NJPiPDiagBuffer();
    if (buffer.length == 0) {
        return;
    }
    NSString *path = NJPiPDiagFilePath();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary<NSString *, id> *attributes = [fileManager attributesOfItemAtPath:path error:nil];
    if ([attributes[NSFileSize] unsignedLongLongValue] > 512 * 1024) {
        [fileManager removeItemAtPath:path error:nil];
    }
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createFileAtPath:path contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) {
        return;
    }
    [handle seekToEndOfFile];
    [handle writeData:buffer];
    [handle closeFile];
    
    
    
    
    NSString *copyPath = [path stringByReplacingOccurrencesOfString:@".ndjson"
                                                       withString:@".copy.ndjson"];
    NSDictionary<NSString *, id> *copyAttributes = [fileManager attributesOfItemAtPath:copyPath error:nil];
    if ([copyAttributes[NSFileSize] unsignedLongLongValue] > 512 * 1024) {
        [fileManager removeItemAtPath:copyPath error:nil];
    }
    if (![fileManager fileExistsAtPath:copyPath]) {
        [fileManager createFileAtPath:copyPath contents:nil attributes:nil];
    }
    NSFileHandle *copyHandle = [NSFileHandle fileHandleForWritingAtPath:copyPath];
    if (copyHandle) {
        [copyHandle seekToEndOfFile];
        [copyHandle writeData:buffer];
        [copyHandle closeFile];
    }
#if NJ_PIP_LAN_LOG_UPLOAD_ENABLED
    
    
    
    NJPiPLanUploadBuffer(buffer);
    NJPiPLanUploadProbeFile();
#endif
    [buffer setLength:0];
}

static void NJPiPDiagFlush(void) {
    dispatch_async(NJPiPDiagQueue(), ^{
        NJPiPDiagFlushLocked();
    });
}

static void NJPiPDiag(const char *format, ...) __attribute__((format(printf, 1, 2)));

static void NJPiPDiag(const char *format, ...) {
    va_list args;
    va_start(args, format);
    char message[2048];
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    NSString *text = [NSString stringWithUTF8String:message];
    
    
    
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT,
                     "[NJPiPDanmaku] %{public}s",
                     text.UTF8String);
    dispatch_async(NJPiPDiagQueue(), ^{
        NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        NJPiPDiagAppendLineLocked(escaped);
    });
}



#if NJ_PIP_LAN_LOG_UPLOAD_ENABLED







static NSUInteger NJPiPLanUploadAttemptCount;
static NSUInteger NJPiPLanUploadOkCount;
static NSUInteger NJPiPLanUploadSentBytes;
static const char *const NJPiPLanUploadReasonNames[] = { "url", "http", "net" };
static const NSUInteger NJPiPLanUploadReasonCount =
    sizeof(NJPiPLanUploadReasonNames) / sizeof(NJPiPLanUploadReasonNames[0]);
static NSUInteger NJPiPLanUploadReasonHits[4];

static void NJPiPLanUploadNoteFailure(NSUInteger reason, NSString *detail) {
    if (reason >= NJPiPLanUploadReasonCount) {
        return;
    }
    NJPiPLanUploadReasonHits[reason] += 1;
    if (NJPiPLanUploadReasonHits[reason] > 2) {
        return;
    }
    NJPiPDiag("netup fail reason=%s n=%lu att=%lu ok=%lu sentB=%lu %s",
              NJPiPLanUploadReasonNames[reason],
              (unsigned long)NJPiPLanUploadReasonHits[reason],
              (unsigned long)NJPiPLanUploadAttemptCount,
              (unsigned long)NJPiPLanUploadOkCount,
              (unsigned long)NJPiPLanUploadSentBytes,
              detail.UTF8String);
}

static NSURLSession *NJPiPLanUploadSession(void) {
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = 5.0;
        configuration.timeoutIntervalForResource = 10.0;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        session = [NSURLSession sessionWithConfiguration:configuration];
        
        NJPiPDiag("netup init url=%s timeout=5s", NJ_PIP_LAN_LOG_URL);
    });
    return session;
}

static void NJPiPLanUploadData(NSData *payload, NSString *name) {
    if (payload.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%s?name=%@", NJ_PIP_LAN_LOG_URL, name]];
    if (!url) {
        NJPiPLanUploadNoteFailure(0, [NSString stringWithFormat:@"name=%@ url=%s", name, NJ_PIP_LAN_LOG_URL]);
        return;
    }
    NJPiPLanUploadAttemptCount += 1;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                      timeoutInterval:5.0];
    request.HTTPMethod = @"POST";
    request.HTTPBody = payload;
    [request setValue:@"application/x-ndjson" forHTTPHeaderField:@"Content-Type"];
    NSURLSessionDataTask *task = [NJPiPLanUploadSession()
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (error) {
                  NJPiPLanUploadNoteFailure(2, [NSString stringWithFormat:@"errdom=%@ errcode=%ld",
                                                error.domain ?: @"-", (long)error.code]);
                  return;
              }
              if (![response isKindOfClass:NSHTTPURLResponse.class]) {
                  NJPiPLanUploadNoteFailure(1, @"status=non-http-response");
                  return;
              }
              NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
              if (status < 200 || status >= 300) {
                  NSString *body = data.length
                      ? ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"-")
                      : @"-";
                  if (body.length > 160) {
                      body = [body substringToIndex:160];
                  }
                  NJPiPLanUploadNoteFailure(1, [NSString stringWithFormat:@"status=%ld body=%@",
                                                (long)status, body]);
                  return;
              }
              
              NJPiPLanUploadOkCount += 1;
              NJPiPLanUploadSentBytes += (NSUInteger)payload.length;
          }];
    [task resume];
}

static void NJPiPLanUploadBuffer(NSData *payload) {
    
    NJPiPLanUploadData([payload copy], @"NJPiPDiagnostics");
}






static unsigned long long NJPiPLanProbeCursor;
static NSUInteger NJPiPLanProbeTick;

static void NJPiPLanUploadProbeFile(void) {
    NJPiPLanProbeTick += 1;
    if (NJPiPLanProbeTick % 10 != 1) {
        return;
    }
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/NJPiPProbe.ndjson"];
    NSDictionary<NSString *, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
    if (NJPiPLanProbeCursor > size) {
        NJPiPLanProbeCursor = 0;  
    }
    if (size <= NJPiPLanProbeCursor) {
        return;
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) {
        return;
    }
    [handle seekToFileOffset:NJPiPLanProbeCursor];
    NSData *chunk = [handle readDataToEndOfFile];
    [handle closeFile];
    if (chunk.length == 0) {
        return;
    }
    if (chunk.length > 4 * 1024 * 1024) {
        chunk = [chunk subdataWithRange:NSMakeRange(0, 4 * 1024 * 1024)];  
    }
    const unsigned char *bytes = (const unsigned char *)chunk.bytes;
    NSUInteger consumed = 0;
    for (NSInteger index = (NSInteger)chunk.length - 1; index >= 0; index--) {
        if (bytes[index] == '\n') {
            consumed = (NSUInteger)(index + 1);
            break;
        }
    }
    if (consumed == 0) {
        return;  
    }
    NJPiPLanProbeCursor += consumed;
    NJPiPLanUploadData([chunk subdataWithRange:NSMakeRange(0, consumed)], @"NJPiPProbe");
}

#endif 

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
    NJPiPDiag("adopt contentSource sample=%p playerLayer=%p active=%d",
              sampleBufferLayer, playerLayer, (int)self.controller.pictureInPictureActive);

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
    NJPiPDiag("danmaku willStart");
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
    NJPiPDiag("danmaku didStart active=%d possible=%d",
              (int)controller.pictureInPictureActive,
              (int)controller.pictureInPicturePossible);
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStartPictureInPicture:controller];
    }
}


- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] failedToStart domain=%{public}s code=%ld description=%{public}s",
                     error.domain.UTF8String,
                     (long)error.code,
                     error.localizedDescription.UTF8String);
    NJPiPDiag("danmaku failed domain=%s code=%ld",
              error.domain.UTF8String, (long)error.code);
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
    NJPiPDiag("danmaku willStop");
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerWillStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_DEFAULT, "[NJPiPDanmaku] didStop");
    NJPiPDiag("danmaku didStop");
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStopPictureInPicture:controller];
    }
}


- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    NJPiPDiag("danmaku restoreUI");
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
    NJPiPDiag("prepared danmaku source=%s video=%s danmaku=%s player=%p",
              NJPiPClassName(sourceView),
              NJPiPClassName(videoView),
              NJPiPClassName(danmakuView),
              videoLayer.player);
    return state;
}







static const void *NJPiPMirrorStateKey = &NJPiPMirrorStateKey;
static const void *NJPiPMirrorStateBoxKey = &NJPiPMirrorStateBoxKey;
static const void *NJPiPFallbackPlayerLayerKey = &NJPiPFallbackPlayerLayerKey;
static const void *NJPiPFallbackSourceViewKey = &NJPiPFallbackSourceViewKey;
static const void *NJPiPPrewarmedAnchorViewKey = &NJPiPPrewarmedAnchorViewKey;
static const void *NJPiPPrewarmedDanmakuViewKey = &NJPiPPrewarmedDanmakuViewKey;
static __thread NSUInteger NJPiPMirrorEnqueueDepth = 0;






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
@property (atomic, assign) long long diagLastSampleLogMs;
- (void)enqueueMirroredSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)invalidate;
@end

static NSHashTable<NJPiPMirrorState *> *NJPiPMirrorStates(void) {
    static NSHashTable<NJPiPMirrorState *> *states;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        states = [NSHashTable weakObjectsHashTable];
    });
    return states;
}

static int NJPiPLayerRequiresFlush(AVSampleBufferDisplayLayer *layer) {
    if (!layer || ![layer respondsToSelector:NSSelectorFromString(@"requiresFlushToResumeDecoding")]) {
        return 0;
    }
    @try {
        return [layer valueForKey:@"requiresFlushToResumeDecoding"] ? 1 : 0;
    } @catch (__unused NSException *exception) {
        return 0;
    }
}

static NSString *NJPiPLayerTimebaseInfo(AVSampleBufferDisplayLayer *layer) {
    if (!layer) {
        return @"-";
    }
    CMTimebaseRef timebase = NULL;
    @try {
        id tb = [layer valueForKey:@"timebase"];
        if ([tb isKindOfClass:[NSValue class]]) {
            timebase = (CMTimebaseRef)[(NSValue *)tb pointerValue];
        }
    } @catch (__unused NSException *exception) {
        timebase = NULL;
    }
    if (!timebase) {
        return @"-";
    }
    Float64 rate = CMTimebaseGetRate(timebase);
    CMTime time = CMTimebaseGetTime(timebase);
    if (rate == 0) {
        return @"paused";
    }
    if (time.timescale <= 0) {
        return [NSString stringWithFormat:@"rate=%.2f time=invalid", rate];
    }
    return [NSString stringWithFormat:@"rate=%.2f time=%.3f", rate, CMTimeGetSeconds(time)];
}

static NSMutableDictionary<NSString *, NSValue *> *NJPiPOriginalIMPs(void) {
    static NSMutableDictionary<NSString *, NSValue *> *imps;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imps = [NSMutableDictionary dictionary];
    });
    return imps;
}

static NSValue *NJPiPDiagPlaybackTimeRange(id self, SEL selector, id item, CMTime time) {
    NSString *key = [NSString stringWithFormat:@"%@/%@",
                     NSStringFromClass([self class]), NSStringFromSelector(selector)];
    IMP original = (IMP)[[NJPiPOriginalIMPs() objectForKey:key] pointerValue];
    if (original) {
        return ((NSValue *(*)(id, SEL, id, CMTime))original)(self, selector, item, time);
    }
    return nil;
}

static void NJPiPDiagSeekToTime(id self, SEL selector, CMTime time, void (^completionHandler)(BOOL finished)) {
    NSString *key = [NSString stringWithFormat:@"%@/%@",
                     NSStringFromClass([self class]), NSStringFromSelector(selector)];
    IMP original = (IMP)[[NJPiPOriginalIMPs() objectForKey:key] pointerValue];
    if (original) {
        ((void (*)(id, SEL, CMTime, void (^)(BOOL)))original)(self, selector, time, completionHandler);
        return;
    }
    if (completionHandler) {
        completionHandler(YES);
    }
}

static int NJPiPDiagTimeControlStatus(id self, SEL selector) {
    NSString *key = [NSString stringWithFormat:@"%@/%@",
                     NSStringFromClass([self class]), NSStringFromSelector(selector)];
    IMP original = (IMP)[[NJPiPOriginalIMPs() objectForKey:key] pointerValue];
    if (original) {
        return ((int (*)(id, SEL))original)(self, selector);
    }
    return 0;
}

static void NJPiPSwizzlePlaybackDelegateIfNeeded(id playbackDelegate) {
    if (!playbackDelegate) {
        return;
    }
    Class delegateClass = [playbackDelegate class];
    NSString *className = NSStringFromClass(delegateClass);
    static NSMutableSet<NSString *> *swizzledClasses;
    static dispatch_once_t swizzledOnceToken;
    dispatch_once(&swizzledOnceToken, ^{
        swizzledClasses = [NSMutableSet set];
    });
    @synchronized (swizzledClasses) {
        if ([swizzledClasses containsObject:className]) {
            return;
        }
        [swizzledClasses addObject:className];
    }
    SEL selectors[3] = {
        NSSelectorFromString(@"sampleBufferPlaybackDelegate:playbackTimeRangeForItem:time:"),
        NSSelectorFromString(@"sampleBufferPlaybackDelegate:seekToTime:completionHandler:"),
        NSSelectorFromString(@"sampleBufferPlaybackDelegateTimeControlStatusForPlayback:"),
    };
    IMP replacements[3] = {
        (IMP)NJPiPDiagPlaybackTimeRange,
        (IMP)NJPiPDiagSeekToTime,
        (IMP)NJPiPDiagTimeControlStatus,
    };
    for (int index = 0; index < 3; index++) {
        SEL selector = selectors[index];
        if (!class_respondsToSelector(delegateClass, selector)) {
            continue;
        }
        Method method = class_getInstanceMethod(delegateClass, selector);
        if (!method) {
            continue;
        }
        [NJPiPOriginalIMPs() setValue:[NSValue valueWithPointer:(void *)method_getImplementation(method)]
                               forKey:[NSString stringWithFormat:@"%@/%@",
                                       className, NSStringFromSelector(selector)]];
        class_replaceMethod(delegateClass,
                            selector,
                            replacements[index],
                            method_getTypeEncoding(method));
    }
}


















static const void *NJPiPOverlayStateKey = &NJPiPOverlayStateKey;

@class NJPiPOverlayDelegateProxy;

@interface NJPiPOverlayState : NSObject
@property (nonatomic, weak) AVPictureInPictureController *controller;
@property (nonatomic, weak, nullable) AVSampleBufferDisplayLayer *officialLayer;
@property (nonatomic, strong) NJPiPOverlayDelegateProxy *delegateProxy;


@property (atomic, assign) BOOL pipStartedByCallback;
@property (nonatomic, strong, nullable) UIView *danmakuView;
@property (atomic, assign, getter=isAttached) BOOL attached;

@property (nonatomic, weak, nullable) UIView *danmakuOriginalSuperview;
@property (nonatomic, assign) NSUInteger danmakuOriginalIndex;
@property (nonatomic, assign) CGRect danmakuOriginalFrame;
@property (nonatomic, assign) BOOL danmakuTranslatesAutoresizing;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *danmakuConstraints;

@property (nonatomic, strong, nullable) CALayer *overlayContainerLayer;
@property (nonatomic, weak, nullable) CALayer *danmakuOriginalSuperlayer;
@property (nonatomic, assign) NSUInteger danmakuOriginalLayerIndex;
@property (nonatomic, assign) CGRect danmakuOriginalLayerFrame;
- (void)attachDanmakuToOfficialLayer;
- (void)restoreDanmaku;
- (void)invalidate;
@end

@interface NJPiPOverlayDelegateProxy : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, weak) id<AVPictureInPictureControllerDelegate> downstream;
@property (nonatomic, weak) NJPiPOverlayState *state;
@end

static NSHashTable<NJPiPOverlayState *> *NJPiPOverlayStates(void) {
    static NSHashTable<NJPiPOverlayState *> *states;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        states = [NSHashTable weakObjectsHashTable];
    });
    return states;
}

static NSString *NJPiPSublayerClassList(CALayer *layer) {
    NSArray<CALayer *> *sublayers = layer.sublayers;
    NSMutableString *list = [NSMutableString string];
    NSUInteger limit = MIN(sublayers.count, (NSUInteger)6);
    for (NSUInteger index = 0; index < limit; index++) {
        if (index > 0) {
            [list appendString:@","];
        }
        [list appendFormat:@"%s@%lu",
         NSStringFromClass([sublayers[index] class]).UTF8String,
         (unsigned long)index];
    }
    if (sublayers.count > limit) {
        [list appendFormat:@"|+%lu", (unsigned long)(sublayers.count - limit)];
    }
    return list;
}




static CGRect NJLayerFrameRelativeToAncestor(CALayer *layer, CALayer *ancestor) {
    if (!layer || !ancestor) {
        return CGRectNull;
    }
    CGRect frame = layer.bounds;
    CALayer *current = layer;
    while (current && current != ancestor) {
        CGPoint origin = CGPointApplyAffineTransform(frame.origin, current.affineTransform);
        frame = CGRectMake(origin.x, origin.y, frame.size.width, frame.size.height);
        current = current.superlayer;
    }
    return current == ancestor ? frame : CGRectNull;
}

static void NJPiPDiagDanmakuRenderer(UIView *danmakuView,
                                     CALayer *officialLayer,
                                     const char *stage) {
    CALayer *danmakuLayer = danmakuView.layer;
    UIView *officialView = NJSourceViewForLayer(officialLayer);
    Class metalLayerClass = NSClassFromString(@"CAMetalLayer");
    NJPiPDiag("ov %s off=%s offBounds=(%.1f,%.1f %.1fx%.1f) offSubN=%lu offView=%s offViewWin=%p dm=%s dmWin=%p dmViewFrame=(%.1f,%.1f %.1fx%.1f) dmLayer=%s dmMetal=%d dmLayerBounds=(%.0f,%.0f %.0fx%.0f) dmSubN=%lu dmSub=[%s] dmContentsNil=%d dmLayerSuper=%s",
              stage,
              NJPiPClassName(officialLayer),
              officialLayer.bounds.origin.x,
              officialLayer.bounds.origin.y,
              officialLayer.bounds.size.width,
              officialLayer.bounds.size.height,
              (unsigned long)(officialLayer ? officialLayer.sublayers.count : 0),
              NJPiPClassName(officialView),
              officialView.window,
              NJPiPClassName(danmakuView),
              danmakuView.window,
              danmakuView.frame.origin.x,
              danmakuView.frame.origin.y,
              danmakuView.frame.size.width,
              danmakuView.frame.size.height,
              NJPiPClassName(danmakuLayer),
              (int)(metalLayerClass && danmakuLayer && [danmakuLayer isKindOfClass:metalLayerClass]),
              danmakuLayer.bounds.size.width,
              danmakuLayer.bounds.size.height,
              (unsigned long)(danmakuLayer ? danmakuLayer.sublayers.count : 0),
              danmakuLayer ? NJPiPSublayerClassList(danmakuLayer).UTF8String : "-",
              (int)(danmakuLayer == nil || danmakuLayer.contents == nil),
              NJPiPClassName(danmakuLayer.superlayer));
}

@implementation NJPiPOverlayState

- (void)attachDanmakuToOfficialLayer {
    if (self.attached) {
        return;
    }
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    
    
    NJPiPDiag("ov attach skipped reason=mixed-offscreen-enabled");
    return;
#endif
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    
    
    NJPiPDiag("ov attach skipped reason=gpu-composite-enabled");
    return;
#endif
    AVSampleBufferDisplayLayer *officialLayer = self.officialLayer;
    if (!officialLayer) {
        NJPiPDiag("ov attach skip=no-official-layer");
        return;
    }
    UIView *danmakuView = self.danmakuView;
    if (!danmakuView) {
        danmakuView = objc_getAssociatedObject(self.controller, NJPiPPrewarmedDanmakuViewKey);
    }
    if (!danmakuView) {
        danmakuView = NJFindVisiblePiPDanmakuView();
    }
    if (!danmakuView || !danmakuView.layer) {
        NJPiPDiag("ov attach skip=no-danmaku-view");
        return;
    }
    self.danmakuView = danmakuView;
    CALayer *danmakuLayer = danmakuView.layer;
    UIView *hostView = nil;
    id layerHost = officialLayer.delegate;
    if ([layerHost isKindOfClass:UIView.class] && [(UIView *)layerHost layer] == officialLayer) {
        hostView = (UIView *)layerHost;
    }
    NJPiPDiag("ov attach begin host=%s hostWin=%p", NJPiPClassName(hostView), hostView.window);
    NJPiPDiagDanmakuRenderer(danmakuView, officialLayer, "pre");
    self.attached = YES;
    if (hostView) {
        
        
        
        
        self.danmakuOriginalSuperview = danmakuView.superview;
        self.danmakuOriginalIndex = self.danmakuOriginalSuperview
            ? [self.danmakuOriginalSuperview.subviews indexOfObject:danmakuView]
            : NSNotFound;
        self.danmakuOriginalFrame = danmakuView.frame;
        self.danmakuTranslatesAutoresizing = danmakuView.translatesAutoresizingMaskIntoConstraints;
        self.danmakuConstraints = NJConstraintsForView(danmakuView, self.danmakuOriginalSuperview);
        [NSLayoutConstraint deactivateConstraints:self.danmakuConstraints];
        CGRect targetFrame = CGRectNull;
        if (hostView.layer == officialLayer) {
            targetFrame = hostView.bounds;
        } else {
            targetFrame = NJLayerFrameRelativeToAncestor(officialLayer, hostView.layer);
        }
        if (CGRectIsNull(targetFrame) || targetFrame.size.width < 1 || targetFrame.size.height < 1) {
            targetFrame = hostView.bounds;
        }
        [danmakuView removeFromSuperview];
        danmakuView.translatesAutoresizingMaskIntoConstraints = YES;
        danmakuView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        danmakuView.frame = targetFrame;
        [hostView addSubview:danmakuView];
        NJPiPDiag("ov inserted variant=view target=(%.1f,%.1f %.1fx%.1f) attachedToHost=%d",
                  targetFrame.origin.x,
                  targetFrame.origin.y,
                  targetFrame.size.width,
                  targetFrame.size.height,
                  (int)(danmakuView.superview == hostView));
    } else {
        
        
        
        CALayer *containerLayer = [CALayer layer];
        
        
        
        containerLayer.frame = officialLayer.bounds;
        containerLayer.masksToBounds = NO;
        self.overlayContainerLayer = containerLayer;
        self.danmakuOriginalSuperlayer = danmakuLayer.superlayer;
        self.danmakuOriginalLayerIndex = danmakuLayer.superlayer
            ? [danmakuLayer.superlayer.sublayers indexOfObject:danmakuLayer]
            : NSNotFound;
        self.danmakuOriginalLayerFrame = danmakuLayer.frame;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [officialLayer addSublayer:containerLayer];
        [danmakuLayer removeFromSuperlayer];
        danmakuLayer.frame = officialLayer.bounds;
        [containerLayer addSublayer:danmakuLayer];
        [CATransaction commit];
        NJPiPDiag("ov inserted variant=layer container=%p containerFrame=(%.1f,%.1f %.1fx%.1f)",
                  containerLayer,
                  containerLayer.frame.origin.x,
                  containerLayer.frame.origin.y,
                  containerLayer.frame.size.width,
                  containerLayer.frame.size.height);
    }
    NJPiPDiag("ov attach end offSubN=%lu dmLayerSuper=%s dmLayerInOfficialTree=%d",
              (unsigned long)officialLayer.sublayers.count,
              NJPiPClassName(danmakuLayer.superlayer),
              (int)(danmakuLayer.superlayer == officialLayer ||
                    danmakuLayer.superlayer == self.overlayContainerLayer));
    NJPiPDiagDanmakuRenderer(danmakuView, officialLayer, "post");
}

- (void)restoreDanmaku {
    if (!self.attached && !self.danmakuOriginalSuperview && !self.overlayContainerLayer) {
        return;
    }
    UIView *danmakuView = self.danmakuView;
    if (self.overlayContainerLayer) {
        CALayer *danmakuLayer = danmakuView.layer;
        CALayer *originalSuperlayer = self.danmakuOriginalSuperlayer;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self.overlayContainerLayer removeFromSuperlayer];
        self.overlayContainerLayer = nil;
        if (danmakuLayer) {
            [danmakuLayer removeFromSuperlayer];
            if (originalSuperlayer) {
                NSUInteger index = MIN(self.danmakuOriginalLayerIndex,
                                       originalSuperlayer.sublayers.count);
                [originalSuperlayer insertSublayer:danmakuLayer atIndex:(unsigned)index];
                danmakuLayer.frame = self.danmakuOriginalLayerFrame;
            }
        }
        [CATransaction commit];
        self.danmakuOriginalSuperlayer = nil;
        NJPiPDiag("ov restored variant=layer");
    }
    if (danmakuView && self.danmakuOriginalSuperview) {
        UIView *originalSuperview = self.danmakuOriginalSuperview;
        [danmakuView removeFromSuperview];
        NSUInteger index = MIN(self.danmakuOriginalIndex, originalSuperview.subviews.count);
        [originalSuperview insertSubview:danmakuView atIndex:index];
        danmakuView.translatesAutoresizingMaskIntoConstraints = self.danmakuTranslatesAutoresizing;
        danmakuView.autoresizingMask = UIViewAutoresizingNone;
        danmakuView.frame = self.danmakuOriginalFrame;
        [NSLayoutConstraint activateConstraints:self.danmakuConstraints];
        [originalSuperview setNeedsLayout];
        NJPiPDiag("ov restored variant=view backTo=%s", NJPiPClassName(originalSuperview));
    }
    self.danmakuOriginalSuperview = nil;
    self.danmakuConstraints = @[];
    self.attached = NO;
}

- (void)invalidate {
    @synchronized (NJPiPOverlayStates()) {
        [NJPiPOverlayStates() removeObject:self];
    }
    [self restoreDanmaku];
    self.officialLayer = nil;
}

- (void)dealloc {
    [self invalidate];
}

@end

@implementation NJPiPOverlayDelegateProxy

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
    NJPiPDiag("ov willStart");
    [self.state attachDanmakuToOfficialLayer];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerWillStartPictureInPicture:controller];
    }
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)controller {
    NJPiPDiag("ov didStart pipAct=%d pipPos=%d attached=%d",
              (int)controller.pictureInPictureActive,
              (int)controller.pictureInPicturePossible,
              (int)self.state.isAttached);
    
    self.state.pipStartedByCallback = YES;
    if (self.state && !self.state.isAttached) {
        NJPiPDiag("ov retry@didStart");
        [self.state attachDanmakuToOfficialLayer];
    }
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStartPictureInPicture:controller];
    }
}


- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error {
    NJPiPDiag("ov failed domain=%s code=%ld", error.domain.UTF8String, (long)error.code);
    self.state.pipStartedByCallback = NO;
    [self.state restoreDanmaku];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureController:controller
                  failedToStartPictureInPictureWithError:error];
    }
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)controller {
    NJPiPDiag("ov willStop");
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerWillStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {
    NJPiPDiag("ov didStop");
    self.state.pipStartedByCallback = NO;
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    
    NJPiMxFlushNow();
    
    NJPiMxForgetCapturedViews("didStop");
#endif
    [self.state restoreDanmaku];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStopPictureInPicture:controller];
    }
}


- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    NJPiPDiag("ov restoreUI");
    [self.state restoreDanmaku];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureController:controller
 restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:completionHandler];
    } else {
        completionHandler(YES);
    }
}

@end

static void NJEnsurePiPOverlayState(AVPictureInPictureController *controller,
                                    AVPictureInPictureControllerContentSource *contentSource) API_AVAILABLE(ios(15.0)) {
    if (!controller || !contentSource || !NJPiPDanmakuEnabled()) {
        return;
    }
    AVSampleBufferDisplayLayer *officialLayer = contentSource.sampleBufferDisplayLayer;
    if (![officialLayer isKindOfClass:AVSampleBufferDisplayLayer.class]) {
        NJPiPDiag("ov skip reason=source-not-sbdl src=%s", NJPiPClassName(contentSource));
        return;
    }
    NJPiPOverlayState *state = objc_getAssociatedObject(controller, NJPiPOverlayStateKey);
    if (state) {
        if (state.officialLayer != officialLayer) {
            NJPiPDiag("ov retarget old=%p new=%p attached=%d",
                      state.officialLayer,
                      officialLayer,
                      (int)state.isAttached);
            state.officialLayer = officialLayer;
            if (state.isAttached) {
                [state restoreDanmaku];
                [state attachDanmakuToOfficialLayer];
            }
        }
        return;
    }
    state = [[NJPiPOverlayState alloc] init];
    state.controller = controller;
    state.officialLayer = officialLayer;
    state.delegateProxy = [[NJPiPOverlayDelegateProxy alloc] init];
    state.delegateProxy.state = state;
    state.delegateProxy.downstream = controller.delegate;
    objc_setAssociatedObject(controller,
                             NJPiPOverlayStateKey,
                             state,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @synchronized (NJPiPOverlayStates()) {
        [NJPiPOverlayStates() addObject:state];
    }
    controller.delegate = state.delegateProxy;
    NJPiPDiag("ov state controller=%p source=%s layer=%p layerSize=%.0fx%.0f downstream=%s",
              controller,
              NJPiPClassName(contentSource),
              officialLayer,
              officialLayer.bounds.size.width,
              officialLayer.bounds.size.height,
              NJPiPClassName(state.delegateProxy.downstream));
}






















#if NJ_PIP_GPU_COMPOSITE_ENABLED

#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import <mach/mach_time.h>
#import <string.h>
#import <stdio.h>
#import <stdlib.h>

#pragma mark - GPU composite: state

static id<MTLDevice> NJPiGpuDevice = nil;
static id<MTLCommandQueue> NJPiGpuCommandQueue = nil;
static id<MTLSamplerState> NJPiGpuSampler = nil;
static CVMetalTextureCacheRef NJPiGpuTextureCache = NULL;


#define NJP_GPU_PIPELINE_COUNT 4
static id<MTLRenderPipelineState> NJPiGpuPipelines[NJP_GPU_PIPELINE_COUNT];
static BOOL NJPiGpuSetupAttempted = NO;
static const char *NJPiGpuSetupFailure = NULL;
static CVPixelBufferPoolRef NJPiGpuPool = NULL;
static OSType NJPiGpuPoolFormat = 0;
static NSUInteger NJPiGpuPoolWidth = 0;
static NSUInteger NJPiGpuPoolHeight = 0;



#define NJP_GPU_RING_COUNT 4
static CMSampleBufferRef NJPiGpuRing[NJP_GPU_RING_COUNT];
static NSUInteger NJPiGpuRingNext = 0;

static const char *NJPiGpuFourcc(OSType format) {
    static char buffer[5];
    buffer[0] = (char)((format >> 24) & 0xFF);
    buffer[1] = (char)((format >> 16) & 0xFF);
    buffer[2] = (char)((format >> 8) & 0xFF);
    buffer[3] = (char)(format & 0xFF);
    buffer[4] = '\0';
    return buffer;
}


#define NJP_GPU_MAX_REASONS 12
static const char *NJPiGpuReasonNames[NJP_GPU_MAX_REASONS];
static unsigned long long NJPiGpuReasonHits[NJP_GPU_MAX_REASONS];
static NSUInteger NJPiGpuReasonCount = 0;

static void NJPiGpuRegisterReasons(void) {
    if (NJPiGpuReasonCount > 0) {
        return;
    }
    const char *reasons[] = { "no-pb", "no-src-tex", "no-dm-pb", "no-dm-tex", "no-pool",
                              "no-pl", "no-cb", "no-enc", "draw", "wrap", "init", "fmt" };
    for (NSUInteger index = 0; index < NJP_GPU_MAX_REASONS; index++) {
        NJPiGpuReasonNames[index] = reasons[index];
    }
    NJPiGpuReasonCount = NJP_GPU_MAX_REASONS;
}

static void NJPiGpuNoteFailure(const char *reason, CMSampleBufferRef sampleBuffer) {
    NJPiGpuRegisterReasons();
    NSUInteger slot = NJP_GPU_MAX_REASONS - 1; 
    for (NSUInteger index = 0; index < NJPiGpuReasonCount; index++) {
        if (NJPiGpuReasonNames[index] && strcmp(NJPiGpuReasonNames[index], reason) == 0) {
            slot = index;
            break;
        }
    }
    NJPiGpuReasonHits[slot] += 1;
    if (NJPiGpuReasonHits[slot] <= 5) {
        CVImageBufferRef imageBuffer = sampleBuffer ? CMSampleBufferGetImageBuffer(sampleBuffer) : NULL;
        NJPiPDiag("gpu fail reason=%s n=%llu pb=%d fmt=%s size=%lux%lu",
                  reason,
                  NJPiGpuReasonHits[slot],
                  imageBuffer ? 1 : 0,
                  imageBuffer ? NJPiGpuFourcc(CVPixelBufferGetPixelFormatType(imageBuffer)) : "-",
                  imageBuffer ? (unsigned long)CVPixelBufferGetWidth(imageBuffer) : 0,
                  imageBuffer ? (unsigned long)CVPixelBufferGetHeight(imageBuffer) : 0);
    }
}


static unsigned long long NJPiGpuOkFrames = 0;
static unsigned long long NJPiGpuOkPixels = 0;
static unsigned long long NJPiGpuDurationNs = 0;
static unsigned long long NJPiGpuMaxDurationNs = 0;
static mach_timebase_info_data_t NJPiGpuTimebase;
static unsigned long long NJPiGpuSummaryLastOk = 0;
static unsigned long long NJPiGpuSummaryLastFail = 0;

static unsigned long long NJPiGpuFailTotal(void) {
    unsigned long long total = 0;
    for (NSUInteger index = 0; index < NJPiGpuReasonCount; index++) {
        total += NJPiGpuReasonHits[index];
    }
    return total;
}


static double NJPiGpuNanoseconds(unsigned long long ticks) {
    if (NJPiGpuTimebase.denom == 0) {
        return 0.0;
    }
    return (double)ticks * (double)NJPiGpuTimebase.numer / (double)NJPiGpuTimebase.denom;
}

static void NJPiGpuSummaryTick(void) {
    NJPiGpuRegisterReasons();
    unsigned long long failTotal = NJPiGpuFailTotal();
    if (NJPiGpuOkFrames == NJPiGpuSummaryLastOk && failTotal == NJPiGpuSummaryLastFail) {
        return; 
    }
    unsigned long long okDelta = NJPiGpuOkFrames - NJPiGpuSummaryLastOk;
    unsigned long long failDelta = failTotal - NJPiGpuSummaryLastFail;
    NJPiGpuSummaryLastOk = NJPiGpuOkFrames;
    NJPiGpuSummaryLastFail = failTotal;
    double avgMicroseconds = okDelta > 0
        ? ((double)NJPiGpuDurationNs / (double)okDelta) * 0.001
        : 0.0;
    double maxMicroseconds = ((double)NJPiGpuMaxDurationNs) * 0.001;
    double megaPixelsPerSecond = ((double)NJPiGpuOkPixels) / 1000000.0;
    NSMutableString *counts = [NSMutableString string];
    for (NSUInteger index = 0; index < NJPiGpuReasonCount; index++) {
        if (NJPiGpuReasonHits[index] > 0) {
            [counts appendFormat:@",%s=%llu", NJPiGpuReasonNames[index], NJPiGpuReasonHits[index]];
        }
    }
    NJPiPDiag("gpu sum win=30s ok=%llu ok_d=%llu fail=%llu fail_d=%llu avg_us=%.1f max_us=%.1f "
              "mpix_total=%.1f setup=%s fails=%s",
              NJPiGpuOkFrames, okDelta, failTotal, failDelta,
              avgMicroseconds, maxMicroseconds, megaPixelsPerSecond,
              NJPiGpuSetupFailure ?: "ok", counts.UTF8String ?: "-");
    NJPiGpuMaxDurationNs = 0;
    NJPiGpuDurationNs = 0;
}

static void NJPiGpuStartSummary(void) {
    static dispatch_source_t timer = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&NJPiGpuTimebase);
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, NJPiPDiagQueue());
        dispatch_source_set_event_handler(timer, ^{
            NJPiGpuSummaryTick();
        });
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC),
                                  30 * NSEC_PER_SEC,
                                  NSEC_PER_SEC);
        dispatch_resume(timer);
    });
}

#pragma mark - GPU composite: Metal setup





static const char *NJPiGpuMetalSource =
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct NJPipVert {\n"
"    float4 position [[position]];\n"
"    float2 texCoord;\n"
"};\n"
"vertex NJPipVert nj_pip_vertex(uint vertexID [[vertex_id]]) {\n"
"    // Fullscreen triangle. NDC y=+1 is row 0 of a Metal render target, so the V\n"
"    // coordinate is flipped here to keep the copy upright inside the CVPixelBuffer.\n"
"    float2 ndc[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };\n"
"    float2 uv[3]  = { float2(0.0, 1.0),   float2(2.0, 1.0),   float2(0.0, -2.0) };\n"
"    NJPipVert out;\n"
"    out.position = float4(ndc[vertexID], 0.0, 1.0);\n"
"    out.texCoord = uv[vertexID];\n"
"    return out;\n"
"}\n"
"fragment float4 nj_pip_copy_bgra(constant float *matrix [[buffer(0)]],\n"
"                                 NJPipVert in [[stage_in]],\n"
"                                 texture2d<float> plane [[texture(0)]],\n"
"                                 sampler s [[sampler(0)]]) {\n"
"    return plane.sample(s, in.texCoord);\n"
"}\n"
"fragment float4 nj_pip_copy_yuv(constant float *matrix [[buffer(0)]],\n"
"                                NJPipVert in [[stage_in]],\n"
"                                texture2d<float> planeY [[texture(0)]],\n"
"                                texture2d<float> planeUV [[texture(1)]],\n"
"                                sampler s [[sampler(0)]]) {\n"
"    float y = planeY.sample(s, in.texCoord).r;\n"
"    float2 c = planeUV.sample(s, in.texCoord).rg - float2(0.5, 0.5);\n"
"    float3 rgb;\n"
"    for (int i = 0; i < 3; i++) {\n"
"        rgb[i] = matrix[i * 4 + 0] * y + matrix[i * 4 + 1] * c.x + matrix[i * 4 + 2] * c.y\n"
"                 + matrix[i * 4 + 3];\n"
"    }\n"
"    // The matrix rows are R, G, B; a BGRA8Unorm render target maps x=B, y=G, z=R,\n"
"    // so the write order is reversed here. (The identity copy of a BGRA source needs\n"
"    // no swap: sampling and writing use the same channel order.)\n"
"    return float4(rgb[2], rgb[1], rgb[0], 1.0);\n"
"}\n"
"fragment float4 nj_pip_blend_bgra(constant float *matrix [[buffer(0)]],\n"
"                                  NJPipVert in [[stage_in]],\n"
"                                  texture2d<float> plane [[texture(0)]],\n"
"                                  sampler s [[sampler(0)]]) {\n"
"    return plane.sample(s, in.texCoord);\n"
"}\n";

static BOOL NJPiGpuPipelineAvailable(NSUInteger index) {
    if (index >= NJP_GPU_PIPELINE_COUNT || NJPiGpuPipelines[index]) {
        return NJPiGpuPipelines[index] != nil;
    }
    if (!NJPiGpuDevice) {
        return NO;
    }
    static const char *fragmentNames[NJP_GPU_PIPELINE_COUNT] = {
        "nj_pip_copy_bgra", "nj_pip_copy_yuv", "nj_pip_copy_yuv", "nj_pip_blend_bgra"
    };
    NSError *error = nil;
    
    static id<MTLLibrary> sharedLibrary = nil;
    if (!sharedLibrary) {
        sharedLibrary = [NJPiGpuDevice newLibraryWithSource:[NSString stringWithUTF8String:NJPiGpuMetalSource]
                                                    options:nil
                                                      error:&error];
    }
    id<MTLLibrary> library = sharedLibrary;
    if (!library) {
        NJPiGpuSetupFailure = "no-library";
        NJPiPDiag("gpu fail reason=init no-library err=%s", error.localizedDescription.UTF8String ?: "-");
        return NO;
    }
    id<MTLFunction> vertex = [library newFunctionWithName:@"nj_pip_vertex"];
    id<MTLFunction> fragment = [library newFunctionWithName:[NSString stringWithUTF8String:fragmentNames[index]]];
    if (!vertex || !fragment) {
        NJPiGpuSetupFailure = "no-function";
        return NO;
    }
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.label = @"njpip-danmaku";
    descriptor.vertexFunction = vertex;
    descriptor.fragmentFunction = fragment;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    if (index == 3) {
        
        
        
        descriptor.colorAttachments[0].blendingEnabled = YES;
        descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    }
    NSError *pipelineError = nil;
    NJPiGpuPipelines[index] = [NJPiGpuDevice newRenderPipelineStateWithDescriptor:descriptor
                                                                          error:&pipelineError];
    if (!NJPiGpuPipelines[index]) {
        NJPiGpuSetupFailure = "no-pipeline";
        NJPiPDiag("gpu fail reason=init no-pl idx=%lu err=%s",
                  (unsigned long)index, pipelineError.localizedDescription.UTF8String ?: "-");
        return NO;
    }
    return YES;
}

static void NJPiGpuSetup(void) {
    if (NJPiGpuSetupAttempted) {
        return;
    }
    NJPiGpuSetupAttempted = YES;
    NJPiGpuRegisterReasons();
    NJPiGpuDevice = MTLCreateSystemDefaultDevice();
    if (!NJPiGpuDevice) {
        NJPiGpuSetupFailure = "no-device";
        NJPiPDiag("gpu fail reason=init no-device");
        return;
    }
    CVReturn cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                                    NULL,
                                                    NJPiGpuDevice,
                                                    NULL,
                                                    &NJPiGpuTextureCache);
    if (cacheStatus != kCVReturnSuccess || !NJPiGpuTextureCache) {
        NJPiGpuDevice = nil;
        NJPiGpuSetupFailure = "no-texcache";
        NJPiPDiag("gpu fail reason=init no-texcache status=%d", cacheStatus);
        return;
    }
    NJPiGpuCommandQueue = [NJPiGpuDevice newCommandQueue];
    MTLSamplerDescriptor *samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    NJPiGpuSampler = [NJPiGpuDevice newSamplerStateWithDescriptor:samplerDescriptor];
    if (!NJPiGpuCommandQueue || !NJPiGpuSampler) {
        NJPiGpuSetupFailure = "no-queue";
        NJPiPDiag("gpu fail reason=init no-queue");
        return;
    }
    CVPixelBufferRef probe = NULL;
    NSDictionary<NSString *, id> *probeAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferWidthKey: @2,
        (NSString *)kCVPixelBufferHeightKey: @2,
        (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    if (CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)probeAttributes, &probe) == kCVReturnSuccess && probe) {
        CVMetalTextureRef probeTexture = NULL;
        if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, NJPiGpuTextureCache, probe, NULL,
                                                      MTLPixelFormatBGRA8Unorm, 2, 2, 0, &probeTexture) == kCVReturnSuccess
            && probeTexture) {
            CFRelease(probeTexture);
        }
        CVPixelBufferRelease(probe);
    }
    
    
    NJPiPDiag("gpu init device=%s texcache=ok",
              NJPiGpuDevice.name.UTF8String ?: "-");
}







static CVPixelBufferRef NJPiGpuTargetBuffer(CVImageBufferRef sourceImage) {
    NSUInteger width = CVPixelBufferGetWidth(sourceImage);
    NSUInteger height = CVPixelBufferGetHeight(sourceImage);
    OSType targetFormat = kCVPixelFormatType_32BGRA;
    if (!NJPiGpuPool || NJPiGpuPoolWidth != width || NJPiGpuPoolHeight != height
        || NJPiGpuPoolFormat != targetFormat) {
        if (NJPiGpuPool) {
            CVPixelBufferPoolRelease(NJPiGpuPool);
            NJPiGpuPool = NULL;
        }
        NSDictionary<NSString *, id> *attributes = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(targetFormat),
            (NSString *)kCVPixelBufferWidthKey: @(width),
            (NSString *)kCVPixelBufferHeightKey: @(height),
            (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
        };
        NSDictionary<NSString *, id> *poolAttributes = @{
            (NSString *)kCVPixelBufferPoolMinimumBufferCountKey: @(NJP_GPU_RING_COUNT + 1),
        };
        CVReturn status = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                                  (__bridge CFDictionaryRef)poolAttributes,
                                                  (__bridge CFDictionaryRef)attributes,
                                                  &NJPiGpuPool);
        if (status != kCVReturnSuccess || !NJPiGpuPool) {
            NJPiGpuPool = NULL;
            NJPiGpuNoteFailure("no-pool", NULL);
            return NULL;
        }
        NJPiGpuPoolWidth = width;
        NJPiGpuPoolHeight = height;
        NJPiGpuPoolFormat = targetFormat;
        NJPiPDiag("gpu pool size=%lux%lu fmt=%s min=%d",
                  (unsigned long)width, (unsigned long)height, NJPiGpuFourcc(targetFormat),
                  NJP_GPU_RING_COUNT + 1);
    }
    CVPixelBufferRef target = NULL;
    if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, NJPiGpuPool, &target) != kCVReturnSuccess
        || !target) {
        NJPiGpuNoteFailure("no-pool", NULL);
        return NULL;
    }
    return target;
}

#pragma mark - GPU composite: danmaku pixel source














typedef CVPixelBufferRef (*NJPiGpuCopyPixelBufferIMP)(id, SEL);

static CVPixelBufferRef NJPiGpuCallCopyPixelBuffer(id candidate) {
    if (!candidate) {
        return NULL;
    }
    SEL selector = @selector(copyPixelBuffer);
    if (![candidate respondsToSelector:selector]) {
        return NULL;
    }
    IMP implementation = [candidate methodForSelector:selector];
    if (!implementation) {
        return NULL;
    }
    return ((NJPiGpuCopyPixelBufferIMP)implementation)(candidate, selector);
}

static id NJPiGpuValueForKey(id object, NSString *key) {
    if (!object) {
        return nil;
    }
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}


















typedef id (*NJPiGpuObjectReturnIMP)(id, SEL);

static id NJPiGpuObjectGetter(id target, SEL selector) {
    if (!target) {
        return nil;
    }
    if (![target respondsToSelector:selector]) {
        return nil;
    }
    IMP implementation = [target methodForSelector:selector];
    if (!implementation) {
        return nil;
    }
    return ((NJPiGpuObjectReturnIMP)implementation)(target, selector);
}






static NSHashTable *NJPiGpuDanmakuServices(void) {
    static NSHashTable *services;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        services = [NSHashTable weakObjectsHashTable];
    });
    return services;
}

static void NJPiGpuRememberDanmakuService(id service) {
    if (!service) {
        return;
    }
    @synchronized (NJPiGpuDanmakuServices()) {
        if (NJPiGpuDanmakuServices().count >= 8) {
            return;
        }
        [NJPiGpuDanmakuServices() addObject:service];
    }
}





static NSHashTable *NJPiGpuDanmakuVouts(void) {
    static NSHashTable *vouts;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vouts = [NSHashTable weakObjectsHashTable];
    });
    return vouts;
}

static void NJPiGpuRememberDanmakuVout(id vout) {
    if (!vout) {
        return;
    }
    @synchronized (NJPiGpuDanmakuVouts()) {
        if (NJPiGpuDanmakuVouts().count >= 8) {
            return;
        }
        [NJPiGpuDanmakuVouts() addObject:vout];
    }
}



static id NJPiGpuOnlineRendererWrapper(const char **renderViewClass, const char **wrapperClass) {
    NSArray *services;
    @synchronized (NJPiGpuDanmakuServices()) {
        services = [NJPiGpuDanmakuServices() allObjects];
    }
    for (id service in services) {
        id context = NJPiGpuObjectGetter(service, @selector(context));
        if (!context) {
            continue;
        }
        id chronos = NJPiGpuObjectGetter(context, @selector(chronos));
        if (!chronos) {
            continue;
        }
        id renderView = NJPiGpuObjectGetter(chronos, @selector(chronosView));
        if (!renderView) {
            continue;
        }
        id wrapper = NJPiGpuObjectGetter(renderView, @selector(rendererWrapper));
        if (!wrapper) {
            continue;
        }
        if (renderViewClass) {
            *renderViewClass = object_getClassName(renderView);
        }
        if (wrapperClass) {
            *wrapperClass = object_getClassName(wrapper);
        }
        return wrapper;
    }
    return nil;
}





typedef void (*NJPiGpuUpdateSyncIMP)(id, SEL, double);
#define NJP_GPU_DRIVE_CLAMP_SECONDS 1.0
#define NJP_GPU_DRIVE_ONE_FRAME (1.0 / 30.0)

static void NJPiGpuDriveChronos(id wrapper) {
    SEL selector = @selector(updateSyncForTimeStep:);
    if (!wrapper) {
        return;
    }
    if (![wrapper respondsToSelector:selector]) {
        return;
    }
    IMP implementation = [wrapper methodForSelector:selector];
    if (!implementation) {
        return;
    }
    if (NJPiGpuTimebase.denom == 0) {
        mach_timebase_info(&NJPiGpuTimebase);
    }
    static __unsafe_unretained id drivenWrapper = nil;
    static uint64_t lastTick = 0;
    uint64_t now = mach_absolute_time();
    double seconds = 0.0;
    if (lastTick != 0 && drivenWrapper == wrapper) {
        seconds = NJPiGpuNanoseconds((unsigned long long)(now - lastTick)) / 1e9;
        if (seconds > NJP_GPU_DRIVE_CLAMP_SECONDS) {
            seconds = NJP_GPU_DRIVE_ONE_FRAME;
        }
    }
    lastTick = now;
    drivenWrapper = wrapper;
    ((NJPiGpuUpdateSyncIMP)implementation)(wrapper, selector, seconds);
}



static char NJPiGpuLastDanmakuRoute[64] = "";

static CVPixelBufferRef NJPiGpuAcceptDanmakuBuffer(CVPixelBufferRef pixelBuffer,
                                                   const char *route,
                                                   const char *ownerClass,
                                                   const char *detail,
                                                   CVImageBufferRef sourceImage) {
    if (!pixelBuffer) {
        return NULL;
    }
    if (strcmp(NJPiGpuLastDanmakuRoute, route) != 0) {
        snprintf(NJPiGpuLastDanmakuRoute, sizeof(NJPiGpuLastDanmakuRoute), "%s", route);
        NJPiPDiag("gpu dmsrc=%s dm=%s%s frame=%lux%lu dmsize=%lux%lu",
                  route,
                  ownerClass,
                  detail ? detail : "",
                  (unsigned long)CVPixelBufferGetWidth(sourceImage),
                  (unsigned long)CVPixelBufferGetHeight(sourceImage),
                  (unsigned long)CVPixelBufferGetWidth(pixelBuffer),
                  (unsigned long)CVPixelBufferGetHeight(pixelBuffer));
    }
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (format != kCVPixelFormatType_32BGRA) {
        
        
        NJPiGpuNoteFailure("fmt", NULL);
        NJPiPDiag("gpu fail reason=fmt dmfmt=%s size=%lux%lu",
                  NJPiGpuFourcc(format),
                  (unsigned long)CVPixelBufferGetWidth(pixelBuffer),
                  (unsigned long)CVPixelBufferGetHeight(pixelBuffer));
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
    return pixelBuffer;
}

static CVPixelBufferRef NJPiGpuDanmakuPixelBuffer(CVImageBufferRef sourceImage) {
    
    const char *renderViewClass = "unknown";
    const char *wrapperClass = "unknown";
    id wrapper = NJPiGpuOnlineRendererWrapper(&renderViewClass, &wrapperClass);
    if (wrapper) {
        NJPiGpuDriveChronos(wrapper);
        char detail[128];
        snprintf(detail, sizeof(detail), " rv=%s", renderViewClass);
        CVPixelBufferRef pixelBuffer = NJPiGpuAcceptDanmakuBuffer(
            NJPiGpuCallCopyPixelBuffer(wrapper),
            "online.bfccronrenderview",
            wrapperClass,
            detail,
            sourceImage);
        if (pixelBuffer) {
            return pixelBuffer;
        }
    }
    
    
    NSArray *vouts;
    @synchronized (NJPiGpuDanmakuVouts()) {
        vouts = [NJPiGpuDanmakuVouts() allObjects];
    }
    for (id vout in vouts) {
        id voutWrapper = NJPiGpuValueForKey(vout, @"rendererWrapper");
        CVPixelBufferRef pixelBuffer = NJPiGpuAcceptDanmakuBuffer(NJPiGpuCallCopyPixelBuffer(voutWrapper),
                                                                  "record.danmakuvout",
                                                                  object_getClassName(vout),
                                                                  NULL,
                                                                  sourceImage);
        if (pixelBuffer) {
            return pixelBuffer;
        }
    }
    
    
    
    NSArray<NJPiPOverlayState *> *states;
    @synchronized (NJPiPOverlayStates()) {
        states = [NJPiPOverlayStates() allObjects];
    }
    for (NJPiPOverlayState *state in states) {
        UIView *danmakuView = state.danmakuView;
        if (!danmakuView) {
            continue;
        }
        CALayer *danmakuLayer = danmakuView.layer;
        
        
        
        id holders[] = { danmakuView, danmakuLayer.delegate };
        for (NSUInteger index = 0; index < 2; index++) {
            id holder = holders[index];
            if (!holder) {
                continue;
            }
            CVPixelBufferRef pixelBuffer = NJPiGpuCallCopyPixelBuffer(holder);
            if (!pixelBuffer) {
                id fallbackWrapper = NJPiGpuValueForKey(holder, @"rendererWrapper");
                pixelBuffer = NJPiGpuCallCopyPixelBuffer(fallbackWrapper);
            }
            pixelBuffer = NJPiGpuAcceptDanmakuBuffer(pixelBuffer, "record.danmakuvout",
                                                     object_getClassName(holder), NULL, sourceImage);
            if (pixelBuffer) {
                return pixelBuffer;
            }
        }
    }
    return NULL;
}
















#pragma mark - GPU composite: the wrap

static BOOL NJPiGpuIsYUV(OSType format) {
    return format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
}




static void NJPiGpuYuvMatrix(OSType sourceFormat, BOOL bt709, float *matrix) {
    double kr = bt709 ? 0.2126 : 0.299;   
    double kb = bt709 ? 0.0722 : 0.114;
    double kg = 1.0 - kr - kb;
    BOOL fullRange = sourceFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    double yScale = fullRange ? 1.0 : 255.0 / 219.0;
    double yOffset = fullRange ? 0.0 : -16.0 / 219.0;
    double cScale = fullRange ? 1.0 : 255.0 / 224.0;
    double rOnCr = 2.0 * (1.0 - kr);
    double bOnCb = 2.0 * (1.0 - kb);
    double gOnCb = -(2.0 * kb * (1.0 - kb)) / kg;
    double gOnCr = -(2.0 * kr * (1.0 - kr)) / kg;
    double rOnCrScaled = rOnCr * cScale;
    double bOnCbScaled = bOnCb * cScale;
    double gOnCbScaled = gOnCb * cScale;
    double gOnCrScaled = gOnCr * cScale;
    matrix[0] = (float)yScale; matrix[1] = 0.0f;                matrix[2] = (float)rOnCrScaled; matrix[3] = (float)(yOffset - 0.5 * rOnCrScaled);
    matrix[4] = (float)yScale; matrix[5] = (float)gOnCbScaled;  matrix[6] = (float)gOnCrScaled; matrix[7] = (float)(yOffset - 0.5 * (gOnCbScaled + gOnCrScaled));
    matrix[8] = (float)yScale; matrix[9] = (float)bOnCbScaled;  matrix[10] = 0.0f;              matrix[11] = (float)(yOffset - 0.5 * bOnCbScaled);
    matrix[12] = 0.0f; matrix[13] = 0.0f; matrix[14] = 0.0f; matrix[15] = 1.0f;
}


static BOOL NJPiGpuWantsBT709(CVImageBufferRef image) {
    
    
    
    
    CFTypeRef value = CVBufferGetAttachment(image, kCVImageBufferYCbCrMatrixKey, NULL);
    BOOL bt709 = NO;
    if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
        bt709 = CFStringCompare((CFStringRef)value, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0)
                == kCFCompareEqualTo;
    }
    return bt709;
}




static id NJPiGpuComposite(id originalSampleObject) {
    CMSampleBufferRef original = (__bridge CMSampleBufferRef)originalSampleObject;
    CVImageBufferRef sourceImage = original ? CMSampleBufferGetImageBuffer(original) : NULL;
    if (!sourceImage) {
        NJPiGpuNoteFailure("no-pb", original);
        return originalSampleObject;
    }
    NJPiGpuSetup();
    if (!NJPiGpuTextureCache || !NJPiGpuCommandQueue) {
        return originalSampleObject;
    }
    OSType sourceFormat = CVPixelBufferGetPixelFormatType(sourceImage);
    NSUInteger width = CVPixelBufferGetWidth(sourceImage);
    NSUInteger height = CVPixelBufferGetHeight(sourceImage);
    BOOL yuv = NJPiGpuIsYUV(sourceFormat);
    NSUInteger pipelineIndex = 0;
    float matrix[16] = { 0 };
    if (sourceFormat == kCVPixelFormatType_32BGRA) {
        pipelineIndex = 0;
        NJPiGpuYuvMatrix(sourceFormat, NO, matrix);
    } else if (yuv) {
        BOOL bt709 = NJPiGpuWantsBT709(sourceImage);
        pipelineIndex = bt709 ? 2 : 1;
        NJPiGpuYuvMatrix(sourceFormat, bt709, matrix);
    } else {
        NJPiGpuNoteFailure("fmt", original);
        return originalSampleObject;
    }
    if (!NJPiGpuPipelineAvailable(pipelineIndex) || !NJPiGpuPipelineAvailable(3)) {
        return originalSampleObject;
    }
    CVPixelBufferRef targetImage = NJPiGpuTargetBuffer(sourceImage);
    if (!targetImage) {
        return originalSampleObject;
    }
    
    
    CVMetalTextureRef sourcePlaneY = NULL;
    CVMetalTextureRef sourcePlaneUV = NULL;
    CVMetalTextureRef targetTextureRef = NULL;
    CVMetalTextureRef danmakuTextureRef = NULL;
    CVPixelBufferRef danmakuImage = NULL;
    CMSampleBufferRef wrapped = NULL;
    BOOL submitted = NO;
    id wrappedObject = nil;
    unsigned long long startedAt = mach_absolute_time();
    do {
        MTLPixelFormat lumaFormat = yuv ? MTLPixelFormatR8Unorm : MTLPixelFormatBGRA8Unorm;
        if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, NJPiGpuTextureCache, sourceImage, NULL,
                                                      lumaFormat, (size_t)width, (size_t)height, 0,
                                                      &sourcePlaneY) != kCVReturnSuccess || !sourcePlaneY) {
            NJPiGpuNoteFailure("no-src-tex", original);
            break;
        }
        if (yuv) {
            if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, NJPiGpuTextureCache, sourceImage, NULL,
                                                          MTLPixelFormatRG8Unorm, (size_t)((width + 1) / 2),
                                                          (size_t)((height + 1) / 2), 1,
                                                          &sourcePlaneUV) != kCVReturnSuccess || !sourcePlaneUV) {
                NJPiGpuNoteFailure("no-src-tex", original);
                break;
            }
        }
        if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, NJPiGpuTextureCache, targetImage, NULL,
                                                      MTLPixelFormatBGRA8Unorm, (size_t)width, (size_t)height, 0,
                                                      &targetTextureRef) != kCVReturnSuccess || !targetTextureRef) {
            NJPiGpuNoteFailure("no-src-tex", original);
            break;
        }
        danmakuImage = NJPiGpuDanmakuPixelBuffer(sourceImage);
        if (!danmakuImage) {
            NJPiGpuNoteFailure("no-dm-pb", original);
            break;
        }
        if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, NJPiGpuTextureCache, danmakuImage, NULL,
                                                      MTLPixelFormatBGRA8Unorm,
                                                      (size_t)CVPixelBufferGetWidth(danmakuImage),
                                                      (size_t)CVPixelBufferGetHeight(danmakuImage), 0,
                                                      &danmakuTextureRef) != kCVReturnSuccess || !danmakuTextureRef) {
            NJPiGpuNoteFailure("no-dm-tex", original);
            break;
        }
        id<MTLCommandBuffer> commandBuffer = [NJPiGpuCommandQueue commandBuffer];
        if (!commandBuffer) {
            NJPiGpuNoteFailure("no-cb", original);
            break;
        }
        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = CVMetalTextureGetTexture(targetTextureRef);
        pass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
        if (!encoder) {
            NJPiGpuNoteFailure("no-enc", original);
            break;
        }
        [encoder setCullMode:MTLCullModeNone];
        
        
        MTLViewport viewport = { 0.0, 0.0, (double)width, (double)height, 0.0, 1.0 };
        [encoder setViewport:viewport];
        [encoder setFragmentSamplerState:NJPiGpuSampler atIndex:0];
        [encoder setFragmentBytes:matrix length:sizeof(matrix) atIndex:0];
        
        [encoder setRenderPipelineState:NJPiGpuPipelines[pipelineIndex]];
        [encoder setFragmentTexture:CVMetalTextureGetTexture(sourcePlaneY) atIndex:0];
        [encoder setFragmentTexture:yuv ? CVMetalTextureGetTexture(sourcePlaneUV) : nil atIndex:1];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        
        [encoder setRenderPipelineState:NJPiGpuPipelines[3]];
        [encoder setFragmentTexture:CVMetalTextureGetTexture(danmakuTextureRef) atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        CVMetalTextureCacheFlush(NJPiGpuTextureCache, 0);
        
        
        CFRetain(sourcePlaneY);
        if (sourcePlaneUV) {
            CFRetain(sourcePlaneUV);
        }
        CFRetain(targetTextureRef);
        CFRetain(danmakuTextureRef);
        submitted = YES;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            CFRelease(sourcePlaneY);
            if (sourcePlaneUV) {
                CFRelease(sourcePlaneUV);
            }
            CFRelease(targetTextureRef);
            CFRelease(danmakuTextureRef);
        }];
        [commandBuffer commit];
        
        
        double elapsedNs = NJPiGpuNanoseconds(mach_absolute_time() - startedAt);
        if (elapsedNs > 0.0) {
            NJPiGpuDurationNs += (unsigned long long)elapsedNs;
            if ((unsigned long long)elapsedNs > NJPiGpuMaxDurationNs) {
                NJPiGpuMaxDurationNs = (unsigned long long)elapsedNs;
            }
        }
        
        
        
        
        
        
        
        
        
        CFDictionaryRef sourceImageAttachments = CVBufferGetAttachments(sourceImage, kCVAttachmentMode_ShouldPropagate);
        if (sourceImageAttachments && CFDictionaryGetCount(sourceImageAttachments) > 0) {
            CVBufferSetAttachments(targetImage, sourceImageAttachments, kCVAttachmentMode_ShouldPropagate);
        }
        
        
        CMVideoFormatDescriptionRef formatDescription = NULL;
        if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, targetImage, &formatDescription) != noErr
            || !formatDescription) {
            NJPiGpuNoteFailure("wrap", original);
            break;
        }
        CMSampleTimingInfo timing = { kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid };
        if (CMSampleBufferGetSampleTimingInfo(original, 0, &timing) != noErr) {
            timing.duration = CMSampleBufferGetDuration(original);
            timing.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(original);
            timing.decodeTimeStamp = kCMTimeInvalid;
        }
        
        
        
        
        OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, targetImage,
                                                                  formatDescription, &timing, &wrapped);
        CFRelease(formatDescription);
        if (status != noErr || !wrapped) {
            NJPiGpuNoteFailure("wrap", original);
            break;
        }
        CFArrayRef sourceAttachments = CMSampleBufferGetSampleAttachmentsArray(original, false);
        if (sourceAttachments) {
            CFArrayRef targetAttachments = CMSampleBufferGetSampleAttachmentsArray(wrapped, true);
            CFIndex count = MIN(CFArrayGetCount(sourceAttachments), CFArrayGetCount(targetAttachments));
            for (CFIndex index = 0; index < count; index++) {
                CFMutableDictionaryRef target = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(targetAttachments, index);
                CFDictionaryRef source = (CFDictionaryRef)CFArrayGetValueAtIndex(sourceAttachments, index);
                CFIndex keyCount = CFDictionaryGetCount(source);
                if (keyCount <= 0 || keyCount > 32) {
                    continue;
                }
                const void *keys[32];
                const void *values[32];
                CFDictionaryGetKeysAndValues(source, keys, values);
                for (CFIndex key = 0; key < keyCount; key++) {
                    CFDictionarySetValue(target, keys[key], values[key]);
                }
            }
        }
        wrappedObject = CFBridgingRelease(wrapped); 
        wrapped = NULL;
        
        
        NSUInteger slot = NJPiGpuRingNext;
        NJPiGpuRingNext = (NJPiGpuRingNext + 1) % NJP_GPU_RING_COUNT;
        if (NJPiGpuRing[slot]) {
            CFRelease(NJPiGpuRing[slot]);
        }
        NJPiGpuRing[slot] = (CMSampleBufferRef)CFBridgingRetain(wrappedObject);
        NJPiGpuOkFrames += 1;
        NJPiGpuOkPixels += (unsigned long long)width * (unsigned long long)height;
    } while (0);
    if (!submitted) {
        if (sourcePlaneY) {
            CFRelease(sourcePlaneY);
        }
        if (sourcePlaneUV) {
            CFRelease(sourcePlaneUV);
        }
        if (targetTextureRef) {
            CFRelease(targetTextureRef);
        }
        if (danmakuTextureRef) {
            CFRelease(danmakuTextureRef);
        }
    }
    if (danmakuImage) {
        CVPixelBufferRelease(danmakuImage);
    }
    if (targetImage) {
        CVPixelBufferRelease(targetImage);
    }
    if (wrapped) {
        CFRelease(wrapped);
    }
    if (!wrappedObject) {
        return originalSampleObject;
    }
    return wrappedObject;
}

#pragma mark - GPU composite: PiP activity gate



static BOOL NJPiGpuPiPActive(void) {
    NSArray<NJPiPOverlayState *> *overlayStates;
    @synchronized (NJPiPOverlayStates()) {
        overlayStates = [NJPiPOverlayStates() allObjects];
    }
    for (NJPiPOverlayState *state in overlayStates) {
        AVPictureInPictureController *controller = state.controller;
        if (controller && controller.pictureInPictureActive) {
            return YES;
        }
    }
    NSArray<NJPiPMirrorState *> *mirrorStates;
    @synchronized (NJPiPMirrorStates()) {
        mirrorStates = [NJPiPMirrorStates() allObjects];
    }
    for (NJPiPMirrorState *state in mirrorStates) {
        AVPictureInPictureController *controller = state.controller;
        if (state.isPresenting || (controller && controller.pictureInPictureActive)) {
            return YES;
        }
    }
    return NO;
}







static const char *NJPiGpuPiPRole(id view) {
    Class sbdlClass = AVSampleBufferDisplayLayer.class;
    if (!sbdlClass) {
        return "nolayer";
    }
    CALayer *layer = nil;
    if ([view isKindOfClass:UIView.class]) {
        layer = ((UIView *)view).layer;
    }
    if (!layer || ![layer isKindOfClass:sbdlClass]) {
        return "not-sbdl";
    }
    NSArray<NJPiPOverlayState *> *states;
    @synchronized (NJPiPOverlayStates()) {
        states = [NJPiPOverlayStates() allObjects];
    }
    for (NJPiPOverlayState *state in states) {
        if (state.officialLayer == layer) {
            return "pip";
        }
    }
    return "untracked";
}

#pragma mark - GPU composite: hook installation

typedef void (*NJPiGpuEnqueueIMP)(id, SEL, id);
static NJPiGpuEnqueueIMP NJPiGpuOriginalEnqueueSmapleBuffer = NULL;
static NJPiGpuEnqueueIMP NJPiGpuOriginalEnqueueSampleBuffer = NULL;
static unsigned long long NJPiGpuHookHits = 0;
static unsigned long long NJPiGpuSkippedNotActive = 0;

static void NJPiGpuTrampoline(id self, SEL _cmd, id sampleBuffer, BOOL primary) {
    NJPiGpuHookHits += 1;
    id enqueued = sampleBuffer;
    
    
    
    
    
    const char *role = NJPiGpuPiPRole(self);
    BOOL active = NJPiGpuPiPActive();
    if (active && strcmp(role, "pip") == 0) {
        enqueued = NJPiGpuComposite(sampleBuffer);
    } else if (NJPiGpuSkippedNotActive < 5) {
        NJPiGpuSkippedNotActive += 1;
        CALayer *layer = [self isKindOfClass:UIView.class] ? ((UIView *)self).layer : nil;
        NJPiPDiag("gpu skip n=%llu pip=%d role=%s self=%s layerClass=%s layerAddr=%p",
                  NJPiGpuHookHits, (int)active, role, object_getClassName(self),
                  layer ? NJPiPClassName(layer) : "-", layer);
    }
    NJPiGpuEnqueueIMP *storage = primary ? &NJPiGpuOriginalEnqueueSmapleBuffer
                                         : &NJPiGpuOriginalEnqueueSampleBuffer;
    if (*storage) {
        (*storage)(self, _cmd, enqueued);
    }
}

static void NJPiGpuHookedEnqueueSmapleBuffer(id self, SEL _cmd, id sampleBuffer) {
    NJPiGpuTrampoline(self, _cmd, sampleBuffer, YES);
}

static void NJPiGpuHookedEnqueueSampleBuffer(id self, SEL _cmd, id sampleBuffer) {
    NJPiGpuTrampoline(self, _cmd, sampleBuffer, NO);
}



static Method NJPiGpuOwnMethodNamed(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method found = NULL;
    for (unsigned int index = 0; index < count; index++) {
        if (sel_isEqual(method_getName(methods[index]), selector)) {
            found = methods[index];
            break;
        }
    }
    free(methods);
    return found;
}

static void NJPiGpuInstallHooks(void) {
    
    
    
    
    
    
    
    
    
    
    
    const struct { const char *className; NSString *selectorName; } candidates[] = {
        { "IJKSDLSampleBufferView", @"enqueueSmapleBuffer:" },
        { "IJKSDLSampleBufferView", @"enqueueSampleBuffer:" },
        { "IJKSampleBufferWrapView", @"enqueueSmapleBuffer:" },
        { "IJKSampleBufferWrapView", @"enqueueSampleBuffer:" },
    };
    for (NSUInteger index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++) {
        Class cls = objc_lookUpClass(candidates[index].className);
        if (!cls) {
            continue;
        }
        SEL selector = NSSelectorFromString(candidates[index].selectorName);
        Method method = NJPiGpuOwnMethodNamed(cls, selector);
        if (!method) {
            continue;
        }
        IMP implementation = method_getImplementation(method);
        if (!implementation) {
            continue;
        }
        BOOL primary = [candidates[index].selectorName isEqualToString:@"enqueueSmapleBuffer:"];
        NJPiGpuEnqueueIMP *storage = primary ? &NJPiGpuOriginalEnqueueSmapleBuffer
                                             : &NJPiGpuOriginalEnqueueSampleBuffer;
        if (*storage) {
            continue; 
        }
        *storage = (NJPiGpuEnqueueIMP)implementation;
        IMP replacement = primary ? (IMP)NJPiGpuHookedEnqueueSmapleBuffer
                                  : (IMP)NJPiGpuHookedEnqueueSampleBuffer;
        method_setImplementation(method, replacement);
        NJPiPDiag("gpu hook cls=%s sel=%s orig=%p replaced=1",
                  class_getName(cls), candidates[index].selectorName.UTF8String, *storage);
    }
    if (!NJPiGpuOriginalEnqueueSmapleBuffer && !NJPiGpuOriginalEnqueueSampleBuffer) {
        NJPiPDiag("gpu hook none reason=no-enqueue-selector");
    }
}



static void NJPiGpuStart(void) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    
    
    NJPiPDiag("gpu load skipped reason=mixed-offscreen-enabled");
    return;
#endif
    if (!NJPiPDanmakuEnabled()) {
        NJPiPDiag("gpu load skipped feature-off");
        return;
    }
    NJPiGpuStartSummary();
    NJPiGpuInstallHooks();
}

#endif 

#if NJ_PIP_MIXED_OFFSCREEN_ENABLED

#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import <mach/mach_time.h>
#import <string.h>
#import <stdio.h>
#import <stdlib.h>
















#pragma mark - Mixed offscreen: state and diagnostics


#define NJP_MX_ROUTE_NONE 0
#define NJP_MX_ROUTE_PASS 1
#define NJP_MX_ROUTE_IMAGE 2
static NSUInteger NJPiMxRoute = NJP_MX_ROUTE_NONE;
static BOOL NJPiMxInitLogged = NO;

static CVPixelBufferPoolRef NJPiMxPool = NULL;
static NSUInteger NJPiMxPoolWidth = 0;
static NSUInteger NJPiMxPoolHeight = 0;
static CVMetalTextureCacheRef NJPiMxTextureCache = NULL;
static id<MTLDevice> NJPiMxDevice = nil;          
static id<MTLCommandQueue> NJPiMxCommandQueue = nil;
static id<MTLSamplerState> NJPiMxSampler = nil;
static id<MTLRenderPipelineState> NJPiMxOwnPipelineCopy = nil;
static id<MTLRenderPipelineState> NJPiMxOwnPipelineBlend = nil;
static const char *NJPiMxSetupFailure = NULL;


static const char *NJPiMxFailViewClass = "-";
static const char *NJPiMxLastPLQ = "-";




#define NJP_MX_RING_COUNT 4
static CMSampleBufferRef NJPiMxRing[NJP_MX_RING_COUNT];
static NSUInteger NJPiMxRingNext = 0;

static const char *NJPiMxFourcc(OSType format) {
    static char buffer[5];
    buffer[0] = (char)((format >> 24) & 0xFF);
    buffer[1] = (char)((format >> 16) & 0xFF);
    buffer[2] = (char)((format >> 8) & 0xFF);
    buffer[3] = (char)(format & 0xFF);
    buffer[4] = '\0';
    return buffer;
}





#define NJP_MX_MAX_REASONS 16
static const char *NJPiMxReasonNames[NJP_MX_MAX_REASONS];
static unsigned long long NJPiMxReasonHits[NJP_MX_MAX_REASONS];
static NSUInteger NJPiMxReasonCount = 0;

static void NJPiMxRegisterReasons(void) {
    if (NJPiMxReasonCount > 0) {
        return;
    }
    
    
    const char *reasons[] = { "no_view", "no_tex", "no_pool", "fmt",
                              "no_metal", "no_img", "no_pb", "no_texref",
                              "no_cb", "no_enc", "no_ivar", "wrap", "other" };
    for (NSUInteger index = 0; index < NJP_MX_MAX_REASONS; index++) {
        NJPiMxReasonNames[index] = index < sizeof(reasons) / sizeof(reasons[0])
                                     ? reasons[index] : NULL;
    }
    NJPiMxReasonCount = sizeof(reasons) / sizeof(reasons[0]);
}

static void NJPiMxNoteFailure(const char *reason, CMSampleBufferRef sampleBuffer) {
    NJPiMxRegisterReasons();
    NSUInteger slot = NJP_MX_MAX_REASONS - 1; 
    for (NSUInteger index = 0; index < NJPiMxReasonCount; index++) {
        if (NJPiMxReasonNames[index] && strcmp(NJPiMxReasonNames[index], reason) == 0) {
            slot = index;
            break;
        }
    }
    NJPiMxReasonHits[slot] += 1;
    if (NJPiMxReasonHits[slot] <= 20) {
        CVImageBufferRef imageBuffer = sampleBuffer ? CMSampleBufferGetImageBuffer(sampleBuffer) : NULL;
        NJPiPDiag("mx fail reason=%s n=%llu pb=%d fmt=%s size=%lux%lu route=%lu cls=%s",
                  reason,
                  NJPiMxReasonHits[slot],
                  imageBuffer ? 1 : 0,
                  imageBuffer ? NJPiMxFourcc(CVPixelBufferGetPixelFormatType(imageBuffer)) : "-",
                  imageBuffer ? (unsigned long)CVPixelBufferGetWidth(imageBuffer) : 0,
                  imageBuffer ? (unsigned long)CVPixelBufferGetHeight(imageBuffer) : 0,
                  (unsigned long)NJPiMxRoute,
                  NJPiMxFailViewClass);
    }
}







static unsigned long long NJPiMxEnteredFrames = 0;
static unsigned long long NJPiMxOkFrames = 0;
static unsigned long long NJPiMxDurationNs = 0;
static unsigned long long NJPiMxMaxDurationNs = 0;
static mach_timebase_info_data_t NJPiMxTimebase;
static unsigned long long NJPiMxSummaryLastIn = 0;
static unsigned long long NJPiMxSummaryLastOk = 0;
static unsigned long long NJPiMxSummaryLastFail = 0;



static unsigned long long NJPiMxExtChanges = 0;
static unsigned long long NJPiMxRendChanges = 0;

static unsigned long long NJPiMxFailTotal(void) {
    unsigned long long total = 0;
    for (NSUInteger index = 0; index < NJPiMxReasonCount; index++) {
        total += NJPiMxReasonHits[index];
    }
    return total;
}

static double NJPiMxNanoseconds(unsigned long long ticks) {
    if (NJPiMxTimebase.denom == 0) {
        return 0.0;
    }
    return (double)ticks * (double)NJPiMxTimebase.numer / (double)NJPiMxTimebase.denom;
}

static void NJPiMxSummaryTick(void) {
    NJPiMxRegisterReasons();
    unsigned long long failTotal = NJPiMxFailTotal();
    if (NJPiMxEnteredFrames == NJPiMxSummaryLastIn && NJPiMxOkFrames == NJPiMxSummaryLastOk
        && failTotal == NJPiMxSummaryLastFail) {
        return;
    }
    unsigned long long inDelta = NJPiMxEnteredFrames - NJPiMxSummaryLastIn;
    unsigned long long okDelta = NJPiMxOkFrames - NJPiMxSummaryLastOk;
    NJPiMxSummaryLastIn = NJPiMxEnteredFrames;
    NJPiMxSummaryLastOk = NJPiMxOkFrames;
    NJPiMxSummaryLastFail = failTotal;
    
    double avgMilliseconds = okDelta > 0
        ? ((double)NJPiMxDurationNs / (double)okDelta) / 1e6
        : 0.0;
    double maxMilliseconds = ((double)NJPiMxMaxDurationNs) / 1e6;
    NSMutableString *counts = [NSMutableString string];
    for (NSUInteger index = 0; index < NJPiMxReasonCount; index++) {
        if (NJPiMxReasonHits[index] > 0) {
            [counts appendFormat:@",%s=%llu", NJPiMxReasonNames[index], NJPiMxReasonHits[index]];
        }
    }
    static const char *routeNames[] = { "none", "pass", "image" };
    const char *routeName = NJPiMxRoute < sizeof(routeNames) / sizeof(routeNames[0])
                                    ? routeNames[NJPiMxRoute] : "?";
    
    
    NJPiPDiag("mx sum win=%llu out=%llu fail=%llu ms=%.2f msmax=%.2f route=%s "
              "exchg=%llu rendchg=%llu setup=%s view=%d plq=%s fails=%s",
              inDelta, okDelta, failTotal, avgMilliseconds, maxMilliseconds, routeName,
              NJPiMxExtChanges, NJPiMxRendChanges,
              NJPiMxSetupFailure ?: "ok",
              NJPiMCapturedView() ? 1 : 0, NJPiMxLastPLQ,
              counts.UTF8String ?: "-");
    NJPiMxMaxDurationNs = 0;
    NJPiMxDurationNs = 0;
}

static void NJPiMxStartSummary(void) {
    static dispatch_source_t timer = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&NJPiMxTimebase);
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, NJPiPDiagQueue());
        dispatch_source_set_event_handler(timer, ^{
            NJPiMxSummaryTick();
        });
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                                  5 * NSEC_PER_SEC,
                                  NSEC_PER_SEC);
        dispatch_resume(timer);
    });
}

#pragma mark - Mixed offscreen: finding the live cron view





typedef id (*NJPiMxObjectReturnIMP)(id, SEL);

static id NJPiMxObjectGetter(id target, SEL selector) {
    if (!target) {
        return nil;
    }
    if (![target respondsToSelector:selector]) {
        return nil;
    }
    IMP implementation = [target methodForSelector:selector];
    if (!implementation) {
        return nil;
    }
    return ((NJPiMxObjectReturnIMP)implementation)(target, selector);
}

static id NJPiMxValueForKey(id object, NSString *key) {
    if (!object) {
        return nil;
    }
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSHashTable *NJPiMxDanmakuServices(void) {
    static NSHashTable *services;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        services = [NSHashTable weakObjectsHashTable];
    });
    return services;
}

static void NJPiMxRememberDanmakuService(id service) {
    if (!service) {
        return;
    }
    @synchronized (NJPiMxDanmakuServices()) {
        if (NJPiMxDanmakuServices().count >= 8) {
            return;
        }
        [NJPiMxDanmakuServices() addObject:service];
    }
}



static id NJPiMxFindCronView(const char **viewClass) {
    
    
    id captured = NJPiMCapturedView();
    if (captured) {
        if (viewClass) {
            *viewClass = object_getClassName(captured);
        }
        NJPiMxFailViewClass = *viewClass;
        return captured;
    }
    NSArray *services;
    @synchronized (NJPiMxDanmakuServices()) {
        services = [NJPiMxDanmakuServices() allObjects];
    }
    for (id service in services) {
        id context = NJPiMxObjectGetter(service, @selector(context));
        if (!context) {
            continue;
        }
        id chronos = NJPiMxObjectGetter(context, @selector(chronos));
        if (!chronos) {
            continue;
        }
        id renderView = NJPiMxObjectGetter(chronos, @selector(chronosView));
        if (!renderView) {
            continue;
        }
        if (viewClass) {
            *viewClass = object_getClassName(renderView);
        }
        NJPiMxFailViewClass = *viewClass;
        return renderView;
    }
    return nil;
}

#pragma mark - Mixed offscreen: the view's own Metal objects








static void NJPiMxScanIvarNames(id view, NSMutableArray<NSString *> *names) {
    Class cls = view ? [view class] : nil;
    while (cls && cls != [UIView class]) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int index = 0; index < count; index++) {
            const char *ivarName = ivar_getName(ivars[index]);
            const char *ivarType = ivar_getTypeEncoding(ivars[index]);
            if (!ivarName || !ivarType || !strchr(ivarType, '@')) {
                continue; 
            }
            [names addObject:[NSString stringWithUTF8String:ivarName] ?: @""];
        }
        free(ivars);
        cls = class_getSuperclass(cls);
    }
}

static BOOL NJPiMxValueConforms(id value, Protocol *protocol) {
    if (!value || !protocol) {
        return NO;
    }
    Class valueClass = [value class];
    return valueClass ? class_conformsToProtocol(valueClass, protocol) : NO;
}

struct NJPiMxMetalObjects {
    id device;
    id commandQueue;
    id pipelineState;
    id renderPass;
    NSString *deviceName;
    NSString *queueName;
    NSString *pipelineName;
    NSString *passName;
};



static void NJPiMxDiscoverMetal(id view, struct NJPiMxMetalObjects *out) {
    static NSString *const deviceKeys[] = { @"_device", @"_metalDevice", @"_mtlDevice" };
    static NSString *const queueKeys[] = { @"_commandQueue", @"_cmdQueue" };
    static NSString *const pipelineKeys[] = { @"_pipelineState", @"_renderPipelineState", @"_pipeline" };
    static NSString *const passKeys[] = { @"_renderPass", @"_passDescriptor" };
    for (NSUInteger index = 0; index < sizeof(deviceKeys) / sizeof(deviceKeys[0]); index++) {
        id value = NJPiMxValueForKey(view, deviceKeys[index]);
        if (NJPiMxValueConforms(value, @protocol(MTLDevice))) { out->device = value; out->deviceName = deviceKeys[index]; break; }
    }
    for (NSUInteger index = 0; index < sizeof(queueKeys) / sizeof(queueKeys[0]); index++) {
        id value = NJPiMxValueForKey(view, queueKeys[index]);
        if (NJPiMxValueConforms(value, @protocol(MTLCommandQueue))) { out->commandQueue = value; out->queueName = queueKeys[index]; break; }
    }
    for (NSUInteger index = 0; index < sizeof(pipelineKeys) / sizeof(pipelineKeys[0]); index++) {
        id value = NJPiMxValueForKey(view, pipelineKeys[index]);
        if (NJPiMxValueConforms(value, @protocol(MTLRenderPipelineState))) { out->pipelineState = value; out->pipelineName = pipelineKeys[index]; break; }
    }
    for (NSUInteger index = 0; index < sizeof(passKeys) / sizeof(passKeys[0]); index++) {
        id value = NJPiMxValueForKey(view, passKeys[index]);
        if (value && [value isKindOfClass:NSClassFromString(@"MTLRenderPassDescriptor")]) {
            out->renderPass = value; out->passName = passKeys[index];
            break;
        }
    }
    if (out->device && out->commandQueue && out->pipelineState && out->renderPass) {
        return; 
    }
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    NJPiMxScanIvarNames(view, names);
    for (NSString *name in names) {
        id value = NJPiMxValueForKey(view, name);
        if (!value) {
            continue;
        }
        if (!out->device && NJPiMxValueConforms(value, @protocol(MTLDevice))) {
            out->device = value;
            out->deviceName = name;
            continue;
        }
        if (!out->commandQueue && NJPiMxValueConforms(value, @protocol(MTLCommandQueue))) {
            out->commandQueue = value;
            out->queueName = name;
            continue;
        }
        if (!out->pipelineState && NJPiMxValueConforms(value, @protocol(MTLRenderPipelineState))) {
            out->pipelineState = value;
            out->pipelineName = name;
            continue;
        }
        if (!out->renderPass && [value isKindOfClass:NSClassFromString(@"MTLRenderPassDescriptor")]) {
            out->renderPass = value;
            out->passName = name;
            continue;
        }
    }
}




static id<MTLTexture> NJPiMxViewTexture(id view, NSString *ivarName) {
    id value = NJPiMxValueForKey(view, ivarName);
    if (!NJPiMxValueConforms(value, @protocol(MTLTexture))) {
        return nil;
    }
    return (id<MTLTexture>)value;
}













static id NJPiMCapturedViewInstance = nil;
static const char *NJPiMCapturedVia = NULL;
static void *NJPiMSeenViews[4];          
static NSUInteger NJPiMSeenCount = 0;
static NSUInteger NJPiMCaptureLogs = 0;

static id NJPiMCapturedView(void) {
    return NJPiMCapturedViewInstance;
}

static void NJPiMxForgetCapturedViews(const char *why) {
    if (!NJPiMCapturedViewInstance) {
        return;
    }
    NJPiPDiag("mx view forget why=%s cls=%s addr=%p", why,
              object_getClassName(NJPiMCapturedViewInstance), NJPiMCapturedViewInstance);
    NJPiMCapturedViewInstance = nil;
    NJPiMCapturedVia = NULL;
}


static BOOL NJPiMIvarPresent(id view, const char *name) {
    Class cls = view ? [view class] : Nil;
    while (cls && cls != [UIView class]) {
        if (class_getInstanceVariable(cls, name)) {
            return YES;
        }
        cls = class_getSuperclass(cls);
    }
    return NO;
}

static BOOL NJPiMViewHasTextureIvars(id view) {
    return NJPiMIvarPresent(view, "_externalTexture") || NJPiMIvarPresent(view, "_rendererTexture");
}



static void NJPiMProbeViewObjects(id view, const char *why) {
    static NSUInteger probes = 0;
    if (!view || probes >= 3) {
        return;
    }
    probes += 1;
    struct NJPiMxMetalObjects metal = { nil, nil, nil, nil, nil, nil, nil, nil };
    NJPiMxDiscoverMetal(view, &metal);
    NJPiPDiag("mx view probe why=%s cls=%s addr=%p ext=%d rend=%d dev=%d q=%d pl=%d pass=%d img=%d sync=%d ivars=%d",
              why, object_getClassName(view), view,
              NJPiMxViewTexture(view, @"_externalTexture") ? 1 : 0,
              NJPiMxViewTexture(view, @"_rendererTexture") ? 1 : 0,
              metal.device ? 1 : 0, metal.commandQueue ? 1 : 0,
              metal.pipelineState ? 1 : 0, metal.renderPass ? 1 : 0,
              [view respondsToSelector:@selector(getMixedImage)] ? 1 : 0,
              [view respondsToSelector:NSSelectorFromString(@"_updateSyncForTimeStep:")] ? 1 : 0,
              NJPiMViewHasTextureIvars(view) ? 1 : 0);
}

static int NJPiMCaptureRank(const char *via) {
    if (!via) {
        return 0;
    }
    if (strcmp(via, "setExternalPixelBuffer:") == 0) {
        return 3;
    }
    if (strcmp(via, "updateGpuState") == 0) {
        return 2;
    }
    return 1; 
}

static void NJPiMCaptureFromHook(id instance, const char *via) {
    if (!instance) {
        return;
    }
    if (instance == NJPiMCapturedViewInstance) {
        return; 
    }
    int candidateRank = NJPiMCaptureRank(via);
    int currentRank = NJPiMCapturedViewInstance ? NJPiMCaptureRank(NJPiMCapturedVia) : 0;
    void *candidate = (__bridge void *)instance;
    BOOL seen = NO;
    for (NSUInteger index = 0; index < NJPiMSeenCount; index++) {
        if (NJPiMSeenViews[index] == candidate) {
            seen = YES;
            break;
        }
    }
    if (seen && candidateRank < currentRank) {
        return; 
    }
    if (NJPiMSeenCount < sizeof(NJPiMSeenViews) / sizeof(NJPiMSeenViews[0])) {
        NJPiMSeenViews[NJPiMSeenCount++] = candidate;
    }
    if (candidateRank < currentRank) {
        
        if (NJPiMCaptureLogs < 3) {
            NJPiMCaptureLogs += 1;
            NJPiPDiag("mx view extra cls=%s addr=%p sel=%s keep=%s@%p",
                      object_getClassName(instance), instance, via,
                      object_getClassName(NJPiMCapturedViewInstance), NJPiMCapturedViewInstance);
        }
        NJPiMProbeViewObjects(instance, via);
        return;
    }
    id previous = NJPiMCapturedViewInstance;
    NJPiMCapturedViewInstance = instance;
    NJPiMCapturedVia = via;
    NJPiMxFailViewClass = object_getClassName(instance);
    if (NJPiMCaptureLogs < 3) {
        NJPiMCaptureLogs += 1;
        NJPiPDiag("mx view cls=%s addr=%p sel=%s old=%p",
                  object_getClassName(instance), instance, via, previous);
    }
    NJPiMProbeViewObjects(instance, via);
}






typedef void (*NJPiMxViewSyncIMP)(id, SEL, double);
#define NJP_MX_DRIVE_CLAMP_SECONDS 1.0
#define NJP_MX_DRIVE_ONE_FRAME (1.0 / 30.0)

static void NJPiMxDriveViewChronos(id view) {
    SEL selector = NSSelectorFromString(@"_updateSyncForTimeStep:");
    if (!view || ![view respondsToSelector:selector]) {
        return;
    }
    IMP implementation = [view methodForSelector:selector];
    if (!implementation) {
        return;
    }
    if (NJPiMxTimebase.denom == 0) {
        mach_timebase_info(&NJPiMxTimebase);
    }
    static __unsafe_unretained id drivenView = nil;
    static uint64_t lastTick = 0;
    uint64_t now = mach_absolute_time();
    double seconds = 0.0;
    if (lastTick != 0 && drivenView == view) {
        seconds = NJPiMxNanoseconds((unsigned long long)(now - lastTick)) / 1e9;
        if (seconds > NJP_MX_DRIVE_CLAMP_SECONDS) {
            seconds = NJP_MX_DRIVE_ONE_FRAME;
        }
    }
    lastTick = now;
    drivenView = view;
    ((NJPiMxViewSyncIMP)implementation)(view, selector, seconds);
}

#pragma mark - Mixed offscreen: our own Metal fallbacks




static const char *NJPiMxMetalSource =
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct NJPipMxVert {\n"
"    float4 position [[position]];\n"
"    float2 texCoord;\n"
"};\n"
"vertex NJPipMxVert nj_pip_mx_vertex(uint vertexID [[vertex_id]]) {\n"
"    float2 ndc[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };\n"
"    float2 uv[3]  = { float2(0.0, 1.0),   float2(2.0, 1.0),   float2(0.0, -2.0) };\n"
"    NJPipMxVert out;\n"
"    out.position = float4(ndc[vertexID], 0.0, 1.0);\n"
"    out.texCoord = uv[vertexID];\n"
"    return out;\n"
"}\n"
"fragment float4 nj_pip_mx_copy(const NJPipMxVert in [[stage_in]],\n"
"                               texture2d<float> plane [[texture(0)]],\n"
"                               sampler s [[sampler(0)]]) {\n"
"    return plane.sample(s, in.texCoord);\n"
"}\n"
"fragment float4 nj_pip_mx_blend(const NJPipMxVert in [[stage_in]],\n"
"                                texture2d<float> plane [[texture(0)]],\n"
"                                sampler s [[sampler(0)]]) {\n"
"    return plane.sample(s, in.texCoord);\n"
"}\n";

static BOOL NJPiMxOwnPipelinesAvailable(void) {
    if (NJPiMxOwnPipelineCopy && NJPiMxOwnPipelineBlend) {
        return YES;
    }
    if (!NJPiMxDevice) {
        return NO;
    }
    NSError *error = nil;
    static id<MTLLibrary> library = nil;
    if (!library) {
        library = [NJPiMxDevice newLibraryWithSource:[NSString stringWithUTF8String:NJPiMxMetalSource]
                                             options:nil
                                               error:&error];
    }
    if (!library) {
        NJPiMxSetupFailure = "no-library";
        NJPiPDiag("mx fail reason=no_metal no-library err=%s", error.localizedDescription.UTF8String ?: "-");
        return NO;
    }
    id<MTLFunction> vertex = [library newFunctionWithName:@"nj_pip_mx_vertex"];
    id<MTLFunction> copyFunction = [library newFunctionWithName:@"nj_pip_mx_copy"];
    id<MTLFunction> blendFunction = [library newFunctionWithName:@"nj_pip_mx_blend"];
    if (!vertex || !copyFunction || !blendFunction) {
        NJPiMxSetupFailure = "no-function";
        return NO;
    }
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.label = @"njpip-mixed";
    descriptor.vertexFunction = vertex;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    NSError *pipelineError = nil;
    descriptor.fragmentFunction = copyFunction;
    NJPiMxOwnPipelineCopy = [NJPiMxDevice newRenderPipelineStateWithDescriptor:descriptor
                                                                       error:&pipelineError];
    if (!NJPiMxOwnPipelineCopy) {
        NJPiMxSetupFailure = "no-pipeline-copy";
        NJPiPDiag("mx fail reason=no_metal no-pl-copy err=%s", pipelineError.localizedDescription.UTF8String ?: "-");
        return NO;
    }
    descriptor.fragmentFunction = blendFunction;
    
    
    
    descriptor.colorAttachments[0].blendingEnabled = YES;
    descriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    descriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    NJPiMxOwnPipelineBlend = [NJPiMxDevice newRenderPipelineStateWithDescriptor:descriptor
                                                                        error:&pipelineError];
    if (!NJPiMxOwnPipelineBlend) {
        NJPiMxSetupFailure = "no-pipeline-blend";
        NJPiPDiag("mx fail reason=no_metal no-pl-blend err=%s", pipelineError.localizedDescription.UTF8String ?: "-");
        return NO;
    }
    return YES;
}

static void NJPiMxEnsureOwnDevice(void) {
    if (NJPiMxDevice) {
        return;
    }
    NJPiMxDevice = MTLCreateSystemDefaultDevice();
    if (!NJPiMxDevice) {
        NJPiMxSetupFailure = "no-device";
        NJPiPDiag("mx fail reason=no_metal no-device");
        return;
    }
    NJPiMxCommandQueue = [NJPiMxDevice newCommandQueue];
    MTLSamplerDescriptor *samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    NJPiMxSampler = [NJPiMxDevice newSamplerStateWithDescriptor:samplerDescriptor];
    if (!NJPiMxCommandQueue || !NJPiMxSampler) {
        NJPiMxSetupFailure = "no-queue";
        NJPiPDiag("mx fail reason=no_metal no-queue");
    }
}





static CVPixelBufferRef NJPiMxTargetBuffer(NSUInteger width, NSUInteger height) {
    if (!NJPiMxPool || NJPiMxPoolWidth != width || NJPiMxPoolHeight != height) {
        if (NJPiMxPool) {
            CVPixelBufferPoolRelease(NJPiMxPool);
            NJPiMxPool = NULL;
        }
        NSDictionary<NSString *, id> *attributes = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (NSString *)kCVPixelBufferWidthKey: @(width),
            (NSString *)kCVPixelBufferHeightKey: @(height),
            (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
        };
        NSDictionary<NSString *, id> *poolAttributes = @{
            (NSString *)kCVPixelBufferPoolMinimumBufferCountKey: @(NJP_MX_RING_COUNT + 1),
        };
        CVReturn status = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                                  (__bridge CFDictionaryRef)poolAttributes,
                                                  (__bridge CFDictionaryRef)attributes,
                                                  &NJPiMxPool);
        if (status != kCVReturnSuccess || !NJPiMxPool) {
            NJPiMxPool = NULL;
            NJPiMxNoteFailure("no_pool", NULL);
            return NULL;
        }
        NJPiMxPoolWidth = width;
        NJPiMxPoolHeight = height;
        NJPiPDiag("mx pool size=%lux%lu fmt=%s min=%d",
                  (unsigned long)width, (unsigned long)height,
                  NJPiMxFourcc(kCVPixelFormatType_32BGRA), NJP_MX_RING_COUNT + 1);
    }
    CVPixelBufferRef target = NULL;
    if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, NJPiMxPool, &target) != kCVReturnSuccess
        || !target) {
        NJPiMxNoteFailure("no_pool", NULL);
        return NULL;
    }
    return target;
}

static id<MTLTexture> NJPiMxTargetTexture(CVPixelBufferRef target, id<MTLDevice> device,
                                          CVMetalTextureRef *outTextureRef) {
    if (!NJPiMxTextureCache) {
        CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, device, NULL,
                                                    &NJPiMxTextureCache);
        if (status != kCVReturnSuccess || !NJPiMxTextureCache) {
            NJPiMxTextureCache = NULL;
            NJPiMxNoteFailure("no_metal", NULL);
            return nil;
        }
    }
    CVMetalTextureRef textureRef = NULL;
    if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, NJPiMxTextureCache, target, NULL,
                                                  MTLPixelFormatBGRA8Unorm,
                                                  (size_t)CVPixelBufferGetWidth(target),
                                                  (size_t)CVPixelBufferGetHeight(target), 0,
                                                  &textureRef) != kCVReturnSuccess || !textureRef) {
        NJPiMxNoteFailure("no_texref", NULL);
        return nil;
    }
    id<MTLTexture> texture = CVMetalTextureGetTexture(textureRef);
    *outTextureRef = textureRef; 
                                 
                                 
    return texture;
}

#pragma mark - Mixed offscreen: the composite

static id NJPiMxWrapProduced(CVPixelBufferRef targetImage, CVImageBufferRef sourceImage,
                             CMSampleBufferRef original); 




static BOOL NJPiMxViewLogged = NO;
static id NJPiMxCompositePass(id view, CMSampleBufferRef original, CVImageBufferRef sourceImage,
                              const char *viewClass) {
    struct NJPiMxMetalObjects metal = { nil, nil, nil, nil, nil, nil, nil, nil };
    NJPiMxDiscoverMetal(view, &metal);
    id<MTLTexture> externalTexture = NJPiMxViewTexture(view, @"_externalTexture");
    id<MTLTexture> rendererTexture = NJPiMxViewTexture(view, @"_rendererTexture");
    if (!externalTexture) {
        
        
        
        if (NJPiMViewHasTextureIvars(view)) {
            NJPiMProbeViewObjects(view, "no_tex");
            NJPiMxNoteFailure("no_tex", original);
        } else {
            NJPiMProbeViewObjects(view, "no_ivar");
            NJPiMxNoteFailure("no_ivar", original);
        }
        return nil;
    }
    static __unsafe_unretained id<MTLTexture> lastExternalTexture = nil;
    static __unsafe_unretained id<MTLTexture> lastRendererTexture = nil;
    static BOOL texturesSeen = NO;
    if (!texturesSeen || externalTexture != lastExternalTexture) {
        NJPiMxExtChanges += 1;
    }
    if (rendererTexture && (!texturesSeen || rendererTexture != lastRendererTexture)) {
        NJPiMxRendChanges += 1;
    }
    texturesSeen = YES;
    lastExternalTexture = externalTexture;
    lastRendererTexture = rendererTexture;
    
    id<MTLDevice> device = metal.device ?: nil;
    id<MTLCommandQueue> commandQueue = metal.commandQueue ?: nil;
    if (!device || !commandQueue) {
        NJPiMxEnsureOwnDevice();
        device = device ?: NJPiMxDevice;
        commandQueue = commandQueue ?: NJPiMxCommandQueue;
    }
    if (!device || !commandQueue) {
        NJPiMxNoteFailure("no_metal", original);
        return nil;
    }
    
    
    
    
    
    
    
    
    
    BOOL texturesAreBGRA = [externalTexture pixelFormat] == MTLPixelFormatBGRA8Unorm
        && (!rendererTexture || [rendererTexture pixelFormat] == MTLPixelFormatBGRA8Unorm);
    BOOL useOwnPipeline = texturesAreBGRA && NJPiMxOwnPipelinesAvailable();
    if (!useOwnPipeline && !metal.pipelineState) {
        NJPiMxNoteFailure("no_metal", original);
        return nil;
    }
    NJPiMxLastPLQ = useOwnPipeline ? "own" : "view";
    if (!NJPiMxViewLogged) {
        NJPiMxViewLogged = YES;
        
        
        
        NJPiPDiag("mx view cls=%s addr=%p ext=%d rend=%d dev=%d q=%d pl=%d pass=%d img=%d sync=%d plq=%s",
                  viewClass, view,
                  externalTexture ? 1 : 0, rendererTexture ? 1 : 0,
                  metal.device ? 1 : 0, metal.commandQueue ? 1 : 0,
                  metal.pipelineState ? 1 : 0, metal.renderPass ? 1 : 0,
                  [view respondsToSelector:NSSelectorFromString(@"getMixedImage")] ? 1 : 0,
                  [view respondsToSelector:NSSelectorFromString(@"_updateSyncForTimeStep:")] ? 1 : 0,
                  useOwnPipeline ? "own" : "view");
        NJPiPDiag("mx metal dev=%s q=%s pl=%s pass=%s",
                  metal.deviceName.UTF8String ?: "-", metal.queueName.UTF8String ?: "-",
                  metal.pipelineName.UTF8String ?: "-", metal.passName.UTF8String ?: "-");
    }
    
    
    
    
    
    
    NSString *deviceName = [device name];
    id externalDevice = nil;
    if ([externalTexture conformsToProtocol:@protocol(MTLTexture)]) {
        externalDevice = [(id<MTLTexture>)externalTexture device];
    }
    NSString *externalDeviceName = externalDevice ? [externalDevice name] : nil;
    if (deviceName && externalDeviceName && ![deviceName isEqual:externalDeviceName]) {
        NJPiMxNoteFailure("no_metal", original);
        NJPiPDiag("mx fail reason=no_metal dev-mismatch want=%s have=%s",
                  deviceName.UTF8String ?: "-", externalDeviceName.UTF8String ?: "-");
        return nil;
    }
    NSUInteger width = CVPixelBufferGetWidth(sourceImage);
    NSUInteger height = CVPixelBufferGetHeight(sourceImage);
    CVPixelBufferRef targetImage = NJPiMxTargetBuffer(width, height);
    if (!targetImage) {
        return nil;
    }
    CVMetalTextureRef targetTextureRef = NULL;
    id<MTLTexture> targetTexture = NJPiMxTargetTexture(targetImage, device, &targetTextureRef);
    if (!targetTexture) {
        if (targetTextureRef) {
            CFRelease(targetTextureRef); 
        }
        CVPixelBufferRelease(targetImage);
        return nil;
    }
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    if (!commandBuffer) {
        NJPiMxNoteFailure("no_cb", original);
        CVPixelBufferRelease(targetImage);
        return nil;
    }
    MTLRenderPassDescriptor *pass = metal.renderPass
        ? [metal.renderPass copy]
        : [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = targetTexture;
    pass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
    if (!encoder) {
        NJPiMxNoteFailure("no_enc", original);
        CVPixelBufferRelease(targetImage);
        return nil;
    }
    [encoder setCullMode:MTLCullModeNone];
    MTLViewport viewport = { 0.0, 0.0, (double)width, (double)height, 0.0, 1.0 };
    [encoder setViewport:viewport];
    if (NJPiMxSampler) {
        [encoder setFragmentSamplerState:NJPiMxSampler atIndex:0];
    }
    if (!useOwnPipeline) {
        
        
        
        
        
        [encoder setRenderPipelineState:metal.pipelineState];
        [encoder setFragmentTexture:externalTexture atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        if (rendererTexture) {
            [encoder setFragmentTexture:rendererTexture atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        }
    } else {
        
        
        [encoder setRenderPipelineState:NJPiMxOwnPipelineCopy];
        [encoder setFragmentTexture:externalTexture atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        if (rendererTexture) {
            [encoder setRenderPipelineState:NJPiMxOwnPipelineBlend];
            [encoder setFragmentTexture:rendererTexture atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        }
    }
    [encoder endEncoding];
    CVMetalTextureCacheFlush(NJPiMxTextureCache, 0);
    
    
    CFRetain(targetTextureRef);
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        CFRelease(targetTextureRef);
    }];
    [commandBuffer commit]; 
    id wrapped = NJPiMxWrapProduced(targetImage, sourceImage, original);
    CVPixelBufferRelease(targetImage);
    return wrapped;
}





typedef id (*NJPiMxGetImageIMP)(id, SEL);

static id NJPiMxCompositeImage(id view, CMSampleBufferRef original, CVImageBufferRef sourceImage) {
    SEL selector = NSSelectorFromString(@"getMixedImage");
    if (![view respondsToSelector:selector]) {
        NJPiMxNoteFailure("no_img", original);
        return nil;
    }
    IMP implementation = [view methodForSelector:selector];
    if (!implementation) {
        NJPiMxNoteFailure("no_img", original);
        return nil;
    }
    id mixed = ((NJPiMxGetImageIMP)implementation)(view, selector);
    Class uiImageClass = NSClassFromString(@"UIImage");
    if (!mixed || !uiImageClass || ![mixed isKindOfClass:uiImageClass]) {
        
        
        NJPiMProbeViewObjects(view, "no_img");
        NJPiMxNoteFailure("no_img", original);
        return nil;
    }
    
    
    CGImageRef cgImage = ((UIImage *)mixed).CGImage;
    if (!cgImage) {
        NJPiMxNoteFailure("no_img", original);
        return nil;
    }
    NSUInteger width = CVPixelBufferGetWidth(sourceImage);
    NSUInteger height = CVPixelBufferGetHeight(sourceImage);
    CVPixelBufferRef targetImage = NJPiMxTargetBuffer(width, height);
    if (!targetImage) {
        return nil;
    }
    id wrapped = nil;
    if (CVPixelBufferLockBaseAddress(targetImage, 0) == kCVReturnSuccess) {
        void *base = CVPixelBufferGetBaseAddress(targetImage);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(targetImage);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = base && colorSpace
            ? CGBitmapContextCreate(base, width, height, 8, bytesPerRow, colorSpace,
                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst)
            : NULL;
        if (context) {
            CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), cgImage);
            CGContextRelease(context);
            wrapped = NJPiMxWrapProduced(targetImage, sourceImage, original);
        } else {
            NJPiMxNoteFailure("fmt", original);
        }
        if (colorSpace) {
            CGColorSpaceRelease(colorSpace);
        }
        CVPixelBufferUnlockBaseAddress(targetImage, 0);
    } else {
        NJPiMxNoteFailure("no_pb", original);
    }
    CVPixelBufferRelease(targetImage);
    return wrapped;
}



static id NJPiMxWrapProduced(CVPixelBufferRef targetImage, CVImageBufferRef sourceImage,
                             CMSampleBufferRef original) {
    CMSampleBufferRef wrapped = NULL;
    id wrappedObject = nil;
    do {
        CFDictionaryRef sourceImageAttachments = CVBufferGetAttachments(sourceImage, kCVAttachmentMode_ShouldPropagate);
        if (sourceImageAttachments && CFDictionaryGetCount(sourceImageAttachments) > 0) {
            CVBufferSetAttachments(targetImage, sourceImageAttachments, kCVAttachmentMode_ShouldPropagate);
        }
        CMVideoFormatDescriptionRef formatDescription = NULL;
        if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, targetImage, &formatDescription) != noErr
            || !formatDescription) {
            NJPiMxNoteFailure("wrap", original);
            break;
        }
        CMSampleTimingInfo timing = { kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid };
        if (CMSampleBufferGetSampleTimingInfo(original, 0, &timing) != noErr) {
            timing.duration = CMSampleBufferGetDuration(original);
            timing.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(original);
            timing.decodeTimeStamp = kCMTimeInvalid;
        }
        OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, targetImage,
                                                                  formatDescription, &timing, &wrapped);
        CFRelease(formatDescription);
        if (status != noErr || !wrapped) {
            NJPiMxNoteFailure("wrap", original);
            break;
        }
        CFArrayRef sourceAttachments = CMSampleBufferGetSampleAttachmentsArray(original, false);
        if (sourceAttachments) {
            CFArrayRef targetAttachments = CMSampleBufferGetSampleAttachmentsArray(wrapped, true);
            CFIndex count = MIN(CFArrayGetCount(sourceAttachments), CFArrayGetCount(targetAttachments));
            for (CFIndex index = 0; index < count; index++) {
                CFMutableDictionaryRef target = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(targetAttachments, index);
                CFDictionaryRef source = (CFDictionaryRef)CFArrayGetValueAtIndex(sourceAttachments, index);
                CFIndex keyCount = CFDictionaryGetCount(source);
                if (keyCount <= 0 || keyCount > 32) {
                    continue;
                }
                const void *keys[32];
                const void *values[32];
                CFDictionaryGetKeysAndValues(source, keys, values);
                for (CFIndex key = 0; key < keyCount; key++) {
                    CFDictionarySetValue(target, keys[key], values[key]);
                }
            }
        }
        wrappedObject = CFBridgingRelease(wrapped);
        wrapped = NULL;
        NSUInteger slot = NJPiMxRingNext;
        NJPiMxRingNext = (NJPiMxRingNext + 1) % NJP_MX_RING_COUNT;
        if (NJPiMxRing[slot]) {
            CFRelease(NJPiMxRing[slot]);
        }
        NJPiMxRing[slot] = (CMSampleBufferRef)CFBridgingRetain(wrappedObject);
        NJPiMxOkFrames += 1;
    } while (0);
    if (wrapped) {
        CFRelease(wrapped);
    }
    return wrappedObject;
}

static id NJPiMxComposite(id originalSampleObject) {
    CMSampleBufferRef original = (__bridge CMSampleBufferRef)originalSampleObject;
    CVImageBufferRef sourceImage = original ? CMSampleBufferGetImageBuffer(original) : NULL;
    if (!sourceImage) {
        NJPiMxNoteFailure("no_pb", original);
        return originalSampleObject;
    }
    NJPiMxEnteredFrames += 1;
    OSType sourceFormat = CVPixelBufferGetPixelFormatType(sourceImage);
    if (sourceFormat != kCVPixelFormatType_32BGRA && sourceFormat != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        && sourceFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        NJPiMxNoteFailure("fmt", original);
        return originalSampleObject;
    }
    const char *viewClass = "unknown";
    id view = NJPiMxFindCronView(&viewClass);
    if (!view) {
        NJPiMxNoteFailure("no_view", original);
        return originalSampleObject;
    }
    
    
    
    
    
    NJPiMxDriveViewChronos(view);
    unsigned long long startedAt = mach_absolute_time();
    id wrapped = nil;
    if (NJPiMxRoute != NJP_MX_ROUTE_IMAGE) {
        wrapped = NJPiMxCompositePass(view, original, sourceImage, viewClass);
        if (wrapped && NJPiMxRoute != NJP_MX_ROUTE_PASS) {
            NJPiMxRoute = NJP_MX_ROUTE_PASS;
            if (!NJPiMxInitLogged) {
                NJPiMxInitLogged = YES;
                NJPiPDiag("mx init route=pass viewcls=%s pool=ok", viewClass);
            }
        }
    }
    if (!wrapped) {
        
        wrapped = NJPiMxCompositeImage(view, original, sourceImage);
        if (wrapped && NJPiMxRoute != NJP_MX_ROUTE_IMAGE) {
            NJPiMxRoute = NJP_MX_ROUTE_IMAGE;
            if (!NJPiMxInitLogged) {
                NJPiMxInitLogged = YES;
                NJPiPDiag("mx init route=image viewcls=%s pool=ok", viewClass);
            }
        }
    }
    double elapsedNs = NJPiMxNanoseconds(mach_absolute_time() - startedAt);
    if (elapsedNs > 0.0) {
        NJPiMxDurationNs += (unsigned long long)elapsedNs;
        if ((unsigned long long)elapsedNs > NJPiMxMaxDurationNs) {
            NJPiMxMaxDurationNs = (unsigned long long)elapsedNs;
        }
    }
    if (!wrapped) {
        return originalSampleObject;
    }
    return wrapped;
}

#pragma mark - Mixed offscreen: PiP activity gate (authoritative sources only)












typedef struct { BOOL active; const char *source; } NJPiMxGate;

static NJPiMxGate NJPiMxMakeGate(BOOL active, const char *source) {
    NJPiMxGate gate;
    gate.active = active;
    gate.source = source;
    return gate;
}

static NJPiMxGate NJPiMxPiPActive(void) {
    NSArray<NJPiPOverlayState *> *overlayStates;
    @synchronized (NJPiPOverlayStates()) {
        overlayStates = [NJPiPOverlayStates() allObjects];
    }
    for (NJPiPOverlayState *state in overlayStates) {
        if (state.pipStartedByCallback) {
            return NJPiMxMakeGate(YES, "controller-callback");
        }
    }
    for (NJPiPOverlayState *state in overlayStates) {
        AVPictureInPictureController *controller = state.controller;
        if (controller && controller.pictureInPictureActive) {
            return NJPiMxMakeGate(YES, "layer-probe");
        }
    }
    NSArray<NJPiPMirrorState *> *mirrorStates;
    @synchronized (NJPiPMirrorStates()) {
        mirrorStates = [NJPiPMirrorStates() allObjects];
    }
    for (NJPiPMirrorState *state in mirrorStates) {
        if (state.isPresenting) {
            return NJPiMxMakeGate(YES, "contentsource");
        }
        AVPictureInPictureController *controller = state.controller;
        if (controller && controller.pictureInPictureActive) {
            return NJPiMxMakeGate(YES, "layer-probe");
        }
    }
    return NJPiMxMakeGate(NO, "none");
}








static CALayer *NJPiMxDestinationLayer(id view) {
    if (!view) {
        return nil;
    }
    
    
    Ivar mLayerIvar = class_getInstanceVariable(object_getClass(view), "_mLayer");
    if (mLayerIvar) {
        id ivarValue = object_getIvar(view, mLayerIvar);
        if ([ivarValue isKindOfClass:CALayer.class]) {
            return (CALayer *)ivarValue;
        }
    }
    SEL getter = sel_registerName("getSampleBufferLayer");
    if ([view respondsToSelector:getter]) {
        IMP implementation = [view methodForSelector:getter];
        id value = implementation ? ((id (*)(id, SEL))implementation)(view, getter) : nil;
        if (value) {
            return (CALayer *)value;
        }
    }
    if ([view isKindOfClass:UIView.class]) {
        CALayer *layer = ((UIView *)view).layer;
        if ([layer isKindOfClass:AVSampleBufferDisplayLayer.class]) {
            return layer;
        }
    }
    return nil;
}


static CALayer *NJPiMxTrackedPiPLayer(CALayer *needle, BOOL *matched) {
    CALayer *first = nil;
    *matched = NO;
    NSArray<NJPiPOverlayState *> *states;
    @synchronized (NJPiPOverlayStates()) {
        states = [NJPiPOverlayStates() allObjects];
    }
    for (NJPiPOverlayState *state in states) {
        CALayer *official = state.officialLayer;
        if (!official) {
            continue;
        }
        if (!first) {
            first = official;
        }
        if (needle && official == needle) {
            *matched = YES;
        }
    }
    return first;
}






static const char *NJPiMxRoleFor(id view, CALayer *destination, BOOL matchedPiP) {
    if (!destination) {
        return "unknown";
    }
    BOOL inWindow = ([view isKindOfClass:UIView.class] && [(UIView *)view window] != nil);
    if (matchedPiP) {
        return inWindow ? "shared" : "pip-layer";
    }
    return inWindow ? "inapp-layer" : "unknown";
}




static NSMapTable *NJPiMxSrcMemo(void) {
    static NSMapTable *memo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        memo = [NSMapTable mapTableWithKeyOptions:NSMapTableWeakMemory
                                     valueOptions:NSMapTableStrongMemory];
    });
    return memo;
}
static unsigned long long NJPiMxSrcLines = 0;

static void NJPiMxNoteSource(id view, CALayer *destination, BOOL matched, const char *role) {
    uintptr_t packed = ((uintptr_t)destination & ~(uintptr_t)1) | (uintptr_t)(matched ? 1 : 0);
    NSNumber *previous = nil;
    @synchronized (NJPiMxSrcMemo()) {
        previous = [NJPiMxSrcMemo() objectForKey:view];
        if (previous && previous.unsignedLongLongValue == packed) {
            return;
        }
        [NJPiMxSrcMemo() setObject:@(packed) forKey:view];
    }
    if (NJPiMxSrcLines >= 12) {
        return;
    }
    NJPiMxSrcLines += 1;
    CALayer *pipLayer = NJPiMxTrackedPiPLayer(destination, &matched);
    NJPiPDiag("mx src self=%s@%p dst=%p dstcls=%s pipLayer=%p match=%d role=%s",
              object_getClassName(view), view, destination,
              destination ? NJPiPClassName(destination) : "-",
              pipLayer, (int)matched, role);
}

#pragma mark - Mixed offscreen: hook installation

typedef void (*NJPiMxEnqueueIMP)(id, SEL, id);
static NJPiMxEnqueueIMP NJPiMxOriginalEnqueueSmapleBuffer = NULL;
static NJPiMxEnqueueIMP NJPiMxOriginalEnqueueSampleBuffer = NULL;
static unsigned long long NJPiMxHookHits = 0;
static unsigned long long NJPiMxSkippedLogged = 0;

static void NJPiMxTrampoline(id self, SEL _cmd, id sampleBuffer, BOOL primary) {
    NJPiMxHookHits += 1;
    id enqueued = sampleBuffer;
    CALayer *destination = NJPiMxDestinationLayer(self);
    BOOL matchedPiP = NO;
    (void)NJPiMxTrackedPiPLayer(destination, &matchedPiP);
    const char *role = NJPiMxRoleFor(self, destination, matchedPiP);
    NJPiMxNoteSource(self, destination, matchedPiP, role);
    NJPiMxGate gate = NJPiMxPiPActive();
    
    static BOOL lastGateActive = NO;
    static NSString *lastGateSource = nil;
    if (gate.active != lastGateActive || ![lastGateSource isEqualToString:@(gate.source)]) {
        lastGateActive = gate.active;
        lastGateSource = @(gate.source);
        NJPiPDiag("mx gate pip=%d src=%s", (int)gate.active, gate.source);
    }
    BOOL composited = NO;
    if (gate.active && (strcmp(role, "pip-layer") == 0 || strcmp(role, "shared") == 0)) {
        composited = YES;
        enqueued = NJPiMxComposite(sampleBuffer);
    }
    
    if (!composited && NJPiMxSkippedLogged < 20) {
        NJPiMxSkippedLogged += 1;
        NJPiPDiag("mx skip n=%llu reason=%s pip=%d gsrc=%s role=%s self=%s dst=%p",
                  NJPiMxHookHits,
                  gate.active ? "role-not-pip" : "pip-inactive",
                  (int)gate.active, gate.source, role,
                  object_getClassName(self), destination);
    }
    NJPiMxEnqueueIMP *storage = primary ? &NJPiMxOriginalEnqueueSmapleBuffer
                                        : &NJPiMxOriginalEnqueueSampleBuffer;
    if (*storage) {
        (*storage)(self, _cmd, enqueued);
    }
}

static void NJPiMxHookedEnqueueSmapleBuffer(id self, SEL _cmd, id sampleBuffer) {
    NJPiMxTrampoline(self, _cmd, sampleBuffer, YES);
}

static void NJPiMxHookedEnqueueSampleBuffer(id self, SEL _cmd, id sampleBuffer) {
    NJPiMxTrampoline(self, _cmd, sampleBuffer, NO);
}

static Method NJPiMxOwnMethodNamed(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method found = NULL;
    for (unsigned int index = 0; index < count; index++) {
        if (sel_isEqual(method_getName(methods[index]), selector)) {
            found = methods[index];
            break;
        }
    }
    free(methods);
    return found;
}

static void NJPiMxInstallHooks(void) {
    
    
    const struct { const char *className; NSString *selectorName; } candidates[] = {
        { "IJKSDLSampleBufferView", @"enqueueSmapleBuffer:" },
        { "IJKSDLSampleBufferView", @"enqueueSampleBuffer:" },
        { "IJKSampleBufferWrapView", @"enqueueSmapleBuffer:" },
        { "IJKSampleBufferWrapView", @"enqueueSampleBuffer:" },
    };
    for (NSUInteger index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++) {
        Class cls = objc_lookUpClass(candidates[index].className);
        if (!cls) {
            continue;
        }
        SEL selector = NSSelectorFromString(candidates[index].selectorName);
        Method method = NJPiMxOwnMethodNamed(cls, selector);
        if (!method) {
            continue;
        }
        IMP implementation = method_getImplementation(method);
        if (!implementation) {
            continue;
        }
        BOOL primary = [candidates[index].selectorName isEqualToString:@"enqueueSmapleBuffer:"];
        NJPiMxEnqueueIMP *storage = primary ? &NJPiMxOriginalEnqueueSmapleBuffer
                                            : &NJPiMxOriginalEnqueueSampleBuffer;
        if (*storage) {
            continue; 
        }
        *storage = (NJPiMxEnqueueIMP)implementation;
        IMP replacement = primary ? (IMP)NJPiMxHookedEnqueueSmapleBuffer
                                  : (IMP)NJPiMxHookedEnqueueSampleBuffer;
        method_setImplementation(method, replacement);
        NJPiPDiag("mx hook cls=%s sel=%s orig=%p replaced=1",
                  class_getName(cls), candidates[index].selectorName.UTF8String, *storage);
    }
    if (!NJPiMxOriginalEnqueueSmapleBuffer && !NJPiMxOriginalEnqueueSampleBuffer) {
        NJPiPDiag("mx hook none reason=no-enqueue-selector");
    }
}


static void NJPiMxStart(void) {
    if (!NJPiPDanmakuEnabled()) {
        NJPiPDiag("mx load skipped feature-off");
        return;
    }
    NJPiMxStartSummary();
    NJPiMxInstallHooks();
}




static void NJPiMxFlushNow(void) {
    dispatch_async(NJPiPDiagQueue(), ^{
        NJPiMxSummaryTick();
        NJPiPDiagFlushLocked();
    });
}






#endif 

static void NJPiPDiagHeartbeat(void) {
    int applicationState = 0;
    UIApplication *application = UIApplication.sharedApplication;
    if (application) {
        applicationState = (int)application.applicationState;
    }
    NSArray<NJPiPOverlayState *> *states;
    @synchronized (NJPiPOverlayStates()) {
        states = [NJPiPOverlayStates() allObjects];
    }
    for (NJPiPOverlayState *state in states) {
        if (!state) {
            continue;
        }
        AVSampleBufferDisplayLayer *officialLayer = state.officialLayer;
        AVPictureInPictureController *controller = state.controller;
        BOOL isSuspended = NO;
        if (controller && [controller respondsToSelector:@selector(isSuspended)]) {
            isSuspended = (BOOL)[(id)controller performSelector:@selector(isSuspended)];
        }
        id playbackDelegate = nil;
        if (@available(iOS 15.0, *)) {
            AVPictureInPictureControllerContentSource *contentSource = controller.contentSource;
            if (contentSource &&
                [contentSource respondsToSelector:@selector(sampleBufferPlaybackDelegate)]) {
                playbackDelegate = [contentSource performSelector:@selector(sampleBufferPlaybackDelegate)];
            }
        }
        if (playbackDelegate) {
            NJPiPSwizzlePlaybackDelegateIfNeeded(playbackDelegate);
        }
        UIView *danmakuView = state.danmakuView;
        CALayer *danmakuLayer = danmakuView.layer;
        NJPiPDiag("hb st=%p app=%d att=%d variant=%s pipAct=%d pipPos=%d pipSusp=%d off=%s offSt=%ld offRdy=%d offFl=%d offTb=%s offSubN=%lu dm=%s dmLayer=%s dmMetal=%d delegate=%s",
                  state,
                  applicationState,
                  (int)state.isAttached,
                  state.overlayContainerLayer ? "layer" : (state.danmakuOriginalSuperview ? "view" : "-"),
                  controller ? (int)controller.pictureInPictureActive : -1,
                  controller ? (int)controller.pictureInPicturePossible : -1,
                  (int)isSuspended,
                  NJPiPClassName(officialLayer),
                  officialLayer ? (long)officialLayer.status : -1,
                  officialLayer ? (int)officialLayer.readyForDisplay : -1,
                  NJPiPLayerRequiresFlush(officialLayer),
                  NJPiPLayerTimebaseInfo(officialLayer).UTF8String,
                  (unsigned long)(officialLayer ? officialLayer.sublayers.count : 0),
                  NJPiPClassName(danmakuView),
                  NJPiPClassName(danmakuLayer),
                  (int)[danmakuLayer isKindOfClass:NSClassFromString(@"CAMetalLayer")],
                  NJPiPClassName(playbackDelegate));
    }
    NJPiPDiag("hb app=%d states=%lu", applicationState, (unsigned long)states.count);
}

static void NJPiPDiagBackgroundProbe(void) {
    int applicationState = 0;
    UIApplication *application = UIApplication.sharedApplication;
    if (application) {
        applicationState = (int)application.applicationState;
    }
    NSArray<NJPiPMirrorState *> *states;
    @synchronized (NJPiPMirrorStates()) {
        states = [NJPiPMirrorStates() allObjects];
    }
    for (NJPiPMirrorState *state in states) {
        if (!state) {
            continue;
        }
        AVPictureInPictureController *controller = state.controller;
        BOOL isSuspended = NO;
        if (controller && [controller respondsToSelector:@selector(isSuspended)]) {
            isSuspended = (BOOL)[(id)controller performSelector:@selector(isSuspended)];
        }
        UIView *hostView = state.contentViewController.hostView;
        NJPiPDiag("bgprobe st=%p app=%d pres=%d pipAct=%d pipPos=%d pipSusp=%d host=%p hostWin=%s n=%lu",
                  state,
                  applicationState,
                  (int)state.isPresenting,
                  controller ? (int)controller.pictureInPictureActive : -1,
                  controller ? (int)controller.pictureInPicturePossible : -1,
                  (int)isSuspended,
                  hostView,
                  NJPiPClassName(hostView.window),
                  (unsigned long)state.mirroredFrameCount);
    }
}

static void NJPiPDiagStart(void) {
    static dispatch_once_t onceToken;
    static dispatch_source_t timer = NULL;
    dispatch_once(&onceToken, ^{
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, NJPiPDiagQueue());
        dispatch_source_set_event_handler(timer, ^{
            NJPiPDiagHeartbeat();
            NJPiPDiagFlushLocked();
        });
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                                  NSEC_PER_SEC,
                                  100 * NSEC_PER_MSEC);
        dispatch_resume(timer);
    });
}

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
    NJPiPDiag("present source=%s danmaku=%s attached=%d frames=%lu",
              NJPiPClassName(sourceView),
              NJPiPClassName(self.danmakuView),
              self.danmakuView.superview == hostView,
              (unsigned long)self.mirroredFrameCount);
}

- (void)enqueueMirroredSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self.isPresenting || !sampleBuffer) {
        return;
    }
    AVSampleBufferDisplayLayer *mirrorLayer = self.mirrorView.sampleBufferDisplayLayer;
    if (mirrorLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
        [mirrorLayer flushAndRemoveImage];
    }

    
    
    
    
    
    
    CMSampleBufferRef mirrorSample = NULL;
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) {
        return;
    }
    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
        kCFAllocatorDefault,
        imageBuffer,
        &formatDescription);
    if (formatStatus != noErr || !formatDescription) {
        return;
    }
    CMSampleTimingInfo timing = {
        .duration = kCMTimeInvalid,
        .presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock()),
        .decodeTimeStamp = kCMTimeInvalid,
    };
    OSStatus sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
        kCFAllocatorDefault,
        imageBuffer,
        formatDescription,
        &timing,
        &mirrorSample);
    CFRelease(formatDescription);
    if (sampleStatus != noErr || !mirrorSample) {
        return;
    }
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(mirrorSample, true);
    CFIndex attachmentCount = attachments ? CFArrayGetCount(attachments) : 0;
    for (CFIndex index = 0; index < attachmentCount; index++) {
        CFMutableDictionaryRef attachment =
            (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, index);
        CFDictionarySetValue(attachment,
                             kCMSampleAttachmentKey_DisplayImmediately,
                             kCFBooleanTrue);
    }
    [mirrorLayer enqueueSampleBuffer:mirrorSample];
    self.mirroredFrameCount += 1;
    if (self.mirroredFrameCount == 1) {
        os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                         "[NJPiPDanmaku] first ready sample sourcePTS=%.3f mirrorPTS=%.3f attachments=%ld ready=%d",
                         CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)),
                         CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(mirrorSample)),
                         (long)attachmentCount,
                         mirrorLayer.readyForDisplay);
    }
    long long diagNowMs = (long long)llround([NSDate date].timeIntervalSince1970 * 1000.0);
    if (diagNowMs - self.diagLastSampleLogMs >= 500) {
        self.diagLastSampleLogMs = diagNowMs;
        CFArrayRef sourceAttachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, NO);
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
        CMTime sourcePTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        NJPiPDiag("smp n=%lu pts=%.3f opst=%.3f ready=%d att=%ld fmt=%ld size=%lux%lu mpts=%.3f mst=%ld mrdy=%d",
                  (unsigned long)self.mirroredFrameCount,
                  CMTimeGetSeconds(sourcePTS),
                  CMTimeGetSeconds(CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)),
                   (int)CMSampleBufferDataIsReady(sampleBuffer),
                   sourceAttachments ? (long)CFArrayGetCount(sourceAttachments) : 0,
                   (long)pixelFormat,
                  (unsigned long)CVPixelBufferGetWidth(imageBuffer),
                  (unsigned long)CVPixelBufferGetHeight(imageBuffer),
                  CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(mirrorSample)),
                  (long)mirrorLayer.status,
                  (int)mirrorLayer.readyForDisplay);
    }
    CFRelease(mirrorSample);
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
    NJPiPDiag("restore frames=%lu", (unsigned long)self.mirroredFrameCount);
    self.mirroredFrameCount = 0;
}

- (void)invalidate {
    @synchronized (NJPiPMirrorStates()) {
        [NJPiPMirrorStates() removeObject:self];
    }
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
    NJPiPDiag("mirror willStart");
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
    NJPiPDiag("mirror didStart active=%d possible=%d frames=%lu",
              (int)controller.pictureInPictureActive,
              (int)controller.pictureInPicturePossible,
              (unsigned long)self.state.mirroredFrameCount);
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStartPictureInPicture:controller];
    }
}


- (void)pictureInPictureController:(AVPictureInPictureController *)controller failedToStartPictureInPictureWithError:(NSError *)error {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] failed mirror start domain=%{public}s code=%ld description=%{public}s",
                     error.domain.UTF8String,
                     (long)error.code,
                     error.localizedDescription.UTF8String);
    NJPiPDiag("mirror failed domain=%s code=%ld",
              error.domain.UTF8String, (long)error.code);
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureController:controller
                  failedToStartPictureInPictureWithError:error];
    }
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)controller {
    NJPiPDiag("mirror willStop");
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerWillStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)controller {
    NJPiPDiag("mirror didStop");
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStopPictureInPicture:controller];
    }
}


- (void)pictureInPictureController:(AVPictureInPictureController *)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    NJPiPDiag("mirror restoreUI");
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
    
    
    
    
    state.sourceView = activeSourceView;
    state.referenceSourceView = referenceSourceView;
    state.activeVideoCallSourceView = activeSourceView;
    state.sourceVideoRenderer = NJPiPSampleBufferRenderer(sourceLayer);
    
    
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
    
    
    
    
    
    
    
    
    
    CMTimebaseRef mirrorTimebase = NULL;
    @try {
        id sourceTimebaseValue = [sourceLayer valueForKey:@"timebase"];
        if ([sourceTimebaseValue isKindOfClass:[NSValue class]]) {
            mirrorTimebase = (CMTimebaseRef)[(NSValue *)sourceTimebaseValue pointerValue];
        }
    } @catch (__unused NSException *exception) {
        mirrorTimebase = NULL;
    }
    if (mirrorTimebase) {
        state.mirrorView.sampleBufferDisplayLayer.controlTimebase = mirrorTimebase;
    }
    NJPiPDiag("mirror timebase reused=%d", (int)(mirrorTimebase != NULL));
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
    @synchronized (NJPiPMirrorStates()) {
        [NJPiPMirrorStates() addObject:state];
    }
    NJPiPDiag("prepared anchor=%p layer=%p danmaku=%s",
              activeSourceView,
              sourceLayer,
              NJPiPClassName(state.danmakuView));
    return state;
}


#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

__asm__(".linker_option \"-framework\", \"CydiaSubstrate\"");

@class BBPlayerDanmakuService; @class BBPlayerUpTagWidget; @class BBPlayerPortraitScreenBottomWidget; @class BFCCRONRenderView; @class AVSampleBufferVideoRenderer; @class AVSampleBufferDisplayLayer; @class AVPictureInPictureController; @class BBPlayerFlexContainerWidget; @class BAPICommunityServiceDmV1Command; @class BAPICommunityServiceDmV1DmViewReply; @class _TtC18BBPictureInPicture15PlayerContainer; @class BBPlayerDanmakuVoutView; @class BAPIAppViewuniteV1ViewProgressReply; @class BBPlayerGotoStoryWidget; @class BBPlayerBizGotoStoryWidget; @class BBSBPiPManager; @class BFCCRONRenderBaseView; @class BFCCRONRenderViewV2; @class BBPlayerOperationTagService; 


#line 5179 "BiliBiliMDDylib/Logos/Detail/NJDetailPlayerAd.xm"
static BBPlayerDanmakuService* (*_logos_orig$App$BBPlayerDanmakuService$initWithContext$)(_LOGOS_SELF_TYPE_INIT BBPlayerDanmakuService*, SEL, id) _LOGOS_RETURN_RETAINED; static BBPlayerDanmakuService* _logos_method$App$BBPlayerDanmakuService$initWithContext$(_LOGOS_SELF_TYPE_INIT BBPlayerDanmakuService*, SEL, id) _LOGOS_RETURN_RETAINED; static void (*_logos_orig$App$BBPlayerDanmakuService$serviceOnStart)(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBPlayerDanmakuService$serviceOnStart(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBPlayerDanmakuService$serviceOnStop)(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBPlayerDanmakuService$serviceOnStop(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBPlayerDanmakuService$loadDMViewWithContextExtra$completeBlock$)(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL, id, id); static void _logos_method$App$BBPlayerDanmakuService$loadDMViewWithContextExtra$completeBlock$(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL, id, id); static UIView * (*_logos_orig$App$BBPlayerDanmakuService$view)(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL); static UIView * _logos_method$App$BBPlayerDanmakuService$view(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST, SEL); static BBSBPiPManager* (*_logos_orig$App$BBSBPiPManager$init)(_LOGOS_SELF_TYPE_INIT BBSBPiPManager*, SEL) _LOGOS_RETURN_RETAINED; static BBSBPiPManager* _logos_method$App$BBSBPiPManager$init(_LOGOS_SELF_TYPE_INIT BBSBPiPManager*, SEL) _LOGOS_RETURN_RETAINED; static BOOL (*_logos_orig$App$BBSBPiPManager$needsBindingPlayerContainer)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static BOOL _logos_method$App$BBSBPiPManager$needsBindingPlayerContainer(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBSBPiPManager$bindGraftData$shareId$dataSource$completion$)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, id, id, id, id); static void _logos_method$App$BBSBPiPManager$bindGraftData$shareId$dataSource$completion$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, id, id, id, id); static void (*_logos_orig$App$BBSBPiPManager$bindGraftData$ugcDataSourceAdapter$completion$)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, id, id, id); static void _logos_method$App$BBSBPiPManager$bindGraftData$ugcDataSourceAdapter$completion$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, id, id, id); static void (*_logos_orig$App$BBSBPiPManager$prepareToStart)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBSBPiPManager$prepareToStart(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBSBPiPManager$stopPreparing)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBSBPiPManager$stopPreparing(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBSBPiPManager$start)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBSBPiPManager$start(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBSBPiPManager$stop)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBSBPiPManager$stop(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBSBPiPManager$stopWithReason$)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, NSInteger); static void _logos_method$App$BBSBPiPManager$stopWithReason$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, NSInteger); static void (*_logos_orig$App$BBSBPiPManager$setPictureInPictureStatus$)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, NSInteger); static void _logos_method$App$BBSBPiPManager$setPictureInPictureStatus$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL, NSInteger); static void (*_logos_orig$App$BBSBPiPManager$dealloc)(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBSBPiPManager$dealloc(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST, SEL); static _TtC18BBPictureInPicture15PlayerContainer* (*_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$init)(_LOGOS_SELF_TYPE_INIT _TtC18BBPictureInPicture15PlayerContainer*, SEL) _LOGOS_RETURN_RETAINED; static _TtC18BBPictureInPicture15PlayerContainer* _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$init(_LOGOS_SELF_TYPE_INIT _TtC18BBPictureInPicture15PlayerContainer*, SEL) _LOGOS_RETURN_RETAINED; static void (*_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$director_didPrepared)(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$director_didPrepared(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$director_didComplete)(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$director_didComplete(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$dealloc)(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$dealloc(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBPlayerDanmakuVoutView$setupRenderer$)(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuVoutView* _LOGOS_SELF_CONST, SEL, id); static void _logos_method$App$BBPlayerDanmakuVoutView$setupRenderer$(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuVoutView* _LOGOS_SELF_CONST, SEL, id); static void (*_logos_orig$App$BFCCRONRenderBaseView$updateGpuState)(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderBaseView* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BFCCRONRenderBaseView$updateGpuState(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderBaseView* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BFCCRONRenderView$setExternalPixelBuffer$)(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderView* _LOGOS_SELF_CONST, SEL, id); static void _logos_method$App$BFCCRONRenderView$setExternalPixelBuffer$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderView* _LOGOS_SELF_CONST, SEL, id); static void (*_logos_orig$App$BFCCRONRenderView$_updateSyncForTimeStep$)(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderView* _LOGOS_SELF_CONST, SEL, double); static void _logos_method$App$BFCCRONRenderView$_updateSyncForTimeStep$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderView* _LOGOS_SELF_CONST, SEL, double); static void (*_logos_orig$App$BFCCRONRenderViewV2$setExternalPixelBuffer$)(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderViewV2* _LOGOS_SELF_CONST, SEL, id); static void _logos_method$App$BFCCRONRenderViewV2$setExternalPixelBuffer$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderViewV2* _LOGOS_SELF_CONST, SEL, id); static void (*_logos_orig$App$BFCCRONRenderViewV2$_updateSyncForTimeStep$)(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderViewV2* _LOGOS_SELF_CONST, SEL, double); static void _logos_method$App$BFCCRONRenderViewV2$_updateSyncForTimeStep$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderViewV2* _LOGOS_SELF_CONST, SEL, double); static void (*_logos_orig$App$AVSampleBufferDisplayLayer$enqueueSampleBuffer$)(_LOGOS_SELF_TYPE_NORMAL AVSampleBufferDisplayLayer* _LOGOS_SELF_CONST, SEL, CMSampleBufferRef); static void _logos_method$App$AVSampleBufferDisplayLayer$enqueueSampleBuffer$(_LOGOS_SELF_TYPE_NORMAL AVSampleBufferDisplayLayer* _LOGOS_SELF_CONST, SEL, CMSampleBufferRef); static void (*_logos_orig$App$AVSampleBufferVideoRenderer$enqueueSampleBuffer$)(_LOGOS_SELF_TYPE_NORMAL AVSampleBufferVideoRenderer* _LOGOS_SELF_CONST, SEL, CMSampleBufferRef); static void _logos_method$App$AVSampleBufferVideoRenderer$enqueueSampleBuffer$(_LOGOS_SELF_TYPE_NORMAL AVSampleBufferVideoRenderer* _LOGOS_SELF_CONST, SEL, CMSampleBufferRef); static AVPictureInPictureController* (*_logos_orig$App$AVPictureInPictureController$initWithPlayerLayer$)(_LOGOS_SELF_TYPE_INIT AVPictureInPictureController*, SEL, AVPlayerLayer *) _LOGOS_RETURN_RETAINED; static AVPictureInPictureController* _logos_method$App$AVPictureInPictureController$initWithPlayerLayer$(_LOGOS_SELF_TYPE_INIT AVPictureInPictureController*, SEL, AVPlayerLayer *) _LOGOS_RETURN_RETAINED; static void (*_logos_orig$App$AVPictureInPictureController$startPictureInPicture)(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$AVPictureInPictureController$startPictureInPicture(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL); static AVPictureInPictureController* (*_logos_orig$App$AVPictureInPictureController$initWithContentSource$)(_LOGOS_SELF_TYPE_INIT AVPictureInPictureController*, SEL, AVPictureInPictureControllerContentSource *) _LOGOS_RETURN_RETAINED; static AVPictureInPictureController* _logos_method$App$AVPictureInPictureController$initWithContentSource$(_LOGOS_SELF_TYPE_INIT AVPictureInPictureController*, SEL, AVPictureInPictureControllerContentSource *) _LOGOS_RETURN_RETAINED; static void (*_logos_orig$App$AVPictureInPictureController$setContentSource$)(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL, AVPictureInPictureControllerContentSource *); static void _logos_method$App$AVPictureInPictureController$setContentSource$(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL, AVPictureInPictureControllerContentSource *); static void (*_logos_orig$App$AVPictureInPictureController$setDelegate$)(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL, id<AVPictureInPictureControllerDelegate>); static void _logos_method$App$AVPictureInPictureController$setDelegate$(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL, id<AVPictureInPictureControllerDelegate>); static id<AVPictureInPictureControllerDelegate> (*_logos_orig$App$AVPictureInPictureController$delegate)(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL); static id<AVPictureInPictureControllerDelegate> _logos_method$App$AVPictureInPictureController$delegate(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$AVPictureInPictureController$dealloc)(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$AVPictureInPictureController$dealloc(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST, SEL); static BBPlayerUpTagWidget* (*_logos_orig$App$BBPlayerUpTagWidget$initWithContext$)(_LOGOS_SELF_TYPE_INIT BBPlayerUpTagWidget*, SEL, id) _LOGOS_RETURN_RETAINED; static BBPlayerUpTagWidget* _logos_method$App$BBPlayerUpTagWidget$initWithContext$(_LOGOS_SELF_TYPE_INIT BBPlayerUpTagWidget*, SEL, id) _LOGOS_RETURN_RETAINED; static void (*_logos_orig$App$BBPlayerPortraitScreenBottomWidget$setupFirstControlConstraints)(_LOGOS_SELF_TYPE_NORMAL BBPlayerPortraitScreenBottomWidget* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBPlayerPortraitScreenBottomWidget$setupFirstControlConstraints(_LOGOS_SELF_TYPE_NORMAL BBPlayerPortraitScreenBottomWidget* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBPlayerPortraitScreenBottomWidget$setupSecondControlConstraints)(_LOGOS_SELF_TYPE_NORMAL BBPlayerPortraitScreenBottomWidget* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBPlayerPortraitScreenBottomWidget$setupSecondControlConstraints(_LOGOS_SELF_TYPE_NORMAL BBPlayerPortraitScreenBottomWidget* _LOGOS_SELF_CONST, SEL); static BBPlayerBizGotoStoryWidget* (*_logos_orig$App$BBPlayerBizGotoStoryWidget$initWithContext$)(_LOGOS_SELF_TYPE_INIT BBPlayerBizGotoStoryWidget*, SEL, id) _LOGOS_RETURN_RETAINED; static BBPlayerBizGotoStoryWidget* _logos_method$App$BBPlayerBizGotoStoryWidget$initWithContext$(_LOGOS_SELF_TYPE_INIT BBPlayerBizGotoStoryWidget*, SEL, id) _LOGOS_RETURN_RETAINED; static BBPlayerGotoStoryWidget* (*_logos_orig$App$BBPlayerGotoStoryWidget$initWithContext$flexConfiguration$)(_LOGOS_SELF_TYPE_INIT BBPlayerGotoStoryWidget*, SEL, id, id) _LOGOS_RETURN_RETAINED; static BBPlayerGotoStoryWidget* _logos_method$App$BBPlayerGotoStoryWidget$initWithContext$flexConfiguration$(_LOGOS_SELF_TYPE_INIT BBPlayerGotoStoryWidget*, SEL, id, id) _LOGOS_RETURN_RETAINED; static NSArray * (*_logos_orig$App$BBPlayerOperationTagService$tagModels)(_LOGOS_SELF_TYPE_NORMAL BBPlayerOperationTagService* _LOGOS_SELF_CONST, SEL); static NSArray * _logos_method$App$BBPlayerOperationTagService$tagModels(_LOGOS_SELF_TYPE_NORMAL BBPlayerOperationTagService* _LOGOS_SELF_CONST, SEL); static NSSet<NSNumber *> * _logos_method$App$BBPlayerOperationTagService$nj_filterTypes(_LOGOS_SELF_TYPE_NORMAL BBPlayerOperationTagService* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$App$BBPlayerFlexContainerWidget$didLayoutSubWidgets)(_LOGOS_SELF_TYPE_NORMAL BBPlayerFlexContainerWidget* _LOGOS_SELF_CONST, SEL); static void _logos_method$App$BBPlayerFlexContainerWidget$didLayoutSubWidgets(_LOGOS_SELF_TYPE_NORMAL BBPlayerFlexContainerWidget* _LOGOS_SELF_CONST, SEL); static BAPICommunityServiceDmV1DmViewReply* (*_logos_orig$App$BAPICommunityServiceDmV1DmViewReply$initWithData$extensionRegistry$error$)(_LOGOS_SELF_TYPE_INIT BAPICommunityServiceDmV1DmViewReply*, SEL, id, id, id *) _LOGOS_RETURN_RETAINED; static BAPICommunityServiceDmV1DmViewReply* _logos_method$App$BAPICommunityServiceDmV1DmViewReply$initWithData$extensionRegistry$error$(_LOGOS_SELF_TYPE_INIT BAPICommunityServiceDmV1DmViewReply*, SEL, id, id, id *) _LOGOS_RETURN_RETAINED; static BAPIAppViewuniteV1ViewProgressReply* (*_logos_orig$App$BAPIAppViewuniteV1ViewProgressReply$initWithData$extensionRegistry$error$)(_LOGOS_SELF_TYPE_INIT BAPIAppViewuniteV1ViewProgressReply*, SEL, id, id, id *) _LOGOS_RETURN_RETAINED; static BAPIAppViewuniteV1ViewProgressReply* _logos_method$App$BAPIAppViewuniteV1ViewProgressReply$initWithData$extensionRegistry$error$(_LOGOS_SELF_TYPE_INIT BAPIAppViewuniteV1ViewProgressReply*, SEL, id, id, id *) _LOGOS_RETURN_RETAINED; 

@interface BBPlayerDanmakuService : NSObject
- (instancetype)initWithContext:(id)context;
- (void)serviceOnStart;
- (void)serviceOnStop;
- (void)loadDMViewWithContextExtra:(id)contextExtra completeBlock:(id)completeBlock;
- (UIView *)view;
- (double)currentTime;
- (double)playbackRate;
@end



static BBPlayerDanmakuService* _logos_method$App$BBPlayerDanmakuService$initWithContext$(_LOGOS_SELF_TYPE_INIT BBPlayerDanmakuService* __unused self, SEL __unused _cmd, id context) _LOGOS_RETURN_RETAINED {
    id result = _logos_orig$App$BBPlayerDanmakuService$initWithContext$(self, _cmd, context);
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService init self=%p result=%p context=%p contextClass=%{public}s thread=%{public}s",
                     self, result, context, NJPiPClassName(context), NSThread.currentThread.description.UTF8String);
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    
    
    NJPiMxRememberDanmakuService(self);
#endif
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    
    
    NJPiGpuRememberDanmakuService(self);
#endif
    return result;
}

static void _logos_method$App$BBPlayerDanmakuService$serviceOnStart(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService start self=%p view=%p time=%.3f rate=%.3f",
                     self, [self view], [self currentTime], [self playbackRate]);
    NJPiPDiag("dm service start");
    _logos_orig$App$BBPlayerDanmakuService$serviceOnStart(self, _cmd);

    
    
    
    
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

static void _logos_method$App$BBPlayerDanmakuService$serviceOnStop(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService stop self=%p view=%p time=%.3f",
                     self, [self view], [self currentTime]);
    NJPiPDiag("dm service stop");
    _logos_orig$App$BBPlayerDanmakuService$serviceOnStop(self, _cmd);
}

static void _logos_method$App$BBPlayerDanmakuService$loadDMViewWithContextExtra$completeBlock$(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id contextExtra, id completeBlock) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService loadDMView self=%p extra=%p extraClass=%{public}s completion=%p",
                     self, contextExtra, NJPiPClassName(contextExtra), completeBlock);
    _logos_orig$App$BBPlayerDanmakuService$loadDMViewWithContextExtra$completeBlock$(self, _cmd, contextExtra, completeBlock);

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

static UIView * _logos_method$App$BBPlayerDanmakuService$view(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuService* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    UIView *view = _logos_orig$App$BBPlayerDanmakuService$view(self, _cmd);
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



static BBSBPiPManager* _logos_method$App$BBSBPiPManager$init(_LOGOS_SELF_TYPE_INIT BBSBPiPManager* __unused self, SEL __unused _cmd) _LOGOS_RETURN_RETAINED {
    id result = _logos_orig$App$BBSBPiPManager$init(self, _cmd);
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager init self=%p result=%p class=%{public}s",
                     self, result, NJPiPClassName(result));
    NJPiPDiag("sbg init");
    return result;
}

static BOOL _logos_method$App$BBSBPiPManager$needsBindingPlayerContainer(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    BOOL result = _logos_orig$App$BBSBPiPManager$needsBindingPlayerContainer(self, _cmd);
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager needsBinding self=%p result=%d status=%ld",
                     self, result, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg needsBinding=%d status=%ld", (int)result, (long)[self pictureInPictureStatus]);
    return result;
}

static void _logos_method$App$BBSBPiPManager$bindGraftData$shareId$dataSource$completion$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id graftData, id shareId, id dataSource, id completion) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager bind shared self=%p graft=%p(%{public}s) share=%p source=%p(%{public}s) completion=%p",
                      self, graftData, NJPiPClassName(graftData), shareId,
                      dataSource, NJPiPClassName(dataSource), completion);
    NJPiPDiag("sbg bind share");
    _logos_orig$App$BBSBPiPManager$bindGraftData$shareId$dataSource$completion$(self, _cmd, graftData, shareId, dataSource, completion);
}

static void _logos_method$App$BBSBPiPManager$bindGraftData$ugcDataSourceAdapter$completion$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id graftData, id adapter, id completion) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager bind UGC self=%p graft=%p(%{public}s) adapter=%p(%{public}s) completion=%p",
                      self, graftData, NJPiPClassName(graftData),
                      adapter, NJPiPClassName(adapter), completion);
    NJPiPDiag("sbg bind ugc");
    _logos_orig$App$BBSBPiPManager$bindGraftData$ugcDataSourceAdapter$completion$(self, _cmd, graftData, adapter, completion);
}

static void _logos_method$App$BBSBPiPManager$prepareToStart(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager prepare self=%p status=%ld needsBinding=%d",
                     self, (long)[self pictureInPictureStatus], [self needsBindingPlayerContainer]);
    NJPiPDiag("sbg prepare status=%ld", (long)[self pictureInPictureStatus]);
    _logos_orig$App$BBSBPiPManager$prepareToStart(self, _cmd);
}

static void _logos_method$App$BBSBPiPManager$stopPreparing(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stopPreparing self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg stopPreparing");
    _logos_orig$App$BBSBPiPManager$stopPreparing(self, _cmd);
}

static void _logos_method$App$BBSBPiPManager$start(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager start self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg start");
    _logos_orig$App$BBSBPiPManager$start(self, _cmd);
}

static void _logos_method$App$BBSBPiPManager$stop(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stop self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg stop");
    _logos_orig$App$BBSBPiPManager$stop(self, _cmd);
}

static void _logos_method$App$BBSBPiPManager$stopWithReason$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSInteger reason) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stopWithReason self=%p reason=%ld status=%ld",
                     self, (long)reason, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg stopWithReason=%ld", (long)reason);
    _logos_orig$App$BBSBPiPManager$stopWithReason$(self, _cmd, reason);
}

static void _logos_method$App$BBSBPiPManager$setPictureInPictureStatus$(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSInteger status) {
    NSInteger oldStatus = [self pictureInPictureStatus];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager status self=%p old=%ld new=%ld",
                     self, (long)oldStatus, (long)status);
    NJPiPDiag("sbg status old=%ld new=%ld", (long)oldStatus, (long)status);
    _logos_orig$App$BBSBPiPManager$setPictureInPictureStatus$(self, _cmd, status);
}

static void _logos_method$App$BBSBPiPManager$dealloc(_LOGOS_SELF_TYPE_NORMAL BBSBPiPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager dealloc self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg dealloc");
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMxFlushNow();
    NJPiMxForgetCapturedViews("sbg");
#endif
    _logos_orig$App$BBSBPiPManager$dealloc(self, _cmd);
}



@interface _TtC18BBPictureInPicture15PlayerContainer : NSObject
- (void)director_didPrepared;
- (void)director_didComplete;
@end



static _TtC18BBPictureInPicture15PlayerContainer* _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$init(_LOGOS_SELF_TYPE_INIT _TtC18BBPictureInPicture15PlayerContainer* __unused self, SEL __unused _cmd) _LOGOS_RETURN_RETAINED {
    id result = _logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$init(self, _cmd);
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer init self=%p result=%p class=%{public}s",
                     self, result, NJPiPClassName(result));
    NJPiPDiag("sbgc init");
    return result;
}

static void _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$director_didPrepared(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer prepared self=%p thread=%{public}s",
                     self, NSThread.currentThread.description.UTF8String);
    NJPiPDiag("sbgc prepared");
    _logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$director_didPrepared(self, _cmd);
}

static void _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$director_didComplete(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer complete self=%p",
                     self);
    NJPiPDiag("sbgc complete");
    _logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$director_didComplete(self, _cmd);
}

static void _logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$dealloc(_LOGOS_SELF_TYPE_NORMAL _TtC18BBPictureInPicture15PlayerContainer* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer dealloc self=%p", self);
    NJPiPDiag("sbgc dealloc");
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMxFlushNow();
    NJPiMxForgetCapturedViews("sbgc");
#endif
    _logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$dealloc(self, _cmd);
}



@interface BBPlayerDanmakuVoutView : NSObject
- (void)setupRenderer:(id)renderer;
@end














static void _logos_method$App$BBPlayerDanmakuVoutView$setupRenderer$(_LOGOS_SELF_TYPE_NORMAL BBPlayerDanmakuVoutView* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id renderer) {
    _logos_orig$App$BBPlayerDanmakuVoutView$setupRenderer$(self, _cmd, renderer);
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    NJPiGpuRememberDanmakuVout(self);
#endif
}










@interface BFCCRONRenderBaseView : UIView
- (void)updateGpuState;
@end
@interface BFCCRONRenderView : BFCCRONRenderBaseView
- (void)setExternalPixelBuffer:(id)arg0;
- (void)_updateSyncForTimeStep:(double)seconds;
@end
@interface BFCCRONRenderViewV2 : BFCCRONRenderBaseView
- (void)setExternalPixelBuffer:(id)arg0;
- (void)_updateSyncForTimeStep:(double)seconds;
@end


static void _logos_method$App$BFCCRONRenderBaseView$updateGpuState(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderBaseView* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "updateGpuState");
#endif
    _logos_orig$App$BFCCRONRenderBaseView$updateGpuState(self, _cmd);
}



static void _logos_method$App$BFCCRONRenderView$setExternalPixelBuffer$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderView* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id arg0) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "setExternalPixelBuffer:");
#endif
    _logos_orig$App$BFCCRONRenderView$setExternalPixelBuffer$(self, _cmd, arg0);
}
static void _logos_method$App$BFCCRONRenderView$_updateSyncForTimeStep$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderView* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, double seconds) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "_updateSyncForTimeStep:");
#endif
    _logos_orig$App$BFCCRONRenderView$_updateSyncForTimeStep$(self, _cmd, seconds);
}



static void _logos_method$App$BFCCRONRenderViewV2$setExternalPixelBuffer$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderViewV2* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id arg0) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "setExternalPixelBuffer:");
#endif
    _logos_orig$App$BFCCRONRenderViewV2$setExternalPixelBuffer$(self, _cmd, arg0);
}
static void _logos_method$App$BFCCRONRenderViewV2$_updateSyncForTimeStep$(_LOGOS_SELF_TYPE_NORMAL BFCCRONRenderViewV2* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, double seconds) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "_updateSyncForTimeStep:");
#endif
    _logos_orig$App$BFCCRONRenderViewV2$_updateSyncForTimeStep$(self, _cmd, seconds);
}







static void _logos_method$App$AVSampleBufferDisplayLayer$enqueueSampleBuffer$(_LOGOS_SELF_TYPE_NORMAL AVSampleBufferDisplayLayer* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, CMSampleBufferRef sampleBuffer) {
    NJPiPMirrorState *state = NJPiPMirrorStateForObject(self);
    if (!state || NJPiPMirrorEnqueueDepth > 0) {
        _logos_orig$App$AVSampleBufferDisplayLayer$enqueueSampleBuffer$(self, _cmd, sampleBuffer);
        return;
    }
    NJPiPMirrorEnqueueDepth += 1;
    _logos_orig$App$AVSampleBufferDisplayLayer$enqueueSampleBuffer$(self, _cmd, sampleBuffer);
    NJPiPMirrorEnqueueDepth -= 1;
    [state enqueueMirroredSampleBuffer:sampleBuffer];
}



@interface AVSampleBufferVideoRenderer (NJPiPMirroring)
- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end



static void _logos_method$App$AVSampleBufferVideoRenderer$enqueueSampleBuffer$(_LOGOS_SELF_TYPE_NORMAL AVSampleBufferVideoRenderer* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, CMSampleBufferRef sampleBuffer) {
    NJPiPMirrorState *state = NJPiPMirrorStateForObject(self);
    if (!state || NJPiPMirrorEnqueueDepth > 0) {
        _logos_orig$App$AVSampleBufferVideoRenderer$enqueueSampleBuffer$(self, _cmd, sampleBuffer);
        return;
    }
    NJPiPMirrorEnqueueDepth += 1;
    _logos_orig$App$AVSampleBufferVideoRenderer$enqueueSampleBuffer$(self, _cmd, sampleBuffer);
    NJPiPMirrorEnqueueDepth -= 1;
    [state enqueueMirroredSampleBuffer:sampleBuffer];
}





static AVPictureInPictureController* _logos_method$App$AVPictureInPictureController$initWithPlayerLayer$(_LOGOS_SELF_TYPE_INIT AVPictureInPictureController* __unused self, SEL __unused _cmd, AVPlayerLayer * playerLayer) _LOGOS_RETURN_RETAINED {
    
    
    AVPictureInPictureController *controller = _logos_orig$App$AVPictureInPictureController$initWithPlayerLayer$(self, _cmd, playerLayer);
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] controller player-layer init class=%{public}s controller=%p enabled=%d",
                     NJPiPClassName(controller), controller, NJPiPDanmakuEnabled());
    NJPiPDiag("pip initPlayerLayer enabled=%d", NJPiPDanmakuEnabled());
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

static void _logos_method$App$AVPictureInPictureController$startPictureInPicture(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NJPiPDiag("pip start");
    UIView *fallbackSourceView = objc_getAssociatedObject(self, NJPiPFallbackSourceViewKey);
    if (!fallbackSourceView.window) {
        AVPlayerLayer *fallbackPlayerLayer = objc_getAssociatedObject(self,
                                                                       NJPiPFallbackPlayerLayerKey);
        fallbackSourceView = NJViewWithBackingLayer(fallbackPlayerLayer) ?:
                             NJSourceViewForLayer(fallbackPlayerLayer);
    }
    NJPrewarmPiPMirrorInput(self, fallbackSourceView);
    _logos_orig$App$AVPictureInPictureController$startPictureInPicture(self, _cmd);
}

static AVPictureInPictureController* _logos_method$App$AVPictureInPictureController$initWithContentSource$(_LOGOS_SELF_TYPE_INIT AVPictureInPictureController* __unused self, SEL __unused _cmd, AVPictureInPictureControllerContentSource * contentSource) _LOGOS_RETURN_RETAINED {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] controller content-source init class=%{public}s source=%{public}s enabled=%d",
                     NJPiPClassName(self), NJPiPClassName(contentSource), NJPiPDanmakuEnabled());
    NJPiPDiag("pip initContentSource enabled=%d", NJPiPDanmakuEnabled());
    
    
    
    AVPictureInPictureController *controller = _logos_orig$App$AVPictureInPictureController$initWithContentSource$(self, _cmd, contentSource);
    if (controller && NJPiPDanmakuEnabled()) {
        NJTrackPiPController(controller);
        if (@available(iOS 15.0, *)) {
            NJEnsurePiPOverlayState(controller, contentSource);
        }
    }
    return controller;
}

static void _logos_method$App$AVPictureInPictureController$setContentSource$(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, AVPictureInPictureControllerContentSource * contentSource) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] controller set source class=%{public}s source=%{public}s enabled=%d",
                     NJPiPClassName(self), NJPiPClassName(contentSource), NJPiPDanmakuEnabled());
    NJPiPDiag("pip setContentSource enabled=%d", NJPiPDanmakuEnabled());
    
    
    
    NJPiPMirrorState *oldState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    if (contentSource == oldState.customContentSource) {
        _logos_orig$App$AVPictureInPictureController$setContentSource$(self, _cmd, contentSource);
        return;
    }
    [oldState invalidate];
    objc_setAssociatedObject(self, NJPiPMirrorStateKey, nil, OBJC_ASSOCIATION_ASSIGN);
    
    
    _logos_orig$App$AVPictureInPictureController$setContentSource$(self, _cmd, contentSource);
    if (@available(iOS 15.0, *)) {
        if (NJPiPDanmakuEnabled() && contentSource) {
            NJEnsurePiPOverlayState(self, contentSource);
        }
    }
}

static void _logos_method$App$AVPictureInPictureController$setDelegate$(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id<AVPictureInPictureControllerDelegate> delegate) {
    NJPiPOverlayState *overlayState = objc_getAssociatedObject(self, NJPiPOverlayStateKey);
    if (overlayState && delegate != overlayState.delegateProxy) {
        overlayState.delegateProxy.downstream = delegate;
        _logos_orig$App$AVPictureInPictureController$setDelegate$(self, _cmd, overlayState.delegateProxy);
        return;
    }
    NJPiPMirrorState *mirrorState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    if (mirrorState && delegate != mirrorState.delegateProxy) {
        mirrorState.delegateProxy.downstream = delegate;
        _logos_orig$App$AVPictureInPictureController$setDelegate$(self, _cmd, mirrorState.delegateProxy);
        return;
    }
    NJPiPDanmakuState *state = objc_getAssociatedObject(self, NJPiPDanmakuStateKey);
    if (state && delegate != state.delegateProxy) {
        state.delegateProxy.downstream = delegate;
        _logos_orig$App$AVPictureInPictureController$setDelegate$(self, _cmd, state.delegateProxy);
        return;
    }
    _logos_orig$App$AVPictureInPictureController$setDelegate$(self, _cmd, delegate);
}

static id<AVPictureInPictureControllerDelegate> _logos_method$App$AVPictureInPictureController$delegate(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    id<AVPictureInPictureControllerDelegate> delegate = _logos_orig$App$AVPictureInPictureController$delegate(self, _cmd);
    NJPiPOverlayState *overlayState = objc_getAssociatedObject(self, NJPiPOverlayStateKey);
    if (overlayState && delegate == overlayState.delegateProxy && overlayState.delegateProxy.downstream) {
        return overlayState.delegateProxy.downstream;
    }
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

static void _logos_method$App$AVPictureInPictureController$dealloc(_LOGOS_SELF_TYPE_NORMAL AVPictureInPictureController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NJPiPDiag("pip dealloc");
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMxFlushNow();
    NJPiMxForgetCapturedViews("pip");
#endif
    NJPiPOverlayState *overlayState = objc_getAssociatedObject(self, NJPiPOverlayStateKey);
    [overlayState invalidate];
    objc_setAssociatedObject(self, NJPiPOverlayStateKey, nil, OBJC_ASSOCIATION_ASSIGN);
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
    _logos_orig$App$AVPictureInPictureController$dealloc(self, _cmd);
}



@interface BBPlayerWidget : NSObject

@property (readonly, weak, nonatomic) BBPlayerWidget *superWidget;
@property (readonly, copy, nonatomic) NSArray *subWidgets;

@end

@interface BBPlayerUpTagWidget : NSObject

@end




static BBPlayerUpTagWidget* _logos_method$App$BBPlayerUpTagWidget$initWithContext$(_LOGOS_SELF_TYPE_INIT BBPlayerUpTagWidget* __unused self, SEL __unused _cmd, id context) _LOGOS_RETURN_RETAINED {
    return nil;
}



@interface BBPlayerPortraitScreenBottomWidget : NSObject


- (id)upTagWidget;

- (id)operationTagWidget;

@end




static void _logos_method$App$BBPlayerPortraitScreenBottomWidget$setupFirstControlConstraints(_LOGOS_SELF_TYPE_NORMAL BBPlayerPortraitScreenBottomWidget* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    BBPlayerWidget *upTagWidget = [self upTagWidget];
    if (upTagWidget) {
        _logos_orig$App$BBPlayerPortraitScreenBottomWidget$setupFirstControlConstraints(self, _cmd);
    }
}


static void _logos_method$App$BBPlayerPortraitScreenBottomWidget$setupSecondControlConstraints(_LOGOS_SELF_TYPE_NORMAL BBPlayerPortraitScreenBottomWidget* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    BBPlayerWidget *operationTagWidget = [self operationTagWidget];
    if (operationTagWidget) {
        _logos_orig$App$BBPlayerPortraitScreenBottomWidget$setupSecondControlConstraints(self, _cmd);
    }
}







static BBPlayerBizGotoStoryWidget* _logos_method$App$BBPlayerBizGotoStoryWidget$initWithContext$(_LOGOS_SELF_TYPE_INIT BBPlayerBizGotoStoryWidget* __unused self, SEL __unused _cmd, id context) _LOGOS_RETURN_RETAINED {
    if (NJ_VERTICAL_SCREEN_MODE_VALUE) {
        return _logos_orig$App$BBPlayerBizGotoStoryWidget$initWithContext$(self, _cmd, context);
    }
    return nil;
}






static BBPlayerGotoStoryWidget* _logos_method$App$BBPlayerGotoStoryWidget$initWithContext$flexConfiguration$(_LOGOS_SELF_TYPE_INIT BBPlayerGotoStoryWidget* __unused self, SEL __unused _cmd, id context, id configuration) _LOGOS_RETURN_RETAINED {
    if (NJ_VERTICAL_SCREEN_MODE_VALUE) {
        return _logos_orig$App$BBPlayerGotoStoryWidget$initWithContext$flexConfiguration$(self, _cmd, context, configuration);
    }
    return nil;
}



@interface BBPlayerCoreOperationTagModel : NSObject

@property (nonatomic) unsigned long long type;

@end


@interface BBPlayerOperationTagService : NSObject

@property (retain, nonatomic) NSArray *tagModels;

- (NSSet<NSNumber *> *)nj_filterTypes;

@end



static NSArray * _logos_method$App$BBPlayerOperationTagService$tagModels(_LOGOS_SELF_TYPE_NORMAL BBPlayerOperationTagService* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSArray *origTagModels = _logos_orig$App$BBPlayerOperationTagService$tagModels(self, _cmd);
    NSMutableArray *items = [NSMutableArray array];
    for (BBPlayerCoreOperationTagModel *item in origTagModels) {
        if ([[self nj_filterTypes] containsObject:@(item.type)]) {
            continue;
        }
        [items addObject:item];
    }
    
    [self setValue:items forKeyPath:@"_tagModels"];
    return items;
}


static NSSet<NSNumber *> * _logos_method$App$BBPlayerOperationTagService$nj_filterTypes(_LOGOS_SELF_TYPE_NORMAL BBPlayerOperationTagService* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSSet *filterSet = objc_getAssociatedObject(self, @selector(nj_filterTypes));
    if (!filterSet) {
        NSArray *types = @[
            @(1),      
        ];
        filterSet = [NSSet setWithArray:types];
        objc_setAssociatedObject(self, @selector(nj_filterTypes), filterSet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return filterSet;
}



@interface BBPlayerFlexContainerWidget : BBPlayerWidget

@end



static void _logos_method$App$BBPlayerFlexContainerWidget$didLayoutSubWidgets(_LOGOS_SELF_TYPE_NORMAL BBPlayerFlexContainerWidget* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {

    _logos_orig$App$BBPlayerFlexContainerWidget$didLayoutSubWidgets(self, _cmd);
}





@interface BAPICommunityServiceDmV1Command : NSObject


@property (retain, nonatomic) NSMutableArray *commandDmsArray;

@end






@interface BAPICommunityServiceDmV1DmViewReply : NSObject

@property (retain, nonatomic) BAPICommunityServiceDmV1Command *command;

@property (retain, nonatomic) NSMutableArray *activityMetaArray;

@end



static BAPICommunityServiceDmV1DmViewReply* _logos_method$App$BAPICommunityServiceDmV1DmViewReply$initWithData$extensionRegistry$error$(_LOGOS_SELF_TYPE_INIT BAPICommunityServiceDmV1DmViewReply* __unused self, SEL __unused _cmd, id data, id registry, id * error) _LOGOS_RETURN_RETAINED {
    BAPICommunityServiceDmV1DmViewReply *ret = _logos_orig$App$BAPICommunityServiceDmV1DmViewReply$initWithData$extensionRegistry$error$(self, _cmd, data, registry, error);
    
    [ret.command.commandDmsArray removeAllObjects];
    
    [ret.activityMetaArray removeAllObjects];
    return ret;
}



@interface BAPIAppViewuniteV1DmResource : NSObject

@property (retain, nonatomic) NSMutableArray *commandDmsArray;

@property (retain, nonatomic) NSMutableArray *cardsArray;

@end

@interface BAPIAppViewuniteV1ViewProgressReply : NSObject

@property (retain, nonatomic) BAPIAppViewuniteV1DmResource *dm;

@end



static BAPIAppViewuniteV1ViewProgressReply* _logos_method$App$BAPIAppViewuniteV1ViewProgressReply$initWithData$extensionRegistry$error$(_LOGOS_SELF_TYPE_INIT BAPIAppViewuniteV1ViewProgressReply* __unused self, SEL __unused _cmd, id data, id registry, id * error) _LOGOS_RETURN_RETAINED {
    BAPIAppViewuniteV1ViewProgressReply *ret = _logos_orig$App$BAPIAppViewuniteV1ViewProgressReply$initWithData$extensionRegistry$error$(self, _cmd, data, registry, error);
    
    [ret.dm.cardsArray removeAllObjects];
    return ret;
}


 


static __attribute__((constructor)) void _logosLocalCtor_1590142d(int __unused argc, char __unused **argv, char __unused **envp) {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] module loaded master=%d pip=%d",
                     NJ_MASTER_SWITCH_VALUE, NJ_PIP_DANMAKU_VALUE);
    NSDictionary<NSString *, id> *bundleInfo = [NSBundle mainBundle].infoDictionary;
    NJPiPDiag("load sha=%s target=%s bundle=%s build=%s master=%d pip=%d",
              NJ_PI_P_BUILD_SHA,
              NJ_PI_P_TARGET_APP_URL,
               [(NSString *)[bundleInfo objectForKey:@"CFBundleShortVersionString"] UTF8String],
               [(NSString *)[bundleInfo objectForKey:@"CFBundleVersion"] UTF8String],
              NJ_MASTER_SWITCH_VALUE, NJ_PIP_DANMAKU_VALUE);
    
    
    
    
    
    NJPiPDiag("pip arch=native-layerinsert sha=%s (was: native-overlay; setMetaLayer: rejected: WMMetaLayer parameter)",
              NJ_PI_P_BUILD_SHA);
    NJPiPDiagStart();
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    
    
    
    
    NJPiMxStart();
#endif
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    
    
    
    
    NJPiGpuStart();
#endif
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                     object:nil
                                                      queue:nil
                                                 usingBlock:^(__unused NSNotification *note) {
        NJPiPDiag("app foreground");
        NJPiPDiagFlush();
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(__unused NSNotification *note) {
        NJPiPDiag("app background");
        NJPiPDiagBackgroundProbe();
        NJPiPDiagFlush();
    }];
    if (NJ_MASTER_SWITCH_VALUE) {
        {Class _logos_class$App$BBPlayerDanmakuService = objc_getClass("BBPlayerDanmakuService"); { MSHookMessageEx(_logos_class$App$BBPlayerDanmakuService, @selector(initWithContext:), (IMP)&_logos_method$App$BBPlayerDanmakuService$initWithContext$, (IMP*)&_logos_orig$App$BBPlayerDanmakuService$initWithContext$);}{ MSHookMessageEx(_logos_class$App$BBPlayerDanmakuService, @selector(serviceOnStart), (IMP)&_logos_method$App$BBPlayerDanmakuService$serviceOnStart, (IMP*)&_logos_orig$App$BBPlayerDanmakuService$serviceOnStart);}{ MSHookMessageEx(_logos_class$App$BBPlayerDanmakuService, @selector(serviceOnStop), (IMP)&_logos_method$App$BBPlayerDanmakuService$serviceOnStop, (IMP*)&_logos_orig$App$BBPlayerDanmakuService$serviceOnStop);}{ MSHookMessageEx(_logos_class$App$BBPlayerDanmakuService, @selector(loadDMViewWithContextExtra:completeBlock:), (IMP)&_logos_method$App$BBPlayerDanmakuService$loadDMViewWithContextExtra$completeBlock$, (IMP*)&_logos_orig$App$BBPlayerDanmakuService$loadDMViewWithContextExtra$completeBlock$);}{ MSHookMessageEx(_logos_class$App$BBPlayerDanmakuService, @selector(view), (IMP)&_logos_method$App$BBPlayerDanmakuService$view, (IMP*)&_logos_orig$App$BBPlayerDanmakuService$view);}Class _logos_class$App$BBSBPiPManager = objc_getClass("BBSBPiPManager"); { MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(init), (IMP)&_logos_method$App$BBSBPiPManager$init, (IMP*)&_logos_orig$App$BBSBPiPManager$init);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(needsBindingPlayerContainer), (IMP)&_logos_method$App$BBSBPiPManager$needsBindingPlayerContainer, (IMP*)&_logos_orig$App$BBSBPiPManager$needsBindingPlayerContainer);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(bindGraftData:shareId:dataSource:completion:), (IMP)&_logos_method$App$BBSBPiPManager$bindGraftData$shareId$dataSource$completion$, (IMP*)&_logos_orig$App$BBSBPiPManager$bindGraftData$shareId$dataSource$completion$);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(bindGraftData:ugcDataSourceAdapter:completion:), (IMP)&_logos_method$App$BBSBPiPManager$bindGraftData$ugcDataSourceAdapter$completion$, (IMP*)&_logos_orig$App$BBSBPiPManager$bindGraftData$ugcDataSourceAdapter$completion$);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(prepareToStart), (IMP)&_logos_method$App$BBSBPiPManager$prepareToStart, (IMP*)&_logos_orig$App$BBSBPiPManager$prepareToStart);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(stopPreparing), (IMP)&_logos_method$App$BBSBPiPManager$stopPreparing, (IMP*)&_logos_orig$App$BBSBPiPManager$stopPreparing);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(start), (IMP)&_logos_method$App$BBSBPiPManager$start, (IMP*)&_logos_orig$App$BBSBPiPManager$start);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(stop), (IMP)&_logos_method$App$BBSBPiPManager$stop, (IMP*)&_logos_orig$App$BBSBPiPManager$stop);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(stopWithReason:), (IMP)&_logos_method$App$BBSBPiPManager$stopWithReason$, (IMP*)&_logos_orig$App$BBSBPiPManager$stopWithReason$);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, @selector(setPictureInPictureStatus:), (IMP)&_logos_method$App$BBSBPiPManager$setPictureInPictureStatus$, (IMP*)&_logos_orig$App$BBSBPiPManager$setPictureInPictureStatus$);}{ MSHookMessageEx(_logos_class$App$BBSBPiPManager, sel_registerName("dealloc"), (IMP)&_logos_method$App$BBSBPiPManager$dealloc, (IMP*)&_logos_orig$App$BBSBPiPManager$dealloc);}Class _logos_class$App$_TtC18BBPictureInPicture15PlayerContainer = objc_getClass("_TtC18BBPictureInPicture15PlayerContainer"); { MSHookMessageEx(_logos_class$App$_TtC18BBPictureInPicture15PlayerContainer, @selector(init), (IMP)&_logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$init, (IMP*)&_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$init);}{ MSHookMessageEx(_logos_class$App$_TtC18BBPictureInPicture15PlayerContainer, @selector(director_didPrepared), (IMP)&_logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$director_didPrepared, (IMP*)&_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$director_didPrepared);}{ MSHookMessageEx(_logos_class$App$_TtC18BBPictureInPicture15PlayerContainer, @selector(director_didComplete), (IMP)&_logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$director_didComplete, (IMP*)&_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$director_didComplete);}{ MSHookMessageEx(_logos_class$App$_TtC18BBPictureInPicture15PlayerContainer, sel_registerName("dealloc"), (IMP)&_logos_method$App$_TtC18BBPictureInPicture15PlayerContainer$dealloc, (IMP*)&_logos_orig$App$_TtC18BBPictureInPicture15PlayerContainer$dealloc);}Class _logos_class$App$BBPlayerDanmakuVoutView = objc_getClass("BBPlayerDanmakuVoutView"); { MSHookMessageEx(_logos_class$App$BBPlayerDanmakuVoutView, @selector(setupRenderer:), (IMP)&_logos_method$App$BBPlayerDanmakuVoutView$setupRenderer$, (IMP*)&_logos_orig$App$BBPlayerDanmakuVoutView$setupRenderer$);}Class _logos_class$App$BFCCRONRenderBaseView = objc_getClass("BFCCRONRenderBaseView"); { MSHookMessageEx(_logos_class$App$BFCCRONRenderBaseView, @selector(updateGpuState), (IMP)&_logos_method$App$BFCCRONRenderBaseView$updateGpuState, (IMP*)&_logos_orig$App$BFCCRONRenderBaseView$updateGpuState);}Class _logos_class$App$BFCCRONRenderView = objc_getClass("BFCCRONRenderView"); { MSHookMessageEx(_logos_class$App$BFCCRONRenderView, @selector(setExternalPixelBuffer:), (IMP)&_logos_method$App$BFCCRONRenderView$setExternalPixelBuffer$, (IMP*)&_logos_orig$App$BFCCRONRenderView$setExternalPixelBuffer$);}{ MSHookMessageEx(_logos_class$App$BFCCRONRenderView, @selector(_updateSyncForTimeStep:), (IMP)&_logos_method$App$BFCCRONRenderView$_updateSyncForTimeStep$, (IMP*)&_logos_orig$App$BFCCRONRenderView$_updateSyncForTimeStep$);}Class _logos_class$App$BFCCRONRenderViewV2 = objc_getClass("BFCCRONRenderViewV2"); { MSHookMessageEx(_logos_class$App$BFCCRONRenderViewV2, @selector(setExternalPixelBuffer:), (IMP)&_logos_method$App$BFCCRONRenderViewV2$setExternalPixelBuffer$, (IMP*)&_logos_orig$App$BFCCRONRenderViewV2$setExternalPixelBuffer$);}{ MSHookMessageEx(_logos_class$App$BFCCRONRenderViewV2, @selector(_updateSyncForTimeStep:), (IMP)&_logos_method$App$BFCCRONRenderViewV2$_updateSyncForTimeStep$, (IMP*)&_logos_orig$App$BFCCRONRenderViewV2$_updateSyncForTimeStep$);}Class _logos_class$App$AVSampleBufferDisplayLayer = objc_getClass("AVSampleBufferDisplayLayer"); { MSHookMessageEx(_logos_class$App$AVSampleBufferDisplayLayer, @selector(enqueueSampleBuffer:), (IMP)&_logos_method$App$AVSampleBufferDisplayLayer$enqueueSampleBuffer$, (IMP*)&_logos_orig$App$AVSampleBufferDisplayLayer$enqueueSampleBuffer$);}Class _logos_class$App$AVSampleBufferVideoRenderer = objc_getClass("AVSampleBufferVideoRenderer"); { MSHookMessageEx(_logos_class$App$AVSampleBufferVideoRenderer, @selector(enqueueSampleBuffer:), (IMP)&_logos_method$App$AVSampleBufferVideoRenderer$enqueueSampleBuffer$, (IMP*)&_logos_orig$App$AVSampleBufferVideoRenderer$enqueueSampleBuffer$);}Class _logos_class$App$AVPictureInPictureController = objc_getClass("AVPictureInPictureController"); { MSHookMessageEx(_logos_class$App$AVPictureInPictureController, @selector(initWithPlayerLayer:), (IMP)&_logos_method$App$AVPictureInPictureController$initWithPlayerLayer$, (IMP*)&_logos_orig$App$AVPictureInPictureController$initWithPlayerLayer$);}{ MSHookMessageEx(_logos_class$App$AVPictureInPictureController, @selector(startPictureInPicture), (IMP)&_logos_method$App$AVPictureInPictureController$startPictureInPicture, (IMP*)&_logos_orig$App$AVPictureInPictureController$startPictureInPicture);}{ MSHookMessageEx(_logos_class$App$AVPictureInPictureController, @selector(initWithContentSource:), (IMP)&_logos_method$App$AVPictureInPictureController$initWithContentSource$, (IMP*)&_logos_orig$App$AVPictureInPictureController$initWithContentSource$);}{ MSHookMessageEx(_logos_class$App$AVPictureInPictureController, @selector(setContentSource:), (IMP)&_logos_method$App$AVPictureInPictureController$setContentSource$, (IMP*)&_logos_orig$App$AVPictureInPictureController$setContentSource$);}{ MSHookMessageEx(_logos_class$App$AVPictureInPictureController, @selector(setDelegate:), (IMP)&_logos_method$App$AVPictureInPictureController$setDelegate$, (IMP*)&_logos_orig$App$AVPictureInPictureController$setDelegate$);}{ MSHookMessageEx(_logos_class$App$AVPictureInPictureController, @selector(delegate), (IMP)&_logos_method$App$AVPictureInPictureController$delegate, (IMP*)&_logos_orig$App$AVPictureInPictureController$delegate);}{ MSHookMessageEx(_logos_class$App$AVPictureInPictureController, sel_registerName("dealloc"), (IMP)&_logos_method$App$AVPictureInPictureController$dealloc, (IMP*)&_logos_orig$App$AVPictureInPictureController$dealloc);}Class _logos_class$App$BBPlayerUpTagWidget = objc_getClass("BBPlayerUpTagWidget"); { MSHookMessageEx(_logos_class$App$BBPlayerUpTagWidget, @selector(initWithContext:), (IMP)&_logos_method$App$BBPlayerUpTagWidget$initWithContext$, (IMP*)&_logos_orig$App$BBPlayerUpTagWidget$initWithContext$);}Class _logos_class$App$BBPlayerPortraitScreenBottomWidget = objc_getClass("BBPlayerPortraitScreenBottomWidget"); { MSHookMessageEx(_logos_class$App$BBPlayerPortraitScreenBottomWidget, @selector(setupFirstControlConstraints), (IMP)&_logos_method$App$BBPlayerPortraitScreenBottomWidget$setupFirstControlConstraints, (IMP*)&_logos_orig$App$BBPlayerPortraitScreenBottomWidget$setupFirstControlConstraints);}{ MSHookMessageEx(_logos_class$App$BBPlayerPortraitScreenBottomWidget, @selector(setupSecondControlConstraints), (IMP)&_logos_method$App$BBPlayerPortraitScreenBottomWidget$setupSecondControlConstraints, (IMP*)&_logos_orig$App$BBPlayerPortraitScreenBottomWidget$setupSecondControlConstraints);}Class _logos_class$App$BBPlayerBizGotoStoryWidget = objc_getClass("BBPlayerBizGotoStoryWidget"); { MSHookMessageEx(_logos_class$App$BBPlayerBizGotoStoryWidget, @selector(initWithContext:), (IMP)&_logos_method$App$BBPlayerBizGotoStoryWidget$initWithContext$, (IMP*)&_logos_orig$App$BBPlayerBizGotoStoryWidget$initWithContext$);}Class _logos_class$App$BBPlayerGotoStoryWidget = objc_getClass("BBPlayerGotoStoryWidget"); { MSHookMessageEx(_logos_class$App$BBPlayerGotoStoryWidget, @selector(initWithContext:flexConfiguration:), (IMP)&_logos_method$App$BBPlayerGotoStoryWidget$initWithContext$flexConfiguration$, (IMP*)&_logos_orig$App$BBPlayerGotoStoryWidget$initWithContext$flexConfiguration$);}Class _logos_class$App$BBPlayerOperationTagService = objc_getClass("BBPlayerOperationTagService"); { MSHookMessageEx(_logos_class$App$BBPlayerOperationTagService, @selector(tagModels), (IMP)&_logos_method$App$BBPlayerOperationTagService$tagModels, (IMP*)&_logos_orig$App$BBPlayerOperationTagService$tagModels);}{ char _typeEncoding[1024]; unsigned int i = 0; memcpy(_typeEncoding + i, @encode(NSSet<NSNumber *> *), strlen(@encode(NSSet<NSNumber *> *))); i += strlen(@encode(NSSet<NSNumber *> *)); _typeEncoding[i] = '@'; i += 1; _typeEncoding[i] = ':'; i += 1; _typeEncoding[i] = '\0'; class_addMethod(_logos_class$App$BBPlayerOperationTagService, @selector(nj_filterTypes), (IMP)&_logos_method$App$BBPlayerOperationTagService$nj_filterTypes, _typeEncoding); }Class _logos_class$App$BBPlayerFlexContainerWidget = objc_getClass("BBPlayerFlexContainerWidget"); { MSHookMessageEx(_logos_class$App$BBPlayerFlexContainerWidget, @selector(didLayoutSubWidgets), (IMP)&_logos_method$App$BBPlayerFlexContainerWidget$didLayoutSubWidgets, (IMP*)&_logos_orig$App$BBPlayerFlexContainerWidget$didLayoutSubWidgets);}Class _logos_class$App$BAPICommunityServiceDmV1DmViewReply = objc_getClass("BAPICommunityServiceDmV1DmViewReply"); { MSHookMessageEx(_logos_class$App$BAPICommunityServiceDmV1DmViewReply, @selector(initWithData:extensionRegistry:error:), (IMP)&_logos_method$App$BAPICommunityServiceDmV1DmViewReply$initWithData$extensionRegistry$error$, (IMP*)&_logos_orig$App$BAPICommunityServiceDmV1DmViewReply$initWithData$extensionRegistry$error$);}Class _logos_class$App$BAPIAppViewuniteV1ViewProgressReply = objc_getClass("BAPIAppViewuniteV1ViewProgressReply"); { MSHookMessageEx(_logos_class$App$BAPIAppViewuniteV1ViewProgressReply, @selector(initWithData:extensionRegistry:error:), (IMP)&_logos_method$App$BAPIAppViewuniteV1ViewProgressReply$initWithData$extensionRegistry$error$, (IMP*)&_logos_orig$App$BAPIAppViewuniteV1ViewProgressReply$initWithData$extensionRegistry$error$);}}
    }
}
