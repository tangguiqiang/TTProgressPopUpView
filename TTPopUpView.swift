//
//  TTPopUpView.swift
//  TTProgressView
//
//  Created by tang on 2017/2/21.
//  Copyright © 2017年 tang. All rights reserved.
//  基于 ASPopUpView 的swift版本


// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// This UIView subclass is used internally by ASProgressPopUpView
// The public API is declared in ASProgressPopUpView.h
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

import UIKit

protocol PopUpViewProtocol {
    func currentValuleOffSet() -> CFTimeInterval
    func colorDidUpdate(opaqueColor: UIColor)
}

let arrowHeight: CGFloat = 8.0
let popViewWidth_Pad: CGFloat = 1.15
let popViewHeight_Dad: CGFloat = 1.1
let fillColorAnimationKey = "fillColor"

class TTPopUpView: UIView {

    // public
    var delegate: PopUpViewProtocol?
    
    private var _cornerRadius: CGFloat?
    
    var cornerRadius: CGFloat? {
        set {
            if _cornerRadius != newValue {
                _cornerRadius = newValue
                self.pathLayer?.path = path(forRect: bounds, arrowOffset: arrowCenterOffSet!)?.cgPath
            }
        }
        get {
            return _cornerRadius
        }
        
    }
    private var _color: UIColor?
    var color: UIColor? {
        set {
            if _color != newValue {
                _color = newValue
            }
            pathLayer?.fillColor = _color?.cgColor
            colorAnimLayer.removeAnimation(forKey: fillColorAnimationKey)
        }
        get {
            return UIColor(cgColor: (pathLayer?.presentation()?.fillColor)!)
        }
    }
    
    // private
    private var shouldAnimate: Bool = false
    private var animateDuration: CFTimeInterval?
    private lazy var attributeString: NSMutableAttributedString = NSMutableAttributedString()
    internal var pathLayer: CAShapeLayer?
    private lazy var textLayer: CATextLayer = {
        let textL = CATextLayer()
        textL.alignmentMode = "center"
        textL.anchorPoint = CGPoint(x: 0, y: 0)
        textL.contentsScale = UIScreen.main.scale
        let defalutTextLAnim = CABasicAnimation()
        defalutTextLAnim.duration = 0.25
        textL.actions = ["contents": defalutTextLAnim]
        return textL
    }()
    private var arrowCenterOffSet: CGFloat? = 0.0
    // never actually visible, its purpose is to interpolate color values for the popUpView color animation
    // using shape layer because it has a 'fillColor' property which is consistent with _backgroundLayer
    internal lazy var colorAnimLayer: CAShapeLayer = CAShapeLayer()
    
    
    override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }
    
    override func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if self.shouldAnimate == true {
            let anim = CABasicAnimation(keyPath: event)
            anim.beginTime = CACurrentMediaTime()
            anim.timingFunction = CAMediaTimingFunction(name: "easeInEaseOut")
            anim.fromValue = layer.presentation()?.value(forKey: event)
            anim.duration = self.animateDuration!
            return anim
        } else {
            return NSNull()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let textHeight = self.attributeString.size().height
        let textRect = CGRect(x: bounds.origin.x, y: (bounds.size.height - arrowHeight - textHeight) / 2, width: bounds.size.width, height: textHeight)
        self.textLayer.frame = textRect.integral
        
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        isUserInteractionEnabled = true
        pathLayer = (self.layer) as? CAShapeLayer
        
        self.cornerRadius = 4.0
        self.layer.addSublayer(self.textLayer)
        self.layer.addSublayer(self.colorAnimLayer)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // public func
    func opaqueColor() -> UIColor? {
        if colorAnimLayer.presentation()?.fillColor == nil {
            return opaqueUIColorFromCGColor(col: (pathLayer?.fillColor)!)
        } else {
            return nil
        }
    }
    
    var textColor: UIColor? {
        didSet {
            textLayer.foregroundColor = textColor?.cgColor
        }
    }
    
    var font: UIFont? {
        didSet {
            attributeString.addAttribute(NSFontAttributeName, value: font ?? 15.0, range: NSRange(location: 0, length: attributeString.length))
            textLayer.font = font?.fontName as CFTypeRef?
            if let temp = font?.pointSize {
                textLayer.fontSize = temp
            }
        }
    }
    
    var text: String? {
        didSet {
            if let temp = text {
                attributeString.mutableString.setString(temp)
                textLayer.string = temp
            }
        }
    }
   
    
    func setAnimation(colors: [UIColor], keyTimes: [NSNumber]) {
        var cgColorsArr = [CGColor]()
        for color in colors {
            cgColorsArr.append(color.cgColor)
        }
        
        let keyAnim = CAKeyframeAnimation(keyPath: fillColorAnimationKey)
        keyAnim.keyTimes = keyTimes
        keyAnim.values = cgColorsArr
        keyAnim.fillMode = "both"
        keyAnim.duration = 1
        keyAnim.delegate = self
        
        colorAnimLayer.speed = FLT_MIN
        colorAnimLayer.timeOffset = 0.0
        colorAnimLayer.add(keyAnim, forKey: fillColorAnimationKey)
    }
    
    func setAnimationOffset(animOffset: CGFloat, returnColor: ((_ opaqueReturnColor: UIColor?) -> ())?) {
        if (colorAnimLayer.animation(forKey: fillColorAnimationKey) != nil) {
            colorAnimLayer.timeOffset = CFTimeInterval(animOffset)
            pathLayer?.fillColor = colorAnimLayer.presentation()?.fillColor
            
            if let block = returnColor {
                block(opaqueColor())
            }
        }
    }
    
    func setFrame(frame2: CGRect, arrowOffset: CGFloat, text: String) {
        // only redraw path if either the arrowOffset or popUpView size has changed
        
        if arrowOffset != arrowCenterOffSet || !frame2.size.equalTo(self.frame.size) {
            pathLayer?.path = path(forRect: frame2, arrowOffset: arrowOffset)?.cgPath
        }
        
        arrowCenterOffSet = arrowOffset
        
        let anchorX = 0.5 + (arrowOffset / frame2.width)
        self.layer.anchorPoint = CGPoint(x: anchorX, y: 1)
        self.layer.position = CGPoint(x: frame2.minX + frame2.width * anchorX, y: 0)
        self.layer.bounds = CGRect(origin: CGPoint.zero, size: frame2.size)
        self.text = text
        
    }
    
    
    func animationBlock(animB: ((_ durationT: CFTimeInterval) -> ())?) {
        shouldAnimate = true
        animateDuration = 0.5
        let anim = layer.animation(forKey: "position")
        if anim != nil { // if previous animation hasn't finished reduce the time of new animation
            let elapsedTime = min(CACurrentMediaTime() - (anim?.beginTime)!, (anim?.duration)!)
            animateDuration = animateDuration! * elapsedTime / (anim?.duration)!
        }
        if animB != nil {
            animB!(animateDuration!)
        }
        shouldAnimate = false
        
    }
    
    func popUpSizeFor(string: String) -> CGSize {
        attributeString.mutableString.setString(string)
        let w = ceil(attributeString.size().width * popViewWidth_Pad)
        let h = ceil(attributeString.size().height * popViewHeight_Dad + arrowHeight)
        return CGSize(width: w, height: h)
    }
    
    func showAnimation(animated: Bool) {
        if animated == false {
            self.layer.opacity = 1.0
            return
        }
        
        CATransaction.begin()
        // start the transform animation from scale 0.5, or its current value if it's already running
        let fromeValue = self.layer.animation(forKey: "transform") != nil ? self.layer.presentation()?.value(forKey: "transform") : NSValue(caTransform3D: CATransform3DMakeScale(0.5, 0.5, 1))
        
        self.layer.customAnimation(animationName: "transform", fromeValue: fromeValue, toValue: NSValue(caTransform3D: CATransform3DIdentity), customizeBlock: {
            (animation) in
            animation.duration = 0.6
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.8, 2.5, 0.35, 0.5)
        })
        
        self.layer.customAnimation(animationName: "opacity", fromeValue: nil, toValue: 1.0, customizeBlock: {
            animation in
            animation.duration = 0.1
        })
        
        CATransaction.commit()
        
    }

    func hideAnimation(animated: Bool, completionBlock: (() -> ())?) {
        CATransaction.begin()
        
        CATransaction.setCompletionBlock { 
            if completionBlock != nil {
                completionBlock!()
            }
            self.layer.transform = CATransform3DIdentity
        }
        
        if animated == true {
            self.layer.customAnimation(animationName: "transform", fromeValue: nil, toValue: NSValue(caTransform3D:CATransform3DMakeScale(0.5, 0.5, 1)), customizeBlock: { (animation) in
                animation.duration = 0.55
                animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, -2, 0.3, 3)
            })
            
            self.layer.customAnimation(animationName: "opacity", fromeValue: nil, toValue: 0.0, customizeBlock: { (animation) in
                animation.duration = 0.75
            })
        } else {
            self.layer.opacity = 0.0
        }
        
        CATransaction.commit()
    }
    
    
    
    
    // private func
    private func path(forRect: CGRect, arrowOffset: CGFloat) -> UIBezierPath? {
        
        guard forRect.equalTo(CGRect.zero) == false else {
            return nil
        }
        
        let rect = CGRect(origin: CGPoint.zero, size: forRect.size)
            
            // Create rounded rect
        
        var roundedRect = rect
        roundedRect.size.height -= arrowHeight
        
        let popPath = UIBezierPath(roundedRect: roundedRect, cornerRadius: self.cornerRadius!)
        // create arrow path
        let maxX = roundedRect.maxX
        let arrowTipX = rect.midX + arrowOffset
        let tip = CGPoint(x: arrowTipX, y: rect.maxY)
        
        let arrowLength = roundedRect.height / 2.0
        let x = arrowLength * tan(CGFloat(45.0) * CGFloat(M_PI / 180)) // x = half the length of the base of the arrow
        
        let arrowPath = UIBezierPath()
        arrowPath.move(to: tip)
        arrowPath.addLine(to: CGPoint(x: max(arrowTipX - x, 0), y: roundedRect.maxY - arrowLength))
        arrowPath.addLine(to: CGPoint(x: min(arrowTipX + x, maxX), y: roundedRect.maxY - arrowLength))
        arrowPath.close()
        
        popPath.append(arrowPath)
        
        return popPath
        
        
    }
    
    // 这个是c函数转的
    private func opaqueUIColorFromCGColor(col: CGColor?) -> UIColor? {
        guard col != nil else {
            return nil
        }
        
        let components = col?.components
        if col?.numberOfComponents == 2 {
            return UIColor(white: (components?[0])!, alpha: 1.0)
        } else {
            return UIColor(red: (components?[0])!, green: (components?[1])!, blue: (components?[2])!, alpha: 1.0)
        }
    }
    
}



extension TTPopUpView: CAAnimationDelegate {
    func animationDidStart(_ anim: CAAnimation) {
        colorAnimLayer.speed = 0.0
        colorAnimLayer.timeOffset = (self.delegate?.currentValuleOffSet())!
        
        pathLayer?.fillColor = colorAnimLayer.presentation()?.fillColor
        self.delegate?.colorDidUpdate(opaqueColor: self.opaqueColor()!)
        
    }}

extension CALayer {
    func customAnimation(animationName: String, fromeValue: Any?, toValue: Any?, customizeBlock:((_ baseAnim: CABasicAnimation) -> ())?) {
        self.setValue(toValue, forKey: animationName)
        let anim = CABasicAnimation(keyPath: animationName)
        if fromeValue == nil {
            anim.fromValue = self.presentation()?.value(forKey: animationName)
        } else {
            anim.fromValue = fromeValue
        }
        anim.toValue = toValue
        
        if customizeBlock != nil {
            customizeBlock!(anim)
        }
        
        self.add(anim, forKey: animationName)
        
    }
}


