//
//  AvatarPickerView.swift
//  Daily Music
//
//  The tappable avatar: shows the current photo (or InitialsAvatar), opens the
//  privacy-preserving PhotosPicker (no usage string needed), crops, downscales,
//  uploads, and writes the resulting public URL back to the bound avatarURL.
//

import SwiftUI
import PhotosUI

struct AvatarPickerView: View {
    @Binding var avatarURL: String?
    let displayName: String?
    var size: CGFloat = 96

    @Environment(AppEnvironment.self) private var env

    @State private var pickerItem: PhotosPickerItem?
    @State private var cropItem: IdentifiableImage?
    @State private var isUploading = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    preview
                    Circle()
                        .fill(Theme.Brand.gradient[0])
                        .frame(width: size * 0.32, height: size * 0.32)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay { Circle().stroke(Color(.systemBackground), lineWidth: 3) }
                }
            }
            .buttonStyle(.plain)

            if isUploading { ProgressView() }
            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }
        }
        .onChange(of: pickerItem) { _, item in Task { await loadPicked(item) } }
        .sheet(item: $cropItem) { wrapped in
            CircularImageCropper(
                image: wrapped.image,
                onConfirm: { cropped in cropItem = nil; Task { await upload(cropped) } },
                onCancel: { cropItem = nil }
            )
        }
    }

    @ViewBuilder private var preview: some View {
        if let avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { image in image.resizable().scaledToFill() }
                placeholder: { InitialsAvatar(name: displayName, size: size) }
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            InitialsAvatar(name: displayName, size: size)
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let ui = UIImage(data: data) {
            cropItem = IdentifiableImage(ui)
        }
        pickerItem = nil
    }

    private func upload(_ image: UIImage) async {
        guard let data = AvatarImageProcessor.downscaledJPEG(image) else { return }
        isUploading = true; errorText = nil
        defer { isUploading = false }
        do { avatarURL = try await env.profileStore.uploadAvatar(data) }
        catch { errorText = "Couldn't upload that photo. Try again." }
    }
}

// Wraps a UIImage so it can drive `.sheet(item:)`.
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
    init(_ image: UIImage) { self.image = image }
}
