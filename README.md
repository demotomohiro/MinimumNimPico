# Minimum Nim Pico
This is a minimum program runs on [Raspberry Pi Pico](https://www.raspberrypi.com/documentation/microcontrollers/silicon.html) written in [Nim](https://nim-lang.org).
It doesn't uses files in [Raspberry Pi Pico SDK](https://github.com/raspberrypi/pico-sdk) excepts the linker script in https://github.com/raspberrypi/pico-sdk/tree/master/src/rp2_common/pico_crt0/rp2040
This minimum program just output the message "This is minimum pure Nim pico program!" to UART and stops.
Currently supports only "No Flash" build. That means you need to use Picoprobe, OpenOCD and GDB to load the program to Raspberry Pi Pico. It is written only to the SRAM, not to the flash memory on Raspberry Pi Pico. So when the Pico lost power, loaded program gone.

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

## How to build
```console
$ git clone https://github.com/demotomohiro/minimumNimPico.git
$ cd minimumNimPico/src
$ nim c -d:PicoSDKPath=/path/to/pico-sdk uartReg.nim
```

## How to run
Read:
https://github.com/demotomohiro/picosdk4nim#loading-elf-file-to-pico-using-picoprobe-without-writing-to-flash-memory

You can read the message sent from Raspberry Pi Pico through UART:
```console
$ minicom -D /dev/ttyACM0 -b 115200
```

## Learning Resources
- [RP2040 Datasheet](https://www.raspberrypi.com/documentation/microcontrollers/silicon.html)
- [A bare metal programming guide](https://github.com/cpq/bare-metal-programming-guide)
- [Cortex-M0 Devices Generic User Guide](https://developer.arm.com/documentation/dui0662/latest/)
