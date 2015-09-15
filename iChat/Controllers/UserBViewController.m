//
//  UserBViewController.m
//  iChat
//
//  Created by yz on 15/9/13.
//  Copyright (c) 2015年 DeviceOne. All rights reserved.
//

#import "UserBViewController.h"
#import "DefineService.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface UserBViewController()<CBPeripheralManagerDelegate>
- (IBAction)btnBackClick:(UIButton *)sender;

- (IBAction)btnSendClick:(UIButton *)sender;

@property (weak, nonatomic) IBOutlet UITextView *textFiled;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *updateCharacteristic;
@property (strong, nonatomic) NSData                    *dataToSend;
@property (nonatomic, readwrite) NSInteger              sendDataIndex;
@end

@implementation UserBViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    _peripheralManager = [[CBPeripheralManager alloc]initWithDelegate:self queue:nil];
    UITapGestureRecognizer *viewTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(viewTap:)];
    [self.view addGestureRecognizer:viewTap];

}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.peripheralManager stopAdvertising];
}
- (void)viewTap:(UITapGestureRecognizer *)recognizer
{
    [self.view endEditing:YES];
}

- (IBAction)btnBackClick:(UIButton *)sender {
    
}

- (IBAction)btnSendClick:(UIButton *)sender {
    self.dataToSend = [self.textFiled.text dataUsingEncoding:NSUTF8StringEncoding];
    self.sendDataIndex = 0;
    [self sendData];
}
- (void)addService
{
    self.updateCharacteristic = [[CBMutableCharacteristic alloc]initWithType:[CBUUID UUIDWithString:kCharacterUUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    CBMutableService *updateService = [[CBMutableService alloc]initWithType:[CBUUID UUIDWithString:kServiceUUID] primary:YES];
    updateService.characteristics = @[self.updateCharacteristic];
    [self.peripheralManager addService:updateService];
}
#pragma mark - 外围设备管理器代理方法
//蓝牙状态改变回调
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
        {
            [self addService];
            
        }
            break;
            
        default:
            break;
    }
}
 -(void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (!error) {
        [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:kServiceUUID]] }];
    }
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
//    self.dataToSend = [@"dfas你好fafdasfdsadffadsfadfafdasfasfdasfbxvbvsdfgagasdfasdfadsdafdfsfdafdafafasfasdfadfdasfdsafas" dataUsingEncoding:NSUTF8StringEncoding];
//    self.sendDataIndex = 0;
//    [self sendData];
}
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    // Start sending again
    [self sendData];
}
- (void)sendData
{
    static BOOL sendingEOM = NO;
    
    if (sendingEOM) {
        
        BOOL didSend = [self.peripheralManager updateValue:[kEndFlag dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.updateCharacteristic onSubscribedCentrals:nil];
        if (didSend) {
            sendingEOM = NO;
        }
        return;
    }
    if (self.sendDataIndex >= self.dataToSend.length) {
        return;
    }
    BOOL didSend = YES;
    
    while (didSend) {
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        if (amountToSend > kNOTIFY_MTU) amountToSend = kNOTIFY_MTU;
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes+self.sendDataIndex length:amountToSend];
        
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.updateCharacteristic onSubscribedCentrals:nil];
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
        
        self.sendDataIndex += amountToSend;
        
        if (self.sendDataIndex >= self.dataToSend.length) {
            
            sendingEOM = YES;
            
            BOOL eomSent = [self.peripheralManager updateValue:[kEndFlag dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.updateCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                sendingEOM = NO;
            }
            
            return;
        }
    }
}


@end














