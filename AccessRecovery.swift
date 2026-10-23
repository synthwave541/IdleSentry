import Foundation
import CryptoKit

/// A copy of the identical signed executable keeps the same identity; a rebuilt
/// ad-hoc signature changes it and may invalidate macOS's saved approval.
enum BuildIdentity {
    static let current: String = {
        guard let url = Bundle.main.executableURL, let data = try? Data(contentsOf: url) else {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }()
}

enum AccessRecovery {
    static func shouldShow(granted: Bool, returningUser: Bool, previousBuild: String?,
                           currentBuild: String, lastTrustedBuild: String?, dismissedBuild: String?) -> Bool {
        guard !granted, dismissedBuild != currentBuild else { return false }
        return returningUser || lastTrustedBuild != nil || (previousBuild != nil && previousBuild != currentBuild)
    }
}
