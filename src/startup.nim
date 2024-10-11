# This code is based on https://github.com/raspberrypi/pico-sdk/blob/master/src/rp2_common/pico_crt0/crt0.S

#import std/volatile

const PicoMemoryPlacement {.strdefine.} = "flash"

# In C lang, program starts from main function.
# Nim generates C main function.
# resetHandler proc calls it.
proc main(argc: cint; args: ptr cstring; env: ptr cstring): cint {.importc.}
proc trap {.importc: "__builtin_trap".}

template incPtr[T](p: var ptr T) =
  p = cast[ptr T](cast[uint](p) + sizeof(T).uint)

var
# Following symbols are defined in the linker script in pico_crt0 in pico-sdk.
# So use only their address and don't read the value.
# The linker script assign an address to these symbols and `stackTop.addr` is the way to get the address.
# https://sourceware.org/binutils/docs/ld/Source-Code-Reference.html
  stackTop {.importc: "__StackTop".}: cint
  bssStart {.importc: "__bss_start__".}: cint
  bssEnd {.importc: "__bss_end__".}: cint

when PicoMemoryPlacement != "noFlash":
  var
    etext {.importc: "__etext".}: cint
    dataStart {.importc: "__data_start__".}: cint
    dataEnd {.importc: "__data_end__".}: cint

    scratchXSrc {.importc: "__scratch_x_source__".}: cint
    scratchXStart {.importc: "__scratch_x_start__".}: cint
    scratchXEnd {.importc: "__scratch_x_end__".}: cint

    scratchYSrc {.importc: "__scratch_y_source__".}: cint
    scratchYStart {.importc: "__scratch_y_start__".}: cint
    scratchYEnd {.importc: "__scratch_y_end__".}: cint

  proc copyMem(srcStart, dstStart, dstEnd: ptr cint) =
    var
      src = srcStart
      dst = dstStart

    while dst != dstEnd:
      dst[] = src[]
      incPtr src
      incPtr dst

proc resetHandler {.noconv,
                    exportc,
                    asmNoStackFrame,
                    noreturn,
                    codegenDecl: "[[noreturn, gnu::naked]] $# $#$#".} =
  when PicoMemoryPlacement != "noFlash":
    copyMem etext.addr, dataStart.addr, dataEnd.addr
    copyMem scratchXSrc.addr, scratchXStart.addr, scratchXEnd.addr
    copyMem scratchYSrc.addr, scratchYStart.addr, scratchYEnd.addr

  # Fill BSS with zero.
  var p = bssStart.addr
  while p != bssEnd.addr:
    p[] = 0
    incPtr p

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

  #var interruptVectorTable {.importc.}: array[16, proc () {.noconv.}]

# Bootrom jumps to here.
proc entryPoint {.exportc: "_entry_point",
                  asmNoStackFrame,
                  noreturn,
                  codegenDecl: "[[noreturn, gnu::naked, gnu::section(\".reset\")]] $# $#$#".} =
  when true:
    # This code need to be written as assembler because:
    #   - It must not use stack pointer because it is not set.
    #   - Need to read pointers at the address 0.
    #     - Reading from 0 is undefined behaviour in C
    #       and gcc produces an undefined instruction (.inst 0xdeff)
    #     - https://gcc.gnu.org/bugzilla/show_bug.cgi?id=115770
    when PicoMemoryPlacement != "noFlash":
      asm """
        mov r0, #0
      """
    else:
      asm """
        ldr r0, =interruptVectorTable
      """
    asm """
      @ Load the register address that have the vector table address
      ldr r1, = 0xe0000000 + 0x0000ed08
      @ Set the vector table address at the ROM (0x0) to the register.
      str r0, [r1]
      @ Load the stack address and the reset handler address
      @ from the vector table at the ROM.
      ldmia r0!, {r1, r2}
      msr msp, r1
      @ Load from the vector table at the ROM
      @ and jump
      bx r2
    """
  else:
    const
      PPBBase = 0xe0000000'u
      PPBVTOROffset = 0x0000ed08'u
      # BOOTROM_VTABLE_OFFSET = 0x0'u

    # The address of the register holds the address of vector table.
    const PPBVTOR = cast[ptr ptr UncheckedArray[proc() {.noconv.}]](PPBBase + PPBVTOROffset)

    let pVecTable = cast[ptr UncheckedArray[proc() {.noconv.}]](
                        interruptVectorTable.addr
                    )

    volatileStore PPBVTOR, pVecTable

    # Set stack pointer.
    # You should not use any instructions that uses the stack pointer
    # before assigning a valid address to the stack pointer.
    let stackPtr = pVecTable[][0]
    asm """
      msr msp, %0
      :
      : "r" (`stackPtr`)
    """
    pVecTable[][1]()
