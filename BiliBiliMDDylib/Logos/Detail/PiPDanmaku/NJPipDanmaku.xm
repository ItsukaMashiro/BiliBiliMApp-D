// 画中画弹幕

#import <UIKit/UIKit.h>
#import "NJCommonDefine.h"
#import "NJPipDanmakuManager.h"

%ctor {
    if (NJ_MASTER_SWITCH_VALUE) {
        [[NJPipDanmakuManager sharedInstance] startObserving];
    }
}
