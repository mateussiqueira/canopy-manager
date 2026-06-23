import SwiftUI
import UniformTypeIdentifiers

struct ChatMessage: Identifiable {
  let id = UUID()
  let role: Role
  let content: String
  let attachments: [Attachment]
  let timestamp: Date
  let modelUsed: String?
  let tokensUsed: Int?

  enum Role: String, Codable {
    case user, assistant, system
    var icon: String {
      switch self {
      case .user: "person.circle.fill"
      case .assistant: "leaf.fill"
      case .system: "gearshape.2.fill"
      }
    }
    var color: Color {
      switch self {
      case .user: .accentColor
      case .assistant: .green
      case .system: .secondary
      }
    }
  }

  struct Attachment: Identifiable, Equatable {
    let id = UUID()
    let type: AttachmentType
    let data: Data
    let filename: String

    enum AttachmentType: String, Codable {
      case image, audio, file, code
      var icon: String {
        ["image": "photo", "audio": "waveform", "file": "doc", "code": "chevron.left.forwardslash.chevron.right"][rawValue] ?? "doc"
      }
    }

    static func image(from url: URL) -> Attachment? {
      guard let data = try? Data(contentsOf: url) else { return nil }
      return Attachment(type: .image, data: data, filename: url.lastPathComponent)
    }

    static func audio(from url: URL) -> Attachment? {
      guard let data = try? Data(contentsOf: url) else { return nil }
      return Attachment(type: .audio, data: data, filename: url.lastPathComponent)
    }
  }
}

// MARK: - Conversation History
struct Conversation: Identifiable, Codable {
  let id = UUID()
  var title: String
  var messages: [CodableMessage]
  var createdAt: Date
  var updatedAt: Date
  var modelUsed: String

  struct CodableMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date
  }
}
