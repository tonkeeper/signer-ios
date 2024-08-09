import UIKit
import TKUIKit

final class ScannerView: UIView {

  let previewView = ScannerPreviewView()
  let cameraPermissionViewContainer = UIView()
  let dimmingView = UIView()
  let titleLabel = UILabel()
  let captionLabel = UILabel()
  let flashlightButton = ToggleButton()
  private let labelsStackView = UIStackView()
  private let viewFinderView = UIView()
  private let viewFinderMaskLayer = CAShapeLayer()
  private let viewFinderCornersLayer = CAShapeLayer()
    
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    previewView.frame = bounds
    cameraPermissionViewContainer.frame = bounds
    dimmingView.frame = bounds
    
    let viewFinderRect = calculateViewFinderRect(bounds: bounds)
    
    viewFinderMaskLayer.path = createViewFinderBezierPath(bounds: bounds).cgPath
    viewFinderMaskLayer.frame = bounds
    
    viewFinderCornersLayer.path = createCornersPath(
      viewFinderRect: viewFinderRect
    )
    viewFinderMaskLayer.frame = bounds
    
    viewFinderView.frame = viewFinderRect
    
    let flashlightButtonFrame = CGRect(x: bounds.width/2 - .flashlightButtonSide/2,
                                       y: viewFinderRect.maxY + .flashlightButtonTopOffset,
                                       width: .flashlightButtonSide,
                                       height: .flashlightButtonSide)
    flashlightButton.frame = flashlightButtonFrame
    flashlightButton.layer.cornerRadius = flashlightButtonFrame.height / 2
  }
  
  func setCameraPermissionDeniedView(_ view: UIView) {
    cameraPermissionViewContainer.addSubview(view)
    view.snp.makeConstraints { make in
      make.edges.equalTo(cameraPermissionViewContainer)
    }
  }
}

private extension ScannerView {
  func setup() {
    backgroundColor = .black
    
    cameraPermissionViewContainer.isHidden = true
    
    dimmingView.backgroundColor = .black.withAlphaComponent(0.72)
    
    viewFinderMaskLayer.fillColor = UIColor.orange.cgColor
    viewFinderMaskLayer.fillRule = .evenOdd
    dimmingView.layer.mask = viewFinderMaskLayer
    
    viewFinderCornersLayer.strokeColor = UIColor.white.cgColor
    viewFinderCornersLayer.fillColor = UIColor.clear.cgColor
    viewFinderCornersLayer.lineWidth = 3
    viewFinderCornersLayer.lineCap = .round
    dimmingView.layer.addSublayer(viewFinderCornersLayer)
    
    viewFinderView.layer.addSublayer(viewFinderCornersLayer)
    
    labelsStackView.axis = .vertical
    labelsStackView.spacing = 4
    titleLabel.numberOfLines = 0
    captionLabel.numberOfLines = 0
    captionLabel.alpha = 0.64
    
    setupFlashlightButton()
    
    addSubview(previewView)
    addSubview(dimmingView)
    addSubview(viewFinderView)
    addSubview(labelsStackView)
    addSubview(flashlightButton)
    addSubview(cameraPermissionViewContainer)
    
    labelsStackView.addArrangedSubview(titleLabel)
    labelsStackView.addArrangedSubview(captionLabel)
    
    labelsStackView.snp.makeConstraints { make in
      make.bottom.equalTo(viewFinderView.snp.top).offset(-CGFloat.titleBottomOffset)
      make.left.equalTo(self).offset(32)
      make.right.equalTo(self).offset(-32)
    }
  }
  
  func setupFlashlightButton() {
    flashlightButton.isHidden = true
    flashlightButton.setBackgroundColor(
      .black.withAlphaComponent(0.48),
      for: .deselected
    )
    flashlightButton.setBackgroundColor(
      .white,
      for: .selected
    )
    flashlightButton.setTintColor(
      .white,
      for: .deselected
    )
    flashlightButton.setTintColor(
      .black,
      for: .selected
    )
    flashlightButton.setImage(.TKUIKit.Icons.Size56.flashlightOff,
                              for: .normal)
  }
  
  func calculateViewFinderRect(bounds: CGRect) -> CGRect {
    let side = bounds.width - (.holeSideOffset * 2)
    let x: CGFloat = .holeSideOffset
    let y: CGFloat = bounds.height/2 - side/2
    let rect = CGRect(x: x, y: y,
                      width: side, height: side)
    return rect
  }
  
  func createViewFinderBezierPath(bounds: CGRect) -> UIBezierPath {
    let path = UIBezierPath(rect: bounds)
    path.append(UIBezierPath(roundedRect: calculateViewFinderRect(bounds: bounds),
                             cornerRadius: .cornerRadius))
    return path
  }
  
  func createCornersPath(viewFinderRect: CGRect) -> CGPath {
    let path = CGMutablePath()
    addCorner(path: path,
              start: .init(x: 0, y: .cornerSide),
              end: .init(x: .cornerSide, y: 0),
              corner: .init(x: 0, y: 0))
    addCorner(path: path,
              start: .init(x: viewFinderRect.width - .cornerSide, y: 0),
              end: .init(x: viewFinderRect.width, y: .cornerSide),
              corner: .init(x: viewFinderRect.width, y: 0))
    addCorner(path: path,
              start: .init(x: viewFinderRect.width, y: viewFinderRect.height - .cornerSide),
              end: .init(x: viewFinderRect.width - .cornerSide, y: viewFinderRect.height),
              corner: .init(x: viewFinderRect.width, y: viewFinderRect.height))
    addCorner(path: path,
              start: .init(x: .cornerSide, y: viewFinderRect.height),
              end: .init(x: 0, y: viewFinderRect.height - .cornerSide),
              corner: .init(x: 0, y: viewFinderRect.height))
    return path
  }
  
  func addCorner(path: CGMutablePath,
                 start: CGPoint,
                 end: CGPoint,
                 corner: CGPoint) {
    path.move(to: start)
    path.addArc(tangent1End: corner,
                tangent2End: end,
                radius: .cornerRadius)
    path.addLine(to: end)
  }
}

private extension CGFloat {
  static let holeSideOffset: CGFloat = 56
  static let cornerRadius: CGFloat = 8
  static let cornerSide: CGFloat = 24
  static let cornerWidth: CGFloat = 3
  static let flashlightButtonSide: CGFloat = 56
  static let flashlightButtonTopOffset: CGFloat = 32
  static let titleBottomOffset: CGFloat = 32
}
