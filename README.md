<p align="center">
  <img src="https://raw.githubusercontent.com/mateussiqueira/canopy/dev/public/logo.svg" width="100">
</p>
<p align="center"><strong>Canopy Manager</strong> — Native macOS app for MLX models + Canopy</p>

---

Native macOS app (SwiftUI) to manage local MLX models and Canopy AI agent on Apple Silicon.

## Features

- **Model Browser** — View all MLX models with sizes and categories
- **Server Control** — Start/stop MLX inference server, select any model
- **Auto Model Selection** — Quick prompt that picks the right model for your task
- **Canopy Integration** — One-click access to Canopy CLI

## Requirements

- macOS 14+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4)
- [Canopy](https://github.com/mateussiqueira/canopy) installed
- MLX models on SSD (`/Volumes/BACKUP/mlx/models/`)

## Download

[Download CanopyManager.dmg](.build/release/CanopyManager.dmg)

Or build from source:

```bash
git clone https://github.com/mateussiqueira/canopy-manager.git
cd canopy-manager
swift build -c release
open .build/release/CanopyManager.app
```

## Screenshots

![Models](https://raw.githubusercontent.com/mateussiqueira/canopy/dev/public/logo.svg)

## License

MIT
