//
//  TUAppDelegate.m
//  KinectTEST1
//
//  Created by Tatsuo Unemi on 2013/08/13.
//  Copyright (c) 2013, Tatsuo Unemi. All rights reserved.
//

#import "TUAppDelegate.h"

static int got_rgb = 0, got_depth = 0;
static uint16_t *depth_back, *depth_front;
static uint8_t *rgb_back, *rgb_front;
static MyView *myView;
static NSLock *imgLock;
static NSInteger depthTh = 1280;

static void err_msg(NSString *msg) {
	NSRunCriticalAlertPanel(@"Error in KinectTEST1", msg, @"OK", nil, nil);
}
static void depth_cb(freenect_device *dev, void *v_depth, uint32_t timestamp) {
	[imgLock lock];
	depth_back = depth_front;
	freenect_set_depth_buffer(dev, depth_back);
	depth_front = (uint16_t *)v_depth;
	got_depth++;
	if (got_rgb) [myView setNeedsDisplay:YES];
	[imgLock unlock];
}
static void rgb_cb(freenect_device *dev, void *rgb, uint32_t timestamp) {
	[imgLock lock];
	rgb_back = rgb_front;
	freenect_set_video_buffer(dev, rgb_back);
	rgb_front = (uint8_t*)rgb;
	got_rgb++;
	if (got_depth) [myView setNeedsDisplay:YES];
	[imgLock unlock];
}
@implementation TUAppDelegate
- (void)dealloc {
	[imgRep release];
	[imgLock release];
    [super dealloc];
}
- (NSBitmapImageRep *)maskedImage {
	if (!imgRep) return nil;
	[imgLock lock];
	unsigned char *buf = [imgRep bitmapData];
	memcpy(buf, rgb_front, 640*480*3);
	got_depth = got_rgb = 0;
	[imgLock unlock];
	for (int i = 0; i < 640*480; i ++) {
		if (depth_front[i] > depthTh) memset(&buf[i*3], 0, 3);
		else if (depth_front[i] < 1) memset(&buf[i*3], 0, 3);
	}
	return imgRep;
}
- (void)freenectThread:(id)arg {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	freenectThread = [[NSThread currentThread] retain];
	freenect_set_depth_callback(f_dev, depth_cb);
	freenect_set_video_callback(f_dev, rgb_cb);
	freenect_set_video_mode(f_dev, freenect_find_video_mode(
		FREENECT_RESOLUTION_MEDIUM, FREENECT_VIDEO_RGB));
	freenect_set_depth_mode(f_dev, freenect_find_depth_mode(
		FREENECT_RESOLUTION_MEDIUM, FREENECT_DEPTH_REGISTERED));
	freenect_set_video_buffer(f_dev, rgb_back);
	freenect_set_depth_buffer(f_dev, depth_back);
	if (freenect_start_video(f_dev))
		{ err_msg(@"Could not start video."); [NSApp terminate:nil]; };
	if (freenect_start_depth(f_dev))
		{ err_msg(@"Could not start depth."); [NSApp terminate:nil]; };
	freenect_set_led(f_dev, LED_RED);
	unsigned long count = 0;
	while(!die && freenect_process_events(f_ctx) >= 0) if (count++ > 600) {
		count = 0;
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
	}
	freenect_stop_depth(f_dev);
	freenect_stop_video(f_dev);
	freenect_set_led(f_dev, LED_GREEN);
	freenect_close_device(f_dev);
	freenect_shutdown(f_ctx);
	[pool release];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	depth_back = (uint16_t*)malloc(640*480*sizeof(uint16_t));
	depth_front = (uint16_t*)malloc(640*480*sizeof(uint16_t));
	rgb_back = (uint8_t*)malloc(640*480*3);
	rgb_front = (uint8_t*)malloc(640*480*3);
	uint8_t *imgBuf = (uint8_t*)malloc(640*480*3);
	imgRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:(unsigned char *[]){imgBuf}
		pixelsWide:640 pixelsHigh:480 bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO
		colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:640*3 bitsPerPixel:24];
	if (!imgRep) { err_msg(@"Could not allocate NSBitmapImageRep."); [NSApp terminate:nil]; }
	if (freenect_init(&f_ctx, NULL) < 0)
		{ err_msg(@"Could not initialize FREENECT."); [NSApp terminate:nil]; }
//	freenect_set_log_level(f_ctx, FREENECT_LOG_DEBUG);
	freenect_select_subdevices(f_ctx, FREENECT_DEVICE_CAMERA|FREENECT_DEVICE_MOTOR);
	if (freenect_num_devices(f_ctx) < 1)
		{ err_msg(@"Could find no Kinect device."); [NSApp terminate:nil]; }
	if (freenect_open_device(f_ctx, &f_dev, 0) < 0)
		{ err_msg(@"Could not open Kinect device."); [NSApp terminate:nil]; }
	if (freenect_set_led(f_dev, LED_GREEN))
		{ err_msg(@"Could not change LED color."); [NSApp terminate:nil]; }
	if (!(myView = self.view))
		{ err_msg(@"Could not find view object."); [NSApp terminate:nil]; }
	[dSlider setIntegerValue:depthTh];
	[dDigits setIntegerValue:depthTh];
	freenect_update_tilt_state(f_dev);
	freenect_angle = freenect_get_tilt_degs(freenect_get_tilt_state(f_dev));
	[tSlider setDoubleValue:freenect_angle];
	[tDigits setDoubleValue:freenect_angle];
	imgLock = [[NSLock alloc] init];
	[NSThread detachNewThreadSelector:@selector(freenectThread:) toTarget:self withObject:nil];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	die = YES;
	do { usleep(100000); }
	while ([freenectThread isExecuting]);
	free(depth_back);
	free(depth_front);
	free(rgb_back);
	free(rgb_front);
}
- (IBAction)changeDepthTh:(id)sender {
	depthTh = [dSlider doubleValue];
	[dDigits setIntegerValue:depthTh];
}
- (IBAction)changeTilt:(id)sender {
	double v = round([tSlider doubleValue]);
	if (v == freenect_angle) return;
	[tDigits setDoubleValue:(freenect_angle = v)];
	freenect_set_tilt_degs(f_dev, freenect_angle);
}
@end

@implementation MyView
- (void)drawRect:(NSRect)dirtyRect {
	[[(TUAppDelegate *)[NSApp delegate] maskedImage]
		drawInRect:[self bounds] fromRect:(NSRect){0,0,586,440}
		operation:NSCompositeCopy fraction:1. respectFlipped:NO hints:@{}];
}
@end
