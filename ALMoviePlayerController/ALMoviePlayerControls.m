//
//  ALMoviePlayerControls.m
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import "ALMoviePlayerControls.h"
#import "ALMoviePlayerController.h"
#import "ALAirplayView.h"
#import "ALButton.h"
#import <tgmath.h>
#import <QuartzCore/QuartzCore.h>

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

@interface ALMoviePlayerControlsBar : UIView

@property (nonatomic, strong) UIColor *color;

@end

static const inline BOOL isIpad() {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}
static const CGFloat activityIndicatorSize = 40.f;
static const CGFloat iPhoneScreenPortraitWidth = 320.f;

@interface ALMoviePlayerControls () <ALAirplayViewDelegate, ALButtonDelegate> {
    @private
    int windowSubviews;
}

@property (nonatomic, weak) ALMoviePlayerController *moviePlayer;
@property (nonatomic, assign) ALMoviePlayerControlsState state;
@property (nonatomic, getter = isShowing) BOOL showing;

@property (nonatomic, strong) NSTimer *durationTimer;

@property (nonatomic, strong) UIView *activityBackgroundView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) ALMoviePlayerControlsBar *topBar;
@property (nonatomic, strong) ALMoviePlayerControlsBar *bottomBar;
@property (nonatomic, strong) UISlider *durationSlider;
@property (nonatomic, strong) ALButton *playPauseButton;
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, strong) ALAirplayView *airplayView;
@property (nonatomic, strong) ALButton *fullscreenButton;
@property (nonatomic, strong) UILabel *timeElapsedLabel;
@property (nonatomic, strong) UILabel *timeRemainingLabel;
@property (nonatomic, strong) ALButton *seekForwardButton;
@property (nonatomic, strong) ALButton *seekBackwardButton;
@property (nonatomic, strong) ALButton *scaleButton;

@end

@implementation ALMoviePlayerControls

# pragma mark - Construct/Destruct

- (id)initWithMoviePlayer:(ALMoviePlayerController *)moviePlayer style:(ALMoviePlayerControlsStyle)style {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        _moviePlayer = moviePlayer;
        _style = style;
        _showing = NO;
        _fadeDelay = 5.0;
        _timeRemainingDecrements = NO;
        _barColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        
        //in fullscreen mode, move controls away from top status bar and bottom screen bezel. I think the iOS7 control center gestures interfere with the uibutton touch events. this will alleviate that a little (correct me if I'm wrong and/or adjust if necessary).
        _barHeight = [UIDevice iOSVersion] >= 7.0 ? 70.f : 50.f;
        
        _seekRate = 3.f;
        _state = ALMoviePlayerControlsStateIdle;
        
        [self setup];
        [self addNotifications];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_durationTimer invalidate];
    [self nilDelegates];
}

# pragma mark - Construct/Destruct Helpers

- (void)setup {
    if (self.style == ALMoviePlayerControlsStyleNone)
        return;

    //top bar
    _topBar = [[ALMoviePlayerControlsBar alloc] init];
    _topBar.color = _barColor;
    _topBar.alpha = 0.f;
    [self addSubview:_topBar];
    
    //bottom bar
    _bottomBar = [[ALMoviePlayerControlsBar alloc] init];
    _bottomBar.color = _barColor;
    _bottomBar.alpha = 0.f;
    [self addSubview:_bottomBar];
    
    _durationSlider = [[UISlider alloc] init];
    _durationSlider.value = 0.f;
    _durationSlider.continuous = YES;
    [_durationSlider addTarget:self action:@selector(durationSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_durationSlider addTarget:self action:@selector(durationSliderTouchBegan:) forControlEvents:UIControlEventTouchDown];
    [_durationSlider addTarget:self action:@selector(durationSliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside];
    [_durationSlider addTarget:self action:@selector(durationSliderTouchEnded:) forControlEvents:UIControlEventTouchUpOutside];
    
    _timeElapsedLabel = [[UILabel alloc] init];
    _timeElapsedLabel.backgroundColor = [UIColor clearColor];
    _timeElapsedLabel.font = [UIFont systemFontOfSize:12.f];
    _timeElapsedLabel.textColor = [UIColor lightTextColor];
    _timeElapsedLabel.textAlignment = NSTextAlignmentRight;
    _timeElapsedLabel.text = @"0:00";
    _timeElapsedLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    _timeElapsedLabel.layer.shadowRadius = 1.f;
    _timeElapsedLabel.layer.shadowOffset = CGSizeMake(1.f, 1.f);
    _timeElapsedLabel.layer.shadowOpacity = 0.8f;
    
    _timeRemainingLabel = [[UILabel alloc] init];
    _timeRemainingLabel.backgroundColor = [UIColor clearColor];
    _timeRemainingLabel.font = [UIFont systemFontOfSize:12.f];
    _timeRemainingLabel.textColor = [UIColor lightTextColor];
    _timeRemainingLabel.textAlignment = NSTextAlignmentLeft;
    _timeRemainingLabel.text = @"0:00";
    _timeRemainingLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    _timeRemainingLabel.layer.shadowRadius = 1.f;
    _timeRemainingLabel.layer.shadowOffset = CGSizeMake(1.f, 1.f);
    _timeRemainingLabel.layer.shadowOpacity = 0.8f;
    
    if (_style == ALMoviePlayerControlsStyleFullscreen || (_style == ALMoviePlayerControlsStyleDefault && _moviePlayer.isFullscreen)) {
        [_topBar addSubview:_durationSlider];
        [_topBar addSubview:_timeElapsedLabel];
        [_topBar addSubview:_timeRemainingLabel];
        
        _fullscreenButton = [[ALButton alloc] init];
        [_fullscreenButton setTitle:@"Done" forState:UIControlStateNormal];
        [_fullscreenButton setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
        _fullscreenButton.titleLabel.shadowOffset = CGSizeMake(1.f, 1.f);
        [_fullscreenButton.titleLabel setFont:[UIFont systemFontOfSize:14.f]];
        _fullscreenButton.delegate = self;
        [_fullscreenButton addTarget:self action:@selector(fullscreenPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_topBar addSubview:_fullscreenButton];
        
        _scaleButton = [[ALButton alloc] init];
        _scaleButton.delegate = self;
        [_scaleButton setImage:[UIImage imageNamed:@"movieFullscreen.png"] forState:UIControlStateNormal];
        [_scaleButton setImage:[UIImage imageNamed:@"movieEndFullscreen.png"] forState:UIControlStateSelected];
        [_scaleButton addTarget:self action:@selector(scalePressed:) forControlEvents:UIControlEventTouchUpInside];
        [_topBar addSubview:_scaleButton];
        
        _volumeView = [[MPVolumeView alloc] init];
        [_volumeView setShowsRouteButton:NO];
        [_volumeView setShowsVolumeSlider:YES];
        [_bottomBar addSubview:_volumeView];
        
        _seekForwardButton = [[ALButton alloc] init];
        [_seekForwardButton setImage:[UIImage imageNamed:@"movieForward.png"] forState:UIControlStateNormal];
        [_seekForwardButton setImage:[UIImage imageNamed:@"movieForwardSelected.png"] forState:UIControlStateSelected];
        _seekForwardButton.delegate = self;
        [_seekForwardButton addTarget:self action:@selector(seekForwardPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_seekForwardButton];
        
        _seekBackwardButton = [[ALButton alloc] init];
        [_seekBackwardButton setImage:[UIImage imageNamed:@"movieBackward.png"] forState:UIControlStateNormal];
        [_seekBackwardButton setImage:[UIImage imageNamed:@"movieBackwardSelected.png"] forState:UIControlStateSelected];
        _seekBackwardButton.delegate = self;
        [_seekBackwardButton addTarget:self action:@selector(seekBackwardPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_seekBackwardButton];
    }
    
    else if (_style == ALMoviePlayerControlsStyleEmbedded || (_style == ALMoviePlayerControlsStyleDefault && !_moviePlayer.isFullscreen)) {
        [_bottomBar addSubview:_durationSlider];
        [_bottomBar addSubview:_timeElapsedLabel];
        [_bottomBar addSubview:_timeRemainingLabel];
        
        _fullscreenButton = [[ALButton alloc] init];
        [_fullscreenButton setImage:[UIImage imageNamed:@"movieFullscreen.png"] forState:UIControlStateNormal];
        [_fullscreenButton addTarget:self action:@selector(fullscreenPressed:) forControlEvents:UIControlEventTouchUpInside];
        _fullscreenButton.delegate = self;
        [_bottomBar addSubview:_fullscreenButton];
    }
    
    //static stuff
    _playPauseButton = [[ALButton alloc] init];
    [_playPauseButton setImage:[UIImage imageNamed:@"moviePause.png"] forState:UIControlStateNormal];
    [_playPauseButton setImage:[UIImage imageNamed:@"moviePlay.png"] forState:UIControlStateSelected];
    [_playPauseButton setSelected:_moviePlayer.playbackState == MPMoviePlaybackStatePlaying ? NO : YES];
    [_playPauseButton addTarget:self action:@selector(playPausePressed:) forControlEvents:UIControlEventTouchUpInside];
    _playPauseButton.delegate = self;
    [_bottomBar addSubview:_playPauseButton];
    
    _airplayView = [[ALAirplayView alloc] init];
    _airplayView.delegate = self;
    [_bottomBar addSubview:_airplayView];
    
    _activityBackgroundView = [[UIView alloc] init];
    [_activityBackgroundView setBackgroundColor:[UIColor blackColor]];
    _activityBackgroundView.alpha = 0.f;
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicator.alpha = 0.f;
    _activityIndicator.hidesWhenStopped = YES;
}

- (void)resetViews {
    [self stopDurationTimer];
    [self nilDelegates];
    [_topBar removeFromSuperview];
    [_bottomBar removeFromSuperview];
}

- (void)nilDelegates {
    _airplayView.delegate = nil;
    _playPauseButton.delegate = nil;
    _fullscreenButton.delegate = nil;
    _seekForwardButton.delegate = nil;
    _seekBackwardButton.delegate = nil;
    _scaleButton.delegate = self;
}

# pragma mark - Setters

- (void)setStyle:(ALMoviePlayerControlsStyle)style {
    if (_style != style) {
        BOOL flag = _style == ALMoviePlayerControlsStyleDefault;
        [self hideControls:^{
            [self resetViews];
            _style = style;
            [self setup];
            if (_style != ALMoviePlayerControlsStyleNone) {
                double delayInSeconds = 0.2;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self setDurationSliderMaxMinValues];
                    [self monitorMoviePlayback]; //resume values
                    [self startDurationTimer];
                    [self showControls:^{
                        if (flag) {
                            //put style back to default
                            _style = ALMoviePlayerControlsStyleDefault;
                        }
                    }];
                    
                });
            } else {
                if (flag) {
                    //put style back to default
                    _style = ALMoviePlayerControlsStyleDefault;
                }
            }
        }];
    }
}

- (void)setState:(ALMoviePlayerControlsState)state {
    if (_state != state) {
        _state = state;
        
        switch (state) {
            case ALMoviePlayerControlsStateLoading:
                [self showLoadingIndicators];
                break;
            case ALMoviePlayerControlsStateReady:
                [self hideLoadingIndicators];
                break;
            case ALMoviePlayerControlsStateIdle:
            default:
                break;
        }
    }
}

- (void)setBarColor:(UIColor *)barColor {
    if (_barColor != barColor) {
        _barColor = barColor;
        [self.topBar setColor:barColor];
        [self.bottomBar setColor:barColor];
    }
}

# pragma mark - UIControl/Touch Events

- (void)durationSliderTouchBegan:(UISlider *)slider {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
    [self.moviePlayer pause];
}

- (void)durationSliderTouchEnded:(UISlider *)slider {
    [self.moviePlayer setCurrentPlaybackTime:floor(slider.value)];
    [self.moviePlayer play];
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)durationSliderValueChanged:(UISlider *)slider {
    double currentTime = floor(slider.value);
    double totalTime = floor(self.moviePlayer.duration);
    [self setTimeLabelValues:currentTime totalTime:totalTime];
}

- (void)buttonTouchedDown:(UIButton *)button {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
}

- (void)buttonTouchedUpOutside:(UIButton *)button {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)buttonTouchCancelled:(UIButton *)button {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)airplayButtonTouchedDown {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
}

- (void)airplayButtonTouchedUpOutside {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)airplayButtonTouchFailed {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)airplayButtonTouchedUpInside {
    //TODO iphone
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow) {
        keyWindow = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    }
    if (isIpad()) {
        windowSubviews = keyWindow.layer.sublayers.count;
        [keyWindow addObserver:self forKeyPath:@"layer.sublayers" options:NSKeyValueObservingOptionNew context:NULL];
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:UIWindowDidBecomeKeyNotification object:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (![keyPath isEqualToString:@"layer.sublayers"]) {
        return;
    }
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow) {
        keyWindow = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    }
    if (keyWindow.layer.sublayers.count == windowSubviews) {
        [keyWindow removeObserver:self forKeyPath:@"layer.sublayers"];
        [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
    }
}

- (void)windowDidResignKey:(NSNotification *)note {
    UIWindow *resignedWindow = (UIWindow *)[note object];
    if ([self isAirplayShowingInView:resignedWindow]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIWindowDidResignKeyNotification object:nil];
        [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
    }
}

- (void)windowDidBecomeKey:(NSNotification *)note {
    UIWindow *keyWindow = (UIWindow *)[note object];
    if ([self isAirplayShowingInView:keyWindow]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIWindowDidBecomeKeyNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:UIWindowDidResignKeyNotification object:nil];
    }
}

- (BOOL)isAirplayShowingInView:(UIView *)view {
    BOOL actionSheet = NO;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIActionSheet class]]) {
            actionSheet = YES;
        } else {
            actionSheet = [self isAirplayShowingInView:subview];
        }
    }
    return actionSheet;
}

- (void)playPausePressed:(UIButton *)button {
    self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying ? [self.moviePlayer pause] : [self.moviePlayer play];
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)fullscreenPressed:(UIButton *)button {
    if (self.style == ALMoviePlayerControlsStyleDefault) {
        self.style = self.moviePlayer.isFullscreen ? ALMoviePlayerControlsStyleEmbedded : ALMoviePlayerControlsStyleFullscreen;
    }
    if (self.moviePlayer.currentPlaybackRate != 1.f) {
        self.moviePlayer.currentPlaybackRate = 1.f;
    }
    [self.moviePlayer setFullscreen:!self.moviePlayer.isFullscreen animated:YES];
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)scalePressed:(UIButton *)button {
    button.selected = !button.selected;
    [self.moviePlayer setScalingMode:button.selected ? MPMovieScalingModeAspectFill : MPMovieScalingModeAspectFit];
}

- (void)seekForwardPressed:(UIButton *)button {
    self.moviePlayer.currentPlaybackRate = !button.selected ? self.seekRate : 1.f;
    button.selected = !button.selected;
    self.seekBackwardButton.selected = NO;
    if (!button.selected) {
        [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
    }
}

- (void)seekBackwardPressed:(UIButton *)button {
    self.moviePlayer.currentPlaybackRate = !button.selected ? -self.seekRate : 1.f;
    button.selected = !button.selected;
    self.seekForwardButton.selected = NO;
    if (!button.selected) {
        [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.style == ALMoviePlayerControlsStyleNone)
        return;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.style == ALMoviePlayerControlsStyleNone)
        return;
    self.isShowing ? [self hideControls:nil] : [self showControls:nil];
}

# pragma mark - Notifications

- (void)addNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlaybackStateDidChange:) name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieFinished:) name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieContentURLDidChange:) name:ALMoviePlayerContentURLDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieDurationAvailable:) name:MPMovieDurationAvailableNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieLoadStateDidChange:) name:MPMoviePlayerLoadStateDidChangeNotification object:nil];
}

- (void)movieFinished:(NSNotification *)note {
    self.playPauseButton.selected = YES;
    [self.durationTimer invalidate];
    [self.moviePlayer setCurrentPlaybackTime:0.0];
    [self monitorMoviePlayback]; //reset values
    [self hideControls:nil];
    self.state = ALMoviePlayerControlsStateIdle;
}

- (void)movieLoadStateDidChange:(NSNotification *)note {
    switch (self.moviePlayer.loadState) {
        case MPMovieLoadStatePlayable:
        case MPMovieLoadStatePlaythroughOK:
            [self showControls:nil];
            self.state = ALMoviePlayerControlsStateReady;
            break;
        case MPMovieLoadStateStalled:
        case MPMovieLoadStateUnknown:
            break;
        default:
            break;
    }
}

- (void)moviePlaybackStateDidChange:(NSNotification *)note {
    switch (self.moviePlayer.playbackState) {
        case MPMoviePlaybackStatePlaying:
            self.playPauseButton.selected = NO;
            [self startDurationTimer];
            
            //local file
            if ([self.moviePlayer.contentURL.scheme isEqualToString:@"file"]) {
                [self setDurationSliderMaxMinValues];
                [self showControls:nil];
            }
        case MPMoviePlaybackStateSeekingBackward:
        case MPMoviePlaybackStateSeekingForward:
            self.state = ALMoviePlayerControlsStateReady;
            break;
        case MPMoviePlaybackStateInterrupted:
            self.state = ALMoviePlayerControlsStateLoading;
            break;
        case MPMoviePlaybackStatePaused:
        case MPMoviePlaybackStateStopped:
            self.state = ALMoviePlayerControlsStateIdle;
            self.playPauseButton.selected = YES;
            [self stopDurationTimer];
            break;
        default:
            break;
    }
}

- (void)movieDurationAvailable:(NSNotification *)note {
    [self setDurationSliderMaxMinValues];
}

- (void)movieContentURLDidChange:(NSNotification *)note {
    [self hideControls:^{
        //don't show loading indicator for local files
        self.state = [self.moviePlayer.contentURL.scheme isEqualToString:@"file"] ? ALMoviePlayerControlsStateReady : ALMoviePlayerControlsStateLoading;
    }];
}

# pragma mark - Internal Methods

- (void)startDurationTimer {
    self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(monitorMoviePlayback) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.durationTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopDurationTimer {
    [self.durationTimer invalidate];
}

- (void)showControls:(void(^)(void))completion {
    if (!self.isShowing) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
        if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
            [self.topBar setNeedsDisplay];
        }
        [self.bottomBar setNeedsDisplay];
        [UIView animateWithDuration:0.3 delay:0.0 options:0 animations:^{
            if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
                self.topBar.alpha = 1.f;
            }
            self.bottomBar.alpha = 1.f;
        } completion:^(BOOL finished) {
            _showing = YES;
            if (completion)
                completion();
            [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
        }];
    } else {
        if (completion)
            completion();
    }
}

- (void)hideControls:(void(^)(void))completion {
    if (self.isShowing) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
        [UIView animateWithDuration:0.3 delay:0.0 options:0 animations:^{
            if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
                self.topBar.alpha = 0.f;
            }
            self.bottomBar.alpha = 0.f;
        } completion:^(BOOL finished) {
            _showing = NO;
            if (completion)
                completion();
        }];
    } else {
        if (completion)
            completion();
    }
}

- (void)showLoadingIndicators {
    [self addSubview:_activityBackgroundView];
    [self addSubview:_activityIndicator];
    [_activityIndicator startAnimating];
    
    [UIView animateWithDuration:0.2f animations:^{
        _activityBackgroundView.alpha = 1.f;
        _activityIndicator.alpha = 1.f;
    }];
}

- (void)hideLoadingIndicators {
    [UIView animateWithDuration:0.2f delay:0.0 options:0 animations:^{
        self.activityBackgroundView.alpha = 0.0f;
        self.activityIndicator.alpha = 0.f;
    } completion:^(BOOL finished) {
        [self.activityBackgroundView removeFromSuperview];
        [self.activityIndicator removeFromSuperview];
    }];
}

- (void)setDurationSliderMaxMinValues {
    CGFloat duration = self.moviePlayer.duration;
    self.durationSlider.minimumValue = 0.f;
    self.durationSlider.maximumValue = duration;
}

- (void)setTimeLabelValues:(double)currentTime totalTime:(double)totalTime {
    double minutesElapsed = floor(currentTime / 60.0);
    double secondsElapsed = fmod(currentTime, 60.0);
    self.timeElapsedLabel.text = [NSString stringWithFormat:@"%.0f:%02.0f", minutesElapsed, secondsElapsed];
    
    double minutesRemaining;
    double secondsRemaining;
    if (self.timeRemainingDecrements) {
        minutesRemaining = floor((totalTime - currentTime) / 60.0);
        secondsRemaining = fmod((totalTime - currentTime), 60.0);
    } else {
        minutesRemaining = floor(totalTime / 60.0);
        secondsRemaining = floor(fmod(totalTime, 60.0));
    }
    self.timeRemainingLabel.text = self.timeRemainingDecrements ? [NSString stringWithFormat:@"-%.0f:%02.0f", minutesRemaining, secondsRemaining] : [NSString stringWithFormat:@"%.0f:%02.0f", minutesRemaining, secondsRemaining];
}

- (void)monitorMoviePlayback {
    double currentTime = floor(self.moviePlayer.currentPlaybackTime);
    double totalTime = floor(self.moviePlayer.duration);
    [self setTimeLabelValues:currentTime totalTime:totalTime];
    self.durationSlider.value = ceil(currentTime);
}

- (void)layoutSubviews {
    [super layoutSubviews];
            
    if (self.style == ALMoviePlayerControlsStyleNone)
        return;
    
    //common sizes
    CGFloat paddingFromBezel = self.frame.size.width <= iPhoneScreenPortraitWidth ? 10.f : 20.f;
    CGFloat paddingBetweenButtons = self.frame.size.width <= iPhoneScreenPortraitWidth ? 10.f : 30.f;
    CGFloat paddingBetweenPlaybackButtons = self.frame.size.width <= iPhoneScreenPortraitWidth ? 20.f : 30.f;
    CGFloat paddingBetweenLabelsAndSlider = 10.f;
    CGFloat sliderHeight = 34.f; //default height
    CGFloat volumeHeight = 20.f;
    CGFloat volumeWidth = isIpad() ? 210.f : 120.f;
    CGFloat seekWidth = 36.f;
    CGFloat seekHeight = 20.f;
    CGFloat airplayWidth = 30.f;
    CGFloat airplayHeight = 22.f;
    CGFloat playWidth = 18.f;
    CGFloat playHeight = 22.f;
    CGFloat labelWidth = 30.f;
    
    if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
        //top bar
        CGFloat fullscreenWidth = 34.f;
        CGFloat fullscreenHeight = self.barHeight;
        CGFloat scaleWidth = 28.f;
        CGFloat scaleHeight = 28.f;
        self.topBar.frame = CGRectMake(0, 0, self.frame.size.width, self.barHeight);
        self.fullscreenButton.frame = CGRectMake(paddingFromBezel, self.barHeight/2 - fullscreenHeight/2, fullscreenWidth, fullscreenHeight);
        self.timeElapsedLabel.frame = CGRectMake(self.fullscreenButton.frame.origin.x + self.fullscreenButton.frame.size.width + paddingBetweenButtons, 0, labelWidth, self.barHeight);
        self.scaleButton.frame = CGRectMake(self.topBar.frame.size.width - paddingFromBezel - scaleWidth, self.barHeight/2 - scaleHeight/2, scaleWidth, scaleHeight);
        self.timeRemainingLabel.frame = CGRectMake(self.scaleButton.frame.origin.x - paddingBetweenButtons - labelWidth, 0, labelWidth, self.barHeight);
        
        //bottom bar
        self.bottomBar.frame = CGRectMake(0, self.frame.size.height - self.barHeight, self.frame.size.width, self.barHeight);
        self.playPauseButton.frame = CGRectMake(self.bottomBar.frame.size.width/2 - playWidth/2, self.barHeight/2 - playHeight/2, playWidth, playHeight);
        self.seekForwardButton.frame = CGRectMake(self.playPauseButton.frame.origin.x + self.playPauseButton.frame.size.width + paddingBetweenPlaybackButtons, self.barHeight/2 - seekHeight/2 + 1.f, seekWidth, seekHeight);
        self.seekBackwardButton.frame = CGRectMake(self.playPauseButton.frame.origin.x - paddingBetweenPlaybackButtons - seekWidth, self.barHeight/2 - seekHeight/2 + 1.f, seekWidth, seekHeight);
        
        //hide volume view in iPhone's portrait orientation
        if (self.frame.size.width <= iPhoneScreenPortraitWidth) {
            self.volumeView.alpha = 0.f;
        } else {
            self.volumeView.alpha = 1.f;
            self.volumeView.frame = CGRectMake(paddingFromBezel, self.barHeight/2 - volumeHeight/2, volumeWidth, volumeHeight);
        }
        
        self.airplayView.frame = CGRectMake(self.bottomBar.frame.size.width - paddingFromBezel - airplayWidth, self.barHeight/2 - airplayHeight/2, airplayWidth, airplayHeight);
    }
    
    else if (self.style == ALMoviePlayerControlsStyleEmbedded || (self.style == ALMoviePlayerControlsStyleDefault && !self.moviePlayer.isFullscreen)) {
        self.bottomBar.frame = CGRectMake(0, self.frame.size.height - self.barHeight, self.frame.size.width, self.barHeight);
        
        //left side of bottom bar
        self.playPauseButton.frame = CGRectMake(paddingFromBezel, self.barHeight/2 - playHeight/2, playWidth, playHeight);
        self.timeElapsedLabel.frame = CGRectMake(self.playPauseButton.frame.origin.x + self.playPauseButton.frame.size.width + paddingBetweenButtons, 0, labelWidth, self.barHeight);
        
        //right side of bottom bar
        CGFloat fullscreenWidth = 28.f;
        CGFloat fullscreenHeight = fullscreenWidth;
        self.fullscreenButton.frame = CGRectMake(self.bottomBar.frame.size.width - paddingFromBezel - fullscreenWidth, self.barHeight/2 - fullscreenHeight/2, fullscreenWidth, fullscreenHeight);
        self.airplayView.frame = CGRectMake(self.fullscreenButton.frame.origin.x - paddingBetweenButtons - airplayWidth, self.barHeight/2 - airplayHeight/2, airplayWidth, airplayHeight);
        self.timeRemainingLabel.frame = CGRectMake(self.airplayView.frame.origin.x - paddingBetweenButtons - labelWidth, 0, labelWidth, self.barHeight);
    }
    
    //duration slider
    CGFloat timeRemainingX = self.timeRemainingLabel.frame.origin.x;
    CGFloat timeElapsedX = self.timeElapsedLabel.frame.origin.x;
    CGFloat sliderWidth = ((timeRemainingX - paddingBetweenLabelsAndSlider) - (timeElapsedX + self.timeElapsedLabel.frame.size.width + paddingBetweenLabelsAndSlider));
    self.durationSlider.frame = CGRectMake(timeElapsedX + self.timeElapsedLabel.frame.size.width + paddingBetweenLabelsAndSlider, self.barHeight/2 - sliderHeight/2, sliderWidth, sliderHeight);
    
    if (self.state == ALMoviePlayerControlsStateLoading) {
        [_activityBackgroundView setFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [_activityIndicator setFrame:CGRectMake((self.frame.size.width / 2) - (activityIndicatorSize / 2), (self.frame.size.height / 2) - (activityIndicatorSize / 2), activityIndicatorSize, activityIndicatorSize)];
    }
}

@end

# pragma mark - ALMoviePlayerControlsBar

@implementation ALMoviePlayerControlsBar

- (id)init {
    if ( self = [super init] ) {
        self.opaque = NO;
    }
    return self;
}

- (void)setColor:(UIColor *)color {
    if (_color != color) {
        _color = color;
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [_color CGColor]);
    CGContextFillRect(context, rect);
}

@end
