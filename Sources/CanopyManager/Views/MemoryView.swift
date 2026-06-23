import SwiftUI

struct MemoryView: View {
  @EnvironmentObject var state: AppState
  @State private var stats = SystemStats()
  @State private var isRefreshing = false
  @State private var isMoving = false
  @State private var moveLog = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        cardsGrid
        Divider()
        cacheSection
        Divider()
        swapSection
        if !moveLog.isEmpty { logSection }
      }
      .padding(16)
    }
    .onAppear { Task { await refresh() } }
  }

  // MARK: - System Stats

  struct SystemStats {
    var ramTotal: Double = 0; var ramUsed: Double = 0; var ramPercent: Double = 0
    var swapTotal: Double = 0; var swapUsed: Double = 0; var swapPercent: Double = 0
    var internalFree: Double = 0; var internalTotal: Double = 0
    var thunderboltFree: Double?; var thunderboltTotal: Double?
    var memoryPressure: String = "—"
    var appCaches: [(name: String, size: String, path: String)] = []
    var swapOnSSD: Bool = false
  }

  func refresh() async {
    isRefreshing = true
    stats = await gatherStats()
    isRefreshing = false
  }

  func gatherStats() async -> SystemStats {
    var s = SystemStats()

    // RAM via sysctl + vm_stat
    if case .success(let out) = await MLXService.shell("sysctl hw.memsize 2>/dev/null | awk '{print $2}'", timeout: 5) {
      s.ramTotal = (Double(out.trimmingCharacters(in: .whitespaces)) ?? 0) / 1_073_741_824
    }
    if case .success(let out) = await MLXService.shell("vm_stat 2>/dev/null | awk '/page size/ {p=$8} /Pages active/ {a=$3} /Pages wired/ {w=$4} END {printf \"%.1f\", (a+w)*p/1073741824}'", timeout: 5) {
      s.ramUsed = Double(out.trimmingCharacters(in: .whitespaces)) ?? 0
    }
    if s.ramTotal > 0 { s.ramPercent = (s.ramUsed / s.ramTotal) * 100 }

    // Swap
    if case .success(let out) = await MLXService.shell("sysctl vm.swapusage 2>/dev/null | awk '{print $7, $10}'", timeout: 5) {
      let parts = out.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
      if parts.count >= 2 {
        s.swapUsed = Double(parts[0].replacingOccurrences(of: ",", with: ".")) ?? 0
        s.swapTotal = Double(parts[1].replacingOccurrences(of: ",", with: ".")) ?? 0
        if s.swapTotal > 0 { s.swapPercent = (s.swapUsed / s.swapTotal) * 100 }
      }
    }

    // SSD Internal
    if case .success(let out) = await MLXService.shell("df -g / 2>/dev/null | tail -1 | awk '{print $4, $2}'", timeout: 5) {
      let parts = out.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
      if parts.count >= 2 { s.internalFree = Double(parts[0]) ?? 0; s.internalTotal = Double(parts[1]) ?? 0 }
    }

    // Thunderbolt SSD
    if FileManager.default.fileExists(atPath: "/Volumes/BACKUP") {
      if case .success(let out) = await MLXService.shell("df -g /Volumes/BACKUP 2>/dev/null | tail -1 | awk '{print $4, $2}'", timeout: 5) {
        let parts = out.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        if parts.count >= 2 { s.thunderboltFree = Double(parts[0]); s.thunderboltTotal = Double(parts[1]) }
      }
    }

    // Memory pressure
    if case .success(let out) = await MLXService.shell("memory_pressure 2>/dev/null | head -1 | awk -F: '{print $2}'", timeout: 5) {
      s.memoryPressure = out.trimmingCharacters(in: .whitespaces)
    }

    // App cache sizes
    let cachePaths = [
      ("Docker", NSHomeDirectory() + "/Library/Containers/com.docker.docker"),
      ("npm", NSHomeDirectory() + "/.npm"),
      ("Xcode", NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"),
      ("Gradle", NSHomeDirectory() + "/.gradle"),
      ("CocoaPods", NSHomeDirectory() + "/Library/Caches/CocoaPods"),
    ]
    for (name, path) in cachePaths {
      if FileManager.default.fileExists(atPath: path) {
        let result = await MLXService.shell("du -sh \"\(path)\" 2>/dev/null | awk '{print $1}'", timeout: 10)
        if case .success(let size) = result {
          s.appCaches.append((name, size.trimmingCharacters(in: .whitespaces), path))
        }
      }
    }

    // Check if swap on SSD exists
    s.swapOnSSD = FileManager.default.fileExists(atPath: "/Volumes/BACKUP/.mac-memory-optimizer/swap/swapfile_64gb")

    return s
  }

  // MARK: - Header

  var header: some View {
    HStack {
      Image(systemName: "memorychip").font(.title2).foregroundStyle(.blue)
      Text("Memória").font(.title2).fontWeight(.bold)
      Spacer()
      if stats.ramPercent > 0 { pressureBadge }
      Button("Atualizar") { Task { await refresh() } }
        .buttonStyle(.bordered).disabled(isRefreshing)
      if isRefreshing { ProgressView().scaleEffect(0.6) }
    }
  }

  var pressureBadge: some View {
    HStack(spacing: 4) {
      Circle().fill(stats.ramPercent < 50 ? .green : stats.ramPercent < 80 ? .orange : .red).frame(width: 8)
      Text(stats.ramPercent < 50 ? "Baixa" : stats.ramPercent < 80 ? "Média" : "Alta")
        .font(.caption).fontWeight(.medium)
    }
    .padding(.horizontal, 8).padding(.vertical, 3)
    .background((stats.ramPercent < 50 ? Color.green : stats.ramPercent < 80 ? Color.orange : Color.red).opacity(0.12))
    .cornerRadius(6)
  }

  // MARK: - Cards

  var cardsGrid: some View {
    LazyVGrid(columns: [.init(.adaptive(minimum: 200))], spacing: 12) {
      ramCard
      swapCard
      internalDiskCard
      thunderboltCard
    }
  }

  var ramCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "memorychip").foregroundStyle(.blue)
        Text("RAM").font(.headline)
        Spacer()
        Text("\(stats.ramUsed, specifier: "%.1f")/\(stats.ramTotal, specifier: "%.0f") GB").font(.caption).monospaced()
      }
      bar(value: stats.ramPercent, color: stats.ramPercent < 50 ? .green : stats.ramPercent < 80 ? .orange : .red)
      HStack {
        Text("\(stats.ramPercent, specifier: "%.0f")% usado").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("Pressão: \(stats.memoryPressure)").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding(12).background(Color(.textBackgroundColor)).cornerRadius(10)
  }

  var swapCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "arrow.triangle.swap").foregroundStyle(.orange)
        Text("Swap").font(.headline)
        Spacer()
        Text("\(stats.swapUsed, specifier: "%.1f")/\(stats.swapTotal, specifier: "%.0f") GB").font(.caption).monospaced()
      }
      bar(value: stats.swapPercent, color: stats.swapPercent < 50 ? .green : stats.swapPercent < 80 ? .orange : .red)
      HStack {
        Text("\(stats.swapPercent, specifier: "%.0f")% usado").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text(stats.swapOnSSD ? "✅ Swap no SSD" : "⚠️ Swap no HD interno").font(.caption2)
      }
    }
    .padding(12).background(Color(.textBackgroundColor)).cornerRadius(10)
  }

  var internalDiskCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "internaldrive").foregroundStyle(.green)
        Text("SSD Interno").font(.headline)
        Spacer()
        Text("\(stats.internalFree, specifier: "%.0f") GB livres").font(.caption).monospaced()
      }
      if stats.internalTotal > 0 {
        let used = stats.internalTotal - stats.internalFree
        let pct = used / stats.internalTotal * 100
        bar(value: pct, color: pct < 70 ? .green : pct < 85 ? .orange : .red)
        Text(stats.internalFree < 20 ? "🔴 Crítico — mover caches urgente" : stats.internalFree < 50 ? "🟡 Pouco espaço" : "✅ OK")
          .font(.caption2)
      }
    }
    .padding(12).background(Color(.textBackgroundColor)).cornerRadius(10)
  }

  var thunderboltCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "externaldrive").foregroundStyle(.cyan)
        Text("Thunderbolt SSD").font(.headline)
        Spacer()
        if let free = stats.thunderboltFree {
          Text("\(free, specifier: "%.0f") GB livres").font(.caption).monospaced()
        } else { Text("N/A").font(.caption).foregroundStyle(.red) }
      }
      if let free = stats.thunderboltFree, let total = stats.thunderboltTotal {
        let used = total - free; let pct = used / total * 100
        bar(value: pct, color: .cyan)
        Text(free > 500 ? "✅ Muito espaço livre" : free > 100 ? "✅ Espaço suficiente" : "🟡 Enchendo")
          .font(.caption2)
      } else {
        Text("❌ SSD Thunderbolt não encontrado em /Volumes/BACKUP").font(.caption).foregroundStyle(.red)
      }
    }
    .padding(12).background(Color(.textBackgroundColor)).cornerRadius(10)
  }

  func bar(value: Double, color: Color) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)).frame(height: 12)
        RoundedRectangle(cornerRadius: 4).fill(color.gradient).frame(width: geo.size.width * CGFloat(min(value, 100) / 100), height: 12)
      }
    }.frame(height: 12)
  }

  // MARK: - Cache Section

  var cacheSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Mover Caches para Thunderbolt SSD", systemImage: "externaldrive.badge.plus").font(.headline)
      Text("Libera espaço no SSD interno — clica no app pra mover").font(.caption).foregroundStyle(.secondary)

      if stats.appCaches.isEmpty {
        Text("Nenhum cache encontrado").font(.caption).foregroundStyle(.secondary)
      }

      LazyVGrid(columns: [.init(.adaptive(minimum: 200))], spacing: 8) {
        ForEach(stats.appCaches, id: \.name) { cache in
          Button(action: { Task { await moveCache(name: cache.name, path: cache.path) } }) {
            HStack {
              Image(systemName: cacheIcon(cache.name)).font(.title3).foregroundStyle(.blue)
              VStack(alignment: .leading) {
                Text(cache.name).font(.subheadline).fontWeight(.medium)
                Text("\(cache.size) → SSD").font(.caption2).foregroundStyle(.secondary)
              }
              Spacer()
              if isMoving { ProgressView().scaleEffect(0.5) }
            }.padding(8)
          }
          .buttonStyle(.bordered).disabled(isMoving)
        }
      }
    }
  }

  func cacheIcon(_ name: String) -> String {
    switch name.lowercased() {
    case "docker": "square.stack.3d.up"
    case "npm", "cocoapods": "nosign"
    case "xcode": "hammer"
    case "gradle": "gearshape.2"
    default: "folder"
    }
  }

  // MARK: - Swap Section

  var swapSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Swap no Thunderbolt SSD", systemImage: "externaldrive.badge.bolt").font(.headline)
      Text("Cria swapfile de 64GB no SSD externo — libera RAM e swap do SSD interno")
        .font(.caption).foregroundStyle(.secondary)

      HStack(spacing: 12) {
        Button(action: { Task { await createSwap() } }) {
          HStack {
            Image(systemName: stats.swapOnSSD ? "checkmark.circle.fill" : "play.fill")
            Text(stats.swapOnSSD ? "Swap já existe" : "Criar Swap 64GB")
          }.frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).tint(.blue).disabled(isMoving || stats.swapOnSSD)

        Button(action: { Task { await activateSwap() } }) {
          Label("Ativar Swap", systemImage: "bolt.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).disabled(!stats.swapOnSSD)
      }

      if stats.swapOnSSD {
        HStack {
          Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
          Text("Swapfile de 64GB criado no Thunderbolt SSD. Clique em 'Ativar Swap' para ativar (requer senha).")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(8).background(Color.green.opacity(0.06)).cornerRadius(8)
      }
    }
  }

  var logSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Log", systemImage: "text.alignleft").font(.headline)
      ScrollView {
        Text(moveLog).font(.caption).monospaced().frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 120).padding(8).background(Color(.textBackgroundColor)).cornerRadius(8)
    }
  }

  // MARK: - Actions

  func moveCache(name: String, path: String) async {
    isMoving = true
    moveLog += "📦 Movendo \(name)...\n"
    let target = "/Volumes/BACKUP/.mac-memory-optimizer/apps/\(name.lowercased())"
    let result = await MLXService.shell("""
      mkdir -p "\(target)" && \
      rsync -avh "\(path)/" "\(target)/" 2>&1 | tail -2 && \
      mv "\(path)" "\(path).backup" 2>/dev/null && \
      ln -s "\(target)" "\(path)" 2>/dev/null && \
      echo "✅ \(name) movido para Thunderbolt SSD"
    """, timeout: 300)
    if case .success(let out) = result { moveLog += out + "\n" }
    if case .failure(let err) = result { moveLog += "❌ \(err.localizedDescription)\n" }
    await refresh()
    isMoving = false
  }

  func createSwap() async {
    isMoving = true
    moveLog += "🔄 Criando swapfile de 64GB no Thunderbolt SSD...\n"
    let result = await MLXService.shell("""
      mkdir -p "/Volumes/BACKUP/.mac-memory-optimizer/swap" && \
      SWAPFILE="/Volumes/BACKUP/.mac-memory-optimizer/swap/swapfile_64gb" && \
      if [ ! -f "$SWAPFILE" ]; then \
        dd if=/dev/zero of="$SWAPFILE" bs=1m count=65536 2>&1 | tail -1 && \
        chmod 600 "$SWAPFILE" && \
        echo "✅ Swapfile de 64GB criado"; \
      else echo "✅ Swapfile já existe"; fi
    """, timeout: 600)
    if case .success(let out) = result { moveLog += out + "\n" }
    if case .failure(let err) = result { moveLog += "❌ \(err.localizedDescription)\n" }
    await refresh()
    isMoving = false
  }

  func activateSwap() async {
    moveLog += "⚡ Ativando swap no Thunderbolt SSD...\n"
    let result = await MLXService.shell("""
      echo "⚠️  Para ativar o swap, execute no Terminal:"
      echo "  sudo vnutil -a '/Volumes/BACKUP/.mac-memory-optimizer/swap/swapfile_64gb'"
      echo ""
      echo "Isso requer senha de administrador."
    """, timeout: 10)
    if case .success(let out) = result { moveLog += out + "\n" }
  }
}
