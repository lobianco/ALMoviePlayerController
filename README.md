# ALMoviePlayerController

ALMoviePlayerController is a drop-in replacement for MPMoviePlayerController that exposes the UI elements and allows for maximum customization.

### Preview

**ALMoviePlayerController on iPad, iOS 7.0**

![Preview1](http://alobi.github.io/ALMoviePlayerController/screenshots/screenshot2.png)

**ALMoviePlayerController on iPhone, iOS 6.1**

![Preview2](http://alobi.github.io/ALMoviePlayerController/screenshots/screenshot1.png)

### Features

* Drop-in replacement for ```MPMoviePlayerController```
* Many different customization options, or you can go with the stock Apple look
* Portrait and landscape support
* Universal (iPhone and iPad) support
* iOS 5.0 - iOS 7 support
* Lightweight, stable component with small memory footprint

## Installation

Installation is easy.

### Cocoapods

1. Add ```pod 'ALMoviePlayerController', '~>0.2.0'``` to your Podfile
2. ```#import <ALMoviePlayerController/ALMoviePlayerController.h>``` in your view of choice

### Manually

1. [Download the ZIP](https://github.com/alobi/ALMoviePlayerController/archive/master.zip) from Github and copy the ALMoviePlayerController directory to your project
2. Link the ```QuartzCore.framework``` and ```MediaPlayer.framework``` library in your project's Build Phases
3. ```#import "ALMoviePlayerController.h"``` in your view of choice

### Tested Environments

ALMoviePlayerController has been tested to work on iOS 5.0, 5.1 and 6.0 (simulator), iOS 6.1 (device), and iOS 7.0 (device). ALMoviePlayerController requires that ARC be enabled.

## Example Usage

The process is as follows:

1. Create an ```ALMoviePlayerController``` movie player and assign yourself as its delegate
2. Create the ```ALMoviePlayerControls``` controls (and optionally customize)
3. Assign the controls to the movie player
4. Set the movie player's ```contentURL```, which will start playing the movie
5. On device rotation, adjust movie player frame if it's not in fullscreen (when in fullscreen, rotation is handled automatically)
6. Implement ```ALMoviePlayerController``` delegate methods 

**In code:**

```objc
@property (nonatomic, strong) ALMoviePlayerController *moviePlayer;

//...

// create a movie player
self.moviePlayer = [[ALMoviePlayerController alloc] initWithFrame:self.view.frame];
self.moviePlayer.delegate = self; //IMPORTANT!
    
// create the controls
ALMoviePlayerControls *movieControls = [[ALMoviePlayerControls alloc] initWithMoviePlayer:self.moviePlayer style:ALMoviePlayerControlsStyleDefault];

// optionally customize the controls here...
/* 
[movieControls setBarColor:[UIColor colorWithRed:195/255.0 green:29/255.0 blue:29/255.0 alpha:0.5]];
[movieControls setTimeRemainingDecrements:YES];
[movieControls setFadeDelay:2.0];
[movieControls setBarHeight:100.f];
[movieControls setSeekRate:2.f];
 */
    
// assign the controls to the movie player
[self.moviePlayer setControls:movieControls];

// add movie player to your view
[self.view addSubview:self.moviePlayer.view];
    
//set contentURL (this will automatically start playing the movie)
[self.moviePlayer setContentURL:[NSURL URLWithString:@"http://archive.org/download/WaltDisneyCartoons-MickeyMouseMinnieMouseDonaldDuckGoofyAndPluto/WaltDisneyCartoons-MickeyMouseMinnieMouseDonaldDuckGoofyAndPluto-HawaiianHoliday1937-Video.mp4"]];
```

**On rotation:**

```objc
if (!self.moviePlayer.isFullscreen) {
    [self.moviePlayer setFrame:frame];
    //"frame" is whatever the movie player's frame should be at that given moment
}
```

**Note:** you MUST use ```[ALMoviePlayerController setFrame:]``` to adjust frame, NOT ```[ALMoviePlayerController.view setFrame:]```

### Delegate methods

```objc
@required
- (void)moviePlayerWillMoveFromWindow;
```

```objc
@optional
- (void)movieTimedOut;
```

**Note:** ```moviePlayerWillMoveFromWindow``` is required for fullscreen mode to work properly. It should be used to re-add the movie player to your view controller's view (because during the transition to fullscreen, it was moved to ```[[UIApplication sharedApplication] keyWindow]```. 

Your code might look something like this:

```objc
- (void)moviePlayerWillMoveFromWindow {
    if (![self.view.subviews containsObject:self.moviePlayer.view])
        [self.view addSubview:self.moviePlayer.view];
    
    [self.moviePlayer setFrame:frame];
}
```

### Controls Properties

ALMoviePlayerControls has the following editable properties:

```objc
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
```

### Controls Styles

```objc
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
```

## Suggestions?

If you have any suggestions, let me know! If you find any bugs, please open a new issue.

## Contact Me

You can reach me anytime at the addresses below. If you use the library, feel free to give me a shoutout on Twitter to let me know how you like it. I'd love to hear your thoughts. 

Github: [alobi](https://github.com/alobi) <br>
Twitter: [@lobi4nco](https://twitter.com/lobi4nco) <br>
Email: [anthony@lobian.co](mailto:anthony@lobian.co) 

## Credits & License

ALMoviePlayerController is developed and maintained by Anthony Lobianco ([@lobi4nco](https://twitter.com/lobi4nco)). Licensed under the MIT License. Basically, I would appreciate attribution if you use it.

Enjoy!

(⌐■_■)
