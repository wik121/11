import SwiftUI

/// The only branding anywhere in the app: a small, unobtrusive mark
/// shown in the bottom-right corner of each screen.
struct WatermarkView: View {
    var body: some View {
        Text("WT 2026")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}
