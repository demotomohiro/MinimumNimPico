# This code is based on https://github.com/raspberrypi/pico-sdk/blob/master/src/rp2_common/pico_crt0/crt0.S

import std/volatile

const
  PPBBase = 0xe0000000'u
  PPBVTOROffset = 0x0000ed08'u

# The address of the register holds the address of vector table.
const PPBVTOR = cast[ptr ptr UncheckedArray[proc() {.noconv.}]](PPBBase + PPBVTOROffset)

# In C lang, program starts from main function.
# Nim generates C main function.
# resetHandler proc calls it.
proc main(argc: cint; args: ptr cstring; env: ptr cstring): int {.importc.}
proc trap {.importc: "__builtin_trap".}

var
# Following symbols are defined in the linker script in pico_crt0 in pico-sdk.
# So use only their address and don't read the value.
# The linker script assign an address to these symbols and `stackTop.addr` is the way to get the address.
# https://sourceware.org/binutils/docs/ld/Source-Code-Reference.html
  stackTop {.importc: "__StackTop".}: cint
  bssStart {.importc: "__bss_start__".}: cint
  bssEnd {.importc: "__bss_end__".}: cint

proc resetHandler {.noconv, exportc, noreturn, codegenDecl: "[[noreturn, gnu::naked]] $# $#$#".} =
  # Fill BSS with zero.
  var p = bssStart.addr
  while p != bssEnd.addr:
    p[] = 0
    p = cast[ptr int32](cast[uint32](p) + 4'u32)

  discard main(1, nil, nil)
  trap()

proc defaultIsr {.noconv, exportc.} =
  trap()

when false:
  var interruptVectorTable {.codegenDecl: "[[gnu::section(\".vectors\")]] $# $# ".} : array[16, proc() {.noconv.}]
  #[
    = [
      cast[proc() {.noconv.}](stackTop.addr),
      resetHandler,
      defaultIsr, # NMI
      defaultIsr, # hardfault
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr, # svcall
      defaultIsr,
      defaultIsr,
      defaultIsr, # pendsv
      defaultIsr, # systick
    ]
  ]#
else:
  {.emit:"""/*VARSECTION*/
    [[gnu::section(".vectors")]] void (*interruptVectorTable[])() = {
      (void (*)())&__StackTop,
      resetHandler,
      defaultIsr,   // NMI
      defaultIsr,   // hardfault
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,
      defaultIsr,   // svcall
      defaultIsr,
      defaultIsr,
      defaultIsr,   // pendsv
      defaultIsr,   // systick
    };
  """.}

  var interruptVectorTable {.importc.}: array[16, proc () {.noconv.}]

# Bootrom jumps to here.
proc entryPoint {.exportc: "_entry_point", noreturn, codegenDecl: "[[noreturn, gnu::naked, gnu::section(\".reset\")]] $# $#$#".} =
  volatileStore PPBVTOR, cast[ptr UncheckedArray[proc() {.noconv.}]](interruptVectorTable.addr)

  # Set stack pointer.
  # You should not use any instructions that uses the stack pointer
  # before assigning a valid address to the stack pointer.
  let stackPtr = stackTop.addr
  asm """
    msr msp, %0
    :
    : "r" (`stackPtr`)
  """
  interruptVectorTable[1]()
