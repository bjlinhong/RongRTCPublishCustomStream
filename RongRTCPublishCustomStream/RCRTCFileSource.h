//
//  RCRTCFileSource.h
//  RongRTCLib
//
//  Created by RongCloud on 2019/1/18.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <RongRTCLib/RongRTCLib.h>


@protocol RCRTCFileCapturerDelegate <NSObject>

- (void)didWillStartRead;
- (void)didReadCompleted;

@end

@protocol RCRTCVideoObserverInterface;

NS_ASSUME_NONNULL_BEGIN

@interface RCRTCFileSource : NSObject <RCRTCVideoSourceInterface>

@property (nonatomic,weak)id <RCRTCFileCapturerDelegate> delegate;

@property (nonatomic, copy, readonly)NSString *currentPath;

- (instancetype)initWithFilePath:(NSString *)filePath;

- (BOOL)stop;

@end

NS_ASSUME_NONNULL_END
