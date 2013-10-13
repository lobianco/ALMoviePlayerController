//
//  ALMoviePlayerControls.h
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MPMoviePlayerController.h>

@class ALMoviePlayerController;

typedef enum {
    /** Controls will appear in a bottom bar */
    ALMoviePlayerControlsStyleEmbedded,
    
    /** Controls will appear in a top bar and bottom bar */
    ALMoviePlayerControlsStyleFullscreen,
    
    /** Controls will appear as ALMoviePlayerControlsStyleFullscreen when in fullscreen and ALMoviePlayerControlsStyleEmbedded at all other times */
    ALMoviePlayerControlsStyleDefault,
    
    /** Controls will not appear */
    ALMoviePlayerControlsStyleNone,
    
} ALMoviePlayerControlsStyle;

typedef enum {
    /** Controls are not doing anything */
    ALMoviePlayerControlsStateIdle,
    
    /** Controls are waiting for movie to finish loading */
    ALMoviePlayerControlsStateLoading,
    
    /** Controls are ready to play and/or playing */
    ALMoviePlayerControlsStateReady,
    
} ALMoviePlayerControlsState;

@interface ALMoviePlayerControls : UIView

/** 
 The style of the controls. Can be changed on the fly.
 
 Default value is ALMoviePlayerControlsStyleDefault
 */
@property (nonatomic, assign) ALMoviePlayerControlsStyle style;

/** 
 The state of the controls.
 */
@property (nonatomic, readonly) ALMoviePlayerControlsState state;

/**
 The color of the control bars. 
 
 Default value is black with a hint of transparency.
 */
@property (nonatomic, strong) UIColor *barColor;

/**
 The height of the control bars. 
 
 Default value is 70.f for iOS7+ and 50.f for previous versions.
 */
@property (nonatomic, assign) CGFloat barHeight;

/**
 The amount of time that the controls should stay on screen before automatically hiding.
 
 Default value is 5 seconds.
 */
@property (nonatomic, assign) NSTimeInterval fadeDelay;

/**
 The rate at which the movie should fastforward or rewind.
 
 Default value is 3x.
 */
@property (nonatomic, assign) float seekRate;

/** 
 Should the time-remaining number decrement as the video plays?
 
 Default value is NO.
 */
@property (nonatomic) BOOL timeRemainingDecrements;

/**
 Are the controls currently showing on screen?
 */
@property (nonatomic, readonly, getter = isShowing) BOOL showing;


/** 
 The default initializer method. The parameter may not be nil.
 */
- (id)initWithMoviePlayer:(ALMoviePlayerController *)moviePlayer style:(ALMoviePlayerControlsStyle)style;

@end