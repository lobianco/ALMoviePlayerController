//
//  ALAirplayView.h
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>

@protocol ALAirplayViewDelegate <NSObject>
@optional
- (void)airplayButtonTouchedDown;
- (void)airplayButtonTouchedUpInside;
- (void)airplayButtonTouchedUpOutside;
- (void)airplayButtonTouchFailed;
@end

@interface ALAirplayView : MPVolumeView

@property (nonatomic, weak) id<ALAirplayViewDelegate> delegate;

@end
