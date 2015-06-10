//
//  ViewModel.m
//  Ephemeral
//
//  Created by Robert Carlsen on 6/9/15.
//  Copyright © 2015 Robert Carlsen. All rights reserved.
//

#import "ViewModel.h"
#import "ShareManager.h"
#import "VideoManager.h"

@interface ViewModel ()
@property(nonatomic)ViewState viewState;
@property(nonatomic)CGFloat recordingProgress;
@property(nonatomic)BOOL canShare;

@property(nonatomic)ShareManager *shareManager;
@property(nonatomic, readwrite, copy)NSString *shareStatusMessage;

@property(nonatomic)VideoManager *videoManager;
@property(nonatomic)NSURL *videoUrl;
@end

// seconds
NSTimeInterval const recordingMaxDuration = 5.0; // 2.5;

NSString * const kUserDefaultsKeyHideIntro = @"kUserDefaultsKeyHideIntro";

@implementation ViewModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultsKeyHideIntro]) {
            _viewState = ViewStateIdle;
        }
        else {
            _viewState = ViewStateIntro;
        }

        @weakify(self);

        _recordingProgress = 0;
        _canShare = NO;

        _viewStateSignal = [RACObserve(self, viewState) distinctUntilChanged];
        _canShareSignal = RACObserve(self, canShare);
        
        _videoManager = [VideoManager new];
        RAC(self, videoUrl) = _videoManager.processedVideoSignal;
        _canRecordSignal = RACObserve(self.videoManager, canRecord);
        [[_videoManager.processedVideoSignal ignore:nil] subscribeNext:^(NSURL *value) {
            @strongify(self);
            self.viewState = ViewStateRecordingComplete;
        }];
        

        _recordingProgressSignal = RACObserve(self, recordingProgress);
        [_recordingProgressSignal logNext];

    }
    return self;
}

#pragma mark Methods
-(void)dismissInstructions;
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:kUserDefaultsKeyHideIntro];
    [defaults synchronize];
    
    self.viewState = ViewStateIdle;
}

-(void)beginRecording;
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    @weakify(self);

    self.viewState = ViewStateRecordingProgress;
    [self.videoManager startRecording];
    
    // polling the video progress
    [[[RACSignal interval:0.05 onScheduler:[RACScheduler mainThreadScheduler]]
      takeUntil:[self.videoManager.processedVideoSignal ignore:nil]] // will emit when the video is ready
     subscribeNext:^(NSDate *timerDate) {
         @strongify(self);
         self.recordingProgress = self.videoManager.recordingProgress;
     } completed:^{
         @strongify(self);
         self.recordingProgress = 0;
     }];

}

-(void)cancelRecording;
{
    if (_viewState == ViewStateRecordingProgress) {
        NSLog(@"%s", __PRETTY_FUNCTION__);
        self.recordingProgress = 0;
        [self.videoManager cancelRecording];
        self.viewState = ViewStateRecordingCancelled;
    }
}

-(void)share;
{
    @weakify(self);
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (_viewState == ViewStateRecordingComplete ||
        _viewState == ViewStateShareFailed) {
        if (!_shareManager) {
            _shareManager = [ShareManager new];
        }
        
        self.shareStatusMessage = nil;
        self.viewState = ViewStateShareProgress;
        
        // do share stuff and map completion to shareComplete/failure states
        [_shareManager shareVideo:self.videoUrl
                   withCompletion:^(BOOL success, NSError *error) {
            @strongify(self);
            if (success) {
                self.shareStatusMessage = NSLocalizedString(@"(saved to camera roll)", nil);
                self.viewState = ViewStateShareComplete;
            }
            else {
                // TODO: capture the reason from the error and display
                self.shareStatusMessage = NSLocalizedString(@"Sharing failed.", nil);
                self.viewState = ViewStateShareFailed;
            }
        }];

    }
}

-(void)cancelShare;
{
    if (_viewState == ViewStateShareProgress) {
        // stop the share, if in progress.
        self.shareStatusMessage = NSLocalizedString(@"Sharing cancelled.", nil);
        self.viewState = ViewStateShareFailed;
    }
}

-(void)reset;
{
    if (self.videoUrl) {
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtURL:self.videoUrl error:nil];
    }
    
    [_videoManager reset];
    self.viewState = ViewStateIdle;
}

@end
