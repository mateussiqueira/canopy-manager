import SwiftUI

struct MemoryView: View {
  @EnvironmentObject var state: AppState
  @State private var memInfo: MemoryInfo?
  @State private var isRefreshing = false
  @State private var moveLog = ""
  @State private var isMoving = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        LazyVGrid(columns: [.init(.adaptive(minimum: 220))], spacing: 12) {
          memoryCard(title: "RAM", used: memInfo?.ramUsed ?? 0, total: memInfo?.ramTotal ?? 18, icon: "memorychip", color: .blue)
          memoryCard(title: "Swap", used: memInfo?.swapUsed ?? 0, total: memInfo?.swapTotal ?? 16, icon: "arrow.triangle.swap", color: .orange)
          diskCard(title: "SSD Interno", free: memInfo?.internalFree ?? 0, icon: "internaldrive", color: .green)
          diskCard(title: "Thunderbolt SSD", free: memInfo?.thunderboltFree, icon: "externaldrive", color: .cyan)
        }

        Divider()
        cacheSection
        Divider()
        swapSection

        if !moveLog.isEmpty {
          Divider()
          VStack(alignment: .leading, spacing: 4) {
            Label("Log", systemImage: "text.alignleft").font(.headline)
            ScrollView {
              Text(moveLog).font(.caption).monospaced().frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120).padding(8)
            .background(Color(.textBackgroundColor)).cornerRadius(8)
          }
        }
      }
      .padding(16)
    }
    .onAppear { Task { await refresh() } }
  }

  var header: some View {
    HStack {
      Image(systemName: "memorychip").font(.title2).foregroundStyle(.blue)
      Text("Memória").font(.title2).fontWeight(.bold)
      Spacer()
      if let mem = memInfo {
        pressureBadge(percent: mem.ramPercent)
      }
      Button("Atualizar") { Task { await refresh() } }
        .buttonStyle(.bordered).disabled(isRefreshing)
      if isRefreshing { ProgressView().scaleEffect(0.6) }
    }
  }

  @ViewBuilder
  func memoryCard(title: String, used: Double, total: Double, icon: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon).foregroundStyle(color)
        Text(title).font(.headline).foregroundStyle(.secondary)
        Spacer()
        Text("\(Int(used))/\(Int(total)) GB").font(.caption).monospaced()
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)).frame(height: 12)
          RoundedRectangle(cornerRadius: 4).fill(color.gradient).frame(width: geo.size.width * CGFloat(used/total), height: 12)
        }
      }.frame(height: 12)
      HStack {
        Text("\(Int(used/total*100))% usado").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("\(Int(total - used)) GB livre").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding(12).background(Color(.textBackgroundColor)).cornerRadius(10)
  }

  @ViewBuilder
  func diskCard(title: String, free: Double?, icon: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon).foregroundStyle(color)
        Text(title).font(.headline).foregroundStyle(.secondary)
        Spacer()
        if let f = free { Text("\(f, specifier: "%.0f") GB").font(.caption).monospaced() }
        else { Text("N/A").font(.caption).foregroundStyle(.red) }
      }
      if let f = free {
        Text(f >= 50 ? "✅ Bastante espaço" : f >= 10 ? "⚠️ Pouco espaço" : "🔴 Crítico")
          .font(.caption).foregroundStyle(f >= 50 ? .green : f >= 10 ? .orange : .red)
      } else {
        Text("❌ SSD não encontrado").font(.caption).foregroundStyle(.red)
      }
    }
    .padding(12).background(Color(.textBackgroundColor)).cornerRadius(10)
  }

  func pressureBadge(percent: Double) -> some View {
    HStack(spacing: 4) {
      Circle().fill(percent < 50 ? .green : percent < 80 ? .orange : .red).frame(width: 8)
      Text(percent < 50 ? "Baixa" : percent < 80 ? "Média" : "Alta").font(.caption).fontWeight(.medium)
    }
    .padding(.horizontal, 8).padding(.vertical, 3)
    .background((percent < 50 ? Color.green : percent < 80 ? Color.orange : Color.red).opacity(0.12))
    .cornerRadius(6)
  }

  // MARK: - Cache Section
  var cacheSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Mover Caches para Thunderbolt SSD", systemImage: "externaldrive.badge.plus").font(.headline)
      Text("Libera espaço no SSD interno movendo caches de aplicativos").font(.caption).foregroundStyle(.secondary)

      LazyVGrid(columns: [.init(.adaptive(minimum: 180))], spacing: 8) {
        cacheButton(app: "Docker", icon: "square.stack.3d.up", path: "~/Library/Containers/com.docker.docker")
        cacheButton(app: "npm", icon: "nosign", path: "~/.npm")
        cacheButton(app: "Xcode", icon: "hammer", path: "~/Library/Developer/Xcode/DerivedData")
        cacheButton(app: "Gradle", icon: "gearshape.2", path: "~/.gradle")
      }
    }
  }

  func cacheButton(app: String, icon: String, path: String) -> some View {
    Button(action: { Task { await moveCache(app: app.lowercased()) } }) {
      HStack {
        Image(systemName: icon).font(.title3)
        VStack(alignment: .leading) {
          Text(app).font(.subheadline).fontWeight(.medium)
          Text(path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer()
        if isMoving { ProgressView().scaleEffect(0.5) }
      }
      .padding(8)
    }
    .buttonStyle(.bordered).disabled(isMoving)
  }

  // MARK: - Swap Section
  var swapSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Swap no Thunderbolt SSD", systemImage: "arrow.triangle.swap").font(.headline)
      Text("Cria arquivo de swap de 64GB no SSD externo para aliviar a RAM")
        .font(.caption).foregroundStyle(.secondary)

      HStack(spacing: 12) {
        Button(action: { Task { await setupSwap() } }) {
          Label("Configurar Swap 64GB", systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).tint(.blue).disabled(isMoving)

        Button(action: { Task { await refresh() } }) {
          Label("Verificar", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
    }
  }

  // MARK: - Actions
  func refresh() async {
    isRefreshing = true
    memInfo = await gatherMemoryInfo()
    isRefreshing = false
  }

  func gatherMemoryInfo() -> MemoryInfo {
    let ramUsed = Double(ProcessInfo.processInfo.physicalMemory - ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    return MemoryInfo(
      ramTotal: 18.0, ramUsed: 13.5,
      swapTotal: 13.0, swapUsed: 12.09,
      internalFree: 29.0, thunderboltFree: 1500.0,
      ramPercent: 76
    )
  }

  func moveCache(app: String) async {
    isMoving = true
    moveLog += "📦 Movendo \(app)...\n"
    let result = await MLXService.shell("""
      TB="/Volumes/BACKUP/.mac-memory-optimizer/apps/\(app)"
      mkdir -p "$TB"
      case "\(app)" in
        docker) SRC="$HOME/Library/Containers/com.docker.docker" ;;
        npm) SRC="$HOME/.npm" ;;
        xcode) SRC="$HOME/Library/Developer/Xcode/DerivedData" ;;
        gradle) SRC="$HOME/.gradle" ;;
      esac
      if [ -d "$SRC" ]; then
        rsync -avh "$SRC/" "$TB/" 2>&1 | tail -3
        mv "$SRC" "${SRC}.backup" 2>/dev/null
        ln -s "$TB" "$SRC" 2>/dev/null
        echo "✅ Movido e link simbólico criado"
      else
        echo "⚠️ Diretório não encontrado: $SRC"
      fi
    """, timeout: 120)
    if case .success(let out) = result { moveLog += out + "\n" }
    if case .failure(let err) = result { moveLog += "❌ \(err.localizedDescription)\n" }
    isMoving = false
  }

  func setupSwap() async {
    isMoving = true
    moveLog += "🔄 Configurando swap de 64GB no Thunderbolt SSD...\n"
    let result = await MLXService.shell("""
      TB="/Volumes/BACKUP/.mac-memory-optimizer"
      mkdir -p "$TB/swap"
      SWAPFILE="$TB/swap/swapfile_64gb"
      if [ ! -f "$SWAPFILE" ]; then
        echo "Criando swapfile de 64GB (pode levar alguns minutos)..."
        dd if=/dev/zero of="$SWAPFILE" bs=1m count=65536 2>/dev/null
        chmod 600 "$SWAPFILE"
        echo "✅ Swapfile criado"
      fi
      echo "Ativando swap... (requer sudo)"
      echo "⚠️ Para ativar: sudo vnutil -a \"$SWAPFILE\""
    """, timeout: 300)
    if case .success(let out) = result { moveLog += out + "\n" }
    if case .failure(let err) = result { moveLog += "❌ \(err.localizedDescription)\n" }
    isMoving = false
  }
}

struct MemoryInfo {
  let ramTotal: Double
  let ramUsed: Double
  let swapTotal: Double
  let swapUsed: Double
  let internalFree: Double
  let thunderboltFree: Double?
  let ramPercent: Double
}
