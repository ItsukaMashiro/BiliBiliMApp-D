#line 1 "E:/opencodeworkspace/BiliBiliMApp/BiliBiliMDDylib/Logos/Detail/PiPDanmaku/NJPipDanmaku.xm"


// 画中画弹幕
#import <UIKit/UIKit.h>
#import "NJCommonDefine.h"
#import "NJPipDanmakuManager.h"

/// 与 NJPipDanmaku.xm 中同名开关保持一致：本文件是 Logos 生成产物，但 pbxproj 的
/// Sources 编译的就是它，且 CI 只对 build phase 里 touch 过的 .xm 重新跑 logos
/// （见 project.pbxproj:1949），所以这里必须与 .xm 同步，否则改动不会进入产物。
/// 默认 0：遗留的视图搬移路径与 NJDetailPlayerAd.xm 的原生层方案冲突。
#define NJ_PIP_LEGACY_VIEW_MOVE_ENABLED 0


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


#line 7 "E:/opencodeworkspace/BiliBiliMApp/BiliBiliMDDylib/Logos/Detail/PiPDanmaku/NJPipDanmaku.xm"
static __attribute__((constructor)) void _logosLocalCtor_6b1a2c3d(int __unused argc, char __unused **argv, char __unused **envp) {
#if NJ_PIP_LEGACY_VIEW_MOVE_ENABLED
    if (NJ_MASTER_SWITCH_VALUE) {
        [[NJPipDanmakuManager sharedManager] startObserving];
    }
#endif
}
