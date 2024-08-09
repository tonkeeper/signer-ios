import Foundation
import AVFoundation
import UIKit
import SignerCore
import TonSwift

protocol ScannerViewModuleOutput: AnyObject {
  var didScanDeeplink: ((Deeplink) -> Void)? { get set }
  var didScanDeeplinkUnsupportedVersion: (() -> Void)? { get set }
}

protocol ScannerViewModel: AnyObject {
  
  var didUpdateTitle: ((NSAttributedString?) -> Void)? { get set }
  var didUpdateSubtitle: ((NSAttributedString?) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapSettingsButton()
  func didTapFlashlightButton(isToggled: Bool)
}

final class ScannerViewModelImplementation: NSObject, ScannerViewModel, ScannerViewModuleOutput {
  
  // MARK: - ScannerViewModuleOutput
  
  var didScanDeeplink: ((Deeplink) -> Void)?
  var didScanDeeplinkUnsupportedVersion: (() -> Void)?
  
  // MARK: - ScannerViewModel
  
  var didUpdateTitle: ((NSAttributedString?) -> Void)?
  var didUpdateSubtitle: ((NSAttributedString?) -> Void)?
 
  func viewDidLoad() {
    setup()
  }
  
  func didTapSettingsButton() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    urlOpener.open(url: url)
  }
  
  func didTapFlashlightButton(isToggled: Bool) {
    guard let captureDevice = AVCaptureDevice.default(for: .video),
          captureDevice.hasTorch
    else { return }
    
    try? captureDevice.lockForConfiguration()
    try? captureDevice.setTorchModeOn(level: 1)
    captureDevice.torchMode = isToggled ? .on : .off
    captureDevice.unlockForConfiguration()
  }

  // MARK: - State
  
  private var multiQRCode = MultiQRCode()
  
  // MARK: - Dependencies
  
  private let urlOpener: URLOpener
  private let scannerController: ScannerController
  private let title: String?
  private let subtitle: String?
  
  // MARK: - Init
  
  init(urlOpener: URLOpener,
       scannerController: ScannerController,
       title: String?,
       subtitle: String?) {
    self.urlOpener = urlOpener
    self.scannerController = scannerController
    self.title = title
    self.subtitle = subtitle
  }
}

private extension ScannerViewModelImplementation {
  func setup() {
    didUpdateTitle?(
      title?.withTextStyle(
        .h2,
        color: .white,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
    )
    
    didUpdateSubtitle?(
      subtitle?.withTextStyle(
        .body1,
        color: .white,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    )
  }
}

struct MultiQRCode {
  private var chunks = [String]()
  private var chunksSet = Set<String>()
  
  var fullString: String {
    chunks.joined()
  }
  
  mutating func setNext(_ chunk: String) {
    guard !chunksSet.contains(chunk) else { return }
    chunksSet.insert(chunk)
    chunks.append(chunk)
  }
  
  mutating func reset() {
    chunks = []
    chunksSet = []
  }
}
