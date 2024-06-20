import UIKit
import TKUIKit
import TKCoordinator
import SignerCore
import SignerLocalize

final class EnterPasswordCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didEnterPassword: ((String) -> Void)?
  var didSignOut: (() -> Void)?
  
  private let assembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter, assembly: SignerCore.Assembly) {
    self.assembly = assembly
    super.init(router: router)
  }

  override func start() {
    openEnterPassword()
  }
}

private extension EnterPasswordCoordinator {
  func openEnterPassword() {
    let configurator = EnterPasswordPasswordInputViewModelConfigurator(
      mnemonicsRepository: assembly.repositoriesAssembly.mnemonicsRepository(),
      title: SignerLocalize.Password.Confirmation.title
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak self] password in
      self?.didEnterPassword?(password)
    }
    
    let singOutButton = TKButton(configuration: .titleHeaderButtonConfiguration(category: .secondary))
    singOutButton.configuration.padding.top = 4
    singOutButton.configuration.padding.bottom = 4
    singOutButton.configuration.content = TKButton.Configuration.Content(
      title: .plainString(
        SignerLocalize.SignOut.Button.title
      )
    )
    singOutButton.configuration.action = { [weak self] in
      self?.openSignOutAlert()
    }
    module.view.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: singOutButton)
    
    let iconImageView = UIImageView(image: UIImage(named: "top_bar_app_icon"))
    iconImageView.contentMode = .center
    
    let iconView = UIView()
    iconView.backgroundColor = .Background.content
    iconView.layer.cornerRadius = 8
    iconView.layer.masksToBounds = true
    iconView.addSubview(iconImageView)
    
    iconImageView.snp.makeConstraints { make in
      make.edges.equalTo(iconView)
    }
    iconView.snp.makeConstraints { make in
      make.width.height.equalTo(32)
    }
    
    
    module.view.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: iconView)
    
    router.push(viewController: module.view,
                onPopClosures: {})
  }
  
  func openSignOutAlert() {
    let alertViewController = UIAlertController(
      title: SignerLocalize.SignOut.Alert.title,
      message: SignerLocalize.SignOut.Alert.caption,
      preferredStyle: .alert
    )
    alertViewController.addAction(
      UIAlertAction(title: SignerLocalize.Actions.cancel,
                    style: .default)
    )
    alertViewController.addAction(
      UIAlertAction(title: SignerLocalize.SignOut.Alert.Button.sign_out,
                    style: .destructive,
                    handler: { [weak self] _ in
                      self?.didSignOut?()
                    })
    )
    router.rootViewController.present(alertViewController, animated: true)
  }
}
