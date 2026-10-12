import Foundation

public struct TransactionModel {
  public struct Item {
    public let title: String
    public let subtitle: String?
    public let value: String?
    public let valueSubtitle: String?
    public let comment: String?
    /// A secondary line used for safety notes: an attached-TON excess recipient,
    /// an unknown op-code, a "whole balance" / "contract destroyed" warning, or the
    /// reason a request could not be decoded. `nil` when there is nothing to warn about.
    public let warning: String?
    /// Whether this item represents a high-risk action (wallet extension change,
    /// whole-balance / destroy send, or an undecodable request) and should be
    /// rendered with danger styling.
    public let isDangerous: Bool

    public init(
      title: String,
      subtitle: String?,
      value: String?,
      valueSubtitle: String?,
      comment: String?,
      warning: String? = nil,
      isDangerous: Bool = false
    ) {
      self.title = title
      self.subtitle = subtitle
      self.value = value
      self.valueSubtitle = valueSubtitle
      self.comment = comment
      self.warning = warning
      self.isDangerous = isDangerous
    }
  }

  public let items: [Item]
  public let seqno: UInt64
  public let tonNetwork: TonNetwork?
  public let boc: String
  /// `false` when the body could not be fully decoded. The confirmation screen must
  /// not allow signing in that case ("not shown -> not signed").
  public let canSign: Bool

  public init(
    items: [Item],
    seqno: UInt64,
    tonNetwork: TonNetwork?,
    boc: String,
    canSign: Bool = true
  ) {
    self.items = items
    self.seqno = seqno
    self.tonNetwork = tonNetwork
    self.boc = boc
    self.canSign = canSign
  }
}
