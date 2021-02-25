//
//  VideoRoomViewController.m
//  RTCQuickStartDemo
//
//  Created by LiuLinhong on 2020/10/27.
//  Copyright © 2020 RongCloud. All rights reserved.
//

#import "VideoRoomViewController.h"
#import "AppID.h"
#import <Masonry.h>
#import <RongRTCLib/RongRTCLib.h>
#import <RongIMLibCore/RongIMLibCore.h>
#import "RCRTCFileSource.h"

#define kScreenWidth self.view.frame.size.width
#define kScreenHeight self.view.frame.size.height


@interface VideoRoomViewController () <RCRTCRoomEventDelegate, RCRTCFileCapturerDelegate>

@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) RCRTCLocalVideoView *localView;
@property (nonatomic, strong) RCRTCRemoteVideoView *remoteView;
@property (nonatomic, strong) RCRTCRemoteVideoView *remoteFileVideoView;
@property (nonatomic, strong) RCRTCLocalVideoView *localFileVideoView;
@property (nonatomic, strong) RCRTCRoom *room;
@property (nonatomic, strong) RCRTCEngine *engine;
@property (nonatomic, strong) RCRTCFileSource *fileCapturer;
@property (nonatomic, strong) RCRTCVideoOutputStream *fileVideoOutputStream;

@end


@implementation VideoRoomViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initializeRCRTCEngine];
    [self setupLocalVideoView];
    [self setupFileVideoView];
    [self setupRemoteVideoView];
    [self setupRemoteFileVideoView];
    [self setupRoomMenuView];
    [self initializeRCIMCoreClient];
}

- (void)initializeRCIMCoreClient {
    //融云SDK 5.0.0 及其以上版本使用
    [[RCCoreClient sharedCoreClient] initWithAppKey:AppID];
    [[RCCoreClient sharedCoreClient] connectWithToken:token
                                             dbOpened:^(RCDBErrorCode code) {
        NSLog(@"MClient dbOpened code: %zd", code);
    } success:^(NSString *userId) {
        NSLog(@"IM连接成功userId: %@", userId);
        [self joinRoom];
    } error:^(RCConnectErrorCode status) {
        NSLog(@"IM连接失败errorCode: %ld", (long)status);
    }];
    
    /*
     //融云SDK 5.0.0 以下版本, 不包含5.0.0 使用
    //初始化融云 SDK
    [[RCIMClient sharedRCIMClient] initWithAppKey:AppID];
    RCIMClient.sharedRCIMClient.logLevel = RC_Log_Level_None;
    //前置条件 IM建立连接
    [[RCIMClient sharedRCIMClient] connectWithToken:token
                                           dbOpened:^(RCDBErrorCode code) {
    }
                                            success:^(NSString *userId) {
        NSLog(@"IM连接成功userId:%@",userId);
    }
                                              error:^(RCConnectErrorCode errorCode) {
        NSLog(@"IM连接失败errorCode:%ld",(long)errorCode);
    }];
     */
}

- (void)initializeRCRTCEngine {
    self.engine = [RCRTCEngine sharedInstance];
    [self.engine enableSpeaker:YES];
}

//添加本地采集预览界面
- (void)setupLocalVideoView {
    RCRTCLocalVideoView *localView = [[RCRTCLocalVideoView alloc] initWithFrame:self.view.bounds];
    localView.fillMode = RCRTCVideoFillModeAspectFill;
    [self.view addSubview:localView];
    self.localView = localView;
}

//添加本地自定义视频界面
- (void)setupFileVideoView {
    self.localFileVideoView = [[RCRTCLocalVideoView alloc] initWithFrame:CGRectMake(kScreenWidth - 240, 20, 100, 100 * 4 / 3)];
    self.localFileVideoView.fillMode = RCRTCVideoFillModeAspect;
    self.localFileVideoView.frameAnimated = NO;
}
    
//添加远端视频小窗口
- (void)setupRemoteVideoView {
    self.remoteView = [[RCRTCRemoteVideoView alloc] initWithFrame:CGRectMake(kScreenWidth - 120, 20, 100, 100 * 4 / 3)];
    self.remoteView.fillMode = RCRTCVideoFillModeAspectFill;
    self.remoteView.hidden = YES;
    [self.view addSubview:self.remoteView];
}

//添加远端自定义视频界面
- (void)setupRemoteFileVideoView {
    self.remoteFileVideoView = [[RCRTCRemoteVideoView alloc] initWithFrame:CGRectMake(kScreenWidth - 240, 20, 100, 100 * 4 / 3)];
    self.remoteFileVideoView.fillMode = RCRTCVideoFillModeAspectFill;
    self.remoteFileVideoView.hidden = YES;
    [self.view addSubview:self.remoteFileVideoView];
}

//添加控制按钮层
- (void)setupRoomMenuView {
    [self.view addSubview:self.menuView];
    [self.menuView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(0);
        make.bottom.mas_equalTo(-50);
        make.size.mas_offset(CGSizeMake(kScreenWidth, 50));
    }];
}

/*
 加入房间, 回调成功后:
   1.本地视频采集
   2.发布本地视频流
   3.加入房间时如果已经有远端用户在房间中, 需要订阅远端流
 */
- (void)joinRoom {
    [[RCRTCEngine sharedInstance] joinRoom:RoomId
                                completion:^(RCRTCRoom * _Nullable room, RCRTCCode code) {
        if (code == RCRTCCodeSuccess) {
            //设置房间代理
            self.room = room;
            room.delegate = self;
            
            // 1.本地视频采集
            [[self.engine defaultVideoStream] setVideoView:self.localView];
            [[self.engine defaultVideoStream] startCapture];
            
            [self.engine enableSpeaker:YES];
            
            // 2.发布本地视频流
            [room.localUser publishDefaultStreams:^(BOOL isSuccess, RCRTCCode desc) {
                if (isSuccess && desc == RCRTCCodeSuccess) {
                    NSLog(@"本地流发布成功");
                }
            }];
    
            // 3.加入房间时如果已经有远端用户在房间中, 需要订阅远端流
            if ([room.remoteUsers count] > 0) {
                NSMutableArray *streamArray = [NSMutableArray array];
                for (RCRTCRemoteUser *user in room.remoteUsers) {
                    [streamArray addObjectsFromArray:user.remoteStreams];
                }
                // 订阅远端音视频流
                [self subscribeRemoteResource:streamArray];
            }
        } else {
            NSLog(@"加入房间失败 %zd", code);
        }
    }];
}

//麦克风静音
- (void)micMute:(UIButton *)btn {
    btn.selected = !btn.selected;
    [self.engine.defaultAudioStream setMicrophoneDisable:btn.selected];
}

//本地摄像头切换
- (void)changeCamera:(UIButton *)btn {
    btn.selected = !btn.selected;
    [self.engine.defaultVideoStream switchCamera];
}

//挂断
- (void)leaveRoom {
    [self stopPublishVideoFile];
    //关闭摄像头采集
    [self.engine.defaultVideoStream stopCapture];
    [self.remoteView removeFromSuperview];
    //退出房间
    [self.engine leaveRoom:^(BOOL isSuccess, RCRTCCode code) {
        if (isSuccess && code == RCRTCCodeSuccess) {
            NSLog(@"退出房间成功code:%ld", (long)code);
        }
    }];
}

- (void)startPublishVideoFile:(UIButton *)btn {
    btn.selected = !btn.selected;
    
    //发布自定义视频流
    if (btn.selected) {
        NSString *tag = @"RongRTCFileVideo";
        self.fileVideoOutputStream = [[RCRTCVideoOutputStream alloc] initVideoOutputStreamWithTag:tag];
        
        RCRTCVideoStreamConfig *videoConfig = self.fileVideoOutputStream.videoConfig;
        videoConfig.videoSizePreset = RCRTCVideoSizePreset640x360;
        [self.fileVideoOutputStream setVideoConfig:videoConfig];
        [self.fileVideoOutputStream setVideoView:self.localFileVideoView];
        [self.view addSubview:self.localFileVideoView];
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"video_demo2_low"
                                                         ofType:@"mp4"];
        
        self.fileCapturer = [[RCRTCFileSource alloc] initWithFilePath:path];
        self.fileCapturer.delegate = self;
        self.fileVideoOutputStream.videoSource = self.fileCapturer;
        [self.fileCapturer setObserver:self.fileVideoOutputStream];
        
        [self.room.localUser publishStream:self.fileVideoOutputStream
                                completion:^(BOOL isSuccess, RCRTCCode desc) {
            if (desc == RCRTCCodeSuccess) {
                NSLog(@"发布自定义流成功");
            }
            else {
                NSLog(@"发布自定义流成功");
            }
        }];
    }
    else {
        [self stopPublishVideoFile];
    }
}

//取消发布自定义视频流
- (void)stopPublishVideoFile {
    if (self.fileCapturer) {
        [self.fileCapturer stop];
        self.fileCapturer.delegate = nil;
        self.fileCapturer = nil;
    }
    
    [self.localFileVideoView removeFromSuperview];
    
    [self.room.localUser unpublishStream:self.fileVideoOutputStream
                              completion:^(BOOL isSuccess, RCRTCCode desc) {
    }];
    self.localFileVideoView = nil;
}

#pragma mark - RCRTCFileCapturerDelegate
- (void)didWillStartRead {
    [self.localFileVideoView flushVideoView];
}

- (void)didReadCompleted {
    [self.localFileVideoView flushVideoView];
}

#pragma mark - RCRTCRoomEventDelegate
- (void)didPublishStreams:(NSArray<RCRTCInputStream *> *)streams {
    [self subscribeRemoteResource:streams];
}

- (void)didUnpublishStreams:(NSArray<RCRTCInputStream *>*)streams {
    for (RCRTCInputStream *stream in streams) {
        if (stream.mediaType == RTCMediaTypeVideo) {
            RCRTCVideoInputStream *tmpInputStream = (RCRTCVideoInputStream *) stream;
            if ([stream.tag isEqualToString:@"RongRTCFileVideo"]) {
                self.remoteFileVideoView.hidden = YES;
            }
            else {
                self.remoteView.hidden = YES;
            }
        }
    }
}

- (void)didLeaveUser:(RCRTCRemoteUser*)user {
    self.remoteFileVideoView.hidden = YES;
    self.remoteView.hidden = YES;
}

//订阅远端用户资源
- (void)subscribeRemoteResource:(NSArray<RCRTCInputStream *> *)streams {
    // 创建并设置远端视频预览视图
    for (RCRTCInputStream *stream in streams) {
        if (stream.mediaType == RTCMediaTypeVideo) {
            RCRTCVideoInputStream *tmpInputStream = (RCRTCVideoInputStream *) stream;
            if ([stream.tag isEqualToString:@"RongRTCFileVideo"]) {
                [tmpInputStream setVideoView:self.remoteFileVideoView];
                self.remoteFileVideoView.hidden = NO;
            }
            else {
                [tmpInputStream setVideoView:self.remoteView];
                self.remoteView.hidden = NO;
            }
        }
    }
    
    // 订阅房间中远端用户音视频流资源
    [self.room.localUser subscribeStream:streams
                             tinyStreams:nil
                              completion:^(BOOL isSuccess, RCRTCCode desc) {}];
}

#pragma mark - Getter
- (UIView *)menuView {
    if (!_menuView) {
        _menuView = [UIView new];
        
        UIButton *muteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [muteBtn setImage:[UIImage imageNamed:@"mute"] forState:UIControlStateNormal];
        [muteBtn setImage:[UIImage imageNamed:@"mute_hover"] forState:UIControlStateSelected];
        [muteBtn addTarget:self action:@selector(micMute:) forControlEvents:UIControlEventTouchUpInside];
        [_menuView addSubview:muteBtn];
        
        UIButton *exitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [exitBtn setImage:[UIImage imageNamed:@"hang_up"] forState:UIControlStateNormal];
        [exitBtn addTarget:self action:@selector(leaveRoom) forControlEvents:UIControlEventTouchUpInside];
        [_menuView addSubview:exitBtn];
        
        UIButton *changeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [changeBtn setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
        [changeBtn setImage:[UIImage imageNamed:@"camera_hover"] forState:UIControlStateSelected];
        [changeBtn addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventTouchUpInside];
        [_menuView addSubview:changeBtn];
        
        UIButton *customBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [customBtn setImage:[UIImage imageNamed:@"file_video"] forState:UIControlStateNormal];
        [customBtn setImage:[UIImage imageNamed:@"file_video_hover"] forState:UIControlStateSelected];
        [customBtn addTarget:self action:@selector(startPublishVideoFile:) forControlEvents:UIControlEventTouchUpInside];
        [_menuView addSubview:customBtn];
        
        CGFloat padding = (kScreenWidth - 50 * 4) / 5;
        CGSize btnSize = CGSizeMake(50, 50);
        
        [muteBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_offset(padding);
            make.centerY.mas_equalTo(0);
            make.size.mas_offset(btnSize);
        }];
        [exitBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_offset(padding * 2 + 50);
            make.centerY.mas_equalTo(0);
            make.size.mas_offset(btnSize);
        }];
        [changeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_offset(padding * 3 + 50 * 2);
            make.centerY.mas_equalTo(0);
            make.size.mas_offset(btnSize);
        }];
        [customBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.mas_offset(-padding);
            make.centerY.mas_equalTo(0);
            make.size.mas_offset(btnSize);
        }];
    }
    return _menuView;
}

@end
