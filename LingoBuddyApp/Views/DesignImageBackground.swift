import SwiftUI
import UIKit

struct DesignImageBackground: View {
    let imageName: String

    var body: some View {
        GeometryReader { proxy in
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()
            } else {
                Color(red: 0.51, green: 0.81, blue: 0.97)
                    .ignoresSafeArea()
            }
        }
    }
}
