import Foundation

public enum TonkeeperApp {
  case standart
  case mobile
  case pro
  public var scheme: String {
    switch self {
    case .standart:
      "tonkeeper"
    case .mobile:
      "tonkeeper-mob"
    case .pro:
      "tonkeeper-pro"
    }
  }
  public var url: String {
    "\(scheme)://"
  }
}
