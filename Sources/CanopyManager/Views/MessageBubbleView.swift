import SwiftUI

struct MessageBubbleView: View {
  let message: ChatMessage
  var isStreaming: Bool = false

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: message.role.icon)
        .font(.title3).foregroundStyle(message.role.color)
        .frame(width: 28, height: 28)
        .background(message.role.color.opacity(0.1)).clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(message.role == .user ? "Você" : "Canopy").font(.caption).fontWeight(.semibold)
          if let model = message.modelUsed, message.role == .assistant {
            Text(model).font(.caption2).foregroundStyle(.secondary)
              .padding(.horizontal, 4).padding(.vertical, 1)
              .background(Color.green.opacity(0.1)).cornerRadius(3)
          }
          Spacer()
          Text(message.timestamp, style: .time).font(.caption2).foregroundStyle(.tertiary)
        }

        if !message.attachments.isEmpty {
          LazyVGrid(columns: [.init(.adaptive(minimum: 120))], spacing: 4) {
            ForEach(message.attachments) { attachment in
              switch attachment.type {
              case .image:
                if let nsImage = NSImage(data: attachment.data) {
                  Image(nsImage: nsImage).resizable().scaledToFit()
                    .frame(maxHeight: 150).cornerRadius(8)
                }
              case .audio:
                Label(attachment.filename, systemImage: "waveform")
                  .font(.caption).padding(6).background(Color(.textBackgroundColor)).cornerRadius(6)
              case .file, .code:
                Label(attachment.filename, systemImage: attachment.type.icon)
                  .font(.caption).padding(6).background(Color(.textBackgroundColor)).cornerRadius(6)
              }
            }
          }
        }

        if message.role == .assistant || isStreaming {
          ChatMarkdown(text: message.content, isStreaming: isStreaming)
        } else {
          Text(message.content).font(.body).textSelection(.enabled)
        }
      }
      .padding(12).background(bubbleColor).cornerRadius(12)
    }
    .padding(.vertical, 4)
  }

  var bubbleColor: Color {
    switch message.role {
    case .user: Color.accentColor.opacity(0.08)
    case .assistant: Color(.textBackgroundColor)
    case .system: Color.orange.opacity(0.06)
    }
  }
}

// MARK: - Markdown Rendered
struct ChatMarkdown: View {
  let text: String
  var isStreaming: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(blocks.indices, id: \.self) { i in
        if blocks[i].isCode {
          ScrollView(.horizontal, showsIndicators: false) {
            Text(blocks[i].content)
              .font(.system(.caption, design: .monospaced))
              .padding(8).frame(maxWidth: .infinity, alignment: .leading)
          }
          .background(Color(.textBackgroundColor)).cornerRadius(6)
        } else {
          Text(blocks[i].content)
            .font(.body).textSelection(.enabled)
        }
      }
    }
  }

  var blocks: [Block] {
    var result: [Block] = []
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var i = 0
    while i < lines.count {
      if lines[i].hasPrefix("```") {
        i += 1
        var code: [String] = []
        while i < lines.count, !lines[i].hasPrefix("```") { code.append(lines[i]); i += 1 }
        i += 1
        result.append(Block(content: code.joined(separator: "\n"), isCode: true))
      } else {
        result.append(Block(content: lines[i], isCode: false))
        i += 1
      }
    }
    return result
  }

  struct Block { let content: String; let isCode: Bool }
}
