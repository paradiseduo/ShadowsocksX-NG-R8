//
//  NetSpeedMonitor.m
//  Test
//
//  Created by YouShaoduo on 2020/3/22.
//  Copyright © 2020 YouShaoduo. All rights reserved.
//

#import "NetSpeedMonitor.h"
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <net/route.h>
#import <SystemConfiguration/SCDynamicStore.h>

@interface NetSpeedMonitor()
@property(nonatomic, copy) NSMutableDictionary * lastData;
@property(nonatomic) size_t sysctlBufferSize;
@property(nonatomic) uint8_t *sysctlBuffer;
@end

@implementation NetSpeedMonitor
- (instancetype)init {
    if (self = [super init]) {
        self.lastData = [[NSMutableDictionary alloc] init];
        self.sysctlBufferSize = 0;
        self.sysctlBuffer = malloc(self.sysctlBufferSize);
        [self netStats];
        return self;
    }
    return nil;
}

- (NSMutableDictionary *)netStats {
    int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST,0};
    size_t currentSize = 0;
    if (sysctl(mib, 6, NULL, &currentSize, NULL, 0) !=  0) {
        return nil;
    }
    
    if (!self.sysctlBuffer || (currentSize > self.sysctlBufferSize)) {
        if (self.sysctlBuffer) {
            free(self.sysctlBuffer);
        }
        self.sysctlBufferSize = 0;
        self.sysctlBuffer = malloc(currentSize);
        if (!self.sysctlBuffer) {
            return nil;
        }
        self.sysctlBufferSize = currentSize;
    }
    
    if (sysctl(mib, 6, self.sysctlBuffer, &currentSize, NULL, 0) != 0) {
        return nil;
    }
    
    uint8_t *currentData = self.sysctlBuffer;
    uint8_t *currentDataEnd = self.sysctlBuffer + currentSize;
    NSMutableDictionary    *newStats = [NSMutableDictionary dictionary];
    while (currentData < currentDataEnd) {
        // Expecting interface data
        struct if_msghdr *ifmsg = (struct if_msghdr *)currentData;
        if (ifmsg->ifm_type != RTM_IFINFO) {
            currentData += ifmsg->ifm_msglen;
            continue;
        }
        // Must not be loopback
        if (ifmsg->ifm_flags & IFF_LOOPBACK) {
            currentData += ifmsg->ifm_msglen;
            continue;
        }
        // Only look at link layer items
        struct sockaddr_dl *sdl = (struct sockaddr_dl *)(ifmsg + 1);
        if (sdl->sdl_family != AF_LINK) {
            currentData += ifmsg->ifm_msglen;
            continue;
        }
        // Build the interface name to string so we can key off it
        NSString *interfaceName = [[NSString alloc] initWithBytes:sdl->sdl_data length:sdl->sdl_nlen encoding:NSASCIIStringEncoding];
        if (!interfaceName) {
            currentData += ifmsg->ifm_msglen;
            continue;
        }
        // Load in old statistics for this interface
        NSDictionary *oldStats = [self.lastData objectForKey:interfaceName];
        
        if (oldStats && (ifmsg->ifm_flags & IFF_UP)) {
            // Non-PPP data is sized at u_long, which means we need to deal
            // with 32-bit and 64-bit differently
            uint64_t lastTotalIn = [[oldStats objectForKey:@"totalin"] unsignedLongLongValue];
            uint64_t lastTotalOut = [[oldStats objectForKey:@"totalout"] unsignedLongLongValue];
            // New totals
            uint64_t totalIn = 0, totalOut = 0;
            // Values are always 32 bit and can overflow
            uint32_t lastifIn = [[oldStats objectForKey:@"ifin"] unsignedIntValue];
            uint32_t lastifOut = [[oldStats objectForKey:@"ifout"] unsignedIntValue];
            if (lastifIn > ifmsg->ifm_data.ifi_ibytes) {
                totalIn = lastTotalIn + ifmsg->ifm_data.ifi_ibytes + UINT_MAX - lastifIn + 1;
            } else {
                totalIn = lastTotalIn + (ifmsg->ifm_data.ifi_ibytes - lastifIn);
            }
            if (lastifOut > ifmsg->ifm_data.ifi_obytes) {
                totalOut = lastTotalOut + ifmsg->ifm_data.ifi_obytes + UINT_MAX - lastifOut + 1;
            } else {
                totalOut = lastTotalOut + (ifmsg->ifm_data.ifi_obytes - lastifOut);
            }
            // New deltas (64-bit overflow guard, full paranoia)
            uint64_t deltaIn = (totalIn > lastTotalIn) ? (totalIn - lastTotalIn) : 0;
            uint64_t deltaOut = (totalOut > lastTotalOut) ? (totalOut - lastTotalOut) : 0;
            [newStats setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithUnsignedInt:ifmsg->ifm_data.ifi_ibytes],
                        @"ifin",
                        [NSNumber numberWithUnsignedInt:ifmsg->ifm_data.ifi_obytes],
                        @"ifout",
                        [NSNumber numberWithUnsignedLongLong:deltaIn],
                        @"deltain",
                        [NSNumber numberWithUnsignedLongLong:deltaOut],
                        @"deltaout",
                        [NSNumber numberWithUnsignedLongLong:totalIn],
                        @"totalin",
                        [NSNumber numberWithUnsignedLongLong:totalOut],
                        @"totalout",
                        nil]
                    forKey:interfaceName];
        } else {
            [newStats setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            // Paranoia, is this where the neg numbers came from?
                            [NSNumber numberWithUnsignedInt:ifmsg->ifm_data.ifi_ibytes],
                            @"ifin",
                            [NSNumber numberWithUnsignedInt:ifmsg->ifm_data.ifi_obytes],
                            @"ifout",
                            [NSNumber numberWithUnsignedLongLong:ifmsg->ifm_data.ifi_ibytes],
                            @"totalin",
                            [NSNumber numberWithUnsignedLongLong:ifmsg->ifm_data.ifi_obytes],
                            @"totalout",
                            nil]
            forKey:interfaceName];
        }
        // Continue on
        currentData += ifmsg->ifm_msglen;
    }
    // Store and return
    self.lastData = [[NSMutableDictionary alloc] initWithDictionary:newStats];
    return newStats;
}

+ (NSString *)primaryInterface {
    SCDynamicStoreRef storeRef = SCDynamicStoreCreate(NULL, (CFStringRef)@"FindCurrentInterfaceIpMac", NULL, NULL);
    CFPropertyListRef global = SCDynamicStoreCopyValue (storeRef,CFSTR("State:/Network/Global/IPv4"));
    NSString *primaryInterface = [(__bridge NSDictionary *)global valueForKey:@"PrimaryInterface"];
    CFRelease(storeRef);
    CFRelease(global);
    if (primaryInterface) {
        return primaryInterface;
    }
    return @"en0";
}

- (void)downloadAndUploadSpeed:(void (^)(double, double))speeds {
    double down = 0.0, up = 0.0;
    NSMutableDictionary * result = [self netStats];
    NSString * primaryInterface = [NetSpeedMonitor primaryInterface];
    NSDictionary * dic = result[primaryInterface];
    if (dic) {
        NSNumber * deltain = dic[@"deltain"];
        NSNumber * deltaout = dic[@"deltaout"];
        //这里返回的是字节，我把他转成了最小单位为kb，右移十位相当于除以1024，位运算速度快
        down = deltain.intValue >> 10;
        up = deltaout.intValue >> 10;
    }
    speeds(down, up);
}

- (void)dealloc {
    if (self.sysctlBuffer) {
        free(self.sysctlBuffer);
    }
}
@end
