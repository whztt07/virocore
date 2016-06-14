//
//  VROScene.h
//  ViroRenderer
//
//  Created by Raj Advani on 10/19/15.
//  Copyright © 2015 Viro Media. All rights reserved.
//

#ifndef VROScene_h
#define VROScene_h

#include <stdio.h>
#include <vector>
#include <memory>
#include "VROAllocationTracker.h"
#include "VROAudioPlayer.h"
#include "VROSortKey.h"

class VRONode;
class VRORenderContext;
class VRODriver;
class VROTexture;
class VROGeometry;
class VROHitTestResult;
class VROVector3f;

class VROScene : public std::enable_shared_from_this<VROScene> {
    
public:
    
    VROScene();
    virtual ~VROScene();
    
    void renderBackground(const VRORenderContext &context,
                          const VRODriver &driver);
    void render(const VRORenderContext &context,
                const VRODriver &driver);
    void render2(const VRORenderContext &context,
                 const VRODriver &driver);
    
    void updateSortKeys();
    
    /*
     Add a new root node to the scene.
     */
    void addNode(std::shared_ptr<VRONode> node);
    std::vector<std::shared_ptr<VRONode>> &getRootNodes() {
        return _nodes;
    }
    
    /*
     Set the background of the scene to a cube-map defined by
     the given cube texture, or a sphere defined by the given spherical
     image.
     */
    void setBackgroundCube(std::shared_ptr<VROTexture> textureCube);
    void setBackgroundSphere(std::shared_ptr<VROTexture> textureSphere);
    std::shared_ptr<VROGeometry> getBackground() const {
        return _background;
    }
    
    /*
     Perform a hit test against all of the root nodes (and their
     children) in the scene.
     */
    std::vector<VROHitTestResult> hitTest(VROVector3f ray, const VRORenderContext &context,
                                          bool boundsOnly = false);
    
    
    /*
     Get the audio player for the background track in this scene.
     */
    VROAudioPlayer &getBackgroundAudioPlayer() {
        return _backgroundAudio;
    }
    
private:
    
    /*
     The root nodes of the scene.
     */
    std::vector<std::shared_ptr<VRONode>> _nodes;
    
    /*
     The background visual to display. Rendered before any nodes.
     */
    std::shared_ptr<VROGeometry> _background;
    
    /*
     The nodes ordered for rendering by their sort keys.
     */
    std::vector<VROSortKey> _keys;
    
    /*
     The audio player for the background track of this scene.
     */
    VROAudioPlayer _backgroundAudio;
    
};

#endif /* VROScene_h */
