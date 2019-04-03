//
//  CYUSBMuxdDefind.h
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//

typedef enum : uint32_t {
    USBMuxPacketTypeResult = 1,
    USBMuxPacketTypeConnect = 2,
    USBMuxPacketTypeListen = 3,
    USBMuxPacketTypeDeviceAdd = 4,
    USBMuxPacketTypeDeviceRemove = 5,
    // ? = 6,
    // ? = 7,
    USBMuxPacketTypePlistPayload = 8,
} USBMuxPacketType;

typedef enum : uint32_t {
    USBMuxPacketProtocolBinary = 0,
    USBMuxPacketProtocolPlist = 1,
} USBMuxPacketProtocol;

typedef enum : uint32_t{
    USBMuxReplyCodeOK = 0,
    USBMuxReplyCodeBadCommand = 1,
    USBMuxReplyCodeBadDevice = 2,
    USBMuxReplyCodeConnectionRefused = 3,
    // ? = 4,
    // ? = 5,
    USBMuxReplyCodeBadVersion = 6,
}USBMuxReplyCode;

#pragma pack (1)

struct Usbmux_packet {
    uint32_t size;
    USBMuxPacketProtocol protocol;
    USBMuxPacketType type;
    uint32_t tag;
    char data[0];
};

#pragma pack ()
