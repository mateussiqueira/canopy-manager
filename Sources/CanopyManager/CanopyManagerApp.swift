import SwiftUI

@main
struct CanopyManagerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Window("Canopy Manager", id: "main") {
      ContentView()
        .onAppear {
          NSApp.setActivationPolicy(.regular)
        }
    }
    .windowResizability(.contentMinSize)
    .windowToolbarStyle(.unified)
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button("Sobre Canopy Manager") {
          NSApp.orderFrontStandardAboutPanel(
            options: [
              .applicationName: "Canopy Manager",
              .applicationVersion: "2.0.0",
              .credits: NSAttributedString(
                string: "Gerenciamento local de modelos MLX para Apple Silicon.\nParte do ecossistema Canopy.",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
              )
            ]
          )
        }
      }
      CommandMenu("Servidor") {
        Button("Iniciar/Parar") {
          NotificationCenter.default.post(name: .toggleServer, object: nil)
        }
        .keyboardShortcut(".", modifiers: .command)

        Button("Escaneear Modelos") {
          NotificationCenter.default.post(name: .scanModels, object: nil)
        }
        .keyboardShortcut("r", modifiers: .command)
      }
    }
  }
}

extension Notification.Name {
  static let toggleServer = Notification.Name("toggleServer")
  static let scanModels = Notification.Name("scanModels")
}

class AppDelegate: NSObject, NSApplicationDelegate {
  private var menuBarItem: NSStatusItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Wait for content view to exist then observe
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.setupMenuBar()
    }
  }

  func setupMenuBar() {
    menuBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    guard let button = menuBarItem?.button else { return }

    let image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Canopy Manager")
    image?.isTemplate = true
    button.image = image

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Abrir Canopy Manager", action: #selector(openApp), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())

    let statusItem = NSMenuItem(title: "Servidor: Verificando...", action: nil, keyEquivalent: "")
    statusItem.isEnabled = false
    menu.addItem(statusItem)

    menu.addItem(NSMenuItem(title: "Iniciar/Parar Servidor", action: #selector(toggleServer), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())

    let modelsMenu = NSMenuItem(title: "Selecionar Modelo", action: nil, keyEquivalent: "")
    let modelsSub = NSMenu()
    for model in MLXModel.available {
      let item = NSMenuItem(title: model.name, action: #selector(selectModel(_:)), keyEquivalent: "")
      item.representedObject = model.id
      modelsSub.addItem(item)
    }
    modelsMenu.submenu = modelsSub
    menu.addItem(modelsMenu)

    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Sair", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

    menuBarItem?.menu = menu
  }

  @objc func openApp() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first {
      window.makeKeyAndOrderFront(nil)
    }
  }

  @objc func toggleServer() {
    NotificationCenter.default.post(name: .toggleServer, object: nil)
  }

  @objc func selectModel(_ sender: NSMenuItem) {
    if let id = sender.representedObject as? String {
      UserDefaults.standard.set(id, forKey: "selectedModel")
      NotificationCenter.default.post(name: .toggleServer, object: nil)
    }
  }
}
