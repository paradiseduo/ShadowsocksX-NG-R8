//
//  NetSpeedMonitor.h
//  Test
//
//  Created by ParadiseDuo on 2020/3/22.
//  Copyright © 2020 ParadiseDuo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NetSpeedMonitor : NSObject
+ (NSString *)primaryInterface;
- (void)timeInterval:(NSTimeInterval)interval downloadAndUploadSpeed:(void (^)(double, double))speeds;
@end

NS_ASSUME_NONNULL_END
