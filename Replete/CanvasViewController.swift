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
 
 Should have custom REPL command to output a screenshot of the canvas
 to the replete table.
 
 Alternatively, could make it so whenever we request the js/canvas
 object from replete, it returns a screenshot.
 
 Just do a quick equality check on any output expression:
 evaluate against the canvas element.
 
 Double-tap gesture to enter fullscreen mode.
 Show banner indicating gesture to escape fullscreen, e.g.
 4-finger long-press or something.
 
 Fullscreen mode:
 - Make canvas view first responder
 - Allow user interaction
 - Alternative escape triggered by keyboard shortcuts with UIKeyCommand:
 https://developer.apple.com/reference/uikit/uikeycommand
 
 Could consider alternative mode with transparent keyboard and repl output
 floating in front of canvas. Have seen this used to delightful effect
 in the context of shader programming.
 
 */

extension CGAffineTransform {
    var xScale: Double {
        return sqrt(Double(self.a*self.a) + Double(self.c*self.c))
    }
    
    var yScale: Double {
        return sqrt(Double(self.b*self.b) + Double(self.d*self.d))
    }
}

extension UIImage{
    
    class func imageFromSystemBarButton(systemItem: UIBarButtonSystemItem, renderingMode:UIImageRenderingMode = .alwaysTemplate)-> UIImage {
        
        let tempItem = UIBarButtonItem(barButtonSystemItem: systemItem, target: nil, action: nil)
        
        // add to toolbar and render it
        UIToolbar().setItems([tempItem], animated: false)
        
        // got image from real uibutton
        let itemView = tempItem.value(forKey: "view") as! UIView
        
        for view in itemView.subviews {
            if view is UIButton {
                let button = view as! UIButton
                let image = button.imageView!.image!
                image.withRenderingMode(renderingMode)
                return image
            }
        }
        
        return UIImage()
    }
}


class CanvasViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var canvasView: EJJavaScriptView!
    var canvasSizeLabel: UILabel!
    var playPauseButton: UIButton!
    var playImage: UIImage!
    var pauseImage: UIImage!
    
    var lastPoint: CGPoint = CGPoint.zero
    var lastScale: CGFloat = 0.0
    // maybe the canvas should actually be the full window height
    // pixel-wise, just scaled down initially?
    var initialSize: CGSize = CGSize(width: 80, height: 120)
    let canvasMargin: CGFloat = 20
    var isCanvasFullscreen: Bool = false
    
    
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
        if (isCanvasFullscreen){
            canvasSizeLabel.text = "Long press with 4 fingers to exit fullscreen."
        } else {
            let w = Int(canvasView.frame.size.width)
            let h = Int(canvasView.frame.size.height)
            canvasSizeLabel.text = "\(w)x\(h)"
        }
    }
    
    func showPlayPauseButton(){
        self.playPauseButton.isHidden = false
        self.playPauseButton.alpha = 1.0
    }
    
    func fadeOutPlayPauseButton() {
        self.playPauseButton.isHidden = false

        UIView.animate(withDuration: 1.0, delay: 2.0,
                       options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
                       animations: {
            // wtf: http://stackoverflow.com/a/31102406
            self.playPauseButton.alpha = 0.1
        }, completion: {
            finished in
            self.playPauseButton.isHidden = finished
        })
    }
    
    func showCanvasLabel() {
        self.canvasSizeLabel.isHidden = false
        self.canvasSizeLabel.alpha = 1.0
    }
    
    func fadeOutCanvasLabel() {
        self.canvasSizeLabel.isHidden = false

        UIView.animate(withDuration: 1.0, delay: 2.0,
                       options: [.curveEaseInOut, .beginFromCurrentState],
                       animations: {
            self.canvasSizeLabel.alpha = 0.0
        }, completion: {
            finished in
            self.canvasSizeLabel.isHidden = finished
        })
    }

    override func loadView() {
        super.loadView()

        // Do any additional setup after loading the view.
        self.view = UIView()
        self.view.backgroundColor = UIColor.gray
        self.view.frame = calculateViewFrame()
        
        let canvasFrame = CGRect(origin: CGPoint.zero, size: initialSize)

        canvasView = EJJavaScriptView(frame: canvasFrame, appFolder: "out/")
        // initially disable interaction until we enter fullscreen
        canvasView.isUserInteractionEnabled = false
        
        let panR = UIPanGestureRecognizer.init(target: self, action: #selector(handlePan))
        panR.cancelsTouchesInView = true
        panR.delegate = self
        
        let tapR = UILongPressGestureRecognizer.init(target: self, action: #selector(handleTap))
        tapR.minimumPressDuration = 0
        tapR.cancelsTouchesInView = false
        tapR.delegate = self
        
        let pinchR = UIPinchGestureRecognizer.init(target: self, action: #selector(handlePinch))
        pinchR.cancelsTouchesInView = true
        pinchR.delegate = self
        
        let doubleTapR = UITapGestureRecognizer.init(target: self, action: #selector(handleDoubleTap))
        doubleTapR.numberOfTapsRequired = 2
        doubleTapR.cancelsTouchesInView = false
        doubleTapR.delegate = self
        
        let fourFingerPressR = UILongPressGestureRecognizer.init(target: self, action: #selector(handleFourFingerPress))
        fourFingerPressR.numberOfTouchesRequired = 4
        fourFingerPressR.minimumPressDuration = 0.5
        fourFingerPressR.cancelsTouchesInView = false
        fourFingerPressR.delegate = self
        
        self.view.addGestureRecognizer(panR)
        self.view.addGestureRecognizer(tapR)
        self.view.addGestureRecognizer(pinchR)
        self.view.addGestureRecognizer(doubleTapR)
        self.view.addGestureRecognizer(fourFingerPressR)
        
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
        self.view.addSubview(canvasSizeLabel)
        
        playImage = UIImage.imageFromSystemBarButton(systemItem: .play)
        pauseImage = UIImage.imageFromSystemBarButton(systemItem: .pause)
        
        playPauseButton = UIButton(type: UIButtonType.system)
        playPauseButton.frame = CGRect(
            x: 0,
            y: 0,
            width: 40,
            height: 40
        )
        
        playPauseButton.layer.cornerRadius = 20
        playPauseButton.layer.borderColor = UIColor.white.cgColor
        playPauseButton.layer.borderWidth = 2
        playPauseButton.tintColor = UIColor.white
        playPauseButton.backgroundColor = UIColor.init(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.5)
        playPauseButton.center = canvasView.center
        playPauseButton.showsTouchWhenHighlighted = true
        
        playPauseButton.addTarget(self, action: #selector(handleClickPlayPause), for: .touchUpInside)
        setPlayPauseImage()

        self.view.addSubview(playPauseButton)
    }
    
    override func viewDidLoad() {
        canvasView.loadScript(atPath: "index.js")
        
        updateCanvasLabel()
        fadeOutCanvasLabel()
        fadeOutPlayPauseButton()
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
        
        playPauseButton.center = self.canvasView.center
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: UIKeyInputEscape, modifierFlags: .shift,
                         action: #selector(exitFullscreen),
                         discoverabilityTitle: "Exit Fullscreen Canvas")
        ]
    }
    
    func resetSmallCanvasFrame(){
        // resets the canvas view frame to small size
        // done when rotating screen or when exiting fullscreen
        let rotatedFrame = self.calculateViewFrame()
        
        let canvasFrame = CGRect(origin: CGPoint.zero, size: rotatedFrame.size)
        self.canvasView.frame = canvasFrame
        self.resizeCanvasContext(newCanvasFrame: canvasFrame)
        
        self.view.frame = rotatedFrame
        self.view.setNeedsLayout()
        self.updateCanvasLabel()
        
        print("Transitioned view frame...")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil, completion: {
            _ in
            
            self.resetSmallCanvasFrame()
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
        if touch.view is UIControl {
            return false
        }
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
    
    func handlePlayPauseButton(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            showPlayPauseButton()
        }
        if gestureRecognizer.state == .ended {
            fadeOutPlayPauseButton()
        }
    }
    
    func handleCanvasSizeLabel(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            showCanvasLabel()
        }
        
        if gestureRecognizer.state == .ended {
            fadeOutCanvasLabel()
        }
    }
    
    func setPlayPauseImage(){
        if (self.canvasView.isPaused) {
            self.playPauseButton.setImage(playImage, for: UIControlState.normal)
        } else {
            self.playPauseButton.setImage(pauseImage, for: UIControlState.normal)
        }
    }
    
    @IBAction func handleClickPlayPause(_ sender: UIButton) {
        self.canvasView.isPaused = !self.canvasView.isPaused
        setPlayPauseImage()
        showPlayPauseButton()
    }
    
    func makeCanvasFullscreen(){
        let fullscreenBounds = UIScreen.main.bounds
        self.view.frame = fullscreenBounds
        self.canvasView.frame = fullscreenBounds
        self.resizeCanvasContext(newCanvasFrame: fullscreenBounds)
        self.view.setNeedsLayout()
        self.becomeFirstResponder()
        self.canvasView.isUserInteractionEnabled = true
        isCanvasFullscreen = true
        self.setNeedsStatusBarAppearanceUpdate()
        self.updateCanvasLabel()
    }
    
    @IBAction func exitFullscreen(sender: UIKeyCommand?) {
        self.resignFirstResponder()
        self.canvasView.isUserInteractionEnabled = false
        isCanvasFullscreen = false
        resetSmallCanvasFrame()
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    @IBAction func handleFourFingerPress(_ gestureRecognizer: UIGestureRecognizer) {
        if (isCanvasFullscreen){
            exitFullscreen(sender: nil)
        }
    }
    
    @IBAction func handleDoubleTap(_ gestureRecognizer: UIGestureRecognizer) {
        if (!isCanvasFullscreen){
            makeCanvasFullscreen()
        }
    }
    
    @IBAction func handleTap(_ gestureRecognizer: UIGestureRecognizer) {
        if !isCanvasFullscreen {
            handleShadow(gestureRecognizer: gestureRecognizer)
            handleCanvasSizeLabel(gestureRecognizer: gestureRecognizer)
            handlePlayPauseButton(gestureRecognizer: gestureRecognizer)
        }
    }
    
    func handleTranslate(gestureRecognizer: UIGestureRecognizer) {
        if !isCanvasFullscreen {
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
    }

    
    @IBAction func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        if !isCanvasFullscreen {
            handleTranslate(gestureRecognizer: gestureRecognizer)
            handleShadow(gestureRecognizer: gestureRecognizer)
            handleCanvasSizeLabel(gestureRecognizer: gestureRecognizer)
            handlePlayPauseButton(gestureRecognizer: gestureRecognizer)
        }
    }
    
    @IBAction func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        if !isCanvasFullscreen {
            handleShadow(gestureRecognizer: gestureRecognizer)
            handlePlayPauseButton(gestureRecognizer: gestureRecognizer)
            
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
            setPlayPauseImage()
            handleCanvasSizeLabel(gestureRecognizer: gestureRecognizer)
        }
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
