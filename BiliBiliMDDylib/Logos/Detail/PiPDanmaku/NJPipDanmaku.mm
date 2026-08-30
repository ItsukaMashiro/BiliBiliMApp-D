#line 1 "E:\opencodeworkspace\BiliBiliMApp\BiliBiliMDDylib\Logos\Detail\PiPDanmaku\NJPipDanmaku.xm"


// 画中画弹幕
#import <UIKit/UIKit.h>
#import "NJCommonDefine.h"
#import "NJPipDanmakuManager.h"


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


#line 7 "E:\opencodeworkspace\BiliBiliMApp\BiliBiliMDDylib\Logos\Detail\PiPDanmaku\NJPipDanmaku.xm"
static __attribute__((constructor)) void _logosLocalCtor_6b1a2c3d(int __unused argc, char __unused **argv, char __unused **envp) {
    if (NJ_MASTER_SWITCH_VALUE) {
        [[NJPipDanmakuManager sharedInstance] startObserving];
    }
}
