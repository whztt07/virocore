//
//  VROSample.m
//  ViroRenderer
//
//  Created by Raj Advani on 10/13/15.
//  Copyright © 2015 Raj Advani. All rights reserved.
//

#import <Photos/Photos.h>
#import "VROSample.h"
#import "opencv2/imgcodecs/ios.h"
#import "opencv2/imgproc/imgproc.hpp"
#import "VROImageTracker.h"
#import "VROSampleARDelegate.h"
#import "VROARDraggableNode.h"


typedef NS_ENUM(NSInteger, VROSampleScene) {
    VROSampleSceneOBJ = 0,
    VROSampleSceneTorus,
    VROSampleSceneCamera,
    VROSampleSceneBox,
    VROSampleSceneText,
    VROSampleSceneVideoSphere,
    VROSampleSceneNormalMap,
    VROSampleSceneStereoscopic,
    VROSampleSceneFBX,
    VROSampleSceneARPlane,
    VROSampleSceneARDraggableNode,
    VROSampleScenePortal,
    VROSampleSceneNumScenes,
};

@interface VROSample () <VROEventDelegateProtocol, VROPhysicsBodyDelegateProtocol>

@property (readwrite, nonatomic) std::shared_ptr<VRODriver> driver;
@property (readwrite, nonatomic) BOOL tapEnabled;
@property (readwrite, nonatomic) float torusAngle;
@property (readwrite, nonatomic) float boxAngle;
@property (readwrite, nonatomic) float boxVideoAngle;
@property (readwrite, nonatomic) float objAngle;
@property (readwrite, nonatomic) int sceneIndex;
@property (readwrite, nonatomic) std::shared_ptr<VROVideoTexture> videoTexture;
@property (readwrite, nonatomic) std::shared_ptr<VROEventDelegateiOS> delegate;
@property (readwrite, nonatomic) std::shared_ptr<VROSampleARDelegate> sessionARDelegate;
@property (readwrite, nonatomic) std::shared_ptr<VROSceneController> sceneController;
@property (readwrite, nonatomic) std::shared_ptr<VROPortalTraversalListener> portalTraversalListener;
@property (nonatomic, copy) id clickBlock;

// VROEventDelegateProtocol
- (void) onHover:(int)source isHovering:(bool)isHovering;
- (void) onClick:(int)source clickState:(VROEventDelegate::ClickState)clickState;
- (void) onFuse:(int)source;
- (void) onDrag:(int)source posX:(float)x posY:(float)y posZ:(float)y;

// VROPhysicsBodyDelegateProtocol
- (void)onCollided:(std::string) bodyTagB
         collision:(VROPhysicsBody::VROCollision) collision;
@end

@implementation VROSample  {
    std::vector<std::shared_ptr<VROPhysicsBodyDelegateiOS>> _physicsDeelgates;
    std::shared_ptr<VRONode> _testPhysicsNode;
}



- (std::shared_ptr<VROSceneController>)loadSceneWithIndex:(int)index {
    // uncomment the below line to test the AR library, look for logs "Found corner".
    //[self runImageDetection];

    int modulo = index % VROSampleSceneNumScenes;
    switch (modulo) {
        case VROSampleSceneTorus:
            return [self loadTorusScene];
        case VROSampleSceneCamera:
            return [self loadCameraScene];
        case VROSampleSceneVideoSphere:
            return [self loadVideoSphereScene];
        case VROSampleSceneText:
            return [self loadTextScene];
        case VROSampleSceneOBJ:
            return [self loadOBJScene];
        case VROSampleSceneNormalMap:
            return [self loadNormalMapScene];
        case VROSampleSceneBox:
            return [self loadBoxScene];
        case VROSampleSceneStereoscopic:
            return [self loadStereoBackground];
        case VROSampleSceneFBX:
            return [self loadFBXScene];
        case VROSampleSceneARPlane:
            return [self loadARPlaneScene];
        case VROSampleSceneARDraggableNode:
            return [self loadARDraggableNodeScene];
        case VROSampleScenePortal:
            return [self loadPortalScene];
        default:
            break;
    }
    
    return [self loadPhysicsScene];
}

- (std::shared_ptr<VROTexture>) niagaraTexture {
    VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;
    
    std::vector<std::shared_ptr<VROImage>> cubeImages =  {
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"px"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"nx"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"py"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"ny"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"pz"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"nz"], format)
    };
    
    return std::make_shared<VROTexture>(format, cubeImages);
}

- (std::shared_ptr<VROTexture>) cloudTexture {
    VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;
    
    std::vector<std::shared_ptr<VROImage>> cubeImages =  {
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"px1.jpg"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"nx1.jpg"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"py1.jpg"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"ny1.jpg"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"pz1.jpg"], format),
        std::make_shared<VROImageiOS>([UIImage imageNamed:@"nz1.jpg"], format)
    };
    
    return std::make_shared<VROTexture>(format, cubeImages);
}

- (std::shared_ptr<VROTexture>) westlakeTexture {
    return std::make_shared<VROTexture>(VROTextureInternalFormat::RGBA8, VROMipmapMode::None,
                                        std::make_shared<VROImageiOS>([UIImage imageNamed:@"360_westlake.jpg"],
                                                                      VROTextureInternalFormat::RGBA8));
}

- (void) runImageDetection {

    // fetch the target image to find
    UIImage *targetImage = [UIImage imageNamed:@"ben.jpg"];

    cv::Mat targetMat = cv::Mat();
    UIImageToMat(targetImage, targetMat);

    // initialize the tracker with the target image
    std::shared_ptr<VROImageTracker> tracker = VROImageTracker::createImageTracker(targetMat);

    // fetch the scene image (the "camera" feed)
    cv::Mat sceneMat;
    UIImage *sceneImage = [UIImage imageNamed:@"screenshot.png"];
    UIImageToMat(sceneImage, sceneMat);

    // find the target.
    std::shared_ptr<VROImageTrackerOutput> output = tracker->findTarget(sceneMat);

    if (output->found) {
        for (int i = 0; i < output->corners.size(); i++) {
            NSLog(@"Found corner point: %f %f", output->corners[i].x, output->corners[i].y);
        }
    } else {
        NSLog(@"Couldn't find target in given image");
    }
}

- (std::shared_ptr<VROSceneController>)loadPortalScene {
    std::shared_ptr<VROARSceneController> sceneController = std::make_shared<VROARSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROLight> light = std::make_shared<VROLight>(VROLightType::Spot);
    light->setColor({ 1.0, 0.5, 0.5 });
    light->setPosition( { 0, 0, 0 });
    light->setDirection( { 0, 0, -1.0 });
    light->setAttenuationStartDistance(50);
    light->setAttenuationEndDistance(75);
    light->setSpotInnerAngle(70);
    light->setSpotOuterAngle(120);
    
    std::shared_ptr<VROLight> ambient = std::make_shared<VROLight>(VROLightType::Ambient);
    ambient->setColor({ 1.0, 1.0, 1.0 });
    ambient->setIntensity(250);
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->addLight(light);
    rootNode->addLight(ambient);
    
    std::shared_ptr<VROPortal> portalNode = std::make_shared<VROPortal>();
    portalNode->setBackgroundCube([self cloudTexture]);
    portalNode->addChildNode([self loadFBXModel]);
    portalNode->setPassable(true);
    portalNode->setScale({0.1, 0.1, 0.1});
    portalNode->setPosition({0, 0, -2});
    portalNode->setName("Portal");

    std::shared_ptr<VROPortalFrame> portalNodeEntrance = [self loadPortalEntrance];
    portalNodeEntrance->setOpacity(0);
    portalNodeEntrance->setScale({0, 0, 0});
    portalNodeEntrance->setRotationEuler({ 0, 0, 0 });
    portalNode->setPortalEntrance(portalNodeEntrance);
    
    rootNode->addChildNode(portalNode);
    
    std::shared_ptr<VRONode> occludingInnerSurface = std::make_shared<VRONode>();
    occludingInnerSurface->setGeometry(VROSurface::createSurface(15, 15));
    occludingInnerSurface->setPosition({0, 0, -1});
    
    // Uncomment to test a large surface inside the portal; it should clip against the
    // portal edges
    //portalNode->addChildNode(occludingInnerSurface);
    
    std::shared_ptr<VRONode> occludingBox = std::make_shared<VRONode>();
    occludingBox->setGeometry(VROBox::createBox(0.3, 0.3, 0.3));
    occludingBox->setPosition({0.2, 0, -1});
    occludingBox->getGeometry()->getMaterials().front()->setLightingModel(VROLightingModel::Lambert);
    occludingBox->getGeometry()->getMaterials().front()->getDiffuse().setColor({1.0, 0.0, 0.0, 1.0});
    
    //rootNode->addChildNode(occludingBox);
    
    std::vector<VROVector3f> positions;
    positions.push_back({0, 6, -8});
    positions.push_back({0, -3, -2});
    positions.push_back({0, -8, -2});
    positions.push_back({-5, 0, -2});
    
    for (VROVector3f position : positions) {
        std::shared_ptr<VROPortal> innerPortalNode = std::make_shared<VROPortal>();
        innerPortalNode->setPosition(position);
        innerPortalNode->setBackgroundSphere([self westlakeTexture]);
        
        std::shared_ptr<VROPortalFrame> innerPortalFrame = [self loadPortalEntrance];
        innerPortalFrame->setScale({0.25, 0.25, 0.25});
        innerPortalNode->setPortalEntrance(innerPortalFrame);
        
        std::shared_ptr<VRONode> innerPortalNodeContent = std::make_shared<VRONode>();
        innerPortalNodeContent->setGeometry(VROBox::createBox(0.5, 0.5, 0.5));
        innerPortalNodeContent->getGeometry()->getMaterials().front()->getDiffuse().setColor({0.0, 0.0, 1.0, 1.0});
        innerPortalNodeContent->setPosition({0.2, 0, -1});
        innerPortalNode->addChildNode(innerPortalNodeContent);
        //innerPortalNode->setPassable(true);
        
        std::shared_ptr<VROAction> action = VROAction::perpetualPerFrameAction([self] (VRONode *const node, float seconds) {
            node->setRotation({ 0, (float)(node->getRotationEuler().y + 0.15), 0});
            return true;
        });
        innerPortalNodeContent->runAction(action);
        
        portalNode->addChildNode(innerPortalNode);
    }
    
    std::vector<VROVector3f> sidePositions;
    sidePositions.push_back({-0.5, -1, -2.2});
    sidePositions.push_back({-0.5, 1, -4});
    
    for (VROVector3f sidePosition : sidePositions) {
        std::shared_ptr<VROPortal> sidePortalNode = std::make_shared<VROPortal>();
        sidePortalNode->setPosition(sidePosition);
        sidePortalNode->setBackgroundCube([self niagaraTexture]);
        
        std::shared_ptr<VROPortalFrame> sidePortalFrame = [self loadPortalEntrance];
        sidePortalFrame->setScale({0.06, 0.06, 0.06});
        sidePortalFrame->setRotationEuler({0, M_PI_4, 0});
        sidePortalNode->setPortalEntrance(sidePortalFrame);
        
        std::shared_ptr<VRONode> sidePortalNodeContent = std::make_shared<VRONode>();
        sidePortalNodeContent->setGeometry(VROBox::createBox(0.6, 0.6, 0.6));
        sidePortalNodeContent->setPosition({0.2, 0, -1});
        sidePortalNode->addChildNode(sidePortalNodeContent);
        
        rootNode->addChildNode(sidePortalNode);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VROTransaction::begin();
        VROTransaction::setAnimationDuration(2.5);
        VROTransaction::setTimingFunction(VROTimingFunctionType::Bounce);
        
        portalNodeEntrance->setScale({1, 1, 1});
        portalNodeEntrance->setOpacity(1);
        
        VROTransaction::commit();
    });
    
    self.portalTraversalListener = std::make_shared<VROPortalTraversalListener>(scene);
    self.view.frameSynchronizer->addFrameListener(self.portalTraversalListener);
    
    std::shared_ptr<VRONodeCamera> camera = std::make_shared<VRONodeCamera>();
    scene->getRootNode()->setCamera(camera);
    [self.view setPointOfView:scene->getRootNode()];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VROTransaction::begin();
        VROTransaction::setAnimationDuration(10);
        camera->setPosition({3, 0, -5});
        VROTransaction::commit();
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VROTransaction::begin();
        VROTransaction::setAnimationDuration(5);
        camera->setPosition({-3, 0, -5});
        VROTransaction::commit();
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VROTransaction::begin();
        VROTransaction::setAnimationDuration(10);
        camera->setPosition({0, 0, 0});
        VROTransaction::commit();
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VROTransaction::begin();
        VROTransaction::setAnimationDuration(10);
        camera->setPosition({0, 0, -5});
        VROTransaction::commit();
    });
    
    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadVideoSphereScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROLight> light = std::make_shared<VROLight>(VROLightType::Spot);
    light->setColor({ 1.0, 0.9, 0.9 });
    light->setPosition( { 0, 0, 0 });
    light->setDirection( { 0, 0, -1.0 });
    light->setAttenuationStartDistance(5);
    light->setAttenuationEndDistance(10);
    light->setSpotInnerAngle(0);
    light->setSpotOuterAngle(20);
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->addLight(light);
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"surfing" ofType:@"mp4"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    std::string url = std::string([[fileURL description] UTF8String]);
    
    self.videoTexture = std::make_shared<VROVideoTextureiOS>();
    self.videoTexture->loadVideo(url, [self.view frameSynchronizer], self.driver);
    self.videoTexture->play();
    
    rootNode->setBackgroundSphere(self.videoTexture);
    return sceneController;
}

- (std::shared_ptr<VRONode>) newTorusWithPosition:(VROVector3f)position {
    VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;

    std::shared_ptr<VROTorusKnot> torus = VROTorusKnot::createTorusKnot(3, 8, 0.2, 256, 32);
    std::shared_ptr<VROMaterial> material = torus->getMaterials()[0];
    material->setLightingModel(VROLightingModel::Lambert);
    material->getReflective().setTexture([self cloudTexture]);
    material->getSpecular().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                    std::make_shared<VROImageiOS>([UIImage imageNamed:@"specular"], format)));

    
    std::shared_ptr<VRONode> torusNode = std::make_shared<VRONode>();
    torusNode->setGeometry(torus);
    torusNode->setPosition(position);
    
    return torusNode;
}

- (std::shared_ptr<VROSceneController>)loadTorusScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROLight> light = std::make_shared<VROLight>(VROLightType::Spot);
    light->setColor({ 1.0, 0.3, 0.3 });
    light->setPosition( { 0, 0, 0 });
    light->setDirection( { 0, 0, -1.0 });
    light->setAttenuationStartDistance(5);
    light->setAttenuationEndDistance(10);
    light->setSpotInnerAngle(0);
    light->setSpotOuterAngle(20);
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->addLight(light);
    rootNode->setBackgroundCube([self cloudTexture]);
    
    float d = 5;
    
    rootNode->addChildNode([self newTorusWithPosition:{ 0,  0, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ d,  0, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ 0,  d, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ d,  d, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ d, -d, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{-d,  0, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ 0, -d, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{-d,  d, -d}]);
    rootNode->addChildNode([self newTorusWithPosition:{-d, -d, -d}]);
    
    rootNode->addChildNode([self newTorusWithPosition:{ 0,  0, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ d,  0, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ 0,  d, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ d,  d, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ d, -d, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{-d,  0, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{ 0, -d, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{-d,  d, d}]);
    rootNode->addChildNode([self newTorusWithPosition:{-d, -d, d}]);
    
    std::shared_ptr<VROAction> action = VROAction::perpetualPerFrameAction([self] (VRONode *const node, float seconds) {
        self.torusAngle += .015;
        for (std::shared_ptr<VRONode> &torusNode : node->getChildNodes()) {
            torusNode->setRotation({ 0, self.torusAngle, 0});
        }
        
        return true;
    });
    
    rootNode->runAction(action);
    self.tapEnabled = true;
    return sceneController;
}

- (void)hoverOn:(std::shared_ptr<VRONode>)node {
    std::shared_ptr<VROMaterial> material = node->getGeometry()->getMaterials().front();
    
    VROTransaction::begin();
    VROTransaction::setAnimationDuration(0.2);
    material->getDiffuse().setColor( {1.0, 1.0, 1.0, 1.0 } );
    material->getReflective().setTexture([self cloudTexture]);
    VROTransaction::commit();
}

- (void)hoverOff:(std::shared_ptr<VRONode>)node {
    std::shared_ptr<VROMaterial> material = node->getGeometry()->getMaterials().front();
    
    VROTransaction::begin();
    VROTransaction::setAnimationDuration(0.2);
    material->getDiffuse().setColor( {1.0, 1.0, 1.0, 1.0 } );
    material->getReflective().clear();
    VROTransaction::commit();
}

- (std::shared_ptr<VROSceneController>)loadPhysicsScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    
    std::shared_ptr<VROBox> groundBox = VROBox::createBox(40, 1, 40);
    groundBox->setName("Box 2");
    std::shared_ptr<VROMaterial> materialGround = groundBox->getMaterials()[0];
    materialGround->getDiffuse().setColor({1.0, 1.0, 1.0, 1.0});
    materialGround->setLightingModel(VROLightingModel::Constant);
    materialGround->setCullMode(VROCullMode::None);

    std::shared_ptr<VRONode> groundNode = std::make_shared<VRONode>();
    groundNode->setGeometry(groundBox);
    groundNode->setPosition({0, -10, -5});
    groundNode->setTag("GROUND");
    rootNode->addChildNode(groundNode);

    self.delegate = std::make_shared<VROEventDelegateiOS>(self);
    self.delegate->setEnabledEvent(VROEventDelegate::EventAction::OnClick, true);
    groundNode->setEventDelegate(self.delegate);
    
    std::shared_ptr<VROPhysicsBody> physicsGround = groundNode->initPhysicsBody(VROPhysicsBody::VROPhysicsBodyType::Static,
                                                                                0, nullptr);
    std::shared_ptr<VROPhysicsWorld> physicsWorld = scene->getPhysicsWorld();
    physicsWorld->setGravity({0,-9.81f,0});
    physicsWorld->addPhysicsBody(physicsGround);
     physicsGround->setRestitution(0);
    
    __weak VROSample *w_sample = self;
    self.clickBlock =^ {
        if (w_sample){
            std::vector<float> params = {0.1,0.1, 0.1};
            std::shared_ptr<VROPhysicsShape> shape = std::make_shared<VROPhysicsShape>(VROPhysicsShape::VROShapeType::Box, params);
            //physicsWorld->findCollisionsWithRay({0,0,0}, {0,0,-10}, false, "test2");
            //physicsWorld->findCollisionsWithShape({0,0, -7}, {0,0, -7}, shape, "test3");
            //[w_sample modifyPhysicsNodeTest];
            [w_sample createPhysicsBoxAt:{0,10,-4} withWorld:physicsWorld withRoot:rootNode withTag:"box3"];
        }
    };
    
    //_testPhysicsNode = [self createPhysicsBoxAt:{0,90,-6} withWorld:physicsWorld withRoot:rootNode withTag:"box test scale"];
    return sceneController;
}

- (void)modifyPhysicsNodeTest{
    _testPhysicsNode->setScale(VROVector3f(3,3,3));
}

- (std::shared_ptr<VRONode>)createPhysicsBoxAt:(VROVector3f)position
                 withWorld:(std::shared_ptr<VROPhysicsWorld>)physicsWorld
                  withRoot:(std::shared_ptr<VRONode>) rootNode
                   withTag:(std::string)tag{
        
    std::shared_ptr<VROBox> box = VROBox::createBox(1, 1, 1);
    box->setName("Box 1");
    std::shared_ptr<VROMaterial> material = box->getMaterials()[0];
    material->getDiffuse().setColor({0.6, 0.3, 0.3, 0.5});
    material->setLightingModel(VROLightingModel::Constant);
    material->setCullMode(VROCullMode::None);
    
    std::shared_ptr<VRONode> boxNode = std::make_shared<VRONode>();
    boxNode->setGeometry(box);
    boxNode->setTag(tag);
    boxNode->setPosition(position);
    rootNode->addChildNode(boxNode);
    std::shared_ptr<VROPhysicsBody> physicsBody
        = boxNode->initPhysicsBody(VROPhysicsBody::VROPhysicsBodyType::Dynamic, 5, nullptr);
    
    std::shared_ptr<VROPhysicsBodyDelegateiOS> delegate = std::make_shared<VROPhysicsBodyDelegateiOS>(self);
    _physicsDeelgates.push_back(delegate);
    physicsBody->setPhysicsDelegate(delegate);
    physicsBody->setRestitution(0);
    physicsBody->setUseGravity(true);
    physicsWorld->addPhysicsBody(physicsBody);
    return boxNode;
}

- (void)onCollided:(std::string) bodyKey
         collision:(VROPhysicsBody::VROCollision) collision{
    NSLog(@"Viro on box collided! key: %s tag: %s norm %f, %f, %f", bodyKey.c_str(), collision.collidedBodyTag.c_str(),
          collision.collidedPoint.x, collision.collidedPoint.y, collision.collidedPoint.z);
}

#pragma mark default implementations for VRTEventDelegateProtocol
-(void)onHover:(int)source isHovering:(bool)isHovering {
    //No-op
}

-(void)onClick:(int)source clickState:(VROEventDelegate::ClickState)clickState{
    if (clickState == VROEventDelegate::ClickState::Clicked){
        [self.clickBlock invoke];
    }
}

-(void)onFuse:(int)source{
    //No-op
}

- (void) onDrag:(int)source posX:(float)x posY:(float)y posZ:(float)y {
    // No-op
}

- (std::shared_ptr<VROSceneController>)loadBoxScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->setBackgroundSphere([self westlakeTexture]);
    
    std::shared_ptr<VROLight> ambient = std::make_shared<VROLight>(VROLightType::Ambient);
    ambient->setColor({ 0.6, 0.6, 0.6 });
    
    std::shared_ptr<VROLight> spotRed = std::make_shared<VROLight>(VROLightType::Spot);
    spotRed->setColor({ 1.0, 0.0, 0.0 });
    spotRed->setPosition( { -5, 0, 0 });
    spotRed->setDirection( { 1.0, 0, -1.0 });
    spotRed->setAttenuationStartDistance(20);
    spotRed->setAttenuationEndDistance(30);
    spotRed->setSpotInnerAngle(2.5);
    spotRed->setSpotOuterAngle(5.0);
    
    std::shared_ptr<VROLight> spotBlue = std::make_shared<VROLight>(VROLightType::Spot);
    spotBlue->setColor({ 0.0, 0.0, 1.0 });
    spotBlue->setPosition( { 5, 0, 0 });
    spotBlue->setDirection( { -1.0, 0, -1.0 });
    spotBlue->setAttenuationStartDistance(20);
    spotBlue->setAttenuationEndDistance(30);
    spotBlue->setSpotInnerAngle(2.5);
    spotBlue->setSpotOuterAngle(5.0);
    
    rootNode->addLight(ambient);
    rootNode->addLight(spotRed);
    rootNode->addLight(spotBlue);
    
    VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;
    
    std::shared_ptr<VROTexture> bobaTexture = std::make_shared<VROTexture>(format, VROMipmapMode::Runtime,
                                                                           std::make_shared<VROImageiOS>([UIImage imageNamed:@"boba"], format));
    bobaTexture->setWrapS(VROWrapMode::Repeat);
    bobaTexture->setWrapT(VROWrapMode::Repeat);
    bobaTexture->setMinificationFilter(VROFilterMode::Linear);
    bobaTexture->setMagnificationFilter(VROFilterMode::Linear);
    bobaTexture->setMipFilter(VROFilterMode::Linear);
    
    /*
     Create the box node.
     */
    std::shared_ptr<VROBox> box = VROBox::createBox(2, 2, 2);
    box->setName("Box 1");
    
    std::shared_ptr<VROMaterial> material = box->getMaterials()[0];
    material->setLightingModel(VROLightingModel::Blinn);
    material->getDiffuse().setTexture(bobaTexture);
    material->getDiffuse().setColor({1.0, 1.0, 1.0, 1.0});
    material->getSpecular().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                    std::make_shared<VROImageiOS>([UIImage imageNamed:@"specular"], format)));
    
    /*
     This geometry modifier pushes the first box to the right slightly, by changing _geometry.position.
     */
    std::vector<std::string> modifierCode =  { "uniform float testA;",
                                               "uniform float testB;",
                                               "_geometry.position.x = _geometry.position.x + testA;"
                                             };
    std::shared_ptr<VROShaderModifier> modifier = std::make_shared<VROShaderModifier>(VROShaderEntryPoint::Geometry,
                                                                                      modifierCode);
    
    modifier->setUniformBinder("testA", [](VROUniform *uniform, GLuint location, const VROGeometry &geometry) {
        uniform->setFloat(1.0);
    });
    //material->addShaderModifier(modifier);
    
    /*
     This surface modifier doubles the V tex-coord, making boba.png cover only the top half of the box.
     It then shades the entire surface slightly blue.
     */
    std::vector<std::string> surfaceModifierCode =  {
        "uniform lowp vec3 surface_color;",
        "_surface.diffuse_texcoord.y = _surface.diffuse_texcoord.y * 2.0;"
        "_surface.diffuse_color = vec4(surface_color.xyz, 1.0);"
    };
    std::shared_ptr<VROShaderModifier> surfaceModifier = std::make_shared<VROShaderModifier>(VROShaderEntryPoint::Surface,
                                                                                             surfaceModifierCode);
    
    surfaceModifier->setUniformBinder("surface_color", [](VROUniform *uniform, GLuint location, const VROGeometry &geometry) {
        uniform->setVec3({0.6, 0.6, 1.0});
    });
    //material->addShaderModifier(surfaceModifier);
    
    std::shared_ptr<VRONode> boxParentNode = std::make_shared<VRONode>();
    boxParentNode->setPosition({0, 0, -5});
    
    VROMatrix4f scalePivot;
    scalePivot.translate(1, 1, 0);
    boxParentNode->setScalePivot(scalePivot);
    
    VROMatrix4f rotationPivot;
    rotationPivot.translate(-1, 1, 0);
    //boxParentNode->setRotationPivot(rotationPivot);
    
    std::shared_ptr<VRONode> boxNode = std::make_shared<VRONode>();
    boxNode->setGeometry(box);

    boxParentNode->addChildNode(boxNode);
    rootNode->addChildNode(boxParentNode);
    //boxParentNode->addConstraint(std::make_shared<VROBillboardConstraint>(VROBillboardAxis::All));
    
    /*
     Create a second box node behind the first.
     */
    std::shared_ptr<VROBox> box2 = VROBox::createBox(2, 4, 2);
    box2->setName("Box 2");
    
    std::vector<std::shared_ptr<VROMaterial>> boxMaterials;
    for (int i = 0; i < 6; i ++) {
        std::shared_ptr<VROMaterial> material = std::make_shared<VROMaterial>();
        material->setLightingModel(VROLightingModel::Lambert);
        
        if (i == 0) {
            material->getDiffuse().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                           std::make_shared<VROImageiOS>([UIImage imageNamed:@"boba"], format)));
        }
        else if (i == 1) {
            material->getDiffuse().setColor({ 1.0, 0.0, 0.0, 1.0 });
        }
        else if (i == 2) {
            material->getDiffuse().setColor({ 0.0, 1.0, 0.0, 1.0 });
        }
        else if (i == 3) {
            material->getDiffuse().setColor({ 0.0, 0.0, 1.0, 1.0 });
        }
        else if (i == 4) {
            material->getDiffuse().setColor({ 1.0, 0.0, 1.0, 1.0 });
        }
        else if (i == 5) {
            material->getDiffuse().setColor({ 1.0, 1.0, 0.0, 1.0 });
        }
        
        boxMaterials.push_back(material);
    }
    box2->setMaterials(boxMaterials);
    
    std::shared_ptr<VRONode> boxNode2 = std::make_shared<VRONode>();
    boxNode2->setGeometry(box2);
    boxNode2->setPosition({0, 0, -9});
    
    rootNode->addChildNode(boxNode2);
    
    /*
     Create a third box node behind the second.
     */
    std::shared_ptr<VROBox> box3 = VROBox::createBox(2, 4, 2);
    box3->setName("Box 3");
    
    std::shared_ptr<VROMaterial> material3 = box3->getMaterials()[0];
    material3->setLightingModel(VROLightingModel::Lambert);
    material3->getDiffuse().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                    std::make_shared<VROImageiOS>([UIImage imageNamed:@"boba"], format)));
    material3->getSpecular().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                     std::make_shared<VROImageiOS>([UIImage imageNamed:@"specular"], format)));
    
    std::shared_ptr<VRONode> boxNode3 = std::make_shared<VRONode>();
    boxNode3->setGeometry(box3);
    boxNode3->setPosition({0, 0, -13});
    
    rootNode->addChildNode(boxNode3);
    
    std::shared_ptr<VRONodeCamera> camera = std::make_shared<VRONodeCamera>();
    //camera->setPosition({0, -5, 0});
    
    std::shared_ptr<VRONode> cameraNode = std::make_shared<VRONode>();
    cameraNode->setCamera(camera);
    rootNode->addChildNode(cameraNode);
    
    [self.view setPointOfView:cameraNode];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        VROTransaction::begin();
        VROTransaction::setAnimationDuration(6);
        
        spotRed->setPosition({5, 0, 0});
        spotRed->setDirection({-1, 0, -1});
        
        spotBlue->setPosition({-5, 0, 0});
        spotBlue->setDirection({1, 0, -1});
        
        //cameraNode->setPosition({0, 1, 0});
        //box->setWidth(5);
        //box->setLength(5);
        
        //boxParentNode->setScale({8, 8, 1});
        boxParentNode->setRotationEulerZ(M_PI_2);
        
        VROTransaction::commit();
    });

    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadCameraScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setBackgroundCube([self cloudTexture]);
    
    /*
     Create camera texture.
     */
    int width = 10;
    int height = 10;

    std::shared_ptr<VROCameraTextureiOS> texture = std::make_shared<VROCameraTextureiOS>(VROTextureType::Texture2D);
    texture->initCamera(VROCameraPosition::Back, VROCameraOrientation::Portrait, self.driver);
    texture->play();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        texture->pause();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        texture->play();
    });
    
    std::shared_ptr<VROSurface> surface = VROSurface::createSurface(width, height);
    surface->getMaterials().front()->getDiffuse().setColor({1.0, 1.0, 1.0, 1.0});
    surface->getMaterials().front()->getDiffuse().setTexture(texture);
    
    std::shared_ptr<VRONode> surfaceNode = std::make_shared<VRONode>();
    surfaceNode->setGeometry(surface);
    surfaceNode->setPosition({0, 0, -5.01});
    
    rootNode->addChildNode(surfaceNode);
    
    self.tapEnabled = YES;
    
    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadTextScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->setBackgroundCube([self cloudTexture]);
    
    /*
     Create background for text.
     */
    int width = 10;
    int height = 10;
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"card_main" ofType:@"ktx"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    
    VROTextureFormat format;
    int texWidth;
    int texHeight;
    std::vector<uint32_t> mipSizes;
    std::shared_ptr<VROData> texData = VROTextureUtil::readKTXHeader((uint8_t *)[fileData bytes], (uint32_t)[fileData length],
                                                                     &format, &texWidth, &texHeight, &mipSizes);
    std::vector<std::shared_ptr<VROData>> dataVec = { texData };
    
    std::shared_ptr<VROTexture> texture = std::make_shared<VROTexture>(VROTextureType::Texture2D, format,
                                                                       VROTextureInternalFormat::RGBA8,
                                                                       VROMipmapMode::Pregenerated,
                                                                       dataVec, texWidth, texHeight, mipSizes);
    texture->prewarm(self.driver);
    
    std::shared_ptr<VROSurface> surface = VROSurface::createSurface(width, height, 0.5, 0.5, 1, 1);
    surface->getMaterials().front()->getDiffuse().setColor({1.0, 1.0, 1.0, 1.0});
    surface->getMaterials().front()->getDiffuse().setTexture(texture);
    
    std::shared_ptr<VRONode> surfaceNode = std::make_shared<VRONode>();
    surfaceNode->setGeometry(surface);
    surfaceNode->setPosition({0, 0, -10.01});
    
    rootNode->addChildNode(surfaceNode);
    
    /*
     Create text.
     */
    VROLineBreakMode linebreakMode = VROLineBreakMode::Justify;
    VROTextClipMode clipMode = VROTextClipMode::ClipToBounds;
    
    std::shared_ptr<VROTypeface> typeface = self.driver->newTypeface("SF", 26);
    //std::string string = "Hello Freetype, this is a test of wrapping a long piece of text, longer than all the previous pieces of text.";
    
    std::string string = "In older times when wishing still helped one, there lived a king whose daughters were all beautiful; and the youngest was so beautiful that the sun itself, which has seen so much, was astonished whenever it shone in her face.\n\nClose by the king's castle lay a great dark forest, and under an old lime-tree in the forest was a well, and when the day was very warm, the king's child went out to the forest and sat down by the fountain; and when she was bored she took a golden ball, and threw it up on high and caught it; and this ball was her favorite plaything.";
    
    VROVector3f size = VROText::getTextSize(string, typeface, width, height, linebreakMode, clipMode, 0);
    NSLog(@"Estimated size %f, %f", size.x, size.y);
    
    std::shared_ptr<VROText> text = VROText::createText(string, typeface, {1.0, 0.0, 0.0, 1.0}, width, height,
                                                        VROTextHorizontalAlignment::Left, VROTextVerticalAlignment::Top,
                                                        linebreakMode, clipMode);
    
    text->setName("Text");
    NSLog(@"Realized size %f, %f", text->getWidth(), text->getHeight());
    
    std::shared_ptr<VRONode> textNode = std::make_shared<VRONode>();
    textNode->setGeometry(text);
    textNode->setPosition({0, 0, -10});
    
    rootNode->addChildNode(textNode);
    self.tapEnabled = YES;

    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadNormalMapScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    NSString *objPath = [[NSBundle mainBundle] pathForResource:@"earth" ofType:@"obj"];
    NSURL *objURL = [NSURL fileURLWithPath:objPath];
    std::string url = std::string([[objURL description] UTF8String]);
    
    NSString *basePath = [objPath stringByDeletingLastPathComponent];
    NSURL *baseURL = [NSURL fileURLWithPath:basePath];
    std::string base = std::string([[baseURL description] UTF8String]);
    
    std::shared_ptr<VROLight> light = std::make_shared<VROLight>(VROLightType::Directional);
    light->setColor({ 0.9, 0.9, 0.9 });
    light->setPosition( { 0, 0, 0 });
    light->setDirection( { 0, 0, -1.0 });
    light->setAttenuationStartDistance(50);
    light->setAttenuationEndDistance(75);
    light->setSpotInnerAngle(45);
    light->setSpotOuterAngle(90);
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->addLight(light);
    rootNode->setBackgroundCube([self niagaraTexture]);
    
    std::shared_ptr<VRONode> objNode = VROOBJLoader::loadOBJFromURL(url, base, true,
        [](std::shared_ptr<VRONode> node, bool success) {
            if (!success) {
                return;
            }
            
            node->setPosition({0, 0, -5.5});
            node->setScale({ 0.01, 0.01, 0.01 });
    });
    
    
    rootNode->addChildNode(objNode);
    
    std::shared_ptr<VROAction> action = VROAction::perpetualPerFrameAction([self](VRONode *const node, float seconds) {
        self.objAngle += .010;
        node->setRotation({ 0, self.objAngle, 0});
        
        return true;
    });
    
    objNode->runAction(action);
    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadStereoCard {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    std::shared_ptr<VROSurface> surface = VROSurface::createSurface(20, 20);

    // Debug toggle between stereo image and stereo video cards
    bool showImage = true;
  
    if (showImage){
        std::shared_ptr<VROTexture> imgTexture
        = std::make_shared<VROTexture>(VROTextureInternalFormat::RGBA8,
                                       VROMipmapMode::None, // Don't mipmap 360 images, wastes memory
                                       std::make_shared<VROImageiOS>([UIImage imageNamed:@"stereo1.jpg"], VROTextureInternalFormat::RGBA8),
                                       VROStereoMode::LeftRight);
        surface->getMaterials().front()->getDiffuse().setTexture(imgTexture);
    } else {
        // show video
        NSString *objPath = [[NSBundle mainBundle] pathForResource:@"stereoVid" ofType:@"mp4"];
        NSURL *objURL = [NSURL fileURLWithPath:objPath];
        std::string url = std::string([[objURL description] UTF8String]);
        
        self.videoTexture = std::make_shared<VROVideoTextureiOS>(VROStereoMode::LeftRight);
        self.videoTexture->loadVideo(url, [self.view frameSynchronizer], self.driver);
        self.videoTexture->play();
        surface->getMaterials().front()->getDiffuse().setTexture(self.videoTexture);
    }
    
    std::shared_ptr<VRONode> surfaceNode = std::make_shared<VRONode>();
    surfaceNode->setGeometry(surface);
    surfaceNode->setPosition({0, 0, -35.01});
    
    std::shared_ptr<VROLight> light = std::make_shared<VROLight>(VROLightType::Spot);
    light->setColor({ 0.7, 0.7, 0.7 });
    light->setPosition( { 0, 0, 0 });
    light->setDirection( { 0, 0, -1.0 });
    light->setAttenuationStartDistance(50);
    light->setAttenuationEndDistance(75);
    light->setSpotInnerAngle(45);
    light->setSpotOuterAngle(90);
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->addLight(light);
    rootNode->addChildNode(surfaceNode);
    rootNode->setBackgroundCube([self niagaraTexture]);

    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadStereoBackground {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    
    rootNode->setBackgroundCube([self niagaraTexture]);
    // Debug toggle between stereo image and stereo video background
    bool showImage = false;

    if (showImage){
        std::shared_ptr<VROTexture> imgTexture
        = std::make_shared<VROTexture>(VROTextureInternalFormat::RGBA8,
                                       VROMipmapMode::None, // Don't mipmap 360 images, wastes memory
                                       std::make_shared<VROImageiOS>([UIImage imageNamed:@"stereo3601.jpg"], VROTextureInternalFormat::RGBA8),
                                       VROStereoMode::BottomTop);
        rootNode->setBackgroundSphere(imgTexture);
    }
    else {
        NSString *objPath = [[NSBundle mainBundle] pathForResource:@"stereoVid360" ofType:@"mp4"];
        NSURL *objURL = [NSURL fileURLWithPath:objPath];
        std::string url = std::string([[objURL description] UTF8String]);
        
        self.videoTexture = std::make_shared<VROVideoTextureiOS>(VROStereoMode::BottomTop);
        self.videoTexture->loadVideo(url, [self.view frameSynchronizer], self.driver);
        self.videoTexture->play();
        rootNode->setBackgroundSphere(self.videoTexture);

    }
    
    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadOBJScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    NSString *objPath = [[NSBundle mainBundle] pathForResource:@"male02" ofType:@"obj"];
    NSURL *objURL = [NSURL fileURLWithPath:objPath];
    std::string url = std::string([[objURL description] UTF8String]);
    
    NSString *basePath = [objPath stringByDeletingLastPathComponent];
    NSURL *baseURL = [NSURL fileURLWithPath:basePath];
    std::string base = std::string([[baseURL description] UTF8String]);
    
    std::shared_ptr<VROLight> light = std::make_shared<VROLight>(VROLightType::Spot);
    light->setColor({ 0.7, 0.7, 0.7 });
    light->setPosition( { 0, 0, 0 });
    light->setDirection( { 0, 0, -1.0 });
    light->setAttenuationStartDistance(50);
    light->setAttenuationEndDistance(75);
    light->setSpotInnerAngle(45);
    light->setSpotOuterAngle(90);
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->addLight(light);
    rootNode->setBackgroundCube([self niagaraTexture]);
    
    std::shared_ptr<VRONode> objNode = VROOBJLoader::loadOBJFromURL(url, base, true,
        [](std::shared_ptr<VRONode> node, bool success) {
            if (!success) {
                return;
            }
            
            node->setPosition({0, -10, -20});
            node->setScale({ 0.1, 0.1, 0.1 });
    });
    
    
    rootNode->addChildNode(objNode);
    
    std::shared_ptr<VROAction> action = VROAction::perpetualPerFrameAction([self](VRONode *const node, float seconds) {
        self.objAngle += .015;
        node->setRotation({ 0, self.objAngle, 0});
        
        return true;
    });
    
    objNode->runAction(action);
    
    self.delegate = std::make_shared<VROEventDelegateiOS>(self);
    self.delegate->setEnabledEvent(VROEventDelegate::EventAction::OnFuse, true);
    objNode->setEventDelegate(self.delegate);
    
    return sceneController;
}

- (std::shared_ptr<VROPortalFrame>)loadPortalEntrance {
    NSString *objPath = [[NSBundle mainBundle] pathForResource:@"portal_ring" ofType:@"obj"];
    NSURL *objURL = [NSURL fileURLWithPath:objPath];
    std::string url = std::string([[objURL description] UTF8String]);
    
    NSString *basePath = [objPath stringByDeletingLastPathComponent];
    NSURL *baseURL = [NSURL fileURLWithPath:basePath];
    std::string base = std::string([[baseURL description] UTF8String]);
    
    std::shared_ptr<VROPortalFrame> frame = std::make_shared<VROPortalFrame>();
    std::shared_ptr<VRONode> node = VROOBJLoader::loadOBJFromURL(url, base, true,
                                                                    [](std::shared_ptr<VRONode> node, bool success) {
                                                                        if (!success) {
                                                                            return;
                                                                        }
                                                                        
                                                                        VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;
                                                                        std::shared_ptr<VROMaterial> material = node->getGeometry()->getMaterials().front();
                                                                        material->setCullMode(VROCullMode::None);
                                                                        material->setLightingModel(VROLightingModel::Lambert);
                                                                        material->getDiffuse().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                                                                                       std::make_shared<VROImageiOS>([UIImage imageNamed:@"portal_ring"], format)));
                                                                    });
    
    frame->addChildNode(node);
    return frame;
}

- (std::shared_ptr<VRONode>)loadFBXModel {
    NSString *fbxPath = [[NSBundle mainBundle] pathForResource:@"aliengirl" ofType:@"vrx"];
    NSURL *fbxURL = [NSURL fileURLWithPath:fbxPath];
    std::string url = std::string([[fbxURL description] UTF8String]);
    
    NSString *basePath = [fbxPath stringByDeletingLastPathComponent];
    NSURL *baseURL = [NSURL fileURLWithPath:basePath];
    std::string base = std::string([[baseURL description] UTF8String]);
    
    return VROFBXLoader::loadFBXFromURL(url, base, true,
                                        [self](std::shared_ptr<VRONode> node, bool success) {
                                            if (!success) {
                                                return;
                                            }
                                            
                                            node->setScale({0.04, 0.04, 0.04});
                                            node->setPosition({0, -2, -6});
                                            
                                            if (node->getGeometry()) {
                                                node->getGeometry()->setName("FBX Root Geometry");
                                            }
                                            for (std::shared_ptr<VRONode> &child : node->getChildNodes()) {
                                                if (child->getGeometry()) {
                                                    child->getGeometry()->setName("FBX Geometry");
                                                }
                                            }
                                            
                                            std::set<std::string> animations = node->getAnimationKeys(true);
                                            for (std::string animation : animations) {
                                                pinfo("Loaded animation [%s]", animation.c_str());
                                            }
                                            
                                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                [self animateTake:node];
                                            });
                                        });
}

- (std::shared_ptr<VROSceneController>)loadFBXScene {
    std::shared_ptr<VROSceneController> sceneController = std::make_shared<VROSceneController>();
    std::shared_ptr<VROScene> scene = sceneController->getScene();
    
    std::shared_ptr<VROLight> light = std::make_shared<VROLight>(VROLightType::Spot);
    light->setColor({ 1.0, 1.0, 1.0 });
    light->setPosition( { 0, 0, 0 });
    light->setDirection( { 0, 0, -1.0 });
    light->setAttenuationStartDistance(50);
    light->setAttenuationEndDistance(75);
    light->setSpotInnerAngle(70);
    light->setSpotOuterAngle(120);
    
    std::shared_ptr<VROLight> ambient = std::make_shared<VROLight>(VROLightType::Ambient);
    ambient->setColor({ 1.0, 1.0, 1.0 });
    ambient->setIntensity(1000);
    
    std::shared_ptr<VROPortal> rootNode = scene->getRootNode();
    rootNode->setPosition({0, 0, 0});
    rootNode->addLight(light);
    rootNode->addLight(ambient);
    rootNode->setBackgroundCube([self niagaraTexture]);
    rootNode->addChildNode([self loadFBXModel]);
    
    self.delegate = std::make_shared<VROEventDelegateiOS>(self);
    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadARPlaneScene {
    std::shared_ptr<VROARSceneController> sceneController = std::make_shared<VROARSceneController>();
    std::shared_ptr<VROARScene> arScene = std::dynamic_pointer_cast<VROARScene>(sceneController->getScene());
    std::shared_ptr<VRONode> sceneNode = std::make_shared<VRONode>();
    std::shared_ptr<VROARPlane> arPlane = std::make_shared<VROARPlane>(0, 0);
    
    
    NSString *objPath = [[NSBundle mainBundle] pathForResource:@"coffee_mug" ofType:@"obj"];
    NSURL *objURL = [NSURL fileURLWithPath:objPath];
    std::string url = std::string([[objURL description] UTF8String]);
    
    NSString *basePath = [objPath stringByDeletingLastPathComponent];
    NSURL *baseURL = [NSURL fileURLWithPath:basePath];
    std::string base = std::string([[baseURL description] UTF8String]);
    
    
    
    std::shared_ptr<VRONode> objNode = VROOBJLoader::loadOBJFromURL(url, base, true,
                                                                    [self](std::shared_ptr<VRONode> node, bool success) {
                                                                        if (!success) {
                                                                            return;
                                                                        }
                                                                        node->setScale({0.007, 0.007, 0.007});
                                                                        
                                                                        VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;
                                                                        
                                                                        std::shared_ptr<VROMaterial> material = node->getGeometry()->getMaterials().front();
                                                                        material->getDiffuse().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                                                                                       std::make_shared<VROImageiOS>([UIImage imageNamed:@"coffee_mug"], format)));
                                                                        material->getSpecular().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                                                                                        std::make_shared<VROImageiOS>([UIImage imageNamed:@"coffee_mug_specular"], format)));
                                                                    });
    
    sceneNode->addChildNode(arPlane);
    arPlane->addChildNode(objNode);
    arScene->addARPlane(arPlane);
    arScene->addNode(sceneNode);
    
    // Taking screenshot/video logic:

    VROViewAR *arView = (VROViewAR *)self.view;
    int rand = arc4random_uniform(1000);
    
    // takeVideo if YES, else takePhoto if NO
    BOOL takeVideo = NO;
    if (takeVideo) {
        NSString *filename = [NSString stringWithFormat:@"testvideo%d", rand];
        
        NSLog(@"[VROSample] started recording");
        [arView startVideoRecording:filename saveToCameraRoll:YES errorBlock:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSLog(@"[VROSample] stopped recording");
            [arView stopVideoRecordingWithHandler:^(BOOL success, NSURL *url, NSInteger errorCode) {
                if (url) {
                    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
                }
            }];
        });
    } else {
        NSString *filename = [NSString stringWithFormat:@"testimage%d", rand];
        
        NSLog(@"[VROSample] taking screenshot in 5 seconds");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [arView takeScreenshot:filename saveToCameraRoll:YES withCompletionHandler:^(BOOL success, NSURL *url, NSInteger errorCode) {
                if (url) {
                    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
                }
            }];
        });
    }
    
    return sceneController;
}

- (std::shared_ptr<VROSceneController>)loadARDraggableNodeScene {
    std::shared_ptr<VROARSceneController> sceneController = std::make_shared<VROARSceneController>();
    std::shared_ptr<VROARScene> arScene = std::dynamic_pointer_cast<VROARScene>(sceneController->getScene());
    std::shared_ptr<VRONode> sceneNode = std::make_shared<VRONode>();
    
    NSString *objPath = [[NSBundle mainBundle] pathForResource:@"coffee_mug" ofType:@"obj"];
    NSURL *objURL = [NSURL fileURLWithPath:objPath];
    std::string url = std::string([[objURL description] UTF8String]);
    
    NSString *basePath = [objPath stringByDeletingLastPathComponent];
    NSURL *baseURL = [NSURL fileURLWithPath:basePath];
    std::string base = std::string([[baseURL description] UTF8String]);
    
    
    
    std::shared_ptr<VRONode> objNode = VROOBJLoader::loadOBJFromURL(url, base, true,
                                                                    [self](std::shared_ptr<VRONode> node, bool success) {
                                                                        if (!success) {
                                                                            return;
                                                                        }
                                                                        node->setScale({0.007, 0.007, 0.007});
                                                                        
                                                                        VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;
                                                                        
                                                                        std::shared_ptr<VROMaterial> material = node->getGeometry()->getMaterials().front();
                                                                        material->getDiffuse().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                                                                                       std::make_shared<VROImageiOS>([UIImage imageNamed:@"coffee_mug"], format)));
                                                                        material->getSpecular().setTexture(std::make_shared<VROTexture>(format, VROMipmapMode::None,
                                                                                                                                        std::make_shared<VROImageiOS>([UIImage imageNamed:@"coffee_mug_specular"], format)));
                                                                    });
    
    std::shared_ptr<VROBox> box = VROBox::createBox(.2, .2, .2);
    std::shared_ptr<VROARDraggableNode> draggableNode = std::make_shared<VROARDraggableNode>();
    
    self.delegate = std::make_shared<VROEventDelegateiOS>(self);
    self.delegate->setEnabledEvent(VROEventDelegate::EventAction::OnDrag, true);
    
    draggableNode->setEventDelegate(self.delegate);
    
    draggableNode->setPosition(VROVector3f(0,0,-1));
    std::shared_ptr<VRONode> boxNode = std::make_shared<VRONode>();
    boxNode->setGeometry(box);
    boxNode->setPosition(VROVector3f(0, .13, 0));
    draggableNode->addChildNode(boxNode);
    sceneNode->addChildNode(draggableNode);
    arScene->addNode(sceneNode);
    
    // add a shadow under the box.
    VROTextureInternalFormat format = VROTextureInternalFormat::RGBA8;
    std::shared_ptr<VROTexture> texture = std::make_shared<VROTexture>(format, VROMipmapMode::Runtime,
                                                                       std::make_shared<VROImageiOS>([UIImage imageNamed:@"dark_circle_shadow"], format));
    std::shared_ptr<VROSurface> surface = VROSurface::createSurface(.3, .3);
    surface->getMaterials().front()->getDiffuse().setTexture(texture);
    
    std::shared_ptr<VRONode> surfaceNode = std::make_shared<VRONode>();
    surfaceNode->setGeometry(surface);
    surfaceNode->setRotationEulerX(-1.570795); // rotate it so it's facing "up" (-PI/2)
    
    draggableNode->addChildNode(surfaceNode);
    
    return sceneController;
}

- (void)animateTake:(std::shared_ptr<VRONode>)node {
    node->getAnimation("Take 001", true)->execute(node, [node, self] {
        [self animateTake:node];
    });
}

- (void)setupRendererWithDriver:(std::shared_ptr<VRODriver>)driver {
    self.sceneIndex = VROSampleScenePortal;
    self.driver = driver;
    
    self.sceneController = [self loadSceneWithIndex:self.sceneIndex];
    self.view.sceneController = self.sceneController;
}

- (void)nextSceneAfterDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self nextScene:nullptr];
        [self nextSceneAfterDelay];
    });
}

- (IBAction)nextScene:(id)sender {
    ++self.sceneIndex;
    
    std::shared_ptr<VROSceneController> sceneController = [self loadSceneWithIndex:self.sceneIndex];
    [self.view setSceneController:sceneController];
}

- (void)willRenderEye:(VROEyeType)eye context:(const VRORenderContext *)renderContext {

}

- (void)didRenderEye:(VROEyeType)eye context:(const VRORenderContext *)renderContext {

}

- (void)renderViewDidChangeSize:(CGSize)size context:(VRORenderContext *)context {

}

- (void)userDidRequestExitVR {
    
}

@end

