//
//  SXParticleEmitter.m
//  Sparrow Particle System Extension
//
//  Created by Daniel Sperl on 02.06.11.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SXParticleSystem.h"
#import "SXNSDataExtensions.h"

#import <OpenGLES/ES1/gl.h>
#import <math.h>

// --- macros --------------------------------------------------------------------------------------

// clamp a value within the defined bounds
#define CLAMP(x, a, b) (((x) < (a)) ? (a) : (((x) > (b)) ? (b) : (x)))

// square a number
#define SQ(x) ((x)*(x))

// returns an RGBA color encoded in an UINT
#define SX_RGBA(r, g, b, a)    (((int)(a) << 24) | ((int)(r) << 16) | ((int)(g) << 8) | (int)(b))

// returns a random number between 0 and 1
#define RANDOM_FLOAT()    ((float) arc4random() / UINT_MAX)

// returns a random value between (base - variance) and (base + variance)
#define RANDOM_VARIANCE(base, variance)    ((base) + (variance) * (RANDOM_FLOAT() * 2.0f - 1.0f))

#define RANDOM_COLOR_VARIANCE(base, variance)                                              \
    (SXColor4f){ .red   = CLAMP(RANDOM_VARIANCE(base.red,   variance.red),   0.0f, 1.0f),  \
                 .green = CLAMP(RANDOM_VARIANCE(base.green, variance.green), 0.0f, 1.0f),  \
                 .blue  = CLAMP(RANDOM_VARIANCE(base.blue,  variance.blue),  0.0f, 1.0f),  \
                 .alpha = CLAMP(RANDOM_VARIANCE(base.alpha, variance.alpha), 0.0f, 1.0f) }

// --- private interface ---------------------------------------------------------------------------

@interface SXParticleSystem()

- (void)addParticleWithElapsedTime:(double)time;
- (void)advanceParticle:(SXParticle *)particle byTime:(double)passedTime;
- (void)parseConfiguration:(NSString *)path;
- (SXColor4f)colorFromDictionary:(NSDictionary *)dictionary;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SXParticleSystem

@synthesize numParticles = mNumParticles;
@synthesize texture = mTexture;
@synthesize scaleFactor = mScaleFactor;
@synthesize startColor = mStartColor;
@synthesize startColorVariance = mStartColorVariance;
@synthesize endColor = mEndColor;
@synthesize endColorVariance = mEndColorVariance;
@synthesize emitterType = mEmitterType;
@synthesize emitterX = mEmitterX;
@synthesize emitterY = mEmitterY;
@synthesize emitterXVariance = mEmitterXVariance;
@synthesize emitterYVariance = mEmitterYVariance;
@synthesize maxNumParticles = mMaxNumParticles;
@synthesize lifespan = mLifespan;
@synthesize lifespanVariance = mLifespanVariance;
@synthesize startSize = mStartSize;
@synthesize startSizeVariance = mStartSizeVariance;
@synthesize endSize = mEndSize;
@synthesize endSizeVariance = mEndSizeVariance;
@synthesize emitAngle = mEmitAngle;
@synthesize emitAngleVariance = mEmitAngleVariance;
@synthesize speed = mSpeed;
@synthesize speedVariance = mSpeedVariance;
@synthesize gravityX = mGravityX;
@synthesize gravityY = mGravityY;
@synthesize radialAcceleration = mRadialAcceleration;
@synthesize radialAccelerationVariance = mRadialAccelerationVariance;
@synthesize tangentialAcceleration = mTangentialAcceleration;
@synthesize tangentialAccelerationVariance = mTangentialAccelerationVariance;
@synthesize maxRadius = mMaxRadius;
@synthesize maxRadiusVariance = mMaxRadiusVariance;
@synthesize minRadius = mMinRadius;
@synthesize rotatePerSecond = mRotatePerSecond;
@synthesize rotatePerSecondVariance = mRotatePerSecondVariance;
@synthesize blendFuncSource = mBlendFuncSource;
@synthesize blendFuncDestination = mBlendFuncDestination;

- (id)initWithTexture:(SPTexture *)texture
{
    if ((self = [super init]))
    {
        mTexture = texture;
        
        // choose some useful defaults, just in case no config file is used
        mMaxNumParticles = 32;
        mEmitterType = SXParticleEmitterTypeGravity;
        mStartColor = (SXColor4f){ 1.0f, 1.0f, 1.0f, 1.0f };
        mEndColor   = (SXColor4f){ 0.0f, 0.0f, 0.0f, 0.0f };
        mLifespan = 1.0f;
        mStartSize = texture ? texture.width : 32;
        mEmitAngleVariance = PI / 8.0f;
        mSpeed = 256;
        mSpeedVariance = 64;
        mBlendFuncSource = GL_ONE;
        mBlendFuncDestination = GL_ONE_MINUS_SRC_ALPHA;
        mScaleFactor = [SPStage contentScaleFactor];
        
        mParticles = malloc(sizeof(SXParticle) * mMaxNumParticles);
        mPointSprites = malloc(sizeof(SXPointSprite) * mMaxNumParticles);
    }
    return self;
}

- (id)initWithContentsOfFile:(NSString *)filename texture:(SPTexture *)texture
{
    if ((self = [self initWithTexture:texture]))
    {
        [self parseConfiguration:filename];
    }
    return self;
}

- (id)initWithContentsOfFile:(NSString*)filename
{
    return [self initWithContentsOfFile:filename texture:nil];
}

+ (id)particleSystemWithContentsOfFile:(NSString *)filename
{
    return [[self alloc] initWithContentsOfFile:filename];
}

- (id)copyWithZone:(NSZone *)zone
{
    SXParticleSystem *copy = [[[self class] allocWithZone:zone] initWithTexture:mTexture];
    copy.maxNumParticles = mMaxNumParticles;
    
    copy->mEmitterType = mEmitterType;
    copy->mEmitterX = mEmitterX;
    copy->mEmitterXVariance = mEmitterXVariance;
    copy->mEmitterY = mEmitterY;
    copy->mEmitterYVariance = mEmitterYVariance;
    copy->mMaxNumParticles = mMaxNumParticles;
    copy->mLifespan = mLifespan;
    copy->mLifespanVariance = mLifespanVariance;
    copy->mStartSize = mStartSize;
    copy->mStartSizeVariance = mStartSizeVariance;
    copy->mEndSize = mEndSize;
    copy->mEndSizeVariance = mEndSizeVariance;
    copy->mEmitAngle = mEmitAngle;
    copy->mEmitAngleVariance = mEmitAngleVariance;
    copy->mSpeed = mSpeed;
    copy->mSpeedVariance = mSpeedVariance;
    copy->mGravityX = mGravityX;
    copy->mGravityY = mGravityY;
    copy->mRadialAcceleration = mRadialAcceleration;
    copy->mRadialAccelerationVariance = mRadialAccelerationVariance;
    copy->mTangentialAcceleration = mTangentialAcceleration;
    copy->mTangentialAccelerationVariance = mTangentialAccelerationVariance;
    copy->mMaxRadius = mMaxRadius;
    copy->mMaxRadiusVariance = mMaxRadiusVariance;
    copy->mMinRadius = mMinRadius;
    copy->mRotatePerSecond = mRotatePerSecond;
    copy->mRotatePerSecondVariance = mRotatePerSecondVariance;
    copy->mStartColor = mStartColor;
    copy->mStartColorVariance = mStartColorVariance;
    copy->mEndColor = mEndColor;
    copy->mEndColorVariance = mEndColorVariance;
    copy->mBlendFuncSource = mBlendFuncSource;
    copy->mBlendFuncDestination = mBlendFuncDestination;
    
    return copy;
}

- (void)dealloc
{
    if (mVertexBuffer)
        glDeleteBuffers(1, &mVertexBuffer);
    
    free(mParticles);
    free(mPointSprites);
    
}

- (void)advanceTime:(double)passedTime
{
    // advance existing particles
    
    int particleIndex = 0;    
    while (particleIndex < mNumParticles)
    {
        // get the particle for the current particle index
        SXParticle *currentParticle = &mParticles[particleIndex];
        
        // if the current particle is alive then update it
        if (currentParticle->timeToLive > passedTime) 
        {
            [self advanceParticle:currentParticle byTime:passedTime];
            particleIndex++;
        } 
        else 
        {            
            if (particleIndex != mNumParticles - 1)
                mParticles[particleIndex] = mParticles[mNumParticles - 1];
            
            mNumParticles--;
            
            if (!mNumParticles)
                [self dispatchEvent:[SPEvent eventWithType:@"complete"]];
        }
    }
    
    // create and advance new particles
    
    if (mBurstTime > 0)
    {
        float timeBetweenParticles = mLifespan / mMaxNumParticles;   
        mFrameTime += passedTime;
        while (mFrameTime > 0)
        {
            [self addParticleWithElapsedTime:mFrameTime];
            mFrameTime -= timeBetweenParticles;
        }
        
        if (mBurstTime != DBL_MAX)
            mBurstTime = MAX(0.0, mBurstTime - passedTime);
    }
    
    // update point sprites data (except color, which is updated in 'render:')
    
    for (int i=0; i<mNumParticles; ++i)
    {    
        SXParticle *particle = &mParticles[i];
        SXPointSprite *pointSprite = &mPointSprites[i];
        pointSprite->x = particle->x;
        pointSprite->y = particle->y;
        pointSprite->size = MAX(0, particle->size);
    }
}

- (void)advanceParticle:(SXParticle *)particle byTime:(double)passedTime
{
    passedTime = MIN(passedTime, particle->timeToLive);
    particle->timeToLive -= passedTime;
    
    if (mEmitterType == SXParticleEmitterTypeRadial) 
    {
        particle->rotation += particle->rotationDelta * passedTime;
        particle->radius   -= particle->radiusDelta   * passedTime;
        particle->x = mEmitterX - cosf(particle->rotation) * particle->radius;
        particle->y = mEmitterY - sinf(particle->rotation) * particle->radius;
        
        if (particle->radius < mMinRadius)
            particle->timeToLive = 0;                
    } 
    else 
    {
        float distanceX = particle->x - particle->startX;
        float distanceY = particle->y - particle->startY;                
        float distanceScalar = MAX(0.01f, sqrtf(SQ(distanceX) + SQ(distanceY)));
        
        float radialX = distanceX / distanceScalar;
        float radialY = distanceY / distanceScalar;
        float tangentialX = radialX;
        float tangentialY = radialY;
        
        radialX *= particle->radialAcceleration;
        radialY *= particle->radialAcceleration;
        
        float newY = tangentialX;
        tangentialX = -tangentialY * particle->tangentialAcceleration;
        tangentialY = newY * particle->tangentialAcceleration;
        
        particle->velocityX += passedTime * (mGravityX + radialX + tangentialX);
        particle->velocityY += passedTime * (mGravityY + radialY + tangentialY);
        particle->x += particle->velocityX * passedTime;
        particle->y += particle->velocityY * passedTime;
    }
    
    particle->size += particle->sizeDelta * passedTime;
    
    // Update the particle's color
    particle->color.red   += particle->colorDelta.red   * passedTime;
    particle->color.green += particle->colorDelta.green * passedTime;
    particle->color.blue  += particle->colorDelta.blue  * passedTime;
    particle->color.alpha += particle->colorDelta.alpha * passedTime;
}

- (void)addParticleWithElapsedTime:(double)time
{    
    if (mNumParticles >= mMaxNumParticles)
        return;
    
    float lifespan = RANDOM_VARIANCE(mLifespan, mLifespanVariance);
    if (lifespan <= 0.0f) 
        return;
    
    SXParticle *particle = &mParticles[mNumParticles++];
    particle->timeToLive = lifespan;
    
    particle->x = RANDOM_VARIANCE(mEmitterX, mEmitterXVariance);
    particle->y = RANDOM_VARIANCE(mEmitterY, mEmitterYVariance);
    particle->startX = mEmitterX;
    particle->startY = mEmitterY;
    
    float angle = RANDOM_VARIANCE(mEmitAngle, mEmitAngleVariance);
    float speed = RANDOM_VARIANCE(mSpeed, mSpeedVariance);
    particle->velocityX = speed * cosf(angle);
    particle->velocityY = speed * sinf(angle);
    
    particle->radius = RANDOM_VARIANCE(mMaxRadius, mMaxRadiusVariance);
    particle->radiusDelta = mMaxRadius / lifespan;
    particle->rotation = RANDOM_VARIANCE(mEmitAngle, mEmitAngleVariance);
    particle->rotationDelta = RANDOM_VARIANCE(mRotatePerSecond, mRotatePerSecondVariance);    
    particle->radialAcceleration = RANDOM_VARIANCE(mRadialAcceleration, mRadialAccelerationVariance);
    particle->tangentialAcceleration = RANDOM_VARIANCE(mTangentialAcceleration, mTangentialAccelerationVariance);
    
    float particleStartSize  = MAX(0.1f, RANDOM_VARIANCE(mStartSize, mStartSizeVariance));
    float particleFinishSize = MAX(0.1f, RANDOM_VARIANCE(mEndSize, mEndSizeVariance)); 
    particle->size = particleStartSize;
    particle->sizeDelta = (particleFinishSize - particleStartSize) / lifespan;
    
    SXColor4f startColor = RANDOM_COLOR_VARIANCE(mStartColor, mStartColorVariance);
    SXColor4f endColor   = RANDOM_COLOR_VARIANCE(mEndColor,   mEndColorVariance);

    SXColor4f colorDelta;
    colorDelta.red   = (endColor.red   - startColor.red)   / lifespan;
    colorDelta.green = (endColor.green - startColor.green) / lifespan;
    colorDelta.blue  = (endColor.blue  - startColor.blue)  / lifespan;
    colorDelta.alpha = (endColor.alpha - startColor.alpha) / lifespan;
    
    particle->color = startColor;
    particle->colorDelta = colorDelta;
    
    [self advanceParticle:particle byTime:time];
}

- (void)render:(SPRenderSupport *)support
{
    if (mNumParticles == 0) return;
    
    float alpha = self.alpha;
    [support bindTexture:mTexture];
    
    // we need to know the scale value in respect to the stage
    SPDisplayObject *object = self;
    float totalScale = mScaleFactor;
    while (object) { totalScale *= object.scaleX; object = object.parent; }
    
    // update color and scale data
    for (int i=0; i<mNumParticles; ++i)
    {
        mPointSprites[i].size = mParticles[i].size * totalScale;
        SXColor4f pColor4f = mParticles[i].color;
        mPointSprites[i].color = (GLubyte)(CLAMP(pColor4f.red,   0.0f, 1.0f) * 255) |
                                 (GLubyte)(CLAMP(pColor4f.green, 0.0f, 1.0f) * 255) << 8 |
                                 (GLubyte)(CLAMP(pColor4f.blue,  0.0f, 1.0f) * 255) << 16 |
                                 (GLubyte)(CLAMP(pColor4f.alpha, 0.0f, 1.0f) * alpha * 255) << 24;
    }
    
    if (!mVertexBuffer)
        glGenBuffers(1, &mVertexBuffer);
    
    // update vertex buffer
    glBindBuffer(GL_ARRAY_BUFFER, mVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SXPointSprite) * mMaxNumParticles, mPointSprites, GL_DYNAMIC_DRAW);
    
    // enable drawing states
    glEnable(GL_POINT_SPRITE_OES);    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);  
    glEnableClientState(GL_POINT_SIZE_ARRAY_OES);
    
    // point to specific data
    glBlendFunc(mBlendFuncSource, mBlendFuncDestination);
    glVertexPointer(2, GL_FLOAT, sizeof(SXPointSprite), 0);
    glColorPointer(4, GL_UNSIGNED_BYTE, sizeof(SXPointSprite), (void *)offsetof(SXPointSprite, color));
    glPointSizePointerOES(GL_FLOAT, sizeof(SXPointSprite), (void *)offsetof(SXPointSprite, size));
    glTexEnvi(GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE);
    
    // draw particles!
    glDrawArrays(GL_POINTS, 0, mNumParticles);
    
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);   
    glDisableClientState(GL_POINT_SIZE_ARRAY_OES);    
    glDisable(GL_POINT_SPRITE_OES);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    // reset blending function
    [support reset];
}

- (void)start
{
    [self startBurst:DBL_MAX];
}

- (void)startBurst:(double)duration
{
    mBurstTime = fabs(duration);
}

- (void)stop
{
    mBurstTime = 0;
}

- (SPRectangle*)boundsInSpace:(SPDisplayObject*)targetCoordinateSpace
{
    // we return an empty rectangle (width and height are zero), but with the correct
    // values for x and y.
    
    SPMatrix *transformationMatrix = [self transformationMatrixToSpace:targetCoordinateSpace];
    SPPoint *point = [SPPoint pointWithX:0.0f y:0.0f];
    SPPoint *transformedPoint = [transformationMatrix transformPoint:point];
    return [SPRectangle rectangleWithX:transformedPoint.x y:transformedPoint.y 
                                 width:0.0f height:0.0f];
}

- (BOOL)isComplete
{
    return NO;
}

#pragma mark XML parsing

- (void)parseConfiguration:(NSString *)path
{
    if (!path) return;
    
    float scaleFactor = [SPStage contentScaleFactor];
    mPath = [SPUtils absolutePathToFile:path withScaleFactor:scaleFactor];    
    if (!mPath) [NSException raise:SP_EXC_FILE_NOT_FOUND format:@"file not found: %@", path];
    
//    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSData *xmlData = [[NSData alloc] initWithContentsOfFile:mPath];
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:xmlData];
    
    xmlParser.delegate = self;
    BOOL success = [xmlParser parse];
    
    if (!success)    
        [NSException raise:SP_EXC_FILE_INVALID 
                    format:@"could not parse emitter configuration %@. Error code: %d, domain: %@", 
         path, xmlParser.parserError.code, xmlParser.parserError.domain];
    
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qName 
    attributes:(NSDictionary *)attributeDict 
{
    elementName = [elementName lowercaseString];
    
    if (!mTexture && [elementName isEqualToString:@"texture"])
    {
        NSString *b64Data = [attributeDict valueForKey:@"data"];
        if (b64Data)
        {
            NSData *imageData = [[NSData dataWithBase64EncodedString:b64Data] gzipInflate];
            mTexture = [[SPTexture alloc] initWithContentsOfImage:[UIImage imageWithData:imageData]];
        }
        else
        {
            NSString *filename = [attributeDict valueForKey:@"name"];
            NSString *folder = [mPath stringByDeletingLastPathComponent];
            NSString *absolutePath = [folder stringByAppendingPathComponent:filename];
            mTexture = [[SPTexture alloc] initWithContentsOfFile:absolutePath];
        }
    }
    else if ([elementName isEqualToString:@"sourcepositionvariance"])
    {
        mEmitterXVariance = [[attributeDict objectForKey:@"x"] floatValue];
        mEmitterYVariance = [[attributeDict objectForKey:@"y"] floatValue];
    }
    else if ([elementName isEqualToString:@"gravity"])
    {
        mGravityX = [[attributeDict objectForKey:@"x"] floatValue];
        mGravityY = [[attributeDict objectForKey:@"y"] floatValue];        
    }
    else if ([elementName isEqualToString:@"emittertype"])
        mEmitterType = (SXParticleEmitterType)[[attributeDict objectForKey:@"value"] intValue];
    else if ([elementName isEqualToString:@"maxparticles"])
        self.maxNumParticles = [[attributeDict objectForKey:@"value"] floatValue];    
    else if ([elementName isEqualToString:@"particlelifespan"])
        self.lifespan = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"particlelifespanvariance"])
        mLifespanVariance = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"startparticlesize"])
        mStartSize = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"startparticlesizevariance"])
        mStartSizeVariance = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"finishparticlesize"])
        mEndSize = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"finishparticlesizevariance"])
        mEndSizeVariance = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"angle"])
        mEmitAngle = SP_D2R([[attributeDict objectForKey:@"value"] floatValue]);
    else if ([elementName isEqualToString:@"anglevariance"])
        mEmitAngleVariance = SP_D2R([[attributeDict objectForKey:@"value"] floatValue]);
    else if ([elementName isEqualToString:@"speed"])
        mSpeed = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"speedvariance"])
        mSpeedVariance = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"radialacceleration"])
        mRadialAcceleration = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"radialaccelvariance"])
        mRadialAccelerationVariance = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"tangentialacceleration"])
        mTangentialAcceleration = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"tangentialaccelvariance"])
        mTangentialAccelerationVariance = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"maxradius"])
        mMaxRadius = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"maxradiusvariance"])
        mMaxRadiusVariance = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"minradius"])
        mMinRadius = [[attributeDict objectForKey:@"value"] floatValue];
    else if ([elementName isEqualToString:@"rotatepersecond"])
        mRotatePerSecond = SP_D2R([[attributeDict objectForKey:@"value"] floatValue]);
    else if ([elementName isEqualToString:@"rotatepersecondvariance"])
        mRotatePerSecondVariance = SP_D2R([[attributeDict objectForKey:@"value"] floatValue]);
    else if ([elementName isEqualToString:@"startcolor"])
        mStartColor = [self colorFromDictionary:attributeDict];
    else if ([elementName isEqualToString:@"startcolorvariance"])
        mStartColorVariance = [self colorFromDictionary:attributeDict];
    else if ([elementName isEqualToString:@"finishcolor"])
        mEndColor = [self colorFromDictionary:attributeDict];
    else if ([elementName isEqualToString:@"finishcolorvariance"])
        mEndColorVariance = [self colorFromDictionary:attributeDict];
    else if ([elementName isEqualToString:@"blendfuncsource"])
        mBlendFuncSource = [[attributeDict objectForKey:@"value"] intValue];
    else if ([elementName isEqualToString:@"blendfuncdestination"])
        mBlendFuncDestination = [[attributeDict objectForKey:@"value"] intValue];    
}

- (SXColor4f)colorFromDictionary:(NSDictionary *)dictionary
{
    SXColor4f color;
    color.red   = [[dictionary objectForKey:@"red"]   floatValue];
    color.green = [[dictionary objectForKey:@"green"] floatValue];
    color.blue  = [[dictionary objectForKey:@"blue"]  floatValue];
    color.alpha = [[dictionary objectForKey:@"alpha"] floatValue];
    return color;
}

- (void)setLifespan:(float)value
{
    mLifespan = MAX(0.01, value);
}

- (void)setMaxNumParticles:(int)value
{
    mMaxNumParticles = value;
    mNumParticles = MIN(mMaxNumParticles, mNumParticles);
    mParticles = realloc(mParticles, sizeof(SXParticle) * value);
    mPointSprites = realloc(mPointSprites, sizeof(SXPointSprite) * value);
}

@end
