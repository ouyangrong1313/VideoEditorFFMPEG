//
//  ESGLView.h
#import <UIKit/UIKit.h>

@class IGVideoFrame;
@class IGolfplayerDecoder;

@interface IGolfplayerGLView : UIView

- (id) initWithFrame:(CGRect)frame
             decoder: (IGolfplayerDecoder *) decoder;

- (void) render: (IGVideoFrame *) frame;

@end
