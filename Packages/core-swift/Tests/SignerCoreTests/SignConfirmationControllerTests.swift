import BigInt
import CoreComponents
@testable import SignerCore
import SignerLocalize
import TonSwift
import XCTest

/// Regression tests for TK-4099: "Wallet v5 extended actions are signed but never
/// shown on the confirmation screen" (plus the related send_mode / jetton-TON
/// hiding vectors). The guiding invariant is "not shown -> not signed".
final class SignConfirmationControllerTests: XCTestCase {
  // MARK: - The core vulnerability

  func test_v5_hidden_addExtension_is_now_shown() throws {
    let attacker = Address.mock(workchain: 0, seed: "attacker-extension")
    let body = try Bodies.maliciousV5AddExtension(
      victim: Address.mock(workchain: 0, seed: "merchant"),
      attacker: attacker
    )
    let model = makeController(body: body, version: "v5r1").getTransactionModel(sendTitle: "Send")

    // Before the fix this returned a single "Send 0.001 TON" item and the
    // add_extension action was invisible yet still signed.
    XCTAssertEqual(model.items.count, 2, "both the transfer and the extension must be shown")
    XCTAssertTrue(model.canSign, "a fully decoded request is signable")

    let extensionItem = model.items[1]
    XCTAssertEqual(extensionItem.subtitle, attacker.toShortString(bounceable: true))
    XCTAssertTrue(extensionItem.isDangerous, "granting a wallet extension is high risk")
  }

  // MARK: - Fail closed on anything undecodable

  func test_trailing_garbage_blocks_signing() throws {
    let body = try Bodies.maliciousV5AddExtension(
      victim: Address.mock(workchain: 0, seed: "merchant"),
      attacker: Address.mock(workchain: 0, seed: "attacker"),
      trailingGarbageBits: 7
    )
    let model = makeController(body: body, version: "v5r1").getTransactionModel(sendTitle: "Send")
    XCTAssertFalse(model.canSign, "a body we cannot fully decode must not be signable")
  }

  func test_unknown_extended_action_blocks_signing() throws {
    let body = try Bodies.maliciousV5UnknownExtendedAction(victim: Address.mock(workchain: 0, seed: "merchant"))
    let model = makeController(body: body, version: "v5r1").getTransactionModel(sendTitle: "Send")
    XCTAssertFalse(model.canSign)
  }

  func test_signTransaction_refuses_undecodable_body() async throws {
    let body = try Bodies.maliciousV5UnknownExtendedAction(victim: Address.mock(workchain: 0, seed: "merchant"))
    let url = await makeController(body: body, version: "v5r1").signTransaction(password: "whatever")
    XCTAssertNil(url, "the signer must not produce a signature for an undecodable body")
  }

  // MARK: - Legit bodies must not be falsely blocked

  func test_legit_v5_transfer_is_signable() throws {
    try assertSignableSingleSend(Bodies.legitV5(to: Address.mock(workchain: 0, seed: "to")), version: "v5r1")
  }

  func test_legit_v5_multi_message_transfer_is_signable() throws {
    let body = try Bodies.legitV5Multi(to: [
      Address.mock(workchain: 0, seed: "a"),
      Address.mock(workchain: 0, seed: "b"),
      Address.mock(workchain: 0, seed: "c"),
    ])
    let model = makeController(body: body, version: "v5r1").getTransactionModel(sendTitle: "Send")
    XCTAssertTrue(model.canSign, "a legit multi-message transfer must stay signable")
    XCTAssertEqual(model.items.count, 3)
  }

  func test_legit_v4_transfer_is_signable() throws {
    try assertSignableSingleSend(Bodies.legitV4(to: Address.mock(workchain: 0, seed: "to")), version: "v4r2")
  }

  func test_legit_v3_transfer_is_signable() throws {
    try assertSignableSingleSend(Bodies.legitV3(to: Address.mock(workchain: 0, seed: "to")), version: "v3r2")
  }

  // MARK: - send_mode and attached-TON vectors

  func test_sendMode_128_is_surfaced_as_entire_balance() throws {
    let body = try Bodies.maliciousV5SendAll(victim: Address.mock(workchain: 0, seed: "drain"))
    let model = makeController(body: body, version: "v5r1").getTransactionModel(sendTitle: "Send")
    XCTAssertEqual(model.items.first?.value, SignerLocalizeProxy.entireBalance)
  }

  func test_jetton_transfer_surfaces_attached_ton() throws {
    let body = try Bodies.maliciousV5JettonHidingTon(
      jettonWallet: Address.mock(workchain: 0, seed: "usdt"),
      recipient: Address.mock(workchain: 0, seed: "recipient"),
      excess: Address.mock(workchain: 0, seed: "excess"),
      attachedNanoton: BigUInt(4_200_000_000) // 4.2 TON
    )
    let model = makeController(body: body, version: "v5r1").getTransactionModel(sendTitle: "Send")
    let value = try XCTUnwrap(model.items.first?.value).replacingOccurrences(of: ",", with: ".")
    XCTAssertTrue(value.contains("4.2"), "attached native TON must be shown, not hidden behind the token label — got \(value)")
  }

  // MARK: - Helpers

  private func assertSignableSingleSend(_ body: Data, version: String) {
    let model = makeController(body: body, version: version).getTransactionModel(sendTitle: "Send")
    XCTAssertTrue(model.canSign, "legit \(version) transfer must stay signable")
    XCTAssertEqual(model.items.count, 1)
  }

  private func makeController(body: Data, version: String) -> SignConfirmationController {
    SignConfirmationController(
      model: TonSignModel(
        publicKey: PublicKey(data: Data(repeating: 0xAB, count: 32)),
        body: body,
        returnURL: nil,
        version: version,
        network: nil,
        tonNetwork: .mainnet
      ),
      walletKey: WalletKey(name: "Test", publicKey: PublicKey(data: Data(repeating: 0xAB, count: 32))),
      mnemonicsRepository: ThrowingMnemonicsRepository(),
      deeplinkGenerator: PublishDeeplinkGenerator(),
      amountFormatter: AmountFormatter(bigIntFormatter: BigIntAmountFormatter())
    )
  }
}

private enum SignerLocalizeProxy {
  static let entireBalance = SignerLocalize.SignTransaction.entire_balance
}

private struct ThrowingMnemonicsRepository: MnemonicsRepository {
  struct Denied: Error {}
  func getMnemonic(walletKey: WalletKey, password: String) async throws -> CoreComponents.Mnemonic {
    throw Denied()
  }

  func saveMnemonic(_ mnemonic: CoreComponents.Mnemonic, walletKey: WalletKey, password: String) async throws {}
  func deleteMnemonic(walletKey: WalletKey, password: String) async throws {}
  func checkIfPasswordValid(_ password: String) async -> Bool {
    false
  }

  func changePassword(oldPassword: String, newPassword: String) async throws {}
  func deleteAll() async throws {}
}

// MARK: - Body fixtures (built with TonSwift exactly like real wallets / attackers)

private enum Bodies {
  static let mainnetGlobalId: Int32 = -239

  static func legitV5(to: Address, nanoton: BigUInt = BigUInt(1_500_000_000)) throws -> Data {
    let contract = WalletV5R1(publicKey: pub, walletId: WalletId(networkGlobalId: mainnetGlobalId))
    return try contract.createTransfer(args: WalletTransferData(
      seqno: 1, messages: [MessageRelaxed.internal(to: to, value: nanoton)], sendMode: .walletDefault(), timeout: 0xFFFF_FFFF
    )).signingMessage.endCell().toBoc()
  }

  static func legitV5Multi(to: [Address], nanoton: BigUInt = BigUInt(100_000_000)) throws -> Data {
    let contract = WalletV5R1(publicKey: pub, walletId: WalletId(networkGlobalId: mainnetGlobalId))
    return try contract.createTransfer(args: WalletTransferData(
      seqno: 1, messages: to.map { MessageRelaxed.internal(to: $0, value: nanoton) }, sendMode: .walletDefault(), timeout: 0xFFFF_FFFF
    )).signingMessage.endCell().toBoc()
  }

  static func legitV4(to: Address, nanoton: BigUInt = BigUInt(2_000_000_000)) throws -> Data {
    let contract = WalletV4R2(publicKey: pub)
    return try contract.createTransfer(args: WalletTransferData(
      seqno: 1, messages: [MessageRelaxed.internal(to: to, value: nanoton)], sendMode: .walletDefault(), timeout: 0xFFFF_FFFF
    )).signingMessage.endCell().toBoc()
  }

  static func legitV3(to: Address, nanoton: BigUInt = BigUInt(300_000_000)) throws -> Data {
    let contract = try WalletV3(workchain: 0, publicKey: pub, revision: .r2)
    return try contract.createTransfer(args: WalletTransferData(
      seqno: 1, messages: [MessageRelaxed.internal(to: to, value: nanoton)], sendMode: .walletDefault(), timeout: 0xFFFF_FFFF
    )).signingMessage.endCell().toBoc()
  }

  static func maliciousV5AddExtension(victim: Address, attacker: Address, transferMode: UInt8 = 3, trailingGarbageBits: Int = 0) throws -> Data {
    let out = try outListNode(message: MessageRelaxed.internal(to: victim, value: BigUInt(1_000_000)), mode: transferMode)
    let body = Builder()
    try body.store(uint: UInt64(0x7369_676E), bits: 32)
    try body.store(uint: UInt64(0), bits: 32)
    try body.store(uint: UInt64(0xFFFF_FFFF), bits: 32)
    try body.store(uint: UInt64(1), bits: 32)
    try body.storeMaybe(ref: out)
    try body.store(bit: true)
    try body.store(uint: UInt64(0x02), bits: 8)
    try body.store(attacker)
    if trailingGarbageBits > 0 { try body.store(uint: UInt64(0), bits: trailingGarbageBits) }
    return try body.endCell().toBoc()
  }

  static func maliciousV5SendAll(victim: Address) throws -> Data {
    let out = try outListNode(message: MessageRelaxed.internal(to: victim, value: BigUInt(0)), mode: 128)
    let body = Builder()
    try body.store(uint: UInt64(0x7369_676E), bits: 32)
    try body.store(uint: UInt64(0), bits: 32)
    try body.store(uint: UInt64(0xFFFF_FFFF), bits: 32)
    try body.store(uint: UInt64(1), bits: 32)
    try body.storeMaybe(ref: out)
    try body.store(bit: false)
    return try body.endCell().toBoc()
  }

  static func maliciousV5JettonHidingTon(jettonWallet: Address, recipient: Address, excess: Address, attachedNanoton: BigUInt) throws -> Data {
    let jetton = JettonTransferData(queryId: 0, amount: BigUInt(1), toAddress: recipient, responseAddress: excess, forwardAmount: BigUInt(1), forwardPayload: nil, customPayload: nil)
    let jettonBody = try Builder().store(jetton).endCell()
    let out = try outListNode(message: MessageRelaxed.internal(to: jettonWallet, value: attachedNanoton, body: jettonBody), mode: 3)
    let body = Builder()
    try body.store(uint: UInt64(0x7369_676E), bits: 32)
    try body.store(uint: UInt64(0), bits: 32)
    try body.store(uint: UInt64(0xFFFF_FFFF), bits: 32)
    try body.store(uint: UInt64(1), bits: 32)
    try body.storeMaybe(ref: out)
    try body.store(bit: false)
    return try body.endCell().toBoc()
  }

  static func maliciousV5UnknownExtendedAction(victim: Address) throws -> Data {
    let out = try outListNode(message: MessageRelaxed.internal(to: victim, value: BigUInt(1_000_000)), mode: 3)
    let body = Builder()
    try body.store(uint: UInt64(0x7369_676E), bits: 32)
    try body.store(uint: UInt64(0), bits: 32)
    try body.store(uint: UInt64(0xFFFF_FFFF), bits: 32)
    try body.store(uint: UInt64(1), bits: 32)
    try body.storeMaybe(ref: out)
    try body.store(bit: true)
    try body.store(uint: UInt64(0x7F), bits: 8) // unknown extended-action tag
    return try body.endCell().toBoc()
  }

  private static let pub = Data(repeating: 0xAB, count: 32)

  private static func outListNode(message: MessageRelaxed, mode: UInt8) throws -> Builder {
    let node = Builder()
    try node.store(uint: UInt64(0x0EC3_C86D), bits: 32)
    try node.store(uint: UInt64(mode), bits: 8)
    try node.store(ref: Builder())
    try node.store(ref: Builder().store(message))
    return node
  }
}
