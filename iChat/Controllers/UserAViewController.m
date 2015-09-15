//
//  UserAViewController.m
//  iChat
//
//  Created by yz on 15/9/13.
//  Copyright (c) 2015年 DeviceOne. All rights reserved.
//

#import "UserAViewController.h"
#import "DefineService.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface UserAViewController()<CBCentralManagerDelegate,CBPeripheralDelegate>

- (IBAction)btnBackClick:(UIButton *)sender;
- (IBAction)btnSendClick:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UITextView *textFiled;

@property (strong, nonatomic)CBCentralManager* centralManager;
@property (strong, nonatomic)CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic)NSMutableData *data;
@end

@implementation UserAViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
    UITapGestureRecognizer *viewTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(viewTap:)];
    [self.view addGestureRecognizer:viewTap];
    _data = [[NSMutableData alloc]init];
}
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}
- (IBAction)btnBackClick:(UIButton *)sender {
    
}

- (IBAction)btnSendClick:(UIButton *)sender {
    
}
- (void)viewTap:(UITapGestureRecognizer *)recognizer
{
    [self.view endEditing:YES];
}
#pragma mark - 中心设备管理器代理方法
//蓝牙状态发生改变回调,此方法必须实现
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            [central scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        }
            break;
            
        default:
            NSLog(@"此设备蓝牙没有打开或者不支持蓝牙4.0");
            break;
    }
}
//扫描到外围设备回调
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    //获得合适rssi范围的外围设备
    if (RSSI.integerValue > -15) {
        return;
    }
    if (RSSI.integerValue < -35) {
        return;
    }
    if (self.discoveredPeripheral != peripheral) {
        self.discoveredPeripheral = peripheral;//这里需要本地保存
    }
    [self.centralManager connectPeripheral:peripheral options:nil ];//连接发现的外围设备
}
//连接外围设备失败回调
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"连接设备失败：%@",[error localizedDescription]);
    //清理
    [self clean];
}

//连接外围设备成功回调
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"连接设备成功");
    [self.centralManager stopScan];
    [self.data setLength:0];
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
}
#pragma mark - 外围设备代理方法
//连接到外围设备服务后回调
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"连接服务出错:%@",[error localizedDescription]);
        [self clean];
    }
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kCharacterUUID]] forService:service];
    }
}
//发现某个服务的某个特征后的回调
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"连接特征出错：%@",[error localizedDescription]);
        [self clean];
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacterUUID]]) {
            
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }

}
//某个特征值被跟新后的回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"%@",[error localizedDescription]);
    }
    NSString *stringWithData = [[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"接收到数据：%@",stringWithData);
    //结束符
    if ([stringWithData isEqualToString:kEndFlag]) {
        [self.textFiled setText:[[NSString alloc]initWithData:self.data encoding:NSUTF8StringEncoding]];
        
//        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
//        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    else
    {
        [self.data appendData:characteristic.value];
    }
}
//特征值状态发生变化回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"%@",[error localizedDescription]);
    }
    if (characteristic.isNotifying)
    {
        NSLog(@"Notification began on %@", characteristic);
    }
    else
    {
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

#pragma mark - 私有方法
- (void)clean
{
    // Don't do anything if we're not connected
    if (!self.discoveredPeripheral.state) {
        return;
    }
    
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacterUUID]]) {
                        if (characteristic.isNotifying) {
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}
@end












