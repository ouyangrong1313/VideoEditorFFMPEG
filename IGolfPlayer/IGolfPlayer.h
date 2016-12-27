//
//  IGolfPlayer.h
//  IGolfPlayer
//
//  Created by wuwl on 16/1/25.
//  Copyright © 2016年 wuwl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIColor.h>

typedef enum {
    enDrawType_path,
    enDrawType_Line,
    enDrawType_Circle,
    enDrawType_Rect
} DRAW_TYPE;
typedef enum{
    enPLS_Stop=0,
    enPLS_Playing,
    enPLS_Paused
}Player_State;
typedef enum
{
    enPlayerProgress=0, //message: "当前播放时间-总长度;当前帧-总帧数"
    enPlayerState,//0,stop,1,playing,2,pause
}Player_MSG;
@protocol IGolfPlayerDelegate <NSObject>

-(void)playerState:(id)player
         cmdPlayer:(int)icmd
           message:(NSString*)msg;

@end

@class IGolfplayerDecoder;

extern NSString * const IGolfplayerParameterMinBufferedDuration;    // Float
extern NSString * const IGolfplayerParameterMaxBufferedDuration;    // Float
extern NSString * const IGolfplayerParameterDisableDeinterlacing;   // BOOL

/*
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *path;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    NSMutableArray *ma = [NSMutableArray array];
    NSString *path1 = [[NSBundle mainBundle] pathForResource:@"dd" ofType:@"mp4"];
    [ma addObject:path1];
    path1 = [[NSBundle mainBundle] pathForResource:@"100072_FI_20151208_150923_2903" ofType:@"mp4"];
    [ma addObject:path1];
    
    [ma sortedArrayUsingSelector:@selector(compare:)];
    
    path = ma[indexPath.row];
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
    if ([path.pathExtension isEqualToString:@"wmv"])
        parameters[IGolfplayerParameterMinBufferedDuration] = @(5.0);
        
        // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            parameters[IGolfplayerParameterDisableDeinterlacing] = @(YES);
            
            // disable buffering
            //parameters[IGolfplayerParameterMinBufferedDuration] = @(0.0f);
            //parameters[IGolfplayerParameterMaxBufferedDuration] = @(0.0f);
            
            IGolfPlayer *vc = [IGolfPlayer IGPlayerControllerWithContentPath:path
                                                                                       parameters:parameters left:50 top:50 right:450 bottom:550];
            [self presentViewController:vc animated:YES completion:nil];
    //[self.navigationController pushViewController:vc animated:YES];
    
    LoggerApp(1, @"Playing a movie: %@", path);
}
*/

@interface IGolfPlayer : UIViewController<UITableViewDataSource, UITableViewDelegate>
+ (id) IGPlayerControllerWithContentPath: (NSString *) path
                              parameters: (NSDictionary *) parameters
                                    left:(CGFloat)posleft
                                     top:(CGFloat)postop
                                   right:(CGFloat)posright
                                  bottom:(CGFloat)posbottom;

@property (readonly) BOOL playing;
@property (readonly) int  playState;
@property (weak,nonatomic) id<IGolfPlayerDelegate> iGolfDelegate;

- (id)initWithContent:(CGFloat)posleft
                  top:(CGFloat)postop
                right:(CGFloat)posright
               bottom:(CGFloat)posbottom;

- (void) setMediaPath:(NSString*)path
           parameters:(NSDictionary*)para;

- (void) resizePlayer:(CGFloat)posleft
                  top:(CGFloat)postop
                right:(CGFloat)posright
               bottom:(CGFloat)posbottom;

- (void) play;
- (void) pause;
- (void) stop;
//获取总帧数
- (NSUInteger)  getVideoFramsNum;
- (void) seekVideoFoward:(int)nShowFrm;
- (void) seekVideoRewind:(int)nShowFrm;
//几分之几
- (void) setPlaySpeed:(float)ndiv;
//add by leo 2016-1-31 begin
- (void)undo;
- (void)redo;
- (void)clear;
- (void)setDrawType:(DRAW_TYPE)dwType;
- (void)setDrawClr:(UIColor*)dwClr;
//add by leo 2016-1-31 end
@end
