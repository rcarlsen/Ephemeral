//
//  ViewModel.h
//  Ephemeral
//
//  Created by Robert Carlsen on 6/9/15.
//  Copyright © 2015 Robert Carlsen. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    ViewStateIntro = 0,
    ViewStateIdle,
    ViewStateRecordingProgress,
    ViewStateRecordingComplete,
    ViewStateRecordingCancelled,
    ViewStateShareProgress,
    ViewStateShareComplete,
    ViewStateShareFailed
} ViewState;

@interface ViewModel : RVMViewModel

/// Signal of boxed ViewState values.
@property(nonatomic, readonly)RACSignal *viewStateSignal;

/// Signal of recording progress (boxed, normalized float 0<=n<=1)
@property(nonatomic, readonly)RACSignal *recordingProgressSignal;

/// Signal of boxed BOOL; YES if sharing is available.
@property(nonatomic, readonly)RACSignal *canShareSignal;

/// Signal of boxed BOOL; YES if recording is available.
@property(nonatomic, readonly)RACSignal *canRecordSignal;

@property(nonatomic, readonly, copy)NSString *shareStatusMessage;

-(void)dismissInstructions;

// back to the beginning.
-(void)reset;

-(void)beginRecording;
-(void)cancelRecording;

-(void)share;
-(void)cancelShare;

@end
