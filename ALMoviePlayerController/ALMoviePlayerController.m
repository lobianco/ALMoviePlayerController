//
//  ALMoviePlayerController.m
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import "ALMoviePlayerController.h"

@implementation UIDevice (ALSystemVersion)

+ (float)iOSVersion {
    static float version = 0.f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        version = [[[UIDevice currentDevice] systemVersion] floatValue];
    });
    return version;
}

@end

@implementation UIApplication (ALAppDimensions)

+ (CGSize)sizeInOrientation:(UIInterfaceOrientation)orientation {
    CGSize size = [UIScreen mainScreen].bounds.size;
    UIApplication *application = [UIApplication sharedApplication];
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        size = CGSizeMake(size.height, size.width);
    }
    if (!application.statusBarHidden && [UIDevice iOSVersion] < 7.0) {
        size.height -= MIN(application.statusBarFrame.size.width, application.statusBarFrame.size.height);
    }
    return size;
}

@end

static const CGFloat movieBackgroundPadding = 20.f; //if we don't pad the movie's background view, the edges will appear jagged when rotating
static const NSTimeInterval fullscreenAnimationDuration = 0.3;

@interface ALMoviePlayerController ()

@property (nonatomic, strong) UIView *movieBackgroundView;
@property (nonatomic, readwrite) BOOL movieFullscreen; //used to manipulate default fullscreen property

@end

@implementation ALMoviePlayerController

# pragma mark - Construct/Destruct

- (id)init {
    return [self initWithFrame:CGRectZero];
}

- (id)initWithContentURL:(NSURL *)url {
    [[NSException exceptionWithName:@"ALMoviePlayerController Exception" reason:@"Set contentURL after initialization." userInfo:nil] raise];
    return nil;
}

- (id)initWithFrame:(CGRect)frame {
    if ( (self = [super init]) ) {
        
        self.view.frame = frame;
        self.view.backgroundColor = [UIColor blackColor];
        [self setControlStyle:MPMovieControlStyleNone];
        
        _movieFullscreen = NO;
        
        if (!_movieBackgroundView) {
            _movieBackgroundView = [[UIView alloc] init];
            _movieBackgroundView.alpha = 0.f;
            [_movieBackgroundView setBackgroundColor:[UIColor blackColor]];
        }
    }
    return self;
}

- (void)dealloc {
    _delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

# pragma mark - Getters

- (BOOL)isFullscreen {
    return _movieFullscreen;
}

- (CGFloat)statusBarHeightInOrientation:(UIInterfaceOrientation)orientation {
    if ([UIDevice iOSVersion] >= 7.0)
        return 0.f;
    else if ([UIApplication sharedApplication].statusBarHidden)
        return 0.f;
    return 20.f;
}

# pragma mark - Setters

- (void)setContentURL:(NSURL *)contentURL {
    if (!_controls) {
        [[NSException exceptionWithName:@"ALMoviePlayerController Exception" reason:@"Set contentURL after setting controls." userInfo:nil] raise];
    }
    [super setContentURL:contentURL];
    [[NSNotificationCenter defaultCenter] postNotificationName:ALMoviePlayerContentURLDidChangeNotification object:nil];
    [self play];
}

- (void)setControls:(ALMoviePlayerControls *)controls {
    if (_controls != controls) {
        _controls = controls;
        _controls.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        [self.view addSubview:_controls];
    }
}

- (void)setFrame:(CGRect)frame {
    [self.view setFrame:frame];
    [self.controls setFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
}

- (void)setFullscreen:(BOOL)fullscreen {
    [self setFullscreen:fullscreen animated:NO];
}

- (void)setFullscreen:(BOOL)fullscreen animated:(BOOL)animated {
    _movieFullscreen = fullscreen;
    if (fullscreen) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MPMoviePlayerWillEnterFullscreenNotification object:nil];
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        if (!keyWindow) {
            keyWindow = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        }
        if (CGRectEqualToRect(self.movieBackgroundView.frame, CGRectZero)) {
            [self.movieBackgroundView setFrame:keyWindow.bounds];
        }
        [keyWindow addSubview:self.movieBackgroundView];
        [UIView animateWithDuration:animated ? fullscreenAnimationDuration : 0.0 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.movieBackgroundView.alpha = 1.f;
        } completion:^(BOOL finished) {
            self.view.alpha = 0.f;
            [self.movieBackgroundView addSubview:self.view];
            UIInterfaceOrientation currentOrientation = [[UIApplication sharedApplication] statusBarOrientation];
            [self rotateMoviePlayerForOrientation:currentOrientation animated:NO completion:^{
                [UIView animateWithDuration:animated ? fullscreenAnimationDuration : 0.0 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
                    self.view.alpha = 1.f;
                } completion:^(BOOL finished) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:MPMoviePlayerDidEnterFullscreenNotification object:nil];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarOrientationWillChange:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
                }];
            }];
        }];
        
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:MPMoviePlayerWillExitFullscreenNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        [UIView animateWithDuration:animated ? fullscreenAnimationDuration : 0.0 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.view.alpha = 0.f;
        } completion:^(BOOL finished) {
            if ([self.delegate respondsToSelector:@selector(moviePlayerWillMoveFromWindow)]) {
                [self.delegate moviePlayerWillMoveFromWindow];
            }
            self.view.alpha = 1.f;
            [UIView animateWithDuration:animated ? fullscreenAnimationDuration : 0.0 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.movieBackgroundView.alpha = 0.f;
            } completion:^(BOOL finished) {
                [self.movieBackgroundView removeFromSuperview];
                [[NSNotificationCenter defaultCenter] postNotificationName:MPMoviePlayerDidExitFullscreenNotification object:nil];
            }];
        }];
    }
}

#pragma mark - Notifications

- (void)videoLoadStateChanged:(NSNotification *)note {
    switch (self.loadState) {
        case MPMovieLoadStatePlayable:
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(movieTimedOut) object:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerLoadStateDidChangeNotification object:nil];
        default:
            break;
    }
}

- (void)statusBarOrientationWillChange:(NSNotification *)note {
    UIInterfaceOrientation orientation = (UIInterfaceOrientation)[[[note userInfo] objectForKey:UIApplicationStatusBarOrientationUserInfoKey] integerValue];
    [self rotateMoviePlayerForOrientation:orientation animated:YES completion:nil];
}

- (void)rotateMoviePlayerForOrientation:(UIInterfaceOrientation)orientation animated:(BOOL)animated completion:(void (^)(void))completion {
    CGFloat angle;
    CGSize windowSize = [UIApplication sizeInOrientation:orientation];
    CGRect backgroundFrame;
    CGRect movieFrame;
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            angle = M_PI;
            backgroundFrame = CGRectMake(-movieBackgroundPadding, -movieBackgroundPadding, windowSize.width + movieBackgroundPadding*2, windowSize.height + movieBackgroundPadding*2);
            movieFrame = CGRectMake(movieBackgroundPadding, movieBackgroundPadding, backgroundFrame.size.width - movieBackgroundPadding*2, backgroundFrame.size.height - movieBackgroundPadding*2);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            angle = - M_PI_2;
            backgroundFrame = CGRectMake([self statusBarHeightInOrientation:orientation] - movieBackgroundPadding, -movieBackgroundPadding, windowSize.height + movieBackgroundPadding*2, windowSize.width + movieBackgroundPadding*2);
            movieFrame = CGRectMake(movieBackgroundPadding, movieBackgroundPadding, backgroundFrame.size.height - movieBackgroundPadding*2, backgroundFrame.size.width - movieBackgroundPadding*2);
            break;
        case UIInterfaceOrientationLandscapeRight:
            angle = M_PI_2;
            backgroundFrame = CGRectMake(-movieBackgroundPadding, -movieBackgroundPadding, windowSize.height + movieBackgroundPadding*2, windowSize.width + movieBackgroundPadding*2);
            movieFrame = CGRectMake(movieBackgroundPadding, movieBackgroundPadding, backgroundFrame.size.height - movieBackgroundPadding*2, backgroundFrame.size.width - movieBackgroundPadding*2);
            break;
        case UIInterfaceOrientationPortrait:
        default:
            angle = 0.f;
            backgroundFrame = CGRectMake(-movieBackgroundPadding, [self statusBarHeightInOrientation:orientation] - movieBackgroundPadding, windowSize.width + movieBackgroundPadding*2, windowSize.height + movieBackgroundPadding*2);
            movieFrame = CGRectMake(movieBackgroundPadding, movieBackgroundPadding, backgroundFrame.size.width - movieBackgroundPadding*2, backgroundFrame.size.height - movieBackgroundPadding*2);
            break;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.movieBackgroundView.transform = CGAffineTransformMakeRotation(angle);
            self.movieBackgroundView.frame = backgroundFrame;
            [self setFrame:movieFrame];
        } completion:^(BOOL finished) {
            if (completion)
                completion();
        }];
    } else {
        self.movieBackgroundView.transform = CGAffineTransformMakeRotation(angle);
        self.movieBackgroundView.frame = backgroundFrame;
        [self setFrame:movieFrame];
        if (completion)
            completion();
    }
}

# pragma mark - Internal Methods

- (void)play {
    [super play];
    
    //remote file
    if (![self.contentURL.scheme isEqualToString:@"file"] && self.loadState == MPMovieLoadStateUnknown) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerLoadStateDidChangeNotification object:nil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(movieTimedOut) object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoLoadStateChanged:) name:MPMoviePlayerLoadStateDidChangeNotification object:nil];
        [self performSelector:@selector(movieTimedOut) withObject:nil afterDelay:20.f];
    }
}

-(void)movieTimedOut {
    if (!(self.loadState & MPMovieLoadStatePlayable) || !(self.loadState & MPMovieLoadStatePlaythroughOK)) {
        if ([self.delegate respondsToSelector:@selector(movieTimedOut)]) {
            [self.delegate performSelector:@selector(movieTimedOut)];
        }
    }
}

@end
