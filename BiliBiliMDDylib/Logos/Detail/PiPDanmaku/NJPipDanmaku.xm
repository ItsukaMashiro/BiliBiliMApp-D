// 画中画弹幕

#import <UIKit/UIKit.h>
#import "NJCommonDefine.h"
#import "NJPipDanmakuManager.h"

/// 遗留的「视图搬移」方案开关：NJPipDanmakuManager 每 0.25s 轮询
/// [UIApplication sharedApplication].windows，把 windowLevel == 1000 且 layer 树里含
/// AVPlayerLayer/AVSampleBufferDisplayLayer 的窗口当作 PiP 窗口，再把类名包含
/// danmaku/damaku 的面积最大视图从播放器里 removeFromSuperview 搬进那个窗口
/// （匹配方式是类名字符串包含，没有任何身份校验，见 NJPipDanmakuManager.m:284-292）。
/// 它与 NJDetailPlayerAd.xm 里的原生层方案冲突：会把原生层方案要插入官方 PiP 视频层
/// 子树的弹幕视图搬走（甚至搬到错误的窗口），真机表现为「PiP 里没有弹幕、播放器上的
/// 弹幕也可能消失」，日志也无法归因。因此默认关闭，让新架构的行为可测。
/// 注意：这是独立开关，不能复用 NJ_PIP_DANMAKU_VALUE——那个宏同时是原生层方案的总开关。
/// 置 1 即恢复旧行为；实现代码未删除，可随时回滚。
#define NJ_PIP_LEGACY_VIEW_MOVE_ENABLED 0

%ctor {
#if NJ_PIP_LEGACY_VIEW_MOVE_ENABLED
    if (NJ_MASTER_SWITCH_VALUE) {
        [[NJPipDanmakuManager sharedManager] startObserving];
    }
#endif
}
