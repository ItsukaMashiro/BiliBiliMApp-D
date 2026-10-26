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

/*
 画中画弹幕的第二条路径：GPU 合成（把弹幕烘焙进视频帧再入队）。
 默认 0 = 完全不参与编译（不 hook、不建 Metal 设备、不建计时器），
 现有「把弹幕层插进官方 SBDL 子层」的路径行为不变。
 实现体在下面的 `#pragma mark - GPU composite`（文件后半部分），
 打开方式：把这里的 0 改成 1，或编译期 -DNJ_PIP_GPU_COMPOSITE_ENABLED=1。
 */
#ifndef NJ_PIP_GPU_COMPOSITE_ENABLED
#define NJ_PIP_GPU_COMPOSITE_ENABLED 0
#endif

/*
 画中画弹幕的第三条路径：借官方离屏混合渲染取帧。
 B 站在线播放里 BFCCRONRenderView / BFCCRONRenderViewV2（基类 BFCCRONRenderBaseView，
 +layerClass = CAMetalLayer）每帧已经在 Metal 里把视频和弹幕合成好了：drawPrimitives
 画两张贴图 _externalTexture（视频帧）+ _rendererTexture（弹幕帧），弹幕帧来自无 surface
 的 headless BFCChronosRendererWrapper。这条路不自己合成弹幕，也不改视频供帧点，
 而是每帧向 PiP 的 contentSource 提供一个由「正在播放的 cron 视图」离屏重放出来的
 合成帧（视频+弹幕都在里面），喂进 AVSampleBufferDisplayLayer。
 首选实现（route=pass）：KVC 取视图的 _externalTexture/_rendererTexture 两张贴图，
 用运行时在视图对象图上发现的那组 Metal 对象（device/commandQueue/pipeline）做一次
 离屏 pass——参数结构照抄 -[BFCCRONRenderView getMixedImage]@0x11484cc5c
 （createPixelBuffer → createMetalTexture → 换 colorAttachment → 两趟 drawPrimitives），
 直接产出 CVPixelBuffer，不走 getMixedImage 的 UIImage 来回（少一次拷贝）。
 运行时拿不到这些对象则退化（route=image）：调 getMixedImage/offscreenMixedImage 拿
 UIImage 再转 CVPixelBuffer。两条都实现，运行时按可用性自动选，诊断报选的是哪条。
 V1/V2 由 -[BBPlayerChronos prepareToCronScene]@0x114826a5c 读 Memex key
 v8.27.player.enable_mixed_render_main_thread 决定，命中哪个只在运行时探测真实类名。
 默认 0 = 完全不参与编译（不 hook、不建纹理池），与 GPU 路、插层路互斥：
 本宏为 1 时 GPU 路在 NJPiGpuStart 处让路、插层路在 attachDanmakuToOfficialLayer 处让路。
 实现体在下面的 `#pragma mark - Mixed offscreen`（文件后半部分），
 打开方式：把这里的 0 改成 1，或编译期 -DNJ_PIP_MIXED_OFFSCREEN_ENABLED=1。
 真机可观测性（第二轮加入，改动都在这条路的开关内）：
 - 闸门只认权威来源，按权威度排序：我们挂在官方 controller 上的 delegate 代理收到
   的 didStart/didStop（controller-callback）→ controller.pictureInPictureActive 属性
   （layer-probe）→ mirror 路接管 contentSource 留下的 isPresenting（contentsource）。
   判定每次变化打一行 `mx gate pip=0/1 src=…`，不发明任何推断。
 - 每个被 hook 的实例解析它真正投递的 SBDL（ivar _mLayer；真机证明它不是 view.layer），
   与登记的官方 PiP 层比对，打 `mx src self=类@地址 dst=… pipLayer=… match=0/1`；
   role 取值 = pip-layer / inapp-layer / shared / unknown（确证语义见
   Tools/Analysis/pip-sbdl-topology-2026-10-24.md）。
 - mx sum 周期 30s→5s；同 reason 静默上限 5→20；PiP didStop / SBManager /
   PlayerContainer / controller dealloc 时强制摘要+落盘（真机会话只有 ~9s，周期
   等不到）。
 - §15.22 引擎 PiP 期豁免（真机 b284e67 判决 cpb=553 全 nil 后新增）：反汇编确证
   -[CRONEngine updateRunningState]@0x1151b6db0 在入后台时挂起 C++ cron 引擎
   （sub_1152CA47C(cpp,0)），buffer_queue_ 停止进帧——任何驱动都取不到帧。修法是
   闸门期间保持引擎运行：wrap 路取帧前对 wrapper→renderer(CRONRenderer)→engine→
   cppEngine(box) 直调官方完整恢复函数 sub_1152CA44C(box)（地址以 updateRunningState
   的运行时 IMP 对索引锚 0x1151b6db0 自校准，页不对齐即整体放弃、行为回退现状）；
   并换掉 updateRunningState 实现，仅「闸门开且真后台」走恢复分支，其余原样转
   原实现。标志只随闸门动（didStop 与 enqueuer 闸门同步双路清零）。诊断行
   `mx eng calib/resume/keep`。
  - §15.24 snapshot 取帧路（真机 5e21bce 判决 cpb=97 us=81 全 nil 后新增）：引擎
    保活+补驱动都执行了，buffer_queue_ 仍不出帧——泵/队列在后台就是死的。改走
    官方直播 PiP 同构的「按需同步渲染」：wrap 路 copyPixelBuffer 失败后，沿
    wrapper→renderer→engine 链调第一个响应 snapshot 的对象（-[CRONEngine
    snapshot]@0x1151b6aa4 直接进 C++ 同步离屏渲染，输出 CGImage→UIImage），blit
    成 BGRA 后与视频层合成。能力位加进 mx caps（snap=），新失败名 no_snap。
 - §15.25 限时 applicationState 谎报（真机 98856bc 判决 snapshot 前台通、后台
   入口 ms=0.00 秒挡后新增的判决实验）：官方全部已知后台门都是读
   [UIApplication applicationState]==Background（§15.22 引擎挂起、updateGpuState
   的 GPU 放行、updateDisplayLinkState 皆然），C++ 渲染守卫静态追到 vtable 为止。
   引擎豁免窗口内把 applicationState 的 Background 谎报成 Active（关闸即恢复）；
   出弹幕⇒守卫就是它；不出⇒升级 frida 动态。内部判定/日志一律走
   NJPiMxRealAppState。诊断行 `mx lie hook/active/read`，mx sum 加 lie= 位。
 */
#ifndef NJ_PIP_MIXED_OFFSCREEN_ENABLED
#define NJ_PIP_MIXED_OFFSCREEN_ENABLED 1
#endif

/*
 诊断日志的局域网上传（取日志不必插 USB）：把已经写进 NDJSON 文件的那批新增行
 同时 POST 给接收端（仓库 Tools/log-server.py：POST /njlog?name=<名字>）。
 纯旁路能力：不 hook、不在播放线程等待网络，任何失败只写有限几行诊断。
 与上面的 GPU 合成宏互不相干，各自独立开关。
 换地址：把下面改成你的地址，或编译期 -DNJ_PIP_LAN_LOG_URL='"http://192.168.1.9:8099/njlog"'
 */
#ifndef NJ_PIP_LAN_LOG_URL
#define NJ_PIP_LAN_LOG_URL "http://10.0.0.241:8099/njlog"
#endif
#ifndef NJ_PIP_LAN_LOG_UPLOAD_ENABLED
#define NJ_PIP_LAN_LOG_UPLOAD_ENABLED 1
#endif

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

// MARK: - Persistent file diagnostics (observe only)

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
// 定义在下面 Mixed offscreen 区：先把当前窗口的 mx sum 追加进缓冲，再把缓冲整体
// 落盘（含局域网上传）。PiP didStop / SBManager / PlayerContainer / controller
// dealloc 处调用；宏为 0 时这些调用点不存在（它们各自包在同一开关里）。
static void NJPiMxFlushNow(void);
// 定义在下面 capture 区：teardown（didStop / sbg / sbgc / pip dealloc）清掉捕获的
// cron 视图实例，避免把已释放实例带进下一次会话。
static void NJPiMxForgetCapturedViews(const char *why);
static id NJPiMCapturedView(void);
// 定义在下面 §15.22 区：PiP didStop 把 CRON 引擎豁免标志清回 NO（标志只随闸门动）。
static void NJPiMxEngineNoteStop(void);
// 定义在下面 §15.25 区：谎报钩当前是否生效中（进 mx sum 的 lie= 字段）。
static BOOL NJPiMxAppStateLieActive(void);
// 定义在下面 §15.25 区：绕过谎报钩读真实 applicationState（心跳诊断用）。
static NSInteger NJPiMxRealAppState(void);
#endif
#if NJ_PIP_LAN_LOG_UPLOAD_ENABLED
// 定义在下面（要用 NJPiPDiag 写失败诊断）。两处调用都是 fire-and-forget，
// 调用方不等待网络，也不看返回值。
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
    // Second copy under an explicitly-recognisable name in the same Documents
    // directory: LiveContainer file sharing can expose Documents through
    // `pymobiledevice3 apps afc <bundleid> --documents`, and this file gives
    // that channel a stable name. Best-effort only; failures are ignored.
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
    // 与文件写入共用同一批数据 = 只上传新增行（接收端对请求体有 8 MB 上限，
    // 这里一批最多 16 KB，永远够）。只在两个文件都写完之后才发，语义就是
    // 「已落盘的这些行」；网络失败不影响文件，也不回滚游标。
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
    // Every diagnostic line is also mirrored to os_log: the container files
    // of a nested app inside LiveContainer are not always reachable from the
    // PC side, but os_log can be captured live. Keep the existing prefix.
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

// MARK: - LAN log upload (observe only)

#if NJ_PIP_LAN_LOG_UPLOAD_ENABLED

/*
 尽力而为的日志旁路：把刚落盘的 NDJSON 行 POST 到局域网接收端，取日志不需要插 USB。
 这里没有 hook、没有渲染路径、也不等网络：NSURLSession 的 completion 在自己的队列上，
 调用点只负责把请求丢出去。失败每种原因最多两行诊断（含 HTTP 状态或 NSError 域/码），
 成功不打印。计数器（att/ok/sentB）只在诊断里出现，跨队列读写给的是纯统计，允许撕裂。
 */
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
        // ephemeral：不存 cookie/缓存，也不与 App 自己的 URLSession 抢东西。
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = 5.0;
        configuration.timeoutIntervalForResource = 10.0;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        session = [NSURLSession sessionWithConfiguration:configuration];
        // 只此一行，用来在设备上确认这次包里烧进去的地址。
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
              // 成功不打印；只累加计数，失败诊断里能看到上传是否在工作。
              NJPiPLanUploadOkCount += 1;
              NJPiPLanUploadSentBytes += (NSUInteger)payload.length;
          }];
    [task resume];
}

static void NJPiPLanUploadBuffer(NSData *payload) {
    // 调用点紧接着会清空这个 NSMutableData，所以先固定一份不可变快照再发。
    NJPiPLanUploadData([payload copy], @"NJPiPDiagnostics");
}

/*
 探针文件（Tools/frida/NJPipProbe.js 写的 <NSHomeDirectory()>/Library/NJPiPProbe.ndjson）
 只有插了 frida 的包才存在，读不到就静默跳过。同样只传新增行：自己的游标 + 只截到
 最后一个换行符，剩下的下次再传。约每 10 次 flush（≈10s）看一次，别每次 flush 都读盘。
 */
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
        NJPiPLanProbeCursor = 0;  // 文件被删掉重建
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
        chunk = [chunk subdataWithRange:NSMakeRange(0, 4 * 1024 * 1024)];  // 接收端 8 MB 上限，留一倍余量
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
        return;  // 半行，等下次
    }
    NJPiPLanProbeCursor += consumed;
    NJPiPLanUploadData([chunk subdataWithRange:NSMakeRange(0, consumed)], @"NJPiPProbe");
}

#endif // NJ_PIP_LAN_LOG_UPLOAD_ENABLED

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

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 failedToStartPictureInPictureWithError:(NSError *)error {
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
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMxEngineNoteStop(); // §15.22 关闸
#endif
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
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

// MARK: - Native-layer-insert danmaku overlay
//
// The previous architecture replaced the app's PiP content source with a
// video-call controller hosting a second AVSampleBufferDisplayLayer, and the
// live device showed a grey, stalled PiP window with no danmaku: replacing
// the content source is itself the largest variable on the video path. This
// architecture keeps the app's own SBDL content source completely native (the
// video cannot grey out because we never touch it). The only thing it does is
// insert the danmaku renderer into the official SBDL's layer tree while PiP
// is running, and restore it exactly when PiP stops.
//
// A static re-check of the 8.89 binary showed -[BBPlayerDanmakuVoutView
// setMetaLayer:] takes a WMMetaLayer (the WM/Metal core's own texture overlay
// object, same type as the recorder's mDanmakuLayer/mLayer ivars), not an
// AVSampleBufferDisplayLayer, so that official API cannot be fed here; the
// layer-subtree insertion below is the only overlay path.

static const void *NJPiPOverlayStateKey = &NJPiPOverlayStateKey;

@class NJPiPOverlayDelegateProxy;

@interface NJPiPOverlayState : NSObject
@property (nonatomic, weak) AVPictureInPictureController *controller;
@property (nonatomic, weak, nullable) AVSampleBufferDisplayLayer *officialLayer;
@property (nonatomic, strong) NJPiPOverlayDelegateProxy *delegateProxy;
// didStart/didStop 是系统经我们挂在官方 controller 上的 delegate 代理发来的确证
// 事件（不是推断）。混合路闸门的最高权威来源，见 NJPiMxPiPActive。
@property (atomic, assign) BOOL pipStartedByCallback;
@property (nonatomic, strong, nullable) UIView *danmakuView;
@property (atomic, assign, getter=isAttached) BOOL attached;
// view-carried insertion (preferred when the official layer has a backing view)
@property (nonatomic, weak, nullable) UIView *danmakuOriginalSuperview;
@property (nonatomic, assign) NSUInteger danmakuOriginalIndex;
@property (nonatomic, assign) CGRect danmakuOriginalFrame;
@property (nonatomic, assign) BOOL danmakuTranslatesAutoresizing;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *danmakuConstraints;
// raw layer insertion (fallback when the official layer has no backing view)
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

// Maps a layer's bounds rect up the layer tree into an ancestor layer's
// coordinate space. Rotation/skew is ignored, which holds for the player's
// display-layer stack.
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
    // 第三条路（离屏混合取帧）同样按构造互斥：合成帧里已经有弹幕，再把渲染层
    // 插进官方 SBDL 子层就会画两遍。GPU 路自己的让路判断在它那段里，两段互不引用。
    NJPiPDiag("ov attach skipped reason=mixed-offscreen-enabled");
    return;
#endif
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    // 两条路径按构造互斥：GPU 合成打开时弹幕已经在帧里，再把渲染层插进官方
    // SBDL 子层就会画两遍。宏为 0 时这段不存在，插层路径照旧。
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
        // View-carried insertion: the danmaku view becomes a subview of the
        // view that owns the official SBDL, so its backing layer enters the
        // official SBDL's layer tree through normal view machinery and the
        // existing superview/index/frame/constraints restore pattern applies.
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
        // Raw layer insertion: no backing view for the official layer, so
        // attach a plain container CALayer and move the danmaku view's
        // backing layer into it.
        CALayer *containerLayer = [CALayer layer];
        // No autoresizing: the official SBDL's bounds stay fixed in app
        // coordinates while PiP runs (the PiP window scales the whole layer
        // tree outside this subtree), so a one-shot frame copy is correct.
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
    // 系统确认 PiP 正在跑——闸门的权威事件，只记录不推断。
    self.state.pipStartedByCallback = YES;
    if (self.state && !self.state.isAttached) {
        NJPiPDiag("ov retry@didStart");
        [self.state attachDanmakuToOfficialLayer];
    }
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStartPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 failedToStartPictureInPictureWithError:(NSError *)error {
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
    // 真机第一轮就是栽在短会话：9 秒的 PiP，30s 的摘要周期永远不会触发。
    NJPiMxFlushNow();
    // PiP 停止后主播放器路径可能重建视图：清掉捕获实例，下一段由视图自己的方法重新捕获。
    NJPiMxForgetCapturedViews("didStop");
    NJPiMxEngineNoteStop(); // §15.22 关闸
#endif
    [self.state restoreDanmaku];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
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

/*
 **************** PiP 弹幕的 GPU 合成兜底路径（编译期默认关闭） ****************

 兜底语义：官方 PiP 的内容源是 ijk 自己泵的 AVSampleBufferDisplayLayer
 （静态证据：`IJKSDLSampleBufferView +layerClass` = SBDL、ivar `_mLayer`，
 帧经 `display_pixels:` → `display_pixels_vtb:` → `-[IJKSDLSampleBufferView
 enqueueSmapleBuffer:]`（App 8.89 二进制里这个选择子拼写就是 Smaple）→
 `-[AVSampleBufferDisplayLayer enqueueSampleBuffer:]`；全二进制没有
 `AVSampleBufferVideoRenderer`/`insertTimeSource:`/任何 CMTimebase 设置，
 所以该层是 free-running，只认样本 PTS + 到达时间）。
 如果弹幕层插进那块 SBDL 子层这条路在真机上不被 AVKit 带进 PiP，
 就把弹幕以 source-over 合成进被入队的视频帧本身——PiP 里的内容源只有视频帧，
 帧里有弹幕就一定看得见。

 关掉时（默认）这段代码不产生任何运行时行为：整个实现（含 #import、计数器、
 挂钩安装）都在 `#if NJ_PIP_GPU_COMPOSITE_ENABLED` 里，宏为 0 时预处理阶段全部
 消失，本文件其余部分一行未改；不 hook、不建 Metal device、不建定时器、不多一个
 字符串字面量（诊断里用到的字面量也在块内）。开关本身定义在本文件顶部
 （`NJ_PIP_GPU_COMPOSITE_ENABLED`，紧跟在 build stamp 兜底宏后面），把它改成 1
 即可启用；也可以在编译期传 -DNJ_PIP_GPU_COMPOSITE_ENABLED=1。
 */
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
// Pipelines are keyed by the source pixel layout, chosen once per stream:
// 0 = BGRA copy, 1 = BT.601 video-range YUV copy, 2 = BT.709 YUV copy, 3 = danmaku source-over blend.
#define NJP_GPU_PIPELINE_COUNT 4
static id<MTLRenderPipelineState> NJPiGpuPipelines[NJP_GPU_PIPELINE_COUNT];
static BOOL NJPiGpuSetupAttempted = NO;
static const char *NJPiGpuSetupFailure = NULL;
static CVPixelBufferPoolRef NJPiGpuPool = NULL;
static OSType NJPiGpuPoolFormat = 0;
static NSUInteger NJPiGpuPoolWidth = 0;
static NSUInteger NJPiGpuPoolHeight = 0;
// Ring of in-flight wraps: the wrapped sample is released by the display layer at
// an arbitrary later time, so the pool buffers it hands out are recycled through
// this ring instead of being released inline.
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

// Per-reason failure accounting: at most 5 lines per reason, then silence.
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
    NSUInteger slot = NJP_GPU_MAX_REASONS - 1; // "fmt" is the catch-all slot
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

// Cost accounting, summarised every 30s (see NJPiGpuStartSummary).
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

// mach_absolute_time() ticks are not nanoseconds; convert with the process timebase.
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
        return; // nothing happened in this window: stay quiet
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

// Compiled at runtime with newLibraryWithSource:options:error: so the build needs no
// Metal toolchain and no .metallib: the source below is a plain C string.
// Pass 1 writes the decoded video frame into a BGRA target; pass 2 composites the
// danmaku renderer's own output over it with source-over blending.
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
    // Compiled once and reused for every pipeline (a source compile costs a few ms).
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
        // source-over for a NON-premultiplied source: dst = src.rgb*src.a + dst*(1-src.a).
        // If the real device shows dark halos around danmaku glyphs, the renderer's
        // output is premultiplied and the RGB source factor becomes MTLBlendFactorOne.
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
    // lowPower field dropped on purpose: the diagnostic does not need it, and the SDK
    // used by CI does not expose it as an ObjC property on id<MTLDevice>.
    NJPiPDiag("gpu init device=%s texcache=ok",
              NJPiGpuDevice.name.UTF8String ?: "-");
}

// Target pixel buffer pool: same width/height as the incoming frame. The pixel
// format is 32BGRA because that is the only layout Metal can render into with one
// pass; when the incoming frame already is 32BGRA this is byte-for-byte the same
// format, and when it is 420v the first pass converts it (Metal has no 420v
// render target). The new sample carries a format description built from the new
// buffer, so the display layer sees a consistent pair.
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

// Static evidence (8.89 class dump, tmp/re89/objc-headers.txt):
//  - `BBPlayerDanmakuVoutView : NSObject` owns `BFCChronosRendererWrapper *_rendererWrapper`
//    and `WMMetaLayer *_mLayer`; the view-side element is the UIView whose layer is a
//    CAMetalLayer installed through `BFCMetalLayerRender setMetalLayer:`.
//  - `BFCChronosRendererWrapper` declares `- (struct __CVBuffer *)copyPixelBuffer;`,
//    i.e. the renderer's own output. `copyPixelBuffer` follows the Core Foundation
//    Create Rule, so the returned reference is owned (+1) and released after use.
// The class dump cannot say how to get FROM the tracked view TO that wrapper at
// runtime, so a few documented routes are probed and the one that answered is logged
// once (`gpu dmsrc=…`); the summary line keeps the failure count if none of them do.
// The call is made through a typed IMP so that the app's own selector never has to be
// declared in a category (a `copy…`-named method declaration under ARC would also put
// it in the copy method family, which is a needless compile risk here).
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

// 在线路径（8.89 真机）里弹幕渲染对象不在视图树上：`-[BBPlayerDanmakuService view]`
// 返回的是 BBPlayerChronosContainerView，它既没有 `rendererWrapper` 也没有
// `copyPixelBuffer`，所以「从被跟踪的 view 出发 + KVC」这套探测在线上必然落空
// （真机日志里从来没有出现过 gpu dmsrc=…）。对象图（8.89 class dump：
// tmp/re89/objc-headers.txt:1445047 / :1440714 / :1440666 / :1441057 / :1443891 / :1484715）：
//   -[BBPlayerDanmakuService context]        -> BBPlayerContext
//     （DanmakuService 自身没声明这个 getter，它继承自 BBPlayerObject:1440714 的
//       `@property context` / `- (BBPlayerContext *)context`；现读而不是存下来，
//       播放器复用会换绑 context）
//   -[BBPlayerContext chronos]               -> BBPlayerChronos
//   -[BBPlayerChronos chronosView]           -> BFCCRONRenderView / BFCCRONRenderViewV2
//   -[BFCCRONRenderBaseView rendererWrapper] -> BFCChronosRendererWrapper
//                                              （公开 getter，取代 valueForKey:@"rendererWrapper"）
// 每一环只用 respondsToSelector: + 类型化 IMP；任何一环失败都退回下面的旧路径。
// 这些类不存在于本工程 SDK，因此不补 @interface：一律 id + SEL + 类型化 IMP，
// 与上面的 copyPixelBuffer 用同一种调用方式（补 @interface 反而要为本文件不导入的
// SDK 类型写声明，属于新增编译风险）。
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

// 取帧发生在视频帧入队的线程上，那时手上没有播放器对象，所以只在服务创建时用弱引用
// 记下 BBPlayerDanmakuService 本身（不延长生命周期；最多 8 个，超过说明已经漏掉了释放）。
// context 不在这里存：播放器复用（PVP → 详情页）会换绑 context，存对象会在第一环就拿到
// 失效的那个；下面每次都从服务上现读 -context（继承自 BBPlayerObject，
// objc-headers.txt:1440714 块内 `@property context` / `- (BBPlayerContext *)context`）。
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

// 录制/下载播放那类路径不用 BFCCRONRenderView：8.89 转储里 `BBPlayerDanmakuVoutView`
// 是个 NSObject（objc-headers.txt:1404291），自己持有 `BFCChronosRendererWrapper *_rendererWrapper`
// 这个 ivar（没有 getter，所以这条路只能用 KVC），并且它没有自己的 init ——
// `-setupRenderer:` 才是 ivar 被装上的时刻，登记发生在下面那个 hook 里。
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

// 沿对象图找在线路径的 BFCChronosRendererWrapper；途经对象的真实类名带出来做诊断
// （route 名只能说明「走的是对象图这条路」，是哪个渲染视图要看 rv=）。
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

// PiP 里 B 站自己的弹幕时钟不推进（display link 被暂停），只调 copyPixelBuffer 会反复
// 拿到同一帧。-[BFCChronosRendererWrapper updateSyncForTimeStep:] 的参数是「秒」
// （实现里 ×1e9 换成纳秒），所以按两次取帧之间的真实秒差自驱一次。Δt 必须有上限：
// 切后台再回前台时秒差可能是几十秒，直接喂进去会让弹幕一次性跳到最新。
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

// 取到帧之后的统一处理：来源（route）只在变化时打印一次；只有 BGRA 能被 blend pass
// 直接采样，其它格式仍按现有约定记 fmt 失败并退回未合成的视频帧。
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
        // Only a BGRA source can be sampled by the blend pass without another
        // conversion step; report it and fall back to the raw video frame.
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
    // 1) 在线路径：对象图 + 自驱时间（见上面的注释）。
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
    // 2) 录制/下载路径：登记过的 BBPlayerDanmakuVoutView -> _rendererWrapper（KVC，
    //    这个类没有 getter）。在线路径不会走到这里：它没有 vout 对象。
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
    // 3) 旧路径保留为 fallback：从被跟踪的 view 走 KVC。在线路径命中不了它
    //    （`-[BBPlayerDanmakuService view]` 给的是容器视图），能命中的只有把渲染器
    //    挂在 view 上的那类，所以整条 fallback 统一记成 record.danmakuvout。
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
        // Route list: the view itself, then the object that owns its Metal layer
        // (CAMetalLayer.delegate is the renderer in the BFCMetalLayerRender pattern),
        // and the wrapper ivar behind each of them.
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

#if 0
// TODO(NJPiP-GPU): the fallback that does not work, kept deliberately off.
// If the Chronos renderer ever stops exposing copyPixelBuffer, the only remaining
// handle on the danmaku is its CALayer (`WMMetaLayer *_mLayer`, or the CAMetalLayer
// that `BFCMetalLayerRender setMetalLayer:` installs). Metal cannot sample a
// CALayer: getting its bits means -renderInContext: into a CGBitmapContext or a
// CADisplayLink capture, i.e. CPU-side readback, which this path explicitly forbids
// (no GPU->CPU round trip, no per-pixel CPU compositing). A GPU-feasible variant
// would have to render the layer tree off-screen on the GPU
// (CARenderServer/CAMetalLayer nextDrawable of a layer-hosted view), which needs a
// layer-hosted view we do not own. Requires a dynamic check of what
// BFCMetalLayerRender actually hands the renderer before any of this is worth
// implementing; until then the path falls back to the unmodified video frame.
#endif

#pragma mark - GPU composite: the wrap

static BOOL NJPiGpuIsYUV(OSType format) {
    return format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
}

// Y'CbCr -> R'G'B' as the 16 floats the shader indexes (3 rows of y/cb/cr/const).
// Chroma is sampled with the same texture coordinates as luma, i.e. treated as
// centre-sited; the caveats for a real device are in the report.
static void NJPiGpuYuvMatrix(OSType sourceFormat, BOOL bt709, float *matrix) {
    double kr = bt709 ? 0.2126 : 0.299;   // BT.601 default, BT.709 when the buffer says so
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

// The matrix a buffer asks for, read from its own attachments (never assumed).
static BOOL NJPiGpuWantsBT709(CVImageBufferRef image) {
    // Read only the YCbCr-matrix attachment to pick the shader matrix.
    // CVBufferGetAttachment is a "Get": the returned CFTypeRef is NOT owned by us, so
    // it must NOT be CFReleased — read it immediately, guarded by a CFString type check.
    // (The whole-frame "Copy" path that preserves attachments lives in the wrap below.)
    CFTypeRef value = CVBufferGetAttachment(image, kCVImageBufferYCbCrMatrixKey, NULL);
    BOOL bt709 = NO;
    if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
        bt709 = CFStringCompare((CFStringRef)value, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0)
                == kCFCompareEqualTo;
    }
    return bt709;
}


// Returns the sample to enqueue: the composited one on success, the original on
// any failure. Never re-encodes, never reads pixels back to the CPU.
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
    // Textures live until the GPU work is done; the ring keeps the wrapped sample
    // (and therefore its target buffer) alive until the display layer is done with it.
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
        // Metal leaves no usable default viewport, so state it explicitly: both draws
        // cover the whole target, which is the incoming frame's own size.
        MTLViewport viewport = { 0.0, 0.0, (double)width, (double)height, 0.0, 1.0 };
        [encoder setViewport:viewport];
        [encoder setFragmentSamplerState:NJPiGpuSampler atIndex:0];
        [encoder setFragmentBytes:matrix length:sizeof(matrix) atIndex:0];
        // Pass 1: the decoded frame, converted to the BGRA target if it was YUV.
        [encoder setRenderPipelineState:NJPiGpuPipelines[pipelineIndex]];
        [encoder setFragmentTexture:CVMetalTextureGetTexture(sourcePlaneY) atIndex:0];
        [encoder setFragmentTexture:yuv ? CVMetalTextureGetTexture(sourcePlaneUV) : nil atIndex:1];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        // Pass 2: the danmaku renderer's own output, source-over into the same target.
        [encoder setRenderPipelineState:NJPiGpuPipelines[3]];
        [encoder setFragmentTexture:CVMetalTextureGetTexture(danmakuTextureRef) atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        CVMetalTextureCacheFlush(NJPiGpuTextureCache, 0);
        // The CoreVideo texture bridges must outlive the GPU work, so their
        // references move to the command buffer's completion handler.
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
        // Cost accounting for the wrap itself: the CPU side of the composite ends
        // here, the GPU side is asynchronous and never blocks this thread.
        double elapsedNs = NJPiGpuNanoseconds(mach_absolute_time() - startedAt);
        if (elapsedNs > 0.0) {
            NJPiGpuDurationNs += (unsigned long long)elapsedNs;
            if ((unsigned long long)elapsedNs > NJPiGpuMaxDurationNs) {
                NJPiGpuMaxDurationNs = (unsigned long long)elapsedNs;
            }
        }
        // Carry the incoming frame's attachment metadata (colour primaries, transfer
        // function, YCbCr matrix, etc.) onto the target image buffer, so the format
        // description built from it below — and the sample created from that buffer —
        // describe the same colour space as the incoming frame.
        // CoreVideo plural API is CVBufferGetAttachments (a "Get": the returned
        // CFDictionaryRef is NOT owned by us, so it must NOT be CFReleased) paired with
        // CVBufferSetAttachments. Asking for the ShouldPropagate mode returns exactly the
        // metadata that is meant to carry onto derived frames. It may legitimately come
        // back empty, so only set it when there is at least one attachment.
        CFDictionaryRef sourceImageAttachments = CVBufferGetAttachments(sourceImage, kCVAttachmentMode_ShouldPropagate);
        if (sourceImageAttachments && CFDictionaryGetCount(sourceImageAttachments) > 0) {
            CVBufferSetAttachments(targetImage, sourceImageAttachments, kCVAttachmentMode_ShouldPropagate);
        }
        // Timeline stays untouched: the timing and the per-sample attachments of the
        // incoming sample are copied verbatim onto the wrapped one.
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
        // Build the sample directly from the target image buffer — the correct API for a
        // pixel-buffer-backed sample (CMSampleBufferCreate wants a CMBlockBuffer, not a
        // CVPixelBuffer). CreateReadyWithImageBuffer retains formatDescription, so our own
        // +1 reference is still released just below: the retain/release stays balanced.
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
        wrappedObject = CFBridgingRelease(wrapped); // the create reference goes to ARC
        wrapped = NULL;
        // A ring of recent wrapped samples keeps the target pixel buffer alive for
        // the display layer, which reads it asynchronously after we return.
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

// Reuses the module's own PiP tracking instead of a second state machine: a path is
// only allowed to touch frames while a PiP session this module knows about is live.
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

// Whether `view` is the view whose layer is inside a tracked PiP content source.
// Static analysis cannot pin down whether IJKSDLSampleBufferView's `_mLayer` is the
// one handed to AVKit or an inline-playback-only sibling, so this is reported but
// not required: both cases stay safe because the composite only happens while PiP
// is active, and the log line names the instance addresses for a real device to
// correlate with NJPipProbe.js's per-address counters.
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
    // Two conditions, both required: this module's PiP session is live, and THIS
    // instance is the one whose layer is inside the tracked PiP content source — the
    // pump class is shared with inline playback (BFCPlayerSampleBufferView and
    // IJKSampleBufferWrapView are subclasses of the same base), so the per-instance
    // check is what keeps inline frames untouched.
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

// Only a method the class itself implements is replaced: an inherited one would
// rewrite the superclass's implementation for every other user of it.
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
    // Static evidence (8.89 class dump, tmp/re89/objc-headers.txt):
    //  - `IJKSDLSampleBufferView : UIView` at :1474401 declares
    //    `- (void)enqueueSmapleBuffer:(id)arg0;` at :1474477 — that misspelling is the
    //    only occurrence in the whole binary, and the class has no `enqueueSampleBuffer:`
    //    of its own (it is a UIView, not a display layer: the pump reaches the layer
    //    through its own `_mLayer`).
    //  - `IJKSampleBufferWrapView : IJKSDLSampleBufferView` at :1472265 and
    //    `BFCPlayerSampleBufferView : IJKSDLSampleBufferView` at :1467110 inherit it and
    //    declare nothing, so replacing the base implementation covers every subclass and
    //    hooks the same selector exactly once.
    // Both spellings are probed so a renamed build keeps working.
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
            continue; // already hooked on the other class
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

// 启动点在文件末尾的 %ctor 里（和 NJPiPDiagStart() 同一时刻），这样诊断通道、
// 设置缓存的读取时机都与现有加载路径完全一致，不引入第二个 constructor。
static void NJPiGpuStart(void) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    // 第三条路（离屏混合取帧）打开时这条路让路：互斥只加判断，本路语义一字未动。
    // 宏为 0 时这段不存在，GPU 路加载流程照旧。
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

#endif // NJ_PIP_GPU_COMPOSITE_ENABLED

#if NJ_PIP_MIXED_OFFSCREEN_ENABLED

#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import <mach/mach_time.h>
#import <string.h>
#import <stdio.h>
#import <stdlib.h>

/*
 第三条路径：借官方离屏混合渲染取帧（对照 -[BFCCRONRenderView getMixedImage]@0x11484cc5c /
 -[BFCCRONRenderViewV2 getMixedImage]@0x11484e754，结构见 Tools/Analysis/dmview-backend-2026-10-24.md §1.3/§3）。
 与 GPU 路的分工：GPU 路自己合成「视频帧 + 自己驱动的弹幕光栅化」；这条路把合成的活
 交还给正在播放的 cron 视图——pass 路用视图自己的两张贴图（_externalTexture=视频帧、
 _rendererTexture=弹幕帧）+ 运行时发现的 Metal 对象做一次离屏 pass；image 路直接调
 getMixedImage 拿合成好的 UIImage 再转 CVPixelBuffer。两条都不自己拿视频像素。
 弹幕新鲜度：PiP 在后台时 CADisplayLink 被系统暂停，视图自己的 onDisplayLink 停转，
 所以这里像 GPU 路一样按帧自驱 `-[BFCCRONRenderView(V2) _updateSyncForTimeStep:]`
 （V1 @0x11484c16c 把 wrapper 的 copyPixelBuffer 结果存 _cronRenderBufferRef，V2
 @0x11484e19c 在 main queue 里把 copyPixelBuffer 结果做成 _rendererTexture）。
 两张贴图的新鲜度用「贴图对象指针变化次数」间接观测（exchg/rendchg，不读像素），
 这同时回答「PiP 期间视图还在不在被供帧」这个只能运行时确认的问题。
 */

#pragma mark - Mixed offscreen: state and diagnostics

// 实现选择：0=还没选出来，1=pass（离屏重放视图的两张贴图），2=image（getMixedImage 退化），
// 3=wrap（视频层=正在入队的这一帧，弹幕层=wrapper 自己的 copyPixelBuffer，§15.21 新增、优先）。
#define NJP_MX_ROUTE_NONE 0
#define NJP_MX_ROUTE_PASS 1
#define NJP_MX_ROUTE_IMAGE 2
#define NJP_MX_ROUTE_WRAP 3
static NSUInteger NJPiMxRoute = NJP_MX_ROUTE_NONE;
static BOOL NJPiMxInitLogged = NO;

static CVPixelBufferPoolRef NJPiMxPool = NULL;
static NSUInteger NJPiMxPoolWidth = 0;
static NSUInteger NJPiMxPoolHeight = 0;
static CVMetalTextureCacheRef NJPiMxTextureCache = NULL;
static id<MTLDevice> NJPiMxDevice = nil;          // 自己建的兜底设备（发现的设备优先用视图的）
static id<MTLCommandQueue> NJPiMxCommandQueue = nil;
static id<MTLSamplerState> NJPiMxSampler = nil;
static id<MTLRenderPipelineState> NJPiMxOwnPipelineCopy = nil;
static id<MTLRenderPipelineState> NJPiMxOwnPipelineBlend = nil;
// wrap 路（§15.21）把「手里这一帧」当视频层：420v/420f 需要一条 YUV→BGRA 的 copy
// 通道。它只在 wrap 路被懒编译（NJPiMxOwnPipelineYuvAvailable），pass/image 路
// 的可用性不因为它而变。
static id<MTLRenderPipelineState> NJPiMxOwnPipelineYuv = nil;
static id<MTLLibrary> NJPiMxLibrary = nil;
static const char *NJPiMxSetupFailure = NULL;
// mx fail 行附带最近一次确证过的视图类名（真机第二轮只有 no_tex/no_img，没有依据判断
// 失败落在哪个实例上）；NJPiMxLastPLQ 记录上一帧选用的 pipeline（own/view），进 mx sum。
static const char *NJPiMxFailViewClass = "-";
static const char *NJPiMxLastPLQ = "-";

// Ring of in-flight wraps: same lifetime contract as the GPU path — the display
// layer releases the wrapped sample at an arbitrary later time, so the pool
// buffers it references are recycled through this ring, never released inline.
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

// Per-reason failure accounting: at most 20 lines per reason, then silence
// (same discipline as the GPU path so one broken stream cannot flood the log;
// 20 not 5 because the first real capture exhausted the old cap before PiP
// even started, hiding everything that came after backgrounding).
#define NJP_MX_MAX_REASONS 16
static const char *NJPiMxReasonNames[NJP_MX_MAX_REASONS];
static unsigned long long NJPiMxReasonHits[NJP_MX_MAX_REASONS];
static NSUInteger NJPiMxReasonCount = 0;

static void NJPiMxRegisterReasons(void) {
    if (NJPiMxReasonCount > 0) {
        return;
    }
    // 任务里点名的四类排在最前：no_view / no_tex / no_pool / fmt；
    // 其余是实现内部原因，报告里会原样列出。no_dmsrc 是 §15.21 wrap 路的
    // 「弹幕层拿不到」（wrapper 不存在/不响应 copyPixelBuffer 且 getRendererImage
    // 也不可用），它和 no_tex（wrapper 在但这一帧没出图）是两种不同的下一步。
    const char *reasons[] = { "no_view", "no_tex", "no_pool", "fmt",
                              "no_metal", "no_img", "no_pb", "no_texref",
                              "no_cb", "no_enc", "no_ivar", "no_dmsrc",
                              "no_snap", "wrap", "other" };
    for (NSUInteger index = 0; index < NJP_MX_MAX_REASONS; index++) {
        NJPiMxReasonNames[index] = index < sizeof(reasons) / sizeof(reasons[0])
                                     ? reasons[index] : NULL;
    }
    NJPiMxReasonCount = sizeof(reasons) / sizeof(reasons[0]);
}

static void NJPiMxNoteFailure(const char *reason, CMSampleBufferRef sampleBuffer) {
    NJPiMxRegisterReasons();
    NSUInteger slot = NJP_MX_MAX_REASONS - 1; // catch-all slot
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

// Cost accounting: win = frames that entered the composite while PiP was live,
// out = frames produced, ms = average CPU-side cost per produced frame (GPU work
// is async and never blocks this thread, exactly like the GPU path). Summarised
// every 5s (down from 30s: the first device session lasted ~9s and never hit a
// period), plus a forced tick from NJPiMxFlushNow at PiP stop / teardown; quiet
// when nothing happened in the window.
static unsigned long long NJPiMxEnteredFrames = 0;
static unsigned long long NJPiMxOkFrames = 0;
static unsigned long long NJPiMxDurationNs = 0;
static unsigned long long NJPiMxMaxDurationNs = 0;
static mach_timebase_info_data_t NJPiMxTimebase;
static unsigned long long NJPiMxSummaryLastIn = 0;
static unsigned long long NJPiMxSummaryLastOk = 0;
static unsigned long long NJPiMxSummaryLastFail = 0;
// Texture-identity change counters: 0 while the corresponding texture object is
// reused frame to frame (display link paused / view not fed), growing while the
// official view is actually being fed. Observation only, pointer identity, no pixels read.
static unsigned long long NJPiMxExtChanges = 0;
static unsigned long long NJPiMxRendChanges = 0;
// 弹幕层取源与补驱动观测（§15.21）：cpb=我们主动调 wrapper copyPixelBuffer 的次数；
// us=我们替 wrapper 补驱动 updateSyncForTimeStep: 的次数（§15.23：官方近 0.25s 内
// 无步进时才非零，前台让位、后台接管）；ust=视图自己的 _updateSyncForTimeStep: 被调用次数
// （不含我们 pass 路的自驱——wrap 路不驱视图，这个字段因此只反映官方驱动）。
static unsigned long long NJPiMxWrapperCpbCalls = 0;
static unsigned long long NJPiMxWrapperDrives = 0;
static unsigned long long NJPiMxViewSyncObserved = 0;
static volatile int NJPiMxSelfDriving = 0;
// §15.23：最近一次「官方驱动视图 _updateSyncForTimeStep:」的时刻（mach ticks）。
// 后台 CADisplayLink 停转后官方不再步进引擎，补驱动改按时间窗接管（见 DriveWrapperIfNeeded），
// 判活窗 = 0.25s。0 = 从未观测。
static volatile uint64_t NJPiMxLastOfficialSyncTicks = 0;

static void NJPiMxNoteViewSyncObserved(void) {
    if (!NJPiMxSelfDriving) {
        NJPiMxViewSyncObserved += 1;
        NJPiMxLastOfficialSyncTicks = mach_absolute_time();
    }
}

// 最近一次成功产出帧实际用的弹幕源（进 mx sum 的 dmsrc= 字段）。
static const char *NJPiMxDmSourceName = "none";

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
    // 平均/最大耗时按「这个窗口里产出的帧」算（okDelta），字段名 ms 即毫秒。
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
    static const char *routeNames[] = { "none", "pass", "image", "wrap" };
    const char *routeName = NJPiMxRoute < sizeof(routeNames) / sizeof(routeNames[0])
                                    ? routeNames[NJPiMxRoute] : "?";
    // setup=ok 曾误导（它不反映视图实例）：现在直接报 view=0/1（是否已从视图自己的
    // 方法捕获到实例）与 plq=（上一帧选用的 pipeline）。
    NJPiPDiag("mx sum win=%llu out=%llu fail=%llu ms=%.2f msmax=%.2f route=%s "
              "dmsrc=%s cpb=%llu us=%llu ust=%llu "
              "exchg=%llu rendchg=%llu setup=%s view=%d plq=%s lie=%d fails=%s",
              inDelta, okDelta, failTotal, avgMilliseconds, maxMilliseconds, routeName,
              NJPiMxDmSourceName,
              NJPiMxWrapperCpbCalls, NJPiMxWrapperDrives, NJPiMxViewSyncObserved,
              NJPiMxExtChanges, NJPiMxRendChanges,
              NJPiMxSetupFailure ?: "ok",
              NJPiMCapturedView() ? 1 : 0, NJPiMxLastPLQ, NJPiMxAppStateLieActive(),
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

// 对象图和 GPU 路完全一致（BBPlayerDanmakuService -context-> BBPlayerContext -chronos->
// BBPlayerChronos -chronosView-> BFCCRONRenderView / BFCCRONRenderViewV2，8.89 转储
// tmp/re89/objc-headers.txt，链上每一环 respondsToSelector + 类型化 IMP）。这里单独
// 存一份弱引用表而不是复用 GPU 路的：两条路各自被宏关掉时都不依赖对方还在编译。
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

// 找到正在播放的 cron 视图；把它的真实类名带出来（V1/V2 由 Memex AB
// v8.27.player.enable_mixed_render_main_thread 决定，只能运行时确认）。
static id NJPiMxFindCronView(const char **viewClass) {
    // 优先用「挂视图自己的方法」捕获的实例（被调过 = 存在性有直接证据）；没有才退回
    // 对象链——链上的实例不保证正在被供帧（真机第二轮 no_tex/no_img 的教训，见 capture 区）。
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

// 静态证据只确证了两张贴图的 ivar 名（_externalTexture/_rendererTexture，来自
// onDisplayLink 反汇编里的 setFragmentTexture:atIndex: 操作数，见分析文档 §1.2）；
// commonInit 里 MTLCreateSystemDefaultDevice + newCommandQueue + BFCCRONMetalUtils
// 建 pipeline/textureCache（§1.1 末段），但这些对象的 ivar 名没有反证出来。
// 所以这里不猜死名字：先按候选名 KVC，拿不到的再用运行时 ivar 扫描（类型含 '@'
// 的名字按 KVC 读值，按协议/类名分类），并把命中的 ivar 名原样打进 mx metal 行。
// 只扫视图类自己 + 它的基类（BFCCRONRenderBaseView），到 UIView 为止。
static void NJPiMxScanIvarNames(id view, NSMutableArray<NSString *> *names) {
    Class cls = view ? [view class] : nil;
    while (cls && cls != [UIView class]) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int index = 0; index < count; index++) {
            const char *ivarName = ivar_getName(ivars[index]);
            const char *ivarType = ivar_getTypeEncoding(ivars[index]);
            if (!ivarName || !ivarType || !strchr(ivarType, '@')) {
                continue; // only object-typed ivars are candidates
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

// exact-name candidates first, then the ivar scan. The scan classifies by protocol,
// never by name alone, and records which ivar answered so mx metal is replayable.
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
        return; // exact names resolved everything; no scan
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

// 两张贴图：名字是静态确证的（§1.2 的 setFragmentTexture:atIndex: 操作数）。
// 返回类型必须是协议限定类型：裸 id 上调 pixelFormat/device 会撞上多个同名不同签
// 的方法声明（run 40063065730 的 :3805 就是这么炸的）。
static id<MTLTexture> NJPiMxViewTexture(id view, NSString *ivarName) {
    id value = NJPiMxValueForKey(view, ivarName);
    if (!NJPiMxValueConforms(value, @protocol(MTLTexture))) {
        return nil;
    }
    return (id<MTLTexture>)value;
}

// ── 用「挂视图自己的方法」捕获实例 ────────────────────────────────────────
// 真机第二轮（包 80135d6）确证：对象链能拿到一个视图实例（fails 里只有 no_tex=634/
// no_img=634，没有 no_view），但它的两张贴图永远为 nil——很可能拿到的是隐藏主播放器
// 的闲置实例，不是正在被供帧的那个。所以这里改抓法：挂视图自己必然被调的方法抓 self，
// 方法归属按 8.89 头转储（tmp/re89/objc-headers.txt）：基类 BFCCRONRenderBaseView 只有
// -updateGpuState；-setExternalPixelBuffer:（V1 参数 BFCCRONPixelBuffer*、V2 为 id）与
// -_updateSyncForTimeStep: 在 V1/V2 各自实现。证据强度分档：setExternalPixelBuffer:
// 被调 = 该实例正在被喂视频帧（最高）；updateGpuState 次之（PiP 后台 display link 会
// 被暂停）；_updateSyncForTimeStep: 最弱（我们自己的自驱也会触发，只说明实例可用）。
// 热路径纪律：方法体里只做一次指针比较，相等立即返回；首次见到某实例才做一次 ivar
// 探测（封顶 3 次）并打一行 mx view。实例只持一个强引用，didStop / sbg / sbgc /
// pip dealloc 清空（NJPiMxForgetCapturedViews），不保留已释放实例。
static id NJPiMCapturedViewInstance = nil;
static const char *NJPiMCapturedVia = NULL;
static void *NJPiMSeenViews[4];          // 只存指针做去重比较，永不解引用
static NSUInteger NJPiMSeenCount = 0;
static NSUInteger NJPiMCaptureLogs = 0;
// 弹幕层 wrapper 的弱缓存（§15.21 B）：只认当前捕获视图，换/清实例时一并清。
static __weak id NJPiMxWrapperCached = nil;
static void *NJPiMxWrapperOwner = NULL;   // 只比较指针确认归属，永不解引用

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
    NJPiMxWrapperCached = nil;
    NJPiMxWrapperOwner = NULL;
}

// ivar 在不在实例的类链上（只查类结构，不读值、不分配）。
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

// ── 弹幕层取源：视图挂的 renderer wrapper（§15.21 B）─────────────────────────
// 取证链（HANDOFF 15.11 + Tools/Analysis/dmview-backend-2026-10-24.md）：
// view → -rendererWrapper（ivar _rendererWrapper，BaseView init 起持有）→
// BFCChronosRendererWrapper；它的 -copyPixelBuffer 就是弹幕帧的出处（视图自己的
// _updateSyncForTimeStep: V1 @0x11484c16c / V2 @0x11484e19c 内部先驱动 wrapper
// 再经它取帧做成 _rendererTexture）。取法两条：getter selector、KVC 读 ivar；
// 只持弱引用，与捕获实例同一时机清空。
static id NJPiMxWrapperForView(id view) {
    if (!view) {
        return nil;
    }
    if (NJPiMxWrapperCached && NJPiMxWrapperOwner == (__bridge void *)view) {
        return NJPiMxWrapperCached;
    }
    id wrapper = nil;
    SEL getter = NSSelectorFromString(@"rendererWrapper");
    if ([view respondsToSelector:getter]) {
        wrapper = NJPiMxObjectGetter(view, getter);
    }
    if (!wrapper) {
        wrapper = NJPiMxValueForKey(view, @"_rendererWrapper");
    }
    if (!wrapper) {
        return nil;
    }
    if (![wrapper respondsToSelector:@selector(copyPixelBuffer)]
        && ![wrapper respondsToSelector:NSSelectorFromString(@"updateSyncForTimeStep:")]) {
        return nil; // 链对但类不对：按取不到处理，让 mx caps 把真实类名暴露出来
    }
    NJPiMxWrapperCached = wrapper;
    NJPiMxWrapperOwner = (__bridge void *)view;
    return wrapper;
}

// ── 一次性能力/ivar 自省（§15.21 A）──────────────────────────────────────────
// 每类首次见到实例时触发一次（封顶 4 类）：把类链 ivar 表和能力位打出来，把
// 「每帧 no_tex/no_img」变成可读事实——贴图字段在哪一层、视图响应哪些方法、
// wrapper 真实类名与能力。同结构按类去重；实例级取值是 probe 的职责。
static const char *NJPiMxIntrospectedClasses[4];
static NSUInteger NJPiMxIntrospectedCount = 0;

static void NJPiMxIntrospectOnce(id view, const char *why) {
    if (!view) {
        return;
    }
    const char *className = object_getClassName(view);
    for (NSUInteger index = 0; index < NJPiMxIntrospectedCount; index++) {
        if (strcmp(NJPiMxIntrospectedClasses[index], className) == 0) {
            return;
        }
    }
    if (NJPiMxIntrospectedCount >=
        sizeof(NJPiMxIntrospectedClasses) / sizeof(NJPiMxIntrospectedClasses[0])) {
        return;
    }
    NJPiMxIntrospectedClasses[NJPiMxIntrospectedCount++] = className;
    // 沿类链向上走到 NSObject（不含），链用于定位字段出现在哪一层。
    NSMutableString *chain = [NSMutableString string];
    NSUInteger totalIvars = 0;
    Class classes[6];
    NSUInteger classCount = 0;
    Class cls = object_getClass(view);
    while (cls && cls != [NSObject class] &&
           classCount < sizeof(classes) / sizeof(classes[0])) {
        classes[classCount++] = cls;
        unsigned int ivarCount = 0;
        Ivar *vars = class_copyIvarList(cls, &ivarCount);
        totalIvars += ivarCount;
        if (vars) {
            free(vars);
        }
        if (chain.length) {
            [chain appendString:@">"];
        }
        [chain appendString:NSStringFromClass(cls)];
        cls = class_getSuperclass(cls);
    }
    NJPiPDiag("mx ivars cls=%s n=%lu chain=%s why=%s", className, (unsigned long)totalIvars,
              chain.UTF8String ?: "-", why ?: "-");
    // ivar 分块打印（每行 ≤400 字符、最多 4 块），格式 名:类型编码:偏移。
    NSMutableString *part = [NSMutableString string];
    NSUInteger partNumber = 1;
    for (NSUInteger classIndex = 0; classIndex < classCount && partNumber <= 4; classIndex++) {
        unsigned int ivarCount = 0;
        Ivar *vars = class_copyIvarList(classes[classIndex], &ivarCount);
        for (NSUInteger ivarIndex = 0;
             vars && ivarIndex < ivarCount && partNumber <= 4; ivarIndex++) {
            NSString *entry = [NSString stringWithFormat:@"%s:%s:%ld",
                               ivar_getName(vars[ivarIndex]) ?: "-",
                               ivar_getTypeEncoding(vars[ivarIndex]) ?: "-",
                               (long)ivar_getOffset(vars[ivarIndex])];
            if (part.length + entry.length + 1u > 380u) {
                NJPiPDiag("mx ivars part%lu names=%s", (unsigned long)partNumber,
                          part.UTF8String);
                [part setString:@""];
                partNumber += 1;
            }
            if (part.length) {
                [part appendString:@","];
            }
            [part appendString:entry];
        }
        if (vars) {
            free(vars);
        }
    }
    if (partNumber <= 4 && part.length) {
        NJPiPDiag("mx ivars part%lu names=%s", (unsigned long)partNumber, part.UTF8String);
    }
    // 能力位：B 路弹幕源与降级顺序的直接判据（wrapper cpb → snapshot → view getRendererImage）。
    id wrapper = NJPiMxWrapperForView(view);
    BOOL snapCapable = NO;
    SEL snapSel = NSSelectorFromString(@"snapshot");
    if (wrapper && [wrapper respondsToSelector:snapSel]) {
        snapCapable = YES;
    } else if (wrapper && [wrapper respondsToSelector:NSSelectorFromString(@"renderer")]) {
        IMP rendererImp = [wrapper methodForSelector:NSSelectorFromString(@"renderer")];
        id renderer = rendererImp ? ((id (*)(id, SEL))rendererImp)(wrapper, NSSelectorFromString(@"renderer")) : nil;
        snapCapable = renderer && [renderer respondsToSelector:snapSel];
    }
    NJPiPDiag("mx caps cls=%s gmi=%d gri=%d rw=%d rwc=%s cpb=%d ust=%d _ust=%d setext=%d snap=%d",
              className,
              [view respondsToSelector:@selector(getMixedImage)] ? 1 : 0,
              [view respondsToSelector:NSSelectorFromString(@"getRendererImage")] ? 1 : 0,
              wrapper ? 1 : 0,
              wrapper ? object_getClassName(wrapper) : "-",
              wrapper && [wrapper respondsToSelector:@selector(copyPixelBuffer)] ? 1 : 0,
              wrapper && [wrapper respondsToSelector:NSSelectorFromString(@"updateSyncForTimeStep:")] ? 1 : 0,
              [view respondsToSelector:NSSelectorFromString(@"_updateSyncForTimeStep:")] ? 1 : 0,
              [view respondsToSelector:NSSelectorFromString(@"setExternalPixelBuffer:")] ? 1 : 0,
              snapCapable ? 1 : 0);
}

// 首次捕获 / 换实例 / 取帧失败时各一次：把「ivar 在不在、值是否非空、方法在不在」
// 直接打出来，回答该换哪条取帧路。字段名沿用既有约定。
// §15.21 修 bug：旧版是全局封顶 3 次，配额被捕获路径用光，导致 no_tex/no_img
// 失败路径的 probe 一次都没打（真机 20261024 日志正是缺这段证据）。改成按实例
// 去重（每台实例一次）+ 全局上限 8 台防实例抖动，并在同处触发按类的自省（mx ivars/mx caps）。
static void *NJPiMProbedViews[8];
static NSUInteger NJPiMProbedCount = 0;

static void NJPiMProbeViewObjects(id view, const char *why) {
    if (!view) {
        return;
    }
    void *candidate = (__bridge void *)view;
    for (NSUInteger index = 0; index < NJPiMProbedCount; index++) {
        if (NJPiMProbedViews[index] == candidate) {
            return; // 这台实例已经探过
        }
    }
    if (NJPiMProbedCount >= sizeof(NJPiMProbedViews) / sizeof(NJPiMProbedViews[0])) {
        return;
    }
    NJPiMProbedViews[NJPiMProbedCount++] = candidate;
    struct NJPiMxMetalObjects metal = { nil, nil, nil, nil, nil, nil, nil, nil };
    NJPiMxDiscoverMetal(view, &metal);
    id wrapper = NJPiMxWrapperForView(view);
    NJPiPDiag("mx view probe why=%s cls=%s addr=%p ext=%d rend=%d dev=%d q=%d pl=%d pass=%d img=%d sync=%d ivars=%d rw=%d",
              why, object_getClassName(view), view,
              NJPiMxViewTexture(view, @"_externalTexture") ? 1 : 0,
              NJPiMxViewTexture(view, @"_rendererTexture") ? 1 : 0,
              metal.device ? 1 : 0, metal.commandQueue ? 1 : 0,
              metal.pipelineState ? 1 : 0, metal.renderPass ? 1 : 0,
              [view respondsToSelector:@selector(getMixedImage)] ? 1 : 0,
              [view respondsToSelector:NSSelectorFromString(@"_updateSyncForTimeStep:")] ? 1 : 0,
              NJPiMViewHasTextureIvars(view) ? 1 : 0,
              wrapper ? 1 : 0);
    NJPiMxIntrospectOnce(view, why);
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
    return 1; // _updateSyncForTimeStep:：含我们自己的自驱，证据最弱
}

static void NJPiMCaptureFromHook(id instance, const char *via) {
    if (!instance) {
        return;
    }
    if (instance == NJPiMCapturedViewInstance) {
        return; // 最热路径：一次指针比较
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
        return; // 已评估过、又不构成升级：完全静默
    }
    if (NJPiMSeenCount < sizeof(NJPiMSeenViews) / sizeof(NJPiMSeenViews[0])) {
        NJPiMSeenViews[NJPiMSeenCount++] = candidate;
    }
    if (candidateRank < currentRank) {
        // 证据更弱的新实例：只观测、不接管（同一 App 里可能不止一个 cron 视图）。
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

// 自驱弹幕时钟：和 GPU 路同一个理由（PiP 后台时 display link 被系统暂停，
// 不驱动就反复拿同一帧）。调的是视图自己的 _updateSyncForTimeStep:
// （V1 @0x11484c16c / V2 @0x11484e19c，参数是「秒」的双精度数——V2 内部直接转发
// wrapper 的 updateSyncForTimeStep:），不是 wrapper 的公开版本：只有视图自己的
// 那个会把 copyPixelBuffer 的结果做成 _rendererTexture。Δt 上限同 GPU 路。
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
    // 自驱标记：hook 里的 NJPiMxNoteViewSyncObserved 会因此不把这次算作官方驱动，
    // wrap 路的「官方是否在驱动」判断才不会被我们自己的 pass 路污染。
    NJPiMxSelfDriving = 1;
    ((NJPiMxViewSyncIMP)implementation)(view, selector, seconds);
    NJPiMxSelfDriving = 0;
}

// ── wrap 路的 wrapper 取帧/补驱动（§15.21 B 专用）───────────────────────────
// copyPixelBuffer 是 Create Rule（+1），调用方负责释放（GPU 路 @2385 注释同款）。
typedef CVImageBufferRef (*NJPiMxCopyPixelBufferIMP)(id, SEL);

static CVImageBufferRef NJPiMxCallCopyPixelBuffer(id wrapper) {
    SEL selector = @selector(copyPixelBuffer);
    if (!wrapper || ![wrapper respondsToSelector:selector]) {
        return NULL;
    }
    IMP implementation = [wrapper methodForSelector:selector];
    if (!implementation) {
        return NULL;
    }
    NJPiMxWrapperCpbCalls += 1;
    return ((NJPiMxCopyPixelBufferIMP)implementation)(wrapper, selector);
}

// §15.23 补驱动判活：官方驱动看「近因」而非「历史」——真机判决（ff402e2）是前台
// onDisplayLink: @0x11484dcc4 →（异步 _cronRenderQueue block @0x11484e0b4）→
// _updateSyncForTimeStep: 正常步进（ust 一直在涨），入后台 CADisplayLink 停转后
// 官方步进归零，而旧条件「ust 历史非零就不补」把补驱动永久锁死——引擎没人 step、
// buffer_queue_ 恒空、copyPixelBuffer 恒 nil（no_tex）。现改为：最近 0.25s 内官方
// 步进过就让位（避免前台双驱动抢帧），否则由我们按合成帧率补 step。
// Δt 沿用视图自驱的同一钳制策略（上限 1s，超限按一帧）。
typedef void (*NJPiMxWrapperSyncIMP)(id, SEL, double);

static void NJPiMxDriveWrapperIfNeeded(id wrapper) {
    if (NJPiMxTimebase.denom == 0) {
        mach_timebase_info(&NJPiMxTimebase);
    }
    uint64_t lastOfficial = NJPiMxLastOfficialSyncTicks;
    if (lastOfficial != 0) {
        uint64_t gap = mach_absolute_time() - lastOfficial;
        if (NJPiMxNanoseconds((unsigned long long)gap) < 250.0 * 1e6) {
            return; // 官方仍在驱动，让位
        }
    }
    SEL selector = NSSelectorFromString(@"updateSyncForTimeStep:");
    if (![wrapper respondsToSelector:selector]) {
        return;
    }
    IMP implementation = [wrapper methodForSelector:selector];
    if (!implementation) {
        return;
    }
    static __unsafe_unretained id drivenWrapper = nil;
    static uint64_t lastTick = 0;
    uint64_t now = mach_absolute_time();
    double seconds = 0.0;
    if (lastTick != 0 && drivenWrapper == wrapper) {
        seconds = NJPiMxNanoseconds((unsigned long long)(now - lastTick)) / 1e9;
        if (seconds > NJP_MX_DRIVE_CLAMP_SECONDS) {
            seconds = NJP_MX_DRIVE_ONE_FRAME;
        }
    }
    lastTick = now;
    drivenWrapper = wrapper;
    NJPiMxWrapperDrives += 1;
    ((NJPiMxWrapperSyncIMP)implementation)(wrapper, selector, seconds);
}

#pragma mark - Mixed offscreen: keep the CRON engine running during PiP (§15.22)

// 真机 b284e67 的判决行是 mx sum 的 `cpb=553 us=0 ust=367`：补驱动全部执行、
// 官方视图一次没驱动，而 wrapper.copyPixelBuffer 每次都返回 nil。当时把原因
// 记作「V2 自驱泵没转」，反汇编把这版解释否证了——真正关帧的地方在更下游：
//
//   -[CRONEngine updateRunningState] @0x1151b6db0：读
//   [UIApplication applicationState]，==Background(2) 时走
//   sub_1152CA47C(box,0) = sub_1151B1C38(cpp,0,1) —— C++ 引擎挂起；
//   前台且 !isPaused 时走 sub_1152CA44C(box) = sub_1151B1C38(cpp,1,0) +
//   sub_1151B1EF0(cpp) —— 完整恢复。-[CRONEngine setPaused:] 只是写 _paused
//   再 tail-b 同一个 updateRunningState，所以 setPaused:NO 在后台照样挂起。
//   -[CRONRenderer copyPixelBuffer] @0x1151b8d38 弹的是 buffer_queue_，
//   引擎挂起后队列不再进帧 → 无论怎么驱动都是 no_tex。
//
// 修法不改全局 applicationState（全局谎报副作用不可控），两处配合：
//   1) wrap 路取帧前，对当前 wrapper 解析 renderer(CRONRenderer)→engine→
//      cppEngine(box)，直调官方完整恢复函数 sub_1152CA44C(box)——与官方前台
//      未暂停分支逐字同一条路。函数地址来自 8.89 索引，运行时用锚点自校准：
//      锚 = -[CRONEngine updateRunningState] 实际 IMP 与索引地址 0x1151b6db0
//      之差；差值不是页对齐（slide 必为页大小倍数）就整体放弃、回到现状，
//      绝不拿没对齐的地址盲调。
//   2) 换掉 -[CRONEngine updateRunningState] 的实现：闸门开着且此刻真是后台
//      时走恢复分支（否则入后台的通知会立刻把引擎再挂起，1) 的成果作废）；
//      其余一切情况调原实现——前台路径逐字保持官方行为。
// 关闸两条路都通：三个 delegate 代理的 didStop 直接清回 NO；即使 delegate 事件
// 没送到我们（真机 20261025 实测如此），enqueuer 的闸门变化同步也会清。不存在
// 「PiP 结束后引擎空转」的路径。
// 零参 id 返回的通用取物（无副作用 getter 专用；nil 安全）。
static id NJPiMxObjectViaSelector(id target, NSString *selectorName) {
    if (!target) {
        return nil;
    }
    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector]) {
        return nil;
    }
    IMP implementation = [target methodForSelector:selector];
    return implementation ? ((id (*)(id, SEL))implementation)(target, selector) : nil;
}

// 注意：cppEngine 返回的是裸 C++ 指针（EngineDarwin*，ivar 直读 ldr x0,[x0,#8]），
// 不是 ObjC 对象——取值必须按 void* 走，一旦声明成 id，ARC 会对 C++ vtable 头
// 插 objc_retain → 野指针崩溃（真机 20261025 16:2x 会话即死于此处）。
typedef void (*NJPiMxCronResumeIMP)(void *);
static inline void *NJPiMxRawCppEngine(id engine) {
    if (!engine) {
        return NULL;
    }
    SEL getter = NSSelectorFromString(@"cppEngine");
    IMP getterIMP = [engine methodForSelector:getter];
    return getterIMP ? ((void *(*)(id, SEL))getterIMP)(engine, getter) : NULL;
}
static NJPiMxCronResumeIMP NJPiMxCronResume = NULL;          // sub_1152CA44C 换算后的运行时地址
static IMP NJPiMxOriginalEngineRunningState = NULL;
static volatile BOOL NJPiMxEngineKeepRunning = NO;           // §15.22 引擎豁免标志（只随闸门动）
static unsigned long long NJPiMxEngineResumeLines = 0;
static void NJPiMxAppStateLieSet(BOOL on);                   // §15.25（定义在下方）

static void NJPiMxEngineNoteKeep(BOOL keep) {
    static BOOL lastKeep = NO;
    static BOOL first = YES;
    if (!first && keep == lastKeep) {
        return;
    }
    first = NO;
    lastKeep = keep;
    NJPiPDiag("mx eng keep=%d", (int)keep);
    NJPiMxAppStateLieSet(keep); // §15.25 引擎豁免窗口 = 谎报窗口（关闸即恢复真实状态）
}

// didStop（任意一个 delegate 代理收到）关闸：标志清回 NO，之后的
// updateRunningState 恢复官方原行为。failedToStart 不需要单独处理——
// 那种会话闸门从未开过，标志也从未置起。
static void NJPiMxEngineNoteStop(void) {
    NJPiMxEngineKeepRunning = NO;
    NJPiMxEngineNoteKeep(NO);
}

// §15.25 真状态读取（定义在下方；这里先用后声明，谎报钩在场时内部绕回原 IMP）。
static NSInteger NJPiMxRealAppState(void);

// -[CRONEngine updateRunningState] 的替换实现。除「闸门开 && 确实在后台」外
// 全部原样转原实现；那个唯一分支里调官方前台恢复函数（与官方非暂停分支同路）。
// 判定必须走 NJPiMxRealAppState——§15.25 谎报钩在场时直读 applicationState 恒 Active。
static void NJPiMxEngineRunningStateIMP(id self, SEL _cmd) {
    NJPiMxCronResumeIMP resume = NJPiMxCronResume;
    if (NJPiMxEngineKeepRunning && resume &&
        NJPiMxRealAppState() == UIApplicationStateBackground) {
        void *box = NJPiMxRawCppEngine(self);
        if (box) {
            if (NJPiMxEngineResumeLines < 12) {
                NJPiMxEngineResumeLines += 1;
                NJPiPDiag("mx eng resume=notify self=%s", object_getClassName(self));
            }
            resume(box);
            return;
        }
    }
    if (NJPiMxOriginalEngineRunningState) {
        ((void (*)(id, SEL))NJPiMxOriginalEngineRunningState)(self, _cmd);
    }
}

// 锚点自校准：只在第一次需要时做一次。任何一步不满足就放弃整套方案
// （不装钩、不调裸函数），行为回到 b284e67——失败模式必须是现状而不是崩溃。
static BOOL NJPiMxEngineCalibrate(void) {
    static dispatch_once_t onceToken;
    static BOOL calibrated = NO;
    dispatch_once(&onceToken, ^{
        Class engineClass = NSClassFromString(@"CRONEngine");
        if (!engineClass) {
            NJPiPDiag("mx eng calib=class-missing");
            return;
        }
        Method method = class_getInstanceMethod(engineClass, NSSelectorFromString(@"updateRunningState"));
        if (!method) {
            NJPiPDiag("mx eng calib=method-missing");
            return;
        }
        uintptr_t actual = (uintptr_t)method_getImplementation(method);
        uintptr_t delta = actual - (uintptr_t)0x1151b6db0;  // 索引地址（含 0x100000000 基）
        if (delta == 0 || (delta & 0x3FFF) != 0) {
            NJPiPDiag("mx eng calib=slide-reject delta=0x%llx", (unsigned long long)delta);
            return;
        }
        NJPiMxOriginalEngineRunningState = method_getImplementation(method);
        NJPiMxCronResume = (NJPiMxCronResumeIMP)((uintptr_t)0x1152ca44c + delta);
        method_setImplementation(method, (IMP)NJPiMxEngineRunningStateIMP);
        calibrated = YES;
        NJPiPDiag("mx eng calib=ok delta=0x%llx hook=on", (unsigned long long)delta);
    });
    return calibrated;
}

// 每 PiP 会话对一个 wrapper 只主动恢复一次（通知路径之外再补一次主动恢复，
// 覆盖「先入后台、通知早于首帧合成」的时序）。wrapper 换了实例就重新来。
static void NJPiMxEngineResumeOnce(id wrapper, id view) {
    if (!NJPiMxEngineCalibrate() || !wrapper) {
        return;
    }
    static __weak id resumedWrapper = nil;
    if (resumedWrapper == wrapper) {
        return;
    }
    id renderer = NJPiMxObjectViaSelector(wrapper, @"renderer");   // getter 内部已验 CRONRenderer 类
    id engine = NJPiMxObjectViaSelector(renderer, @"engine");
    if (!engine || ![engine respondsToSelector:NSSelectorFromString(@"cppEngine")]) {
        if (NJPiMxEngineResumeLines < 12) {
            NJPiMxEngineResumeLines += 1;
            NJPiPDiag("mx eng resume=chain-fail wr=%s renderer=%s engine=%s",
                      object_getClassName(wrapper),
                      renderer ? object_getClassName(renderer) : "-",
                      engine ? object_getClassName(engine) : "-");
        }
        return;
    }
    resumedWrapper = wrapper;
    void *box = NJPiMxRawCppEngine(engine);
    // GPU 许可顺带放行（真机静态证明它不在这条取帧路上，属低成本保险；
    // 回前台时官方 updateGpuState 会按真实状态写回）。
    if ([view respondsToSelector:NSSelectorFromString(@"setGpuAccessAllowed:")]) {
        IMP setter = [view methodForSelector:NSSelectorFromString(@"setGpuAccessAllowed:")];
        if (setter) {
            ((void (*)(id, SEL, BOOL))setter)(view, NSSelectorFromString(@"setGpuAccessAllowed:"), YES);
        }
    }
    NJPiPDiag("mx eng resume=proactive engine=%s box=%d", object_getClassName(engine), box ? 1 : 0);
    if (box) {
        NJPiMxCronResume(box);
    }
}

#pragma mark - Mixed offscreen: time-boxed applicationState lie (§15.25)

// 真机 98856bc 判决（§15.24 判读表第三分支）：snapshot=1、前台路完全通
// （out=28 dmsrc=snapshot，~36ms/帧），后台入口 ms=0.00 秒返 nil——渲染入口
// 有一个后台守卫，而它在 C++ 虚方法里（vtable 被 chained fixups 遮住，静态到
// 头）。官方代码里已确证的后台门只有一种花样：读 [UIApplication
// applicationState]==Background——§15.22 的引擎挂起、updateGpuState 的 GPU
// 放行、updateDisplayLinkState 全是这一种。本节是判决实验：引擎豁免期
// （§15.22 标志为 YES 的窗口）把 -[UIApplication applicationState] 的
// Background 谎报成 Active；关闸即恢复真实值。
//   弹幕出现   ⇒ 守卫就是 applicationState（官方代码或 C++ 侧间接受其驱动），
//              实验轮先整体谎报，后续再谈收窄；
//   弹幕仍无   ⇒ 守卫与 applicationState 无关（C++ 内部 running 标志或 Metal
//              后台资源限制），升级 frida gadget 动态断点，不再猜。
// 副作用已知且限时：谎报窗口内整个进程自认前台（官方播放器不暂停——PiP 本来
// 就要它活着；各统计/定时器回活——测试构建可接受，关闸立即恢复）。
// 我方一切内部判定与日志必须用 NJPiMxRealAppState，否则诊断字段失真、且
// §15.22 的 notify 分支会因恒见 Active 而失效。
static IMP NJPiMxOriginalAppState = NULL;
static volatile BOOL NJPiMxAppStateLie = NO;
static unsigned long long NJPiMxAppStateLieLines = 0;

static NSInteger NJPiMxAppStateIMP(id self, SEL _cmd) {
    if (NJPiMxAppStateLie) {
        if (NJPiMxAppStateLieLines < 24) {
            NJPiMxAppStateLieLines += 1;
            NJPiPDiag("mx lie read self=%s", object_getClassName(self));
        }
        return UIApplicationStateActive;
    }
    return ((NSInteger (*)(id, SEL))NJPiMxOriginalAppState)(self, _cmd);
}

static NSInteger NJPiMxRealAppState(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (NJPiMxAppStateLie && NJPiMxOriginalAppState) {
        return ((NSInteger (*)(id, SEL))NJPiMxOriginalAppState)(application, @selector(applicationState));
    }
    return application.applicationState;
}

static void NJPiMxAppStateLieSet(BOOL on) {
    if (on == NJPiMxAppStateLie) {
        return;
    }
    if (on) {
        static dispatch_once_t lieOnce;
        dispatch_once(&lieOnce, ^{
            Method method = class_getInstanceMethod([UIApplication class], @selector(applicationState));
            if (!method) {
                NJPiPDiag("mx lie hook=method-missing");
                return;
            }
            NJPiMxOriginalAppState = method_getImplementation(method);
            method_setImplementation(method, (IMP)NJPiMxAppStateIMP);
            NJPiPDiag("mx lie hook=on");
        });
        if (!NJPiMxOriginalAppState) {
            return;   // 钩没装上就绝不启谎报
        }
    }
    NJPiMxAppStateLie = on;
    NJPiPDiag("mx lie active=%d", (int)on);
}

static BOOL NJPiMxAppStateLieActive(void) {
    return NJPiMxAppStateLie ? YES : NO;
}

#pragma mark - Mixed offscreen: our own Metal fallbacks

// Compiled at runtime like the GPU path. Used only when the view's own pipeline
// could not be discovered but its textures could: sampling two BGRA textures with
// source-over for the danmaku is exactly the structure getMixedImage replays.
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
"fragment float4 nj_pip_mx_yuv(const NJPipMxVert in [[stage_in]],\n"
"                              constant float *matrix [[buffer(0)]],\n"
"                              texture2d<float> planeY [[texture(0)]],\n"
"                              texture2d<float> planeUV [[texture(1)]],\n"
"                              sampler s [[sampler(0)]]) {\n"
"    float y = planeY.sample(s, in.texCoord).r;\n"
"    float2 c = planeUV.sample(s, in.texCoord).rg - float2(0.5, 0.5);\n"
"    float3 rgb;\n"
"    for (int i = 0; i < 3; i += 1) {\n"
"        rgb[i] = matrix[i * 4] * y + matrix[i * 4 + 1] * c.x\n"
"               + matrix[i * 4 + 2] * c.y + matrix[i * 4 + 3];\n"
"    }\n"
"    return float4(rgb.b, rgb.g, rgb.r, 1.0);\n"
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
    if (!NJPiMxLibrary) {
        NJPiMxLibrary = [NJPiMxDevice newLibraryWithSource:[NSString stringWithUTF8String:NJPiMxMetalSource]
                                                   options:nil
                                                     error:&error];
    }
    if (!NJPiMxLibrary) {
        NJPiMxSetupFailure = "no-library";
        NJPiPDiag("mx fail reason=no_metal no-library err=%s", error.localizedDescription.UTF8String ?: "-");
        return NO;
    }
    id<MTLFunction> vertex = [NJPiMxLibrary newFunctionWithName:@"nj_pip_mx_vertex"];
    id<MTLFunction> copyFunction = [NJPiMxLibrary newFunctionWithName:@"nj_pip_mx_copy"];
    id<MTLFunction> blendFunction = [NJPiMxLibrary newFunctionWithName:@"nj_pip_mx_blend"];
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
    // Same blend math as the GPU path's danmaku pass (non-premultiplied source-over;
    // if a real device shows dark halos the renderer output is premultiplied and the
    // source factor must become One — the GPU path left the same note).
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

// YUV 管线是 wrap 路专用（真机的官方视频 sample 就是 420v），惰性编译：
// 它的失败不参与 pass/image 路的可用性判断，只有 wrap 路用到时才检查。
static BOOL NJPiMxOwnPipelineYuvAvailable(void) {
    if (NJPiMxOwnPipelineYuv) {
        return YES;
    }
    if (!NJPiMxOwnPipelinesAvailable()) {
        return NO;
    }
    id<MTLFunction> vertex = [NJPiMxLibrary newFunctionWithName:@"nj_pip_mx_vertex"];
    id<MTLFunction> yuvFunction = [NJPiMxLibrary newFunctionWithName:@"nj_pip_mx_yuv"];
    if (!vertex || !yuvFunction) {
        NJPiMxNoteFailure("no_metal", NULL);
        return NO;
    }
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.label = @"njpip-mixed-yuv";
    descriptor.vertexFunction = vertex;
    descriptor.fragmentFunction = yuvFunction;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    NSError *pipelineError = nil;
    NJPiMxOwnPipelineYuv = [NJPiMxDevice newRenderPipelineStateWithDescriptor:descriptor
                                                                       error:&pipelineError];
    if (!NJPiMxOwnPipelineYuv) {
        NJPiMxNoteFailure("no_metal", NULL);
        NJPiPDiag("mx fail reason=no_metal no-pl-yuv err=%s", pipelineError.localizedDescription.UTF8String ?: "-");
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

// Target pool: BGRA at the incoming frame's own size (the SBDL aspect-fits inside
// PiP, and every frame keeps the video's aspect — kCAGravityResizeAspect on the
// official layer is their on-screen fitting; for a sample-buffer content source
// the equivalent is feeding native-aspect frames, same contract the GPU path uses).
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
    *outTextureRef = textureRef; // same lifetime rule as the GPU path: the bridge must
                                 // outlive the GPU work; the caller moves it to the
                                 // command buffer's completion handler.
    return texture;
}

// ── wrap 路的视频层导入（§15.21 B）──────────────────────────────────────────
// 与 GPU 路的同名工具同体（那边在 NJ_PIP_GPU_COMPOSITE_ENABLED 里，两路各自关宏
// 时不能依赖对方还在编译），这里复制一份给 mixed 路用。
static BOOL NJPiMxIsYUV(OSType format) {
    return format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
}

static void NJPiMxYuvMatrix(OSType sourceFormat, BOOL bt709, float *matrix) {
    double kr = bt709 ? 0.2126 : 0.299;   // BT.601 default, BT.709 when the buffer says so
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

static BOOL NJPiMxWantsBT709(CVImageBufferRef image) {
    // Get（非 Copy）：返回的 CFTypeRef 不属于我们，不 CFRelease，读后立即用。
    CFTypeRef value = CVBufferGetAttachment(image, kCVImageBufferYCbCrMatrixKey, NULL);
    BOOL bt709 = NO;
    if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
        bt709 = CFStringCompare((CFStringRef)value, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0)
                == kCFCompareEqualTo;
    }
    return bt709;
}

// 把一个 CVImageBuffer 的某个平面桥接成 MTLTexture（wrap 路视频/弹幕层都用它）。
// 生命周期规则与 NJPiMxTargetTexture 相同：ref 由调用方移进 command buffer 完成
// 回调里释放，桥接活过 GPU 工作。
static id<MTLTexture> NJPiMxImportTexture(CVImageBufferRef image, MTLPixelFormat format,
                                          size_t width, size_t height, size_t planeIndex,
                                          CVMetalTextureRef *outTextureRef) {
    if (!image || !NJPiMxDevice) {
        return nil;
    }
    if (!NJPiMxTextureCache) {
        CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, NJPiMxDevice,
                                                    NULL, &NJPiMxTextureCache);
        if (status != kCVReturnSuccess || !NJPiMxTextureCache) {
            NJPiMxTextureCache = NULL;
            NJPiMxNoteFailure("no_metal", NULL);
            return nil;
        }
    }
    CVMetalTextureRef textureRef = NULL;
    if (CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, NJPiMxTextureCache, image,
                                                  NULL, format, width, height, planeIndex,
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
                             CMSampleBufferRef original); // forward: shared wrap tail

// pass 路：用视图自己的两张贴图 + 它的（或我们兜底的）Metal 对象做一次离屏 pass。
// 结构照抄 getMixedImage：目标像素缓冲 → 目标 Metal 纹理 → 单一 colorAttachment →
// 两趟 drawPrimitives（视频贴图为 copy 通道、弹幕贴图为 source-over 通道）。
static BOOL NJPiMxViewLogged = NO;
static id NJPiMxCompositePass(id view, CMSampleBufferRef original, CVImageBufferRef sourceImage,
                              const char *viewClass) {
    struct NJPiMxMetalObjects metal = { nil, nil, nil, nil, nil, nil, nil, nil };
    NJPiMxDiscoverMetal(view, &metal);
    id<MTLTexture> externalTexture = NJPiMxViewTexture(view, @"_externalTexture");
    id<MTLTexture> rendererTexture = NJPiMxViewTexture(view, @"_rendererTexture");
    if (!externalTexture) {
        // 区分两种失败（真机第二轮只有笼统的 no_tex）：ivar 在类链上但值为 nil → no_tex
        // （等供帧即可）；ivar 根本不存在 → no_ivar（取帧路必须换成 getMixedImage /
        // getRendererImage / wrapper copyPixelBuffer，再读 ivar 没有意义）。
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
    // Their objects when found; our own device/queue/pipeline as fallback.
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
    // Pipeline choice. Our own pipeline (compiled here, plain BGRA fullscreen
    // triangle) has fully known semantics and wins whenever the source textures
    // are BGRA — deterministic beats clever. Their pipeline is used only when the
    // textures are some other format (YUV on the GPU is plausible for
    // _externalTexture): our shader can't sample those, theirs is the only thing
    // that can, but its vertex-stage contract was never disassembled, so the
    // binding shape below is the best reading of getMixedImage's "swap the
    // texture, replay the draw" structure (分析文档 §1.3). plq records which one
    // was used so the device logs settle whether that reading was right.
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
        // 视图实例 + 两张贴图是否拿到 + 视图自己的 Metal 对象是否拿到 + 本帧选用的
        // pipeline（plq=own 我们编译的 / view 视图自己的）。V1/V2 的真实类名在这里
        // 报出（AB key v8.27.player.enable_mixed_render_main_thread 只能运行时确认）。
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
    // Their textures must live on the device we draw with (this matters most when
    // the view's own device could not be found and we fell back to ours:
    // MTLCreateSystemDefaultDevice hands out the same instance per GPU in-process
    // in the normal case, but if they are not the same object, sampling their
    // texture on our queue is invalid — check by name (device names are stable
    // per GPU) and refuse rather than draw wrong).
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
            CFRelease(targetTextureRef); // CVMetalTextureRef 是 CF 类型；与 GPU 路完成回调同一释放方式
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
        // Their pipeline, their texture formats. Binding shape follows what
        // getMixedImage replays (swap the texture on the same slot, replay the
        // draw) — the only shape the disassembly supports. plq=view records the
        // bet; if the device shows garbage frames with this, the vertex-stage
        // contract was wrong and the image route is the answer.
        [encoder setRenderPipelineState:metal.pipelineState];
        [encoder setFragmentTexture:externalTexture atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        if (rendererTexture) {
            [encoder setFragmentTexture:rendererTexture atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        }
    } else {
        // Our pipelines, known semantics: video as an opaque copy pass, danmaku
        // source-over on top — the same visible result, fully under our control.
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
    // 与 GPU 路同一条生命周期规则：CoreVideo 的纹理桥必须活过 GPU 工作，
    // 引用移交给 commandBuffer 的完成回调；环形缓冲让像素本体活到被换出。
    CFRetain(targetTextureRef);
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        CFRelease(targetTextureRef);
    }];
    [commandBuffer commit]; // GPU work is async; the ring below keeps the pixels alive
    id wrapped = NJPiMxWrapProduced(targetImage, sourceImage, original);
    CVPixelBufferRelease(targetImage);
    return wrapped;
}

// image 路（退化）：调视图自己的 getMixedImage 拿官方已经合成好的 UIImage，
// 再把它的 CGImage 画进我们池里的 BGRA 缓冲（一次 CPU blit；这是任务允许的退化，
// 不是主路）。getMixedImage 内部就是上面那条 offscreen 路的官方实现，所以它
// 不需要我们发现任何 ivar——V1 @0x11484cc5c 与 V2 @0x11484e754 都存在。
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
        // getMixedImage 内部就是靠那两张贴图做离屏 pass 的；它返回 nil 大概率还是
        // 贴图没被供出来。探测一次把证据固定下来（封顶 3 行，不会刷屏）。
        NJPiMProbeViewObjects(view, "no_img");
        NJPiMxNoteFailure("no_img", original);
        return nil;
    }
    // 用 UIImage 的类型化属性拿 CGImage（+0，同步绘制即可）；KVC 拿会触发
    // id→C 指针的桥接报错（run 40063065730 :3938）。
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

// ── wrap 路（§15.21 B 主路）：视频层=正在入队的这一帧，弹幕层=wrapper 的 copyPixelBuffer ──
// 真机的 reframing：视频层我们手里就有（mx src 行确证 fmt=420v size=852x480 正被
// hook），只缺弹幕层。官方把两层在视图里一起烤，但那两张贴图（_externalTexture/
// _rendererTexture）真机恒 nil（probe ext=0 rend=0），所以这条路不押任何私有 ivar。
// 弹幕源优先级与降级：
//   1) [view rendererWrapper] 缓存 → updateSyncForTimeStep:（§15.23：官方近 0.25s
//      步进过就让位，否则补 step）→ copyPixelBuffer（无参，+1）。这就是官方
//      _updateSyncForTimeStep: 内部走的同一条取帧路。
//   2) 队列无帧 → §15.24 snapshot 同步渲染：wrapper→renderer→engine 链上第一个
//      响应 snapshot 的对象现做一次同步离屏渲染出 UIImage（引擎 C++ 直接出 CGImage，
//      不依赖 buffer_queue_ 与 CADisplayLink——与直播官方 PiP 的按需渲染同构）。
//   3) 还没有 → [view getRendererImage]（视图级 offscreen pass，代价高，仅作降级）。
//   4) 都没有 → no_dmsrc，并打一行带能力位的 detail，直接可读。
// 合成复用 pass 路那套自有 Metal 对象（NJPiMxDevice/Sampler/pipeline 族）：真机视频
// 层是 420v，走 nj_pip_mx_yuv；再 source-over 叠弹幕层；产出照旧走 WrapProduced
// （attachments/timing 逐字照抄，不新建第二个 PiP、不改 content source——15.19 原则）。
static BOOL NJPiMxDmsrcDetailLogged = NO;

// §15.24：CGImage → 自有 BGRA 缓冲（blend 通道只采样 BGRA；snapshot 与
// getRendererImage 两条路共用）。返回 +1 引用，失败返回 NULL。
static CVPixelBufferRef NJPiMxPixelBufferFromCGImage(CGImageRef cgImage) {
    size_t dmWidth = CGImageGetWidth(cgImage);
    size_t dmHeight = CGImageGetHeight(cgImage);
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary<NSString *, id> *attributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{},
    };
    if (dmWidth == 0 || dmHeight == 0
        || CVPixelBufferCreate(kCFAllocatorDefault, dmWidth, dmHeight,
                               kCVPixelFormatType_32BGRA,
                               (__bridge CFDictionaryRef)attributes,
                               &pixelBuffer) != kCVReturnSuccess
        || !pixelBuffer) {
        return NULL;
    }
    BOOL drew = NO;
    if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) == kCVReturnSuccess) {
        void *base = CVPixelBufferGetBaseAddress(pixelBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = base && colorSpace
            ? CGBitmapContextCreate(base, dmWidth, dmHeight, 8, bytesPerRow, colorSpace,
                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst)
            : NULL;
        if (context) {
            CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)dmWidth, (CGFloat)dmHeight),
                               cgImage);
            CGContextRelease(context);
            drew = YES;
        }
        if (colorSpace) {
            CGColorSpaceRelease(colorSpace);
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    if (!drew) {
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
    return pixelBuffer; // +1
}

// §15.24 snapshot 取帧路：-[CRONRenderer snapshot] @0x1151b8b08 是纯转发
// （[[self engine] snapshot]）；-[CRONEngine snapshot] @0x1151b6aa4 直接调 C++
// （sub_1151AB11C：组请求 → sub_1151B16F4 同步离屏渲染一帧 → 输出 CGImage），
// 最后包成 UIImage 返回。它不经过 buffer_queue_、不依赖 CADisplayLink——官方
// 直播弹幕 PiP（BBLiveBCDanmakuVideoComposition newRenderedPixelBufferForRequest:）
// 就是同构的「按需同步渲染」，而队列泵在后台是死的（5e21bce 判决：cpb=97 us=81
// 全 nil）。链：wrapper 自己 → renderer → engine，第一个响应 snapshot 者出帧。
static id NJPiMxSnapshotImage(id wrapper) {
    SEL selector = NSSelectorFromString(@"snapshot");
    id candidates[3];
    NSUInteger count = 0;
    candidates[count++] = wrapper;
    id renderer = NJPiMxObjectViaSelector(wrapper, @"renderer");
    if (renderer) {
        candidates[count++] = renderer;
        id engine = NJPiMxObjectViaSelector(renderer, @"engine");
        if (engine) {
            candidates[count++] = engine;
        }
    }
    for (NSUInteger index = 0; index < count; index++) {
        if (![candidates[index] respondsToSelector:selector]) {
            continue;
        }
        IMP implementation = [candidates[index] methodForSelector:selector];
        if (!implementation) {
            continue;
        }
        id image = ((NJPiMxGetImageIMP)implementation)(candidates[index], selector);
        if (image) {
            return image;
        }
    }
    return nil;
}

static id NJPiMxCompositeWrap(id view, CMSampleBufferRef original, CVImageBufferRef sourceImage,
                              const char *viewClass) {
    OSType sourceFormat = CVPixelBufferGetPixelFormatType(sourceImage);
    NSUInteger width = CVPixelBufferGetWidth(sourceImage);
    NSUInteger height = CVPixelBufferGetHeight(sourceImage);
    // ── 弹幕层 ──
    CVPixelBufferRef danmakuImage = NULL;
    const char *dmSource = "none";
    id wrapper = NJPiMxWrapperForView(view);
    if (wrapper) {
        // §15.22：先将引擎保持在运行态（每会话一次），再走取帧路——引擎被官方
        // 入后台挂起时，后面的驱动与 copyPixelBuffer 才有帧可取。
        NJPiMxEngineResumeOnce(wrapper, view);
        NJPiMxDriveWrapperIfNeeded(wrapper);
        danmakuImage = NJPiMxCallCopyPixelBuffer(wrapper); // +1
        if (danmakuImage) {
            OSType danmakuFormat = CVPixelBufferGetPixelFormatType(danmakuImage);
            if (danmakuFormat != kCVPixelFormatType_32BGRA) {
                // 与 GPU 路同一约束：blend 通道只采样 BGRA，别的明确报出。
                NJPiPDiag("mx fail reason=fmt dmsrc=wrapper dmfmt=%s dm=%lux%lu",
                          NJPiMxFourcc(danmakuFormat),
                          (unsigned long)CVPixelBufferGetWidth(danmakuImage),
                          (unsigned long)CVPixelBufferGetHeight(danmakuImage));
                NJPiMxNoteFailure("fmt", original);
                CVPixelBufferRelease(danmakuImage);
                danmakuImage = NULL;
            } else {
                dmSource = "wrapper";
            }
        } else {
            // wrapper 在但本帧没出图：还没被驱动、或弹幕当前为空帧。
            // 是缺驱动还是没内容，看 mx sum 的 us/ust 区分（ust=0 且 us 增长仍 nil
            // 才是真的没内容）。
            NJPiMxNoteFailure("no_tex", original);
        }
    }
    if (!danmakuImage && wrapper) {
        // §15.24：队列没有帧 → 让引擎同步离屏渲染一帧（snapshot 路）。这是官方
        // 直播 PiP 的取帧形态；不依赖那条在后台死掉的队列。
        id snap = NJPiMxSnapshotImage(wrapper);
        Class snapImageClass = NSClassFromString(@"UIImage");
        CGImageRef snapCG = (snap && snapImageClass && [snap isKindOfClass:snapImageClass])
                                ? ((UIImage *)snap).CGImage : NULL;
        if (snapCG) {
            danmakuImage = NJPiMxPixelBufferFromCGImage(snapCG);
            if (danmakuImage) {
                dmSource = "snapshot";
            }
        }
        if (!danmakuImage) {
            NJPiMxNoteFailure("no_snap", original);
        }
    }
    if (!danmakuImage && [view respondsToSelector:NSSelectorFromString(@"getRendererImage")]) {
        SEL getter = NSSelectorFromString(@"getRendererImage");
        IMP implementation = [view methodForSelector:getter];
        id image = implementation ? ((NJPiMxGetImageIMP)implementation)(view, getter) : nil;
        Class uiImageClass = NSClassFromString(@"UIImage");
        CGImageRef cgImage = (image && uiImageClass && [image isKindOfClass:uiImageClass])
            ? ((UIImage *)image).CGImage : NULL;
        if (cgImage) {
            danmakuImage = NJPiMxPixelBufferFromCGImage(cgImage);
            if (danmakuImage) {
                dmSource = "getRendererImage";
            }
        }
    }
    if (!danmakuImage) {
        if (!NJPiMxDmsrcDetailLogged) {
            NJPiMxDmsrcDetailLogged = YES;
            id detailWrapper = NJPiMxWrapperForView(view);
            NJPiPDiag("mx fail detail reason=no_dmsrc cls=%s rw=%d rwc=%s cpb=%d gri=%d",
                      viewClass, detailWrapper ? 1 : 0,
                      detailWrapper ? object_getClassName(detailWrapper) : "-",
                      detailWrapper && [detailWrapper respondsToSelector:@selector(copyPixelBuffer)] ? 1 : 0,
                      [view respondsToSelector:NSSelectorFromString(@"getRendererImage")] ? 1 : 0);
        }
        NJPiMxNoteFailure("no_dmsrc", original);
        return nil;
    }
    NJPiMxDmSourceName = dmSource;
    // ── 自有 Metal pass：视频层（yuv/copy）+ 弹幕层（blend）→ 池里的 BGRA ──
    NJPiMxEnsureOwnDevice();
    if (!NJPiMxDevice || !NJPiMxCommandQueue || !NJPiMxSampler) {
        CVPixelBufferRelease(danmakuImage);
        return nil; // no_metal 已由 EnsureOwnDevice 记
    }
    BOOL yuv = NJPiMxIsYUV(sourceFormat);
    if (!NJPiMxOwnPipelinesAvailable() || (yuv && !NJPiMxOwnPipelineYuvAvailable())) {
        CVPixelBufferRelease(danmakuImage);
        return nil; // no_metal 已由可用性函数记
    }
    CVPixelBufferRef targetImage = NJPiMxTargetBuffer(width, height);
    if (!targetImage) {
        CVPixelBufferRelease(danmakuImage);
        return nil;
    }
    CVMetalTextureRef targetTextureRef = NULL;
    id<MTLTexture> targetTexture = NJPiMxTargetTexture(targetImage, NJPiMxDevice, &targetTextureRef);
    CVMetalTextureRef videoYRef = NULL, videoUVRef = NULL, videoSingleRef = NULL;
    CVMetalTextureRef danmakuRef = NULL;
    id<MTLTexture> videoY = nil, videoUV = nil, videoSingle = nil, danmakuTexture = nil;
    float matrix[16] = { 0 };
    id<MTLCommandBuffer> commandBuffer = nil;
    id wrapped = nil;
    do {
        if (!targetTexture) {
            break;
        }
        if (yuv) {
            videoY = NJPiMxImportTexture(sourceImage, MTLPixelFormatR8Unorm,
                                         (size_t)width, (size_t)height, 0, &videoYRef);
            videoUV = NJPiMxImportTexture(sourceImage, MTLPixelFormatRG8Unorm,
                                          (width + 1) / 2, (height + 1) / 2, 1, &videoUVRef);
            if (!videoY || !videoUV) {
                break;
            }
            NJPiMxYuvMatrix(sourceFormat, NJPiMxWantsBT709(sourceImage), matrix);
        } else {
            videoSingle = NJPiMxImportTexture(sourceImage, MTLPixelFormatBGRA8Unorm,
                                              (size_t)width, (size_t)height, 0, &videoSingleRef);
            if (!videoSingle) {
                break;
            }
        }
        danmakuTexture = NJPiMxImportTexture(danmakuImage, MTLPixelFormatBGRA8Unorm,
                                             CVPixelBufferGetWidth(danmakuImage),
                                             CVPixelBufferGetHeight(danmakuImage), 0, &danmakuRef);
        if (!danmakuTexture) {
            break;
        }
        commandBuffer = [NJPiMxCommandQueue commandBuffer];
        if (!commandBuffer) {
            NJPiMxNoteFailure("no_cb", original);
            break;
        }
        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = targetTexture;
        pass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
        if (!encoder) {
            NJPiMxNoteFailure("no_enc", original);
            break;
        }
        [encoder setCullMode:MTLCullModeNone];
        MTLViewport viewport = { 0.0, 0.0, (double)width, (double)height, 0.0, 1.0 };
        [encoder setViewport:viewport];
        [encoder setFragmentSamplerState:NJPiMxSampler atIndex:0];
        if (yuv) {
            [encoder setRenderPipelineState:NJPiMxOwnPipelineYuv];
            [encoder setFragmentBytes:matrix length:sizeof(matrix) atIndex:0];
            [encoder setFragmentTexture:videoY atIndex:0];
            [encoder setFragmentTexture:videoUV atIndex:1];
        } else {
            [encoder setRenderPipelineState:NJPiMxOwnPipelineCopy];
            [encoder setFragmentTexture:videoSingle atIndex:0];
        }
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder setRenderPipelineState:NJPiMxOwnPipelineBlend];
        [encoder setFragmentTexture:danmakuTexture atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        CVMetalTextureCacheFlush(NJPiMxTextureCache, 0);
        // 与 pass/GPU 路同一条生命周期规则：纹理桥引用移交给完成回调，
        // 环形缓冲让像素本体活到被换出。
        CFRetain(targetTextureRef);
        if (videoYRef) { CFRetain(videoYRef); }
        if (videoUVRef) { CFRetain(videoUVRef); }
        if (videoSingleRef) { CFRetain(videoSingleRef); }
        if (danmakuRef) { CFRetain(danmakuRef); }
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            CFRelease(targetTextureRef);
            if (videoYRef) { CFRelease(videoYRef); }
            if (videoUVRef) { CFRelease(videoUVRef); }
            if (videoSingleRef) { CFRelease(videoSingleRef); }
            if (danmakuRef) { CFRelease(danmakuRef); }
        }];
        [commandBuffer commit];
        wrapped = NJPiMxWrapProduced(targetImage, sourceImage, original);
    } while (0);
    if (targetTextureRef) { CFRelease(targetTextureRef); }
    if (videoYRef) { CFRelease(videoYRef); }
    if (videoUVRef) { CFRelease(videoUVRef); }
    if (videoSingleRef) { CFRelease(videoSingleRef); }
    if (danmakuRef) { CFRelease(danmakuRef); }
    CVPixelBufferRelease(targetImage);
    CVPixelBufferRelease(danmakuImage);
    return wrapped;
}

// 产出的 CVPixelBuffer → CMSampleBuffer：与 GPU 路完全一致的尾部（时间轴逐字照抄、
// 样本 attachments 全量拷贝、环形缓冲续命）。
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
    // §15.21 路线顺序：wrap（手里这帧 + wrapper 弹幕层，不依赖视图两张贴图）→
    // pass（视图的两张贴图）→ image（官方 getMixedImage）。粘住已验证的路线。
    // 自驱时钟只属于 pass 路（它要的是视图内部产出的贴图）：wrap 路不驱视图、
    // 只按 ust 判断要不要补驱 wrapper，避免双驱动，也保证 ust 不被自驱污染。
    unsigned long long startedAt = mach_absolute_time();
    id wrapped = nil;
    if (NJPiMxRoute != NJP_MX_ROUTE_PASS && NJPiMxRoute != NJP_MX_ROUTE_IMAGE) {
        wrapped = NJPiMxCompositeWrap(view, original, sourceImage, viewClass);
        if (wrapped && NJPiMxRoute != NJP_MX_ROUTE_WRAP) {
            NJPiMxRoute = NJP_MX_ROUTE_WRAP;
            if (!NJPiMxInitLogged) {
                NJPiMxInitLogged = YES;
                NJPiPDiag("mx init route=wrap viewcls=%s dmsrc=%s pool=ok",
                          viewClass, NJPiMxDmSourceName);
            }
        }
    }
    if (!wrapped && NJPiMxRoute != NJP_MX_ROUTE_IMAGE) {
        // 先自驱弹幕时钟，再取帧：V2 把 _rendererTexture 的更新排在 main queue，
        // 本帧用到的贴图是上一次驱动的产物（晚一帧，30fps 下无感）；V1 的
        // _updateSyncForTimeStep: 只把 copyPixelBuffer 结果存进 _cronRenderBufferRef，
        // 贴图转换在它的 onDisplayLink 里（PiP 后台被暂停）——V1 上这两张贴图大概率
        // 不新鲜，exchg/rendchg 会把这个结论直接记在日志里。
        NJPiMxDriveViewChronos(view);
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
        // 两条路都实现，运行时按可用性自动选：pass 拿不到贴图/Metal 对象就走 image。
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

// 真机第一轮暴露的缺陷：插层路已经通过 ov state 行确证了 controller 和官方
// content source 都在，混合路却只用属性探测，并在日志里只报 pip=0 不报依据。
// 现在按权威度排序，且来源名原样进日志（mx gate 行），错了能看出来：
// 1) controller-callback：我们挂在官方 controller 上的 delegate 代理收到过
//    pictureInPictureControllerDidStartPictureInPicture:（didStop/failedToStart 清掉）。
//    这是系统发出的事件，不是推断；ov didStart 行早已证明这条观测通路是通的。
// 2) layer-probe：controller.pictureInPictureActive 属性（系统状态直读，作为兜底）。
// 3) contentsource：mirror 路在 PiP 中接管 contentSource 时留下的 isPresenting
//    （adoptContentSourceDuringPictureInPicture），证明 PiP 正在用我们的源，
//    但事件时序不如 1)。
// 没有第四种推断：三个来源全部是已解析的官方对象/官方回调。
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

// 真机第一轮的第二个缺陷：role 用 view.layer 与官方层比对，出现
// layerAddr=0x1163e2680 与 ov state 的 layer=0x3149a2900 对不上的假象——
// enqueue 真正投递的目标是 ivar _mLayer（8.89 转储 :1474401；-
// [IJKSDLSampleBufferView enqueueSmapleBuffer:]@0x114df692c 的 bl 目标就是它，
// 见 Tools/Analysis/pip-sbdl-topology-2026-10-24.md），不是 view.layer。
// 这里解析的就是那个目标层，并与登记表 NJPiPOverlayState.officialLayer
// （contentSource.sampleBufferDisplayLayer 的权威来源）比对。
static CALayer *NJPiMxDestinationLayer(id view) {
    if (!view) {
        return nil;
    }
    // ARC 下 object_getInstanceVariable 被标记 unavailable（run 40069206216），
    // 唯一可用组合是 class_getInstanceVariable + object_getIvar。
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

// 登记表里第一个（通常也是唯一一个）官方 PiP 层；顺带回答 needle 是否命中。
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

// 只有这四种，全是确证语义（拓扑报告同上文件）：
// pip-layer = 目标层就是官方 PiP 层，且本视图不在任何窗口里（离屏供帧视图）；
// shared    = 同一个 SBDL 既挂在窗口里又被 content source 引用；
// inapp-layer = 目标层在窗口里但不是 PiP 层（正常 in-app 供帧，合成应跳过）；
// unknown   = 解析不出目标层 / 层不在窗口里也不是 PiP 层（等运行时再归类）。
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

// 每实例只在「目标层首次出现 / 发生变化」时打一行 mx src，总量封顶。
// dst= 是真正被 enqueue 的 SBDL；pipLayer= 是登记到的官方层（0x0=还没登记）；
// match= 是两者指针比对。低 1 位借用指针对齐存放 match，变化即重打。
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
    // 闸门结论每次变化打一行（含首次），判定本身可审计。
    static BOOL lastGateActive = NO;
    static NSString *lastGateSource = nil;
    if (gate.active != lastGateActive || ![lastGateSource isEqualToString:@(gate.source)]) {
        lastGateActive = gate.active;
        lastGateSource = @(gate.source);
        NJPiPDiag("mx gate pip=%d src=%s", (int)gate.active, gate.source);
        // §15.22：引擎豁免标志随闸门同步——开闸后后台的 updateRunningState 走恢复
        // 分支，关闸立刻回到官方原行为（delegate 事件没送到的会话里，这里就是关闸权威）。
        NJPiMxEngineKeepRunning = gate.active;
        NJPiMxEngineNoteKeep(gate.active);
    }
    BOOL composited = NO;
    if (gate.active && (strcmp(role, "pip-layer") == 0 || strcmp(role, "shared") == 0)) {
        composited = YES;
        enqueued = NJPiMxComposite(sampleBuffer);
    }
    // 上限 5→20：第一轮 5 条配额在进后台之前就烧光了，PiP 期间一条没留。
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
    // Same target selectors and the same own-method-only rule as the GPU path
    // (the enqueueSmapleBuffer: misspelling is the app's own, 8.89 dump :1474477).
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
            continue; // already hooked on the other class
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

// 启动点在文件末尾的 %ctor 里，与 GPU 路同一个时刻规则。
static void NJPiMxStart(void) {
    if (!NJPiPDanmakuEnabled()) {
        NJPiPDiag("mx load skipped feature-off");
        return;
    }
    NJPiMxStartSummary();
    NJPiMxInstallHooks();
}

// PiP didStop / SBManager / PlayerContainer / AVPictureInPictureController dealloc
// 处调用：先把这个窗口的 mx sum 追加进缓冲，再把缓冲整体落盘（含局域网上传）。
// 真机第一轮会话只有 ~9s，30s 周期永远打不出来——现在 5s 一次 + 结束时强制一次。
static void NJPiMxFlushNow(void) {
    dispatch_async(NJPiPDiagQueue(), ^{
        NJPiMxSummaryTick();
        NJPiPDiagFlushLocked();
    });
}

// 注：BFCCRON 渲染视图的捕获钩子不放在这里——`%hook` 会被 logos 在 C 预处理之前
// 展开，放进 #if 里会变成未初始化的 _ungrouped 组（本文件只有 %init(App)，没有
// 裸 %init），logos 直接报 non-initialized hook group。正确写法见下面 %group App
// 里 BBPlayerDanmakuVoutView 旁边的三个 BFCCRON 钩子：hook 常驻，只把调用那一句
// 包进 #if。capture 辅助函数本身（NJPiMCaptureFromHook 等）仍在本开关内。
#endif // NJ_PIP_MIXED_OFFSCREEN_ENABLED

static void NJPiPDiagHeartbeat(void) {
    int applicationState = 0;
    UIApplication *application = UIApplication.sharedApplication;
    if (application) {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
        applicationState = (int)NJPiMxRealAppState(); // 谎报窗口内仍报真实状态
#else
        applicationState = (int)application.applicationState;
#endif
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
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
        applicationState = (int)NJPiMxRealAppState(); // 谎报窗口内仍报真实状态
#else
        applicationState = (int)application.applicationState;
#endif
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

    // IJK's display-layer samples intentionally carry invalid presentation
    // timestamps and depend on state inside its private renderer.  Even a copied
    // DisplayImmediately attachment is not sufficient for a second independent
    // AVSampleBufferDisplayLayer.  Re-wrap the already-decoded CVPixelBuffer in a
    // standard ready sample with a host-clock PTS.  This retains the pixel buffer;
    // it does not decode again or copy its pixels.
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

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 failedToStartPictureInPictureWithError:(NSError *)error {
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
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMxEngineNoteStop(); // §15.22 关闸
#endif
    [self.state restoreContent];
    if ([self.downstream respondsToSelector:_cmd]) {
        [self.downstream pictureInPictureControllerDidStopPictureInPicture:controller];
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)controller
 restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
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
    // The video-call content source requires a running control timebase to
    // display the sample buffer display layer's content.  A NULL timebase
    // causes the system to wait indefinitely for the first frame (gray screen
    // + loading spinner).  The source layer is actively rendering, so it owns
    // a running timebase; reuse it via KVC instead of creating a new one.
    // This avoids the CMTimebase* creation APIs, which this build environment's
    // CoreMedia does not export (only the getter functions link).  The mirror
    // shows the same sample buffers as the source, so the PTS and the reused
    // timebase share the same time domain and frames display immediately.
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
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    // 第三条路要的是对象图的第一环（服务本体）；context/cron view 不在这存，
    // 取帧时从 self 现读，播放器复用换绑后自然就跟着换。
    NJPiMxRememberDanmakuService(self);
#endif
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    // GPU 合成那条路要的是对象图的第一环（服务本体）；context 不在这里存，
    // 取帧时从 self 现读 -context，播放器复用换绑后自然就跟着换。
    NJPiGpuRememberDanmakuService(self);
#endif
    return result;
}

- (void)serviceOnStart {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] DanmakuService start self=%p view=%p time=%.3f rate=%.3f",
                     self, [self view], [self currentTime], [self playbackRate]);
    NJPiPDiag("dm service start");
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
    NJPiPDiag("dm service stop");
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
    NJPiPDiag("sbg init");
    return result;
}

- (BOOL)needsBindingPlayerContainer {
    BOOL result = %orig;
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager needsBinding self=%p result=%d status=%ld",
                     self, result, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg needsBinding=%d status=%ld", (int)result, (long)[self pictureInPictureStatus]);
    return result;
}

- (void)bindGraftData:(id)graftData shareId:(id)shareId dataSource:(id)dataSource completion:(id)completion {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager bind shared self=%p graft=%p(%{public}s) share=%p source=%p(%{public}s) completion=%p",
                      self, graftData, NJPiPClassName(graftData), shareId,
                      dataSource, NJPiPClassName(dataSource), completion);
    NJPiPDiag("sbg bind share");
    %orig;
}

- (void)bindGraftData:(id)graftData ugcDataSourceAdapter:(id)adapter completion:(id)completion {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager bind UGC self=%p graft=%p(%{public}s) adapter=%p(%{public}s) completion=%p",
                      self, graftData, NJPiPClassName(graftData),
                      adapter, NJPiPClassName(adapter), completion);
    NJPiPDiag("sbg bind ugc");
    %orig;
}

- (void)prepareToStart {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager prepare self=%p status=%ld needsBinding=%d",
                     self, (long)[self pictureInPictureStatus], [self needsBindingPlayerContainer]);
    NJPiPDiag("sbg prepare status=%ld", (long)[self pictureInPictureStatus]);
    %orig;
}

- (void)stopPreparing {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stopPreparing self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg stopPreparing");
    %orig;
}

- (void)start {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager start self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg start");
    %orig;
}

- (void)stop {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stop self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg stop");
    %orig;
}

- (void)stopWithReason:(NSInteger)reason {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager stopWithReason self=%p reason=%ld status=%ld",
                     self, (long)reason, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg stopWithReason=%ld", (long)reason);
    %orig;
}

- (void)setPictureInPictureStatus:(NSInteger)status {
    NSInteger oldStatus = [self pictureInPictureStatus];
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager status self=%p old=%ld new=%ld",
                     self, (long)oldStatus, (long)status);
    NJPiPDiag("sbg status old=%ld new=%ld", (long)oldStatus, (long)status);
    %orig;
}

- (void)dealloc {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] SBManager dealloc self=%p status=%ld",
                     self, (long)[self pictureInPictureStatus]);
    NJPiPDiag("sbg dealloc");
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMxFlushNow();
    NJPiMxForgetCapturedViews("sbg");
#endif
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
    NJPiPDiag("sbgc init");
    return result;
}

- (void)director_didPrepared {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer prepared self=%p thread=%{public}s",
                     self, NSThread.currentThread.description.UTF8String);
    NJPiPDiag("sbgc prepared");
    %orig;
}

- (void)director_didComplete {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer complete self=%p",
                     self);
    NJPiPDiag("sbgc complete");
    %orig;
}

- (void)dealloc {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPTrace] PlayerContainer dealloc self=%p", self);
    NJPiPDiag("sbgc dealloc");
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMxFlushNow();
    NJPiMxForgetCapturedViews("sbgc");
#endif
    %orig;
}

%end

@interface BBPlayerDanmakuVoutView : NSObject
- (void)setupRenderer:(id)renderer;
@end

// 这个类在 8.89 转储里是 NSObject（tmp/re89/objc-headers.txt:1404291），不是 UIView，
// 所以原来那个 -didMoveToWindow hook 永远不会被调用（UIKit 不会给 NSObject 发这个方法），
// 它想做的「拿到 vout 对象时登记」也就从来没发生过。这里改成登记在它真正发生的时刻：
// -setupRenderer: 是把 BFCChronosRendererWrapper 装进 _rendererWrapper 的地方。
// 在线路径不依赖这里（走上面的对象图），这里只给录制/下载那条 fallback 用。
//
// 注意：`%hook` 不能整块包在 `#if` 里——logos 在 C 预处理之前就展开 `%hook`，
// 生成的 ctor 仍然会引用 `_logos_method$…$setupRenderer$`，而函数定义被预处理裁掉，
// 结果是 `-Wundefined-internal` + 链接失败（run 40053204709 就是这么挂的）。
// 正确写法跟本文件上面 `-[BBPlayerDanmakuService initWithContext:]` 一致：
// hook 常驻，只把**函数体里的那一句**包进开关；GPU 合成关掉时这里只剩 %orig 透传。
%hook BBPlayerDanmakuVoutView

- (void)setupRenderer:(id)renderer {
    %orig;
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    NJPiGpuRememberDanmakuVout(self);
#endif
}

%end

// ── 捕获 cron 渲染视图实例（配合上面 NJ_PIP_MIXED_OFFSCREEN_ENABLED 内的 capture 区）──
// 三个方法的归属按 8.89 头转储核实：基类只有 updateGpuState（V1/V2 的调用路径都
// 经过它之前的实现，挂基类可同时覆盖）；setExternalPixelBuffer:/_updateSyncForTimeStep:
// 在 V1/V2 各自实现（V1 参数 BFCCRONPixelBuffer*、V2 id——都按 id 接，arm64 ABI
// 一致；我们不读参数，只取 self）。_updateSyncForTimeStep: 按 double 声明：头转储
// 写 (id) 是启发式误标，反汇编确证是 double（V1 @0x11484c16c、V2 @0x11484e19c），
// 同样不读值、只透传。类不存在时 logos 生成的初始化自动跳过，不影响其余 hook。
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

%hook BFCCRONRenderBaseView
- (void)updateGpuState {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "updateGpuState");
#endif
    %orig;
}
%end

%hook BFCCRONRenderView
- (void)setExternalPixelBuffer:(id)arg0 {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "setExternalPixelBuffer:");
#endif
    %orig(arg0);
}
- (void)_updateSyncForTimeStep:(double)seconds {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "_updateSyncForTimeStep:");
    NJPiMxNoteViewSyncObserved();
#endif
    %orig(seconds);
}
%end

%hook BFCCRONRenderViewV2
- (void)setExternalPixelBuffer:(id)arg0 {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "setExternalPixelBuffer:");
#endif
    %orig(arg0);
}
- (void)_updateSyncForTimeStep:(double)seconds {
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    NJPiMCaptureFromHook(self, "_updateSyncForTimeStep:");
    NJPiMxNoteViewSyncObserved();
#endif
    %orig(seconds);
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

- (void)startPictureInPicture {
    NJPiPDiag("pip start");
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
    NJPiPDiag("pip initContentSource enabled=%d", NJPiPDanmakuEnabled());
    // New architecture: the app's own content source is never replaced and
    // the init chain always goes through %orig untouched; we only attach a
    // lightweight overlay state when the source carries an SBDL.
    AVPictureInPictureController *controller = %orig;
    if (controller && NJPiPDanmakuEnabled()) {
        NJTrackPiPController(controller);
        if (@available(iOS 15.0, *)) {
            NJEnsurePiPOverlayState(controller, contentSource);
        }
    }
    return controller;
}

- (void)setContentSource:(AVPictureInPictureControllerContentSource *)contentSource {
    os_log_with_type(NJPiPDanmakuLog(), OS_LOG_TYPE_ERROR,
                     "[NJPiPDanmaku] controller set source class=%{public}s source=%{public}s enabled=%d",
                     NJPiPClassName(self), NJPiPClassName(contentSource), NJPiPDanmakuEnabled());
    NJPiPDiag("pip setContentSource enabled=%d", NJPiPDanmakuEnabled());
    // Legacy mirror-state bookkeeping is retained for rollback; those states
    // are no longer created by either entry hook, so this pass is a no-op in
    // the new architecture.
    NJPiPMirrorState *oldState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    if (contentSource == oldState.customContentSource) {
        %orig;
        return;
    }
    [oldState invalidate];
    objc_setAssociatedObject(self, NJPiPMirrorStateKey, nil, OBJC_ASSOCIATION_ASSIGN);
    // The app's own SBDL content source stays attached: %orig always receives
    // the original source, never a replacement.
    %orig;
    if (@available(iOS 15.0, *)) {
        if (NJPiPDanmakuEnabled() && contentSource) {
            NJEnsurePiPOverlayState(self, contentSource);
        }
    }
}

- (void)setDelegate:(id<AVPictureInPictureControllerDelegate>)delegate {
    // 真机 20261025：PiP 启停全程没有任何 delegate 事件到达我们的三层代理——先记
    // 下系统何时、拿什么对象调 setDelegate:，确证关叉号瞬间 delegate 归属。限 24 行。
    static unsigned long long setLines = 0;
    if (setLines < 24) {
        setLines += 1;
        NJPiPDiag("pip setDelegate self=%p in=%s", (__bridge void *)self,
                  delegate ? object_getClassName(delegate) : "-");
    }
    NJPiPOverlayState *overlayState = objc_getAssociatedObject(self, NJPiPOverlayStateKey);
    if (overlayState && delegate != overlayState.delegateProxy) {
        overlayState.delegateProxy.downstream = delegate;
        %orig(overlayState.delegateProxy);
        return;
    }
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
    id<AVPictureInPictureControllerDelegate> shown = delegate;
    NJPiPOverlayState *overlayState = objc_getAssociatedObject(self, NJPiPOverlayStateKey);
    if (overlayState && delegate == overlayState.delegateProxy && overlayState.delegateProxy.downstream) {
        shown = overlayState.delegateProxy.downstream;
    }
    NJPiPMirrorState *mirrorState = objc_getAssociatedObject(self, NJPiPMirrorStateKey);
    if (mirrorState && delegate == mirrorState.delegateProxy && mirrorState.delegateProxy.downstream) {
        shown = mirrorState.delegateProxy.downstream;
    }
    NJPiPDanmakuState *state = objc_getAssociatedObject(self, NJPiPDanmakuStateKey);
    if (state && delegate == state.delegateProxy && state.delegateProxy.downstream) {
        shown = state.delegateProxy.downstream;
    }
    // 系统若在派发事件前重读 delegate（getter 被调即证据），这里会留下记录。限 24 行。
    static unsigned long long getLines = 0;
    if (getLines < 24) {
        getLines += 1;
        NJPiPDiag("pip getDelegate self=%p real=%s ret=%s", (__bridge void *)self,
                  delegate ? object_getClassName(delegate) : "-",
                  shown ? object_getClassName(shown) : "-");
    }
    return shown;
}

- (void)dealloc {
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
    NSDictionary<NSString *, id> *bundleInfo = [NSBundle mainBundle].infoDictionary;
    NJPiPDiag("load sha=%s target=%s bundle=%s build=%s master=%d pip=%d",
              NJ_PI_P_BUILD_SHA,
              NJ_PI_P_TARGET_APP_URL,
               [(NSString *)[bundleInfo objectForKey:@"CFBundleShortVersionString"] UTF8String],
               [(NSString *)[bundleInfo objectForKey:@"CFBundleVersion"] UTF8String],
              NJ_MASTER_SWITCH_VALUE, NJ_PIP_DANMAKU_VALUE);
    // Unambiguous architecture marker: this build keeps the app's own SBDL
    // content source fully native and only inserts the danmaku renderer into
    // the official layer's subtree. The parenthetical keeps the historical
    // draft name and the rejected-API reason as greppable literals so a
    // `strings` check on the built dylib can prove this build's architecture.
    NJPiPDiag("pip arch=native-layerinsert sha=%s (was: native-overlay; setMetaLayer: rejected: WMMetaLayer parameter)",
              NJ_PI_P_BUILD_SHA);
    NJPiPDiagStart();
#if NJ_PIP_MIXED_OFFSCREEN_ENABLED
    // 第三条路径的启动点：与上面两条按构造互斥（GPU 路在 NJPiGpuStart 让路，
    // 插层路在 attach 让路），只在编译期宏为 1 时存在；宏为 0 时这一行不存在，
    // 加载流程一字未改。产物里是哪条路：`strings` 抓 "mixed-offscreen-enabled"
    // （两处让路的字面量）或运行日志里的 "mx init" 即可判定，无需额外标记行。
    NJPiMxStart();
#endif
#if NJ_PIP_GPU_COMPOSITE_ENABLED
    // 第二条路径的启动点：与上面的插层路径互斥（插层在 attach 处让路），
    // 只在编译期宏为 1 时存在；宏为 0 时这一行不存在，加载流程一字未改。
    // 产物里是哪条路：`strings` 抓 "gpu-composite-enabled"（attach 让路的字面量）
    // 或运行日志里的 "gpu hook cls=…" 即可判定，无需额外标记行。
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
        %init(App);
    }
}
