//
//  BluetoothManager.m
//  RSBluetoothDemo
//
//  Created by CoDancer on 2018/9/12.
//  Copyright © 2018年 IOS. All rights reserved.
//

#import "BluetoothManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "Helper.h"
#import <UIKit/UIKit.h>
#import "NSData+Util.h"
#import "BluetoothCase-Swift.h"

#define SERVICE_UUID @"fff0"
#define Notify_UUID @"fff1"
#define WRITE_UUID @"fff3"

typedef void(^OCToothBlock)(void);
@interface BluetoothManager() <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *cMgr;
@property (nonatomic, strong) CBPeripheral *per;

@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;
@property (nonatomic, strong) NSMutableArray *mutPerArr;

@property (nonatomic, strong) OCToothBlock actionBlock;

@end

@implementation BluetoothManager

+ (instancetype)shareBlueInstanse
{
    static BluetoothManager *model = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        model = [[BluetoothManager alloc] init];
    });
    return model;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cMgr = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        _mutPerArr = [NSMutableArray array];
    }
    return self;
}

- (void)scanperpheral
{
    if ([self.cMgr isScanning]) {
        [self.cMgr stopScan];
    }
    [self.cMgr scanForPeripheralsWithServices:nil          // 通过某些服务筛选外设
                                      options:nil];        // dict,条件
}

- (void)scanDevice {
    
    [self.mutPerArr removeAllObjects];
    [self scanperpheral];
    
}

- (void)stopScan {
    
    [self.cMgr stopScan];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"%s, line = %d", __FUNCTION__, __LINE__);
    switch (central.state) {
        case CBManagerStateUnknown:
            NSLog(@">>>CBCentralManagerStateUnknown");
            break;
        case CBManagerStateResetting:
            NSLog(@">>>CBCentralManagerStateResetting");
            break;
        case CBManagerStateUnsupported:
            NSLog(@">>>CBCentralManagerStateUnsupported");
            break;
        case CBManagerStateUnauthorized:
            NSLog(@">>>CBCentralManagerStateUnauthorized");
            break;
        case CBManagerStatePoweredOff:
            NSLog(@">>>CBCentralManagerStatePoweredOff");
            break;
        case CBManagerStatePoweredOn:
            NSLog(@">>>CBCentralManagerStatePoweredOn");
            [self.cMgr scanForPeripheralsWithServices:nil options:nil];
            
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"%s, line = %d, per = %@, data = %@, rssi = %@", __FUNCTION__, __LINE__, peripheral, advertisementData, RSSI);
    if (![self.mutPerArr containsObject:peripheral] && peripheral.name != nil) {
        
        [self.mutPerArr addObject:peripheral];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BluetoothNoti" object:self.mutPerArr];
    }
}

- (void)connectPeriphralDidTouchCell:(CBPeripheral *)peripheral {
    
    self.per = peripheral;
    [self.cMgr connectPeripheral:self.per options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"%s, line = %d", __FUNCTION__, __LINE__);
    [self showAlertView:[NSString stringWithFormat:@">>>连接到名称为（%@）的设备-成功",peripheral.name] value:@""];
    
    [self.cMgr stopScan];
    self.per.delegate = self;
    [self.per discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%s, line = %d", __FUNCTION__, __LINE__);
    [self showAlertView:[NSString stringWithFormat:@">>>连接到名称为（%@）的设备-失败",peripheral.name] value:@""];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error) {
        for (CBService *service in peripheral.services) {
            
            NSLog(@"serviceUUID:%@", service.UUID.UUIDString);
            
            if ([SERVICE_UUID isEqualToString:[service.UUID.UUIDString lowercaseString]]) {
                //发现特定服务的特征值
                self.hasConnect = YES;
                [service.peripheral discoverCharacteristics:nil forService:service];
            }
        }
    }
}

// 外设发现service的特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    
    NSLog(@"peripheral discover :%@", peripheral);
    
    for (CBCharacteristic *characteristic in service.characteristics) {
                
        if ([[characteristic.UUID.UUIDString lowercaseString] containsString:Notify_UUID]) {

            self.hasConnect = YES;
            [self.per setNotifyValue:YES forCharacteristic:characteristic];
        }else if ([WRITE_UUID isEqualToString:[characteristic.UUID.UUIDString lowercaseString]]) {

            self.hasConnect = YES;
            self.writeCharacteristic = characteristic;
        }
    }
}

// 获取characteristic的值（监听指令）
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    //打印出characteristic的UUID和值
    //!注意，value的类型是NSData，具体开发时，会根据外设协议制定的方式去解析数据
    if (characteristic.value == nil) {
        return;
    }
    
    if ([Helper getTimeFromDevice:characteristic.value]) { //获取发送时间指令的通知
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GetDeviceTime" object:nil];
    }
}

- (void)writeData:(NSData *)data complete:(void (^)(void))completion {
    
    if (self.writeCharacteristic == nil) {
        
        [self showAlertView:@"请先确认连接蓝牙设备" value:@""];
        return;
    }
    
    self.actionBlock = completion;
    [self.per writeValue:data forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
}

// 写入成功
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    
    if (!error) {
        
        if (self.actionBlock) {
            
            self.actionBlock();
        }
        
    } else {
        
        NSLog(@"WriteVale Error = %@", error);
    }
}

- (void)showAlertView:(NSString *)message value:(NSString *)value {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:message
                                                    message:value
                                                   delegate:nil
                                          cancelButtonTitle:@"确定"
                                          otherButtonTitles:nil];
    [alert show];
}

@end
