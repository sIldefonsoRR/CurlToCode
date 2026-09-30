import AppKit
import SwiftUI

/// Shown over the main window for a moment at launch (click to skip).
struct SplashView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.22, blue: 0.40), Color(red: 0.21, green: 0.45, blue: 0.65)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )

            VStack(spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

                Text("cURL to Code")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                Text("Paste a curl command, get ready-to-run code.")
                    .font(.title3)
                    .opacity(0.85)

                HStack(spacing: 8) {
                    ForEach(Language.allCases) { language in
                        HStack(spacing: 5) {
                            Circle().fill(language.color).frame(width: 7, height: 7)
                            Text(language.displayName)
                        }
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                    }
                }
                .padding(.top, 6)

                ProgressView()
                    .controlSize(.small)
                    .colorScheme(.dark)
                    .padding(.top, 12)

                Text("Version \(version)")
                    .font(.caption)
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(40)
        }
    }
}
