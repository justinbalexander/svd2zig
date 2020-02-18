# Svd2Zig

## Build:

```
zig build
```

## Usage:

```
svd2zig {path/to/svd/file} > path/to/output.zig
zig fmt path/to/output.zig # to prettify
```

## Suggested location to find SVD file:

https://github.com/posborne/cmsis-svd

## Output (after running through zig fmt):

```zig
/// Access control
pub const AC = struct {
    pub const base_address = 0xe000ef90;

    /// Instruction and Data Tightly-Coupled Memory           Control Registers
    pub const ITCMCR = struct {
        pub const address = 0xe000ef90 + 0x0;
        pub const size_type = u32;
        pub const reset_value: size_type = 0x0;
        const write_mask = 0x7f;
        pub fn write(setting: size_type) void {
            const mmio_ptr = @intToPtr(*volatile size_type, address);
            mmio.ptr.* = setting & write_mask;
        }
        pub fn read() size_type {
            const mmio_ptr = @intToPtr(*volatile size_type, address);
            return mmio.ptr.*;
        }

        /// EN
        pub const EN = struct {
            pub const offset = 0;
            pub const width = 1;
            pub const mask = 0x1 << offset;
            pub fn val(setting: u32) u32 {
                return (setting & 0x1) << offset;
            }
        };

        /// RMW
        pub const RMW = struct {
            pub const offset = 1;
            pub const width = 1;
            pub const mask = 0x1 << offset;
            pub fn val(setting: u32) u32 {
                return (setting & 0x1) << offset;
            }
        };

        /// RETEN
        pub const RETEN = struct {
            pub const offset = 2;
            pub const width = 1;
            pub const mask = 0x1 << offset;
            pub fn val(setting: u32) u32 {
                return (setting & 0x1) << offset;
            }
        };

        /// SZ
        pub const SZ = struct {
            pub const offset = 3;
            pub const width = 4;
            pub const mask = 0xf << offset;
            pub fn val(setting: u32) u32 {
                return (setting & 0xf) << offset;
            }
        };
    };
```

