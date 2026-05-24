#import "DigitalHandWriting.h"
#import <MLKitCommon/MLKitCommon.h>
#import <MLKitDigitalInkRecognition/MLKitDigitalInkRecognition.h>

@implementation DigitalHandWriting

- (void)recognize:(CDVInvokedUrlCommand*)command {
    // Execute on a background queue to ensure the UI and WebCore loops never stutter
    [self.commandDelegate runInBackground:^{
        @try {
            // 1. Extract arguments passed from the JS bridge
            NSDictionary *inkData = [command.arguments objectAtIndex:0];
            NSString *langTag = [command.arguments objectAtIndex:1];
            
            // Optional layout dimension hints (pass 0 from JS if unused)
            CGFloat canvasWidth = [[command.arguments objectAtIndex:2] floatValue];
            CGFloat canvasHeight = [[command.arguments objectAtIndex:3] floatValue];

            NSArray *strokesArray = [inkData objectForKey:@"strokes"];
            if (!strokesArray || strokesArray.count == 0) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No coordinate strokes to analyze."];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }

            // 2. Parse JS coordinates structure into native MLKInk objects
            NSMutableArray *mlkStrokes = [NSMutableArray array];
            
            for (NSDictionary *strokeDict in strokesArray) {
                NSArray *pointsArray = [strokeDict objectForKey:@"points"];
                NSMutableArray *mlkPoints = [NSMutableArray array];
                
                for (NSDictionary *pointDict in pointsArray) {
                    float x = [[pointDict objectForKey:@"x"] floatValue];
                    float y = [[pointDict objectForKey:@"y"] floatValue];
                    long long t = [[pointDict objectForKey:@"t"] longLongValue];
                    
                    MLKStrokePoint *strokePoint = [[MLKStrokePoint alloc] initWithX:x y:y timestamp:t];
                    [mlkPoints addObject:strokePoint];
                }
                
                MLKStroke *stroke = [[MLKStroke alloc] initWithPoints:mlkPoints];
                [mlkStrokes addObject:stroke];
            }

            MLKInk *ink = [[MLKInk alloc] initWithStrokes:mlkStrokes];

            // 3. Locate the corresponding language model identifier
            MLKDigitalInkRecognitionModelIdentifier *modelIdentifier = [MLKDigitalInkRecognitionModelIdentifier modelIdentifierFromLanguageTag:langTag];
            if (!modelIdentifier) {
                NSString *errStr = [NSString stringWithFormat:@"Unsupported iOS language tag: %@", langTag];
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errStr];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                return;
            }

            // 4. Initialize model references and the central download manager
            MLKDigitalInkRecognitionModel *model = [[MLKDigitalInkRecognitionModel alloc] initWithModelIdentifier:modelIdentifier];
            MLKModelManager *modelManager = [MLKModelManager modelManager];

            // Lambda execution block to run the final recognition logic
            void (^runRecognition)(void) = ^{
                MLKDigitalInkRecognizerOptions *options = [[MLKDigitalInkRecognizerOptions alloc] initWithModel:model];
                
                // Attach layout dimensional writing space if provided
                if (canvasWidth > 0 && canvasHeight > 0) {
                    options.writingArea = [[MLKWritingArea alloc] initWithWidth:canvasWidth height:canvasHeight];
                }
                
                MLKDigitalInkRecognizer *recognizer = [MLKDigitalInkRecognizer digitalInkRecognizerWithOptions:options];

                [recognizer recognizeInk:ink
                              completion:^(MLKDigitalInkRecognitionResult * _Nullable recognitionResult, NSError * _Nullable error) {
                    if (error) {
                        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
                        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
                        return;
                    }

                    NSString *recognizedText = @"";
                    if (recognitionResult.candidates.count > 0) {
                        // Return highest confidence text string candidate match
                        recognizedText = recognitionResult.candidates.firstObject.text;
                    }

                    NSDictionary *response = @{@"text": recognizedText};
                    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
                    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
                }];
            };

            // 5. Check if the offline model language asset pack is downloaded locally
            if ([modelManager isModelDownloaded:model]) {
                runRecognition();
            } else {
                // Downloads asset pack dynamically over network if missing (~20MB target)
                MLKModelDownloadConditions *conditions = [[MLKModelDownloadConditions alloc] initWithAllowsCellularAccess:YES allowsBackgroundDownloading:YES];
                
                [modelManager downloadModel:model
                                 conditions:conditions
                                 completion:^(NSError * _Nullable error) {
                    if (error) {
                        NSString *errStr = [NSString stringWithFormat:@"iOS language pack download failed: %@", error.localizedDescription];
                        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errStr];
                        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
                        return;
                    }
                    // Model fetched successfully, run inference!
                    runRecognition();
                }];
            }
        } @catch (NSException *exception) {
            NSString *errStr = [NSString stringWithFormat:@"iOS Native Exception: %@", exception.reason];
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errStr];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    }];
}

@end
