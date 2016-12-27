//
//  IGolfplayerDecoder.h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

extern NSString * IGolfplayerErrorDomain;

typedef enum {
    
    IGolfplayerErrorNone,
    IGolfplayerErrorOpenFile,
    IGolfplayerErrorStreamInfoNotFound,
    IGolfplayerErrorStreamNotFound,
    IGolfplayerErrorCodecNotFound,
    IGolfplayerErrorOpenCodec,
    IGolfplayerErrorAllocateFrame,
    IGolfplayerErrorSetupScaler,
    IGolfplayerErroReSampler,
    IGolfplayerErrorUnsupported,
    
} IGolfplayerError;

typedef enum {
    
    IGFrameTypeAudio,
    IGFrameTypeVideo,
    IGFrameTypeArtwork,
    IGFrameTypeSubtitle,
    
} IGFrameType;

typedef enum {
        
    IGVideoFrameFormatRGB,
    IGVideoFrameFormatYUV,
    
} IGVideoFrameFormat;

@interface IGMovieFrame : NSObject
@property (readonly, nonatomic) IGFrameType type;
@property (readonly, nonatomic) CGFloat position;
@property (readonly, nonatomic) CGFloat duration;
@end

@interface IGAudioFrame : IGMovieFrame
@property (readonly, nonatomic, strong) NSData *samples;
@end

@interface IGVideoFrame : IGMovieFrame
@property (readonly, nonatomic) IGVideoFrameFormat format;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
@end

@interface IGVideoFrameRGB : IGVideoFrame
@property (readonly, nonatomic) NSUInteger linesize;
@property (readonly, nonatomic, strong) NSData *rgb;
- (UIImage *) asImage;
@end

@interface IGVideoFrameYUV : IGVideoFrame
@property (readonly, nonatomic, strong) NSData *luma;
@property (readonly, nonatomic, strong) NSData *chromaB;
@property (readonly, nonatomic, strong) NSData *chromaR;
@end

@interface IGArtworkFrame : IGMovieFrame
@property (readonly, nonatomic, strong) NSData *picture;
- (UIImage *) asImage;
@end

@interface IGSubtitleFrame : IGMovieFrame
@property (readonly, nonatomic, strong) NSString *text;
@end

typedef BOOL(^IGolfplayerDecoderInterruptCB)();

@interface IGolfplayerDecoder : NSObject

@property (readonly, nonatomic, strong) NSString *path;
@property (readonly, nonatomic) BOOL isEOF;
@property (readwrite,nonatomic) CGFloat position;
@property (readonly, nonatomic) CGFloat duration;
@property (readonly, nonatomic) CGFloat fps;
@property (readonly, nonatomic) CGFloat sampleRate;
@property (readonly, nonatomic) NSUInteger frameWidth;
@property (readonly, nonatomic) NSUInteger frameHeight;
@property (readonly, nonatomic) NSUInteger audioStreamsCount;
@property (readwrite,nonatomic) NSInteger selectedAudioStream;
@property (readonly, nonatomic) NSUInteger subtitleStreamsCount;
@property (readwrite,nonatomic) NSInteger selectedSubtitleStream;
@property (readonly, nonatomic) BOOL validVideo;
@property (readonly, nonatomic) BOOL validAudio;
@property (readonly, nonatomic) BOOL validSubtitles;
@property (readonly, nonatomic, strong) NSDictionary *info;
@property (readonly, nonatomic, strong) NSString *videoStreamFormatName;
@property (readonly, nonatomic) BOOL isNetwork;
@property (readonly, nonatomic) CGFloat startTime;
@property (readwrite, nonatomic) BOOL disableDeinterlacing;
@property (readwrite, nonatomic, strong) IGolfplayerDecoderInterruptCB interruptCallback;

+ (id) movieDecoderWithContentPath: (NSString *) path
                             error: (NSError **) perror;

- (BOOL) openFile: (NSString *) path
            error: (NSError **) perror;
- (NSUInteger) getVideoFramesNum;

-(void) closeFile;

- (BOOL) setupVideoFrameFormat: (IGVideoFrameFormat) format;

- (NSArray *) decodeFrames: (CGFloat) minDuration;

@end

@interface IGolfplayerSubtitleASSParser : NSObject

+ (NSArray *) parseEvents: (NSString *) events;
+ (NSArray *) parseDialogue: (NSString *) dialogue
                  numFields: (NSUInteger) numFields;
+ (NSString *) removeCommandsFromEventText: (NSString *) text;

@end