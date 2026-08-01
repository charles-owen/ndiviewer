import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: NDIViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("NDI source", selection: $model.selectedSourceID) {
                    Text("Select a source...").tag(String?.none)
                    ForEach(model.sources) { source in
                        Text(source.name).tag(String?.some(source.id))
                    }
                }
                .frame(minWidth: 320)

                Button("Refresh") { model.refreshSources() }
                    .disabled(model.isRefreshing)

                Button(model.isConnected ? "Disconnect" : "Connect") {
                    model.isConnected ? model.disconnect() : model.connectSelectedSource()
                }
                .disabled(!model.isConnected && model.selectedSourceID == nil)

                Spacer()

                if model.isConnected {
                    Label(model.statusText, systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.statusText)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.bar)

            ZStack {
                Color.black

                if let image = model.currentFrame {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 48))
                        Text(model.isConnected ? "Waiting for video..." : "Choose an NDI source and connect")
                    }
                    .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .alert("NDI Viewer", isPresented: $model.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.errorMessage)
        }
    }
}
