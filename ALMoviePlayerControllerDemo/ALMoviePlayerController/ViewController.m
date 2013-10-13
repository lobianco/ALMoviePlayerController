//
//  ViewController.m
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import "ViewController.h"
#import "ALMoviePlayerController.h"

@interface ViewController () <ALMoviePlayerControllerDelegate>

@property (nonatomic, strong) ALMoviePlayerController *moviePlayer;
@property (nonatomic) CGRect defaultFrame;

@end

@implementation ViewController

- (id)init {
    self = [super init];
    if (self) {
        self.title = NSLocalizedString(@"ALMoviePlayerController", @"ALMoviePlayerController");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor darkGrayColor];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Local File" style:UIBarButtonItemStyleBordered target:self action:@selector(localFile)];
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Remote File" style:UIBarButtonItemStyleBordered target:self action:@selector(remoteFile)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    //create a player
    self.moviePlayer = [[ALMoviePlayerController alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    self.moviePlayer.view.alpha = 0.f;
    self.moviePlayer.delegate = self; //IMPORTANT!
    
    //create the controls
    ALMoviePlayerControls *movieControls = [[ALMoviePlayerControls alloc] initWithMoviePlayer:self.moviePlayer style:ALMoviePlayerControlsStyleDefault];
    //[movieControls setAdjustsFullscreenImage:NO];
    [movieControls setBarColor:[UIColor colorWithRed:195/255.0 green:29/255.0 blue:29/255.0 alpha:0.5]];
    [movieControls setTimeRemainingDecrements:YES];
    //[movieControls setFadeDelay:2.0];
    //[movieControls setBarHeight:100.f];
    //[movieControls setSeekRate:2.f];
    
    //assign controls
    [self.moviePlayer setControls:movieControls];
    [self.view addSubview:self.moviePlayer.view];
    
    //THEN set contentURL
    [self.moviePlayer setContentURL:[NSURL URLWithString:@"http://archive.org/download/WaltDisneyCartoons-MickeyMouseMinnieMouseDonaldDuckGoofyAndPluto/WaltDisneyCartoons-MickeyMouseMinnieMouseDonaldDuckGoofyAndPluto-HawaiianHoliday1937-Video.mp4"]];
    
    //delay initial load so statusBarOrientation returns correct value
    double delayInSeconds = 0.3;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self configureViewForOrientation:[UIApplication sharedApplication].statusBarOrientation];
        [UIView animateWithDuration:0.3 delay:0.0 options:0 animations:^{
            self.moviePlayer.view.alpha = 1.f;
        } completion:^(BOOL finished) {
            self.navigationItem.leftBarButtonItem.enabled = YES;
            self.navigationItem.rightBarButtonItem.enabled = YES;
        }];
    });
}

- (void)configureViewForOrientation:(UIInterfaceOrientation)orientation {
    CGFloat videoWidth = 0;
    CGFloat videoHeight = 0;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        videoWidth = 700.f;
        videoHeight = 535.f;
    } else {
        videoWidth = self.view.frame.size.width;
        videoHeight = 220.f;
    }
    
    //calulate the frame on every rotation, so when we're returning from fullscreen mode we'll know where to position the movie plauyer
    self.defaultFrame = CGRectMake(self.view.frame.size.width/2 - videoWidth/2, self.view.frame.size.height/2 - videoHeight/2, videoWidth, videoHeight);
    
    //only manage the movie player frame when it's not in fullscreen. when in fullscreen, the frame is automatically managed
    if (self.moviePlayer.isFullscreen)
        return;
    
    //you MUST use [ALMoviePlayerController setFrame:] to adjust frame, NOT [ALMoviePlayerController.view setFrame:]
    [self.moviePlayer setFrame:self.defaultFrame];
}

//these files are in the public domain and no longer have property rights
- (void)localFile {
    [self.moviePlayer stop];
    [self.moviePlayer setContentURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"popeye" ofType:@"mp4"]]];
    [self.moviePlayer play];
}

- (void)remoteFile {
    [self.moviePlayer stop];
    [self.moviePlayer setContentURL:[NSURL URLWithString:@"http://archive.org/download/WaltDisneyCartoons-MickeyMouseMinnieMouseDonaldDuckGoofyAndPluto/WaltDisneyCartoons-MickeyMouseMinnieMouseDonaldDuckGoofyAndPluto-HawaiianHoliday1937-Video.mp4"]];
    [self.moviePlayer play];
}

//IMPORTANT!
- (void)moviePlayerWillMoveFromWindow {
    //movie player must be readded to this view upon exiting fullscreen mode.
    if (![self.view.subviews containsObject:self.moviePlayer.view])
        [self.view addSubview:self.moviePlayer.view];
    
    //you MUST use [ALMoviePlayerController setFrame:] to adjust frame, NOT [ALMoviePlayerController.view setFrame:]
    [self.moviePlayer setFrame:self.defaultFrame];
}

- (void)movieTimedOut {
    NSLog(@"MOVIE TIMED OUT");
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self configureViewForOrientation:toInterfaceOrientation];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
