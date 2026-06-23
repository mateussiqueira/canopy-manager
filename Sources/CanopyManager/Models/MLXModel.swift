import Foundation

struct MLXModel: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let sizeGB: Double
  let category: ModelCategory
  let description: String

  enum ModelCategory: String, Codable, CaseIterable {
    case fast = "Rápido"
    case general = "Geral"
    case code = "Código"
    case vision = "Visão"

    var icon: String {
      switch self {
      case .fast: "bolt.fill"
      case .general: "brain"
      case .code: "chevron.left.forwardslash.chevron.right"
      case .vision: "eye"
      }
    }
  }

  var folderName: String {
    switch id {
    case "mistral-7b": "Mistral-7B-Instruct-v0.3-4bit"
    case "llama-3.1-8b": "Meta-Llama-3.1-8B-Instruct-4bit"
    case "qwen2.5-7b": "Qwen2.5-7B-Instruct-4bit"
    case "qwen2.5-coder-14b": "Qwen2.5-Coder-14B-Instruct-4bit"
    case "deepseek-coder-v2": "DeepSeek-Coder-V2-Lite-Instruct-4bit"
    case "qwen2.5-vl-7b": "Qwen2.5-VL-7B-Instruct-4bit"
    default: id
    }
  }

  static let available: [MLXModel] = [
    MLXModel(id: "mistral-7b", name: "Mistral 7B", sizeGB: 3.8, category: .fast, description: "Respostas rápidas, perguntas simples"),
    MLXModel(id: "llama-3.1-8b", name: "Llama 3.1 8B", sizeGB: 4.2, category: .general, description: "Conversas gerais, raciocínio"),
    MLXModel(id: "qwen2.5-7b", name: "Qwen 2.5 7B", sizeGB: 4.0, category: .general, description: "Tarefas gerais"),
    MLXModel(id: "qwen2.5-coder-14b", name: "Qwen 2.5 Coder 14B", sizeGB: 7.7, category: .code, description: "Código, refatoração, debugging"),
    MLXModel(id: "deepseek-coder-v2", name: "DeepSeek Coder V2 16B", sizeGB: 8.2, category: .code, description: "Código complexo, arquitetura"),
    MLXModel(id: "qwen2.5-vl-7b", name: "Qwen 2.5 VL 7B", sizeGB: 5.0, category: .vision, description: "Visão/multimodal"),
  ]

  static func byId(_ id: String) -> MLXModel? { available.first(where: { $0.id == id }) }
}
