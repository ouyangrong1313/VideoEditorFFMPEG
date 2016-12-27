//
//  IGolfPlayer.m
//  IGolfPlayer
//
//  Created by wuwl on 16/1/25.
//  Copyright © 2016年 wuwl. All rights reserved.
//

#import "IGolfPlayer.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "IGolfplayerDecoder.h"
#import "IGAudioManager.h"
#import "IGolfplayerGLView.h"
#import "IGLogger.h"

NSString * const IGolfplayerParameterMinBufferedDuration = @"IGolfplayerParameterMinBufferedDuration";
NSString * const IGolfplayerParameterMaxBufferedDuration = @"IGolfplayerParameterMaxBufferedDuration";
NSString * const IGolfplayerParameterDisableDeinterlacing = @"IGolfplayerParameterDisableDeinterlacing";

////////////////////////////////////////////////////////////////////////////////

static NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft)
{
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
    if (h != 0) [format appendFormat:@"%d:%0.2d", h, m];
    else        [format appendFormat:@"%d", m];
    [format appendFormat:@":%0.2d", s];
    
    return format;
}

////////////////////////////////////////////////////////////////////////////////

enum {
    
    IGplayerInfoSectionGeneral,
    IGPlayerInfoSectionVideo,
    IGPlayerInfoSectionAudio,
    IGPlayerInfoSectionSubtitles,
    IGPlayerInfoSectionMetadata,
    IGPlayerInfoSectionCount,
};

enum {
    
    IGPlayerInfoGeneralFormat,
    IGPlayerInfoGeneralBitrate,
    IGPlayerInfoGeneralCount,
};

////////////////////////////////////////////////////////////////////////////////

//add by leo 2016-1-31 begin
#define kLineWidth 2
#define kLineColor ([UIColor redColor])
#define kCircleColor ([UIColor yellowColor])

//#define M_SHOWCONTRL

@interface PainterLineModel : NSObject

@property (assign,nonatomic) CGFloat lineWidth;//线宽
@property (strong,nonatomic) UIColor *lineColor;//颜色
@property (strong,nonatomic) UIBezierPath *linePath;//路径

-(instancetype)initWithPainterInfo:(CGFloat) anWidth withColor:(UIColor *) anColor withPath:(UIBezierPath *) anPath;

@end
@implementation PainterLineModel
@synthesize lineColor,linePath,lineWidth;

-(instancetype)initWithPainterInfo:(CGFloat) anWidth withColor:(UIColor *) anColor withPath:(UIBezierPath *) anPath{
    self=[super init];
    if(self) {
        lineWidth=anWidth;
        lineColor=anColor;
        linePath=anPath;
    }
    return self;
}
@end

//#define ANIMATION_RECT
//add by leo 2016-1-31 end

static NSMutableDictionary * gHistory;

#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0

@interface IGolfPlayer () {
    
    IGolfplayerDecoder      *_decoder;
    dispatch_queue_t    _dispatchQueue;
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    NSMutableArray      *_subtitles;
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
    CGFloat             _moviePosition;
    BOOL                _disableUpdateHUD;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    BOOL                _fullscreen;
    BOOL                _hiddenHUD;
    BOOL                _fitMode;
    BOOL                _infoMode;
    BOOL                _restoreIdleTimer;
    BOOL                _interrupted;
    
    IGolfplayerGLView       *_glView;
    UIImageView         *_imageView;
#ifdef M_SHOWCONTRL
    UIView              *_topHUD;
    UIView              *_bottomCtl;
    UIToolbar           *_topBar;
    UIToolbar           *_bottomBar;
    UISlider            *_progressSlider;
    
    UIBarButtonItem     *_playBtn;
    UIBarButtonItem     *_pauseBtn;
    UIBarButtonItem     *_rewindBtn;
    UIBarButtonItem     *_fforwardBtn;
    UIBarButtonItem     *_spaceItem;
    UIBarButtonItem     *_fixedSpaceItem;
    
    UIButton            *_doneButton;
    
    UIButton            *_lineButton;
    UIButton            *_circleButton;
    UIButton            *_rectButton;
    UIButton            *_clrButton;
    UIButton            *_resetButton;
    
    UILabel             *_progressLabel;
    UILabel             *_leftLabel;
    UIButton            *_infoButton;
    UITableView         *_tableView;
    UILabel             *_subtitlesLabel;
#endif
    //进度轮
    UIActivityIndicatorView *_activityIndicatorView;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    UITapGestureRecognizer *_doubleTapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    
#ifdef DEBUG
    UILabel             *_messageLabel;
    NSTimeInterval      _debugStartTime;
    NSUInteger          _debugAudioStatus;
    NSDate              *_debugAudioStatusTS;
#endif
    
    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    BOOL                _buffered;
    
    BOOL                _savedIdleTimer;
    
    NSDictionary        *_parameters;
    //add by leo 2016-1-31 begin
    CGPoint startPoint;
    CGPoint endPoint;
    CGPoint movePoint;
    int clrIndex;
    int bInit;
    //当前帧数
    int nCurFrame;
    //总帧数
    int nTotalFrames;
    
    NSString *tsfPath;
    CGRect rcPlayer;
    BOOL _mouseMoved;
    int _nLeftOffset;
    int _nTopOffSet;
    //add by leo 2016-1-31 end
}

//add by leo 2016-1-31 begin
//加绘图测试
@property(nonatomic,assign)DRAW_TYPE drawType;//可变路径
@property(nonatomic,assign)CGMutablePathRef path;//可变路径
@property(nonatomic,strong)CALayer *rectLayer;//画图子层
@property(nonatomic,strong)CALayer *drawLayer;//画线子层
//@property (assign,nonatomic) CGMutablePathRef path;
@property (assign,nonatomic) BOOL isHavePath;
//保留path 路径
@property (strong,nonatomic) NSMutableArray *pathArray;
@property (nonatomic, strong) NSMutableArray *redoOperasPath;
@property (nonatomic, strong) NSMutableArray *undoOperasPath;
@property (assign,nonatomic) CGFloat lineWidth;
@property (strong,nonatomic) UIColor *lineColor;
//播放速度比
@property (readwrite) float fplaySpeed;
//add by leo 2016-1-31 end

@property (readwrite) BOOL playing;
@property (readwrite) int playState;
@property (readwrite) BOOL decoding;
@property (readwrite, strong) IGArtworkFrame *artworkFrame;
@end

@implementation IGolfPlayer

+ (void)initialize
{
    if (!gHistory)
        gHistory = [NSMutableDictionary dictionary];
}

- (BOOL)prefersStatusBarHidden { return YES; }

+ (id) IGPlayerControllerWithContentPath: (NSString *) path
                              parameters: (NSDictionary *) parameters
                                    left:(CGFloat)posleft
                                     top:(CGFloat)postop
                                   right:(CGFloat)posright
                                  bottom:(CGFloat)posbottom
{
    id<IGAudioManager> audioManager = [IGAudioManager audioManager];
    [audioManager activateAudioSession];
    return [[IGolfPlayer alloc] initWithContentPath: path parameters: parameters left:posleft top:postop right:posright bottom:posbottom];
}

- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters
                      left:(CGFloat)posleft
                       top:(CGFloat)postop
                     right:(CGFloat)posright
                    bottom:(CGFloat)posbottom
{
    NSAssert(path.length > 0, @"empty path");
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        //add by leo 2016-1-31 begin
        _nLeftOffset = posleft;
        _nTopOffSet = postop;
        rcPlayer = CGRectMake(posleft, postop, posright-posleft, posbottom-postop);
        //初始化线宽和颜色
        _lineWidth=3.0f;
        _lineColor=[UIColor redColor];
        _drawType = enDrawType_Line;//enDrawType_path;
        clrIndex = 0;
        tsfPath = path;
        //add by leo 2016-1-31 end
        
        _moviePosition = 0;
        //        self.wantsFullScreenLayout = YES;
        _parameters = parameters;
        
        __weak IGolfPlayer *weakSelf = self;
        IGolfplayerDecoder *decoder = [[IGolfplayerDecoder alloc] init];
        
        decoder.interruptCallback = ^BOOL(){
            
            __strong IGolfPlayer *strongSelf = weakSelf;
            return strongSelf ? [strongSelf interruptDecoder] : YES;
        };
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            
            NSError *error = nil;
            [decoder openFile:path error:&error];
            
            __strong IGolfPlayer *strongSelf = weakSelf;
            if (strongSelf) {
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    [strongSelf setMovieDecoder:decoder withError:error];
                });
            }
        });
    }
    return self;
}

- (id)initWithContent:(CGFloat)posleft
                         top:(CGFloat)postop
                       right:(CGFloat)posright
                      bottom:(CGFloat)posbottom

{
    id<IGAudioManager> audioManager = [IGAudioManager audioManager];
    [audioManager activateAudioSession];
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        //self.view = nil;//这样赋值等于找死
        //add by leo 2016-1-31 begin
        _nLeftOffset = posleft;
        _nTopOffSet = postop;
        rcPlayer = CGRectMake(posleft, postop, posright-posleft, posbottom-postop);
        //初始化线宽和颜色
        _lineWidth=3.0f;
        _lineColor=[UIColor redColor];
        _drawType = enDrawType_Line;//enDrawType_path;
        clrIndex = 0;
        //add by leo 2016-1-31 end
        //会重复创建decoder？
        _decoder = nil;
        //_decoder = [[IGolfplayerDecoder alloc] init];
        //[self didMoveToParentViewController:self];
    }
    return self;
}

- (void) setMediaPath:(NSString*)path
           parameters:(NSDictionary*)para
{
    tsfPath = path;
    _parameters = para;
    /*
    if (self.playState==enPLS_Stop) {
        _moviePosition = 0;
        //        self.wantsFullScreenLayout = YES;
        __weak IGolfPlayer *weakSelf = self;
        //会重复创建decoder？
        //IGolfplayerDecoder *decoder = [[IGolfplayerDecoder alloc] init];
        _decoder.interruptCallback = ^BOOL(){
            __strong IGolfPlayer *strongSelf = weakSelf;
            return strongSelf ? [strongSelf interruptDecoder] : YES;
        };
        //打开文件时间长，所以就要移动到后台执行，这里直接执行，网络的，就很耗时
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *error = nil;
        [_decoder openFile:tsfPath error:&error];
        
        __strong IGolfPlayer *strongSelf = weakSelf;
        if (strongSelf) {
             dispatch_sync(dispatch_get_main_queue(), ^{
            [strongSelf setMovieDecoder:_decoder withError:error];
             });
        }
        });
    }*/
}

- (void) dealloc
{
    [self pause];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_dispatchQueue) {
        // Not needed as of ARC.
        //        dispatch_release(_dispatchQueue);
        _dispatchQueue = NULL;
    }
    
    LoggerStream(1, @"%@ dealloc", self);
}

- (void) resizePlayer:(CGFloat)posleft
                  top:(CGFloat)postop
                right:(CGFloat)posright
               bottom:(CGFloat)posbottom
{
    _nLeftOffset = posleft;
    _nTopOffSet = postop;
    rcPlayer = CGRectMake(posleft, postop, posright-posleft, posbottom-postop);
    //重新计算屏幕尺寸位置
    self.view.frame = rcPlayer;
    if (_decoder) {
        [self setupPresentView];
    }
}

- (void)loadView
{
    // LoggerStream(1, @"loadView");
    CGRect bounds = rcPlayer;//[[UIScreen mainScreen] applicationFrame];//rcPlayer;//
    bounds.origin = CGPointMake(0, 0);
    bounds.size = rcPlayer.size;
    
    //if (!self.view)
    {
        self.view = [[UIView alloc] initWithFrame:bounds];
    }
    //self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.frame = rcPlayer;
    self.view.backgroundColor = [UIColor blackColor];
    self.view.tintColor = [UIColor blackColor];
    
    if (!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    }
    //_activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicatorView.center = self.view.center;
    _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    [self.view addSubview:_activityIndicatorView];
    
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
#ifdef DEBUG
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,40,width-40,40)];
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.textColor = [UIColor redColor];
    _messageLabel.hidden = YES;
    _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.numberOfLines = 2;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_messageLabel];
#endif
    
    CGFloat topH = 50;
    CGFloat botH = 50;//50;
    CGFloat botHead = height-2*botH;
#ifdef M_SHOWCONTRL
    _topHUD    = [[UIView alloc] initWithFrame:CGRectMake(0,0,0,0)];
    _bottomCtl = [[UIView alloc]initWithFrame:CGRectMake(0,0,0,0)];
    
    _topBar    = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, width, topH)];
    _bottomBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, height-botH, width, botH)];
    _bottomBar.tintColor = [UIColor blackColor];
    
    _topHUD.frame = CGRectMake(0,0,width,_topBar.frame.size.height);
    _bottomCtl.frame = CGRectMake(0,botHead,width,_bottomBar.frame.size.height);
    
    _topHUD.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _bottomCtl.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |UIViewAutoresizingFlexibleWidth;
    _bottomBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:_topBar];
    [self.view addSubview:_topHUD];
    [self.view addSubview:_bottomBar];
    [self.view addSubview:_bottomCtl];
    
    // top hud
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.frame = CGRectMake(0, 1, 50, topH);
    _doneButton.backgroundColor = [UIColor clearColor];
    //    _doneButton.backgroundColor = [UIColor redColor];
    [_doneButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_doneButton setTitle:NSLocalizedString(@"OK", nil) forState:UIControlStateNormal];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _doneButton.showsTouchWhenHighlighted = YES;
    [_doneButton addTarget:self action:@selector(doneDidTouch:)
          forControlEvents:UIControlEventTouchUpInside];
    
    _lineButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _lineButton.frame = CGRectMake(0 + 55, 1, 50, topH);
    _lineButton.backgroundColor = [UIColor clearColor];
    [_lineButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_lineButton setTitle:NSLocalizedString(@"/", nil) forState:UIControlStateNormal];
    _lineButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _lineButton.showsTouchWhenHighlighted = YES;
    [_lineButton addTarget:self action:@selector(LineDidTouch:)
          forControlEvents:UIControlEventTouchUpInside];
    //    [_doneButton setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    _circleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _circleButton.frame = CGRectMake(0 + 55 + 55, 1, 50, topH);
    _circleButton.backgroundColor = [UIColor clearColor];
    [_circleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_circleButton setTitle:NSLocalizedString(@"O", nil) forState:UIControlStateNormal];
    _circleButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _circleButton.showsTouchWhenHighlighted = YES;
    [_circleButton addTarget:self action:@selector(CircleDidTouch:)
            forControlEvents:UIControlEventTouchUpInside];
    
    _rectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _rectButton.frame = CGRectMake(0 + 55 + 55 + 55, 1, 50, topH);
    _rectButton.backgroundColor = [UIColor clearColor];
    [_rectButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_rectButton setTitle:NSLocalizedString(@"[]", nil) forState:UIControlStateNormal];
    _rectButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _rectButton.showsTouchWhenHighlighted = YES;
    [_rectButton addTarget:self action:@selector(RectDidTouch:)
          forControlEvents:UIControlEventTouchUpInside];
    
    _clrButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _clrButton.frame = CGRectMake(0 + 55 + 55 + 55 + 55, 1, 50, topH);
    _clrButton.backgroundColor = [UIColor clearColor];
    [_clrButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_clrButton setTitle:NSLocalizedString(@"!", nil) forState:UIControlStateNormal];
    _clrButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _clrButton.showsTouchWhenHighlighted = YES;
    [_clrButton addTarget:self action:@selector(ColorDidTouch:)
         forControlEvents:UIControlEventTouchUpInside];
    
    _resetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _resetButton.frame = CGRectMake(0 + 55 + 55 + 55 + 55 + 55 +55, 1, 50, topH);
    _resetButton.backgroundColor = [UIColor clearColor];
    [_resetButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_resetButton setTitle:NSLocalizedString(@"X", nil) forState:UIControlStateNormal];
    _resetButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _resetButton.showsTouchWhenHighlighted = YES;
    [_resetButton addTarget:self action:@selector(ResetDidTouch:)
           forControlEvents:UIControlEventTouchUpInside];
    
    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(46, 1+botHead, 50, topH)];//[[UILabel alloc] initWithFrame:CGRectMake(46, 1, 50, topH)];
    _progressLabel.backgroundColor = [UIColor clearColor];
    _progressLabel.opaque = NO;
    _progressLabel.adjustsFontSizeToFitWidth = NO;
    _progressLabel.textAlignment = NSTextAlignmentRight;
    _progressLabel.textColor = [UIColor blackColor];
    _progressLabel.text = @"";
    _progressLabel.font = [UIFont systemFontOfSize:12];
    
    _progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(100, 2+botHead, width-197, topH)];
    _progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _progressSlider.continuous = NO;
    _progressSlider.value = 0;
    //    [_progressSlider setThumbImage:[UIImage imageNamed:@"kxmovie.bundle/sliderthumb"]
    //                          forState:UIControlStateNormal];
    
    _leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(width-92, 1+botHead, 60, topH)];
    _leftLabel.backgroundColor = [UIColor clearColor];
    _leftLabel.opaque = NO;
    _leftLabel.adjustsFontSizeToFitWidth = NO;
    _leftLabel.textAlignment = NSTextAlignmentLeft;
    _leftLabel.textColor = [UIColor blackColor];
    _leftLabel.text = @"";
    _leftLabel.font = [UIFont systemFontOfSize:12];
    _leftLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
    _infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    _infoButton.frame = CGRectMake(width-31, botHead+(topH-20)/2+1, 20, 20);
    _infoButton.showsTouchWhenHighlighted = YES;
    _infoButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_infoButton addTarget:self action:@selector(infoDidTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    [_topHUD addSubview:_doneButton];
    [_topHUD addSubview:_lineButton];
    [_topHUD addSubview:_circleButton];
    [_topHUD addSubview:_rectButton];
    [_topHUD addSubview:_clrButton];
    [_topHUD addSubview:_resetButton];
    //    [_topHUD addSubview:_progressLabel];
    //    [_topHUD addSubview:_progressSlider];
    //    [_topHUD addSubview:_leftLabel];
    //    [_topHUD addSubview:_infoButton];
    
    [_bottomCtl addSubview:_progressLabel];
    [_bottomCtl addSubview:_progressSlider];
    [_bottomCtl addSubview:_leftLabel];
    [_bottomCtl addSubview:_infoButton];
    
    // bottom hud
    _spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                               target:nil
                                                               action:nil];
    
    _fixedSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                    target:nil
                                                                    action:nil];
    _fixedSpaceItem.width = 30;
    
    _rewindBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
                                                               target:self
                                                               action:@selector(rewindDidTouch:)];
    
    _playBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                             target:self
                                                             action:@selector(playDidTouch:)];
    _playBtn.width = 50;
    
    _pauseBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                              target:self
                                                              action:@selector(playDidTouch:)];
    _pauseBtn.width = 50;
    
    _fforwardBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                                                                 target:self
                                                                 action:@selector(forwardDidTouch:)];
    
    [self updateBottomBar];
#endif
    if (_decoder) {
        [self setupPresentView];
    } else {
#ifdef M_SHOWCONTRL
        _progressLabel.hidden = YES;
        _progressSlider.hidden = YES;
        _leftLabel.hidden = YES;
        _infoButton.hidden = YES;
#endif
    }
    //add by leo 2016-1-31 begin
    _playing = NO;
    
    _fplaySpeed = (float)4/8;//1.0;//0.125;//0.5;//2.0;//1.0;0 表示逐帧播放,4/8非常慢，0.5 就没事
    _playState = enPLS_Stop;
    //add by leo 2016-1-31 end
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if (self.playing) {
        
        [self pause];
        [self freeBufferedFrames];
        
        if (_maxBufferedDuration > 0) {
            
            _minBufferedDuration = _maxBufferedDuration = 0;
            [self play];
            
            LoggerStream(0, @"didReceiveMemoryWarning, disable buffering and continue playing");
            
        } else {
            // force ffmpeg to free allocated memory
            [_decoder closeFile];
            [_decoder openFile:nil error:nil];
            
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                        message:NSLocalizedString(@"Out of memory", nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                              otherButtonTitles:nil] show];
        }
        
    } else {
        
        [self freeBufferedFrames];
        [_decoder closeFile];
        [_decoder openFile:nil error:nil];
    }
}

//add by leo 新增为画图 begin
/*步骤：
 1创建一个子层  在子层上上有一个图形
 2创建一个子层 用来画线 并且记录在移动的过程中的路径
 3给有图形的子层设置动画 跟线的路径是一样一样的
 */
- (void) viewDidLoad{
    [super viewDidLoad];
    //对画线子层进行相应设计
    _drawLayer = [[CALayer alloc]init];
    _drawLayer.bounds = self.view.bounds;
    _drawLayer.position = self.view.layer.position;
    _drawLayer.anchorPoint = self.view.layer.anchorPoint;
    //设置drawlayer 的代理为自己，让代理进行画图设置以及画图的工作
    self.drawLayer.delegate = self;
    [self.view.layer addSublayer:_drawLayer];
#ifdef ANIMATION_RECT
    //对子层进行初始化
    _rectLayer = [[CALayer alloc]init];
    _rectLayer.backgroundColor = [[UIColor yellowColor]CGColor];
    //大小
    _rectLayer.bounds = CGRectMake(0, 0, 30, 30);
    //墙上的位置
    _rectLayer.position = CGPointMake(100, 100);
    
    [self.view.layer addSublayer:_rectLayer];
#endif
}
/*
 开始画线 画线需要路径
 在触摸开始的时候创建路径 并设置开始点为触摸点
 在触摸移动的时候添加线进去并刷新
 在触摸结束的时候释放路径（因为path的创建是creat 需要手动释放）
 */
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    endPoint = startPoint = [touch locationInView:self.view];
    startPoint.x -= _nLeftOffset;
    startPoint.y -= _nTopOffSet;
    endPoint = startPoint;
    _mouseMoved = false;
    //创建一个可变的path
    switch (_drawType) {
        case enDrawType_path:
        {
            //获得当前点 并将当前点设置为path的开始点
            _path = CGPathCreateMutable();
            CGPathMoveToPoint(_path, nil, startPoint.x, startPoint.y);
        }
            break;
        case enDrawType_Line:
        case enDrawType_Circle:
        case enDrawType_Rect:
        {
            
        }
            break;
        default:
            break;
    }
    
    _isHavePath=YES;
}
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    _mouseMoved = true;
    movePoint = location;
    movePoint.x -= _nLeftOffset;
    movePoint.y -= _nTopOffSet;
    //endPoint = location;
    switch (_drawType) {
        case enDrawType_path:
            if(_path)
            {
                //获得当前点 并将点添加到path中
                CGPathAddLineToPoint(_path, nil, movePoint.x, movePoint.y);
            }
            break;
        case enDrawType_Circle:
        {
        }
            break;
        case enDrawType_Line:
        {
        }
            break;
        default:
            break;
    }
    [self.drawLayer setNeedsDisplay];
}

/*
 在触摸结束的时候开始一个动画  当然了这个动画效果就是图片层的移动
 首先应该创建一个动画帧 动画
 然后设置相应的参数
 最后给要设置的涂层加上动画
 */
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    /*
     在触摸结束的时候开始一个动画  当然了这个动画效果就是图片层的移动
     首先应该创建一个动画帧 动画
     然后设置相应的参数
     最后给要设置的涂层加上动画
     */
    if (!_mouseMoved) {
        return;
    }
    _mouseMoved = false;
    UITouch *touch = [touches anyObject];
    endPoint = [touch locationInView:self.view];
    endPoint.x -= _nLeftOffset;
    endPoint.y -= _nTopOffSet;
#ifdef ANIMATION_RECT
    if (_path && _drawType==enDrawType_path) {
        CAKeyframeAnimation *keyFrameA = [[CAKeyframeAnimation alloc]init];
        //持续时间是3秒
        keyFrameA.duration = 6.0f;
        //设置 keyPath（指定的接受动画的关键路径 也就是点）
        keyFrameA.keyPath = @"position";
        //设置 path （基于点的属性的路径）
        keyFrameA.path = self.path;
        
        //设置图能够留在最后的位置
        keyFrameA.removedOnCompletion = NO;
        keyFrameA.fillMode = kCAFillModeForwards;
        
        //相应的添加动画
        [self.rectLayer addAnimation:keyFrameA forKey:@"keyFrame"];
    }
#endif
    
    //if(_path)
    {
        UIBezierPath *_oldPath = nil;//[UIBezierPath bezierPathWithCGPath:_path];
        //add by leo 2016-1-31 begin
        switch (_drawType) {
            case enDrawType_path:
            {
                _oldPath = [UIBezierPath bezierPathWithCGPath:_path];
                CGPathRelease(_path);
            }
                break;
            case enDrawType_Line:
            {
                _oldPath = [UIBezierPath bezierPath];
                [_oldPath moveToPoint: startPoint];
                [_oldPath addLineToPoint: endPoint];
            }
                break;
            case enDrawType_Circle:
            {
                //以 end start 之间为直径
                float nDiameter = (endPoint.y-startPoint.y);//fabs(endPoint.y-startPoint.y);
                //计算直径
                nDiameter = sqrtf(powf(endPoint.y-startPoint.y,2)+powf(endPoint.x-startPoint.x, 2));
                float stOX = startPoint.x + (endPoint.x-startPoint.x)/2;
                float stOY = startPoint.y + (endPoint.y-startPoint.y)/2;
                
                float stX = stOX - nDiameter/2;
                float stY = stOY - nDiameter/2;
                _oldPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(stX,stY,nDiameter,nDiameter)];//16, 18, 36, 36)];
            }
                break;
            case enDrawType_Rect:
            {
                float rcfWid = endPoint.x - startPoint.x;
                float rcfHeight = endPoint.y - startPoint.y;
                //以 end start 为对角线
                _oldPath = [UIBezierPath bezierPathWithRect: CGRectMake(startPoint.x,startPoint.y,rcfWid,rcfHeight)];
            }
                break;
            default:
                break;
        }
        //获取当前绘制的曲线
        PainterLineModel *_model=[[PainterLineModel alloc]initWithPainterInfo:_lineWidth withColor:_lineColor withPath:_oldPath];
        
        if(!_pathArray){
            //初始化路径数组
            _pathArray=[NSMutableArray array];
        }
        if (!_undoOperasPath) {
            _undoOperasPath = [NSMutableArray array];
            _redoOperasPath = [NSMutableArray array];
        }
        
        //写入数组
        [_pathArray addObject:_model];
        [_undoOperasPath addObject:_model];
        
        _isHavePath=NO;
        //add by leo 2016-1-31 end
        //释放path
        //CGPathRelease(_path);
        [self.drawLayer setNeedsDisplay];
    }
}

#pragma mark-实现caLayer的代理方法
-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    //add by leo 2016-1-31 begin
    //绘制临时的
    CGContextSetLineWidth(ctx, self.lineWidth);
    CGContextSetStrokeColorWithColor(ctx, [self.lineColor CGColor]);
    if (_mouseMoved) {
        //endPoint-->movePoint
        switch (_drawType) {
        case enDrawType_Line:
        {
            CGMutablePathRef tmppath = CGPathCreateMutable();
            CGPathMoveToPoint(tmppath, nil, startPoint.x, startPoint.y);
            CGPathAddLineToPoint(tmppath, nil, movePoint.x, movePoint.y);
            CGContextAddPath(ctx, tmppath);//将path加入到ctx中
            CGPathRelease(tmppath);
        }
            break;
        case enDrawType_Circle:
        {
            float nDiameter = (movePoint.y-startPoint.y);//fabs(endPoint.y-startPoint.y);
            nDiameter = sqrtf(powf(movePoint.y-startPoint.y,2)+powf(movePoint.x-startPoint.x, 2));
            //圆心的坐标
            float stOX = startPoint.x + (movePoint.x-startPoint.x)/2;
            float stOY = startPoint.y + (movePoint.y-startPoint.y)/2;
            
            float stX = stOX - nDiameter/2;
            float stY = stOY - nDiameter/2;
            UIBezierPath *_oldPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(stX,stY,nDiameter,nDiameter)];//16, 18, 36, 36)];
            CGContextAddPath(ctx, _oldPath.CGPath);
        }
            break;
        case enDrawType_Rect:
        {
            float rcfWid = movePoint.x - startPoint.x;
            float rcfHeight = movePoint.y - startPoint.y;
            UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(startPoint.x,startPoint.y,rcfWid,rcfHeight)];
            CGContextAddPath(ctx, rectanglePath.CGPath);
        }
            break;

        default:
            break;
        }
        //执行绘画
        CGContextDrawPath(ctx, kCGPathStroke);
    }
    
    //遍历旧的路径
    for(PainterLineModel *models in _pathArray){
        CGContextAddPath(ctx, models.linePath.CGPath);
        CGContextSetLineWidth(ctx, models.lineWidth);
        CGContextSetStrokeColorWithColor(ctx, [models.lineColor CGColor]);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextDrawPath(ctx, kCGPathStroke);
    }
    //add by leo 2016-1-31 end    //设置花臂的颜色
    //CGContextAddPath(ctx, _path);//将path加入到ctx中
    //CGContextSetStrokeColorWithColor(ctx, [[UIColor redColor]CGColor]);
    //CGContextDrawPath(ctx, kCGPathStroke);//设置值描边不填充
}


- (void)undo {
    PainterLineModel *lstPath = [_undoOperasPath lastObject];
    if (lstPath) {
        startPoint = endPoint ;
        [_pathArray removeLastObject];
        [_undoOperasPath removeLastObject];
        [_redoOperasPath addObject:lstPath];
    }
    [self.drawLayer setNeedsDisplay];
}

- (void)redo {
    PainterLineModel *lstPath = [_redoOperasPath lastObject];
    if (lstPath) {
        [_redoOperasPath removeLastObject];
        [_undoOperasPath addObject:lstPath];
        [_pathArray addObject:lstPath];
    }
    [self.drawLayer setNeedsDisplay];
}

- (void)clear {
    for (PainterLineModel *tmpPath in self.redoOperasPath) {
        tmpPath.linePath = nil;
    }
    for (PainterLineModel *tmpPath in self.undoOperasPath) {
        tmpPath.linePath = nil;
    }
    for (PainterLineModel *tmpPath in self.pathArray) {
        tmpPath.linePath = nil;
    }
    [self.redoOperasPath removeAllObjects];
    [self.undoOperasPath removeAllObjects];
    for(PainterLineModel *models in _pathArray){
        models.linePath = nil;
    }
    startPoint.x = startPoint.y = endPoint.x = endPoint.y = 0;
    [_pathArray removeAllObjects];
    [self.drawLayer setNeedsDisplay];
}
- (void)setDrawType:(DRAW_TYPE)dwType
{
    _drawType = dwType;
    //导致了马上绘制相应的图形
    //[self.drawLayer setNeedsDisplay];
}
- (void)setDrawClr:(UIColor*)dwClr
{
    _lineColor = dwClr;
}
/////// 新增绘图end
- (void) viewDidAppear:(BOOL)animated
{
    // LoggerStream(1, @"viewDidAppear");
    
    [super viewDidAppear:animated];
    
    if (self.presentingViewController)
        [self fullscreenMode:YES];
    
    if (_infoMode)
        [self showInfoView:NO animated:NO];
    
    _savedIdleTimer = [[UIApplication sharedApplication] isIdleTimerDisabled];
    
    [self showHUD: YES];
    
    if (_decoder) {
        
        [self restorePlay];
        
    } else {
        
        [_activityIndicatorView startAnimating];
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
    
    [_activityIndicatorView stopAnimating];
    
    if (_decoder) {
        
        [self pause];
        
        if (_moviePosition == 0 || _decoder.isEOF)
            [gHistory removeObjectForKey:_decoder.path];
        else if (!_decoder.isNetwork)
            [gHistory setValue:[NSNumber numberWithFloat:_moviePosition]
                        forKey:_decoder.path];
    }
    
    if (_fullscreen)
        [self fullscreenMode:NO];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_savedIdleTimer];
    
    [_activityIndicatorView stopAnimating];
    _buffered = NO;
    _interrupted = YES;
    
    LoggerStream(1, @"viewWillDisappear %@", self);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) applicationWillResignActive: (NSNotification *)notification
{
    [self showHUD:YES];
    [self pause];
    
    LoggerStream(1, @"applicationWillResignActive");
}

#pragma mark - gesture recognizer

- (void) handleTap: (UITapGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (sender == _tapGestureRecognizer) {
            
            [self showHUD: _hiddenHUD];
            
        } else if (sender == _doubleTapGestureRecognizer) {
            
            UIView *frameView = [self frameView];
            
            if (frameView.contentMode == UIViewContentModeScaleAspectFit)
                frameView.contentMode = UIViewContentModeScaleAspectFill;
            else
                frameView.contentMode = UIViewContentModeScaleAspectFit;
            
        }
    }
}

- (void) handlePan: (UIPanGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        const CGPoint vt = [sender velocityInView:self.view];
        const CGPoint pt = [sender translationInView:self.view];
        const CGFloat sp = MAX(0.1, log10(fabsf(vt.x)) - 1.0);
        const CGFloat sc = fabsf(pt.x) * 0.33 * sp;
        if (sc > 10) {
            
            const CGFloat ff = pt.x > 0 ? 1.0 : -1.0;
            [self setMoviePosition: _moviePosition + ff * MIN(sc, 600.0)];
        }
        //LoggerStream(2, @"pan %.2f %.2f %.2f sec", pt.x, vt.x, sc);
    }
}

#pragma mark - public

-(void) play
{
    //if (self.playing)
    if ([tsfPath length]<=0) {
        return;
    }
    if (self.playState==enPLS_Stop) {
        _moviePosition = 0;
        //        self.wantsFullScreenLayout = YES;
        __weak IGolfPlayer *weakSelf = self;
        NSError *error = nil;
        if (_decoder==nil) {
            //会重复创建decoder？
            IGolfplayerDecoder *decoder = [[IGolfplayerDecoder alloc] init];
            _decoder.interruptCallback = ^BOOL(){
                __strong IGolfPlayer *strongSelf = weakSelf;
                return strongSelf ? [strongSelf interruptDecoder] : YES;
            };
            //打开文件时间长，所以就要移动到后台执行，这里直接执行，网络的，就很耗时
            //dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [decoder openFile:tsfPath error:&error];
            nCurFrame = nTotalFrames = 0;
            nTotalFrames = [decoder getVideoFramesNum];
            
            __strong IGolfPlayer *strongSelf = weakSelf;
            if (strongSelf) {
                //dispatch_sync(dispatch_get_main_queue(), ^{
                [strongSelf setMovieDecoder:decoder withError:error];
                //});
            }
            //});
            //sleep(5);
        }
        else
        {
            //[_decoder openFile:tsfPath error:&error];
        }
    }
    else if (self.playState==enPLS_Playing) {
        return;
    }
        
    if (_decoder.isEOF) {
        //重新打开文件
        NSError *error = nil;
        [_decoder closeFile];
        [_decoder openFile:tsfPath error:&error];
        nTotalFrames = [_decoder getVideoFramesNum];
        nCurFrame = 0;
    }
    if (!_decoder.validVideo &&
        !_decoder.validAudio) {
        
        return;
    }
    
    if (_interrupted)
        return;
    
    self.playing = YES;
    self.playState = enPLS_Playing;
    _interrupted = NO;
    _disableUpdateHUD = NO;
    _tickCorrectionTime = 0;
    _tickCounter = 0;
    
    NSString *strState = [NSString stringWithFormat:@"%d",enPLS_Playing ];
    if ([_iGolfDelegate respondsToSelector:@selector(playerState:cmdPlayer:message:)]) {
        [_iGolfDelegate playerState:self cmdPlayer:enPlayerState message:strState];
    }

#ifdef DEBUG
    _debugStartTime = -1;
#endif
    
    [self asyncDecodeFrames];
    [self updatePlayButton];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
    
    if (_decoder.validAudio)
        [self enableAudio:YES];
    
    LoggerStream(1, @"play movie");
}

- (void) pause
{
    //if (!self.playing)
    if (self.playState==enPLS_Paused) {
        return;
    }
    
    self.playing = NO;
    //_interrupted = YES;
    self.playState = enPLS_Paused;
    NSString *strState = [NSString stringWithFormat:@"%d",enPLS_Paused ];
    if ([_iGolfDelegate respondsToSelector:@selector(playerState:cmdPlayer:message:)]) {
        [_iGolfDelegate playerState:self cmdPlayer:enPlayerState message:strState];
    }

    [self enableAudio:NO];
#ifdef M_SHOWCONTRL
    [self updatePlayButton];
#endif
    LoggerStream(1, @"pause movie");
}

- (void) stop
{
    self.playing = NO;
    self.playState = enPLS_Stop;
    //让线程退出。。。
    [_decoder closeFile];
    NSString *strState = [NSString stringWithFormat:@"%d",enPLS_Stop ];
    if ([_iGolfDelegate respondsToSelector:@selector(playerState:cmdPlayer:message:)]) {
        [_iGolfDelegate playerState:self cmdPlayer:enPlayerState message:strState];
    }

#ifdef M_SHOWCONTRL
    [self updatePlayButton];
#endif
}

//获取总帧数
- (NSUInteger)  getVideoFramsNum
{
    return nTotalFrames;//[_decoder getVideoFramesNum];
}

- (void) seekVideoFoward:(int)nShowFrm
{
    //播放相应的帧数，但是并没有播放，只是移动并显示
    if (nShowFrm>0) {
        CGFloat pos = (CGFloat)nShowFrm/nTotalFrames;
        [self setMoviePosition:pos];
    }
}

- (void) seekVideoRewind:(int)nShowFrm
{
    //播放相应的帧数，但是并没有播放，只是移动并显示
    if (nShowFrm>0) {
        CGFloat pos = (CGFloat)nShowFrm/nTotalFrames;
        [self setMoviePosition:pos];
    }
}

- (void) setPlaySpeed:(float)ndiv
{
    _fplaySpeed = ndiv;
}

- (void) setMoviePosition: (CGFloat) position
{
    BOOL playMode = self.playing;
    
    self.playing = NO;
    _disableUpdateHUD = YES;
    [self enableAudio:NO];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        [self updatePosition:position playMode:playMode];
    });
}

#pragma mark - actions

- (void) ResetDidTouch: (id) sender
{
    [self clear];
}

- (void) ColorDidTouch: (id) sender
{
    ++clrIndex;
    if (clrIndex>4) {
        clrIndex = 0;
    }
    switch (clrIndex) {
        case 0:
            _lineColor=[UIColor blackColor];
            break;
        case 1:
            _lineColor=[UIColor redColor];
            break;
        case 2:
            _lineColor=[UIColor blueColor];
            break;
        case 3:
            _lineColor=[UIColor yellowColor];
            break;
        case 4:
            _lineColor=[UIColor greenColor];
            break;
        default:
            break;
    }
}

- (void) RectDidTouch: (id) sender
{
    [self setDrawType:enDrawType_Rect];
}

- (void) CircleDidTouch: (id) sender
{
    [self setDrawType:enDrawType_Circle];
}

- (void) LineDidTouch: (id) sender
{
    //_drawType = enDrawType_Line;
    [self setDrawType:enDrawType_Line];
}
- (void) doneDidTouch: (id) sender
{
    if (self.presentingViewController || !self.navigationController)
        [self dismissViewControllerAnimated:YES completion:nil];
    else
        [self.navigationController popViewControllerAnimated:YES];
}

- (void) infoDidTouch: (id) sender
{
    [self showInfoView: !_infoMode animated:YES];
}

- (void) playDidTouch: (id) sender
{
    /*
    if (self.playing)
        [self pause];
    else
        [self play];*/
    if (self.playState==enPLS_Playing) {
        [self pause];
    }
    else
    {
        [self play];
    }
}

- (void) forwardDidTouch: (id) sender
{
    [self setMoviePosition: _moviePosition + 10];
}

- (void) rewindDidTouch: (id) sender
{
    [self setMoviePosition: _moviePosition - 10];
}

- (void) progressDidChange: (id) sender
{
    NSAssert(_decoder.duration != MAXFLOAT, @"bugcheck");
    UISlider *slider = sender;
    [self setMoviePosition:slider.value * _decoder.duration];
}

#pragma mark - private

- (void) setMovieDecoder: (IGolfplayerDecoder *) decoder
               withError: (NSError *) error
{
    LoggerStream(2, @"setMovieDecoder");
    if (!error && decoder) {
        _decoder        = decoder;
        _dispatchQueue  = dispatch_queue_create("IGolfPlayer", DISPATCH_QUEUE_SERIAL);
        _videoFrames    = [NSMutableArray array];
        _audioFrames    = [NSMutableArray array];
        
        if (_decoder.subtitleStreamsCount) {
            _subtitles = [NSMutableArray array];
        }
        
        if (_decoder.isNetwork) {
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
            
        } else {
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
        
        if (!_decoder.validVideo)
            _minBufferedDuration *= 10.0; // increase for audio
        
        // allow to tweak some parameters at runtime
        if (_parameters.count) {
            id val;
            
            val = [_parameters valueForKey: IGolfplayerParameterMinBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _minBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: IGolfplayerParameterMaxBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _maxBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: IGolfplayerParameterDisableDeinterlacing];
            if ([val isKindOfClass:[NSNumber class]])
                _decoder.disableDeinterlacing = [val boolValue];
            
            if (_maxBufferedDuration < _minBufferedDuration)
                _maxBufferedDuration = _minBufferedDuration * 2;
        }
        
        LoggerStream(2, @"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
        
        if (self.isViewLoaded) {
            [self setupPresentView];
#ifdef M_SHOWCONTRL
            _progressLabel.hidden   = NO;
            _progressSlider.hidden  = NO;
            _leftLabel.hidden       = NO;
            _infoButton.hidden      = NO;
#endif
            if (_activityIndicatorView.isAnimating) {
                
                [_activityIndicatorView stopAnimating];
                // if (self.view.window)
                [self restorePlay];
            }
        }
    } else {
        
        if (self.isViewLoaded && self.view.window) {
            
            [_activityIndicatorView stopAnimating];
            if (!_interrupted)
                [self handleDecoderMovieError: error];
        }
    }
}

- (void) restorePlay
{
    NSNumber *n = [gHistory valueForKey:_decoder.path];
    if (n)
        [self updatePosition:n.floatValue playMode:YES];
    else
        [self play];
}

- (void) setupPresentView
{
    CGRect bounds = self.view.bounds;
    
    if (_decoder.validVideo) {
        if (!_glView)
            _glView = [[IGolfplayerGLView alloc] initWithFrame:bounds decoder:_decoder];
        else
            _glView.bounds = bounds;
        //_glView = [[IGolfplayerGLView alloc] initWithFrame:rcPlayer decoder:_decoder];
    }
    
    if (!_glView) {
        LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
        [_decoder setupVideoFrameFormat:IGVideoFrameFormatRGB];
        _imageView = [[UIImageView alloc] initWithFrame:bounds];
        _imageView.backgroundColor = [UIColor blackColor];
    }
    
    UIView *frameView = [self frameView];
    frameView.contentMode = UIViewContentModeScaleAspectFit;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view insertSubview:frameView atIndex:0];
    
    if (_decoder.validVideo) {
        [self setupUserInteraction];
    } else {
        _imageView.image = [UIImage imageNamed:@"bundle/music_icon.png"];
        _imageView.contentMode = UIViewContentModeCenter;
    }
    
    self.view.backgroundColor = [UIColor clearColor];
    
    if (_decoder.duration == MAXFLOAT) {
#ifdef M_SHOWCONTRL
        _leftLabel.text = @"\u221E"; // infinity
        _leftLabel.font = [UIFont systemFontOfSize:14];
        
        CGRect frame;
        
        frame = _leftLabel.frame;
        frame.origin.x += 40;
        frame.size.width -= 40;
        _leftLabel.frame = frame;
        
        frame =_progressSlider.frame;
        frame.size.width += 40;
        _progressSlider.frame = frame;
#endif
    } else {
#ifdef M_SHOWCONTRL
        [_progressSlider addTarget:self
                            action:@selector(progressDidChange:)
                  forControlEvents:UIControlEventValueChanged];
#endif
    }
    
    if (_decoder.subtitleStreamsCount) {
        CGSize size = self.view.bounds.size;
#ifdef M_SHOWCONTRL
        _subtitlesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height, size.width, 0)];
        _subtitlesLabel.numberOfLines = 0;
        _subtitlesLabel.backgroundColor = [UIColor clearColor];
        _subtitlesLabel.opaque = NO;
        _subtitlesLabel.adjustsFontSizeToFitWidth = NO;
        _subtitlesLabel.textAlignment = NSTextAlignmentCenter;
        _subtitlesLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _subtitlesLabel.textColor = [UIColor whiteColor];
        _subtitlesLabel.font = [UIFont systemFontOfSize:16];
        _subtitlesLabel.hidden = YES;
        
        [self.view addSubview:_subtitlesLabel];
#endif
    }
}

- (void) setupUserInteraction
{
    UIView * view = [self frameView];
    view.userInteractionEnabled = YES;
    
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    
    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    [_tapGestureRecognizer requireGestureRecognizerToFail: _doubleTapGestureRecognizer];
    
    [view addGestureRecognizer:_doubleTapGestureRecognizer];
    [view addGestureRecognizer:_tapGestureRecognizer];
    //    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    //    _panGestureRecognizer.enabled = NO;
    //
    //    [view addGestureRecognizer:_panGestureRecognizer];
}

- (UIView *) frameView
{
    return _glView ? _glView : _imageView;
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    //fillSignalF(outData,numFrames,numChannels);
    //return;
    if (_buffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return;
    }
    
    @autoreleasepool {
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                @synchronized(_audioFrames) {
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        IGAudioFrame *frame = _audioFrames[0];
                        
#ifdef DUMP_AUDIO_DATA
                        LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
                        if (_decoder.validVideo) {
                            
                            const CGFloat delta = _moviePosition - frame.position;
                            
                            if (delta < -0.1) {
                                
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
#ifdef DEBUG
                                LoggerStream(0, @"desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 1;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
#ifdef DEBUG
                                LoggerStream(0, @"desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 2;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                continue;
                            }
                        } else {
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;
            } else {
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //LoggerStream(1, @"silence audio");
#ifdef DEBUG
                _debugAudioStatus = 3;
                _debugAudioStatusTS = [NSDate date];
#endif
                break;
            }
        }
    }
}

- (void) enableAudio: (BOOL) on
{
    id<IGAudioManager> audioManager = [IGAudioManager audioManager];
    
    if (on && _decoder.validAudio) {
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
        
        LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
                    (int)audioManager.samplingRate,
                    (int)audioManager.numBytesPerSample,
                    (int)audioManager.numOutputChannels);
        
    } else {
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}

- (BOOL) addFrames: (NSArray *)frames
{
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            
            for (IGMovieFrame *frame in frames)
                if (frame.type == IGFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            for (IGMovieFrame *frame in frames)
                if (frame.type == IGFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (!_decoder.validVideo)
                        _bufferedDuration += frame.duration;
                }
        }
        
        if (!_decoder.validVideo) {
            
            for (IGMovieFrame *frame in frames)
                if (frame.type == IGFrameTypeArtwork)
                    self.artworkFrame = (IGArtworkFrame *)frame;
        }
    }
    
    if (_decoder.validSubtitles) {
        
        @synchronized(_subtitles) {
            
            for (IGMovieFrame *frame in frames)
                if (frame.type == IGFrameTypeSubtitle) {
                    [_subtitles addObject:frame];
                }
        }
    }
    
    return self.playing && _bufferedDuration < _maxBufferedDuration;
}

- (BOOL) decodeFrames
{
    //NSAssert(dispatch_get_current_queue() == _dispatchQueue, @"bugcheck");
    NSArray *frames = nil;
    
    if (_decoder.validVideo ||
        _decoder.validAudio) {
        
        frames = [_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (void) asyncDecodeFrames
{
    if (self.decoding)
        return;
    
    __weak IGolfPlayer *weakSelf = self;
    __weak IGolfplayerDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;
    
    self.decoding = YES;
    dispatch_async(_dispatchQueue, ^{
        {
            __strong IGolfPlayer *strongSelf = weakSelf;
            if (!strongSelf.playing)
                return;
        }
        
        BOOL good = YES;
        while (good) {
            good = NO;
            
            @autoreleasepool {
                __strong IGolfplayerDecoder *decoder = weakDecoder;
                
                if (decoder && (decoder.validVideo || decoder.validAudio)) {
                    
                    NSArray *frames = [decoder decodeFrames:duration];
                    if (frames.count) {
                        
                        __strong IGolfPlayer *strongSelf = weakSelf;
                        if (strongSelf)
                            good = [strongSelf addFrames:frames];
                    }
                }
            }
        }
        
        {
            __strong IGolfPlayer *strongSelf = weakSelf;
            if (strongSelf) strongSelf.decoding = NO;
        }
    });
}

- (void) tick
{
    if (_buffered && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        
        _tickCorrectionTime = 0;
        _buffered = NO;
        [_activityIndicatorView stopAnimating];
    }
    
    CGFloat interval = 0;
    if (!_buffered)
        interval = [self presentFrame];
    
    if (self.playing) {
        
        const NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            if (_decoder.isEOF) {
                //这里播放文件已经播放完毕
                //[self pause];
                [self stop];
                [self updateHUD];
                return;
            }
            
            if (_minBufferedDuration > 0 && !_buffered) {
                _buffered = YES;
                [_activityIndicatorView startAnimating];
            }
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        
        dispatch_time_t popTime;
        if (0.0==_fplaySpeed) {
            popTime = dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC);
        }
        else
            popTime = dispatch_time(DISPATCH_TIME_NOW, time/_fplaySpeed * NSEC_PER_SEC);///_fplaySpeed;
        
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
    if ((_tickCounter++ % 3) == 0) {
        [self updateHUD];
    }
}

- (CGFloat) tickCorrection
{
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    //if ((_tickCounter % 200) == 0)
    //    LoggerStream(1, @"tick correction %.4f", correction);
    
    if (correction > 1.f || correction < -1.f) {
        LoggerStream(1, @"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (CGFloat) presentFrame
{
    CGFloat interval = 0;
    
    if (_decoder.validVideo) {
        
        IGVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            if (_videoFrames.count > 0) {
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
        {
            interval = [self presentVideoFrame:frame];
            //当前播放的帧数
            ++nCurFrame;
        }
    }
    else if (_decoder.validAudio) {
        //interval = _bufferedDuration * 0.5;
        if (self.artworkFrame) {
            _imageView.image = [self.artworkFrame asImage];
            self.artworkFrame = nil;
        }
    }
    
    if (_decoder.validSubtitles)
        [self presentSubtitles];
    
#ifdef DEBUG
    if (self.playing && _debugStartTime < 0)
        _debugStartTime = [NSDate timeIntervalSinceReferenceDate] - _moviePosition;
#endif
    
    return interval;
}

- (CGFloat) presentVideoFrame: (IGVideoFrame *) frame
{
    if (_glView) {
        [_glView render:frame];
    } else {
        IGVideoFrameRGB *rgbFrame = (IGVideoFrameRGB *)frame;
        _imageView.image = [rgbFrame asImage];
    }
    
    _moviePosition = frame.position;
    
    return frame.duration;
}

- (void) presentSubtitles
{
#ifdef M_SHOWCONTRL
    NSArray *actual, *outdated;
    
    if ([self subtitleForPosition:_moviePosition
                           actual:&actual
                         outdated:&outdated])
    {
        if (outdated.count) {
            @synchronized(_subtitles) {
                [_subtitles removeObjectsInArray:outdated];
            }
        }
        
        if (actual.count) {
            NSMutableString *ms = [NSMutableString string];
            for (IGSubtitleFrame *subtitle in actual.reverseObjectEnumerator) {
                if (ms.length) [ms appendString:@"\n"];
                [ms appendString:subtitle.text];
            }
            
            if (![_subtitlesLabel.text isEqualToString:ms]) {
                
                CGSize viewSize = self.view.bounds.size;
                CGSize size = [ms sizeWithFont:_subtitlesLabel.font
                             constrainedToSize:CGSizeMake(viewSize.width, viewSize.height * 0.5)
                                 lineBreakMode:NSLineBreakByTruncatingTail];
                _subtitlesLabel.text = ms;
                _subtitlesLabel.frame = CGRectMake(0, viewSize.height - size.height - 10,
                                                   viewSize.width, size.height);
                _subtitlesLabel.hidden = NO;
            }
        } else {
            _subtitlesLabel.text = nil;
            _subtitlesLabel.hidden = YES;
        }
    }
#endif
}

- (BOOL) subtitleForPosition: (CGFloat) position
                      actual: (NSArray **) pActual
                    outdated: (NSArray **) pOutdated
{
    if (!_subtitles.count)
        return NO;
    
    NSMutableArray *actual = nil;
    NSMutableArray *outdated = nil;
    
    for (IGSubtitleFrame *subtitle in _subtitles) {
        
        if (position < subtitle.position) {
            break; // assume what subtitles sorted by position
        } else if (position >= (subtitle.position + subtitle.duration)) {
            if (pOutdated) {
                if (!outdated)
                    outdated = [NSMutableArray array];
                [outdated addObject:subtitle];
            }
        } else {
            
            if (pActual) {
                if (!actual)
                    actual = [NSMutableArray array];
                [actual addObject:subtitle];
            }
        }
    }
    
    if (pActual) *pActual = actual;
    if (pOutdated) *pOutdated = outdated;
    
    return actual.count || outdated.count;
}

- (void) updateBottomBar
{
#ifdef  M_SHOWCONTRL
    UIBarButtonItem *playPauseBtn = self.playing ? _pauseBtn : _playBtn;
    [_bottomBar setItems:@[_spaceItem, _rewindBtn, _fixedSpaceItem, playPauseBtn,
                           _fixedSpaceItem, _fforwardBtn, _spaceItem] animated:NO];
#endif
}

- (void) updatePlayButton
{
    [self updateBottomBar];
}

- (void) updateHUD
{
    if (_disableUpdateHUD)
        return;
    
    const CGFloat duration = _decoder.duration;
    const CGFloat position = _moviePosition -_decoder.startTime;
    
    NSString *strState = [NSString stringWithFormat:@"%f-%f;%d-%d",position,duration,nCurFrame,nTotalFrames ];
    if ([_iGolfDelegate respondsToSelector:@selector(playerState:cmdPlayer:message:)]) {
        [_iGolfDelegate playerState:self cmdPlayer:enPlayerProgress message:strState];
    }
#ifdef M_SHOWCONTRL
    if (_progressSlider.state == UIControlStateNormal)
        _progressSlider.value = position / duration;
    _progressLabel.text = formatTimeInterval(position, NO);
    
    if (_decoder.duration != MAXFLOAT)
        _leftLabel.text = formatTimeInterval(duration - position, YES);
#endif
#ifdef DEBUG
    const NSTimeInterval timeSinceStart = [NSDate timeIntervalSinceReferenceDate] - _debugStartTime;
    NSString *subinfo = _decoder.validSubtitles ? [NSString stringWithFormat: @" %d",_subtitles.count] : @"";
    
    NSString *audioStatus;
    
    if (_debugAudioStatus) {
        
        if (NSOrderedAscending == [_debugAudioStatusTS compare: [NSDate dateWithTimeIntervalSinceNow:-0.5]]) {
            _debugAudioStatus = 0;
        }
    }
    
    if      (_debugAudioStatus == 1) audioStatus = @"\n(audio outrun)";
    else if (_debugAudioStatus == 2) audioStatus = @"\n(audio lags)";
    else if (_debugAudioStatus == 3) audioStatus = @"\n(audio silence)";
    else audioStatus = @"";
    
    _messageLabel.text = [NSString stringWithFormat:@"%d %d%@ %c - %@ %@ %@\n%@",
                          _videoFrames.count,
                          _audioFrames.count,
                          subinfo,
                          self.decoding ? 'D' : ' ',
                          formatTimeInterval(timeSinceStart, NO),
                          //timeSinceStart > _moviePosition + 0.5 ? @" (lags)" : @"",
                          _decoder.isEOF ? @"- END" : @"",
                          audioStatus,
                          _buffered ? [NSString stringWithFormat:@"buffering %.1f%%", _bufferedDuration / _minBufferedDuration * 100] : @""];
#endif
}

- (void) showHUD: (BOOL) show
{
    _hiddenHUD = !show;
    _panGestureRecognizer.enabled = _hiddenHUD;
#ifdef M_SHOWCONTRL
    [[UIApplication sharedApplication] setIdleTimerDisabled:_hiddenHUD];
    
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                     animations:^{
                         
                         CGFloat alpha = _hiddenHUD ? 0 : 1;
                         _topBar.alpha = alpha;
                         _topHUD.alpha = alpha;
                         _bottomBar.alpha = alpha;
                     }
                     completion:nil];
#endif
}

- (void) fullscreenMode: (BOOL) on
{
    _fullscreen = on;
    UIApplication *app = [UIApplication sharedApplication];
    [app setStatusBarHidden:on withAnimation:UIStatusBarAnimationNone];
    // if (!self.presentingViewController) {
    //[self.navigationController setNavigationBarHidden:on animated:YES];
    //[self.tabBarController setTabBarHidden:on animated:YES];
    // }
}

- (void) setMoviePositionFromDecoder
{
    _moviePosition = _decoder.position;
}

- (void) setDecoderPosition: (CGFloat) position
{
    _decoder.position = position;
}

- (void) enableUpdateHUD
{
    _disableUpdateHUD = NO;
}

- (void) updatePosition: (CGFloat) position
               playMode: (BOOL) playMode
{
    [self freeBufferedFrames];
    
    position = MIN(_decoder.duration - 1, MAX(0, position));
    
    __weak IGolfPlayer *weakSelf = self;
    
    dispatch_async(_dispatchQueue, ^{
        if (playMode)
        {
            {
                __strong IGolfPlayer *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong IGolfPlayer *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf play];
                }
            });
        }
        else
        {
            {
                __strong IGolfPlayer *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
                [strongSelf decodeFrames];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong IGolfPlayer *strongSelf = weakSelf;
                if (strongSelf) {
                    
                    [strongSelf enableUpdateHUD];
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf presentFrame];
                    [strongSelf updateHUD];
                }
            });
        }
    });
}

- (void) freeBufferedFrames
{
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
    if (_subtitles) {
        @synchronized(_subtitles) {
            [_subtitles removeAllObjects];
        }
    }
    
    _bufferedDuration = 0;
}

- (void) showInfoView: (BOOL) showInfo animated: (BOOL)animated
{
#ifdef M_SHOWCONTRL
    if (!_tableView)
        [self createTableView];
    
    [self pause];
    
    CGSize size = self.view.bounds.size;
    CGFloat Y = _topHUD.bounds.size.height;
    
    if (showInfo) {
        _tableView.hidden = NO;
        
        if (animated) {
            [UIView animateWithDuration:0.4
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^{
                                 
                                 _tableView.frame = CGRectMake(0,Y,size.width,size.height - Y);
                             }
                             completion:nil];
        }
        else
        {
            
            _tableView.frame = CGRectMake(0,Y,size.width,size.height - Y);
        }
    }
    else
    {
        if (animated) {
            [UIView animateWithDuration:0.4
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^{
                                 
                                 _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
                             }
                             completion:^(BOOL f){
                                 if (f) {
                                     _tableView.hidden = YES;
                                 }
                             }];
        }
        else {
            
            _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
            _tableView.hidden = YES;
        }
    }
    
    _infoMode = showInfo;
#endif
}

- (void) createTableView
{
#ifdef M_SHOWCONTRL
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.hidden = YES;
    
    CGSize size = self.view.bounds.size;
    CGFloat Y = _topHUD.bounds.size.height;
    _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
    
    [self.view addSubview:_tableView];
#endif
}

- (void) handleDecoderMovieError: (NSError *) error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                              otherButtonTitles:nil];
    [alertView show];
}

- (BOOL) interruptDecoder
{
    //if (!_decoder)
    //    return NO;
    return _interrupted;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return IGPlayerInfoSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case IGplayerInfoSectionGeneral:
            return NSLocalizedString(@"General", nil);
        case IGPlayerInfoSectionMetadata:
            return NSLocalizedString(@"Metadata", nil);
        case IGPlayerInfoSectionVideo: {
            NSArray *a = _decoder.info[@"video"];
            return a.count ? NSLocalizedString(@"Video", nil) : nil;
        }
        case IGPlayerInfoSectionAudio: {
            NSArray *a = _decoder.info[@"audio"];
            return a.count ?  NSLocalizedString(@"Audio", nil) : nil;
        }
        case IGPlayerInfoSectionSubtitles: {
            NSArray *a = _decoder.info[@"subtitles"];
            return a.count ? NSLocalizedString(@"Subtitles", nil) : nil;
        }
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case IGplayerInfoSectionGeneral:
            return IGPlayerInfoGeneralCount;
            
        case IGPlayerInfoSectionMetadata: {
            NSDictionary *d = [_decoder.info valueForKey:@"metadata"];
            return d.count;
        }
            
        case IGPlayerInfoSectionVideo: {
            NSArray *a = _decoder.info[@"video"];
            return a.count;
        }
            
        case IGPlayerInfoSectionAudio: {
            NSArray *a = _decoder.info[@"audio"];
            return a.count;
        }
            
        case IGPlayerInfoSectionSubtitles: {
            NSArray *a = _decoder.info[@"subtitles"];
            return a.count ? a.count + 1 : 0;
        }
            
        default:
            return 0;
    }
}

- (id) mkCell: (NSString *) cellIdentifier
    withStyle: (UITableViewCellStyle) style
{
#ifdef M_SHOWCONTRL
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:cellIdentifier];
    }
    return cell;
#else
    return nil;
#endif
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
#ifdef M_SHOWCONTRL
    UITableViewCell *cell;
    
    if (indexPath.section == IGplayerInfoSectionGeneral) {
        if (indexPath.row == IGPlayerInfoGeneralBitrate) {
            int bitrate = [_decoder.info[@"bitrate"] intValue];
            cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Bitrate", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d kb/s",bitrate / 1000];
            
        }
        else if (indexPath.row == IGPlayerInfoGeneralFormat) {
            NSString *format = _decoder.info[@"format"];
            cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Format", nil);
            cell.detailTextLabel.text = format ? format : @"-";
        }
    } else if (indexPath.section == IGPlayerInfoSectionMetadata) {
        NSDictionary *d = _decoder.info[@"metadata"];
        NSString *key = d.allKeys[indexPath.row];
        cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = key.capitalizedString;
        cell.detailTextLabel.text = [d valueForKey:key];
    } else if (indexPath.section == IGPlayerInfoSectionVideo) {
        NSArray *a = _decoder.info[@"video"];
        cell = [self mkCell:@"VideoCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = a[indexPath.row];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;
    } else if (indexPath.section == IGPlayerInfoSectionAudio) {
        NSArray *a = _decoder.info[@"audio"];
        cell = [self mkCell:@"AudioCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = a[indexPath.row];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;
        BOOL selected = _decoder.selectedAudioStream == indexPath.row;
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        
    } else if (indexPath.section == IGPlayerInfoSectionSubtitles) {
        NSArray *a = _decoder.info[@"subtitles"];
        
        cell = [self mkCell:@"SubtitleCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 1;
        
        if (indexPath.row) {
            cell.textLabel.text = a[indexPath.row - 1];
        } else {
            cell.textLabel.text = NSLocalizedString(@"Disable", nil);
        }
        
        const BOOL selected = _decoder.selectedSubtitleStream == (indexPath.row - 1);
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
#else
    return nil;
#endif
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
#ifdef M_SHOWCONTRL
    if (indexPath.section == IGPlayerInfoSectionAudio) {
        
        NSInteger selected = _decoder.selectedAudioStream;
        
        if (selected != indexPath.row) {
            
            _decoder.selectedAudioStream = indexPath.row;
            NSInteger now = _decoder.selectedAudioStream;
            
            if (now == indexPath.row) {
                
                UITableViewCell *cell;
                
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                
                indexPath = [NSIndexPath indexPathForRow:selected inSection:IGPlayerInfoSectionAudio];
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == IGPlayerInfoSectionSubtitles) {
        NSInteger selected = _decoder.selectedSubtitleStream;
        if (selected != (indexPath.row - 1)) {
            _decoder.selectedSubtitleStream = indexPath.row - 1;
            NSInteger now = _decoder.selectedSubtitleStream;
            
            if (now == (indexPath.row - 1)) {
                UITableViewCell *cell;
                
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                
                indexPath = [NSIndexPath indexPathForRow:selected + 1 inSection:IGPlayerInfoSectionSubtitles];
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            
            // clear subtitles
            _subtitlesLabel.text = nil;
            _subtitlesLabel.hidden = YES;
            @synchronized(_subtitles) {
                [_subtitles removeAllObjects];
            }
        }
    }
#endif
}
@end
