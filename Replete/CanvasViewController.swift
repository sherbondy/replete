//
//  CanvasViewController.swift
//  Replete
//
//  Created by Ethan Sherbondy on 1/29/17.
//  Copyright © 2017 FikesFarm. All rights reserved.
//

import UIKit

/* 
 Idea is to add a play/pause button, and a "fullscreen" button
 would enable user interaction on the javascript context with
 some predefined gesture to exit out of fullscreen.
 
 Also want to refine gestures so that there's acceleration, bounce
 back when going past the edge, hiding when you deliberately flick
 pas edge, toggleable visibility, adjustable size/aspect ratio.
 
 Frame dimensions should be dynamic based on device size.
 - for iPod/iPhone: default to 1/4 of screen dimensions (portrait)
 
 - for iPad: default to 1/4 of portrait dimensions, even in landscape:
   Want to make ideal for split-screen exploration in landscape
 
 
 Incrementally query and display canvas dimensions from context?
 Allow explicit customization/override of canvas dimension(s), maybe
 changing border color to designate that dimension(s) are locked down.
 
 Also want to allow possibility for rendering exclusively
 to external display in airplay mode by default?
 
 */

class CanvasViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var canvasView: EJJavaScriptView!
    var lastPoint: CGPoint = CGPoint.zero
    var lastScale: CGFloat = 0.0
    // maybe the canvas should actually be the full window height
    // pixel-wise, just scaled down initially?
    var initialSize: CGSize = CGSize(width: 80, height: 120)
    let canvasMargin: CGFloat = 20
    
    
    func calculateViewFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds.size
        initialSize = CGSize(width: screenSize.width/4, height: screenSize.height/4)
        
        let viewFrame = CGRect(
            x: screenSize.width - initialSize.width - canvasMargin,
            y: canvasMargin,
            width: initialSize.width, height: initialSize.height
        )
        
        return viewFrame
    }
    

    override func loadView() {
        super.loadView()

        // Do any additional setup after loading the view.
        self.view = UIView()
        self.view.backgroundColor = UIColor.gray
        self.view.frame = calculateViewFrame()
        
        let canvasFrame = CGRect(origin: CGPoint.zero, size: initialSize)

        canvasView = EJJavaScriptView(frame: canvasFrame, appFolder: "out/")
        // initially disable interaction
        canvasView.isUserInteractionEnabled = false
        canvasView.translatesAutoresizingMaskIntoConstraints = true
        
        let panR = UIPanGestureRecognizer.init(target: self, action: #selector(handlePan))
        panR.cancelsTouchesInView = true
        panR.delegate = self
        
        let tapR = UILongPressGestureRecognizer.init(target: self, action: #selector(handleTap))
        tapR.minimumPressDuration = 0
        tapR.cancelsTouchesInView = true
        tapR.delegate = self
        
        let pinchR = UIPinchGestureRecognizer.init(target: self, action: #selector(handlePinch))
        pinchR.cancelsTouchesInView = true
        pinchR.delegate = self
        
        self.view.addGestureRecognizer(panR)
        self.view.addGestureRecognizer(tapR)
        self.view.addGestureRecognizer(pinchR)
        
        self.view.addSubview(canvasView)
    }
    
    override func viewDidLoad() {
        canvasView.loadScript(atPath: "index.js")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil, completion: {
            _ in
            
            let rotatedFrame = self.calculateViewFrame()
            
            let oldFrame = self.canvasView.frame
            let canvasFrame = CGRect(origin: oldFrame.origin, size: rotatedFrame.size)
            self.canvasView.frame = canvasFrame
            (self.canvasView.screenRenderingContext as! EJPresentable).style = canvasFrame
            
            self.view.frame = rotatedFrame
            self.view.transform = CGAffineTransform.identity
            self.view.setNeedsLayout()
            
            print("Transitioned view frame...")
        })
    }
    
    func jsContext() -> JSGlobalContextRef {
        return self.canvasView.jsGlobalContext
    }
    
    
    // Gesture Recognizer Delegate Methods
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }
    
    // gesture handlers and helpers
    
    func showShadow() {
        self.view.layer.shadowColor = UIColor.black.cgColor
        self.view.layer.shadowOpacity = 0.75
        self.view.layer.shadowRadius = 10
    }
    
    func hideShadow() {
        self.view.layer.shadowRadius = 0
    }
    
    func handleShadow(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            showShadow()
        } else if gestureRecognizer.state == .ended {
            hideShadow()
        }
    }
    
    @IBAction func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        handleShadow(gestureRecognizer: gestureRecognizer)
    }
    
    func handleTranslate(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            lastPoint = gestureRecognizer.location(in: self.view)
        }
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            let location = gestureRecognizer.location(in: self.view)
            // note: 'view' is optional and need to be unwrapped
            self.view.transform = self.view.transform.translatedBy(
                x: (location.x - lastPoint.x),
                y: (location.y - lastPoint.y)
            )
            lastPoint = gestureRecognizer.location(in: self.view)
        }
    }

    
    @IBAction func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        handleTranslate(gestureRecognizer: gestureRecognizer)
        handleShadow(gestureRecognizer: gestureRecognizer)
    }
    
    @IBAction func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        if gestureRecognizer.state == .began {
            lastScale = gestureRecognizer.scale
        }
        
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            let currentScale = CGFloat((self.view.layer.value(forKeyPath: "transform.scale") as! NSNumber))
            let maxScale = CGFloat(3.0)
            let minScale = CGFloat(1.0)
            
            let initialScale = 1.0 - (lastScale - gestureRecognizer.scale)
            let newScale = max(
                min(initialScale, maxScale/currentScale),
                minScale/currentScale
            )
            
            self.view.transform = self.view.transform.scaledBy(x: newScale, y: newScale)
            
            let newSize = self.view.frame.size.applying(
                CGAffineTransform.init(scaleX: newScale, y: newScale)
            )
            
            if lastScale != newScale {
                let oldFrame = canvasView.frame
                let newFrame = CGRect(
                    origin: oldFrame.origin,
                    size: newSize
                )
                // HMM, this does not actually make the js/window or js/canvas
                // sizes change... not quite sure how this works.
                // maybe we need to trigger a resize event on the js context?
                self.canvasView.frame = newFrame
                lastScale = newScale
            }
        }
        
        handleTranslate(gestureRecognizer: gestureRecognizer)
        handleShadow(gestureRecognizer: gestureRecognizer)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
