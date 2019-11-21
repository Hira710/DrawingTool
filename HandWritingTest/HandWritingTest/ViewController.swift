//
//  ViewController.swift
//  HandWritingTest
//
//  Created by mini2014a on 2019/11/21.
//  Copyright © 2019 HK. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {

    @IBOutlet var resultLabel:UILabel!
    @IBOutlet var canvasView:UIImageView!

    var charDict:Dictionary<String,String> = Dictionary<String,String>()
    var lastDrawImage:UIImage!
    var bezierPath:UIBezierPath!
    
    var minX:CGFloat!
    var maxX:CGFloat!
    var minY:CGFloat!
    var maxY:CGFloat!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        loadCharInfo()
        onClickedResetBtn()
    }
    func loadCharInfo() {
        guard let charPath:String = Bundle.main.path(forResource: "chars", ofType: "plist") else {
            return
        }
        if let array = NSArray.init(contentsOfFile: charPath){
            for i in 0..<array.count {
                guard let dict:Dictionary<String,String> = array[i] as? Dictionary<String,String> else{
                    continue
                }
                let ascii:String = dict["ascii"] ?? ""
                let value:String = dict["char"] ?? ""
                if (ascii != "" && value != "") {
                    charDict[ascii] = value
                }
            }
        }
//        debugPrint("\(charDict)")
    }
    @IBAction func onClickedResetBtn(){
        canvasView.image = nil
        lastDrawImage = nil
        bezierPath = nil
        resultLabel.text = ""
        resetArea()
    }
    
    // MARK: - Draw
    override func touchesBegan(_ touches: Set<UITouch>,
                               with event: UIEvent?)
    {
        super.touchesBegan(touches, with: event)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(findChar), object: nil)
        
        if let touch = touches.first{
            let currentPoint:CGPoint = touch.location(in: canvasView)
            bezierPath = UIBezierPath.init()
            bezierPath.lineCapStyle = CGLineCap.round
            bezierPath.lineWidth = 4.0
            bezierPath.move(to: currentPoint)
            computeArea(paintPoint: currentPoint)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>,
                               with event: UIEvent?){
        super.touchesMoved(touches, with: event)
        if (bezierPath == nil){
            return;
        }
        if let touch = touches.first{
            let currentPoint:CGPoint = touch.location(in: canvasView)
            
            bezierPath.addLine(to: currentPoint)
            drawLine()
            computeArea(paintPoint: currentPoint)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>,
                               with event: UIEvent?){
        super.touchesEnded(touches, with: event)
        if (bezierPath == nil){
            return;
        }
        if let touch = touches.first{
            let currentPoint:CGPoint = touch.location(in: canvasView)
            bezierPath.addLine(to: currentPoint)
            drawLine()
            computeArea(paintPoint: currentPoint)
        }
        lastDrawImage = canvasView.image

        perform(#selector(findChar), with: nil, afterDelay: 0.3)
    }
    func drawLine(){
        UIGraphicsBeginImageContext(canvasView.frame.size)
        if lastDrawImage != nil {
            lastDrawImage.draw(at: CGPoint.zero)
        }
        
        UIColor.black.setStroke()
        bezierPath.stroke()
        canvasView.image=UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    func resetArea() {
        minX = self.canvasView.frame.size.width
        maxX = 0
        minY = self.canvasView.frame.size.height
        maxY = 0
    }
    func computeArea(paintPoint:CGPoint){
        if paintPoint.x>maxX {
            maxX=paintPoint.x
        }
        if paintPoint.x<minX {
            minX = paintPoint.x
        }
        if paintPoint.y>maxY {
            maxY=paintPoint.y
        }
        if paintPoint.y<minY {
            minY=paintPoint.y
        }
    }
    
    @objc func findChar(){
        if lastDrawImage==nil {
            NSLog("lastDrawImage = nil")
            return
        }
        let canvasWidth = canvasView.frame.size.width
        let canvasHeight = canvasView.frame.size.height
        let outline:CGFloat = 5
        var dMinX:CGFloat = minX-outline
        if dMinX<0 {
            dMinX=0
        }
        var dMaxX:CGFloat = maxX+outline
        if dMaxX>canvasWidth {
            dMaxX=canvasWidth
        }
        var dMinY:CGFloat = minY-outline
        if dMinY<0 {
            dMinY=0
        }
        var dMaxY:CGFloat = maxY+outline
        if dMaxY>canvasHeight {
            dMaxY=canvasHeight
        }
        let emojiWidth:CGFloat = dMaxX-dMinX
        let emojiHeight:CGFloat = dMaxY-dMinY
        let cropRect:CGRect = CGRect(x:dMinX,y:dMinY,width:emojiWidth,height:emojiHeight)
        let cropImgRef:CGImage = lastDrawImage.cgImage!.cropping(to: cropRect)!
        let croppedImage: UIImage = UIImage(cgImage: cropImgRef)
        
        let space:CGFloat = 20
        var drawX:CGFloat = space
        var drawY:CGFloat = space
        var maxWidth:CGFloat = canvasWidth-space*2
        var maxHeight:CGFloat = canvasHeight-space*2
        if emojiWidth>emojiHeight {
            maxHeight = maxWidth*emojiHeight/emojiWidth
            drawY = (canvasHeight-maxHeight)/2
        }else{
            maxWidth = maxHeight*emojiWidth/emojiHeight
            drawX=(canvasWidth-maxWidth)/2
        }
        let drawWidth:CGFloat = 224.0
        let drawHeight:CGFloat = 224.0
        let drawRect:CGRect = CGRect(x:0,y:0,width:drawWidth,height:drawHeight)
        let canvasToDrawW = drawWidth/canvasWidth
        let canvasToDrawH = drawHeight/canvasHeight
        let drawArea = CGRect(x:drawX*canvasToDrawW,y:drawY*canvasToDrawH,width:maxWidth*canvasToDrawW,height:maxHeight*canvasToDrawH)
        UIGraphicsBeginImageContext(drawRect.size)
        UIColor.white.set()
        UIRectFill(drawRect)
        croppedImage.draw(in: drawArea)
        let resultImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        updateClassifications(for: resultImage)
    }
    
    // MARK: - ML
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            //NSLog("lazy classificationRequest")
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let model = try VNCoreMLModel(for: ImageClassifier().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    /// - Tag: PerformRequests
    func updateClassifications(for image: UIImage) {
        //NSLog("updateClassifications")
        //classificationTV.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            //NSLog("DispatchQueue updateClassifications")
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                debugPrint("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        debugPrint("processClassifications")
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.resultLabel.text = "-"
                return
            }

            let classifications = results as! [VNClassificationObservation]
            
            if classifications.isEmpty {
                //self.classificationTV.text = "Nothing recognized."
                //self.foundEmoji(emojiArray: ["none"]);
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(4)
                let charResult = topClassifications.map { classification -> [String:String] in
                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
                    let charValue:String = self.charDict[classification.identifier] ?? ""
                    if(charValue != ""){
                        let charConf = String(format: "%d", Int(classification.confidence*100))
                        return ["char":charValue,"conf":charConf]
                    }else{
                        return ["char":"","conf":"0"]
                    }
                }
                if(charResult.count>0){
                    self.showResult(charArray: charResult);
                }
            }
        }
    }
    func showResult(charArray:[[String:String]]) {
        var resultStr = ""
        for i in 0..<charArray.count {
            let charInfo = charArray[i]
            let charValue = charInfo["char"]
            let charConf = charInfo["conf"]
            let charConfInt = (charConf! as NSString).intValue
            if charConfInt > 10 {
                resultStr = resultStr.appending(String(format: "%@(%d%%)",charValue!, charConfInt))
            }
        }
        resultLabel.text = resultStr
    }
}

