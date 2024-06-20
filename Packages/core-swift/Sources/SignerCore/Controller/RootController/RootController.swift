import Foundation

public final class RootController {
  public enum State {
    case onboarding
    case main
  }
  
  public var didUpdateState: ((State) -> Void)?
  
  private let walletKeysStore: WalletKeysStore
  private let mnemonicsRepository: MnemonicsRepository
  private let signerInfoRepository: SignerInfoRepository
  
  init(walletKeysStore: WalletKeysStore,
       mnemonicsRepository: MnemonicsRepository,
       signerInfoRepository: SignerInfoRepository) {
    self.walletKeysStore = walletKeysStore
    self.mnemonicsRepository = mnemonicsRepository
    self.signerInfoRepository = signerInfoRepository
  }
  
  public func start() {
    _ = walletKeysStore.addEventObserver(self) { observer, event in
      switch event {
      case .didDeleteAll:
        observer.didUpdateState?(.onboarding)
      default:
        break
      }
    }
  }
  
  public func getState() -> State {
    if walletKeysStore.getWalletKeys().isEmpty {
      return .onboarding
    } else {
      return .main
    }
  }
  
  public func logout() async {
    try? await mnemonicsRepository.deleteAll()
    try? signerInfoRepository.removeSignerInfo()
  }
}
