import UIKit
import TKUIKit
import SnapKit

final class UnsupportedVersionViewController: BasicViewController, TKBottomSheetContentViewController {
  private let viewModel: UnsupportedVersionViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
  // MARK: - Init
  
  init(viewModel: UnsupportedVersionViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  // MARK: - TKBottomSheetContentViewController

  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    modalCardViewController.calculateHeight(withWidth: width)
  }
}

// MARK: - Private

private extension UnsupportedVersionViewController {
  func setup() {
    addChild(modalCardViewController)
    view.addSubview(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
    
    modalCardViewController.view.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
  }

  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.modalCardViewController.configuration = configuration
    }
  }
}
