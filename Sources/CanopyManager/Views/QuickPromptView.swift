import SwiftUI

struct QuickPromptView: View {
  @Binding var selectedModel: String
  @Binding var isRunning: Bool
  @State private var prompt = ""
  @State private var output = ""
  @State private var isProcessing = false
  @State private var detectedModel = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Prompt Rápido").font(.headline)
      Text("O modelo será selecionado automaticamente baseado na tarefa")
        .font(.caption).foregroundStyle(.secondary)

      HStack {
        TextField("Digite seu prompt...", text: $prompt, axis: .vertical)
          .textFieldStyle(.roundedBorder)
          .lineLimit(3)

        Button("Enviar") { Task { await processPrompt() } }
          .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing || !isRunning)
          .buttonStyle(.borderedProminent)
      }

      if !detectedModel.isEmpty {
        HStack {
          Image(systemName: "cpu")
          Text("Modelo selecionado: \(detectedModel)")
            .font(.caption).foregroundStyle(.secondary)
        }
      }

      if isProcessing {
        HStack {
          ProgressView().scaleEffect(0.8)
          Text("Processando...").font(.caption).foregroundStyle(.secondary)
        }
      }

      if !output.isEmpty {
        ScrollView {
          Text(output)
            .font(.caption).monospaced()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
        .padding(8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
      }
    }
  }

  func processPrompt() async {
    isProcessing = true
    output = ""
    detectedModel = ""

    let text = prompt.trimmingCharacters(in: .whitespaces)
    let escaped = text.replacingOccurrences(of: "'", with: "'\\''")

    detectedModel = await ShellService.shell("""
      \(ShellService.canopyAuto) --dry-run '\(escaped)' 2>&1 | grep 'Modelo selecionado' | sed 's/.*: //'
      """)

    output = await ShellService.shell("""
      \(ShellService.canopyAuto) '\(escaped)' 2>&1 | tail -15
      """)

    isProcessing = false
  }
}
