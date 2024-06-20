import UIKit
import TKUIKit

final class UnsupportedVersionHeaderView: TKView {
  
  private let imageView = UIImageView()
  private let arrowImageView = UIImageView()
  
  override func setup() {
    imageView.image = UIImage(named: "AppIcon")
    imageView.layer.cornerRadius = 24
    imageView.layer.masksToBounds = true
    imageView.layer.cornerCurve = .continuous
    imageView.layer.borderColor = UIColor.Separator.common.cgColor
    imageView.layer.borderWidth = 1
    
    arrowImageView.image = .TKUIKit.Icons.Size28.arrowDown
    arrowImageView.contentMode = .center
    arrowImageView.tintColor = .Icon.primary
    arrowImageView.backgroundColor = .Accent.blue
    arrowImageView.layer.cornerRadius = 18
    arrowImageView.layer.masksToBounds = true
    
    addSubview(imageView)
    addSubview(arrowImageView)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    imageView.snp.makeConstraints { make in
      make.width.height.equalTo(96)
      make.top.bottom.equalTo(self).inset(16)
      make.centerX.equalTo(self)
    }
    
    arrowImageView.snp.makeConstraints { make in
      make.width.height.equalTo(36)
      make.right.equalTo(imageView).offset(6)
      make.bottom.equalTo(imageView).offset(6)
    }
  }
}
