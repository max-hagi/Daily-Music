import SwiftUI
import Testing
@testable import Daily_Music

@MainActor
struct LiquidGlassStyleTests {
    @Test func reusableGlassStylesCompileForCommonSurfaces() {
        _ = Text("card").glassCardStyle()
        _ = Text("pill").glassPillStyle()
        _ = Image(systemName: "music.note").glassIconButtonStyle(tint: .pink)

        #expect(Bool(true))
    }
}
