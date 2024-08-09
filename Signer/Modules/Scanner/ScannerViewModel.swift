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
  var didScanQRCode: (() -> Void)? { get set }
  
  func viewDidLoad()
  func didTapSettingsButton()
  func didScanQRCodeString(_ qrCodeString: String)
}

enum ScannerError: Swift.Error {
  case invalidBoc(String)
}

final class ScannerViewModelImplementation: NSObject, ScannerViewModel, ScannerViewModuleOutput {
  
  // MARK: - ScannerViewModuleOutput
  
  var didScanDeeplink: ((Deeplink) -> Void)?
  var didScanDeeplinkUnsupportedVersion: (() -> Void)?
  var didScanQRCode: (() -> Void)?
  
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
  
  func didScanQRCodeString(_ qrCodeString: String) {
    if qrCodeString.hasPrefix(DeeplinkScheme.tonsign.rawValue) {
      let fullString = multiQRCode.fullString
      do {
        let deeplink = try scannerController.handleScannedQRCode(qrCodeString)
        didScanQRCode?()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        DispatchQueue.main.async {
          self.didScanDeeplink?(deeplink)
        }
      } catch DeeplinkParserError.unsopportedVersion {
        DispatchQueue.main.async {
          self.didScanDeeplinkUnsupportedVersion?()
        }
      } catch {
        multiQRCode.reset()
      }
    }
    multiQRCode.setNext(qrCodeString)
  }

  // MARK: - State
  
  private var multiQRCode = MultiQRCode()
  private let deeplinkParser = DefaultDeeplinkParser(
    parsers: [TonsignDeeplinkParser()]
  )
  
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
  
  private func handleScannedQRCode(_ qrCodeString: String) throws -> Deeplink {
    do {
      let deeplink = try deeplinkParser.parse(string: qrCodeString)
      switch deeplink {
      case .tonsign(let tonsignDeeplink):
        switch tonsignDeeplink {
        case .plain:
          return deeplink
        case .sign(let tonSignModel):
          try validateBodyBoc(tonSignModel.body)
          return deeplink
        }
      }
    } catch {
      throw error
    }
  }
  
  private func validateBodyBoc(_ boc: Data) throws {
    do {
      _ = try Cell.cellFromBoc(src: boc)
    } catch {
      throw ScannerError.invalidBoc(boc.hexString())
    }
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

extension Cell {
  static func cellFromBoc(src: Data) throws -> Cell {
    let cells = try Cell.fromBoc(src: src)
    guard cells.count == 1 else {
      throw TonError.custom("Deserialized more than one cell")
    }
    return cells[0]
  }
}

