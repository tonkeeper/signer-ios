import UIKit
import TKUIKit
import TKQRCode
import SignerCore

struct UnsupportedVersionAssembly {
  private init() {}
  static func module(signerCoreAssembly: SignerCore.Assembly) -> Module<TKBottomSheetViewController, UnsupportedVersionModuleOutput, Void> {
    let viewModel = UnsupportedVersionViewModelImplementation()
    let viewController = UnsupportedVersionViewController(viewModel: viewModel)
    return .init(
      view: TKBottomSheetViewController(
        contentViewController: viewController
      ),
      output: viewModel,
      input: Void()
    )
  }
}
