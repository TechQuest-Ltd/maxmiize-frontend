//
//  VideoEngineObjCBridge.h
//  maxmiize-v1
//
//  Objective-C bridge to expose C++ VideoEngine to Swift
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge to C++ VideoEngine
@interface VideoEngineObjCBridge : NSObject

/// Get the C++ engine version
+ (NSString *)getVersion;

/// Initialize the video engine
+ (BOOL)initialize;

/// Test function to verify C++ is working
+ (NSString *)testMessage;

@end

NS_ASSUME_NONNULL_END
