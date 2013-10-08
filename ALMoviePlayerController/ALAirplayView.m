//
//  ALAirplayView.m
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import "ALAirplayView.h"

@interface ALAirplayView ()

@property (nonatomic, strong) UILongPressGestureRecognizer *pressGesture;

@end

@implementation ALAirplayView

- (id)init {
    if ( self = [super init] ) {
        [self setShowsRouteButton:YES];
        [self setShowsVolumeSlider:NO];
        
        _pressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressed:)];
        _pressGesture.minimumPressDuration = 0.01;
        _pressGesture.cancelsTouchesInView = NO;
        [self addGestureRecognizer:_pressGesture];
    }
    return self;
}

- (void)pressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if ([self.delegate respondsToSelector:@selector(airplayButtonTouchedDown)]) {
            [self.delegate airplayButtonTouchedDown];
        }
    }
    else if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint point = [gesture locationInView:self];
        if (CGRectContainsPoint((CGRect){.origin=CGPointMake(0, 0), .size=self.frame.size}, point)) {
            if ([self.delegate respondsToSelector:@selector(airplayButtonTouchedUpInside)]) {
                [self.delegate airplayButtonTouchedUpInside];
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(airplayButtonTouchedUpOutside)]) {
                [self.delegate airplayButtonTouchedUpOutside];
            }
        }
    }
    else if (gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        if ([self.delegate respondsToSelector:@selector(airplayButtonTouchFailed)]) {
            [self.delegate airplayButtonTouchFailed];
        }
    }
}

@end
