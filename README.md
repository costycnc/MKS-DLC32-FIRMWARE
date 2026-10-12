# MKS-DLC32-FIRMWARE
The source code of MKS DLC32.

## Environment construction:

- vscode

- platformIO

PlatformIOc needs to be installed on vscode.

Open Firmware with vscode, and platformIO will be started, In the platform.ini file，

`default_envs = mks_dlc32_v2_1` 

Note:We will make a pin suitable for V1.0，Settings corresponding to the selection of coreXY.

Then compile and download.

# MKS-DLC32 Firmware Automation (CoreXY / Foam Cutter)

This repository contains the optimized firmware for the **MKS DLC32 V2.1** board, configured for **CoreXY** kinematics (such as hot-wire CNC foam cutters or laser systems).

---

## 📖 The Story Behind This Project (How It All Began)

Every great open-source modification comes from a real-world necessity. This project started in the **costycnc.it** workshop with a clear goal: creating a completely standalone hot-wire foam cutting machine that could start a job instantly, without requiring a computer, a Wi-Fi connection, or screen interaction. 

### ❌ The Failed Attempts (The Hardware Battle)
Our first instinct was to use a classic hardware approach: wiring a physical button to the board to trigger the file. However, the **MKS DLC32 V2.1** board threw several hidden engineering obstacles at us:
1. **The EXP1 Header Failure (GPIO 25):** We mapped the pinout and wired a button to GPIO 25. It failed due to deep software conflicts. Even without a display attached, the proprietary background graphics libraries (`display_init()` / `MKS_LVGL`) kept reconfiguring the pin, floating it, and causing infinite ghost-trigger loops that flooded the serial console.
2. **The EXP2 Header Failure (GPIO 26):** We tried shifting to the touchscreen controller pins, but encountered identical pin-sharing locks from the core system.
3. **The Z-Limit Attempt (GPIO 34):** While electrically isolated and pulled high by the onboard 10kΩ hardware resistor, the microsecond loop speed of the ESP32 chip made mechanical button debouncing unreliable without complex external hardware filtering.

### 💡 The Eureka Moment (The Software Solution)
Faced with endless electrical noise and pin conflicts, we stopped fighting the hardware and asked a different question: *Why add extra buttons when the board already has a perfectly engineered sensor built-in?* **The MicroSD card slot.**

Instead of chasing phantom signals on display pins, we decided to track the physical mounting status of the SD card. By combining a non-blocking timer with a direct check on the filesystem, we created a seamless automation: you slide the card in, the machine silently verifies it, and the motors start moving. No wires, no interference, pure software elegance.

---

## 🚀 Key Features

- 🛠️ **Development Environment:** Fully configured for VS Code and PlatformIO (`default_envs = mks_dlc32_v2_1`).
- 🤖 **Total Stand-Alone Automation:** Non-blocking hardware scan of the MicroSD card hooked directly into the GRBL loop.
- ⚡ **CPU Optimization:** The SD file system check triggers only once every 3 seconds (`millis()` filtered). This keeps the ESP32 processor 100% free to calculate stepper motor pulses smoothly and accurately without any jitter.
- 🛡️ **Safety Guard:** If an SD card is inserted but the required `/costycnc.nc` file is missing, the firmware safely aborts the auto-run sequence instead of spamming error loops.

---

## 📋 Detailed EXP1 Connector Pinout Reference

During our hardware testing phase, we successfully mapped out the elusive EXP1 header layout for the MKS DLC32 V2.1 board. Here is the verified physical pinout (with the **plastic alignment notch facing DOWNWARD**):

```text
       UPPER ROW (Away from the alignment notch)
       [ Pin 1 ]  [ Pin 3 ]  [ Pin 5 ]  [ Pin 7 ]  [ Pin 9 ]
       ( LCD_RS ) ( LCD_EN ) ( LCD_D4 ) (  NC   )  (  GND  )
       
       [ Pin 2 ]  [ Pin 4 ]  [ Pin 6 ]  [ Pin 8 ]  [ Pin 10 ]
       ( MISO   ) ( LCD_CS ) ( SCK    ) ( MOSI  )  (  +5V  )
       LOWER ROW (Adjacent to the plastic notch)
       
       =================== ALIGNMENT NOTCH ===================
```

### Hardware Pin Mapping:
- **Pin 4:** Maps to **GPIO 25** (`LCD_CS`).
- **Pin 9:** Maps to **Ground** (`GND`).

---

## 💻 Where to Include the Code & Implementation

The automation routine must be embedded inside **`Grbl_Esp32/src/Protocol.cpp`**. 

You do **NOT** need to add `#include "SDCard.h"` at the top, because it is already inherited automatically via `#include "Grbl.h"`. 

Open `Protocol.cpp`, scroll down to the **`protocol_main_loop()`** function, locate the beginning of the infinite **`for (;;)`** cycle, and paste this block right after the opening bracket:

```cpp
    int c;
    bool is_need_next = false;
    for (;;) {

        // --- START SD INSERTION AUTOMATIC RUN WITH FILE CHECK ---
        static bool file_already_started = false;
        static uint32_t last_sd_check_time = 0;

        // Run the physical hardware check only once every 3 seconds (3000 ms)
        if (millis() - last_sd_check_time >= 3000) {
            last_sd_check_time = millis(); // Instantly update the benchmark timestamp

            // Electrically query the slot pins to determine the true hardware state
            // Passing 'true' forces a hardware refresh without dragging down the CPU
            bool current_sd_ready = (get_sd_state(true) == SDState::Idle);

            // If the machine is Idle, the SD is ready, and the file hasn't started yet
            if (sys.state == State::Idle && current_sd_ready && !file_already_started) {
                #ifdef ENABLE_SD_CARD
                
                // --- FILE EXISTENCE VERIFICATION STRATEGY ---
                // Open the file directly to make sure it exists on the filesystem
                File testFile = SD.open("/costycnc.nc", "r");
                
                if (testFile) {
                    // File exists! Close it immediately to free up the stream memory
                    testFile.close();
                    
                    grbl_send(CLIENT_ALL, "[MSG:SD Card ready and /costycnc.nc found! Starting cut...]\r\n");
                    
                    // Inject the official run command into the native MKS buffer queue
                    MKS_GRBL_CMD_SEND("$SD/Run=costycnc.nc\n");
                    
                    // Lock the state flag to prevent infinite re-triggering loops
                    file_already_started = true;
                } else {
                    // If the file is NOT found, abort and report to the user
                    grbl_send(CLIENT_ALL, "[MSG:Error: Card inserted but /costycnc.nc is MISSING. Aborting!]\r\n");
                    
                    // Set to true to stay quiet and avoid log spamming until the card is swapped
                    file_already_started = true; 
                }
                #endif
            }

            // If the SD Card is ejected, reset the flag and release the system state
            if (!current_sd_ready && file_already_started && sys.state == State::Idle) {
                file_already_started = false; // Reset successfully completed
                grbl_send(CLIENT_ALL, "[MSG:SD Card removed! System ready for next insertion.]\r\n");
            }
        }
        // --- END SD INSERTION AUTOMATIC RUN ---

#if 1
#ifdef ENABLE_SD_CARD
        // ... (rest of the original Grbl loop code continues here)
```

---

## 🛠️ How To Use (Stand-Alone Operation)

1. Generate your CNC G-Code cutting path using your preferred CAM software.
2. Rename the exported file to exactly **`costycnc.nc`** (ensure lowercase file extension).
3. Copy the file directly to the root directory of a MicroSD card formatted in **FAT32**.
4. Power up your machine (it will sit quietly in `Idle` state).
5. **Insert the MicroSD card:** Within 3 seconds, the board will notice the card, verify the file contents, initialize the axes, and automatically start cutting.
6. Once the execution finishes, the machine returns to its original home position and sleeps back into `Idle` state, waiting for the next card swap.

---

## 📄 License

This project is a custom fork of the Makerbase repository, branching off Bart Dring's core open-source `Grbl_ESP32` architecture. Released under the **GPLv3 License**.

***
Developed by [costycnc](https://github.com) - Visit our official website: [costycnc.it](https://costycnc.it)


<img width="768" height="1365" alt="Gemini_Generated_Image_7x95qj7x95qj7x95" src="https://github.com/user-attachments/assets/ed314566-1696-43f5-b4c6-d649a3ba32fd" />
<img width="1024" height="569" alt="image" src="https://github.com/user-attachments/assets/dc17db23-5b29-4f7c-b971-b8e3af330b16" />

