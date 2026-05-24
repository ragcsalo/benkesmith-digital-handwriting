#import <Cordova/CDV.h>

@interface DigitalHandWriting : CDVPlugin
// The entry point method targeted by Cordova's exec bridge
- (void)recognize:(CDVInvokedUrlCommand*)command;
@end
