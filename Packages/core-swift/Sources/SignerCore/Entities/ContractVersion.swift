public enum ContractVersion: String, Codable, CaseIterable {
  /// Regular wallets
  case v3R1 = "v3r1"
  case v3R2 = "v3r2"
  case v4R1 = "v4r1"
  case v4R2 = "v4r2"
  case v5Beta = "v5beta"
  case v5R1 = "v5r1"
  
  public static var currentVersion: ContractVersion {
    .v5R1
  }
}
