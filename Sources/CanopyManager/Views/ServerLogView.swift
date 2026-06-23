import SwiftUI

struct ServerLogView: View {
  @EnvironmentObject var state: AppState
  @State private var autoScroll = true

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Log do Servidor", systemImage: "text.alignleft")
          .font(.headline)
        Spacer()
        Toggle("Auto-scroll", isOn: $autoScroll)
          .toggleStyle(.switch)
          .controlSize(.small)
        Button("Limpar") {
          state.serverLog = ""
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
      }

      ScrollViewReader { proxy in
        ScrollView {
          Text(state.serverLog)
            .font(.caption).monospaced()
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .id("log-bottom")
        }
        .frame(maxHeight: .infinity)
        .padding(8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .onChange(of: state.serverLog) { _, _ in
          if autoScroll {
            withAnimation { proxy.scrollTo("log-bottom", anchor: .bottom) }
          }
        }
      }
    }
  }
}
