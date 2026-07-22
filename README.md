# LuMini

[![Download Latest Release](https://img.shields.io/badge/Download-Latest_Release-blue?style=for-the-badge&logo=github)](https://github.com/Janneske2001/LuMini/releases/latest)

<!-- IMAGE: Banner or hero shot of the LED ring under a Mac mini (e.g., banner.jpg) -->

A premium 24‑LED RGB ring that sits under your Mac mini, controlled via USB‑C.  
This repository contains the **macOS companion app**.

---

## ✨ Features

### Mac App (SwiftUI)
- **Live circular preview** – mirrors the physical ring in real time  
- **Full UI control** – effects, colours, sliders, numeric input, gradient editor  
- **Draggable gradient bar** – add, remove, reposition and edit color stops instantly  
- **Native macOS color picker** – no opacity slider, instant updates  
- **File‑based presets** – save/load `.rgb` (JSON) presets  
- **EEPROM backup** – save to the ring’s internal memory  
- **Modern menu bar popover** – Control Center‑style toggles with native macOS 26 design
- **Dock icon support** – app appears in the dock when configuration window is open
- **Shortcuts integration** – control the ring via Shortcuts (On/Off, Toggle, Load Preset, Set Effect)  
- **Auto Sleep/Wake** – ring turns off when your Mac sleeps and on when it wakes  
- **Launch at login** – optional, runs as a background service  
- **Built‑in update checker** – notifies you when a new version is available

### Hardware (pre‑assembled)
- 24‑LED RGB ring (WS2812B)  
- RP2040‑based controller board  
- USB‑C cable  
- 3D‑printed enclosure  
- All units are pre‑flashed and ready to use

<!-- IMAGE: Photo of the assembled ring in its enclosure, side view (hardware.jpg) -->

---

## 📥 Download

**Latest release:** [Download the app here](https://github.com/Janneske2001/LuMini/releases/latest)

1. Download the `.zip` file from the Releases page.  
2. Unzip and drag `LuMini.app` to your **Applications** folder.  
3. Open the app – it will appear as a menu bar icon.

> ⚠️ **Gatekeeper warning**: macOS may block the app. To open it, right‑click the app and select **Open** (then confirm). This is normal for unsigned apps.

---

## 🖥️ How to Use

### Menu Bar
- Click the **hexagon** icon in your menu bar.  
- The popover features **Control Center‑style** toggles:  
  - **Power** – turn the ring on/off  
  - **Login** – launch at login  
  - **Sleep** – auto sleep/wake  
- Brightness slider for quick adjustments.  
- Action buttons:  
  - **Gear** – open the full configuration window  
  - **Update** – check for updates (with a satisfying spin animation!)  
  - **Close** – quit the app

<!-- IMAGE: Screenshot of the menu bar popover (menu-bar.png) -->

### Main Window
- The window header features the connection status.
- Choose an **Effect** (Static, Breathe, Chase, Knight, Gradient, Rainbow).  
- Adjust **Main Color**, **Background Color**, **Speed**, **Brightness**, and **Scale**.  
- For Gradient: drag colour dots, tap to edit, double‑tap to remove, click **Add Color**.

<!-- IMAGE: Screenshot of the main app window showing the gradient editor (app-window.png) -->

### About Popover
- Click the profile picture in the bottom toolbar to open the About popover.
- Quick links to **Twitter**, **Donate**, and **GitHub**.
- Update section with **checkbox** for automatic updates and a **Check Now** button.

<!-- IMAGE: Screenshot of the About popover (about.png) -->

### Presets
- **Save to Ring (EEPROM)** – stores settings on the device.  
- **Load from Ring (EEPROM)** – restores from the device.  
- **Save to File…** – exports a `.rgb` file (JSON format).  
- **Load from File…** – imports a `.rgb` file.

<!-- IMAGE: Screenshot of the Save/Load dialog (save-load.png) -->

### Shortcuts Integration
The app exposes three Shortcuts actions:

| Action | Description |
|--------|-------------|
| **Set Power State** | Turn the ring on or off. |
| **Toggle Power** | Flip the current power state. |
| **Load Preset from File** | Load a `.rgb` file via file picker. |

1. Open the **Shortcuts** app on your Mac.  
2. Search for “LuMini”.  
3. Combine with triggers (time, focus, keyboard shortcuts) for automation.

<!-- IMAGE: Screenshot of Shortcuts actions (shortcuts.png) -->

---

## ⚙️ How It’s Made

- **App** – built with SwiftUI and AppKit (IOKit for serial communication).  
- **Firmware** – Arduino / C++ with FastLED, custom coded and pre‑flashed.  
- **Communication** – USB‑C serial (baud 115200).  
- **File format** – `.rgb` (JSON) for portability and sharing.  
- **App Icon** – custom six‑colored ring design in the new `.icon` format (macOS 26+).

---

## 📂 Repository Structure

```
LuMini/
├── LuMini.xcodeproj            # Xcode project
├── Sources/                    # App source code (SwiftUI, AppIntents)
├── README.md                   # This file
├── LICENSE                     # MIT License (app code only)
└── .github/
    └── ISSUE_TEMPLATE/         # Bug report / feature request templates
```

---

## 🧑‍💻 Development

This repository contains the **macOS app source code only**.  

### Building from source (for contributors)
1. Clone the repository:
   ```bash
   git clone https://github.com/Janneske2001/LuMini.git
   cd LuMini
   ```
2. Open `LuMini.xcodeproj` in Xcode 14+.
3. Build and run (⌘R).

> ℹ️ The app runs as a menu bar utility – the main window opens from the menu bar.  
> ℹ️ The app icon is in the new `.icon` format (macOS 26+). For older macOS versions, the app will fall back to a default icon.

---

## 🤝 Contributing

I welcome contributions to the **app code** – bug fixes, UI improvements, or new features.  
Please open an issue first to discuss what you’d like to work on.

---

## 📜 License

The **macOS app source code** is released under the **MIT License** – see the [LICENSE](LICENSE) file for details.

---

## 💖 Support & Donations

If you find this app useful, consider supporting future development:

- **Star** this repository ⭐  
- **Donate** via [PayPal](https://paypal.me/janneske2001)  

---

## 📞 Contact

- **Bug reports / feature requests** – [GitHub Issues](https://github.com/Janneske2001/LuMini/issues)  
- **General questions** – send me a message on Twitter / X
- **Twitter / X** – [@LuMini_Mods](https://twitter.com/LuMini_Mods)  

---

*Made with ❤️ and Swift.*  
*Designed for the Mac mini, by a Mac user.*
