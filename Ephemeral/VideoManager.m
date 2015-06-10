//
//  VideoManager.m
//  
//
//  Created by Robert Carlsen on 6/9/15.
//
//

#import <AVFoundation/AVFoundation.h>

#import "VideoManager.h"

@interface VideoManager ()
<AVCaptureFileOutputRecordingDelegate>

@property(nonatomic, readwrite)RACSignal *processedVideoSignal;
@property(nonatomic)RACSubject *processedVideoSubject;

@property(nonatomic, readwrite)BOOL canRecord;
@property(nonatomic, readwrite)BOOL isRecording;
@property(nonatomic)BOOL wasCancelled;


@property(nonatomic)AVCaptureSession *captureSession;
@property(nonatomic)AVCaptureMovieFileOutput *movieFileOutput;
@property(nonatomic)AVCaptureDeviceInput *deviceInput;

@end

@implementation VideoManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _canRecord = YES;
        _wasCancelled = NO;

        _processedVideoSubject = [RACSubject subject];
        _processedVideoSignal = [_processedVideoSubject replayLast];
        
        _captureSession = [[AVCaptureSession alloc] init];
        
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (videoDevice) {
            NSError *error = nil;
            _deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
            if (_deviceInput) {
                if ([_captureSession canAddInput:_deviceInput]) {
                    [_captureSession addInput:_deviceInput];
                }
                else {
                    NSLog(@"couldn't add video input to capture session");
                    _canRecord = NO;
                }
            }
            else {
                NSLog(@"error creating video device input");
                _canRecord = NO;
            }
        }
        else {
            NSLog(@"error creating video capture device");
            _canRecord = NO;
        }
        
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        if (audioDevice) {
            NSError *error = nil;
            AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
            if (audioInput) {
                if([_captureSession canAddInput:audioInput]) {
                    [_captureSession addInput:audioInput];
                }
                else {
                    NSLog(@"couldn't add audio input");
                    _canRecord = NO;
                }
            }
            else {
                NSLog(@"error creating audio input");
                _canRecord = NO;
            }
        }
        else {
            NSLog(@"error creating audio capture device");
            _canRecord = NO;
        }
        
        _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];

        Float64 durationSeconds = 2.5;
        int32_t preferredTimeScale = 24;
        CMTime maxDuration = CMTimeMakeWithSeconds(durationSeconds, preferredTimeScale);
        _movieFileOutput.maxRecordedDuration = maxDuration;
        
        if ([_captureSession canAddOutput:_movieFileOutput]) {
            [_captureSession addOutput:_movieFileOutput];
        }
        else {
            NSLog(@"error adding movie file output");
            _canRecord = NO;
        }
        
        AVCaptureConnection *captureConnection = [_movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoOrientationSupported]) {
            AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
            [captureConnection setVideoOrientation:orientation];
        }
        
        [_captureSession setSessionPreset:AVCaptureSessionPresetMedium];

        // is this KVO-compliant? who knows...these are old APIs.
        RAC(self, isRecording) = RACObserve(_movieFileOutput, recording);
        [_captureSession startRunning];
    }
    return self;
}

#pragma mark AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray *)connections error:(NSError *)error;
{
    // if completed successfully, and not cancelled, then emit the next signal
    if (!_wasCancelled) {
        // TODO: process the video (make it square)
        // will likely take the temp url passed here, process it async
        // then send the url for the transformed file to the subject.
        [_processedVideoSubject sendNext:outputFileURL];
    }
    else {
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtURL:outputFileURL error:nil];

        [_processedVideoSubject sendNext:nil];
    }
}

#pragma mark Methods
-(void)startRecording;
{
    if (!_canRecord) {
        return;
    }

    _wasCancelled = NO;
    [_processedVideoSubject sendNext:nil];
    
    NSString *tempUUID = [[NSUUID UUID] UUIDString];
    NSURL *tempUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[tempUUID stringByAppendingPathExtension:@"mov"]]];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:tempUrl error:nil];
    
    [_movieFileOutput startRecordingToOutputFileURL:tempUrl
                                  recordingDelegate:self];
}

-(void)finishRecording;
{
    if (!_isRecording) {
        return;
    }
    [_movieFileOutput stopRecording];
}

-(void)cancelRecording;
{
    if (!_isRecording) {
        return;
    }
    _wasCancelled = YES;
    [_movieFileOutput stopRecording];
}


-(double)recordingProgress;
{
    if (![_movieFileOutput isRecording]) {
        return 0.;
    }
    return (CMTimeGetSeconds(_movieFileOutput.recordedDuration) / CMTimeGetSeconds(_movieFileOutput.maxRecordedDuration));
}

-(void)reset;
{
    // NOP
    // intended to remove any temporary files
    // and to reset the video capture systems as appropriate.
}
@end
