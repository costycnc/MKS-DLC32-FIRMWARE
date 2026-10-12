# MKS-DLC32-FIRMWARE  The source code of MKS DLC32.
## Environment construction:
- vscode                        
- platformIO                     
PlatformIOc needs to be installed on vscode.                     
Open Firmware with vscode, and platformIO will be started, In the platform.ini file，                
`default_envs = mks_dlc32_v2_1`                  
Note:We will make a pin suitable for V1.0，Settings corresponding to the selection of coreXY.                  
Then compile and download.

---

# MKS-DLC32 Universal Firmware Automation (SD AutoRun Fork)

This repository contains an optimized, universal fork of the official Makerbase firmware for the **MKS DLC32 V2.1** motherboard, configured for **CoreXY** kinematics (such as hot-wire CNC foam cutters or laser systems).

> 🌍 **Universal Compatibility:** Although this automation was originally developed and tested for **CostyCNC** foam cutters, this firmware is **100% universal**. It works perfectly on **ANY CNC router, laser engraver, or CoreXY machine** in the world, as long as it uses the standard **MKS DLC32 V2.1** mainboard. It does not require any specific brand-locked hardware.

---

## 🛠️ System Architecture & Core Logic

Every universal open-source modification comes from a real-world manufacturing necessity. This project started with a clear production goal: creating a completely standalone machine workflow where a cycle could start instantly **just by inserting the MicroSD card**, without requiring a tethered computer, a Wi-Fi client connection, or manual interface interactions.

### ❌ Hardware Pin Constraints (Failed Implementations)
Our initial development path attempted a classic hardware-triggered approach by wiring a physical macro button directly to different GPIO headers on the board:
1. **EXP1 Header (GPIO 25 Control):** We mapped the physical pinout and wired a button to GPIO 25. It failed due to deep software conflicts. Even with the panel disconnected, the proprietary background graphics libraries (`display_init()` / `MKS_LVGL`) constantly reconfigured the pin state, leading to floating signals and infinite ghost-trigger loops that flooded the serial buffer.
2. **EXP2 Header (GPIO 26 Control):** Shifting to the touchscreen SPI controller lines encountered identical resource locks from the core display system task.
3. **Z-Limit Connector (GPIO 34 Control):** While electrically isolated and tied to an onboard 10kΩ hardware pull-up, the microsecond loop cycle of the ESP32 made mechanical button debouncing unreliable without external analog RC filters.

### 💻 Non-Blocking Software Automation (Final Implementation)
To bypass all hardware constraints, EMI noise, and pin-sharing conflicts, we refactored the logic to let the core framework handle the automation natively through the MicroSD slot itself. Since the board already monitors the card's electrical mounting states via internal variables, we tapped directly into that software routine. 

By combining a non-blocking 3-second scheduler with a filesystem validation step, the machine safely triggers the job streaming cycle purely through card detection. No extra wires, no electrical noise—just pure software efficiency.

### ⚠️ The "\$esp145" Dynamic Parameter Experiment (The Over-Engineering Trap)

After successfully locking down the hardcoded automated routine, we tried to take the firmware to a professional commercial grade. The new goal was to create a native, customizable GRBL string parameter called **`$esp145`**. 

The concept was brilliant on paper:
- Typing `$esp145=myfile.nc` via the serial prompt would save the file target permanently into the ESP32's non-volatile storage (NVS).
- Typing `$esp145=` (blank) would instantly deactivate the entire automation loop, restoring stock factory behavior without needing a re-flash.

#### 🔧 Everything we implemented to build `$esp145`:
1. **Global Declaration:** We injected `StringSetting* esp_auto_file;` in the core architecture of `Grbl_Esp32/src/Settings.cpp` to allocate a dedicated chunk of RAM for the string.
2. **NVS Database Hook:** We wrote a custom static initializer `EspAutoFileInit` in the global scope to map `$esp145` directly into GRBL's core parser, inheriting native properties like automated EEPROM/NVS flash saves (`nvs_set_str`) and prompt visibility (`$$` listing).
3. **Bridge linking:** We introduced `extern StringSetting* esp_auto_file;` at the top of `Grbl_Esp32/src/Protocol.cpp` to create a memory bridge between the independent settings module and the main movement loop.
4. **Dynamic String Traversal:** We modified the infinite execution loop `for(;;)` to dynamically retrieve the raw text buffer using `esp_auto_file->get()`, validating empty array delimiters (`target_file != '\0'`) and formatting variables inside safe RAM heap arrays (`snprintf`).

#### ❌ Why it failed and why we ultimately abandoned it:
Despite the code structure being accurate, we hit severe roadblocks deep within the **C++ static initialization ordering**:
- **Scope Visibility Triggers:** The compiler triggered errors because standard internal system macros like `GRBL_STRING` and `AMIN` change permissions and namespaces across separate modules in this specific Makerbase firmware fork, breaking standard data bindings.
- **The Boot Loop Hazard:** Because `StringSetting` initializes heavily on startup, forcing a custom instance outside the native network loop risked hitting the *Static Initialization Order Fiasco*. This meant `Protocol.cpp` would occasionally read an uninitialized `NULL` pointer at boot, causing immediate hard system crashes before the step generators could even warm up.

#### 🛑 The Unfinished Tasks & The Final Verdict:
To make `$esp145` fully production-ready, we still had to:
- Modify `WebSettings.cpp` to prevent conflicts with other background network protocols.
- Inject a brand new filtering layer inside the touchscreen source tree (`src/mks/MKS_updata.cpp`) because the display currently discards any incoming serial configurations that do not match its four hardcoded network bounds (`[ESP100]`, `[ESP101]`, `[ESP110]`, `[ESP131]`).

At this point, **we realized we were over-complicating a beautiful, working solution.** The scope of the project was stretching out indefinitely, adding bloated layers of software complexity to a machine that just needs to cut material reliably. 

**We decided to stop fighting the framework and abandoned the dynamic parameter.** By stripping down the structural overhead and reverting back to the lean, original hardcoded routine targeting `/costycnc.nc`, we regained 100% compilation safety, zero boot overhead, and an ultra-fluid movement engine. The mode passed, but the raw efficiency of the bits won!

### 🐛 The G-Code Modal Loop Bug: The Hidden Trap of `S0` and `M03`

During testing, we discovered a highly unusual software loop bug triggered by specific G-Code endings. In hot-wire foam cutting, it is common practice **NOT to send `M05` (Spindle Off) immediately** at the end of the toolpath. If the wire turns cold instantly while still inside the foam block during the homing routine, the shrinking material will trap and snap the wire. Keeping the path modally "active" but dropping the heat down via software ensures a clean exit.

However, our automated routine started **re-executing the G-Code file endlessly from the beginning**. The motherboard was not physically rebooting; instead, the file would finish, the machine would wait for exactly 3 seconds (matching our software timer), and then it would start the entire cutting process all over again.

#### 🔍 The Investigation and the Logic Bug:
1. **The Code Suspicion:** Since this happened right after reversing the failed `$esp145` parameter experiment, we initially thought our `Protocol.cpp` clean-up was broken. But the code structure was flawless.
2. **The G-Code Experiments:** To troubleshoot, we tested different final lines:
   - Ending with **`G01 X0 S0`**: The machine repeated the cut indefinitely every 3 seconds.
   - Ending with **`M03 S0`**: The CNC still repeated the cycle, refusing to go into stable standby.
   - **The Solution:** Removing any mention of `M03` or `S0` from the final lines of the G-Code file caused the machine to execute the cut exactly **once** and stop perfectly in a stable state.

#### 🛑 Why this happens (The GRBL Modal Bug):
This is a core architectural bug related to how GRBL handles status reports (\$10) and modal states. When a file ends with an active spindle state (like `M03` or a modally active `S0`), the internal state machine of the MKS firmware doesn't fully clear the buffer. 

Even if the file execution mechanically reaches the last line, the active spindle flag fools the hardware layer into thinking a data stream is still incoming or pending. This prevents the system from triggering a clean, isolated transition back to a true static `Idle`. Our 3-second software sensor (`get_sd_state`) would look at the card, see it was still mounted, and because the system state was hovering in an unstable modal limbo, it would re-inject the `$SD/Run` command, starting the file execution again.

This confirms an unpatched core bug regarding the `M05` execution flow that was already brought up years ago—proving once again that in low-level microcontrollers, **G-Code modal states and software loops are deeply intertwined!**
---

## 🚀 Key Features

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

## 🛠️ How To Use On Any Machine (Stand-Alone Operation)

1. Generate your CNC G-Code cutting path using your preferred CAM software (LaserGRBL, LightBurn, Aspire, etc.).
2. Rename the exported file to exactly **`costycnc.nc`** (ensure lowercase file extension).
3. Copy the file directly to the root directory of a MicroSD card formatted in **FAT32**.
4. Power up your machine (it will sit quietly in `Idle` state).
5. **Insert the MicroSD card:** Within 3 seconds, the board will notice the card, verify the file contents, initialize the axes, and automatically start cutting.
6. Once the execution finishes, the machine returns to its original home position and sleeps back into `Idle` state, waiting for the next card swap.

---

## 📄 License

This project is a custom fork of the Makerbase repository, branching off Bart Dring's core open-source `Grbl_ESP32` architecture. Released under the **GPLv3 License**.

***
Invention and testing credits to [costycnc](https://github.com) - Visit our official website: [costycnc.it](https://costycnc.it)


<img width="768" height="1365" alt="Gemini_Generated_Image_7x95qj7x95qj7x95" src="https://github.com/user-attachments/assets/ed314566-1696-43f5-b4c6-d649a3ba32fd" />
<img width="1024" height="569" alt="image" src="https://github.com/user-attachments/assets/dc17db23-5b29-4f7c-b971-b8e3af330b16" />

