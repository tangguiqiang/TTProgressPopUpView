//
//  TTProgressPopUpView.swift
//  TTProgressView
//
//  Created by tang on 2017/2/21.
//  Copyright © 2017年 tang. All rights reserved.
//

import UIKit


// to supply custom text to the popUpView label, implement <ASProgressPopUpViewDataSource>
// the dataSource will be messaged each time the progress changes
@objc protocol TTProgressPopUpViewDataSource: NSObjectProtocol {
    @objc
    func ttProgressView(progressView: TTProgressPopUpView, progress: CGFloat) -> String?
    
    // by default the popUpView precalculates the largest size required and uses this size to display all values
    // if you'd prefer the popUpView to change size as the text values change then return NO from this method
    @objc
    optional func progressViewShouldPreCalculatePopUpViewSize(progressView: TTProgressPopUpView) -> Bool
}



// when embedding an ASProgressPopUpView inside a TableView or CollectionView
// you need to ensure that the cell it resides in is brought to the front of the view hierarchy
// to prevent the popUpView from being obscured
@objc protocol TTProgressPopUpViewDelegate: NSObjectProtocol {
    @objc
    func progressViewWillDisplayPopUpView(progressView: TTProgressPopUpView)
    
    @objc
    optional func progressViewDidHidePopUpView(progressView: TTProgressPopUpView)
    
}

class TTProgressPopUpView: UIProgressView {
    private var tent: String?
    var dataSource: TTProgressPopUpViewDataSource? {
        didSet {
            caculatePopViewSize()
        }
    }
    var delegate: TTProgressPopUpViewDelegate?
    
    // private
    private lazy var popUpView: TTPopUpView? = {
       let temp = TTPopUpView(frame: CGRect.zero)
        temp.alpha = 0.0
        temp.delegate = self
        
       return temp
    }()
    private lazy var numberFormatter: NumberFormatter? = {
        let temp = NumberFormatter()
        temp.numberStyle = .percent
        return temp
    }()
    
    private var defalutPopUpViewSize: CGSize?// size that fits string ‘100%’
    private var popUpViewSize: CGSize?// usually == _defaultPopUpViewSize, but can vary if dataSource is used
    private var _popUpViewColor: UIColor?
    private var keyTimes: NSArray?
    
    // public
    var textColor: UIColor? = UIColor.white {
        didSet {
            self.popUpView?.textColor = textColor
        }
    }
    
    var font: UIFont? = UIFont.systemFont(ofSize: 20.0) {
        didSet {
            self.popUpView?.font = font
            caculatePopViewSize()
        }
    }
    // setting the value of 'popUpViewColor' overrides 'popUpViewAnimatedColors' and vice versa
    // the return value of 'popUpViewColor' is the currently displayed value
    // this will vary if 'popUpViewAnimatedColors' is set (see below)
    var popUpViewColor: UIColor? {
        
        set {
            _popUpViewColor = newValue
            popViewAnimationColors = nil
            self.popUpView?.color = newValue
            if autoAdjustTrackColor == true {
            super.progressTintColor = self.popUpView?.opaqueColor()
            }
        }
        get {
            if self.popUpView?.color == nil {
                return _popUpViewColor
            } else {
                return self.popUpView?.color
            }
        }
    }
    
    // pass an array of 2 or more UIColors to animate the color change as the progress updates
    var popViewAnimationColors: [UIColor]? {
        didSet {
            setPopUpViewAniamtionColors(popUpViewAnimationColors2: popViewAnimationColors, positions: nil)
        }
    }
    
    // radius of the popUpView, default is 4.0
    var popUpViewCornerRadius: CGFloat = 4.0 {
        didSet {
            self.popUpView?.cornerRadius = popUpViewCornerRadius
        }
    }
    
    // changes the progress track to match current popUpView color
    // the track color alpha is always set to 1.0, even if popUpView color is less than 1.0. dufault is true
    private var _autoAdjustTrackColor: Bool = true
    var autoAdjustTrackColor: Bool {
        set {
            _autoAdjustTrackColor = newValue
            if _autoAdjustTrackColor == false {
                super.progressTintColor = nil
            } else {
                super.progressTintColor = self.popUpView?.opaqueColor()
            }
        }
        get {
            return _autoAdjustTrackColor
        }
    }
    
    // the above @property distributes the colors evenly across the progress view
    // to specify the exact position of colors, pass an NSArray of NSNumbers (in the range 0.0 - 1.0)
    func setPopUpViewAniamtionColors(popUpViewAnimationColors2: [UIColor]?, positions: [NSNumber]?) {
        guard popUpViewAnimationColors2 != nil else {
            return
        }
        
        guard positions != nil else {
            return
        }
        
        if positions != nil {
            assert(popUpViewAnimationColors2?.count == positions?.count, "popUpViewAnimatedColors and locations should contain the same number of items")
        }
        self.popViewAnimationColors = popUpViewAnimationColors2
        
        if (popUpViewAnimationColors2?.count)! >= 2 {
            self.popUpView?.setAnimation(colors: popUpViewAnimationColors2!, keyTimes: keyTimes as! [NSNumber])
        } else {
            if popUpViewAnimationColors2?.last == nil {
                self.popUpViewColor = _popUpViewColor
            } else {
                self.popUpViewColor = popUpViewAnimationColors2?.last
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    private func setup() {
        defalutPopUpViewSize = self.popUpView?.popUpSizeFor(string: (numberFormatter?.string(from: NSNumber(value: 1.0)))!)
        popUpViewSize = defalutPopUpViewSize
//        textColor = UIColor.white
        self.popUpViewColor = UIColor(hue: 0.6, saturation: 0.6, brightness: 0.5, alpha: 0.8)
        self.addSubview(self.popUpView!)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    func showPopUpView(animated: Bool) {
        if self.popUpView?.alpha == 1 { return }
        self.delegate?.progressViewWillDisplayPopUpView(progressView: self)
        self.popUpView?.showAnimation(animated: animated)
    }
    func hidePopUpView(animated: Bool) {
        if self.popUpView?.alpha == 0 { return }
        self.popUpView?.hideAnimation(animated: animated, completionBlock: {
            guard self.delegate != nil else { return }
            self.delegate?.progressViewDidHidePopUpView!(progressView: self)
        })
    }
    
    override func didMoveToWindow() {
        if self.window == nil {
            NotificationCenter.default.removeObserver(self)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActiveNotification(noti:)), name: Notification.Name.UIApplicationDidBecomeActive, object: nil)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePopUpView()
    }
    
    override var progressTintColor: UIColor? {
        willSet {
            self.autoAdjustTrackColor = false
        }
    }
    
    override var progress: Float {
        willSet {
            self.popUpView?.setAnimationOffset(animOffset: CGFloat(progress), returnColor: { (color) in
                super.progressTintColor = color
            })
        }
    }
    
    override func setProgress(_ progress: Float, animated: Bool) {
        if animated == true {
            self.popUpView?.animationBlock(animB: { (duration) in
                UIView.animate(withDuration: duration, animations: { 
                    super.setProgress(progress, animated: animated)
                    self.popUpView?.setAnimationOffset(animOffset: CGFloat(progress), returnColor: { (returnColor) in
                        super.progressTintColor = returnColor
                    })
                    self.layoutIfNeeded()
                })
            })
        } else {
            super.setProgress(progress, animated: animated)
        }
    }
    
    // private 
    private func caculatePopViewSize() {
        defalutPopUpViewSize = self.popUpView?.popUpSizeFor(string: (numberFormatter?.string(from: NSNumber(value: 1.0)))!)
        
        
        // if there isn't a dataSource, set _popUpViewSize to _defaultPopUpViewSize
        
        if self.dataSource == nil {
            popUpViewSize = defalutPopUpViewSize
            return
        }
        
        // if dataSource doesn't want popUpView size precalculated then return early from method
        if self.dataSource!.responds(to: #selector(self.dataSource?.progressViewShouldPreCalculatePopUpViewSize(progressView:))) && self.dataSource!.progressViewShouldPreCalculatePopUpViewSize!(progressView: self) == false { return }
        
        // calculate the largest popUpView size needed to keep the size consistent
        // ask the dataSource for values between 0.0 - 1.0 in 0.01 increments
        // set size to the largest width and height returned from the dataSource
        var width: CGFloat = 0.0, height: CGFloat = 0.0
        for i in 1...100 {
            let string = self.dataSource!.ttProgressView(progressView: self, progress: CGFloat(i / 100))
            if string != nil {
                let size = self.popUpView?.popUpSizeFor(string: string!)
                if let tempSize = size {
                    
                    if (tempSize.width) > width {
                        width = (tempSize.width)
                    }
                    if (tempSize.height) > height {
                        height = (tempSize.height)
                    }
                }
            }
        }
        
        popUpViewSize = (width > 0.0 && height > 0.0) ? CGSize(width: width, height: height) : defalutPopUpViewSize
    }
    
    @objc private func didBecomeActiveNotification(noti: Notification) {
        if self.popViewAnimationColors != nil {
            self.popUpView?.setAnimation(colors: popViewAnimationColors!, keyTimes: keyTimes as! [NSNumber])
        }
    }
    
    private func updatePopUpView() {
        var progressStr: String? = "0"
        if ((self.dataSource?.ttProgressView(progressView: self, progress: CGFloat(self.progress))) == nil) {
            progressStr = (numberFormatter?.string(from: NSNumber(value: self.progress)))

        } else {
            if let temp = self.dataSource?.ttProgressView(progressView: self, progress: CGFloat(self.progress)) {
                progressStr = temp
            }
        
        }
        
        
        if (self.dataSource?.responds(to: #selector(self.dataSource?.progressViewShouldPreCalculatePopUpViewSize(progressView:))))! && self.dataSource?.progressViewShouldPreCalculatePopUpViewSize!(progressView: self) == false {
            if self.dataSource?.ttProgressView(progressView: self, progress: CGFloat(self.progress)) != nil {
                popUpViewSize = self.popUpView?.popUpSizeFor(string: progressStr!)
            } else {
                popUpViewSize = defalutPopUpViewSize
            }
        }

        // calculate the popUpView frame
        let rect = self.bounds
        let xPos = rect.width * CGFloat(self.progress) - ((popUpViewSize?.width))! / 2
        var popUpRect = CGRect(x: xPos, y: rect.minY - (popUpViewSize?.height)!, width: (popUpViewSize?.width)!, height: (popUpViewSize?.height)!)
        
        
        // determine if popUpRect extends beyond the frame of the progress view
        // if so adjust frame and set the center offset of the PopUpView's arrow
        let minOffsetX = popUpRect.minX
        let maxOffsetX = popUpRect.maxX - rect.width
        
        let offset = minOffsetX < 0.0 ? minOffsetX : (maxOffsetX > 0.0 ? maxOffsetX : 0.0)
        popUpRect.origin.x -= offset
        
        self.popUpView?.setFrame(frame2: popUpRect, arrowOffset: offset, text: progressStr!)
        
    }

}

extension TTProgressPopUpView: PopUpViewProtocol {
    func currentValuleOffSet() -> CFTimeInterval {
        return CFTimeInterval(self.progress)
    }
    
    func colorDidUpdate(opaqueColor: UIColor) {
        super.progressTintColor = opaqueColor
    }
}




