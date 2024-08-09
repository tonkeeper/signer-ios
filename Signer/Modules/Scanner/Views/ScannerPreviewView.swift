import UIKit
import AVFoundation

final class ScannerPreviewView: UIView {
  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }
  
  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }
  
  var session: AVCaptureSession? {
    get {
      return videoPreviewLayer.session
    }
    
    set {
      videoPreviewLayer.session = newValue
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    videoPreviewLayer.videoGravity = .resizeAspectFill
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
