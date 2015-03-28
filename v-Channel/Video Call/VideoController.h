//
//  VideoController.h
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "Common.h"

@protocol VideoControllerDelegate <NSObject>

- (void)videoSendCommand:(enum Command)command withData:(NSData*)data;

@end

@interface VideoController : UIViewController

@property (weak, nonatomic) id<VideoControllerDelegate> delegate;

- (void)shutdown;
- (void)videoReceiveCommand:(enum Command)command withData:(NSData*)data;

@end
