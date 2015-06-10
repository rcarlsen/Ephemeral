//
//  VideoManager.h
//  
//
//  Created by Robert Carlsen on 6/9/15.
//
//

#import <Foundation/Foundation.h>

@interface VideoManager : NSObject

// Signal of NSURLs for processed video files after recording.
@property(nonatomic, readonly)RACSignal *processedVideoSignal;

@property(nonatomic, readonly)BOOL canRecord;
@property(nonatomic, readonly)BOOL isRecording;
@property(nonatomic, readonly)double recordingProgress;

-(void)startRecording;
-(void)finishRecording;
-(void)cancelRecording;
-(void)reset;
@end
