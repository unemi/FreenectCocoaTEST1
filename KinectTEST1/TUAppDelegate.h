//
//  TUAppDelegate.h
//  KinectTEST1
//
//  Created by Tatsuo Unemi on 2013/08/13.
//  Copyright (c) 2013, Tatsuo Unemi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <libfreenect/libfreenect.h>

@interface MyView : NSView
@end

@interface TUAppDelegate : NSObject <NSApplicationDelegate> {
	IBOutlet NSSlider *dSlider;
	IBOutlet NSTextField *dDigits;
	IBOutlet NSSlider *tSlider;
	IBOutlet NSTextField *tDigits;
	NSBitmapImageRep *imgRep;
	freenect_context *f_ctx;
	freenect_device *f_dev;
	double freenect_angle;
	NSThread *freenectThread;
	BOOL die;
}
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet MyView *view;
- (IBAction)changeDepthTh:(id)sender;
- (IBAction)changeTilt:(id)sender;
@end
