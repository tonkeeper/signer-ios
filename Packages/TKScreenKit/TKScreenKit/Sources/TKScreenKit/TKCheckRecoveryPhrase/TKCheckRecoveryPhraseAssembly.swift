import Foundation

public struct TKCheckRecoveryPhraseAssembly {
  private init() {}
  public static func module(provider: TKCheckRecoveryPhraseProvider,
                            continueButtonTitle: String)
  -> (viewController: TKCheckRecoveryPhraseViewController, output: TKCheckRecoveryPhraseModuleOutput) {
    let viewModel = TKCheckRecoveryPhraseViewModelImplementation(
      provider: provider,
      continueButtonTitle: continueButtonTitle
    )
    let viewController = TKCheckRecoveryPhraseViewController(viewModel: viewModel)
    return (viewController, viewModel)
  }
}
