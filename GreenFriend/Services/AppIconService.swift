import Foundation
import UIKit

@MainActor
final class AppIconService {
    static let shared = AppIconService()

    private init() {}

    func syncIcon(for theme: AppTheme) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let targetIconName: String? = (theme == .dark) ? "AppIconDarkV2" : nil
        if UIApplication.shared.alternateIconName == targetIconName { return }

        UIApplication.shared.setAlternateIconName(targetIconName) { error in
            guard error != nil else { return }
            // Retry once shortly after in case theme changed during app state transition.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                UIApplication.shared.setAlternateIconName(targetIconName) { retryError in
                    if let retryError {
                        print("AppIconService error: \(retryError.localizedDescription)")
                    }
                }
            }
        }
    }
}
