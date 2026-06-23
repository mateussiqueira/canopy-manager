import SwiftUI

struct DownloadPanelView: View {
  @EnvironmentObject var state: AppState

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "icloud.and.arrow.down")
        .font(.system(size: 40))
        .foregroundStyle(.blue)

      Text("Baixando Modelo")
        .font(.title3).fontWeight(.semibold)

      Text(state.downloadStatus)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      if state.isDownloading {
        ProgressView(value: state.downloadProgress) {
          Text("\(Int(state.downloadProgress * 100))%")
            .font(.caption).foregroundStyle(.secondary)
        }
        .progressViewStyle(.linear)
        .frame(width: 250)
      }

      if !state.isDownloading {
        Button("Fechar") {
          state.showDownloadPanel = false
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(30)
    .frame(width: 350)
  }
}
