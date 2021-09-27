//
//  ARObject.swift
//  ARObject
//
//  Created by Orcun Deniz on 21.09.2021.
//

import ARKit

/// ARObjectable is a protocol to make any SCNNode trackable
protocol ARObjectable where Self: SCNNode {
    
    /// The object's corresponding ARAnchor.
    var anchor: ARAnchor? { get set }
    
    /// The associated tracked raycast used to place this object.
    var trackedRaycast: ARTrackedRaycast? { get set }
    
    /// Flag that indicates the associated anchor should be updated
    /// at the end of a pan gesture or when the object is repositioned.
    var shouldUpdateAnchor: Bool { get set }
    
    /// Stops tracking the object's position and orientation.
    /// - Tag: StopTrackedRaycasts
    func stopTrackedRaycast()
}

extension ARObjectable {
    /// Stops tracking the object's position and orientation.
    /// - Tag: StopTrackedRaycasts
    func stopTrackedRaycast() {
        trackedRaycast?.stopTracking()
        trackedRaycast = nil
    }
}
