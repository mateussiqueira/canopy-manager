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
    case reasoning = "Raciocínio"
    case tiny = "Leve"

    var icon: String {
      switch self {
      case .fast: "bolt.fill"
      case .general: "brain"
      case .code: "chevron.left.forwardslash.chevron.right"
      case .vision: "eye"
      case .reasoning: "lightbulb.max.fill"
      case .tiny: "leaf"
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
    case "llama-3.2-3b": "Llama-3.2-3B-Instruct-4bit"
    case "deepseek-r1-7b": "DeepSeek-R1-Distill-Qwen-7B-4bit"
    case "gemma-2-9b": "Gemma-2-9B-IT-4bit"
    case "qwen2.5-14b": "Qwen2.5-14B-Instruct-4bit"
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
    MLXModel(id: "llama-3.2-3b", name: "Llama 3.2 3B", sizeGB: 1.7, category: .tiny, description: "Sempre ligado, respostas instantâneas"),
    MLXModel(id: "deepseek-r1-7b", name: "DeepSeek R1 7B", sizeGB: 4.0, category: .reasoning, description: "Raciocínio profundo, chain-of-thought"),
    MLXModel(id: "gemma-2-9b", name: "Gemma 2 9B", sizeGB: 4.9, category: .general, description: "Google, alternativa aos atuais"),
    MLXModel(id: "qwen2.5-14b", name: "Qwen 2.5 14B", sizeGB: 4.4, category: .general, description: "Alta qualidade geral"),
  ]

  static func byId(_ id: String) -> MLXModel? { available.first(where: { $0.id == id }) }
}
