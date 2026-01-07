//
//  VideoEngineObjCBridge.mm
//  maxmiize-v1
//
//  Objective-C++ implementation that bridges Swift to C++
//  Note: .mm extension tells Xcode this is Objective-C++
//

#import "VideoEngineObjCBridge.h"
#import "VideoEngine.hpp"

@implementation VideoEngineObjCBridge

static maxmiize::video::VideoEngine* engine = nullptr;

+ (NSString *)getVersion {
    std::string version = maxmiize::video::VideoEngine::getVersion();
    return [NSString stringWithUTF8String:version.c_str()];
}

+ (BOOL)initialize {
    if (engine == nullptr) {
        engine = new maxmiize::video::VideoEngine();
    }
    return engine->initialize();
}

+ (NSString *)testMessage {
    return @"C++ VideoEngine is working! 🎥";
}

+ (void)cleanup {
    if (engine != nullptr) {
        delete engine;
        engine = nullptr;
    }
}

@end
