import SwiftUI
import PhotosUI

// MARK: - Photo Picker View

struct PhotoPickerView: View {
    @ObservedObject var draft: OnboardingDraft
    let onNext: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var isPhotoPickerPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("show me your pet")
                        .font(.displayL)
                        .foregroundStyle(Color.pmSageAccentDark)
                    Text("add 3–5 clear face photos for the best results")
                        .font(.bodyM)
                        .bold()
                        .foregroundStyle(Color.pmSageTextSecondary)
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
                        .foregroundStyle(Color.pmSageAccentDark)
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
                PMSageCTAButton(
                    title: "continue →",
                    action: onNext,
                    isEnabled: draft.isPhotoStepValid
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .background(Color.clear)
        }
        .pmSageScreenBackground()
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
                    .fill(isSelected ? Color.pmSageAccent : Color.pmSageCardNeutral)
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
                    .shadow(color: Color.pmSageAccent.opacity(0.40), radius: 2, x: 0, y: 0)
                    .shadow(color: Color.pmSageAccent.opacity(0.20), radius: 4, x: 0, y: 0)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color.pmSageBorder)
                    }
                    .pmSageSelectableTileShadow(isSelected: isSelected)

                VStack(spacing: 10) {
                    Spacer()

                    if let iconAssetName,
                       let uiImage = UIImage(named: iconAssetName) {
                        Image(uiImage: uiImage)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSideLength, height: iconSideLength)
                            .foregroundStyle(Color.pmSageIconTint)
                            .accessibilityLabel(Text(label))
                    } else {
                        Text(label)
                            .font(.bodyL)
                            .foregroundStyle(Color.pmSageIconTint)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 132)

                if isSelected {
                    Circle()
                        .fill(Color.pmSageAccentDark)
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
                    .fill(isSelected ? Color.pmSageAccent : Color.pmSageCardNeutral)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .shadow(color: Color.pmSageAccent.opacity(0.40), radius: 2, x: 0, y: 0)
                    .shadow(color: Color.pmSageAccent.opacity(0.20), radius: 4, x: 0, y: 0)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color.pmSageBorder)
                    }
                    .pmSageSelectableTileShadow(isSelected: isSelected)

                Text(label)
                    .font(.bodyM)
                    .bold()
                    .foregroundStyle(Color.pmSageIconTint)
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
                        .shadow(color: Color.pmSageAccent.opacity(0.60), radius: 2, x: 0, y: 0)
                        .shadow(color: Color.pmSageAccent.opacity(0.40), radius: 4, x: 0, y: 0)
                        .shadow(color: Color.pmSageAccent.opacity(0.20), radius: 6, x: 0, y: 0)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.pmSageCardNeutral)
                        .frame(width: 180, height: 180)
                        .shadow(color: Color.pmSageAccent.opacity(0.60), radius: 2, x: 0, y: 0)
                        .shadow(color: Color.pmSageAccent.opacity(0.40), radius: 4, x: 0, y: 0)
                        .shadow(color: Color.pmSageAccent.opacity(0.20), radius: 6, x: 0, y: 0)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 2, dash: [8])
                                )
                                .foregroundStyle(Color.pmSageBorder)
                        }
                        .overlay {
                            if isLoading {
                                ProgressView()
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundStyle(Color.pmSageIconTint)
                                    Text("add photo")
                                        .font(.bodyS)
                                        .foregroundStyle(Color.pmSageIconTint)
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
                            .shadow(color: Color.pmSageAccent.opacity(0.40), radius: 2, x: 0, y: 0)
                            .shadow(color: Color.pmSageAccent.opacity(0.20), radius: 4, x: 0, y: 0)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.pmSageCardNeutral)
                            .frame(width: 110, height: 110)
                            .shadow(color: Color.pmSageAccent.opacity(0.40), radius: 2, x: 0, y: 0)
                            .shadow(color: Color.pmSageAccent.opacity(0.20), radius: 4, x: 0, y: 0)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 2)
                                    )
                                    .foregroundStyle(Color.pmSageBorder)
                            }
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(Color.pmSageIconTint)
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
