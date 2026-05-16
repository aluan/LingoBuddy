import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct VideoLearningView: View {
    var onBack: (() -> Void)? = nil
    @ObservedObject var sharedImportStore: SharedImportStore
    @StateObject private var viewModel = VideoLearningViewModel()

    init(onBack: (() -> Void)? = nil, sharedImportStore: SharedImportStore) {
        self.onBack = onBack
        self.sharedImportStore = sharedImportStore
    }
    @State private var urlInput = ""
    @State private var showProcessing = false
    @State private var processingVideoId: String?
    @State private var selectedVideo: VideoContent? = nil
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPDFPicker = false
    @State private var importedSharedItemIDs: Set<String> = []
    @FocusState private var isURLInputFocused: Bool

    private let pageGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.99, blue: 0.96),
            Color(red: 0.82, green: 0.94, blue: 0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        NavigationStack {
            ZStack {
                pageGradient
                    .ignoresSafeArea()
                    .onTapGesture {
                        isURLInputFocused = false
                    }

                navigationLinks

                VStack(spacing: 20) {
                    topBar

                    urlInputSection

                    if viewModel.isLoading {
                        ProgressView("Loading videos...")
                    } else if viewModel.videos.isEmpty {
                        emptyState
                    } else {
                        videoList
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await viewModel.loadVideos()
                    await importPendingSharedItems()
                }
            }
            .onChange(of: sharedImportStore.pendingItems) { _ in
                Task { await importPendingSharedItems() }
            }
            .sheet(isPresented: $showProcessing) {
                if let videoId = processingVideoId {
                    VideoProcessingView(videoId: videoId, onComplete: { video in
                        showProcessing = false
                        processingVideoId = nil
                        Task {
                            await viewModel.loadVideos()
                        }
                    })
                }
            }
        }
    }

    private var navigationLinks: some View {
        NavigationLink(
            destination: Group {
                if let video = selectedVideo {
                    VideoDetailView(
                        video: video,
                        onBack: {
                            selectedVideo = nil
                        },
                        onDelete: {
                            selectedVideo = nil
                            Task {
                                await viewModel.deleteVideo(videoId: video.id)
                            }
                        }
                    )
                }
            },
            isActive: Binding(
                get: { selectedVideo != nil },
                set: { if !$0 { selectedVideo = nil } }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.white.opacity(0.78)))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(onBack == nil ? "LingoBuddy" : "Learning")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                Text("Learn from videos, photos, PDFs, and webpages")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))

                Text("添加学习内容")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

                Spacer()

                if !urlInput.isEmpty {
                    Button(action: { urlInput = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("", text: $urlInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .placeholder(when: urlInput.isEmpty) {
                            Text("粘贴 B站 / 网页链接")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        .focused($isURLInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !urlInput.isEmpty {
                                submitContentURL()
                            }
                        }

                    if !urlInput.isEmpty {
                        Button(action: submitContentURL) {
                            Group {
                                if viewModel.isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                }
                            }
                            .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSubmitting)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: pasteFromClipboard) {
                            VStack(spacing: 2) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 18))
                                Text("粘贴")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45))
                            .frame(width: 44)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .shadow(color: isURLInputFocused ? Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.15) : .black.opacity(0.04), radius: isURLInputFocused ? 8 : 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isURLInputFocused ? Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.3) : .clear,
                            lineWidth: 2
                        )
                )

                if !urlInput.isEmpty && !isURLInputFocused {
                    Text("支持 B站视频链接、普通网页链接")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            sourceActions

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.red.opacity(0.08))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: urlInput.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isURLInputFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.errorMessage)
    }

    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string {
            urlInput = clipboardString
            isURLInputFocused = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.13, green: 0.53, blue: 0.45).opacity(0.5))

            Text("No learning content yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))

            Text("Add a Bilibili video, webpage, photo, camera shot, or PDF to start learning")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .onTapGesture {
            isURLInputFocused = false
        }
    }

    private var videoList: some View {
        List {
            ForEach(viewModel.videos) { video in
                VideoCard(video: video) {
                    selectedVideo = video
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteImmediately(video)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isURLInputFocused = false
        }
    }


    private func deleteImmediately(_ video: VideoContent) {
        if selectedVideo?.id == video.id {
            selectedVideo = nil
        }
        Task {
            await viewModel.deleteVideo(videoId: video.id)
        }
    }

    private var sourceActions: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                SourceActionPill(title: "相册", icon: "photo.on.rectangle", color: Color(red: 0.12, green: 0.45, blue: 0.78))
            }
            .buttonStyle(.plain)

            Button { showCamera = true } label: {
                SourceActionPill(title: "拍照", icon: "camera.fill", color: Color(red: 0.48, green: 0.33, blue: 0.78))
            }
            .buttonStyle(.plain)

            Button { showPDFPicker = true } label: {
                SourceActionPill(title: "PDF", icon: "doc.richtext.fill", color: Color(red: 0.86, green: 0.38, blue: 0.18))
            }
            .buttonStyle(.plain)
        }
        .onChange(of: selectedPhotoItem) { item in
            guard let item else { return }
            Task { await uploadPhotoItem(item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await uploadUIImage(image, fileName: "camera-\(UUID().uuidString).jpg") }
            }
        }
        .sheet(isPresented: $showPDFPicker) {
            DocumentPicker(contentTypes: [.pdf]) { url in
                Task { await uploadFileURL(url, contentType: "pdf") }
            }
        }
    }


    private func importPendingSharedItems() async {
        let items = sharedImportStore.pendingItems.filter { !importedSharedItemIDs.contains($0.id) }
        guard !items.isEmpty else { return }

        for item in items {
            importedSharedItemIDs.insert(item.id)
            do {
                let videoId = try await importSharedItem(item)
                sharedImportStore.remove(item)
                await viewModel.loadVideos()
                if item.kind != .url || !isBilibiliInput(item.text ?? "") {
                    selectedVideo = viewModel.videos.first(where: { $0.id == videoId })
                }
            } catch {
                importedSharedItemIDs.remove(item.id)
                viewModel.errorMessage = error.localizedDescription
                break
            }
        }
    }

    private func importSharedItem(_ item: SharedImportItem) async throws -> String {
        switch item.kind {
        case .url:
            guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                throw VideoLearningError.decodingError
            }
            if isBilibiliInput(text) {
                let videoId = try await viewModel.submitVideo(url: text)
                processingVideoId = videoId
                showProcessing = true
                return videoId
            } else {
                return try await viewModel.submitWebpage(url: text)
            }

        case .text:
            guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                throw VideoLearningError.decodingError
            }
            if let url = firstURL(in: text) {
                if isBilibiliInput(url) {
                    let videoId = try await viewModel.submitVideo(url: url)
                    processingVideoId = videoId
                    showProcessing = true
                    return videoId
                }
                return try await viewModel.submitWebpage(url: url)
            }
            return try await viewModel.submitText(text: text)

        case .image, .pdf, .file:
            guard let fileURL = sharedImportStore.fileURL(for: item) else {
                throw VideoLearningError.decodingError
            }
            let data = try Data(contentsOf: fileURL)
            let contentType = item.kind == .pdf ? "pdf" : "image"
            let mimeType = item.mimeType ?? (item.kind == .pdf ? "application/pdf" : "image/jpeg")
            return try await viewModel.uploadLearningFile(
                data: data,
                fileName: item.fileName ?? fileURL.lastPathComponent,
                mimeType: mimeType,
                contentType: contentType
            )
        }
    }

    private func firstURL(in text: String) -> String? {
        text.range(of: #"https?://\S+"#, options: .regularExpression)
            .map { String(text[$0]).trimmingCharacters(in: CharacterSet(charactersIn: "，。；、）)】]\n\t ")) }
    }

    private func isBilibiliInput(_ input: String) -> Bool {
        input.localizedCaseInsensitiveContains("bilibili")
            || input.localizedCaseInsensitiveContains("b23.tv")
            || input.localizedCaseInsensitiveContains("BV")
    }

    private func submitContentURL() {
        isURLInputFocused = false

        Task {
            do {
                let input = urlInput
                let videoId: String
                if isBilibiliInput(input) {
                    videoId = try await viewModel.submitVideo(url: input)
                    processingVideoId = videoId
                    showProcessing = true
                } else {
                    videoId = try await viewModel.submitWebpage(url: input)
                    await viewModel.loadVideos()
                    selectedVideo = viewModel.videos.first(where: { $0.id == videoId })
                }
                urlInput = ""
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func uploadPhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw VideoLearningError.decodingError
            }
            let videoId = try await viewModel.uploadLearningFile(
                data: data,
                fileName: "photo-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                contentType: "image"
            )
            await viewModel.loadVideos()
            selectedVideo = viewModel.videos.first(where: { $0.id == videoId })
            selectedPhotoItem = nil
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func uploadUIImage(_ image: UIImage, fileName: String) async {
        do {
            guard let data = image.jpegData(compressionQuality: 0.86) else {
                throw VideoLearningError.decodingError
            }
            let videoId = try await viewModel.uploadLearningFile(data: data, fileName: fileName, mimeType: "image/jpeg", contentType: "image")
            await viewModel.loadVideos()
            selectedVideo = viewModel.videos.first(where: { $0.id == videoId })
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func uploadFileURL(_ url: URL, contentType: String) async {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let videoId = try await viewModel.uploadLearningFile(
                data: data,
                fileName: url.lastPathComponent,
                mimeType: "application/pdf",
                contentType: contentType
            )
            await viewModel.loadVideos()
            selectedVideo = viewModel.videos.first(where: { $0.id == videoId })
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

struct VideoCard: View {
    let video: VideoContent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.19, blue: 0.24))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(formatDuration(video.duration))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let source = video.transcriptSource {
                            Text("• \(source)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.78))
            )
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch video.transcriptStatus {
        case "completed":
            return Color(red: 0.13, green: 0.53, blue: 0.45)
        case "processing":
            return Color(red: 0.86, green: 0.52, blue: 0.14)
        case "failed":
            return .red
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch video.transcriptStatus {
        case "completed":
            return "Ready"
        case "processing":
            return "Processing..."
        case "failed":
            return "Failed"
        default:
            return "Pending"
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

@MainActor
final class VideoLearningViewModel: ObservableObject {
    @Published var videos: [VideoContent] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let service = VideoLearningService()

    func loadVideos() async {
        isLoading = true
        errorMessage = nil

        do {
            videos = try await service.fetchVideoList()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func submitVideo(url: String) async throws -> String {
        isSubmitting = true
        errorMessage = nil

        defer { isSubmitting = false }

        return try await service.submitVideo(url: url)
    }

    func submitWebpage(url: String) async throws -> String {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        return try await service.submitWebpage(url: url)
    }

    func submitText(text: String, title: String? = nil) async throws -> String {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        return try await service.submitText(text: text, title: title)
    }

    func uploadLearningFile(data: Data, fileName: String, mimeType: String, contentType: String) async throws -> String {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        return try await service.uploadLearningFile(data: data, fileName: fileName, mimeType: mimeType, contentType: contentType)
    }

    func deleteVideo(videoId: String) async {
        do {
            try await service.deleteVideo(videoId: videoId)
            await loadVideos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    VideoLearningView(sharedImportStore: SharedImportStore())
}

// MARK: - View Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct SourceActionPill: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPicked: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        let dismiss: DismissAction

        init(onPicked: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onPicked = onPicked
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPicked(url)
            }
            dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}
