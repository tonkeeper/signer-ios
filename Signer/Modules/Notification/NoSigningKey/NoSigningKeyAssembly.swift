import UIKit
import TKUIKit
import TKQRCode
import SignerCore

struct NoSigningKeyAssembly {
  private init() {}
  static func module(signerCoreAssembly: SignerCore.Assembly) -> Module<TKBottomSheetViewController, NoSigningKeyModuleOutput, Void> {
    let viewModel = NoSigningKeyViewModelImplementation()
    let viewController = NoSigningKeyViewController(viewModel: viewModel)
    return .init(
      view: TKBottomSheetViewController(
        contentViewController: viewController
      ),
      output: viewModel,
      input: Void()
    )
  }
}
