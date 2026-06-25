//
//  QRCodeWindowController.h
//  shadowsocks
//
//  Created by clowwindy on 10/12/14.
//  Copyright (c) 2014 clowwindy. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SWBQRCodeWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet NSImageView *imageView;
@property (nonatomic, copy) NSString *qrCode;

@end
