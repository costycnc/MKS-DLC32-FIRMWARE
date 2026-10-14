# CostyCNC Cloud Firmware Updater — MKS-DLC32

Browser-based firmware flashing tool for **CostyCNC hot-wire foam cutters** equipped with the **MKS-DLC32** control board.

The updater runs entirely in the browser using the WebSerial API and flashes firmware over USB — no software installation required.

---

## 📋 Options Overview

The portal offers **4 firmware installation modes**, each reachable via a URL parameter (`?opzione=1` … `?opzione=4`) or selectable from the dropdown menu.

| # | URL | Target | Flash Address | File | Keeps user settings? |
|---|-----|--------|---------------|------|----------------------|
| 1 | `?opzione=1` | Full firmware — **NEMA 17 motors** | `0x1000` | `1000-nema.bin` | ❌ No |
| 2 | `?opzione=2` | Full firmware — **28BYJ-48 motors** | `0x1000` | `1000-28byj.bin` | ❌ No |
| 3 | `?opzione=3` | **SD Autorun** code only | `0x10000` | `sd-autorun.bin` | ✅ Yes |
| 4 | `?opzione=4` | **Default central firmware** (recovery) | `0x10000` | `dump-totale.bin` | ✅ Yes |

---

## 🔧 Option Details

### Option 1 — Full firmware for NEMA motors
Installs the complete CostyCNC firmware for MKS-DLC32 boards driving **NEMA 17** stepper motors.

- Flash address: `0x1000`
- File: `1000-nema.bin`

⚠️ **All custom settings are wiped.** This includes:
- `$100`, `$101`, `$102` (motor step calibration)
- `$esp100`, `$esp101` (Wi-Fi router credentials)
- Custom macros and user parameters

After flashing, the machine returns to **factory defaults** and boots in **AP mode**.

---

### Option 2 — Full firmware for 28BYJ-48 motors
Same as Option 1, but built for machines using **28BYJ-48** geared stepper motors.

- Flash address: `0x1000`
- File: `1000-28byj.bin`

**Only difference vs Option 1 — motor step configuration:**

| Parameter | NEMA 17 | 28BYJ-48 |
|-----------|---------|----------|
| `$100` | 100 | 1024 |
| `$101` | 100 | 1024 |
| `$102` | 100 | 1024 |

⚠️ Same warning as Option 1: **all user settings erased**, machine returns to AP mode.

---

### Option 3 — SD Autorun code only
Installs **only the application code** with the **SD card autorun** feature enabled.

- Flash address: `0x10000`
- File: `sd-autorun.bin`

✅ **Safe update.** Does **NOT touch**:
- Web interface files (`index.gz` and related pages)
- All `$` and `$esp` user parameters
- Wi-Fi credentials, motor calibration, custom macros

Use this when you want to enable automatic file execution from the SD card at boot, without losing your configuration.

---

### Option 4 — Default central firmware (recovery)
Installs the **default application code** (without SD autorun).

- Flash address: `0x10000`
- File: `dump-totale.bin`

✅ **Safe update.** Like Option 3, it does **NOT touch** user parameters or custom data.

**When to use:** if **Option 3 fails** or the machine does not boot correctly after an autorun update, use **Option 4** to restore the central firmware to its original state — **without losing** `$` parameters, `$esp` settings, or custom pages.

---

## 🧩 Technical Specifications

- **Board:** MKS-DLC32 (ESP32-based)
- **Flash mode:** `dout`
- **Flash frequency:** `80 MHz`
- **Flash size:** preserved (`keep`)
- **Baud rate:** `921600`
- **Bootloader address:** `0x1000` (full firmware) / `0x10000` (application only)
- **Browser requirement:** Chrome / Edge with WebSerial API — **HTTPS mandatory**

---

## 📁 Files Required on the Server

```
index.html
esptool-bundle.js
1000-nema.bin
1000-28byj.bin
sd-autorun.bin
dump-totale.bin
```

> ⚠️ If you renamed `1000-byj-48.bin` to `1000-28byj.bin`, update both the file on the server **and** the `<option value="...">` in `index.html` so they match.

---

## 🛠️ How the Flashing Works

1. Browser requests the serial port via `navigator.serial.requestPort()`
2. `esptool-bundle.js` opens the connection at `921600` baud
3. The selected `.bin` file is fetched from the server
4. The binary is written to the target flash address
5. Board is disconnected and can be power-cycled

---

## ⚡ Quick Links for Customers

You can send a direct link to a customer and the correct option will be pre-selected automatically (the dropdown menu will be hidden).

| Machine type | Direct link |
|--------------|-------------|
| CostyCNC with **NEMA 17** motors | `https://yourdomain.com/index.html?opzione=1` |
| CostyCNC with **28BYJ-48** motors | `https://yourdomain.com/index.html?opzione=2` |
| Enable **SD autorun** only | `https://yourdomain.com/index.html?opzione=3` |
| **Recovery** — restore central firmware | `https://yourdomain.com/index.html?opzione=4` |---

## 👤 End-User Guide

This page lets you update the firmware of your **CostyCNC hot-wire foam cutter** directly from the browser — no software installation required.

### Requirements
- **MKS-DLC32** board installed on the machine
- USB cable
- Updated **Chrome** or **Edge** browser
- Internet connection

---

### The 4 available options

**🔹 Option 1 — Full firmware for NEMA motors**
Installs the complete CostyCNC firmware for machines with **NEMA 17** motors.

⚠️ **Warning:** all custom settings are erased, including:
- Wi-Fi router credentials
- Motor calibration (`$100`, `$101`, `$102`)
- Custom macros

After flashing, the machine returns to **AP mode** and must be reconfigured.

---

**🔹 Option 2 — Full firmware for 28BYJ-48 motors**
Same as Option 1, but for machines with **28BYJ-48** motors.

The only difference is the motor parameters:

| Parameter | NEMA 17 | 28BYJ-48 |
|-----------|---------|----------|
| `$100` | 100 | 1024 |
| `$101` | 100 | 1024 |
| `$102` | 100 | 1024 |

⚠️ Same warning as Option 1: **all settings are wiped** and the machine returns to AP mode.

---

**🔹 Option 3 — SD Autorun code only**
Installs **only the application code** with the SD-card autorun feature enabled.

✅ **Safe update.** Does **NOT touch**:
- Web pages (`index.gz`)
- `$` and `$esp` parameters
- Wi-Fi password, motor calibration, macros

---

**🔹 Option 4 — Default central firmware (recovery)**
Installs the **default application code**, without SD autorun.

✅ **Safe update.** Like Option 3, it does **NOT touch** parameters or custom data.

**When to use it:** if **Option 3 fails** or the machine does not boot correctly after the autorun update, use **Option 4** to restore the central part to its original state **without losing** your `$`, `$esp` settings or custom pages.

---

### 🛠️ How to proceed

1. Connect the **MKS-DLC32** board to your computer with a USB cable.
2. Open this page in **Chrome** or **Edge** (must be an **HTTPS** connection).
3. Select the desired option from the dropdown menu.
   - If you received a **direct link** from your reseller, the menu will already be pre-filled and hidden.
4. Click the green **"🚀 Avvia Scaricamento e Aggiornamento Cloud"** button.
5. The browser will open a dialog: select your machine's port (e.g. `COM3`) and click **Connect**.
6. Wait until progress reaches **100%**.
7. Power-cycle the board (switch it off and on again).

---

### ⚠️ Important warnings

- **Options 1 and 2 erase everything**: you will need to reconfigure Wi-Fi and recalibrate motors.
- **Options 3 and 4 are safe**: they keep all your settings.
- **Use Option 4 as recovery** if Option 3 causes boot issues.
- **Do not unplug** the board during the update.
- The site **must be HTTPS** — this is a browser requirement.

---

### 📞 Support

For support, contact your reseller or visit the official **CostyCNC** channels.

---

## 📄 License & Credits

Developed by **CostyCNC** for hot-wire foam cutting machines.
