import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var state: AppState
  @Environment(\.dismiss) var dismiss

  var body: some View {
    TabView {
      Form {
        Section("Servidor MLX") {
          HStack {
            Text("Porta:")
            TextField("8080", text: $state.settingsPort)
              .frame(width: 80)
              .monospaced()
          }
          HStack {
            Text("Diretório MLX:")
            TextField("/Volumes/BACKUP/mlx", text: $state.settingsMlxDir)
              .monospaced()
          }
        }

        Section("Canopy") {
          HStack {
            Text("CLI:")
            Text("~/.local/bin/canopy")
              .monospaced().foregroundStyle(.secondary)
          }
          HStack {
            Text("Auto-select:")
            Text("~/.local/bin/canopy-auto")
              .monospaced().foregroundStyle(.secondary)
          }
        }

        Section("Modelos") {
          Text("Armazenamento: \(state.settingsMlxDir)/models/")
            .font(.caption).foregroundStyle(.secondary)
          Text("\(MLXModel.available.count) modelos disponíveis")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .tabItem { Label("Geral", systemImage: "gearshape") }

      Form {
        Section("Informações do Sistema") {
          LabeledContent("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
          LabeledContent("Arquitetura", value: "Apple Silicon")
          LabeledContent("RAM", value: "\(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) GB")
          LabeledContent("MLX Instalado", value: MLXService.checkMlxInstalled(mlxDir: state.settingsMlxDir) ? "Sim" : "Não")
          LabeledContent("Canopy Instalado", value: MLXService.checkCanopyInstalled() ? "Sim" : "Não")
          LabeledContent("Modelos no SSD", value: "\(state.modelSizes.count)")
        }
      }
      .tabItem { Label("Sistema", systemImage: "info.circle") }
    }
    .frame(width: 450, height: 300)
    .onDisappear { state.save() }
  }
}
