# Minimum Nim Pico
This is a minimum program runs on [Raspberry Pi Pico](https://www.raspberrypi.com/documentation/microcontrollers/silicon.html) written in [Nim](https://nim-lang.org). 
It doesn't uses files in [Raspberry Pi Pico SDK](https://github.com/raspberrypi/pico-sdk) excepts the linker script in https://github.com/raspberrypi/pico-sdk/tree/master/src/rp2_common/pico_crt0/rp2040
This minimum program just output a message "This is minimum pure Nim pico program!" to UART and stops.
Currently supports only "No Flash" build. That means you need to use Picoprobe, OpenOCD and GDB to load the program to Raspberry Pi Pico. It is written only to the SRAM, not to the flash memory on Raspberry Pi Pico. So when the Pico lost power, loaded program gone.

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
https://github.com/demotomohiro/picosdk4nim/blob/main/README.md#loading-elf-file-to-pico-using-picoprobe

You can read the message sent from Raspberry Pi Pico through UART:
```console
$ minicom -D /dev/ttyACM0 -b 115200
```
