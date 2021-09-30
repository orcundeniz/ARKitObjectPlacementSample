//
//  ViewController.swift
//  ARKitObjectPlacementSample
//
//  Created by Orcun Deniz on 21.09.2021.
//

import UIKit
import ARKit

final class ViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var arView: ARView!
    
    /**
     The object that has been most recently intereacted with.
     The `selectedObject` can be moved at any time with the tap gesture.
     */
    var selectedObject: ARObjectable?
    
    /// The object that is tracked for use by the pan and rotation gestures.
    var trackedObject: ARObjectable? {
        didSet {
            guard trackedObject != nil else { return }
            selectedObject = trackedObject
        }
    }
    
    /// The tracked screen position used to update the `trackedObject`'s position.
    var currentTrackingPosition: CGPoint?
    
    let coachingOverlay = ARCoachingOverlayView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGestures()
        setupCoachingOverlay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        arView.runSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.pauseSession()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow objects to be translated and rotated at the same time.
        return false
    }
    
    func restartExperience() {
        arView.runSession()
    }
    // MARK: - User Actions
    @objc
    func userTapped(_ gesture: UITapGestureRecognizer) {
        let touchLocation = gesture.location(in: view)

        if let tappedObject = arView.ARObject(at: touchLocation) {
            // If we have an object in the current location, then change its color to red.
            
            // if tapped the same object, unselect
            if tappedObject === selectedObject {
                resetSelectedObject()
            } else {
                // Change old selected to previous state - unselected
                resetSelectedObject()

                // If an object exists at the tap location, select it.
                applySelectionColor(color: .red, to: tappedObject)
                selectedObject = tappedObject
            }
        } else {
            // If we don't have an object in the current location, add new one
            let arrowObject = ArrowNode()
            
            // face them against camera to offer better UX
            if let eulerAngles = arView.pointOfView?.eulerAngles {
                arrowObject.eulerAngles = eulerAngles
            }
            
            // Try placing object 
            arView.placeARObject(arrowObject, at: touchLocation)
        }
    }
    
    @objc
    func userDragging(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            // Check for an object at the touch location.
            if let object = arView.objectInteracting(with: gesture) {
                resetSelectedObject()
                applySelectionColor(color: .red, to: object)
                trackedObject = object
            }
            
        case .changed:
            guard let object = trackedObject else { return }
            // Move an object if the displacment threshold has been met.
            arView.translate(object, basedOn: updatedTrackingPosition(for: object, from: gesture), trackedObject: trackedObject)
            print("interaction dragging changed")
            gesture.setTranslation(.zero, in: arView)
            
        case .ended:
            print("interaction drag ended")
            
            // Update the object's position when the user stops panning.
            guard let object = trackedObject else { break }
            arView.setDown(object, basedOn: updatedTrackingPosition(for: object, from: gesture))
            currentTrackingPosition = nil
            trackedObject = nil
        default:
            break
        }
    }
    
    @objc
    func userRotating(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            if let object = arView.objectInteracting(with: gesture) {
                resetSelectedObject()
                applySelectionColor(color: .red, to: object)
                trackedObject = object
            }
        case .changed:
            trackedObject?.simdEulerAngles.x -= Float(gesture.rotation)
            gesture.rotation = 0
        case .ended:
            trackedObject = nil
        default:
            break
        }
    }
    
    @objc
    func userScaling(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            // Check for an object at the touch location.
            if let object = arView.objectInteracting(with: gesture) {
                resetSelectedObject()
                applySelectionColor(color: .red, to: object)
                object.stopTrackedRaycast()
                trackedObject = object
            }
        case .changed:
            guard let trackedObjectToScale = trackedObject else { return }
            let pinchScaleX: CGFloat = gesture.scale * CGFloat((trackedObjectToScale.scale.x))
            let pinchScaleY: CGFloat = gesture.scale * CGFloat((trackedObjectToScale.scale.y))
            let pinchScaleZ: CGFloat = gesture.scale * CGFloat((trackedObjectToScale.scale.z))
            
            if let biggestScale = [pinchScaleX, pinchScaleY, pinchScaleZ].sorted().last {
                // uniform scale
                trackedObjectToScale.simdScale = [Float(biggestScale), Float(biggestScale), Float(biggestScale)]
            }
            
            gesture.scale = 1
            
        case .ended:
            trackedObject = nil
            
        default:
            break
        }
    }
    
    // MARK: - Helpers
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userTapped(_:)))
        view.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(userDragging(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(userRotating(_:)))
        rotationGesture.delegate = self
        view.addGestureRecognizer(rotationGesture)
              
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(userScaling(_:)))
        view.addGestureRecognizer(pinchGesture)
    }
    
    
    private func resetSelectedObject() {
        if let selectedObject = selectedObject {
            applySelectionColor(color: .blue, to: selectedObject)
        }
        selectedObject = nil
    }
    
    private func applySelectionColor(color: UIColor, to object: ARObjectable) {
        object.enumerateChildNodes({
            object, stop in
            // change the color of all the children
            object.geometry?.firstMaterial?.diffuse.contents = color
        })
    }
    
    private func updatedTrackingPosition(for object: ARObjectable, from gesture: UIPanGestureRecognizer) -> CGPoint {
        let translation = gesture.translation(in: arView)
        
        let currentPosition = currentTrackingPosition ?? CGPoint(arView.projectPoint(object.position))
        let updatedPosition = CGPoint(x: currentPosition.x + translation.x, y: currentPosition.y + translation.y)
        currentTrackingPosition = updatedPosition
        return updatedPosition
    }
}

