//
//  ShareManager.h
//  
//
//  Created by Robert Carlsen on 6/9/15.
//
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    ShareManagerErrorCodeSuccess,
    ShareManagerErrorCodeFailed,
    ShareManagerErrorCodeUnknown = NSUIntegerMax
} ShareManagerErrorCode;

@interface ShareManager : NSObject

- (void)shareVideo:(NSURL*)videoUrl withCompletion:(void(^)(BOOL success, NSError *error))callback;

@end
