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

/*
static const inline BOOL isIpad() {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}
 */

static const CGFloat activityIndicatorSize = 40.f;

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
        
        [self setup];
        [self addNotifications];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_durationTimer invalidate];
    _airplayView.delegate = nil;
    _playPauseButton.delegate = nil;
    _fullscreenButton.delegate = nil;
}

# pragma mark - Construct/Destruct Helpers

- (void)setup {
    if (self.style == ALMoviePlayerControlsStyleNone)
        return;
    
    _fadeDelay = 5.0;
    _timeRemainingDecrements = NO;
    
    //top bar
    _topBar = [[ALMoviePlayerControlsBar alloc] init];
    _topBar.alpha = 0.f;
    [self addSubview:_topBar];
    
    //bottom bar
    _bottomBar = [[ALMoviePlayerControlsBar alloc] init];
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
    _timeElapsedLabel.font = [UIFont systemFontOfSize:14.f];
    _timeElapsedLabel.textColor = [UIColor lightTextColor];
    _timeElapsedLabel.textAlignment = NSTextAlignmentRight;
    _timeElapsedLabel.text = @"0:00";
    _timeElapsedLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    _timeElapsedLabel.layer.shadowRadius = 1.f;
    _timeElapsedLabel.layer.shadowOffset = CGSizeMake(1.f, 1.f);
    _timeElapsedLabel.layer.shadowOpacity = 0.8f;
    
    _timeRemainingLabel = [[UILabel alloc] init];
    _timeRemainingLabel.backgroundColor = [UIColor clearColor];
    _timeRemainingLabel.font = [UIFont systemFontOfSize:14.f];
    _timeRemainingLabel.textColor = [UIColor lightTextColor];
    _timeRemainingLabel.textAlignment = NSTextAlignmentLeft;
    _timeRemainingLabel.text = @"0:00";
    _timeRemainingLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    _timeRemainingLabel.layer.shadowRadius = 1.f;
    _timeRemainingLabel.layer.shadowOffset = CGSizeMake(1.f, 1.f);
    _timeRemainingLabel.layer.shadowOpacity = 0.8f;
    
    _playPauseButton = [[ALButton alloc] init];
    [_playPauseButton setImage:[UIImage imageNamed:@"moviePause.png"] forState:UIControlStateNormal];
    [_playPauseButton setImage:[UIImage imageNamed:@"moviePlay.png"] forState:UIControlStateSelected];
    [_playPauseButton addTarget:self action:@selector(playPausePressed:) forControlEvents:UIControlEventTouchUpInside];
    _playPauseButton.delegate = self;
    
    _airplayView = [[ALAirplayView alloc] init];
    _airplayView.delegate = self;
    
    _fullscreenButton = [[ALButton alloc] init];
    [_fullscreenButton setImage:[UIImage imageNamed:@"movieFullscreen.png"] forState:UIControlStateNormal];
    [_fullscreenButton addTarget:self action:@selector(fullscreenPressed:) forControlEvents:UIControlEventTouchUpInside];
    _fullscreenButton.delegate = self;
    
    if (_style == ALMoviePlayerControlsStyleFullscreen || (_style == ALMoviePlayerControlsStyleDefault && _moviePlayer.isFullscreen)) {
        [_topBar addSubview:_durationSlider];
        [_topBar addSubview:_timeElapsedLabel];
        [_topBar addSubview:_timeRemainingLabel];
        [_bottomBar addSubview:_playPauseButton];
        
        _volumeView = [[MPVolumeView alloc] init];
        [_volumeView setShowsRouteButton:NO];
        [_volumeView setShowsVolumeSlider:YES];
        [_bottomBar addSubview:_volumeView];
        
        [_bottomBar addSubview:_airplayView];
        [_bottomBar addSubview:_fullscreenButton];
    }
    
    else if (_style == ALMoviePlayerControlsStyleEmbedded || (_style == ALMoviePlayerControlsStyleDefault && !_moviePlayer.isFullscreen)) {
        [_bottomBar addSubview:_playPauseButton];
        [_bottomBar addSubview:_durationSlider];
        [_bottomBar addSubview:_timeElapsedLabel];
        [_bottomBar addSubview:_timeRemainingLabel];
        
        [_bottomBar addSubview:_airplayView];
        [_bottomBar addSubview:_fullscreenButton];
    }
    
    //static stuff
    _activityBackgroundView = [[UIView alloc] init];
    [_activityBackgroundView setBackgroundColor:[UIColor blackColor]];
    _activityBackgroundView.alpha = 0.f;
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicator.alpha = 0.f;
    _activityIndicator.hidesWhenStopped = YES;
}

- (void)resetViews {
    [self stopDurationTimer];
    _fullscreenButton.delegate = nil;
    _airplayView.delegate = nil;
    _playPauseButton.delegate = nil;
    [_topBar removeFromSuperview];
    [_bottomBar removeFromSuperview];
}

# pragma mark - Setters

- (void)setStyle:(ALMoviePlayerControlsStyle)style {
    BOOL flag = _style == ALMoviePlayerControlsStyleDefault;
    if (_style != style) {
        _style = style;
        
        [self hideControls:^{
            [self resetViews];
            [self setup];
            double delayInSeconds = 0.2;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self setDurationSliderMaxMinValues];
                [self monitorMoviePlayback]; //resume values
                [self startDurationTimer];
                [self showControls];
                if (flag) {
                    _style = ALMoviePlayerControlsStyleDefault;
                }
            });
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

- (void)buttonTouchedDown {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
}

- (void)buttonTouchedUpOutside {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)buttonTouchCancelled {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)airplayButtonTouchedDown {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
}

- (void)airplayButtonTouchedUpInside {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow) {
        keyWindow = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    }
    windowSubviews = keyWindow.layer.sublayers.count;
    [keyWindow addObserver:self forKeyPath:@"layer.sublayers" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)airplayButtonTouchedUpOutside {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)airplayButtonTouchFailed {
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
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

- (void)playPausePressed:(UIButton *)button {
    self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying ? [self.moviePlayer pause] : [self.moviePlayer play];
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)fullscreenPressed:(UIButton *)button {
    if (self.style == ALMoviePlayerControlsStyleDefault) {
        self.style = self.moviePlayer.isFullscreen ? ALMoviePlayerControlsStyleEmbedded : ALMoviePlayerControlsStyleFullscreen;
    }
    [self.moviePlayer setFullscreen:!self.moviePlayer.isFullscreen animated:YES];
    [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.style == ALMoviePlayerControlsStyleNone)
        return;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.style == ALMoviePlayerControlsStyleNone)
        return;
    self.isShowing ? [self hideControls:nil] : [self showControls];
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
    self.state = ALMoviePlayerControlsStateIdle;
}

- (void)movieLoadStateDidChange:(NSNotification *)note {
    switch (self.moviePlayer.loadState) {
        case MPMovieLoadStatePlayable:
            [self showControls];
        case MPMovieLoadStatePlaythroughOK:
            self.state = ALMoviePlayerControlsStateReady;
            break;
        case MPMovieLoadStateStalled:
        case MPMovieLoadStateUnknown:
            self.state = ALMoviePlayerControlsStateLoading;
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
                [self showControls];
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
    [self hideControls:nil];
    //don't show loading indicator for local files
    self.state = [self.moviePlayer.contentURL.scheme isEqualToString:@"file"] ? ALMoviePlayerControlsStateReady : ALMoviePlayerControlsStateLoading;
}

# pragma mark - Internal Methods

- (void)startDurationTimer {
    self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(monitorMoviePlayback) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.durationTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopDurationTimer {
    [self.durationTimer invalidate];
}

- (void)showControls {
    if (!self.isShowing) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
        if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
            [self.topBar setNeedsDisplay];
        }
        [self.bottomBar setNeedsDisplay];
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveLinear|UIViewAnimationOptionBeginFromCurrentState animations:^{
            if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
                self.topBar.alpha = 1.f;
            }
            self.bottomBar.alpha = 1.f;
        } completion:^(BOOL finished) {
            _showing = YES;
            [self performSelector:@selector(hideControls:) withObject:nil afterDelay:self.fadeDelay];
        }];
    }
}

- (void)hideControls:(void(^)(void))completion {
    if (self.isShowing) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls:) object:nil];
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveLinear|UIViewAnimationOptionBeginFromCurrentState animations:^{
            if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
                self.topBar.alpha = 0.f;
            }
            self.bottomBar.alpha = 0.f;
        } completion:^(BOOL finished) {
            _showing = NO;
            if (completion)
                completion();
        }];
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
    [UIView animateWithDuration:0.2f delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
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
    self.timeRemainingLabel.text = [NSString stringWithFormat:@"%.0f:%02.0f", minutesRemaining, secondsRemaining];
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
    CGFloat paddingFromBezel = self.frame.size.width <= 320.f ? 10.f : 30.f;
    CGFloat paddingBetweenButtons = self.frame.size.width <= 320.f ? 10.f : 30.f;
    CGFloat paddingBetweenLabelsAndSlider = 10.f;
    CGFloat barHeight = 50.f;
    CGFloat sliderHeight = 34.f; //default height
    CGFloat airplayWidth = 30.f;
    CGFloat airplayHeight = 22.f;
    CGFloat fullscreenWidth = 28.f;
    CGFloat fullscreenHeight = fullscreenWidth;
    CGFloat labelWidth = 40.f;
    
    if (self.style == ALMoviePlayerControlsStyleFullscreen || (self.style == ALMoviePlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
        //top bar
        self.topBar.frame = CGRectMake(0, 0, self.frame.size.width, barHeight);
        self.timeElapsedLabel.frame = CGRectMake(paddingFromBezel, 0, labelWidth, barHeight);
        self.timeRemainingLabel.frame = CGRectMake(self.topBar.frame.size.width - paddingFromBezel - labelWidth, 0, labelWidth, barHeight);
        
        //bottom bar
        self.bottomBar.frame = CGRectMake(0, self.frame.size.height - barHeight, self.frame.size.width, barHeight);
        self.playPauseButton.frame = CGRectMake(self.bottomBar.frame.size.width/2 - 9.f, barHeight/2 - 11.f, 18.f, 22.f);
        self.volumeView.frame = CGRectMake(paddingFromBezel, barHeight/2 - 10.f, 160.f, 20.f);
        self.fullscreenButton.frame = CGRectMake(self.bottomBar.frame.size.width - paddingFromBezel - fullscreenWidth, barHeight/2 - fullscreenHeight/2, fullscreenWidth, fullscreenHeight);
        self.airplayView.frame = CGRectMake(self.fullscreenButton.frame.origin.x - paddingBetweenButtons - airplayWidth, barHeight/2 - airplayHeight/2, airplayWidth, airplayHeight);
    }
    
    else if (self.style == ALMoviePlayerControlsStyleEmbedded || (self.style == ALMoviePlayerControlsStyleDefault && !self.moviePlayer.isFullscreen)) {
        self.bottomBar.frame = CGRectMake(0, self.frame.size.height - barHeight, self.frame.size.width, barHeight);
        
        //left side of bottom bar
        self.playPauseButton.frame = CGRectMake(paddingFromBezel, barHeight/2 - 11.f, 18.f, 22.f);
        self.timeElapsedLabel.frame = CGRectMake(self.playPauseButton.frame.origin.x + self.playPauseButton.frame.size.width + paddingBetweenButtons, 0, labelWidth, barHeight);
        
        //right side of bottom bar
        self.fullscreenButton.frame = CGRectMake(self.bottomBar.frame.size.width - paddingFromBezel - fullscreenWidth, barHeight/2 - fullscreenHeight/2, fullscreenWidth, fullscreenHeight);
        self.airplayView.frame = CGRectMake(self.fullscreenButton.frame.origin.x - paddingBetweenButtons - airplayWidth, barHeight/2 - airplayHeight/2, airplayWidth, airplayHeight);
        self.timeRemainingLabel.frame = CGRectMake(self.airplayView.frame.origin.x - paddingBetweenButtons - labelWidth, 0, labelWidth, barHeight);
    }
    
    //duration slider
    CGFloat timeRemainingX = self.timeRemainingLabel.frame.origin.x;
    CGFloat timeElapsedX = self.timeElapsedLabel.frame.origin.x;
    CGFloat sliderWidth = ((timeRemainingX - paddingBetweenLabelsAndSlider) - (timeElapsedX + self.timeElapsedLabel.frame.size.width + paddingBetweenLabelsAndSlider));
    self.durationSlider.frame = CGRectMake(timeElapsedX + self.timeElapsedLabel.frame.size.width + paddingBetweenLabelsAndSlider, barHeight/2 - sliderHeight/2, sliderWidth, sliderHeight);
    
    if (self.state == ALMoviePlayerControlsStateLoading) {
        [_activityBackgroundView setFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [_activityIndicator setFrame:CGRectMake((self.frame.size.width / 2) - (activityIndicatorSize / 2), (self.frame.size.height / 2) - (activityIndicatorSize / 2), activityIndicatorSize, activityIndicatorSize)];
    }
}

@end

@implementation ALMoviePlayerControlsBar

- (id)init {
    if ( self = [super init] ) {
        self.opaque = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.0 alpha:0.5].CGColor);
    CGContextFillRect(context, rect);
}

@end
