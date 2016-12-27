//
//  IGAudioManager.h


#import <CoreFoundation/CoreFoundation.h>

typedef void (^IGAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@protocol IGAudioManager <NSObject>

@property (readonly) UInt32             numOutputChannels;
@property (readonly) Float64            samplingRate;
@property (readonly) UInt32             numBytesPerSample;
@property (readonly) Float32            outputVolume;
@property (readonly) BOOL               playing;
@property (readonly, strong) NSString   *audioRoute;

@property (readwrite, copy) IGAudioManagerOutputBlock outputBlock;

- (BOOL) activateAudioSession;
- (void) deactivateAudioSession;
- (BOOL) play;
- (void) pause;

@end

@interface IGAudioManager : NSObject
+ (id<IGAudioManager>) audioManager;
@end
