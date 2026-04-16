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
                        .foregroundStyle(LandingPalette.textPrimary)
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
            .background(LandingPalette.background.opacity(0.96))
        }
        .background {
            LinearGradient(
                colors: [LandingPalette.background, LandingPalette.backgroundTint],
                startPoint: .top,
                endPoint: .bottom
            )
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
                    .fill(isSelected ? Color(hex: "#7E9C78").opacity(0.38) : Color(hex: "#EFECE6"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
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
                    .fill(isSelected ? Color(hex: "#7E9C78").opacity(0.38) : Color(hex: "#EFECE6"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
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
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "#F2F4ED"))
                        .frame(width: 180, height: 180)
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
                                        .foregroundStyle(Color(hex: "#5F7B5A"))
                                    Text("add photo")
                                        .font(.bodyS)
                                        .foregroundStyle(Color(hex: "#5F7B5A"))
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
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "#F2F4ED"))
                            .frame(width: 110, height: 110)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color(hex: "#B8C7B2").opacity(0.8), lineWidth: 1)
                            }
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(Color(hex: "#5F7B5A"))
                            }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
