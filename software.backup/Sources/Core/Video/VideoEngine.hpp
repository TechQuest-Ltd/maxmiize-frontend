//
//  VideoEngine.hpp
//  maxmiize-v1
//
//  C++ Video Engine for high-performance video processing
//  Handles video decoding, frame extraction, and timecode management
//

#ifndef VideoEngine_hpp
#define VideoEngine_hpp

#include <string>
#include <vector>
#include <cstdint>

namespace maxmiize {
namespace video {

// Video metadata structure
struct VideoMetadata {
    std::string filePath;
    int64_t durationMs;
    double frameRate;
    int width;
    int height;
    std::string codec;
};

// Simple video engine class
class VideoEngine {
public:
    VideoEngine();
    ~VideoEngine();

    // Initialize the engine
    bool initialize();

    // Load a video file
    bool loadVideo(const std::string& filePath);

    // Get video metadata
    VideoMetadata getMetadata() const;

    // Extract frame at specific timestamp (in milliseconds)
    bool extractFrame(int64_t timestampMs, uint8_t* buffer, size_t bufferSize);

    // Get the engine version
    static std::string getVersion();

private:
    bool initialized_;
    VideoMetadata metadata_;
};

} // namespace video
} // namespace maxmiize

#endif /* VideoEngine_hpp */
