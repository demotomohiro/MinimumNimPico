# https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
#   2.1.2. Atomic Register Access
# https://github.com/raspberrypi/pico-sdk/blob/master/src/rp2_common/hardware_base/include/hardware/address_mapped.h

import std/volatile

type
  ioRw32* = distinct uint32
  ioRo32* = distinct uint32

const
  #RegAliasRWBits  = 0x0000'u32
  RegAliasXorBits = 0x1000'u32
  RegAliasSetBits = 0x2000'u32
  RegAliasClrBits = 0x3000'u32

template hwModifyBits(regAddr: var ioRw32; mask: uint32; regAlias: uint32) =
  volatileStore(cast[ptr uint32](cast[uint32](regAddr.addr) or regAlias), mask)

template hwSetBits*(regAddr: var ioRw32; mask: uint32) =
  hwModifyBits(regAddr, mask, RegAliasSetBits)

template hwClearBits*(regAddr: var ioRw32; mask: uint32) =
  hwModifyBits(regAddr, mask, RegAliasClrBits)

template hwXorBits*(regAddr: var ioRw32; mask: uint32) =
  hwModifyBits(regAddr, mask, RegAliasXorBits)

template hwWriteMasked*(regAddr: var ioRw32; values, writeMask: uint32) =
  hwXorBits(regAddr, (regAddr.uint32 xor values) and writeMask)
