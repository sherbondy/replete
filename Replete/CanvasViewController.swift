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

extension CGAffineTransform {
    var xScale: Double {
        return sqrt(Double(self.a*self.a) + Double(self.c*self.c))
    }
    
    var yScale: Double {
        return sqrt(Double(self.b*self.b) + Double(self.d*self.d))
    }
}

class CanvasViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var canvasView: EJJavaScriptView!
    var canvasSizeLabel: UILabel!
    var lastPoint: CGPoint = CGPoint.zero
    var lastScale: CGFloat = 0.0
    // maybe the canvas should actually be the full window height
    // pixel-wise, just scaled down initially?
    var initialSize: CGSize = CGSize(width: 80, height: 120)
    let canvasMargin: CGFloat = 20
    
    
    func calculateViewFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds.size
        initialSize = CGSize(
            width: round(screenSize.width/4),
            height: round(screenSize.height/4)
        )
        
        let viewFrame = CGRect(
            x: screenSize.width - initialSize.width - canvasMargin,
            y: canvasMargin,
            width: initialSize.width, height: initialSize.height
        )
        
        return viewFrame
    }
    
    func updateCanvasLabel() {
        let w = Int(canvasView.frame.size.width)
        let h = Int(canvasView.frame.size.height)
        canvasSizeLabel.text = "\(w)x\(h)"
    }
    
    func fadeOutCanvasLabel() {
        UIView.animate(withDuration: 1.0, delay: 2.0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
            self.canvasSizeLabel.alpha = 0.0
        }, completion: nil)
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
        
        let canvasSizeLabelFrame = CGRect(
            origin: CGPoint.zero,
            size: CGSize(
                width: initialSize.width,
                height: 16
            )
        )
        canvasSizeLabel = UILabel(frame: canvasSizeLabelFrame)
        canvasSizeLabel.autoresizingMask = UIViewAutoresizing.flexibleWidth
        canvasSizeLabel.textColor = UIColor.white
        canvasSizeLabel.textAlignment = NSTextAlignment.center
        canvasSizeLabel.font = UIFont.systemFont(ofSize: 12)
        canvasSizeLabel.backgroundColor = UIColor.black
        updateCanvasLabel()
        fadeOutCanvasLabel()
        
        self.view.addSubview(canvasSizeLabel)
    }
    
    override func viewDidLoad() {
        canvasView.loadScript(atPath: "index.js")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func resizeCanvasContext(newCanvasFrame: CGRect) {
        let scale = UIScreen.main.scale
        self.canvasView.screenRenderingContext.width = Int16(round(newCanvasFrame.size.width*scale))
        self.canvasView.screenRenderingContext.height = Int16(round(newCanvasFrame.size.height*scale))
        (self.canvasView.screenRenderingContext as! EJPresentable).style = newCanvasFrame
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil, completion: {
            _ in
            
            let rotatedFrame = self.calculateViewFrame()
            
            let oldFrame = self.canvasView.frame
            let canvasFrame = CGRect(origin: oldFrame.origin, size: rotatedFrame.size)
            self.canvasView.frame = canvasFrame
            self.resizeCanvasContext(newCanvasFrame: canvasFrame)
            
            self.view.frame = rotatedFrame
            self.view.setNeedsLayout()
            self.updateCanvasLabel()
            
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
        if gestureRecognizer.state == .changed {
            let location = gestureRecognizer.location(in: self.view)
            // note: 'view' is optional and need to be unwrapped
            let center = self.view.center
            let newCenter = CGPoint(
                x: center.x - (lastPoint.x - location.x),
                y: center.y - (lastPoint.y - location.y)
            )
            
            self.view.center = newCenter
            lastPoint = gestureRecognizer.location(in: self.view)
        }
    }
    
    func handleCanvasSizeLabel(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            self.canvasSizeLabel.alpha = 1.0
        }
        
        if gestureRecognizer.state == .ended {
            self.fadeOutCanvasLabel()
        }
    }

    
    @IBAction func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        handleTranslate(gestureRecognizer: gestureRecognizer)
        handleShadow(gestureRecognizer: gestureRecognizer)
        handleCanvasSizeLabel(gestureRecognizer: gestureRecognizer)
    }
    
    @IBAction func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        handleTranslate(gestureRecognizer: gestureRecognizer)
        handleShadow(gestureRecognizer: gestureRecognizer)
        
        if gestureRecognizer.state == .began {
            lastScale = gestureRecognizer.scale
        }
        
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            let currentScale = CGFloat(self.view.frame.size.width / initialSize.width)
            let maxScale = CGFloat(3.0)
            let minScale = CGFloat(1.0)
            
            let initialScale = 1.0 - (lastScale - gestureRecognizer.scale)
            let newScale = max(
                min(initialScale, maxScale/currentScale),
                minScale/currentScale
            )
            
            let newBounds = self.view.bounds.applying(
                CGAffineTransform.init(scaleX: newScale, y: newScale)
            )
            let roundedBounds = CGRect(
                origin: newBounds.origin,
                size: CGSize(
                    width: round(newBounds.width),
                    height: round(newBounds.height)
                )
            )
            
            self.view.bounds = roundedBounds
            lastScale = newScale
        }
        
        let oldFrame = canvasView.frame
        let newCanvasFrame = CGRect(
            origin: oldFrame.origin,
            size: self.view.bounds.size
        )
        
        // HMM, this does not actually make the js/window or js/canvas
        // sizes change... not quite sure how this works.
        // maybe we need to trigger a resize event on the js context?
        if gestureRecognizer.state == .changed {
            self.canvasView.isPaused = true
            self.canvasView.frame = newCanvasFrame
            resizeCanvasContext(newCanvasFrame: newCanvasFrame)
        }
        
        if gestureRecognizer.state == .ended {
            self.canvasView.isPaused = false
        }
        
        updateCanvasLabel()
        handleCanvasSizeLabel(gestureRecognizer: gestureRecognizer)
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
