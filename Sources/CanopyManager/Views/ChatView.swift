import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
  @EnvironmentObject var state: AppState
  @State private var messages: [ChatMessage] = []
  @State private var inputText = ""
  @State private var isStreaming = false
  @State private var streamingText = ""
  @State private var attachedImage: ChatMessage.Attachment?
  @State private var attachedAudio: ChatMessage.Attachment?
  @State private var isRecording = false
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      header
      messageList
      if attachedImage != nil || attachedAudio != nil { attachmentBar }
      inputBar
    }
    .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
      handleDrop(providers)
      return true
    }
  }

  // MARK: - Header
  var header: some View {
    HStack {
      Label("Chat Multimodal", systemImage: "message.fill").font(.headline)
      Spacer()
      if isStreaming {
        HStack(spacing: 4) {
          ProgressView().scaleEffect(0.6)
          Text("Streaming...").font(.caption).foregroundStyle(.secondary)
        }
      }
      if state.isServerRunning {
        Circle().fill(.green).frame(width: 6, height: 6)
      }
      Button("Limpar") { withAnimation { messages = []; streamingText = "" } }
        .buttonStyle(.borderless).controlSize(.small)
    }
    .padding(.horizontal, 16).padding(.vertical, 8).background(.ultraThinMaterial)
  }

  // MARK: - Messages
  var messageList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          if messages.isEmpty && !isStreaming { emptyState }
          ForEach(messages) { msg in MessageBubbleView(message: msg).id(msg.id) }
          if isStreaming {
            MessageBubbleView(
              message: ChatMessage(role: .assistant, content: streamingText, attachments: [], timestamp: Date(), modelUsed: state.selectedModel?.name, tokensUsed: nil),
              isStreaming: true
            ).id("streaming")
          }
        }
        .padding(.horizontal, 12)
      }
      .onChange(of: messages.count) { _, _ in
        withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
      }
      .onChange(of: streamingText) { _, _ in
        if isStreaming { proxy.scrollTo("streaming", anchor: .bottom) }
      }
    }
  }

  var emptyState: some View {
    VStack(spacing: 20) {
      Spacer().frame(height: 60)
      Image(systemName: "leaf.fill").font(.system(size: 50)).foregroundStyle(.green.opacity(0.3))
      Text("Canopy Chat").font(.title2).fontWeight(.semibold)
      Text("Modelo: \(state.selectedModel?.name ?? "Nenhum")").font(.subheadline).foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 8) {
        FeatureRow(icon: "photo", text: "Arraste imagens ou clique em 📷")
        FeatureRow(icon: "waveform", text: "Grave áudio ou anexe arquivos 🎤")
        FeatureRow(icon: "sparkle", text: "Modelo selecionado automaticamente")
      }.padding().background(Color(.textBackgroundColor)).cornerRadius(12)
    }.frame(maxWidth: .infinity)
  }

  // MARK: - Attachments
  var attachmentBar: some View {
    HStack(spacing: 8) {
      if let img = attachedImage { AttachmentChip(icon: "photo", label: img.filename, onRemove: { attachedImage = nil }) }
      if let audio = attachedAudio { AttachmentChip(icon: "waveform", label: audio.filename, onRemove: { attachedAudio = nil }) }
      Spacer()
    }
    .padding(.horizontal, 12).padding(.vertical, 6).background(Color(.textBackgroundColor).opacity(0.5))
  }

  // MARK: - Input
  var inputBar: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 8) {
        Button(action: pickImage) { Image(systemName: "photo").font(.title3) }.buttonStyle(.plain).help("Anexar imagem")
        Button(action: pickFile) { Image(systemName: "paperclip").font(.title3) }.buttonStyle(.plain).help("Anexar arquivo")
        Button(action: { Task { await toggleRecording() } }) {
          Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
            .font(.title3).foregroundStyle(isRecording ? .red : .primary)
        }.buttonStyle(.plain).help(isRecording ? "Parar" : "Gravar áudio")

        TextField("Digite sua mensagem...", text: $inputText, axis: .vertical)
          .textFieldStyle(.plain).focused($isFocused).lineLimit(5)
          .onSubmit { Task { await sendMessage() } }

        Button(action: { Task { await sendMessage() } }) {
          Image(systemName: "arrow.up.circle.fill").font(.system(size: 28))
            .foregroundStyle(canSend ? Color.accentColor : Color.gray.opacity(0.3))
        }.buttonStyle(.plain).disabled(!canSend)

        if let model = state.selectedModel {
          Text(model.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1).frame(maxWidth: 60)
        }
      }
      .padding(.horizontal, 12).padding(.vertical, 8)
    }
    .background(.ultraThinMaterial)
  }

  var canSend: Bool {
    (!inputText.trimmingCharacters(in: .whitespaces).isEmpty || attachedImage != nil) && !isStreaming && state.isServerRunning
  }

  // MARK: - Actions
  func sendMessage() async {
    guard canSend else {
      if !state.isServerRunning {
        state.errorMessage = "Servidor MLX não está rodando.\nInicie no painel Gerenciar."
        state.showError = true
      }
      return
    }

    let text = inputText.trimmingCharacters(in: .whitespaces)
    inputText = ""

    var finalText = text
    if let audio = attachedAudio {
      finalText = "[Áudio: \(audio.filename)] " + finalText
      attachedAudio = nil
    }

    let img = attachedImage
    attachedImage = nil

    var imageNote = ""
    if img != nil { imageNote = "\n\n[Imagem anexada: processando via modelo de visão...]" }

    let userMsg = ChatMessage(role: .user, content: finalText + imageNote, attachments: img.map { [$0] } ?? [], timestamp: Date(), modelUsed: nil, tokensUsed: nil)
    withAnimation { messages.append(userMsg) }

    isStreaming = true
    streamingText = ""
    let history = messages.dropLast().map { ["role": $0.role.rawValue, "content": $0.content] }

    let result = await MLXChatService.streamMessage(text: finalText, history: history) { token in
      streamingText += token
    }

    isStreaming = false

    switch result {
    case .success:
      let msg = ChatMessage(role: .assistant, content: streamingText, attachments: [], timestamp: Date(), modelUsed: state.selectedModel?.name, tokensUsed: nil)
      withAnimation { messages.append(msg) }
      streamingText = ""
    case .failure(let error):
      withAnimation { messages.append(ChatMessage(role: .system, content: "❌ \(error.localizedDescription)", attachments: [], timestamp: Date(), modelUsed: nil, tokensUsed: nil)) }
    }
  }

  func toggleRecording() async {
    isRecording = true
    let url = URL(fileURLWithPath: "/tmp/canopy_recording.m4a")
    _ = await WhisperService.recordAudio(to: url, duration: 30)
    if let attachment = ChatMessage.Attachment.audio(from: url) {
      attachedAudio = attachment
    }
    isRecording = false
  }

  func pickImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.begin { result in
      if result == .OK, let url = panel.url, let attachment = ChatMessage.Attachment.image(from: url) {
        attachedImage = attachment
      }
    }
  }

  func pickFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image, .audio, .plainText, .json, .pdf]
    panel.begin { result in
      if result == .OK, let url = panel.url {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext),
           let attachment = ChatMessage.Attachment.image(from: url) {
          attachedImage = attachment
        } else if ["m4a", "wav", "mp3", "aac"].contains(ext),
                  let attachment = ChatMessage.Attachment.audio(from: url) {
          attachedAudio = attachment
        }
      }
    }
  }

  func handleDrop(_ providers: [NSItemProvider]) {
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, _ in
          if let url = data as? URL, let attachment = ChatMessage.Attachment.image(from: url) {
            DispatchQueue.main.async { attachedImage = attachment }
          }
        }
      }
    }
  }
}

struct FeatureRow: View {
  let icon: String; let text: String
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon).frame(width: 20).foregroundStyle(.green)
      Text(text).font(.subheadline)
    }
  }
}

struct AttachmentChip: View {
  let icon: String; let label: String; let onRemove: () -> Void
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon).font(.caption2)
      Text(label).font(.caption)
      Button(action: onRemove) { Image(systemName: "xmark.circle.fill").font(.caption2) }.buttonStyle(.plain)
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
    .background(Color.accentColor.opacity(0.1)).cornerRadius(6)
  }
}
