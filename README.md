# 🛡️ IdleSentry

A native, lightweight macOS menu bar utility that automatically terminates sensitive applications when your machine goes idle, keeping your active workspace private from prying eyes.

<p align="center">
  <img src="AppIcon.icns" width="128" height="128" alt="IdleSentry Icon">
</p>

---

## 💡 The Problem
Imagine you're at the office, a coffee shop, or working around family. Your boss calls you suddenly, or you step away for a quick break. You don't lock your screen in time, leaving Slack, browser tabs, password managers, or terminal sessions fully exposed. 

**IdleSentry** solves this. It runs quietly in the menu bar, monitors user inactivity, and automatically terminates pre-configured sensitive apps once a custom countdown expires.

---

## ✨ Features

- 🔋 **Native & Lightweight**: Built with native Swift and SwiftUI. Run-time footprint is minimal (near-zero CPU, tiny memory footprint).
- 🕒 **Custom Inactivity Timer**: Enforce a global inactivity threshold before countdown triggering.
- 🎯 **Targeted Protection**: Only terminates the specific applications you configure.
- ⚡ **Quit Behaviors**: Choose between **Standard Quit** (safely lets apps save data) or **Force Quit** (instant process termination).
- ⚙️ **Launch on Startup**: Native login item support (`SMAppService`) to keep you protected automatically.
- 🔒 **Privacy First**: operates 100% locally on your machine. No telemetry, no analytic trackers, and no internet access required.

---

## 📦 Installation & Gatekeeper Note

Because IdleSentry is free and open-source, it is signed locally (ad-hoc) rather than using a paid Apple Developer certificate. On first launch, macOS Gatekeeper will block execution with a warning.

To bypass this and run the app:
1. Download the latest release `.dmg` from the **Releases** tab.
2. Drag **IdleSentry.app** to your **Applications** folder.
3. Open your Terminal and run the following command to clear the quarantine flag:
   ```bash
   xattr -cr /Applications/IdleSentry.app
   ```
4. Launch the app normally.

*Requires macOS 13.0 (Ventura) or later.*

---

## 🛠️ Compiling from Source

You can easily build the project yourself using the included build tools:

1. Clone the repository:
   ```bash
   git clone https://github.com/synthwave541/IdleSentry.git
   cd IdleSentry
   ```
2. Build the app bundle:
   ```bash
   ./build.sh
   ```
3. Generate the distribution installer package:
   ```bash
   ./package.sh
   ```
   *Note: Building from source automatically marks the application as a **Custom Build** (`1.0.0-custom`) for security and integrity.*

---

## 🖥️ Windows Version
A native Windows port (supporting standard Windows PCs, 32-bit x86, and Qualcomm/Snapdragon ARM64 machines) is currently under active development. Stay tuned!

---

## 📄 License

Distributed under the **Apache License 2.0**. 

*The name "IdleSentry" and the shield/clock branding assets are trademarks. You are free to fork the codebase and distribute custom builds, but you cannot distribute them under the name "IdleSentry" or use the official branding without permission.*
