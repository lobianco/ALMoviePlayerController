//
//  ALButton.h
//  ALMoviePlayerController
//
//  Created by Anthony Lobianco on 10/8/13.
//  Copyright (c) 2013 Anthony Lobianco. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ALButtonDelegate <NSObject>
@optional
- (void)buttonTouchedDown:(UIButton *)button;
- (void)buttonTouchedUpOutside:(UIButton *)button;
- (void)buttonTouchCancelled:(UIButton *)button;
@end

@interface ALButton : UIButton

@property (nonatomic, weak) id<ALButtonDelegate> delegate;

@end
