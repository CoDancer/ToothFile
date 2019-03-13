//
//  BluetoothManager.h
//  RSBluetoothDemo
//
//  Created by CoDancer on 2018/9/12.
//  Copyright © 2018年 IOS. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;
@interface BluetoothManager : NSObject

@property (nonatomic, assign) BOOL hasConnect;

+ (instancetype)shareBlueInstanse;

- (void)scanDevice;

- (void)stopScan;

- (void)connectPeriphralDidTouchCell:(CBPeripheral *)peripheral;

- (void)writeData:(NSData *)data complete:(void (^)(void))completion;

@end
