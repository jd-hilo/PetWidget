import SwiftUI

enum BrandLandingMode {
    case loading
    case welcome
}

struct BrandLandingView: View {
    @Environment(\.petmojiPalette) private var palette

    let mode: BrandLandingMode
    var onGetStarted: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text("Petmoji")
                .font(.displayL)
                .foregroundStyle(palette.accentDark)

            Text("your pet, on your home screen")
                .font(.bodyM)
                .bold()
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .pmSageScreenBackground()
        .safeAreaInset(edge: .bottom) {
            if mode == .welcome, let onGetStarted {
                PMSageCTAButton(title: "get started", action: onGetStarted)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
    }
}
