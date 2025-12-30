import SwiftUI

extension View {

    /// iOS: skryje pozadie navigation baru, macOS: nič (no-op)
    @ViewBuilder
    func platformHideNavigationBarBackground() -> some View {
        #if os(iOS)
        self.toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Opraví tvoj existujúci call `.iosHideNavigationBarBackround()`
    /// (na iOS spraví hide background, na macOS nič)
    @ViewBuilder
    func iosHideNavigationBarBackround() -> some View {
        platformHideNavigationBarBackground()
    }
}

extension ToolbarItemPlacement {
    static var platformTrailing: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }

    static var platformLeading: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
        #endif
    }
}
