//
//  NJPipDanmakuManager.h
//  BiliBiliTweak
//
//  Created by touchWorld on 2025/8/11.
//

#import <UIKit/UIKit.h>
#import "NJCommonDefine.h"

NS_ASSUME_NONNULL_BEGIN

/// 画中画弹幕管理器
/// 画中画（PiP）模式下，将弹幕视图对齐到画中画窗口的视频区域上，实现画中画弹幕显示
@interface NJPipDanmakuManager : NSObject

/// 画中画弹幕当前是否处于激活状态
@property (nonatomic, assign, readonly) BOOL isPipDanmakuActive;

/// 开始监听画中画窗口
- (void)startObserving;

/// 停止监听画中画窗口
- (void)stopObserving;

NJ_SINGLETON_H(Manager)

@end

NS_ASSUME_NONNULL_END
