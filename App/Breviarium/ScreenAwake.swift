import UIKit

/// Keep screen awake (1.7, `docs/1.7_plan.md`, decided 2026-11-17): while the app is open,
/// the screen never dims or locks; iOS's own auto-lock applies again once the user leaves
/// it.
///
/// UIKit exception (approved 2026-11-17): SwiftUI has no API for the idle timer, so this
/// file makes the one UIKit call, `UIApplication.isIdleTimerDisabled`, and nothing else.
/// It needs no permission, entitlement or background mode, so a free Apple ID signs it,
/// and it works on iOS 26.
enum ScreenAwake {
    @MainActor static func apply(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
    }
}
