//
//  Game.h
//  AppScaffold
//

#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>
#import "SXParticleSystem.h"

@interface Game : SPSprite
{
  @private 
    float mGameWidth;
    float mGameHeight;
    SXParticleSystem *mParticleSystem;
}

- (id)initWithWidth:(float)width height:(float)height;

@property (nonatomic, assign) float gameWidth;
@property (nonatomic, assign) float gameHeight;

@end
