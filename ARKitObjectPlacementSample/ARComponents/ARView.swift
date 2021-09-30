//
//  ARSceneView.swift
//  ARSceneView
//
//  Created by Orcun Deniz on 21.09.2021.
//

import Foundation
import ARKit


/// Custom ARSCNView
final class ARView: ARSCNView {

    let configuration = ARWorldTrackingConfiguration()

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        automaticallyUpdatesLighting = true
        showsStatistics = true
        debugOptions = [.showFeaturePoints]
        preferredFramesPerSecond = 60
        contentScaleFactor = 1.0
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        if #available(iOS 13.4, *) {
            /// LIDAR support for better world understanding. World understanding works only textural surfaces and in good lightining conditions without LIDAR scanner.
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
        }
    }
    
    func runSession() {
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
    }
    
    func pauseSession() {
        session.pause()
    }
}

// MARK: Position Testing
extension ARSCNView {
    /// Hit tests against the `ARSCNView` to find an object at the provided 2D point.
    func ARObject(at point: CGPoint) -> ARObjectable? {
        let hitTestOptions: [SCNHitTestOption: Any] = [.boundingBoxOnly: true, .searchMode: true]
        let hitTestResults = hitTest(point, options: hitTestOptions)
        
        return hitTestResults.lazy.compactMap { result in
            return self.existingObjectContainingNode(result.node)
        }.first
    }
    
    
   func objectInteracting(with gesture: UIGestureRecognizer) -> ARObjectable? {
       for index in 0..<gesture.numberOfTouches {
           let touchLocation = gesture.location(ofTouch: index, in: self)
           
           // Look for an object directly under the `touchLocation`.
           if let object = ARObject(at: touchLocation) {
               return object
           }
       }
       
       // As a last resort look for an object under the center of the touches.
       if let center = gesture.center(in: self) {
           return ARObject(at: center)
       }
       
       return nil
   }
    
    /// - Tag: DragVirtualObject
    func translate(_ object: ARObjectable, basedOn screenPos: CGPoint, trackedObject: ARObjectable?) {
        object.stopTrackedRaycast()

        // Update the object by using a one-time position request.
        if let raycastQuery = raycastQuery(from: screenPos, allowing: .estimatedPlane, alignment: .any),
           !(session.raycast(raycastQuery).isEmpty) {
            createRaycastAndUpdate3DPosition(of: object, from: raycastQuery, compare: trackedObject)
        }
    }
    
    func setDown(_ object: ARObjectable, basedOn screenPos: CGPoint) {
        object.stopTrackedRaycast()
        
        // Prepare to update the object's anchor to the current location.
        object.shouldUpdateAnchor = true
        
        // Attempt to create a new tracked raycast from the current location.
        if let raycastQuery = raycastQuery(from: screenPos, allowing: .estimatedPlane, alignment: .any) {
            setTrackedRaycast(for: object, with: raycastQuery)
        } else {
            // If the tracked raycast did not succeed, simply update the anchor to the object's current position.
            object.shouldUpdateAnchor = false
            DispatchQueue.main.async { [weak self] in
                self?.updateAnchor(for: object)
            }
        }
    }
    /// Returns a `ARObjectable` if one exists as an ancestor to the provided node.
    private func existingObjectContainingNode(_ node: SCNNode) -> ARObjectable? {
        if let virtualObjectRoot = node as? ARObjectable {
            return virtualObjectRoot
        }
        
        guard let parent = node.parent else { return nil }
        
        // Recurse up to check if the parent is a `ARObjectable`.
        return existingObjectContainingNode(parent)
    }
    
    private func createRaycastAndUpdate3DPosition(of object: ARObjectable,
                                          from query: ARRaycastQuery,
                                          compare trackedObject: ARObjectable?) {
        guard let result = session.raycast(query).first,
              let trackedObject = trackedObject else {
                  return
              }
        
        if trackedObject == object {
            // If an object that's aligned to a surface is being dragged, then
            // smoothen its orientation to avoid visible jumps, and apply only the translation directly.
            object.simdWorldPosition = result.worldTransform.translation
        } else {
            self.setTransform(of: object, with: result)
        }
    }
}

// - MARK: Object placement
extension ARSCNView {
    
    /// Places the `ARObjectable`
    func placeARObject(_ object: ARObjectable, at point: CGPoint) {
        if let raycastQuery = raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any),
           let result = session.raycast(raycastQuery).first  {
            setTransform(of: object, with: result)
            setObjectPlacement(for: object)
            setTrackedRaycast(for: object, with: raycastQuery)
        }
        
    }
    
    private func setObjectPlacement(for object: ARObjectable) {
        scene.rootNode.addChildNode(object)
        object.shouldUpdateAnchor = true
    }
    
    private func setTrackedRaycast(for object: ARObjectable, with raycastQuery: ARRaycastQuery) {
        object.trackedRaycast = session.trackedRaycast(raycastQuery) { [weak self] (results) in
            self?.setVirtualObject3DPosition(results, with: object)
        }
    }
    
    // - Tag: ProcessRaycastResults
    private func setVirtualObject3DPosition(_ results: [ARRaycastResult], with object: ARObjectable) {
        
        guard let result = results.first else {
            fatalError("Unexpected case: the update handler is always supposed to return at least one result.")
        }
        
        self.setTransform(of: object, with: result)

        if object.shouldUpdateAnchor {
            object.shouldUpdateAnchor = false
            DispatchQueue.main.async { [weak self] in
                self?.updateAnchor(for: object)
            }
        }
    }
    
    private func setTransform(of object: ARObjectable, with result: ARRaycastResult) {
        let prevScale = object.simdScale
        let prevRotation = object.simdRotation
        
        object.simdWorldPosition = result.worldTransform.translation
        object.simdScale = prevScale
        object.simdRotation = prevRotation
    }
    
    /// Updates the anchor of the `ARObjectable`
    private func updateAnchor(for object: ARObjectable) {
        // If the anchor is not nil, remove it from the session.
        if let anchor = object.anchor {
            session.remove(anchor: anchor)
        }
        
        // Create a new anchor with the object's current transform and add it to the session
        let newAnchor = ARAnchor(transform: object.simdWorldTransform)
        object.anchor = newAnchor
        session.add(anchor: newAnchor)
    }
}
