//
//  IGLogger.h
#ifndef IGolfplayer_IGLogger_h
#define IGolfplayer_IGLogger_h

//#define DUMP_AUDIO_DATA

#ifdef DEBUG
#    define LoggerStream(level, ...)   NSLog(__VA_ARGS__)
#    define LoggerVideo(level, ...)    NSLog(__VA_ARGS__)
#    define LoggerAudio(level, ...)    NSLog(__VA_ARGS__)
#else

#    define LoggerStream(...)          while(0) {}
#    define LoggerVideo(...)           while(0) {}
#    define LoggerAudio(...)           while(0) {}

#endif

#endif
