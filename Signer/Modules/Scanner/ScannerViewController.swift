import UIKit
import TKUIKit
import SwiftUI
import AVFoundation

final class ScannerViewController: GenericViewViewController<ScannerView> {
  
  private enum SessionSetupState {
    case success
    case failed
  }
  
  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "ScannerViewControllerCaptureSessionQueue")
  private let metadataOutputQueue = DispatchQueue(label: "ScannerViewControllerMetadataQueue")
  private var sessionSetupState: SessionSetupState = .success
  private var device: AVCaptureDevice?
  private var isSessionRunning = false
  private var observationToken: NSObjectProtocol?
  
  private lazy var cameraSetupFailedViewController: UIViewController = {
    let view = NoCameraPermissionView { [weak self] in
      self?.viewModel.didTapSettingsButton()
    }
    let viewController = UIHostingController(rootView: view)
    viewController.view.backgroundColor = .Background.page
    return viewController
  }()
  private let viewModel: ScannerViewModel
  
  // MARK: - Init
  
  init(viewModel: ScannerViewModel) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    sessionQueue.async {
      switch self.sessionSetupState {
      case .success:
        self.session.startRunning()
        self.isSessionRunning = self.session.isRunning
        let hasTorch = self.device?.hasTorch ?? false
        DispatchQueue.main.async {
          self.customView.previewView.isHidden = false
          self.customView.cameraPermissionViewContainer.isHidden = true
          self.customView.flashlightButton.isHidden = !hasTorch
        }
      case .failed:
        DispatchQueue.main.async {
          self.customView.cameraPermissionViewContainer.isHidden = false
          self.customView.previewView.isHidden = true
          self.customView.flashlightButton.isHidden = true
        }
      }
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    sessionQueue.async {
      guard self.sessionSetupState == .success else {
        return
      }
      self.session.stopRunning()
      self.isSessionRunning = self.session.isRunning
    }
    super.viewWillDisappear(animated)
  }
}

// MARK: - Private

private extension ScannerViewController {
  func setup() {
    customView.previewView.session = session
    
    customView.flashlightButton.didToggle = { [weak self] isToggled in
      self?.viewModel.didTapFlashlightButton(isToggled: isToggled)
    }
    
    let swipeDownButton = QRScannerSwipeDownButton()
    swipeDownButton.addTarget(self, action: #selector(didTapSwipeDownButton), for: .touchUpInside)
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: swipeDownButton)
    
    addChild(cameraSetupFailedViewController)
    customView.setCameraPermissionDeniedView(cameraSetupFailedViewController.view)
    cameraSetupFailedViewController.didMove(toParent: self)
    
    sessionQueue.async {
      self.setupObservations()
      self.setupSession()
    }
  }
  
  @objc
  func didTapSwipeDownButton() {
    dismiss(animated: true)
  }
  
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak customView] title in
      customView?.titleLabel.attributedText = title
    }
    
    viewModel.didUpdateSubtitle = { [weak customView] subtitle in
      customView?.captionLabel.attributedText = subtitle
    }
  }
  
  func setupSession() {
    session.beginConfiguration()
    
    guard let device = AVCaptureDevice.default(for: .video) else {
      sessionSetupState = .failed
      session.commitConfiguration()
      return
    }
    self.device = device
    do {
      let videoDeviceInput = try AVCaptureDeviceInput(device: device)
      guard session.canAddInput(videoDeviceInput) else {
        sessionSetupState = .failed
        session.commitConfiguration()
        return
      }
      session.addInput(videoDeviceInput)
      
      let metaDataOutput = AVCaptureMetadataOutput()
      guard session.canAddOutput(metaDataOutput) else {
        sessionSetupState = .failed
        session.commitConfiguration()
        return
      }
      session.addOutput(metaDataOutput)
      metaDataOutput.setMetadataObjectsDelegate(self, queue: metadataOutputQueue)
      metaDataOutput.metadataObjectTypes = [.qr]
      
      
      session.commitConfiguration()
    } catch {
      sessionSetupState = .failed
      session.commitConfiguration()
    }
  }
  
  func setupObservations() {
    observationToken = NotificationCenter.default.addObserver(
      forName: .AVCaptureSessionRuntimeError,
      object: session,
      queue: .main) { [weak self] notification in
        guard let self else { return }
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        guard error.code == .mediaServicesWereReset else { return }
        self.sessionQueue.async {
          guard self.isSessionRunning else {
            return
          }
          self.session.startRunning()
          self.isSessionRunning = self.session.isRunning
        }
      }
  }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput, 
                      didOutput metadataObjects: [AVMetadataObject],
                      from connection: AVCaptureConnection) {
    guard !metadataObjects.isEmpty,
          let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          metadataObject.type == .qr,
          let stringValue = metadataObject.stringValue
    else { return }
    print(stringValue)
  }
}
