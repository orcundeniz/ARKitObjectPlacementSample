//
//  Arrow.swift
//  Arrow
//
//  Created by Orcun Deniz on 21.09.2021.
//

import ARKit

final class ArrowNode: SCNNode, ARObjectable {
    var anchor: ARAnchor?

    var trackedRaycast: ARTrackedRaycast?

    var shouldUpdateAnchor: Bool = false

    override init() {
        super.init()
        
        let coneGeometry = SCNCone(topRadius: 2.0*0.005, bottomRadius: 0, height: 2.0*0.005)
        coneGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        let coneNode = SCNNode(geometry: coneGeometry)
        
        let cylinderGeometry = SCNCylinder(radius: 1.0*0.005, height: 3.0*0.005)
        cylinderGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        let cylinderNode = SCNNode(geometry: cylinderGeometry)
        
        coneNode.position = SCNVector3(0, 0, 0)
        cylinderNode.position = SCNVector3(0, ((Float(coneGeometry.height) + Float(cylinderGeometry.height)) / 2 ), 0)
        
        addChildNode(coneNode)
        addChildNode(cylinderNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
