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

type
  ResetsHw = object
    reset: ioRw32
    wdsel: ioRw32
    resetDone: ioRo32

const
  ResetsBase          = 0x4000_c000'u
  ResetsResetUART0Bit = 1'u32 shl 22'u32

let resetsHW {.volatile.} = cast[ptr ResetsHW](ResetsBase)

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
  # Suppose clk_peri was initialize in clocks_init in
  # pico-sdk/src/rp2_common/hardware_clocks/clocks.c
  # and equals to clk_sys.
  const
    ClkPeri = 125_000_000'u32
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

proc uartWrite(text: string) =
  for i in text:
    while (uart0hw.fr.uint32 and UartFRTXFFBit) != 0:
      discard
    uart0hw.dr = i.ioRw32

proc main =
  resetsHW.reset.hwSetBits(ResetsResetUART0Bit)
  resetsHW.reset.hwClearBits(ResetsResetUART0Bit)
  while (resetsHW.resetDone.uint32 and ResetsResetUART0Bit) == 0:
    discard

  gpioSetUart(0)
  gpioSetUart(1)

  uartInit()
  uartWrite("This is minimum pure Nim pico program!")

main()

proc exit {.exportc.} =
  # exit function called from `pico_crt0/crt0.S`.
  # It says `exit` should not return.
  discard
