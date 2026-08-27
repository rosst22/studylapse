import AVFoundation
import CoreMedia
import VideoToolbox

/// Every tuning knob for the time-lapse pipeline, plus the size math that
/// justifies the defaults. See README.md for the full table.
struct CaptureConfiguration: Sendable, Equatable {

    /// Wall-clock seconds between the frames we keep. Everything else is dropped.
    var frameInterval: TimeInterval = 4.0

    /// Frames per second in the finished video.
    var playbackFrameRate: Int32 = 30

    /// 720p. Kept landscape-native; orientation is metadata, not pixels.
    var width: Int = 1280
    var height: Int = 720

    /// Hard ceiling handed to the HEVC encoder.
    var averageBitRate: Int = 3_500_000

    var cameraPosition: AVCaptureDevice.Position = .front

    // MARK: - Derived math

    /// How many times faster than real life the lapse plays.
    /// 4 s interval x 30 fps = 120x.
    var speedUpFactor: Double { frameInterval * Double(playbackFrameRate) }

    func outputDuration(forStudyDuration seconds: TimeInterval) -> TimeInterval {
        seconds / speedUpFactor
    }

    func frameCount(forStudyDuration seconds: TimeInterval) -> Int {
        Int((seconds / frameInterval).rounded(.down))
    }

    /// bytes = bitrate x output_duration / 8.  Storage tracks *output* length,
    /// not session length -- a 2 s interval costs 2.5x a 5 s interval.
    func estimatedBytes(forStudyDuration seconds: TimeInterval) -> Int64 {
        Int64(outputDuration(forStudyDuration: seconds) * Double(averageBitRate) / 8.0)
    }

    // MARK: - Timing

    var timescale: CMTimeScale { CMTimeScale(playbackFrameRate) }

    /// The whole trick of a time lapse: frame N is stamped at N/30 seconds,
    /// discarding the real capture timestamp. 1800 frames captured over two
    /// hours become a 60-second video.
    func presentationTime(forFrameIndex index: Int64) -> CMTime {
        CMTime(value: index, timescale: timescale)
    }

    // MARK: - Encoder settings

    /// - Parameter dimensions: post-rotation size. Portrait capture is 720x1280.
    func videoOutputSettings(dimensions: CGSize) -> [String: Any] {
        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: averageBitRate,
            // One keyframe per output second. A time lapse is all jump cuts, so
            // long GOPs make the encoder burn its budget on bad predictions.
            AVVideoMaxKeyFrameIntervalKey: playbackFrameRate,
            AVVideoMaxKeyFrameIntervalDurationKey: 1.0,
            AVVideoExpectedSourceFrameRateKey: playbackFrameRate,
            AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel as String,
        ]
        return [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height),
            AVVideoCompressionPropertiesKey: compression,
        ]
    }

    /// Native biplanar YUV. Matches what the camera hands us, so the encoder
    /// takes it with zero conversion.
    func pixelBufferAttributes(dimensions: CGSize) -> [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String:
                Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            kCVPixelBufferWidthKey as String: Int(dimensions.width),
            kCVPixelBufferHeightKey as String: Int(dimensions.height),
        ]
    }
}
