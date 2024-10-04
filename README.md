# Minimum Nim Pico
This is a minimum program runs on [Raspberry Pi Pico](https://www.raspberrypi.com/documentation/microcontrollers/silicon.html) written in [Nim](https://nim-lang.org).
It doesn't uses .c and CMake files in [Raspberry Pi Pico SDK](https://github.com/raspberrypi/pico-sdk) but uses linker scripts and assembly code.
This minimum program just keep outputing the message "This is minimum pure Nim pico program!" to UART and blinking LED every second.

There are tools and libraries, [Raspberry Pi Pico SDK for Nim](https://github.com/EmbeddedNim/picostdlib) or [PicoSDK4Nim](https://github.com/demotomohiro/picosdk4nim) that wrap Raspberry Pi Pico SDK so that types and functions in the SDK can be used in Nim code and user can produce a program runs on Raspberry Pi Pico.
But these tools are complicated because Raspberry Pi Pico SDK uses [CMake](https://cmake.org) as build tools and SDK users need to use it to produce a pico program.
So these tools need to produce CMake files and run CMake to build.
But combining CMake and Nim's build system is complicated.
Using .c and header files in Pico SDK without using CMake is also not easy because these files include header files in different places and uses many defines.
If I could build the program for Raspberry Pi Pico without using Raspberry Pico SDK, I don't need to use CMake and I can build programs for Pico only with simple config.nims file just set several compile options for cross compiling.
But I need to implements SDK myself.

## Requirements
- GCC for cross compiling to RP2040 (arm-none-eabi-gcc)
  - Read "Appendix C: Manual toolchain setup" in [Getting Started with the Raspberry Pi Pico-Series](https://rptl.io/pico-get-started)
  - If you are Gentoo Linux user: https://wiki.gentoo.org/wiki/Crossdev
- Nim 2.0.8
- [Raspberry Pi Pico SDK](https://github.com/raspberrypi/pico-sdk)
- [picotool](https://github.com/raspberrypi/picotool) (optional)
  - Used to generate uf2 file

## How to build
```console
$ git clone https://github.com/raspberrypi/pico-sdk.git
$ git clone https://github.com/demotomohiro/minimumNimPico.git
$ cd minimumNimPico/src
$ nim c -d:PicoSDKPath=../../pico-sdk uartReg.nim
```
If it worked without errors, it produces `uartReg`.

In default, produced binary is written to the flash memory on Raspberry Pi Pico. Adding `-d:PicoMemoryPlacement="noFlash"` option to Nim produces "No Flash" build.
For example:
```console
nim c -d:PicoSDKPath=../../pico-sdk -d:PicoMemoryPlacement="noFlash" uartReg.nim
```
No Flash build is not written to the flash memory of Raspberry Pi Pico but loaded to SRAM. So when the Pico lost power, loaded program gone.

## How to run
There are 2 ways to load and run the program on Raspberry Pi Pico:
Convert to uf2 file or use OpenOCD.
Using uf2 file is easier but if you frequently change code and run or use GDB, using OpenOCD would be better.
- UF2
You need to build [picotool](https://github.com/raspberrypi/picotool).
Following command convert `uartReg` to `uartReg.uf2`.
```console
picotool uf2 convert uartReg -t elf uartReg.uf2
```
Plug Raspberry Pi Pico into the USB port of your PC with holding down `BOOTSEL` button on the Pico. Then it runs in USB mass storage mode and and a new storage should appears on your PC as if USB flash memory was plugged in.
Then copy `uartReg.uf2` to the storage.
Right after you copied it, the Pico runs the program and you will see the LED on Pico blinking.
If you want to load uf2 file again, disconnect the Pico and plug it again in the same way.

- OpenOCD
  Read:
  - Appendix A: Debugprobe in [Getting Started with the Raspberry Pi Pico-Series](https://rptl.io/pico-get-started)
  - https://github.com/demotomohiro/picosdk4nim#loading-elf-file-to-pico-using-picoprobe-without-writing-to-flash-memory

`uartReg` output the message from GPIO 0 (PIN0 on Raspberry Pi Pico board).
You can read the message sent from Raspberry Pi Pico through UART:
```console
$ minicom -D /dev/ttyACM0 -b 115200
```

## Learning Resources
- [RP2040 Datasheet](https://www.raspberrypi.com/documentation/microcontrollers/silicon.html)
- [A bare metal programming guide](https://github.com/cpq/bare-metal-programming-guide)
- [RP2040 Boot Sequence](https://vanhunteradams.com/Pico/Bootloader/Boot_sequence.html)
- [Cortex-M0 Devices Generic User Guide](https://developer.arm.com/documentation/dui0662/latest/)
