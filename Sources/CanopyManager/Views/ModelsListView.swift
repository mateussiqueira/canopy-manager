import SwiftUI

struct ModelsListView: View {
  @State private var modelSizes: [(String, String)] = []
  @State private var isLoading = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Modelos MLX").font(.headline)

      if isLoading {
        ProgressView().frame(maxWidth: .infinity).padding()
      }

      List {
        ForEach(MLXModel.available) { model in
          HStack(spacing: 12) {
            Image(systemName: model.category.icon)
              .foregroundStyle(categoryColor(model.category))
              .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
              Text(model.name).fontWeight(.medium)
              Text(model.description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(sizeString(for: model.folderName))
              .font(.caption).foregroundStyle(.secondary)
              .monospaced()

            Text(model.category.rawValue)
              .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
              .background(categoryColor(model.category).opacity(0.15))
              .cornerRadius(4)
          }
          .padding(.vertical, 2)
        }
      }
    }
    .onAppear { Task { await loadSizes() } }
  }

  func loadSizes() async {
    modelSizes = await ShellService.modelSizes()
    isLoading = false
  }

  func sizeString(for folder: String) -> String {
    modelSizes.first(where: { $0.0 == folder })?.1 ?? "-"
  }

  func categoryColor(_ cat: MLXModel.ModelCategory) -> Color {
    switch cat {
    case .fast: .green
    case .general: .blue
    case .code: .orange
    case .vision: .purple
    }
  }
}
