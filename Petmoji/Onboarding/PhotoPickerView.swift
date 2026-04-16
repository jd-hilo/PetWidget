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
                        .foregroundStyle(Color.pmTextPrimary)
                    Text("add 3–5 clear face photos for the best results")
                        .font(.bodyM)
                        .foregroundStyle(Color.pmTextSecondary)
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
                        .foregroundStyle(Color.pmTextPrimary)
                        .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        ForEach(Species.allCases, id: \.self) { species in
                            PMChip(
                                label: species.displayName,
                                isSelected: draft.species == species
                            ) {
                                draft.species = species
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    isPhotoPickerPresented = true
                } label: {
                    Text(draft.photos.isEmpty ? "add photos" : "add more photos")
                        .font(.buttonFont)
                        .foregroundStyle(Color.pmPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.pmPrimaryLight, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                PMPrimaryButton(
                    title: "continue →",
                    action: onNext,
                    isEnabled: draft.isPhotoStepValid
                )
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
            .background(Color.pmBackground.opacity(0.95))
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
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.pmCardAlt)
                        .frame(width: 220, height: 220)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 2, dash: [8])
                                )
                                .foregroundStyle(Color.pmTextSecondary.opacity(0.4))
                        }
                        .overlay {
                            if isLoading {
                                ProgressView()
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundStyle(Color.pmTextSecondary)
                                    Text("add photo")
                                        .font(.bodyS)
                                        .foregroundStyle(Color.pmTextSecondary)
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
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.pmCardAlt)
                            .frame(width: 140, height: 140)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(Color.pmTextSecondary)
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
