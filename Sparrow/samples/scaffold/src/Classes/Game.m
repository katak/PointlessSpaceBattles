//
//  Game.m
//  AppScaffold
//

#import "Game.h" 

// --- private interface ---------------------------------------------------------------------------

@interface Game ()

- (void)setup;
- (void)onImageTouched:(SPTouchEvent *)event;
- (void)onResize:(SPResizeEvent *)event;

@property (nonatomic) float accel;
#define ACCEL_FACTOR 20000  // this value can vary depending on the application
#define NUM_FILTER_POINTS 10    // number of recent points to use in average
@end


// --- class implementation ------------------------------------------------------------------------

@implementation Game

@synthesize gameWidth  = mGameWidth;
@synthesize gameHeight = mGameHeight;
@synthesize accel;  // accelerometer acceleration value

UIAccelerometer *accelerometer;
NSMutableArray *rawAccel;

SPImage *playerShip;

float objXSpeed;
float objYSpeed;
float dt;                       // time elapsed

BOOL atLeftEdgeOfScreen = NO;   // flag for player collision with left screen edge
BOOL atRightEdgeOfScreen = NO;  // flag for player collision with right screen edge
int frameCount = 0;
SPTextField *textField;

- (id)initWithWidth:(float)width height:(float)height
{
    if ((self = [super init]))
    {
        mGameWidth = width;
        mGameHeight = height;
        
        objXSpeed = 1.0;
        objYSpeed = 1.0;
        
        accelerometer = [UIAccelerometer sharedAccelerometer];
        accelerometer.updateInterval = 1.0/60.0;
        accelerometer.delegate = self;
        
        rawAccel = [NSMutableArray arrayWithCapacity:NUM_FILTER_POINTS];
        for (int i = 0; i < NUM_FILTER_POINTS; i++)
        {
            [rawAccel addObject:[NSNumber numberWithFloat:0.0]];
        }
        
        mParticleSystem = [[SXParticleSystem alloc] initWithContentsOfFile:@"waterfall.pex"];
        mParticleSystem.x = width / 2.0f;
        mParticleSystem.y = height / 2.0f;
        
        [self addChild:mParticleSystem];
//        [self.stage.juggler addObject:mParticleSystem];
        [[SPStage mainStage].juggler addObject:mParticleSystem];
        
//        mParticleSystem.emitterX = 20.0f;
//        mParticleSystem.emitterY = -40.0f;
//        mParticleSystem.scaleY = -1;
//        mParticleSystem.scaleFactor = 2.0;    // more native for retina?
        
//        blog.onebyonedesign.com/flash/particle-editor-for-starling-framework/
        
        [mParticleSystem start];
         
         
        
        [self setup];
    }
    return self;
}

- (void)dealloc
{
    // release any resources here
    
    [Media releaseAtlas];
    [Media releaseSound];
    
}

- (void)setup
{
    // This is where the code of your game will start. 
    // In this sample, we add just a few simple elements to get a feeling about how it's done.
    
    [SPAudioEngine start];  // starts up the sound engine
    
    
    // The Application contains a very handy "Media" class which loads your texture atlas
    // and all available sound files automatically. Extend this class as you need it --
    // that way, you will be able to access your textures and sounds throughout your 
    // application, without duplicating any resources.
    
    [Media initAtlas];      // loads your texture atlas -> see Media.h/Media.m
    [Media initSound];      // loads all your sounds    -> see Media.h/Media.m
    
    
    // Create a background image. Since the demo must support all different kinds of orientations,
    // we center it on the stage with the pivot point.
    
    SPImage *background = [[SPImage alloc] initWithContentsOfFile:@"background.jpg"];
    background.pivotX = background.width / 2;
    background.pivotY = background.height / 2;
    background.x = mGameWidth / 2;
    background.y = mGameHeight / 2;
//    [self addChild:background];
    
    
    // Display the Sparrow egg
    
    playerShip = [[SPImage alloc] initWithContentsOfFile:@"ship.jpeg"];
    playerShip.pivotX = (int)playerShip.width / 2;
    playerShip.pivotY = (int)playerShip.height / 2;
    playerShip.x = mGameWidth / 2;
    playerShip.y = mGameHeight / 2;
//    [self addChild:playerShip];
    
//    SPImage *image = [[SPImage alloc] initWithTexture:[Media atlasTexture:@"sparrow"]];
//    image.pivotX = (int)image.width / 2;
//    image.pivotY = (int)image.height / 2;
//    image.x = mGameWidth / 2;
//    image.y = mGameHeight / 2 + 40;
//    [self addChild:image];
    
    // play a sound when the image is touched
//    [image addEventListener:@selector(onImageTouched:) atObject:self forType:SP_EVENT_TYPE_TOUCH];
    
    // and animate it a little
//    SPTween *tween = [SPTween tweenWithTarget:image time:1.5 transition:SP_TRANSITION_EASE_IN_OUT];
//    [tween animateProperty:@"y" targetValue:image.y + 30];
//    [tween animateProperty:@"rotation" targetValue:0.1];
//    tween.loop = SPLoopTypeReverse;
//    [[SPStage mainStage].juggler addObject:tween];
    
    
    // Create a text field
    
    NSString *text = @"Frame: ";
    
    textField = [[SPTextField alloc] initWithWidth:280 height:80 text:text];
    textField.x = 50;    // (mGameWidth - textField.width) / 2;
    textField.y = 50;   // image.y - 175;
    textField.color = 0xFFFFFF;
    [self addChild:textField];
    

    // The scaffold autorotates the game to all supported device orientations. 
    // Choose the orienations you want to support in the Target Settings ("Summary"-tab).
    // To update the game content accordingly, listen to the "RESIZE" event; it is dispatched
    // to all game elements (just like an ENTER_FRAME event).
    // 
    // To force the game to start up in landscape, add the key "Initial Interface Orientation" to
    // the "App-Info.plist" file and choose any landscape orientation.
    
    [self addEventListener:@selector(onResize:) atObject:self forType:SP_EVENT_TYPE_RESIZE];
    
    // Per default, this project compiles as a universal application. To change that, enter the 
    // project info screen, and in the "Build"-tab, find the setting "Targeted device family".
    //
    // Now choose:  
    //   * iPhone      -> iPhone only App
    //   * iPad        -> iPad only App
    //   * iPhone/iPad -> Universal App  
    //
    // To support the iPad, the minimum "iOS deployment target" is "iOS 3.2".
    
    [self addEventListener:@selector(onEnterFrame:) atObject:self forType:SP_EVENT_TYPE_ENTER_FRAME];
    [self addEventListener:@selector(onScreenTouched:) atObject:self forType:SP_EVENT_TYPE_TOUCH];
}

- (void)onImageTouched:(SPTouchEvent *)event
{
    NSSet *touches = [event touchesWithTarget:self andPhase:SPTouchPhaseEnded];
    if ([touches anyObject])
    {
        [Media playSound:@"sound.caf"];
    }
}

- (void)onResize:(SPResizeEvent *)event
{
    NSLog(@"new size: %.0fx%.0f (%@)", event.width, event.height, 
          event.isPortrait ? @"portrait" : @"landscape");
}

- (void)onEnterFrame:(SPEnterFrameEvent *)event
{
    frameCount++;
    textField.text = [NSString stringWithFormat:@"Frame: %d",frameCount];
    dt = event.passedTime;
}

- (void)onScreenTouched:(SPTouchEvent *)event
{
    frameCount = 0;
}

// accelerometer handler
// implement a low-pass filter to extract stable acceleration value
- (void) accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *) acceleration
{
    BOOL shouldMove = NO;
    
    if((!atLeftEdgeOfScreen) || (!atRightEdgeOfScreen)){
        if(acceleration.x < -0.05){
            shouldMove = YES;
        }else if(acceleration.x > 0.05){
            shouldMove = YES;
        }
    }if(atLeftEdgeOfScreen){
        if(acceleration.x < 0){
            shouldMove = NO;
        }if(acceleration.x > 0){
            atLeftEdgeOfScreen = NO;
            shouldMove = YES;
        }
    }if(atRightEdgeOfScreen){
        if(acceleration.x > 0){
            shouldMove = NO;
        }if(acceleration.x < 0){
            atRightEdgeOfScreen = NO;
            shouldMove = YES;
        }
    }
    
    if(shouldMove){
        // player ship bounds checking
        if(playerShip.x < 40){
            playerShip.x = 40;
            atLeftEdgeOfScreen = YES;
        }else if(playerShip.x > (mGameWidth-40)){
            playerShip.x = mGameWidth-40;
            atRightEdgeOfScreen = YES;
        }else{
            if(dt != 0){
                playerShip.x += objXSpeed * accel * dt * dt;
            }
        }
    }
    
    // insert newest value
    // will push current values over by 1 spot, extending length by 1
    
    [rawAccel insertObject:[NSNumber numberWithFloat: acceleration.x] atIndex:0];
    
    // remove oldest value, returning length to NUM_FILTER_POINTS
    [rawAccel removeObjectAtIndex:NUM_FILTER_POINTS];
    
    // perform averaging
    accel = 0.0;
    for (NSNumber *raw in rawAccel)
    {
        accel += [raw floatValue];
    }
    accel *= ACCEL_FACTOR / NUM_FILTER_POINTS;
}
@end
