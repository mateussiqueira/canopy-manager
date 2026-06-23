import Foundation

struct MLXChatService {
  static var baseURL: String {
    let port = UserDefaults.standard.string(forKey: "serverPort") ?? "8080"
    return "http://localhost:\(port)/v1"
  }

  static func sendMessage(text: String, history: [[String: String]] = []) async -> Result<ChatResponse, ChatError> {
    var messages = history
    messages.append(["role": "user", "content": text])

    let body: [String: Any] = [
      "model": "default_model",
      "messages": messages,
      "max_tokens": 4096,
      "temperature": 0.7,
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
          let url = URL(string: "\(baseURL)/chat/completions") else {
      return .failure(.invalidRequest)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    request.timeoutInterval = 300

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        return .failure(.networkError("Resposta inválida"))
      }
      guard httpResponse.statusCode == 200 else {
        let body = String(data: data, encoding: .utf8) ?? ""
        return .failure(.serverError(httpResponse.statusCode, body))
      }
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String else {
        return .failure(.parseError("Formato de resposta inesperado"))
      }
      let usage = json["usage"] as? [String: Any]
      return .success(ChatResponse(
        content: content,
        model: json["model"] as? String ?? "default_model",
        tokens: usage?["total_tokens"] as? Int ?? 0,
        finishReason: first["finish_reason"] as? String
      ))
    } catch let error as URLError where error.code == .timedOut {
      return .failure(.timeout)
    } catch {
      return .failure(.networkError(error.localizedDescription))
    }
  }

  static func streamMessage(text: String, history: [[String: String]] = [], onToken: @escaping (String) -> Void) async -> Result<Void, ChatError> {
    var messages = history
    messages.append(["role": "user", "content": text])

    let body: [String: Any] = [
      "model": "default_model",
      "messages": messages,
      "max_tokens": 4096,
      "temperature": 0.7,
      "stream": true,
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
          let url = URL(string: "\(baseURL)/chat/completions") else {
      return .failure(.invalidRequest)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    request.timeoutInterval = 300

    do {
      let (bytes, response) = try await URLSession.shared.bytes(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        return .failure(.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, ""))
      }

      for try await line in bytes.lines {
        let str = line
        guard str.hasPrefix("data: ") else { continue }
        let jsonStr = String(str.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        guard !jsonStr.isEmpty, jsonStr != "[DONE]" else { continue }

        if let jsonData = jsonStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any],
           let token = delta["content"] as? String {
          await MainActor.run { onToken(token) }
        }
      }
      return .success(())
    } catch {
      return .failure(.networkError(error.localizedDescription))
    }
  }

  static func checkServerRunning() async -> Bool {
    guard let url = URL(string: "\(baseURL)/models") else { return false }
    var request = URLRequest(url: url)
    request.timeoutInterval = 5
    return (try? await URLSession.shared.data(for: request)).map { _ in true } ?? false
  }
}
