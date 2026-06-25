//
//  QRCodeWindowController.m
//  shadowsocks
//
//  Created by clowwindy on 10/12/14.
//  Copyright (c) 2014 clowwindy. All rights reserved.
//

#import "SWBQRCodeWindowController.h"
#import <CoreImage/CoreImage.h>

@interface SWBQRCodeWindowController ()

- (void)updateQRCodeImage;

@end

@implementation SWBQRCodeWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    [self updateQRCodeImage];
}

- (void)setQrCode:(NSString *)qrCode {
    _qrCode = [qrCode copy];
    if (self.isWindowLoaded) {
        [self updateQRCodeImage];
    }
}

- (void)updateQRCodeImage {
    NSImage *image = [[self class] generateQRCodeImageForString:self.qrCode size:NSMakeSize(256., 256.)];
    self.imageView.image = image;
}

+ (NSImage *)generateQRCodeImageForString:(NSString *)string size:(NSSize)size {
    if (string.length == 0) {
        NSLog(@"Skipping QR image generation: empty payload");
        return nil;
    }

    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (!qrFilter) {
        NSLog(@"Failed to create QR filter for payload length %lu", (unsigned long)string.length);
        return nil;
    }

    [qrFilter setValue:data forKey:@"inputMessage"];
    [qrFilter setValue:@"H" forKey:@"inputCorrectionLevel"];

    CIImage *qrImage = qrFilter.outputImage;
    CIFilter *colorFilter = [CIFilter filterWithName:@"CIFalseColor"];
    if (colorFilter) {
        [colorFilter setValue:qrImage forKey:kCIInputImageKey];
        [colorFilter setValue:[CIColor colorWithRed:0 green:0 blue:0] forKey:@"inputColor0"];
        [colorFilter setValue:[CIColor colorWithRed:1 green:1 blue:1] forKey:@"inputColor1"];
        qrImage = colorFilter.outputImage ?: qrImage;
    }

    CGRect extent = CGRectIntegral(qrImage.extent);
    if (CGRectIsEmpty(extent) || size.width <= 0 || size.height <= 0) {
        NSLog(@"Failed to create QR image: invalid output extent for payload length %lu", (unsigned long)string.length);
        return nil;
    }

    CGFloat scale = MIN(size.width / CGRectGetWidth(extent), size.height / CGRectGetHeight(extent));
    size_t width = (size_t)CGRectGetWidth(extent) * scale;
    size_t height = (size_t)CGRectGetHeight(extent) * scale;

    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:qrImage fromRect:extent];
    if (!cgImage) {
        NSLog(@"Failed to render QR image for payload length %lu", (unsigned long)string.length);
        return nil;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);

    if (!bitmapContext) {
        CGImageRelease(cgImage);
        NSLog(@"Failed to allocate QR bitmap context for payload length %lu", (unsigned long)string.length);
        return nil;
    }

    CGContextSetInterpolationQuality(bitmapContext, kCGInterpolationNone);
    CGContextScaleCTM(bitmapContext, scale, scale);
    CGContextDrawImage(bitmapContext, extent, cgImage);

    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);
    CGImageRelease(cgImage);

    if (!scaledImage) {
        NSLog(@"Failed to create scaled QR image for payload length %lu", (unsigned long)string.length);
        return nil;
    }

    NSImage *image = [[NSImage alloc] initWithCGImage:scaledImage size:size];
    CGImageRelease(scaledImage);

    return image;
}

- (IBAction)copyToPasteboardClicked:(NSButton *)sender {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];

    NSMutableArray *objects = [NSMutableArray array];
    if (self.qrCode) {
        [objects addObject:self.qrCode];
    }

    NSImage *image = self.imageView.image ?: [[self class] generateQRCodeImageForString:self.qrCode size:NSMakeSize(256., 256.)];
    if (image) {
        [objects addObject:image];
    }

    BOOL success = [pasteboard writeObjects:objects];
    if (!success) {
        NSLog(@"Failed to copy QR payload to pasteboard; payload length: %lu, image available: %@", (unsigned long)self.qrCode.length, image ? @"YES" : @"NO");
    }
}

@end
