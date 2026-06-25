//
//  qrCodeOnScreen.m
//  ssrMac
//
//  Created by ssrlive on 1/25/18.
//  Copyright © 2018 ssrlive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

#import "qrCodeOnScreen.h"

@implementation qrCodeOnScreen

+ (CGImageRef)newScreenshotForDisplay:(CGDirectDisplayID)displayID index:(unsigned int)displayIndex {
    if (@available(macOS 15.2, *)) {
        __block CGImageRef capturedImage = NULL;
        __block NSError *captureError = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        [SCScreenshotManager captureImageInRect:CGDisplayBounds(displayID) completionHandler:^(CGImageRef  _Nullable image, NSError * _Nullable error) {
            if (image) {
                capturedImage = CGImageRetain(image);
            }
            captureError = error;
            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
        if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
            NSLog(@"Timed out capturing display screenshot for QR scan; display index: %u", displayIndex);
            return NULL;
        }

        if (captureError) {
            NSLog(@"Failed to capture display screenshot for QR scan; display index: %u, error: %@", displayIndex, captureError);
            return NULL;
        }

        if (!capturedImage) {
            NSLog(@"Screen capture returned no image for QR scan; display index: %u", displayIndex);
        }

        return capturedImage;
    }

    NSLog(@"Screen QR scan requires macOS 15.2 or later");
    return NULL;
}

+ (NSArray<NSURL *> *) scan {
    // displays[] Quartz display ID's
    CGDirectDisplayID   *displays = nil;
    
    CGError             err = CGDisplayNoErr;
    CGDisplayCount      dspCount = 0;
    
    // How many active displays do we have?
    err = CGGetActiveDisplayList(0, NULL, &dspCount);
    
    // If we are getting an error here then their won't be much to display.
    if(err != CGDisplayNoErr) {
        NSLog(@"Could not get active display count (%d)\n", err);
        return nil;
    }
    
    // Allocate enough memory to hold all the display IDs we have.
    displays = calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
    
    // Get the list of active displays
    err = CGGetActiveDisplayList(dspCount, displays, &dspCount);
    
    // More error-checking here.
    if (err != CGDisplayNoErr) {
        NSLog(@"Could not get active display list (%d)\n", err);
        free(displays);
        return nil;
    }
    
    NSMutableArray* foundSSUrls = [NSMutableArray array];
    
    CIDetector *detector =
    [CIDetector detectorOfType:@"CIDetectorTypeQRCode"
                       context:nil
                       options:@{ CIDetectorAccuracy:CIDetectorAccuracyHigh }];
    
    for (unsigned int displaysIndex = 0; displaysIndex < dspCount; displaysIndex++) {
        CGImageRef image = [self newScreenshotForDisplay:displays[displaysIndex] index:displaysIndex];
        if (!image) {
            continue;
        }

        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image]];
        for (CIQRCodeFeature *feature in features) {
            NSString *messageString = feature.messageString;
            if ([messageString hasPrefix:@"ss://"] || [messageString hasPrefix:@"ssr://"]) {
                NSURL *url = [NSURL URLWithString:messageString];
                if (url) {
                    [foundSSUrls addObject:url];
                    NSLog(@"Detected supported QR code during screen scan; display index: %u, payload length: %lu", displaysIndex, (unsigned long)messageString.length);
                } else {
                    NSLog(@"Failed to parse supported QR code during screen scan; display index: %u, payload length: %lu", displaysIndex, (unsigned long)messageString.length);
                }
            } else if (messageString.length) {
                NSLog(@"Ignoring unsupported QR code during screen scan; display index: %u, payload length: %lu", displaysIndex, (unsigned long)messageString.length);
            }
        }
        CGImageRelease(image);
    }

    free(displays);

    return foundSSUrls;
}

@end
