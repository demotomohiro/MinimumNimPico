import std/[strformat]

const PicoSDKPath {.strdefine.} = ""
when PicoSDKPath == "":
  {.error: "Please run 'git clone https://github.com/raspberrypi/pico-sdk.git --branch master --depth 1' and specify the path to Raspberry Pi Pico SDK with `-d:PicoSDKPath=/path/to/pico-sdk`".}

switch("define", "danger")
switch("mm", "none") # use "arc", "orc" or "none"
# Don't need to enable checkAbi unless you use C header.
#switch("define", "checkAbi")
switch("define", "useMalloc")
switch("define", "noSignalHandler")
switch("cpu", "arm")
switch("os", "any")
switch("threads", "off")
switch("gcc.options.linker", "")
switch("arm.any.gcc.exe", "arm-none-eabi-gcc")
switch("arm.any.gcc.linkerexe", "arm-none-eabi-gcc")
# `-ffunction-sections` and `-fdata-sections` in passC and `-Wl,--gc-sections` are optional. They makes output program smaller.
switch("passC", "-mcpu=cortex-m0plus -mthumb -ffunction-sections -fdata-sections")
const LinkerScriptPath = PicoSDKPath & "/src/rp2_common/pico_crt0/rp2040/memmap_no_flash.ld"
switch("passL", &"-mcpu=cortex-m0plus -mthumb -nostartfiles -nodefaultlibs -Wl,--gc-sections -T " & LinkerScriptPath)
