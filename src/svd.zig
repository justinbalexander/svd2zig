const std = @import("std");
const builtin = @import("builtin");
const Buffer = std.Buffer;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const warn = std.debug.warn;

const SvdTranslationError = error{NotEnoughInfoToTranslate};

/// Top Level
pub const Device = struct {
    name: Buffer,
    version: Buffer,
    description: Buffer,
    cpu: ?Cpu,

    /// Bus Interface Properties
    /// Smallest addressable unit in bits
    address_unit_bits: ?u32,

    /// The Maximum data bit width accessible within a single transfer
    width: ?u32,

    /// Start register default properties
    size: ?u32,
    reset_value: ?u32,
    reset_mask: ?u32,
    peripherals: Peripherals,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var version = try Buffer.init(allocator, "");
        errdefer version.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();

        return Self{
            .name = name,
            .version = version,
            .description = description,
            .cpu = null,
            .address_unit_bits = null,
            .width = null,
            .size = null,
            .reset_value = null,
            .reset_mask = null,
            .peripherals = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.version.deinit();
        self.description.deinit();
    }
};

pub const Cpu = struct {
    name: Buffer,
    revision: Buffer,
    endian: Buffer,
    mpu_present: ?bool,
    fpu_present: ?bool,
    nvic_prio_bits: ?u32,
    vendor_systick_config: ?bool,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var revision = try Buffer.init(allocator, "");
        errdefer revision.deinit();
        var endian = try Buffer.init(allocator, "");
        errdefer endian.deinit();

        return Self{
            .name = name,
            .revision = revision,
            .endian = endian,
            .mpu_present = null,
            .fpu_present = null,
            .nvic_prio_bits = null,
            .vendor_systick_config = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.revision.deinit();
        self.endian.deinit();
    }
};

pub const Peripherals = ArrayList(Peripheral);

pub const Peripheral = struct {
    name: Buffer,
    group_name: Buffer,
    base_address: ?u32,
    address_block: ?AddressBlock,
    interrupt: ?Interrupt,
    registers: ?Registers,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var group_name = try Buffer.init(allocator, "");
        errdefer group_name.deinit();

        return Self{
            .name = name,
            .group_name = group_name,
            .base_address = null,
            .address_block = null,
            .interrupt = null,
            .registers = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.group_name.deinit();
    }
};

pub const AddressBlock = struct {
    offset: ?u32,
    size: ?u32,
    usage: Buffer,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var usage = try Buffer.init(allocator, "");
        errdefer usage.deinit();

        return Self{
            .offset = null,
            .size = null,
            .usage = usage,
        };
    }

    pub fn deinit(self: *Self) void {
        self.usage.deinit();
    }
};

pub const Interrupt = struct {
    name: Buffer,
    description: Buffer,
    value: ?u32,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();

        return Self{
            .name = name,
            .description = description,
            .value = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.description.deinit();
    }
};

const Registers = ArrayList(Register);

pub const Register = struct {
    name: Buffer,
    display_name: Buffer,
    description: Buffer,
    address_offset: ?u32,
    size: ?u32,
    reset_value: ?u32,
    fields: Fields,

    access: Access = ReadWrite,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var display_name = try Buffer.init(allocator, "");
        errdefer display_name.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();

        return Self{
            .name = name,
            .display_name = display_name,
            .description = description,
            .address_offset = null,
            .size = null,
            .reset_value = null,
            .fields = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.display_name.deinit();
        self.description.deinit();
    }
};

pub const Access = enum {
    ReadOnly,
    WriteOnly,
    ReadWrite,
};

pub const Fields = ArrayList(Field);

pub const Field = struct {
    name: Buffer,
    description: Buffer,
    bit_offset: ?u32,
    bit_width: ?u32,

    access: Access = .ReadWrite,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();

        return Self{
            .name = name,
            .description = description,
            .bit_offset = null,
            .bit_width = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.description.deinit();
    }

    pub fn printToBuffer(self: Self, buffer: *Buffer) !void {
        if (self.name.len() == 0) {
            return SvdTranslationError.NotEnoughInfoToTranslate;
        }
        const offset = self.bit_offset orelse return SvdTranslationError.NotEnoughInfoToTranslate;
        const width = self.bit_width orelse return SvdTranslationError.NotEnoughInfoToTranslate;
        const base_mask = bitWidthToMask(width);

        try buffer.print("\n", .{});

        if (self.description.len() > 0) {
            try buffer.print("/// {}\n", .{self.description.toSlice()});
        }
        try buffer.print(
            \\const {} = struct {{
            \\    pub const offset = {};
            \\    pub const width = {};
            \\    pub const mask = 0x{x} << offset;
            \\    pub fn val(setting: u32) u32 {{
            \\        return (setting & 0x{x}) << offset;
            \\    }}
            \\}};
            \\
        , .{
            self.name.toSlice(),
            offset,
            width,
            base_mask,
            base_mask,
        });
    }
};

test "Field print" {
    var allocator = std.testing.allocator;
    const fieldDesiredPrint =
        \\
        \\/// rngen comment
        \\const rngen = struct {
        \\    pub const offset = 2;
        \\    pub const width = 1;
        \\    pub const mask = 0x1 << offset;
        \\    pub fn val(setting: u32) u32 {
        \\        return (setting & 0x1) << offset;
        \\    }
        \\};
        \\
    ;

    const fieldDesiredPrintx2 =
        \\
        \\/// rngen comment
        \\const rngen = struct {
        \\    pub const offset = 2;
        \\    pub const width = 1;
        \\    pub const mask = 0x1 << offset;
        \\    pub fn val(setting: u32) u32 {
        \\        return (setting & 0x1) << offset;
        \\    }
        \\};
        \\
        \\/// doc comment
        \\const field_namespace = struct {
        \\    pub const offset = 3;
        \\    pub const width = 4;
        \\    pub const mask = 0xf << offset;
        \\    pub fn val(setting: u32) u32 {
        \\        return (setting & 0xf) << offset;
        \\    }
        \\};
        \\
    ;

    var output_buffer = try Buffer.init(allocator, "");
    defer output_buffer.deinit();

    var field = try Field.init(allocator);
    defer field.deinit();

    var field2 = try Field.init(allocator);
    defer field2.deinit();

    try field.name.append("rngen");
    try field.description.append("rngen comment");
    field.bit_offset = 2;
    field.bit_width = 1;

    try field2.name.append("field_namespace");
    try field2.description.append("doc comment");
    field2.bit_offset = 3;
    field2.bit_width = 4;

    try field.printToBuffer(&output_buffer);
    std.testing.expect(output_buffer.eql(fieldDesiredPrint));

    try field2.printToBuffer(&output_buffer);
    std.testing.expect(output_buffer.eql(fieldDesiredPrintx2));
}

fn bitWidthToMask(width: u32) usize {
    const max_supported_bits = 32;
    const width_to_mask = blk: {
        comptime var mask_array: [max_supported_bits + 1]usize = undefined;
        inline for (mask_array) |*item, i| {
            const i_use = if (i == 0) max_supported_bits else i;
            item.* = std.math.maxInt(@Type(builtin.TypeInfo{
                .Int = .{
                    .is_signed = false,
                    .bits = i_use,
                },
            }));
        }
        break :blk mask_array;
    };
    const width_to_mask_slice = width_to_mask[0..];

    return width_to_mask_slice[if (width > max_supported_bits) 0 else width];
}
