# svd2Zig

Generate
[Zig](https://ziglang.org/)
header files from
[CMSIS-SVD](http://www.keil.com/pack/doc/CMSIS/SVD/html/index.html)
files for accessing MMIO registers.

The entire specification is not completely supported yet. The header file that
was needed and prompted this repository was for the STM32F767ZG, which is
completely translated into Zig.

Feel free to send pull requests to flesh out the parts of the specification that
are missing for your project.

The output is intentionally formatted in the usual C style so that simple
text completion capabilities can be used to quickly find the correct register
values and fields. This eliminates the need for a language server protocol
extension, at the expense of not following the Zig style guide.

## Build:

```
zig build -Drelease-safe
```

## Usage:

```
./zig-cache/bin/svd2zig path/to/svd/file > path/to/output.zig
zig fmt path/to/output.zig # to prettify
```

## Suggested location to find SVD file:

https://github.com/posborne/cmsis-svd

## Sample Output (after running through zig fmt):

```zig
/// Access control
pub const AC_BASE_ADDRESS = 0xe000ef90;

/// Instruction and Data Tightly-Coupled Memory           Control Registers
pub const AC_ITCMCR_ADDRESS = 0xe000ef90 + 0x0;
pub const AC_ITCMCR_RESET_VALUE = 0x0;
pub inline fn AC_ITCMCR_Write(setting: u32) void {
    const write_mask = 0x7f;
    const mmio_ptr = @intToPtr(*volatile u32, AC_ITCMCR_ADDRESS);
    mmio_ptr.* = setting & write_mask;
}
pub inline fn AC_ITCMCR_Read() u32 {
    const mmio_ptr = @intToPtr(*volatile u32, AC_ITCMCR_ADDRESS);
    return mmio_ptr.*;
}

/// EN
pub const AC_ITCMCR_EN_OFFSET = 0;
pub const AC_ITCMCR_EN_MASK = 0x1 << AC_ITCMCR_EN_OFFSET;
pub inline fn AC_ITCMCR_EN(setting: u32) u32 {
    return (setting & 0x1) << AC_ITCMCR_EN_OFFSET;
}

/// RMW
pub const AC_ITCMCR_RMW_OFFSET = 1;
pub const AC_ITCMCR_RMW_MASK = 0x1 << AC_ITCMCR_RMW_OFFSET;
pub inline fn AC_ITCMCR_RMW(setting: u32) u32 {
    return (setting & 0x1) << AC_ITCMCR_RMW_OFFSET;
}

/// RETEN
pub const AC_ITCMCR_RETEN_OFFSET = 2;
pub const AC_ITCMCR_RETEN_MASK = 0x1 << AC_ITCMCR_RETEN_OFFSET;
pub inline fn AC_ITCMCR_RETEN(setting: u32) u32 {
    return (setting & 0x1) << AC_ITCMCR_RETEN_OFFSET;
}

/// SZ
pub const AC_ITCMCR_SZ_OFFSET = 3;
pub const AC_ITCMCR_SZ_MASK = 0xf << AC_ITCMCR_SZ_OFFSET;
pub inline fn AC_ITCMCR_SZ(setting: u32) u32 {
    return (setting & 0xf) << AC_ITCMCR_SZ_OFFSET;
}
```

