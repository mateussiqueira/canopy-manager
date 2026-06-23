import SwiftUI

struct ModelManagementView: View {
  @EnvironmentObject var state: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Modelos MLX", systemImage: "square.stack.3d.up.fill")
          .font(.headline)
        Spacer()
        if state.isScanningModels {
          ProgressView().scaleEffect(0.7).padding(.trailing, 4)
        }
        Text("\(MLXModel.available.count) disponíveis")
          .font(.caption).foregroundStyle(.secondary)
      }

      List {
        ForEach(MLXModel.ModelCategory.allCases, id: \.self) { cat in
          let models = MLXModel.available.filter { $0.category == cat }
          if !models.isEmpty {
            Section {
              ForEach(models) { model in
                ModelRow(
                  model: model,
                  size: state.modelSizes[model.folderName] ?? "-",
                  isSelected: state.selectedModelId == model.id,
                  isDownloaded: MLXService.checkModelExists(modelId: model.id, mlxDir: state.settingsMlxDir),
                  onSelect: { state.selectedModelId = model.id },
                  onDownload: { Task { await state.downloadModel(model.id) } }
                )
              }
            } header: {
              Label(cat.rawValue, systemImage: cat.icon)
                .foregroundStyle(categoryColor(cat))
            }
          }
        }
      }
    }
    .onAppear { Task { await state.scanModels() } }
  }

  func categoryColor(_ cat: MLXModel.ModelCategory) -> Color {
    switch cat {
    case .fast: .green
    case .general: .blue
    case .code: .orange
    case .vision: .purple
    case .reasoning: .yellow
    case .tiny: .mint
    }
  }
}

struct ModelRow: View {
  let model: MLXModel
  let size: String
  let isSelected: Bool
  let isDownloaded: Bool
  let onSelect: () -> Void
  let onDownload: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: model.category.icon)
        .foregroundStyle(categoryColor)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(model.name).fontWeight(.medium)
        Text(model.description).font(.caption).foregroundStyle(.secondary)
      }

      Spacer()

      if !isDownloaded {
        Button("Baixar", action: onDownload)
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .tint(.blue)
      }

      Text(size)
        .font(.caption).monospaced()
        .foregroundStyle(.secondary)
        .frame(width: 60, alignment: .trailing)

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { onSelect() }
    .padding(.vertical, 2)
  }

  var categoryColor: Color {
    switch model.category {
    case .fast: .green
    case .general: .blue
    case .code: .orange
    case .vision: .purple
    case .reasoning: .yellow
    case .tiny: .mint
    }
  }
}


