//
//  ALButton.m
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import "ALButton.h"

@implementation ALButton

- (id)init {
    if ( self = [super init] ) {
        self.adjustsImageWhenHighlighted = YES;
        self.showsTouchWhenHighlighted = YES;
        [self addTarget:self action:@selector(touchedDown:) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(touchedUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
        [self addTarget:self action:@selector(touchCancelled:) forControlEvents:UIControlEventTouchCancel];
    }
    return self;
}

- (void)touchedDown:(UIButton *)button {
    if ([self.delegate respondsToSelector:@selector(buttonTouchedDown)]) {
        [self.delegate buttonTouchedDown];
    }
}

- (void)touchedUpOutside:(UIButton *)button {
    if ([self.delegate respondsToSelector:@selector(buttonTouchedUpOutside)]) {
        [self.delegate buttonTouchedUpOutside];
    }
}

- (void)touchCancelled:(UIButton *)button {
    if ([self.delegate respondsToSelector:@selector(buttonTouchCancelled)]) {
        [self.delegate buttonTouchCancelled];
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
