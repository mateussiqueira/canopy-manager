import SwiftUI

struct QuickPromptView: View {
  @EnvironmentObject var state: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Prompt Rápido", systemImage: "text.bubble.fill")
          .font(.headline)
        Spacer()

        if !state.detectedModel.isEmpty {
          HStack(spacing: 4) {
            Image(systemName: "cpu").font(.caption2)
            Text(state.detectedModel)
              .font(.caption).fontWeight(.medium)
          }
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(Color.accentColor.opacity(0.12))
          .cornerRadius(6)
        }
      }

      HStack(alignment: .bottom, spacing: 8) {
        TextField(
          "Ex: refatore essa classe, implemente uma API, explique esse erro...",
          text: $state.promptText,
          axis: .vertical
        )
        .textFieldStyle(.plain)
        .padding(10)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .lineLimit(4)

        Button(action: { Task { await state.processPrompt() } }) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title2)
        }
        .buttonStyle(.plain)
        .disabled(state.promptText.trimmingCharacters(in: .whitespaces).isEmpty || state.isProcessing)
        .foregroundStyle(state.isProcessing || state.promptText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.accentColor)
      }

      if state.isProcessing {
        HStack(spacing: 8) {
          ProgressView().scaleEffect(0.8)
          Text("Processando...").font(.caption).foregroundStyle(.secondary)
        }
      }

      if !state.promptOutput.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Label("Resposta", systemImage: "checkmark.circle")
              .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Copiar") {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(state.promptOutput, forType: .string)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
          }

          ScrollView {
            Text(state.promptOutput)
              .font(.caption).monospaced()
              .frame(maxWidth: .infinity, alignment: .leading)
              .textSelection(.enabled)
          }
          .frame(maxHeight: 250)
          .padding(8)
          .background(Color(.textBackgroundColor))
          .cornerRadius(8)
        }
      }
    }
  }
}


