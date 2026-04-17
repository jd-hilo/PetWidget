import SwiftUI
import PhotosUI

private enum PhotoPickerSpeciesStyle {
    /// Dark muted sage (a touch greener than `#605F52`, same general weight).
    static let iconTint = Color(hex: "#556B52")
}

/// Selected: tight shadow that follows the tile edge — strongest below (`y` + small `radius`), minimal side bleed.
/// SwiftUI shadows are always radial; keep `radius` small and `x: 0` to bias darkness under the bottom edge.
private struct SpeciesSelectedShadowModifier: ViewModifier {
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSelected {
            content
                .shadow(color: Color.black.opacity(0.30), radius: 7, x: 0, y: 11)
                .shadow(color: Color.black.opacity(0.13), radius: 2, x: 0, y: 5)
        } else {
            content
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Photo Picker View

struct PhotoPickerView: View {
    @ObservedObject var draft: OnboardingDraft
    let onNext: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var isPhotoPickerPresented = false
    
    private enum LandingPalette {
        static let background = Color(hex: "#FDFEFA")
        static let backgroundTint = Color(hex: "#F2F4ED")
        static let surface = Color(hex: "#F2F4ED")
        static let accent = Color(hex: "#7E9C78")
        static let accentDark = Color(hex: "#5F7B5A")
        static let textPrimary = Color(hex: "#2A3128")
        static let textSecondary = Color(hex: "#6F7A70")
        static let border = Color(hex: "#B8C7B2")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("show me your pet")
                        .font(.displayL)
                        .foregroundStyle(LandingPalette.accentDark)
                    Text("add 3–5 clear face photos for the best results")
                        .font(.bodyM)
                        .bold()
                        .foregroundStyle(LandingPalette.textSecondary)
                }
                .padding(.horizontal, 24)

                // Photo grid (tap to open picker)
                PhotoGridView(
                    photos: draft.photos,
                    isLoading: isLoadingPhotos,
                    onTap: { isPhotoPickerPresented = true }
                )

                // Species picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("what kind of pet?")
                        .font(.titleL)
                        .foregroundStyle(LandingPalette.accentDark)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            SpeciesTileButton(
                                label: Species.dog.displayName.lowercased(),
                                iconAssetName: "dogIcon",
                                isSelected: draft.species == .dog,
                                action: { draft.species = .dog }
                            )

                            SpeciesTileButton(
                                label: Species.cat.displayName.lowercased(),
                                iconAssetName: "catIcon",
                                isSelected: draft.species == .cat,
                                action: { draft.species = .cat }
                            )
                        }

                        SpeciesWideButton(
                            label: Species.other.displayName.lowercased(),
                            isSelected: draft.species == .other,
                            action: { draft.species = .other }
                        )
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    isPhotoPickerPresented = true
                } label: {
                    Text(draft.photos.isEmpty ? "add photos" : "add more")
                        .font(.bodyL)
                        .foregroundStyle(PhotoPickerSpeciesStyle.iconTint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule(style: .continuous)
                                .fill(LandingPalette.surface)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(LandingPalette.border.opacity(0.85), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Text("continue →")
                        .font(.buttonFont)
                        .foregroundStyle(.white.opacity(draft.isPhotoStepValid ? 1 : 0.75))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule(style: .continuous)
                                .fill(draft.isPhotoStepValid ? LandingPalette.accent : LandingPalette.accent.opacity(0.45))
                        )
                        .shadow(
                            color: draft.isPhotoStepValid ? LandingPalette.accentDark.opacity(0.28) : .clear,
                            radius: 10,
                            x: 0,
                            y: 6
                        )
                }
                .buttonStyle(.plain)
                .disabled(!draft.isPhotoStepValid)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .background(Color.clear)
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [LandingPalette.background, LandingPalette.backgroundTint],
                    startPoint: .top,
                    endPoint: .bottom
                )
                OnboardingBackgroundPattern()
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                isLoadingPhotos = true
                var images: [UIImage] = []
                var dataItems: [Data] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                        dataItems.append(data)
                    }
                }
                await MainActor.run {
                    // Treat each picker session as an edit of current photo set.
                    draft.photos = images
                    draft.photoData = dataItems
                    isLoadingPhotos = false
                }
            }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedItems,
            maxSelectionCount: 5,
            matching: .images
        )
    }
}

private struct OnboardingBackgroundPattern: View {
    private let symbolColor = Color(hex: "#8FA287")

    private struct PatternSymbol {
        let systemName: String
        let point: CGPoint
        let size: CGFloat
        let opacity: Double
        let rotation: Double
    }

    private var leftEdgeSymbols: [PatternSymbol] {
        [
            .init(systemName: "pawprint.fill", point: .init(x: 0.06, y: 0.04), size: 42, opacity: 0.46, rotation: -12),
            .init(systemName: "pawprint", point: .init(x: 0.14, y: 0.09), size: 34, opacity: 0.38, rotation: 6),
            .init(systemName: "leaf", point: .init(x: 0.05, y: 0.16), size: 40, opacity: 0.34, rotation: 22),
            .init(systemName: "leaf.fill", point: .init(x: 0.15, y: 0.21), size: 30, opacity: 0.30, rotation: -18),
            .init(systemName: "pawprint.fill", point: .init(x: 0.05, y: 0.30), size: 38, opacity: 0.40, rotation: 10),
            .init(systemName: "pawprint", point: .init(x: 0.13, y: 0.36), size: 30, opacity: 0.34, rotation: -16),
            .init(systemName: "leaf", point: .init(x: 0.04, y: 0.45), size: 42, opacity: 0.32, rotation: 28),
            .init(systemName: "leaf.fill", point: .init(x: 0.13, y: 0.54), size: 30, opacity: 0.30, rotation: -24),
            .init(systemName: "pawprint.fill", point: .init(x: 0.06, y: 0.63), size: 40, opacity: 0.42, rotation: 8),
            .init(systemName: "pawprint", point: .init(x: 0.14, y: 0.70), size: 30, opacity: 0.34, rotation: -12),
            .init(systemName: "leaf", point: .init(x: 0.04, y: 0.79), size: 40, opacity: 0.32, rotation: 20),
            .init(systemName: "pawprint.fill", point: .init(x: 0.06, y: 0.90), size: 38, opacity: 0.40, rotation: 14),
            .init(systemName: "leaf.fill", point: .init(x: 0.15, y: 0.95), size: 30, opacity: 0.28, rotation: -18)
        ]
    }

    private var rightEdgeSymbols: [PatternSymbol] {
        [
            .init(systemName: "pawprint.fill", point: .init(x: 0.94, y: 0.05), size: 40, opacity: 0.44, rotation: 14),
            .init(systemName: "pawprint", point: .init(x: 0.86, y: 0.10), size: 32, opacity: 0.36, rotation: -8),
            .init(systemName: "leaf", point: .init(x: 0.96, y: 0.18), size: 40, opacity: 0.32, rotation: -24),
            .init(systemName: "leaf.fill", point: .init(x: 0.87, y: 0.23), size: 30, opacity: 0.30, rotation: 16),
            .init(systemName: "pawprint.fill", point: .init(x: 0.95, y: 0.32), size: 38, opacity: 0.40, rotation: -10),
            .init(systemName: "pawprint", point: .init(x: 0.87, y: 0.39), size: 30, opacity: 0.34, rotation: 12),
            .init(systemName: "leaf", point: .init(x: 0.96, y: 0.48), size: 42, opacity: 0.30, rotation: -18),
            .init(systemName: "leaf.fill", point: .init(x: 0.87, y: 0.57), size: 30, opacity: 0.28, rotation: 26),
            .init(systemName: "pawprint.fill", point: .init(x: 0.94, y: 0.66), size: 38, opacity: 0.40, rotation: -8),
            .init(systemName: "pawprint", point: .init(x: 0.86, y: 0.74), size: 30, opacity: 0.34, rotation: 10),
            .init(systemName: "leaf", point: .init(x: 0.95, y: 0.83), size: 40, opacity: 0.32, rotation: -22),
            .init(systemName: "pawprint.fill", point: .init(x: 0.93, y: 0.92), size: 38, opacity: 0.40, rotation: 10),
            .init(systemName: "leaf.fill", point: .init(x: 0.86, y: 0.97), size: 28, opacity: 0.26, rotation: 20)
        ]
    }

    var body: some View {
        let screenSize = UIScreen.main.bounds.size
        ZStack {
            ForEach(Array(leftEdgeSymbols.enumerated()), id: \.offset) { _, symbol in
                decorativeSymbol(
                    symbol.systemName,
                    at: symbol.point,
                    in: screenSize,
                    size: symbol.size,
                    opacity: symbol.opacity,
                    rotation: symbol.rotation
                )
            }

            ForEach(Array(rightEdgeSymbols.enumerated()), id: \.offset) { _, symbol in
                decorativeSymbol(
                    symbol.systemName,
                    at: symbol.point,
                    in: screenSize,
                    size: symbol.size,
                    opacity: symbol.opacity,
                    rotation: symbol.rotation
                )
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .allowsHitTesting(false)
    }

    private func decorativeSymbol(
        _ systemName: String,
        at relativePoint: CGPoint,
        in size: CGSize,
        size iconSize: CGFloat,
        opacity: Double,
        rotation: Double
    ) -> some View {
        let absoluteX = size.width * relativePoint.x
        let absoluteY = size.height * relativePoint.y

        return Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(symbolColor.opacity(opacity))
            .rotationEffect(.degrees(rotation))
            .position(x: absoluteX, y: absoluteY)
    }
}

struct SpeciesTileButton: View {
    let label: String
    let iconAssetName: String?
    let isSelected: Bool
    let action: () -> Void

    private var iconSideLength: CGFloat {
        guard let name = iconAssetName else { return 84 }
        return name.range(of: "cat", options: .caseInsensitive) != nil ? 96 : 84
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color(hex: "#7E9C78") : Color(hex: "#EFECE6"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
                    // Match small photo placeholder: tight sage glow + border.
                    .shadow(color: Color(hex: "#7E9C78").opacity(0.40), radius: 2, x: 0, y: 0)
                    .shadow(color: Color(hex: "#7E9C78").opacity(0.20), radius: 4, x: 0, y: 0)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color(hex: "#B8C7B2"))
                    }
                    .modifier(SpeciesSelectedShadowModifier(isSelected: isSelected))

                VStack(spacing: 10) {
                    Spacer()

                    if let iconAssetName,
                       let uiImage = UIImage(named: iconAssetName) {
                        Image(uiImage: uiImage)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSideLength, height: iconSideLength)
                            .foregroundStyle(PhotoPickerSpeciesStyle.iconTint)
                            .accessibilityLabel(Text(label))
                    } else {
                        Text(label)
                            .font(.bodyL)
                            .foregroundStyle(PhotoPickerSpeciesStyle.iconTint)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 132)

                if isSelected {
                    Circle()
                        .fill(Color(hex: "#5F7B5A"))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(10)
                }
            }
        }
        .buttonStyle(SpringButtonStyle())
    }
}

struct SpeciesWideButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color(hex: "#7E9C78") : Color(hex: "#EFECE6"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .shadow(color: Color(hex: "#7E9C78").opacity(0.40), radius: 2, x: 0, y: 0)
                    .shadow(color: Color(hex: "#7E9C78").opacity(0.20), radius: 4, x: 0, y: 0)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color(hex: "#B8C7B2"))
                    }
                    .modifier(SpeciesSelectedShadowModifier(isSelected: isSelected))

                Text(label)
                    .font(.bodyM)
                    .bold()
                    .foregroundStyle(PhotoPickerSpeciesStyle.iconTint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Photo Grid

struct PhotoGridView: View {
    let photos: [UIImage]
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Large primary photo
                if let first = photos.first {
                    Image(uiImage: first)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color(hex: "#7E9C78").opacity(0.60), radius: 2, x: 0, y: 0)
                        .shadow(color: Color(hex: "#7E9C78").opacity(0.40), radius: 4, x: 0, y: 0)
                        .shadow(color: Color(hex: "#7E9C78").opacity(0.20), radius: 6, x: 0, y: 0)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "#EFECE6"))
                        .frame(width: 180, height: 180)
                        // Tight border-hugging glow (small radii, no offset — dense near the edge).
                        .shadow(color: Color(hex: "#7E9C78").opacity(0.60), radius: 2, x: 0, y: 0)
                        .shadow(color: Color(hex: "#7E9C78").opacity(0.40), radius: 4, x: 0, y: 0)
                        .shadow(color: Color(hex: "#7E9C78").opacity(0.20), radius: 6, x: 0, y: 0)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 2, dash: [8])
                                )
                                .foregroundStyle(Color(hex: "#B8C7B2"))
                        }
                        .overlay {
                            if isLoading {
                                ProgressView()
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundStyle(PhotoPickerSpeciesStyle.iconTint)
                                    Text("add photo")
                                        .font(.bodyS)
                                        .foregroundStyle(PhotoPickerSpeciesStyle.iconTint)
                                }
                            }
                        }
                }

                // Small thumbnails
                ForEach(1..<5, id: \.self) { i in
                    if i < photos.count {
                        Image(uiImage: photos[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color(hex: "#7E9C78").opacity(0.40), radius: 2, x: 0, y: 0)
                            .shadow(color: Color(hex: "#7E9C78").opacity(0.20), radius: 4, x: 0, y: 0)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "#EFECE6"))
                            .frame(width: 110, height: 110)
                            // Lighter, still tight to the border.
                            .shadow(color: Color(hex: "#7E9C78").opacity(0.40), radius: 2, x: 0, y: 0)
                            .shadow(color: Color(hex: "#7E9C78").opacity(0.20), radius: 4, x: 0, y: 0)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 2)
                                    )
                                    .foregroundStyle(Color(hex: "#B8C7B2"))
                            }
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(PhotoPickerSpeciesStyle.iconTint)
                            }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
