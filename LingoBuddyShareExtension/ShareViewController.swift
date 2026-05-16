import UIKit
import UniformTypeIdentifiers
import LinkPresentation
import os.log

final class ShareViewController: UIViewController {
    private let logger = Logger(subsystem: "com.aluan.LingoBuddys.ShareExtension", category: "ShareViewController")
    private let closeButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let previewIconView = UIImageView()
    private let previewTitleLabel = UILabel()
    private let previewSubtitleLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var pendingItem: SharedImportItem?
    private var isSaving = false

    override func viewDidLoad() {
        super.viewDidLoad()
        logger.log("ShareExtension: viewDidLoad called")
        configureUI()
        logger.log("ShareExtension: configureUI completed")
        Task { await prepareSharedContent() }
    }

    private func configureUI() {
        view.backgroundColor = .systemBackground

        closeButton.setTitle("取消", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.tintColor = UIColor(red: 0.13, green: 0.53, blue: 0.45, alpha: 1)
        saveButton.isEnabled = false
        saveButton.alpha = 0.45
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)

        titleLabel.text = "LingoBuddy"
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)
        header.addSubview(titleLabel)
        header.addSubview(saveButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 64),
            closeButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            saveButton.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])

        let separator = UIView()
        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true

        let preview = makePreviewView()

        let stack = UIStackView(arrangedSubviews: [header, separator, preview])
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ])

        loadingIndicator.startAnimating()
    }

    private func makePreviewView() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemBackground

        previewIconView.image = UIImage(systemName: "doc.text.image.fill")
        previewIconView.tintColor = .white
        previewIconView.contentMode = .center
        previewIconView.backgroundColor = UIColor(red: 0.18, green: 0.42, blue: 0.95, alpha: 1)
        previewIconView.layer.cornerRadius = 4
        previewIconView.clipsToBounds = true
        previewIconView.translatesAutoresizingMaskIntoConstraints = false

        previewTitleLabel.text = "正在读取分享内容..."
        previewTitleLabel.font = .systemFont(ofSize: 20, weight: .regular)
        previewTitleLabel.textColor = .label
        previewTitleLabel.numberOfLines = 2
        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        previewSubtitleLabel.text = "稍等一下，即可收藏到 LingoBuddy"
        previewSubtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        previewSubtitleLabel.textColor = .secondaryLabel
        previewSubtitleLabel.numberOfLines = 3
        previewSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(previewIconView)
        container.addSubview(previewTitleLabel)
        container.addSubview(previewSubtitleLabel)
        container.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 166),

            previewIconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            previewIconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 32),
            previewIconView.widthAnchor.constraint(equalToConstant: 112),
            previewIconView.heightAnchor.constraint(equalToConstant: 112),

            previewTitleLabel.leadingAnchor.constraint(equalTo: previewIconView.trailingAnchor, constant: 18),
            previewTitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -28),
            previewTitleLabel.topAnchor.constraint(equalTo: previewIconView.topAnchor, constant: 4),

            previewSubtitleLabel.leadingAnchor.constraint(equalTo: previewTitleLabel.leadingAnchor),
            previewSubtitleLabel.trailingAnchor.constraint(equalTo: previewTitleLabel.trailingAnchor),
            previewSubtitleLabel.topAnchor.constraint(equalTo: previewTitleLabel.bottomAnchor, constant: 18),

            loadingIndicator.leadingAnchor.constraint(equalTo: previewTitleLabel.leadingAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: previewSubtitleLabel.bottomAnchor, constant: 12)
        ])

        return container
    }

    private func prepareSharedContent() async {
        print("=== LingoBuddy: prepareSharedContent started ===")
        do {
            guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
                print("=== LingoBuddy: no extension items ===")
                throw ShareImportError.noInput
            }

            print("=== LingoBuddy: found \(extensionItems.count) extension items ===")

            for extensionItem in extensionItems {
                print("=== LingoBuddy: processing extension item with \(extensionItem.attachments?.count ?? 0) attachments ===")
                for provider in extensionItem.attachments ?? [] {
                    if let item = try await importItem(from: provider) {
                        print("=== LingoBuddy: successfully imported item of kind \(item.kind) ===")
                        await MainActor.run {
                            pendingItem = item
                            showReadyState(for: item)
                            print("=== LingoBuddy: showReadyState called, buttons should be enabled ===")
                        }
                        return
                    }
                }
            }

            print("=== LingoBuddy: no supported content found ===")
            throw ShareImportError.unsupported
        } catch {
            print("=== LingoBuddy: error preparing content: \(error) ===")
            await MainActor.run {
                loadingIndicator.stopAnimating()
                loadingIndicator.isHidden = true
                previewTitleLabel.text = "暂不支持这个内容"
                previewSubtitleLabel.text = "请分享网页链接、文字、图片或 PDF。"
                saveButton.isEnabled = false
                saveButton.alpha = 0.45
            }
        }
    }

    private func showReadyState(for item: SharedImportItem) {
        print("=== LingoBuddy: showReadyState called for item kind: \(item.kind) ===")
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true

        saveButton.isEnabled = true
        saveButton.alpha = 1
        print("=== LingoBuddy: saveButton enabled - saveButton.isEnabled=\(saveButton.isEnabled) ===")

        switch item.kind {
        case .url:
            previewIconView.contentMode = .center
            previewIconView.backgroundColor = UIColor(red: 0.18, green: 0.42, blue: 0.95, alpha: 1)
            previewIconView.tintColor = .white
            previewIconView.image = UIImage(systemName: "link")
            previewTitleLabel.text = cleanedPreviewTitle(item.text) ?? "网页链接"
            previewSubtitleLabel.text = item.text ?? "点右上角“保存”后，会添加到 LingoBuddy。"

            if let text = item.text, let url = URL(string: text) {
                Task { await loadLinkPreview(for: url) }
            }
        case .text:
            previewIconView.image = UIImage(systemName: "text.alignleft")
            previewTitleLabel.text = "文本内容"
            previewSubtitleLabel.text = cleanedPreviewTitle(item.text) ?? "点右上角“保存”后，会添加到 LingoBuddy。"
        case .image:
            previewIconView.image = UIImage(systemName: "photo.fill")
            previewTitleLabel.text = item.fileName ?? "图片"
            previewSubtitleLabel.text = "点右上角“保存”后，会添加到 LingoBuddy。"
        case .pdf:
            previewIconView.image = UIImage(systemName: "doc.richtext.fill")
            previewTitleLabel.text = item.fileName ?? "PDF 文档"
            previewSubtitleLabel.text = "点右上角“保存”后，会添加到 LingoBuddy。"
        case .file:
            previewIconView.image = UIImage(systemName: "doc.fill")
            previewTitleLabel.text = item.fileName ?? "文件"
            previewSubtitleLabel.text = "点右上角“保存”后，会添加到 LingoBuddy。"
        }
    }

    private func loadLinkPreview(for url: URL) async {
        let metadataProvider = LPMetadataProvider()
        metadataProvider.timeout = 5

        do {
            let metadata = try await fetchMetadata(for: url, provider: metadataProvider)

            await MainActor.run {
                if let title = metadata.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    previewTitleLabel.text = title
                }

                let subtitle = metadata.originalURL?.absoluteString ?? metadata.url?.absoluteString ?? url.absoluteString
                previewSubtitleLabel.text = subtitle
            }

            if let imageProvider = metadata.imageProvider ?? metadata.iconProvider,
               let image = try? await loadPreviewImage(from: imageProvider) {
                await MainActor.run {
                    previewIconView.image = image
                    previewIconView.tintColor = nil
                    previewIconView.backgroundColor = .secondarySystemBackground
                    previewIconView.contentMode = .scaleAspectFill
                }
            }
        } catch {
            NSLog("LingoBuddyShareExtension link preview failed: %@", String(describing: error))
        }
    }

    private func fetchMetadata(for url: URL, provider: LPMetadataProvider) async throws -> LPLinkMetadata {
        try await withCheckedThrowingContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: ShareImportError.unsupported)
                }
            }
        }
    }

    private func loadPreviewImage(from provider: NSItemProvider) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error { continuation.resume(throwing: error); return }
                    if let image = object as? UIImage {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: ShareImportError.unsupported)
                    }
                }
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error { continuation.resume(throwing: error); return }
                if let data, let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ShareImportError.unsupported)
                }
            }
        }
    }

    private func cleanedPreviewTitle(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= 48 { return cleaned }
        return String(cleaned.prefix(48)) + "..."
    }

    @objc private func saveButtonTapped() {
        logger.log("ShareExtension: saveButtonTapped called")
        guard let pendingItem, !isSaving else {
            logger.log("ShareExtension: save ignored, pendingItem=\(String(describing: self.pendingItem)), isSaving=\(self.isSaving)")
            return
        }

        isSaving = true
        setSavingUI(true)
        previewTitleLabel.text = "正在保存..."
        previewSubtitleLabel.text = "正在添加到 LingoBuddy"

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await ShareExtensionBackend.submit(item: pendingItem)
                await MainActor.run {
                    self.logger.log("ShareExtension: item submitted to backend")
                    self.previewTitleLabel.text = "已保存"
                    self.previewSubtitleLabel.text = "已添加到 LingoBuddy"
                    self.loadingIndicator.stopAnimating()
                    self.loadingIndicator.isHidden = true
                }
                try? await Task.sleep(nanoseconds: 650_000_000)
                await MainActor.run {
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            } catch {
                await MainActor.run {
                    self.logger.error("ShareExtension: save failed: \(error.localizedDescription)")
                    self.isSaving = false
                    self.setSavingUI(false)
                    self.previewTitleLabel.text = "保存失败"
                    self.previewSubtitleLabel.text = error.localizedDescription
                }
            }
        }
    }

    private func setSavingUI(_ saving: Bool) {
        closeButton.isEnabled = !saving
        saveButton.isEnabled = !saving && pendingItem != nil
        saveButton.alpha = saveButton.isEnabled ? 1 : 0.45
        if saving {
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
            saveButton.setTitle("保存中", for: .normal)
        } else {
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            saveButton.setTitle("保存", for: .normal)
        }
    }

    @objc private func closeButtonTapped() {
        extensionContext?.cancelRequest(withError: ShareImportError.cancelled)
    }

    private func importItem(from provider: NSItemProvider) async throws -> SharedImportItem? {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = try await loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
            return SharedImportItem(
                id: UUID().uuidString,
                kind: .url,
                text: url.absoluteString,
                fileName: nil,
                mimeType: nil,
                relativeFilePath: nil,
                createdAt: Date()
            )
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = try await loadString(from: provider, typeIdentifier: UTType.plainText.identifier) {
            return SharedImportItem(
                id: UUID().uuidString,
                kind: .text,
                text: text,
                fileName: nil,
                mimeType: nil,
                relativeFilePath: nil,
                createdAt: Date()
            )
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier),
           let file = try await copyFile(from: provider, typeIdentifier: UTType.pdf.identifier, preferredExtension: "pdf") {
            return SharedImportItem(
                id: UUID().uuidString,
                kind: .pdf,
                text: nil,
                fileName: file.fileName,
                mimeType: "application/pdf",
                relativeFilePath: file.relativePath,
                createdAt: Date()
            )
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let file = try await copyFile(from: provider, typeIdentifier: UTType.image.identifier, preferredExtension: "jpg") {
            return SharedImportItem(
                id: UUID().uuidString,
                kind: .image,
                text: nil,
                fileName: file.fileName,
                mimeType: file.mimeType ?? "image/jpeg",
                relativeFilePath: file.relativePath,
                createdAt: Date()
            )
        }

        return nil
    }

    private func loadURL(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let text = item as? String {
                    continuation.resume(returning: URL(string: text))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadString(from provider: NSItemProvider, typeIdentifier: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func copyFile(from provider: NSItemProvider, typeIdentifier: String, preferredExtension: String) async throws -> (relativePath: String, fileName: String, mimeType: String?)? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                do {
                    if let error { throw error }
                    guard let url else { continuation.resume(returning: nil); return }

                    let directory = try SharedImportStore.sharedFilesDirectory()
                    let sourceName = url.lastPathComponent.isEmpty ? "shared.\(preferredExtension)" : url.lastPathComponent
                    let fileName = "\(UUID().uuidString)-\(sourceName)"
                    let destination = directory.appendingPathComponent(fileName)
                    try FileManager.default.copyItem(at: url, to: destination)
                    continuation.resume(returning: ("SharedImports/\(fileName)", sourceName, UTType(filenameExtension: preferredExtension)?.preferredMIMEType))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum ShareImportError: LocalizedError {
    case noInput
    case unsupported
    case cancelled
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noInput:
            return "没有找到分享内容"
        case .unsupported:
            return "暂不支持这个内容"
        case .cancelled:
            return "已取消"
        case .saveFailed:
            return "服务器保存失败"
        }
    }
}

private enum ShareExtensionBackend {
    private static var baseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String ?? "http://192.168.3.17:3000"
    }

    @discardableResult
    static func submit(item: SharedImportItem) async throws -> String {
        switch item.kind {
        case .url:
            guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                throw ShareImportError.unsupported
            }
            if isBilibiliInput(text) {
                return try await postJSON(path: "/video-learning/submit", body: ["url": text])
            }
            return try await postJSON(path: "/video-learning/submit-webpage", body: ["url": text])

        case .text:
            guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                throw ShareImportError.unsupported
            }
            if let url = firstURL(in: text) {
                if isBilibiliInput(url) {
                    return try await postJSON(path: "/video-learning/submit", body: ["url": url])
                }
                return try await postJSON(path: "/video-learning/submit-webpage", body: ["url": url])
            }
            return try await postJSON(path: "/video-learning/submit-text", body: ["text": text])

        case .image, .pdf, .file:
            guard let fileURL = await fileURL(for: item) else {
                throw ShareImportError.unsupported
            }
            let data = try Data(contentsOf: fileURL)
            let contentType = item.kind == .pdf ? "pdf" : "image"
            let mimeType = item.mimeType ?? (item.kind == .pdf ? "application/pdf" : "image/jpeg")
            return try await upload(data: data, fileName: item.fileName ?? fileURL.lastPathComponent, mimeType: mimeType, contentType: contentType)
        }
    }

    private static func postJSON(path: String, body: [String: String]) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(VideoSubmitResponse.self, from: data).videoId
    }

    private static func upload(data: Data, fileName: String, mimeType: String, contentType: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: baseURL + "/video-learning/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fields: ["contentType": contentType],
            fileField: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: data
        )

        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(VideoSubmitResponse.self, from: responseData).videoId
    }

    private static func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ShareImportError.saveFailed
        }
    }

    private static func multipartBody(
        boundary: String,
        fields: [String: String],
        fileField: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var data = Data()
        for (key, value) in fields {
            data.appendString("--\(boundary)\r\n")
            data.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            data.appendString("\(value)\r\n")
        }
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        data.appendString("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.appendString("\r\n")
        data.appendString("--\(boundary)--\r\n")
        return data
    }

    @MainActor
    private static func fileURL(for item: SharedImportItem) -> URL? {
        guard let relativeFilePath = item.relativeFilePath,
              let containerURL = SharedImportStore.containerURL() else { return nil }
        return containerURL.appendingPathComponent(relativeFilePath)
    }

    private static func firstURL(in text: String) -> String? {
        text.range(of: #"https?://\S+"#, options: .regularExpression)
            .map { String(text[$0]).trimmingCharacters(in: CharacterSet(charactersIn: "，。；、）)】]\n\t ")) }
    }

    private static func isBilibiliInput(_ input: String) -> Bool {
        input.localizedCaseInsensitiveContains("bilibili")
            || input.localizedCaseInsensitiveContains("b23.tv")
            || input.localizedCaseInsensitiveContains("BV")
    }
}

private struct VideoSubmitResponse: Decodable {
    let videoId: String
    let status: String
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
