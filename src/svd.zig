const std = @import("std");
const builtin = @import("builtin");
const Buffer = std.Buffer;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const warn = std.debug.warn;

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
    max_bit_width: ?u32,

    /// Start register default properties
    reg_default_size: ?u32,
    reg_default_reset_value: ?u32,
    reg_default_reset_mask: ?u32,
    peripherals: Peripherals,
    interrupts: Interrupts,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var version = try Buffer.init(allocator, "");
        errdefer version.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();
        var peripherals = Peripherals.init(allocator);
        errdefer peripherals;
        var interrupts = Interrupts.init(allocator);
        errdefer interrupts;

        return Self{
            .name = name,
            .version = version,
            .description = description,
            .cpu = null,
            .address_unit_bits = null,
            .max_bit_width = null,
            .reg_default_size = null,
            .reg_default_reset_value = null,
            .reg_default_reset_mask = null,
            .peripherals = peripherals,
            .interrupts = interrupts,
        };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.version.deinit();
        self.description.deinit();
        self.peripherals.deinit();
        self.interrupts.deinit();
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        const name = if (self.name.len() == 0) "unknown" else self.name.toSliceConst();
        const version = if (self.version.len() == 0) "unknown" else self.version.toSliceConst();
        const description = if (self.description.len() == 0) "unknown" else self.description.toSliceConst();
        try std.fmt.format(context, Errors, output,
            \\pub const device_name = {};
            \\pub const device_revision = {};
            \\pub const device_description = {};
            \\
        , .{ name, version, description });
        if (self.cpu) |the_cpu| {
            try std.fmt.format(context, Errors, output, "{}\n", .{the_cpu});
        }
        // now print peripherals
        for (self.peripherals.toSliceConst()) |peripheral| {
            try std.fmt.format(context, Errors, output, "{}\n", .{peripheral});
        }
        // now print interrupt table
        try output(context, "pub const interrupts = struct {\n");
        for (self.interrupts.toSliceConst()) |interrupt| {
            if (interrupt.value) |int_value| {
                try std.fmt.format(
                    context,
                    Errors,
                    output,
                    "pub const {} = {};\n",
                    .{ interrupt.name.toSliceConst(), int_value },
                );
            }
        }
        try output(context, "};");
        return;
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

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");

        const name = if (self.name.len() == 0) "unknown" else self.name.toSliceConst();
        const revision = if (self.revision.len() == 0) "unknown" else self.revision.toSliceConst();
        const endian = if (self.endian.len() == 0) "unknown" else self.endian.toSliceConst();
        const mpu_present = self.mpu_present orelse false;
        const fpu_present = self.mpu_present orelse false;
        const vendor_systick_config = self.vendor_systick_config orelse false;
        try std.fmt.format(context, Errors, output,
            \\pub const cpu = struct {{
            \\    pub const name = {};
            \\    pub const revision = {};
            \\    pub const endian = {};
            \\    pub const mpu_present = {};
            \\    pub const fpu_present = {};
            \\    pub const vendor_systick_config = {};
            \\
        , .{ name, revision, endian, mpu_present, fpu_present, vendor_systick_config });
        if (self.nvic_prio_bits) |prio_bits| {
            try std.fmt.format(context, Errors, output,
                \\    pub const nvic_prio_bits = {};
                \\
            , .{prio_bits});
        }
        try output(context, "};");
        return;
    }
};

pub const Peripherals = ArrayList(Peripheral);

pub const Peripheral = struct {
    name: Buffer,
    group_name: Buffer,
    description: Buffer,
    base_address: ?u32,
    address_block: ?AddressBlock,
    registers: Registers,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var group_name = try Buffer.init(allocator, "");
        errdefer group_name.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();
        var registers = Registers.init(allocator);
        errdefer registers.deinit();

        return Self{
            .name = name,
            .group_name = group_name,
            .description = description,
            .base_address = null,
            .address_block = null,
            .registers = registers,
        };
    }

    pub fn copy(self: Self, allocator: *Allocator) !Self {
        var the_copy = try Self.init(allocator);
        errdefer the_copy.deinit();

        try the_copy.name.append(self.name.toSliceConst());
        try the_copy.group_name.append(self.group_name.toSliceConst());
        try the_copy.description.append(self.description.toSliceConst());
        the_copy.base_address = self.base_address;
        the_copy.address_block = self.address_block;
        for (self.registers.toSliceConst()) |self_register| {
            try the_copy.registers.append(try self_register.copy(allocator));
        }

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.group_name.deinit();
        self.description.deinit();
        self.registers.deinit();
    }

    pub fn isValid(self: Self) bool {
        if (self.name.len() == 0) {
            return false;
        }
        _ = self.base_address orelse return false;

        return true;
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");
        if (!self.isValid()) {
            try output(context, "// Not enough info to print register value\n");
            return;
        }
        const name = self.name.toSlice();
        const description = if (self.description.len() == 0) "No description" else self.description.toSliceConst();
        try std.fmt.format(context, Errors, output,
            \\/// {}
            \\pub const {}_Base_Address = 0x{x};
            \\
        , .{ description, name, self.base_address.? });
        // now print registers
        for (self.registers.toSliceConst()) |register| {
            try std.fmt.format(context, Errors, output, "{}\n", .{register});
        }

        return;
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

pub const Interrupts = ArrayList(Interrupt);

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

    pub fn copy(self: Self, allocator: *Allocator) !Self {
        var the_copy = try Self.init(allocator);

        try the_copy.name.append(self.name.toSliceConst());
        try the_copy.description.append(self.description.toSliceConst());
        the_copy.value = self.value;

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.description.deinit();
    }

    pub fn isValid(self: Self) bool {
        if (self.name.len() == 0) {
            return false;
        }
        _ = self.value orelse return false;

        return true;
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");
        if (!self.isValid()) {
            try output(context, "// Not enough info to print interrupt value\n");
            return;
        }
        const name = self.name.toSlice();
        const description = if (self.description.len() == 0) "No description" else self.description.toSliceConst();
        try std.fmt.format(context, Errors, output,
            \\/// {}
            \\pub const {} = {};
            \\
        , .{ description, name, value.? });
    }
};

const Registers = ArrayList(Register);

pub const Register = struct {
    periph_containing: Buffer,
    name: Buffer,
    display_name: Buffer,
    description: Buffer,
    base_address: u32, // must come from peripheral
    address_offset: ?u32,
    size: u32,
    reset_value: u32,
    fields: Fields,

    access: Access = .ReadWrite,

    const Self = @This();

    pub fn init(allocator: *Allocator, periph: []const u8, base_address: u32, reset_value: u32, size: u32) !Self {
        var prefix = try Buffer.init(allocator, "");
        errdefer prefix.deinit();
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var display_name = try Buffer.init(allocator, "");
        errdefer display_name.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();
        var fields = Fields.init(allocator);
        errdefer fields.deinit();

        try prefix.replaceContents(periph);

        return Self{
            .periph_containing = prefix,
            .name = name,
            .display_name = display_name,
            .description = description,
            .base_address = base_address,
            .address_offset = null,
            .size = size,
            .reset_value = reset_value,
            .fields = fields,
        };
    }

    pub fn copy(self: Self, allocator: *Allocator) !Self {
        var the_copy = try Self.init(allocator, self.periph_containing.toSliceConst(), self.base_address, self.reset_value, self.size);

        try the_copy.name.append(self.name.toSliceConst());
        try the_copy.display_name.append(self.display_name.toSliceConst());
        try the_copy.description.append(self.description.toSliceConst());
        the_copy.address_offset = self.address_offset;
        the_copy.access = self.access;
        for (self.fields.toSliceConst()) |self_field| {
            try the_copy.fields.append(try self_field.copy(allocator));
        }

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.periph_containing.deinit();
        self.name.deinit();
        self.display_name.deinit();
        self.description.deinit();

        self.fields.deinit();
    }

    pub fn isValid(self: Self) bool {
        if (self.name.len() == 0) {
            return false;
        }
        _ = self.address_offset orelse return false;

        return true;
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");
        if (!self.isValid()) {
            try output(context, "// Not enough info to print register value\n");
            return;
        }
        const name = self.name.toSliceConst();
        const periph = self.periph_containing.toSliceConst();
        const description = if (self.description.len() == 0) "No description" else self.description.toSliceConst();
        try std.fmt.format(context, Errors, output,
            \\/// {}
            \\
        , .{description});
        try std.fmt.format(context, Errors, output,
            \\pub const {}_{}_Address = 0x{x} + 0x{x};
            \\pub const {}_{}_Reset_Value = 0x{x};
            \\
        , .{
            // address
            periph,
            name,
            self.base_address,
            self.address_offset.?,
            // reset value
            periph,
            name,
            self.reset_value,
        });
        var write_mask: u32 = 0;
        for (self.fields.toSliceConst()) |field| {
            if (field.bit_offset) |def_offset| {
                if (field.bit_width) |def_width| {
                    if (field.access != .ReadOnly) {
                        write_mask |= bitWidthToMask(def_width) << @truncate(u5, def_offset);
                    }
                }
            }
        }
        const write_str =
            \\pub inline fn {}_{}_Write(setting: u{}) void {{
            \\    const write_mask = 0x{x};
            \\    const mmio_ptr = @intToPtr(*volatile u{}, {}_{}_Address);
            \\    mmio_ptr.* = setting & write_mask;
            \\}}
            \\
        ;
        const read_str =
            \\pub inline fn {}_{}_Read() u{} {{
            \\    const mmio_ptr = @intToPtr(*volatile u{}, {}_{}_Address);
            \\    return mmio_ptr.*;
            \\}}
            \\
        ;

        var effective_access = if (write_mask == 0) .ReadOnly else self.access;

        switch (effective_access) {
            .ReadWrite => {
                try std.fmt.format(context, Errors, output, write_str, .{
                    // func name
                    periph,
                    name,
                    self.size,
                    // write mask
                    write_mask,
                    // pointer type and address
                    self.size,
                    periph,
                    name,
                });
                try std.fmt.format(context, Errors, output, read_str, .{
                    // func name and return type
                    periph,
                    name,
                    self.size,
                    // pointer type and address
                    self.size,
                    periph,
                    name,
                });
            },
            .WriteOnly => {
                try std.fmt.format(context, Errors, output, write_str, .{
                    // func name
                    periph,
                    name,
                    self.size,
                    // write mask
                    write_mask,
                    // pointer type and address
                    self.size,
                    periph,
                    name,
                });
            },
            .ReadOnly => {
                try std.fmt.format(context, Errors, output, read_str, .{
                    // func name and return type
                    periph,
                    name,
                    self.size,
                    // pointer type and address
                    self.size,
                    periph,
                    name,
                });
            },
        }
        // now print fields
        for (self.fields.toSliceConst()) |field| {
            try std.fmt.format(context, Errors, output, "{}\n", .{field});
        }

        return;
    }
};

pub const Access = enum {
    ReadOnly,
    WriteOnly,
    ReadWrite,
};

pub const Fields = ArrayList(Field);

pub const Field = struct {
    periph: Buffer,
    register: Buffer,
    name: Buffer,
    description: Buffer,
    bit_offset: ?u32,
    bit_width: ?u32,

    access: Access = .ReadWrite,

    const Self = @This();

    pub fn init(allocator: *Allocator, periph_containing: []const u8, register_containing: []const u8) !Self {
        var periph = try Buffer.init(allocator, periph_containing);
        errdefer periph.deinit();
        var register = try Buffer.init(allocator, register_containing);
        errdefer register.deinit();
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();

        return Self{
            .periph = periph,
            .register = register,
            .name = name,
            .description = description,
            .bit_offset = null,
            .bit_width = null,
        };
    }

    pub fn copy(self: Self, allocator: *Allocator) !Self {
        var the_copy = try Self.init(allocator, self.periph.toSliceConst(), self.register.toSliceConst());

        try the_copy.name.append(self.name.toSliceConst());
        try the_copy.description.append(self.description.toSliceConst());
        the_copy.bit_offset = self.bit_offset;
        the_copy.bit_width = self.bit_width;
        the_copy.access = self.access;

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.periph.deinit();
        self.register.deinit();
        self.name.deinit();
        self.description.deinit();
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");
        if (self.name.len() == 0) {
            try output(context, "// No name to print field value\n");
            return;
        }
        if ((self.bit_offset == null) or (self.bit_width == null)) {
            try output(context, "// Not enough info to print field\n");
            return;
        }
        const name = self.name.toSlice();
        const periph = self.periph.toSliceConst();
        const register = self.register.toSliceConst();
        const description = if (self.description.len() == 0) "No description" else self.description.toSliceConst();
        const offset = self.bit_offset.?;
        const base_mask = bitWidthToMask(self.bit_width.?);
        try std.fmt.format(context, Errors, output,
            \\/// {}
            \\pub const {}_{}_{}_Offset = {};
            \\pub const {}_{}_{}_Mask = 0x{x} << {}_{}_{}_Offset;
            \\pub inline fn {}_{}_{}(setting: u32) u32 {{
            \\    return (setting & 0x{x}) << {}_{}_{}_Offset;
            \\}}
            \\
        , .{
            description,
            // offset
            periph,
            register,
            name,
            offset,
            // mask
            periph,
            register,
            name,
            base_mask,
            periph,
            register,
            name,
            // val
            periph,
            register,
            name,
            // setting
            base_mask,
            periph,
            register,
            name,
        });
        return;
    }
};

test "Field print" {
    var allocator = std.testing.allocator;
    const fieldDesiredPrint =
        \\
        \\/// RNGEN comment
        \\pub const PERIPH_RND_RNGEN_Offset = 2;
        \\pub const PERIPH_RND_RNGEN_Mask = 0x1 << PERIPH_RND_RNGEN_Offset;
        \\pub inline fn PERIPH_RND_RNGEN(setting: u32) u32 {
        \\    return (setting & 0x1) << PERIPH_RND_RNGEN_Offset;
        \\}
        \\
        \\
    ;

    var output_buffer = try Buffer.init(allocator, "");
    defer output_buffer.deinit();
    var buf_stream = &std.io.BufferOutStream.init(&output_buffer).stream;

    var field = try Field.init(allocator, "PERIPH", "RND");
    defer field.deinit();

    try field.name.append("RNGEN");
    try field.description.append("RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;

    try buf_stream.print("{}\n", .{field});
    std.testing.expect(output_buffer.eql(fieldDesiredPrint));
}

test "Register Print" {
    var allocator = std.testing.allocator;
    const registerDesiredPrint =
        \\
        \\/// RND comment
        \\pub const PERIPH_RND_Address = 0x24000 + 0x100;
        \\pub const PERIPH_RND_Reset_Value = 0x0;
        \\pub inline fn PERIPH_RND_Write(setting: u32) void {
        \\    const write_mask = 0x4;
        \\    const mmio_ptr = @intToPtr(*volatile u32, PERIPH_RND_Address);
        \\    mmio_ptr.* = setting & write_mask;
        \\}
        \\pub inline fn PERIPH_RND_Read() u32 {
        \\    const mmio_ptr = @intToPtr(*volatile u32, PERIPH_RND_Address);
        \\    return mmio_ptr.*;
        \\}
        \\
        \\/// RNGEN comment
        \\pub const PERIPH_RND_RNGEN_Offset = 2;
        \\pub const PERIPH_RND_RNGEN_Mask = 0x1 << PERIPH_RND_RNGEN_Offset;
        \\pub inline fn PERIPH_RND_RNGEN(setting: u32) u32 {
        \\    return (setting & 0x1) << PERIPH_RND_RNGEN_Offset;
        \\}
        \\
        \\
        \\
    ;

    var output_buffer = try Buffer.init(allocator, "");
    defer output_buffer.deinit();
    var buf_stream = &std.io.BufferOutStream.init(&output_buffer).stream;

    var register = try Register.init(allocator, "PERIPH", 0x24000, 0, 0x20);
    defer register.deinit();
    try register.name.append("RND");
    try register.description.append("RND comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator, "PERIPH", "RND");
    defer field.deinit();

    try field.name.append("RNGEN");
    try field.description.append("RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadWrite; // write field will exist

    try register.fields.append(field);

    try buf_stream.print("{}\n", .{register});
    var expected = output_buffer.toSlice();
    std.testing.expectEqualSlices(u8, expected, registerDesiredPrint);
}

test "Peripheral Print" {
    var allocator = std.testing.allocator;
    const peripheralDesiredPrint =
        \\
        \\/// PERIPH comment
        \\pub const PERIPH_Base_Address = 0x24000;
        \\
        \\/// RND comment
        \\pub const PERIPH_RND_Address = 0x24000 + 0x100;
        \\pub const PERIPH_RND_Reset_Value = 0x0;
        \\pub inline fn PERIPH_RND_Read() u32 {
        \\    const mmio_ptr = @intToPtr(*volatile u32, PERIPH_RND_Address);
        \\    return mmio_ptr.*;
        \\}
        \\
        \\/// RNGEN comment
        \\pub const PERIPH_RND_RNGEN_Offset = 2;
        \\pub const PERIPH_RND_RNGEN_Mask = 0x1 << PERIPH_RND_RNGEN_Offset;
        \\pub inline fn PERIPH_RND_RNGEN(setting: u32) u32 {
        \\    return (setting & 0x1) << PERIPH_RND_RNGEN_Offset;
        \\}
        \\
        \\
        \\
        \\
    ;

    var output_buffer = try Buffer.init(allocator, "");
    defer output_buffer.deinit();
    var buf_stream = &std.io.BufferOutStream.init(&output_buffer).stream;

    var peripheral = try Peripheral.init(allocator);
    defer peripheral.deinit();
    try peripheral.name.append("PERIPH");
    try peripheral.description.append("PERIPH comment");
    peripheral.base_address = 0x24000;

    var register = try Register.init(allocator, "PERIPH", peripheral.base_address.?, 0, 0x20);
    defer register.deinit();
    try register.name.append("RND");
    try register.description.append("RND comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator, "PERIPH", "RND");
    defer field.deinit();

    try field.name.append("RNGEN");
    try field.description.append("RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadOnly; // since only register, write field will not exist

    try register.fields.append(field);

    try peripheral.registers.append(register);

    try buf_stream.print("{}\n", .{peripheral});
    std.testing.expectEqualSlices(u8, peripheralDesiredPrint, output_buffer.toSliceConst());
}
fn bitWidthToMask(width: u32) u32 {
    const max_supported_bits = 32;
    const width_to_mask = blk: {
        comptime var mask_array: [max_supported_bits + 1]u32 = undefined;
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
