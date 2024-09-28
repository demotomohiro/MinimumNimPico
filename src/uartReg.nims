import std/[strformat, os]

const PicoSDKPath {.strdefine.} = ""
when PicoSDKPath == "":
  {.error: "Please run 'git clone https://github.com/raspberrypi/pico-sdk.git --branch master --depth 1' and specify the path to Raspberry Pi Pico SDK with `-d:PicoSDKPath=/path/to/pico-sdk`".}
const PicoSDKPathAbs = PicoSDKPath.expandTilde.absolutePath()

const
  # "flash": Put code on flash memory
  # "noFlash": Put code on SRAM and don't use flash. So code is lost when power is lost.
  PicoMemoryPlacement {.strdefine.} = "flash"

  # Size of flash memory
  # Check `PICO_FLASH_SIZE_BYTES` in https://github.com/raspberrypi/pico-sdk/tree/master/src/boards/include/boards
  # if you use a board other than Raspberry Pi Pico
  PicoFlashSize {.strdefine.} = "2 * 1024 * 1024"

  # Select board name from
  # https://github.com/raspberrypi/pico-sdk/tree/master/src/boards/include/boards
  # without '.h' suffix.
  PicoBoard {.strdefine.} = "pico"

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
const
  LinkerScript = when PicoMemoryPlacement == "flash":
                   "memmap_default.ld"
                 elif PicoMemoryPlacement == "noFlash":
                   "memmap_no_flash.ld"
  LinkerScriptPath = &"{PicoSDKPathAbs}/src/rp2_common/pico_crt0/rp2040/{LinkerScript}"
switch("passL", &"-mcpu=cortex-m0plus -mthumb -nostartfiles -nodefaultlibs -Wl,--gc-sections -T {LinkerScriptPath}")
# Generate map file
switch("passL", "-Wl,-Map=uartReg.map")

when PicoMemoryPlacement != "noFlash":
  let generatedFileDir = nimcacheDir() & "/generated"

  block:
    let generatedPicoIncDir = generatedFileDir & "/pico"
    generatedPicoIncDir.mkDir()

    let picoBoardHeader = fmt"{PicoSDKPathAbs}/src/boards/include/boards/{PicoBoard}.h"
    # Following generated header files are included by
    # https://github.com/raspberrypi/pico-sdk/blob/master/src/rp2040/boot_stage2/compile_time_choice.S
    writeFile(generatedPicoIncDir & "/config_autogen.h",
              &"#include \"{picoBoardHeader}\"\n")
    writeFile(generatedPicoIncDir & "/version.h",
              """
#define PICO_SDK_VERSION_MAJOR    2
#define PICO_SDK_VERSION_MINOR    0
#define PICO_SDK_VERSION_REVISION 0
#define PICO_SDK_VERSION_STRING   "2.0.0"
""")

  block:
    let
      backendCCompiler = get("arm.any.gcc.exe")
      includeDirs = &"-I{PicoSDKPathAbs}/src/rp2040/boot_stage2/asminclude " &
                    &"-isystem {PicoSDKPathAbs}/src/rp2040/hardware_regs/include " &
                    &"-isystem {PicoSDKPathAbs}/src/rp2040/boot_stage2/include " &
                    &"-isystem {PicoSDKPathAbs}/src/common/pico_base_headers/include " &
                    &"-isystem {generatedFileDir} " &
                    &"-isystem {PicoSDKPathAbs}/src/rp2040/pico_platform/include " &
                    &"-isystem {PicoSDKPathAbs}/src/rp2_common/pico_platform_compiler/include " &
                    &"-isystem {PicoSDKPathAbs}/src/rp2_common/pico_platform_sections/include " &
                    &"-isystem {PicoSDKPathAbs}/src/rp2_common/pico_platform_panic/include "
      elfOutputPath = generatedFileDir & "/bs2_default.elf"
      input = &"{PicoSDKPathAbs}/src/rp2040/boot_stage2/compile_time_choice.S"

    exec &"{backendCCompiler} -DPICO_32BIT=1 -DPICO_BOARD=\"{PicoBoard}\" -DPICO_BUILD=1 -DPICO_NO_HARDWARE=0 -DPICO_ON_DEVICE=1 -DPICO_RP2040=1 {includeDirs} -mcpu=cortex-m0plus -mthumb -g -O3 -DNDEBUG  -nostartfiles -Wl,--script={PicoSDKPathAbs}/src/rp2040/boot_stage2/boot_stage2.ld -o {elfOutputPath} {input}"
    let binOutputPath = generatedFileDir & "/bs2_default.bin"
    exec &"arm-none-eabi-objcopy -Obinary {elfOutputPath} {binOutputPath}"
    let paddedChecksummedOutputPath = generatedFileDir & "/bs2_default_padded_checksummed.S"
    exec &"python {PicoSDKPathAbs}/src/rp2040/boot_stage2/pad_checksum -s 0xffffffff {binOutputPath} {paddedChecksummedOutputPath}"
    switch("passL", paddedChecksummedOutputPath)

  block:
    let
      generatedLDDir = generatedFileDir & "/picold"
      outLdPath = generatedLDDir & "/pico_flash_region.ld"
    generatedLDDir.mkDir()
    # outLdPath is included by https://github.com/raspberrypi/pico-sdk/blob/master/src/rp2_common/pico_crt0/rp2040/memmap_default.ld
    # https://github.com/raspberrypi/pico-sdk/tree/master/src/rp2_common/pico_standard_link
    writeFile outLdPath, &"FLASH(rx) : ORIGIN = 0x10000000, LENGTH = ({PicoFlashSize})\n"
    switch("passL", "-Wl,-L" & generatedLDDir)
