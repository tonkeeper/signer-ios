import Foundation
import SignerCore
import SignerLocalize
import UIKit
import TKUIKit
import TKQRCode
import TonSwift

protocol UnsupportedVersionModuleOutput: AnyObject {
  var didTapUpdate: (() -> Void)? { get set }
  var didTapClose: (() -> Void)? { get set }
}

protocol UnsupportedVersionViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

final class UnsupportedVersionViewModelImplementation: UnsupportedVersionViewModel, UnsupportedVersionModuleOutput {
  
  // MARK: - UnsupportedVersionModuleOutput
  
  var didTapUpdate: (() -> Void)?
  var didTapClose: (() -> Void)?

  // MARK: - UnsupportedVersionViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    let model = buildModalCardModel()
    didUpdateConfiguration?(model)
  }
}

private extension UnsupportedVersionViewModelImplementation {
  
  func buildModalCardModel() -> TKModalCardViewController.Configuration {
    let header = TKModalCardViewController.Configuration.Header(
      items: [
        .customView(UnsupportedVersionHeaderView(), bottomSpacing: 16),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: SignerLocalize.UnsupportedVersion.title.withTextStyle(
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
            text: SignerLocalize.UnsupportedVersion.caption.withTextStyle(
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
            title: SignerLocalize.Actions.update,
            size: .large,
            category: .primary,
            isEnabled: true,
            isActivity: false,
            tapAction: { [weak self] _, _ in
              self?.didTapUpdate?()
            }
          ),
          bottomSpacing: 16
        ),
        .button(
          TKModalCardViewController.Configuration.Button(
            title: SignerLocalize.Actions.later,
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
