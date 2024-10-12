import std/volatile
import registerAccess

when false:
  const PicoSDKPath {.strdefine.} = ""
  const PicoSDKSrc = PicoSDKPath & "/src/"
  {.compile(PicoSDKSrc & "rp2_common/pico_crt0/crt0.S",
            "-DPICO_NO_FLASH=1 -DPICO_RP2040=1 -I" & PicoSDKSrc & "common/pico_base_headers/include" &
            " -I" & PicoSDKSrc & "rp2040/pico_platform/include/" &
            " -I" & PicoSDKSrc & "rp2_common/pico_platform_compiler/include/" &
            " -I" & PicoSDKSrc & "rp2040/hardware_regs/include" &
            " -I" & PicoSDKSrc & "rp2_common/pico_platform_sections/include" &
            " -I" & PicoSDKSrc & "rp2_common/pico_platform_panic/include" &
            " -I" & PicoSDKSrc & "common/pico_binary_info/include" &
            " -I" & PicoSDKSrc & "rp2_common/pico_bootrom/include" &
            #" -I" & PicoSDKSrc & "" &
            " -I" & PicoSDKSrc & "/common/boot_picobin_headers/include").}
else:
  import startup

proc breakPoint =
  asm "bkpt #0xab"

type
  ResetsHw = object
    reset: ioRw32
    wdsel: ioRw32
    resetDone: ioRo32

const
  ResetsBase          = 0x4000_c000'u
  ResetsResetUART0Bit = 1'u32 shl 22'u32
  ResetsResetPADS_BANK0Bit = 1'u32 shl 8'u32
  ResetsResetIO_BANK0Bit = 1'u32 shl 5'u32

let resetsHW {.volatile.} = cast[ptr ResetsHW](ResetsBase)

type
  ClockKind = enum
    ckGpOut0 = 0,
    ckGpOut1 = 1,
    ckGpOut2 = 2,
    ckGpOut3 = 3,
    ckRef = 4,
    ckSys = 5,
    ckPeri = 6,
    ckUsb = 7,
    ckAdc = 8,
    ckRtc = 9

  ClockHw = object
    ctrl: ioRw32
    divisor: ioRw32
    selected: ioRo32

  ClocksHw = object
    clk: array[ClockKind, ClockHw]

const
  ClocksClkCtrlEnableBit = 1'u32 shl 11'u32
  ClocksClkPeriCtrlAUXSRCBits = 7'u32 shl 5'u32

var clocksHw {.volatile.} = cast[ptr ClocksHw](0x40008000'u32)

type
  RoscHw = object
    ctrl: ioRw32

var roscHw {.volatile.} = cast[ptr RoscHw](0x40060000'u32)

type
  WatchdogHw = object
    ctrl: ioRw32
    load: ioRw32
    reason: ioRo32
    scratch: array[8, ioRw32]
    tick: ioRw32

var watchdogHw {.volatile.} = cast[ptr WatchdogHw](0x40058000'u32)

proc initClocks =
  # Set ring oscillator, rclocks and tick to known state,
  # even if their register values are the same to reset values.
  # They can be different from reset value because they can be
  # changed by the program ran before this program.

  # `clk_ref` and `clk_sys` generate clock from Ring Oscillator.
  # Don't use crystal oscillator as using ring oscillator is simpler
  # and you can design a board without crystal oscillator.
  hwWriteMasked(roscHw.ctrl, 0xfab shl 12, 0xfff shl 12)

  hwClearBits(clocksHw.clk[ckRef].ctrl, 3)
  while (clocksHw.clk[ckRef].selected.uint32 and 1'u32) != 1'u32:
    discard
  clocksHw.clk[ckRef].divisor = 0x100'u32.ioRw32

  hwClearBits(clocksHw.clk[ckSys].ctrl, 1)
  while (clocksHw.clk[ckSys].selected.uint32 and 1'u32) != 1'u32:
    discard
  clocksHw.clk[ckSys].divisor = 0x100'u32.ioRw32

  # clk_peri is used by UART.
  hwClearBits(clocksHw.clk[ckPeri].ctrl, ClocksClkCtrlEnableBit)
  hwWriteMasked(clocksHw.clk[ckPeri].ctrl, 0'u32, ClocksClkPeriCtrlAUXSRCBits)
  hwSetBits(clocksHw.clk[ckPeri].ctrl, ClocksClkCtrlEnableBit)
  clocksHw.clk[ckPeri].divisor = 0x100'u32.ioRw32

  # `TIMER.TIMERAWL` is incremented every `WATCHDOG.TICK.CYCLES`
  # cycle of `clk_ref`.
  # Suppose ring oscillator runs at a nominal 6.5MHz.
  # Set 65 to tick so that timerHw.timeRawL is incremented
  # 100_000 times per second.
  watchdogHw.tick = (0x200 + 65).ioRw32

type
  TimerHw = object
    dummy: array[9, int32]
    timeRawH: ioRo32
    timeRawL: ioRo32

var timerHw {.volatile.} = cast[ptr TimerHw](0x40054000)

proc busyWaitMilliSec(delay: int32) =
  let
    delayT = delay.uint32 * 100
    start = timerHw.timeRawL.uint32
  while (timerHw.timeRawL.uint32 - start) <= delayT:
    discard

const NumBank0GPIOs = 30

type
  GPIOStatusControl = object
    status: ioRo32
    ctrl: ioRw32

  IOBank0Hw = object
    io: array[NumBank0GPIOs, GPIOStatusControl]

var ioBank0Hw {.volatile.} = cast[ptr IOBank0Hw](0x4001_4000)

type
  PadsBankHw = object
    voltageSelect: ioRw32
    gpios: array[NumBank0GPIOs, ioRw32]

var padsBankHw {.volatile.} = cast[ptr PadsBankHw](0x4001_c000'u)

const
  PadsBank0GPIOODBit = 1'u32 shl 7
  PadsBank0GPIOIEBit = 1'u32 shl 6

proc gpioSetUart(gpio: int) =
  hwWriteMasked(padsBankHw.gpios[gpio], PadsBank0GPIOIEBit,
                PadsBank0GPIOODBit or PadsBank0GPIOIEBit)

  ioBank0Hw.io[gpio].ctrl = 2.ioRw32

type
  # SIO doesn't support atomic access
  SioHw = object
    somePadding0: array[4, uint32]
    gpioOut: uint32
    gpioOutSet: uint32
    gpioOutClr: uint32
    gpioOutXor: uint32
    gpioOE: uint32

var sioHw {.volatile.} = cast[ptr SioHw](0xd0000000)

proc ledOn =
  ioBank0Hw.io[25].ctrl = 5.ioRw32
  sioHw.gpioOE = 1'u32 shl 25
  sioHw.gpioOut = 1'u32 shl 25

proc ledFlip =
  sioHw.gpioOutXor = 1'u32 shl 25

type
  UartHw = object
    dr: ioRw32
    rsr: ioRw32
    somePadding0: array[4, uint32]
    fr: ioRo32
    somePadding1: array[1, uint32]
    ilpr: ioRw32
    ibrd: ioRw32
    fbrd: ioRw32
    lcrh: ioRw32
    cr: ioRw32
    ifls: ioRw32
    imsc: ioRw32
    ris: ioRo32
    mis: ioRo32
    icr: ioRw32
    dmacr: ioRw32

const
  UartFRTXFFBit = 1'u32 shl 5
  UartLCRHWLenLSB = 5'u32
  UartLCRHWLenBits = 0b11'u32 shl 5
  UartLCRHFEnBit = 1'u32 shl 4
  UartLCRHStp2LSB = 3'u32
  UartLCRHStp2Bit = 1'u32 shl 3
  UartLCRHEPSBit = 1'u32 shl 2
  UartLCRHPEnBit = 0b10'u32
  UartCRRXEBit = 1'u32 shl 9
  UartCRTXEBit = 1'u32 shl 8
  UartCRUartEnBit = 1'u32

var uart0hw {.volatile.} = cast[ptr UartHw](0x4003_4000'u32)

proc uartDisableBeforeLCRWrite(): uint32 =
  let crSave = uart0hw.cr.uint32

  if (crSave and UartCRUartEnBit) == 1:
    uart0hw.cr.hwClearBits(UartCRUartEnBit or UartCRTXEBit or UartCRRXEBit)

  crSave

proc uartWriteLCRBitsMasked(values, writeMask: uint32) =
  let crSave = uartDisableBeforeLCRWrite()
  hwWriteMasked(uart0hw.lcrh, values, writeMask)
  uart0hw.cr = crSave.ioRw32

proc uartSetBaudrate(baudRate: static uint32) =
  const
    ClkPeri = when true:
                # Suppose clk_peri was initialized in `initClocks`.
                # So it should be the same to ROSC.
                6_000_000'u32
              else:
                # Suppose clk_peri was initialize in clocks_init in
                # pico-sdk/src/rp2_common/hardware_clocks/clocks.c
                # and equals to clk_sys.
                125_000_000'u32
    UARTCLK = ClkPeri

  # See 4.2.3.1. in
  # https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
  when UARTCLK.int64 < 16.int64 * baudRate.int64:
    {.warning: "UARTCLK is too low or baudRate is too high"}
  elif UARTCLK.int64 > 16.int64 * 65535.int64 * baudRate.int64:
    {.warning: "UARTCLK is too high or baudRate is too low"}

  # baudRateDiv = UARTCLK / (16 * Baud Rate)
  # baudRateDiv * 2^7 = (UARTCLK * 2^7)/ (16 * baudRate)
  #                   = (UARTCLK * 2^3) / baudRate
  const baudRateDiv2_7 = (8 * UARTCLK.int64) div baudRate.int64
  const
    baseIbrd = baudRateDiv2_7 shr 7
    (ibrd, fbrd) = when baseIbrd == 0:
                     (1'u32, 0'u32)
                   elif baseIbrd >= 65535:
                     (65535'u32, 0'u32)
                   else:
                     (baseIbrd.uint32, (((baseIbrd and 0x7f) + 1) div 2).uint32)
  uart0hw.ibrd = ibrd.ioRw32
  uart0hw.fbrd = fbrd.ioRw32

  uartWriteLCRBitsMasked(0, 0)

proc uartSetFormat(dataBits, stopBits: uint) =
  uartWriteLCRBitsMasked(((dataBits - 5'u32) shl UartLCRHWLenLSB) or
                         ((stopBits - 1'u32) shl UartLCRHStp2LSB),
                         UartLCRHWLenBits or
                         UartLCRHStp2Bit or
                         UartLCRHPEnBit or
                         UartLCRHEPSBit)

proc uartInit =
  uartSetBaudrate(115200)
  uartSetFormat(8, 1)
  hwSetBits(uart0hw.lcrh, UartLCRHFEnBit)
  uart0hw.cr = (UartCRUartEnBit or UartCRTXEBit or UartCRRXEBit).ioRw32

proc uartWrite(text: static string) =
  for i in text:
    while (uart0hw.fr.uint32 and UartFRTXFFBit) != 0:
      discard
    uart0hw.dr = i.ioRw32

when false:
  proc uartWriteBin(x: uint32) =
    for i in 0..31:
      if (i and 7) == 0:
        while (uart0hw.fr.uint32 and UartFRTXFFBit) != 0:
          discard
        uart0hw.dr = ioRw32 ' '
      while (uart0hw.fr.uint32 and UartFRTXFFBit) != 0:
        discard
      uart0hw.dr = ioRw32(if (x and (1'u32 shl (31 - i))) == 0: '0' else: '1')

proc main =
  initClocks()

  const resetMask = ResetsResetUART0Bit or ResetsResetPADS_BANK0Bit or ResetsResetIO_BANK0Bit
  resetsHW.reset.hwSetBits(resetMask)
  resetsHW.reset.hwClearBits(resetMask)
  while ((not resetsHW.resetDone.uint32) and resetMask) != 0:
    discard

  gpioSetUart(0)
  gpioSetUart(1)

  uartInit()

  ledOn()

  while true:
    uartWrite("This is minimum pure Nim pico program!\r\n")
    ledFlip()
    busyWaitMilliSec(1_000)

main()

proc exit {.exportc.} =
  # exit function called from `pico_crt0/crt0.S`.
  # It says `exit` should not return.
  discard

proc terminate {.exportcpp: "nimTerminate".} =
  while true:
    discard

# This variable is defined in
# libstdc++-v3/libsupc++/eh_unex_handler.cc
# libstdc++-v3/libsupc++/unwind-cxx.h
# in GCC

{.emit: """
#include <exception>
namespace __cxxabiv1 {
std::terminate_handler __terminate_handler = nimTerminate;
}
""".}
