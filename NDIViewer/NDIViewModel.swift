import AppKit
import Foundation

struct NDISource: Identifiable, Hashable {
    let id: String
    let name: String
}

@MainActor
final class NDIViewModel: ObservableObject {
    @Published var sources: [NDISource] = []
    @Published var selectedSourceID: String?
    @Published var currentFrame: CGImage?
    @Published var statusText = "Initializing NDI..."
    @Published var isConnected = false
    @Published var isRefreshing = false
    @Published var showingError = false
    @Published var errorMessage = ""

    private let client = NDIClient()
    private var refreshTask: Task<Void, Never>?

    init() {
        client.onVideoFrame = { [weak self] image in
            self?.currentFrame = image
        }
        client.onStatus = { [weak self] status in
            self?.statusText = status
        }
        client.onError = { [weak self] message in
            guard let self else { return }
            self.errorMessage = message
            self.showingError = true
            self.statusText = "Error"
        }
    }

    func start() {
        guard client.initialize() else {
            showError(client.lastError ?? "Could not initialize the NDI runtime.")
            return
        }
        statusText = "Searching for NDI sources..."
        refreshSources()
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.refreshSources(showSpinner: false)
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        disconnect()
        client.shutdown()
    }

    func refreshSources(showSpinner: Bool = true) {
        if showSpinner { isRefreshing = true }
        client.discoverSources { [weak self] names in
            Task { @MainActor in
                guard let self else { return }
                let previousSelection = self.selectedSourceID
                self.sources = names.map { NDISource(id: $0, name: $0) }
                if let previousSelection, self.sources.contains(where: { $0.id == previousSelection }) {
                    self.selectedSourceID = previousSelection
                }
                self.isRefreshing = false
                if !self.isConnected {
                    self.statusText = names.isEmpty ? "No NDI sources found" : "\(names.count) source\(names.count == 1 ? "" : "s") found"
                }
            }
        }
    }

    func connectSelectedSource() {
        guard let selectedSourceID else { return }
        currentFrame = nil
        if client.connect(toSourceNamed: selectedSourceID) {
            isConnected = true
            statusText = "Connecting to \(selectedSourceID)..."
        } else {
            showError(client.lastError ?? "Unable to connect to the selected NDI source.")
        }
    }

    func disconnect() {
        client.disconnect()
        isConnected = false
        currentFrame = nil
        statusText = sources.isEmpty ? "No NDI sources found" : "Disconnected"
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        statusText = "Error"
    }
}
