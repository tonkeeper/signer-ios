import BigInt
import Foundation
import SignerLocalize
import TonSwift

public final class SignConfirmationController {
  public var hexBody: String {
    do {
      let cell = try Cell.cellFromBoc(src: model.body)
      return try cell.toBoc().hexString()
    } catch {
      return ""
    }
  }

  public let model: TonSignModel
  public var walletKey: WalletKey
  private let mnemonicsRepository: MnemonicsRepository
  private let deeplinkGenerator: PublishDeeplinkGenerator
  private let amountFormatter: AmountFormatter

  init(
    model: TonSignModel,
    walletKey: WalletKey,
    mnemonicsRepository: MnemonicsRepository,
    deeplinkGenerator: PublishDeeplinkGenerator,
    amountFormatter: AmountFormatter
  ) {
    self.model = model
    self.walletKey = walletKey
    self.mnemonicsRepository = mnemonicsRepository
    self.deeplinkGenerator = deeplinkGenerator
    self.amountFormatter = amountFormatter
  }

  public func getTransactionModel(sendTitle: String) -> TransactionModel {
    do {
      // Strict decode: every action that will be signed must be understood and
      // shown. If anything is left unparsed, we fall through to the catch below,
      // present an explicit "not recognized" state and block signing.
      let transaction = try parseSignedBody(model.body, version: contractVersion)
      let items = transaction.actions.map { makeItem($0, sendTitle: sendTitle) }
      return TransactionModel(
        items: items,
        seqno: transaction.seqno,
        tonNetwork: model.tonNetwork,
        boc: model.body.hexString(),
        canSign: true
      )
    } catch {
      return TransactionModel(
        items: [TransactionModel.Item(
          title: SignerLocalize.SignTransaction.unrecognized_title,
          subtitle: nil,
          value: nil,
          valueSubtitle: nil,
          comment: nil,
          warning: SignerLocalize.SignTransaction.unrecognized_warning,
          isDangerous: true
        )],
        seqno: 0,
        tonNetwork: model.tonNetwork,
        boc: model.body.hexString(),
        canSign: false
      )
    }
  }

  public func signTransaction(password: String) async -> URL? {
    do {
      // Never sign a body we could not fully account for on screen.
      // This is the crypto-boundary enforcement of "not shown -> not signed";
      // it holds even if the UI confirmation gate is somehow bypassed.
      _ = try parseSignedBody(model.body, version: contractVersion)

      let mnemonic = try await mnemonicsRepository.getMnemonic(walletKey: walletKey, password: password)
      let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
      let privateKey = keyPair.privateKey
      let signer = WalletTransferSecretKeySigner(secretKey: privateKey.data)

      let messageCell = try Cell.cellFromBoc(src: model.body)
      let signature = try signer.signMessage(messageCell.hash())

      return deeplinkGenerator.generatePublishDeeplink(
        signature: signature,
        return: model.returnURL
      )
    } catch {
      return nil
    }
  }

  public func createEmulationURL(baseURLProvider: (TonNetwork) -> URL?, seqno: UInt64) -> URL? {
    let tonNetwork = model.tonNetwork ?? .mainnet
    guard let hexBoc = createEmulationHexBoc(seqno: seqno) else { return nil }
    return baseURLProvider(tonNetwork)?.appendingPathComponent(hexBoc)
  }

  public func createEmulationHexBoc(seqno: UInt64) -> String? {
    let tonNetwork = model.tonNetwork ?? .mainnet
    do {
      let version = contractVersion
      let contract: WalletContract
      let transferCell: Cell
      switch version {
      case .v5R1:
        contract = WalletV5R1(
          publicKey: model.publicKey.data,
          walletId: WalletId(
            networkGlobalId: Int32(tonNetwork.rawValue),
            workchain: 0
          )
        )
        transferCell = try createEmulationTransferCellV5(body: model.body)
      case .v5Beta:
        contract = WalletV5Beta(
          publicKey: model.publicKey.data,
          walletId: WalletIdBeta(
            networkGlobalId: Int32(tonNetwork.rawValue),
            workchain: 0
          )
        )
        transferCell = try createEmulationTransferCellV5(body: model.body)
      case .v4R2:
        contract = WalletV4R2(publicKey: model.publicKey.data)
        transferCell = try createEmulationTransferCell(body: model.body)
      case .v4R1:
        contract = WalletV4R1(publicKey: model.publicKey.data)
        transferCell = try createEmulationTransferCell(body: model.body)
      case .v3R2:
        contract = try WalletV3(workchain: 0, publicKey: model.publicKey.data, revision: .r2)
        transferCell = try createEmulationTransferCell(body: model.body)
      case .v3R1:
        contract = try WalletV3(workchain: 0, publicKey: model.publicKey.data, revision: .r1)
        transferCell = try createEmulationTransferCell(body: model.body)
      }

      let externalMessage = try Message.external(
        to: contract.address(),
        stateInit: seqno == 0 ? contract.stateInit : nil,
        body: transferCell
      )
      let cell = try Builder().store(externalMessage).endCell()
      return try cell.toBoc().hexString()
    } catch {
      return nil
    }
  }

  private func createEmulationTransferCell(body: Data) throws -> Cell {
    let signer = WalletTransferEmptyKeySigner()
    let messageCell = try Cell.cellFromBoc(src: body).toBuilder()
    let signature = try signer.signMessage(messageCell.endCell().hash())
    let body = Builder()
    try body.store(data: signature)
    try body.store(messageCell)
    return try body.endCell()
  }

  private func createEmulationTransferCellV5(body: Data) throws -> Cell {
    let signer = WalletTransferEmptyKeySigner()
    let messageCell = try Cell.cellFromBoc(src: body).toBuilder()
    let signature = try signer.signMessage(messageCell.endCell().hash())
    let body = Builder()
    try body.store(messageCell)
    try body.store(data: signature)
    return try body.endCell()
  }

  private var contractVersion: ContractVersion {
    if let version = model.version,
       let contractVersion = ContractVersion(tonsignValue: version)
    {
      return contractVersion
    }
    return .currentVersion
  }
}

// MARK: - Display model mapping

private extension SignConfirmationController {
  func makeItem(_ action: TransferAction, sendTitle: String) -> TransactionModel.Item {
    switch action {
    case let .sendMessage(send):
      return makeSendItem(send, sendTitle: sendTitle)
    case let .addExtension(address):
      return TransactionModel.Item(
        title: SignerLocalize.SignTransaction.set_extension_title,
        subtitle: address.toShortString(bounceable: true),
        value: nil,
        valueSubtitle: nil,
        comment: nil,
        warning: SignerLocalize.SignTransaction.extension_warning,
        isDangerous: true
      )
    case let .removeExtension(address):
      return TransactionModel.Item(
        title: SignerLocalize.SignTransaction.remove_extension_title,
        subtitle: address.toShortString(bounceable: true),
        value: nil,
        valueSubtitle: nil,
        comment: nil,
        warning: SignerLocalize.SignTransaction.extension_warning,
        isDangerous: true
      )
    case let .setSignatureAuth(allowed):
      return TransactionModel.Item(
        title: allowed
          ? SignerLocalize.SignTransaction.enable_signature_title
          : SignerLocalize.SignTransaction.disable_signature_title,
        subtitle: nil,
        value: nil,
        valueSubtitle: nil,
        comment: nil,
        warning: SignerLocalize.SignTransaction.extension_warning,
        isDangerous: true
      )
    }
  }

  func makeSendItem(_ send: SendMessageAction, sendTitle: String) -> TransactionModel.Item {
    let sendsAll = send.sendMode & 128 != 0
    let destroys = send.sendMode & 32 != 0

    let tonString = amountFormatter.formatAmount(
      send.tonValue,
      fractionDigits: 9,
      maximumFractionDigits: 9,
      symbol: "TON"
    )
    // Always show the native TON that actually leaves the wallet, even for
    // token / NFT transfers where it used to be hidden behind a label.
    let value = sendsAll ? SignerLocalize.SignTransaction.entire_balance : tonString

    let subtitle: String?
    var valueSubtitle: String?
    var warnings: [String] = []

    switch send.payload {
    case .ton:
      subtitle = send.destination.toShortString(bounceable: false)
    case let .jetton(jettonWallet, _, recipient, excess):
      subtitle = recipient.toShortString(bounceable: false)
      valueSubtitle = "\(SignerLocalize.SignTransaction.token_label) · \(jettonWallet.toShortString(bounceable: true))"
      if let excess {
        warnings.append("\(SignerLocalize.SignTransaction.excess_to) \(excess.toShortString(bounceable: true))")
      }
    case let .nft(nftItem, newOwner, excess):
      subtitle = newOwner.toShortString(bounceable: false)
      valueSubtitle = "\(SignerLocalize.SignTransaction.nft_label) · \(nftItem.toShortString(bounceable: true))"
      if let excess {
        warnings.append("\(SignerLocalize.SignTransaction.excess_to) \(excess.toShortString(bounceable: true))")
      }
    case let .unknown(opCode):
      subtitle = send.destination.toShortString(bounceable: false)
      warnings.append("\(SignerLocalize.SignTransaction.unknown_operation) 0x\(String(opCode, radix: 16))")
    }

    if destroys {
      warnings.append(SignerLocalize.SignTransaction.destroy_warning)
    }

    return TransactionModel.Item(
      title: sendTitle,
      subtitle: subtitle,
      value: value,
      valueSubtitle: valueSubtitle,
      comment: send.comment,
      warning: warnings.isEmpty ? nil : warnings.joined(separator: "\n"),
      isDangerous: destroys || sendsAll
    )
  }
}

// MARK: - Strict signed-body parser

//
// Developed and verified against the Wallet v3/v4/v5 message layouts (TonSwift's
// own transfer builders + the canonical wallet-contract-v5 TL-B). The guiding
// rule is "not shown -> not signed": anything we cannot fully account for makes
// the whole decode throw, which disables signing.

private extension SignConfirmationController {
  enum ParseError: Swift.Error {
    case tooShort
    case unexpectedExternalOutMessage
    case unknownOutActionTag(UInt32)
    case unknownExtendedActionTag(UInt8)
    case unsupportedV5BetaExtendedActions
  }

  enum TransferAction {
    case sendMessage(SendMessageAction)
    case addExtension(Address)
    case removeExtension(Address)
    case setSignatureAuth(Bool)
  }

  struct SendMessageAction {
    enum Payload {
      case ton
      case jetton(jettonWallet: Address, amount: BigUInt, recipient: Address, excess: Address?)
      case nft(nftItem: Address, newOwner: Address, excess: Address?)
      case unknown(opCode: UInt32)
    }

    let destination: Address
    let tonValue: BigUInt
    let sendMode: UInt8
    let payload: Payload
    let comment: String?
  }

  struct ParsedTransaction {
    let seqno: UInt64
    let actions: [TransferAction]
  }

  static let outActionSendMsgTag: UInt32 = 0x0EC3_C86D
  static let jettonTransferOp: UInt32 = 0xF8A7EA5
  static let nftTransferOp: UInt32 = 0x5FCC_3D14

  func parseSignedBody(_ boc: Data, version: ContractVersion) throws -> ParsedTransaction {
    let slice = try Cell.cellFromBoc(src: boc).toSlice()
    switch version {
    case .v5R1:
      return try parseV5(slice)
    case .v5Beta:
      return try parseV5Beta(slice)
    case .v3R1, .v3R2, .v4R1, .v4R2:
      return try parseLegacy(slice, hasOrderOpByte: version == .v4R1 || version == .v4R2)
    }
  }

  func endParseStrict(_ slice: Slice) throws {
    try slice.endParse() // throws if any bits or refs remain
  }

  // w5_signed_request: opcode(32) wallet_id(32) valid_until(32) msg_seqno(32)
  //                    inner:(out_actions:(Maybe ^OutList) extended_actions:(Maybe W5ExtendedActionList))
  func parseV5(_ slice: Slice) throws -> ParsedTransaction {
    guard slice.remainingBits >= 128 else { throw ParseError.tooShort }
    try slice.skip(32) // opcode (signed internal/external)
    try slice.skip(32) // wallet_id
    try slice.skip(32) // valid_until
    let seqno = try slice.loadUint(bits: 32)

    var actions: [TransferAction] = []

    if try slice.loadBoolean() { // out_actions: Maybe ^OutList
      try actions.append(contentsOf: parseOutList(slice.loadRef()))
    }
    if try slice.loadBoolean() { // extended_actions: Maybe W5ExtendedActionList
      try parseExtendedActions(startingAt: slice, into: &actions)
    }

    try endParseStrict(slice)
    return ParsedTransaction(seqno: seqno, actions: actions)
  }

  // v5beta: opcode(32) wallet_id(80) valid_until(32) msg_seqno(32)
  //          has_other_actions(1 = false) out_actions:^(OutList)
  func parseV5Beta(_ slice: Slice) throws -> ParsedTransaction {
    guard slice.remainingBits >= 177 else { throw ParseError.tooShort }
    try slice.skip(32) // opcode
    try slice.skip(80) // network_global_id, workchain, wallet version, subwallet
    try slice.skip(32) // valid_until
    let seqno = try slice.loadUint(bits: 32)
    guard !(try slice.loadBoolean()) else { throw ParseError.unsupportedV5BetaExtendedActions }
    let actions = try parseOutList(slice.loadRef())
    try endParseStrict(slice)
    return ParsedTransaction(seqno: seqno, actions: actions)
  }

  /// out_list_empty$_ = OutList 0;
  /// out_list$_ prev:^(OutList n) action:OutAction = OutList (n+1);
  /// action_send_msg#0ec3c86d mode:(## 8) out_msg:^MessageRelaxed = OutAction;
  func parseOutList(_ cell: Cell) throws -> [TransferAction] {
    var collected: [TransferAction] = []
    var node = try cell.toSlice()
    while node.remainingRefs > 0 {
      let tag = try UInt32(node.loadUint(bits: 32))
      guard tag == Self.outActionSendMsgTag else {
        throw ParseError.unknownOutActionTag(tag)
      }
      let mode = try UInt8(node.loadUint(bits: 8))
      let prev = try node.loadRef()
      let messageCell = try node.loadRef()
      try endParseStrict(node)
      let message = try MessageRelaxed.loadFrom(slice: messageCell.toSlice())
      try collected.append(.sendMessage(parseMessage(message, sendMode: mode)))
      node = try prev.toSlice()
    }
    try endParseStrict(node) // out_list_empty base
    return collected.reversed() // list is built inner-last; restore original order
  }

  /// extended_list_last$_   action:W5ExtendedAction                                = list 0;
  /// extended_list_action$_ action:W5ExtendedAction prev:^(W5ExtendedActionList n) = list (n+1);
  func parseExtendedActions(startingAt slice: Slice, into actions: inout [TransferAction]) throws {
    var node = slice // the first extended action is inline in the inner-request cell
    while true {
      try actions.append(parseExtendedAction(node))
      if node.remainingRefs > 0 {
        node = try node.loadRef().toSlice()
      } else {
        break
      }
    }
    if node !== slice {
      try endParseStrict(node)
    }
  }

  func parseExtendedAction(_ slice: Slice) throws -> TransferAction {
    let tag = try UInt8(slice.loadUint(bits: 8))
    switch tag {
    case 0x02:
      let address: Address = try slice.loadType()
      return .addExtension(address)
    case 0x03:
      let address: Address = try slice.loadType()
      return .removeExtension(address)
    case 0x04:
      let allowed = try slice.loadBoolean()
      return .setSignatureAuth(allowed)
    default:
      throw ParseError.unknownExtendedActionTag(tag)
    }
  }

  // v3: wallet_id(32) valid_until(32) seqno(32)             then per message: mode(8) ^MessageRelaxed
  // v4: wallet_id(32) valid_until(32) seqno(32) order_op(8) then per message: mode(8) ^MessageRelaxed
  func parseLegacy(_ slice: Slice, hasOrderOpByte: Bool) throws -> ParsedTransaction {
    guard slice.remainingBits >= 96 else { throw ParseError.tooShort }
    try slice.skip(32) // wallet_id / subwallet
    try slice.skip(32) // valid_until
    let seqno = try slice.loadUint(bits: 32)
    if hasOrderOpByte {
      try slice.skip(8) // op (0 = simple order)
    }

    var actions: [TransferAction] = []
    while slice.remainingRefs > 0 {
      let mode = try UInt8(slice.loadUint(bits: 8))
      let messageCell = try slice.loadRef()
      let message = try MessageRelaxed.loadFrom(slice: messageCell.toSlice())
      try actions.append(.sendMessage(parseMessage(message, sendMode: mode)))
    }
    try endParseStrict(slice)
    return ParsedTransaction(seqno: seqno, actions: actions)
  }

  func parseMessage(_ message: MessageRelaxed, sendMode: UInt8) throws -> SendMessageAction {
    guard case let .internalInfo(info) = message.info else {
      throw ParseError.unexpectedExternalOutMessage
    }
    let destination = info.dest
    let tonValue = info.value.coins.rawValue
    let opCode = peekOpCode(message.body)

    switch opCode {
    case Self.jettonTransferOp:
      if let data = try? JettonTransferData.loadFrom(slice: message.body.toSlice()) {
        return SendMessageAction(
          destination: destination,
          tonValue: tonValue,
          sendMode: sendMode,
          payload: .jetton(jettonWallet: destination, amount: data.amount, recipient: data.toAddress, excess: data.responseAddress),
          comment: parseComment(data.forwardPayload)
        )
      }
      return SendMessageAction(destination: destination, tonValue: tonValue, sendMode: sendMode, payload: .unknown(opCode: Self.jettonTransferOp), comment: nil)
    case Self.nftTransferOp:
      if let data = try? NFTTransferData.loadFrom(slice: message.body.toSlice()) {
        return SendMessageAction(
          destination: destination,
          tonValue: tonValue,
          sendMode: sendMode,
          payload: .nft(nftItem: destination, newOwner: data.newOwnerAddress, excess: data.responseAddress),
          comment: parseComment(data.forwardPayload)
        )
      }
      return SendMessageAction(destination: destination, tonValue: tonValue, sendMode: sendMode, payload: .unknown(opCode: Self.nftTransferOp), comment: nil)
    case let .some(op) where op != 0:
      return SendMessageAction(destination: destination, tonValue: tonValue, sendMode: sendMode, payload: .unknown(opCode: op), comment: nil)
    default:
      return SendMessageAction(destination: destination, tonValue: tonValue, sendMode: sendMode, payload: .ton, comment: parseComment(message.body))
    }
  }

  func peekOpCode(_ body: Cell) -> UInt32? {
    guard let slice = try? body.toSlice(), slice.remainingBits >= 32 else { return nil }
    guard let op = try? slice.preloadUint(bits: 32) else { return nil }
    return UInt32(op)
  }

  func parseComment(_ cell: Cell?) -> String? {
    guard let cell, let slice = try? cell.toSlice() else { return nil }
    guard let raw = try? slice.loadSnakeString() else { return nil }
    let trimmed = raw.trimmingCharacters(in: CharacterSet(["\0"]))
    return trimmed.isEmpty ? nil : trimmed
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
