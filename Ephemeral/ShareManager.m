//
//  ShareManager.m
//  
//
//  Created by Robert Carlsen on 6/9/15.
//
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "ShareManager.h"

@implementation ShareManager

- (void)shareVideo:(NSURL*)videoUrl withCompletion:(void(^)(BOOL success, NSError *error))callback;
{
    // do sharing stuff with the passed in url
    NSLog(@"(fake) sharing video file at url: %@", [videoUrl description]);
    
    // fake a share after delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // want to fake a failure to show both states:
        BOOL maybeDidSucceed = (arc4random()%1000) >= 500;
        if (maybeDidSucceed) {
            
            // writing the video to the library to show that it was recorded / saved.
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            [library writeVideoAtPathToSavedPhotosAlbum:videoUrl
                                        completionBlock:^(NSURL *assetURL, NSError *error) {
                                            if (callback) {
                                                callback((error == nil), error);
                                            }
                                        }];
        }
        else {
            if (callback) {
                callback(NO, [NSError errorWithDomain:@"net.robertcarlsen.ephemeral.share"
                                                 code:ShareManagerErrorCodeUnknown
                                             userInfo:nil]);
            }
        }
    });
}
    
@end
