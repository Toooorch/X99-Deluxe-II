#h1 X99DeluxeII
All my files (including 3rd party work) for X99 Deluxe II based hack.

Currenly used Clover version: **Clover_v2.4k_r4077** [clover](https://sourceforge.net/projects/cloverefiboot/)

#h2 **Setup:**
- Asus X99 Deluxe II Rev 1.02 [asus](https://www.asus.com/us/Motherboards/X99-DELUXE-II/)
- i7 5820K 3.3Ghz > O.C. 3.8Ghz (There are some base support hints on OS X for Haswell-E)
- nVidia 1080 Ti (nVidia WEB Drivers)
- G.Skill Trident Z RGB 64GB 3200Mhz > O.C. 3600MHZ
- Seasonic Prime Titanium 850W

- Samsung 960 PRO 512GB
- Samsung 850 EVO 250G
- WD Blue 1TB
- Apple HDD 1TB

#h2 **Drivers & Patches**
**Audio:**
- VoodooHDA-2.8.8 > then manually install 2.8.9.kext (works great in this order) [repo](https://sourceforge.net/projects/voodoohda/)

**Network:**
- WiFi - OOB
- BT - BrcmBluetoothInjector.kext [repo](https://github.com/the-darkvoid/BrcmPatchRAM)
- Intel® I218V - IntelMausiEthernet.kext [repo](https://github.com/Mieze/IntelMausiEthernet)
- Intel® I211-A

**USB**
- X99_Injector_USB_3.kext

**ACPI Tables**
- Piker Alpha ssdtPRGen.sh [repo](https://github.com/Piker-Alpha/ssdtPRGen.sh)
- freqVectorsEdit.sh [repo](https://github.com/Piker-Alpha/freqVectorsEdit.sh)

**XCPM**
- Piker Alpha Patches

**NVMe**
- Piker Alpha Patch

#h2 **BIOS Settings:**
Changed values, default values on X99 are not listen.

Boot
- CMS - Disabled
- Secure Boot - Other OS

Advanced USB Configuration
- EHCI Hand-Off - Enabled

Onboard Devices
- ASMEDIA USB 3.1 Battery Charging Support - Enabled

#h2 **System Services**
**iMessage and iCloud services:**
use iMessageDebug for extract ROM and MLB(Board Serial Number) from
"real" Mac machine then insert your numbers to config.plist

**never install OS with those numbers** otherwise Apple will block them
and you will have to call Apple support (and that is horrible thing trust me).
