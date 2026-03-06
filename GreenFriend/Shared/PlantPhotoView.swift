import SwiftUI
import UIKit

struct PlantPhotoView: View {
    let customImageData: Data?
    let referenceImageURL: String?
    let size: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let customImageData,
               let uiImage = UIImage(data: customImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let referenceImageURL,
                      let url = URL(string: referenceImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        photoPlaceholder
                    case .failure:
                        photoPlaceholder
                    @unknown default:
                        photoPlaceholder
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }

    private var photoPlaceholder: some View {
        Image("PlantPlaceholder")
            .resizable()
            .scaledToFill()
    }
}
