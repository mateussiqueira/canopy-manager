import SwiftUI

struct StatusDashboard: View {
  @EnvironmentObject var state: AppState

  var body: some View {
    VStack(spacing: 16) {
      // Status Card
      HStack(spacing: 20) {
        StatusBadge(
          icon: "server.rack",
          label: "MLX Server",
          value: state.isServerRunning ? "Online" : "Offline",
          color: state.isServerRunning ? .green : .red
        )
        StatusBadge(
          icon: "cpu",
          label: "Modelo Ativo",
          value: state.selectedModel?.name ?? "-",
          color: .blue
        )
        StatusBadge(
          icon: "memorychip",
          label: "Porta",
          value: state.settingsPort,
          color: .secondary
        )
        StatusBadge(
          icon: "terminal",
          label: "Canopy CLI",
          value: MLXService.checkCanopyInstalled() ? "Instalado" : "Ausente",
          color: MLXService.checkCanopyInstalled() ? .green : .orange
        )
      }

      // Quick actions
      HStack(spacing: 12) {
        Button(action: { Task { await state.toggleServer() } }) {
          Label(
            state.isServerRunning ? "Parar Servidor" : "Iniciar Servidor",
            systemImage: state.isServerRunning ? "stop.fill" : "play.fill"
          )
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(state.isServerRunning ? .red : .green)
        .disabled(state.isProcessing)

        Button(action: { Task { await state.scanModels() } }) {
          Label("Escaneear Modelos", systemImage: "arrow.clockwise")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button(action: { state.showDownloadPanel = true }) {
          Label("Baixar Modelo", systemImage: "icloud.and.arrow.down")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(state.isDownloading)

        Button(action: state.openCanopy) {
          Label("Abrir Canopy", systemImage: "terminal")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!MLXService.checkCanopyInstalled())
      }
    }
  }
}

struct StatusBadge: View {
  let icon: String
  let label: String
  let value: String
  let color: Color

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon).foregroundStyle(color)
      VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.caption2).foregroundStyle(.secondary)
        Text(value).font(.callout).fontWeight(.medium)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.textBackgroundColor))
    .cornerRadius(10)
  }
}
