import Foundation
import SignerCore
import SignerLocalize
import UIKit
import TKUIKit
import TKQRCode
import TonSwift

protocol NoSigningKeyModuleOutput: AnyObject {
  var didTapClose: (() -> Void)? { get set }
}

protocol NoSigningKeyViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

final class NoSigningKeyViewModelImplementation: NoSigningKeyViewModel, NoSigningKeyModuleOutput {
  
  // MARK: - NoSigningKeyModuleOutput
  
  var didTapClose: (() -> Void)?

  // MARK: - NoSigningKeyViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    let model = buildModalCardModel()
    didUpdateConfiguration?(model)
  }
}

private extension NoSigningKeyViewModelImplementation {
  
  func buildModalCardModel() -> TKModalCardViewController.Configuration {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.image = .TKUIKit.Icons.Size84.exclamationmarkCircle
    imageView.tintColor = .Icon.secondary
    
    let header = TKModalCardViewController.Configuration.Header(
      items: [
        .customView(imageView, bottomSpacing: 12),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: SignerLocalize.NoSigningKey.title.withTextStyle(
              .h2,
              color: .Text.primary,
              alignment: .center,
              lineBreakMode: .byWordWrapping
            ),
            numberOfLines: 0
          ),
          bottomSpacing: 4
        ),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: SignerLocalize.NoSigningKey.caption.withTextStyle(
              .body1,
              color: .Text.secondary,
              alignment: .center,
              lineBreakMode: .byWordWrapping
            ),
            numberOfLines: 0
          ),
          bottomSpacing: 32
        ),
        .button(
          TKModalCardViewController.Configuration.Button(
            title: SignerLocalize.Actions.ok,
            size: .large,
            category: .secondary,
            isEnabled: true,
            isActivity: false,
            tapAction: { [weak self] _, _ in
              self?.didTapClose?()
            }
          ),
          bottomSpacing: 0
        )
      ]
    )
    
    return TKModalCardViewController.Configuration(
      header: header,
      actionBar: nil
    )
  }
}
