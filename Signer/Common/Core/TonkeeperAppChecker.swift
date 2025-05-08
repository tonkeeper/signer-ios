import UIKit
import SignerCore

struct TonkeeperAppChecker {
  enum State {
    case none
    case tonkeeper
    case mobile
    case pro
    case mobileAndPro
  }
  static func checkTonkeeperAppInstallState() -> State {
    let isTonkeeperInstalled = UIApplication.shared.canOpenURL(URL(string: TonkeeperApp.standart.url)!)
    let isMobileInstalled = UIApplication.shared.canOpenURL(URL(string: TonkeeperApp.mobile.url)!)
    let isProInstalled = UIApplication.shared.canOpenURL(URL(string: TonkeeperApp.pro.url)!)
    
    switch (isMobileInstalled, isProInstalled) {
    case (true, true):
      return .mobileAndPro
    case (true, false):
      return .mobile
    case (false, true):
      return .pro
    case (false, false):
      if isTonkeeperInstalled { return .tonkeeper }
      return .none
    }
  }
}
