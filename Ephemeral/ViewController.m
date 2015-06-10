//
//  ViewController.m
//  Ephemeral
//
//  Created by Robert Carlsen on 6/9/15.
//  Copyright (c) 2015 Robert Carlsen. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

#import "ViewController.h"
#import "ViewModel.h"

@interface ViewController ()
@property(nonatomic) IBOutlet UIButton *recordButton;
@property(nonatomic) IBOutlet UIProgressView *progressView;
@property(nonatomic) IBOutlet UIView *instructionsView;
@property(nonatomic) IBOutlet UIView *shareProgressView;
@property(nonatomic) IBOutlet UIButton *cancelShareButton;

@property(nonatomic) ViewModel *viewModel;
@end

@implementation ViewController

-(void)awakeFromNib;
{
    _viewModel = [ViewModel new];
}

- (void)viewDidLoad {
    @weakify(self);
    [super viewDidLoad];

    [_recordButton.layer setCornerRadius:CGRectGetWidth(_recordButton.bounds)/2.0];
    [_shareProgressView.layer setCornerRadius:5.];
    [_instructionsView.layer setCornerRadius:5.];
    
    RACCommand *cancelShareCommand = [[RACCommand alloc] initWithEnabled:nil
                                                             signalBlock:^RACSignal *(id input) {
                                                                 @strongify(self);
                                                                 [self.viewModel cancelShare];
                                                                 return [RACSignal empty];
                                                             }];
    [_cancelShareButton setRac_command:cancelShareCommand];

    RACSignal *recordButtonTitleSignal = [[self.viewModel canRecordSignal] map:^id(id value) {
        return ([value boolValue] ?
                NSLocalizedString(@"Record", nil) :
                NSLocalizedString(@"Recording not supported", nil));
    }];

    [_recordButton rac_liftSelector:@selector(setTitle:forState:)
                        withSignals:recordButtonTitleSignal, [RACSignal return:@(UIControlStateNormal)], nil];

    RAC(_recordButton, enabled) = [self.viewModel canRecordSignal];
    [[_recordButton rac_signalForControlEvents:UIControlEventTouchDown] subscribeNext:^(id x) {
        @strongify(self);
        [self.viewModel beginRecording];
    }];
    
    [[_recordButton rac_signalForControlEvents:(UIControlEventTouchUpInside|UIControlEventTouchUpOutside)] subscribeNext:^(id x) {
        @strongify(self);
        [self.viewModel cancelRecording];
    }];
    
    RACSignal *isRecording = [[_viewModel recordingProgressSignal] map:^id(NSNumber *value) {
        CGFloat progress = [value floatValue];
        return @(progress > 0);
    }];
    RACSignal *recordingColor = [isRecording map:^id(NSNumber *value) {
        return ([value boolValue]) ? [UIColor redColor] : [UIColor blackColor];
    }];
    RAC(_recordButton, backgroundColor) = recordingColor;
    
    RAC(self.progressView, progress, @0) = [self.viewModel recordingProgressSignal];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [[tapGesture rac_gestureSignal] subscribeNext:^(id x) {
        @strongify(self);
        [self.viewModel dismissInstructions];
    }];
    [_instructionsView addGestureRecognizer:tapGesture];
    

    [[[self.viewModel viewStateSignal] logNext]
     subscribeNext:^(id x) {
        @strongify(self);
        ViewState viewState = [x unsignedIntegerValue];
        switch (viewState) {
            case ViewStateIntro:
                // first run, initial state
                // reveal the instructions
                self.instructionsView.hidden = NO;
                self.recordButton.hidden = NO;
                self.progressView.hidden = YES;
                self.shareProgressView.hidden = YES;

                break;
            case ViewStateIdle:
                // initial state after first run.
                if (!self.instructionsView.hidden) {
                    [UIView animateWithDuration:0.3
                                     animations:^{
                                         self.instructionsView.alpha = 0;
                                     } completion:^(BOOL finished) {
                                         self.instructionsView.hidden = YES;
                                         self.instructionsView.alpha = 1;
                                     }];
                }
                self.recordButton.hidden = NO;
                self.progressView.hidden = YES;
                self.shareProgressView.hidden = YES;
                break;
            case ViewStateRecordingProgress:
                // record progress
                self.progressView.hidden = NO;
                break;
            case ViewStateRecordingComplete:
                // interstitial before share panel
                self.progressView.hidden = YES;
            {                
                UIAlertController *alertController =
                [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Share this?", nil)
                                                    message:NSLocalizedString(@"The video will be discarded if not shared.", nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    @strongify(self);
                    [self.viewModel share];
                }]];
                [alertController addAction:[UIAlertAction actionWithTitle:@"Discard" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                    @strongify(self);
                    [self.viewModel reset];
                }]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
                break;
            case ViewStateRecordingCancelled:
                // interstitial before idle
                self.progressView.hidden = YES;
                [self.viewModel reset];
                break;
            case ViewStateShareProgress:
                // show share activity indicator
                self.shareProgressView.hidden = NO;
                break;
            case ViewStateShareComplete:
                // confirm share success
                self.shareProgressView.hidden = YES;
            {
                UIAlertController *alertController =
                [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Shared", nil)
                                                    message:[self.viewModel shareStatusMessage]
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"Got it!" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    @strongify(self);
                    [self.viewModel reset];
                }]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
                break;
            case ViewStateShareFailed:
                // present share error
                self.shareProgressView.hidden = YES;
            {
                UIAlertController *alertController =
                [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Not shared", nil)
                                                    message:[self.viewModel shareStatusMessage]
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"Try again" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    @strongify(self);
                    [self.viewModel share];
                }]];
                [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                    @strongify(self);
                    [self.viewModel reset];
                }]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
                break;
            default:
                break;
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
