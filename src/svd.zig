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
    description: Buffer,
    base_address: ?u32,
    address_block: ?AddressBlock,
    interrupt: ?Interrupt,
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
            .interrupt = null,
            .registers = registers,
        };
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

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");
        if (!self.isValid()) {
            try output(context, "// Not enough info to print register value\n");
            return;
        }
        const name = self.name.toSlice();
        const description = if (self.description.len() == 0) "No description" else self.description.toSliceConst();
        try std.fmt.format(context, Errors, output,
            \\/// {}
            \\pub const {} = struct {{
            \\    pub const base_address = 0x{x};
            \\
        , .{ description, name, self.base_address.? });
        if (self.interrupt) |interrupt_info| {
            if (interrupt_info.value) |interrupt_num| {
                try std.fmt.format(context, Errors, output,
                    \\    pub const interrupt = {};
                    \\
                , .{interrupt_num});
            }
        }
        // now print registers
        for (self.registers.toSliceConst()) |register| {
            try std.fmt.format(context, Errors, output, "{}\n", .{register});
        }

        try output(context, "};");
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

    pub fn isValid(self: Self) bool {
        if (self.name.len() == 0) {
            return false;
        }
        _ = self.value orelse return false;

        return true;
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
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

    pub fn init(allocator: *Allocator, base_address: u32, reset_value: u32, size: u32) !Self {
        var name = try Buffer.init(allocator, "");
        errdefer name.deinit();
        var display_name = try Buffer.init(allocator, "");
        errdefer display_name.deinit();
        var description = try Buffer.init(allocator, "");
        errdefer description.deinit();
        var fields = Fields.init(allocator);
        errdefer fields.deinit();

        return Self{
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

    pub fn deinit(self: *Self) void {
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

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");
        if (!self.isValid()) {
            try output(context, "// Not enough info to print register value\n");
            return;
        }
        const name = self.name.toSlice();
        const description = if (self.description.len() == 0) "No description" else self.description.toSliceConst();
        try std.fmt.format(context, Errors, output,
            \\/// {}
            \\pub const {} = struct {{
            \\
        , .{ description, name });
        try std.fmt.format(context, Errors, output,
            \\    pub const address = 0x{x} + 0x{x};
            \\    pub const size_type = u{};
            \\    pub const reset_value: size_type = 0x{x};
            \\
        , .{ self.base_address, self.address_offset.?, self.size, self.reset_value });
        var write_mask: u32 = std.math.maxInt(u32);
        for (self.fields.toSliceConst()) |field| {
            if (field.bit_offset) |def_offset| {
                if (field.bit_width) |def_width| {
                    write_mask &= ~(bitWidthToMask(def_width) << @truncate(u5, def_offset));
                }
            }
        }
        const write_str =
            \\    const write_mask = 0x{x};
            \\    pub fn write(setting: size_type) void {{
            \\        const mmio_ptr = @intToPtr(*volatile size_type, address);
            \\        mmio.ptr.* = setting & write_mask;
            \\    }}
            \\
        ;
        const read_str =
            \\    pub fn read() size_type {
            \\        const mmio_ptr = @intToPtr(*volatile size_type, address);
            \\        return mmio.ptr.*;
            \\    }
            \\
        ;
        switch (self.access) {
            .ReadWrite => {
                try std.fmt.format(context, Errors, output, write_str, .{write_mask});
                try output(context, read_str);
            },
            .WriteOnly => {
                try std.fmt.format(context, Errors, output, write_str, .{write_mask});
            },
            .ReadOnly => {
                try output(context, read_str);
            },
        }
        // now print fields
        for (self.fields.toSliceConst()) |field| {
            try std.fmt.format(context, Errors, output, "{}\n", .{field});
        }

        try output(context, "};");
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

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        try output(context, "\n");
        if (self.name.len() == 0) {
            try output(context, "// No name to print field value\n");
            return;
        }
        var offset_exists: bool = false;
        const name = self.name.toSlice();
        const description = if (self.description.len() == 0) "No description" else self.description.toSliceConst();
        try std.fmt.format(context, Errors, output,
            \\/// {}
            \\pub const {} = struct {{
            \\
        , .{ description, name });
        if (self.bit_offset) |offset| {
            try std.fmt.format(context, Errors, output,
                \\    pub const offset = {};
                \\
            , .{offset});
            offset_exists = true;
        }
        if (self.bit_width) |width| {
            try std.fmt.format(context, Errors, output,
                \\    pub const width = {};
                \\
            , .{width});
            if (offset_exists) {
                const base_mask = bitWidthToMask(width);
                try std.fmt.format(context, Errors, output,
                    \\    pub const mask = 0x{x} << offset;
                    \\    pub fn val(setting: u32) u32 {{
                    \\        return (setting & 0x{x}) << offset;
                    \\    }}
                    \\
                , .{ base_mask, base_mask });
            }
        }
        try output(context, "};");
        return;
    }
};

test "Field print" {
    var allocator = std.testing.allocator;
    const fieldDesiredPrint =
        \\
        \\/// rngen comment
        \\pub const rngen = struct {
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
        \\pub const rngen = struct {
        \\    pub const offset = 2;
        \\    pub const width = 1;
        \\    pub const mask = 0x1 << offset;
        \\    pub fn val(setting: u32) u32 {
        \\        return (setting & 0x1) << offset;
        \\    }
        \\};
        \\
        \\/// doc comment
        \\pub const field_namespace = struct {
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

    try output_buffer.print("{}\n", .{field});
    std.testing.expect(output_buffer.eql(fieldDesiredPrint));

    try output_buffer.print("{}\n", .{field2});
    std.testing.expect(output_buffer.eql(fieldDesiredPrintx2));
}

test "Register Print" {
    var allocator = std.testing.allocator;
    const registerDesiredPrint =
        \\
        \\/// register comment
        \\pub const reg_name = struct {
        \\    pub const address = 0x24000 + 0x100;
        \\    pub const size_type = u32;
        \\    pub const reset_value: size_type = 0x0;
        \\    const write_mask = 0xfffffffb;
        \\    pub fn write(setting: size_type) void {
        \\        const mmio_ptr = @intToPtr(*volatile size_type, address);
        \\        mmio.ptr.* = setting & write_mask;
        \\    }
        \\    pub fn read() size_type {
        \\        const mmio_ptr = @intToPtr(*volatile size_type, address);
        \\        return mmio.ptr.*;
        \\    }
        \\
        \\/// rngen comment
        \\pub const rngen = struct {
        \\    pub const offset = 2;
        \\    pub const width = 1;
        \\    pub const mask = 0x1 << offset;
        \\    pub fn val(setting: u32) u32 {
        \\        return (setting & 0x1) << offset;
        \\    }
        \\};
        \\};
        \\
    ;

    var output_buffer = try Buffer.init(allocator, "");
    defer output_buffer.deinit();

    var register = try Register.init(allocator, 0x24000, 0, 0x20);
    defer register.deinit();
    try register.name.append("reg_name");
    try register.description.append("register comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator);
    defer field.deinit();

    try field.name.append("rngen");
    try field.description.append("rngen comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadOnly; // effects register write fn, TODO: handle WriteOnly

    try register.fields.append(field);

    try output_buffer.print("{}\n", .{register});
    std.testing.expect(output_buffer.eql(registerDesiredPrint));
}

test "Peripheral Print" {
    var allocator = std.testing.allocator;
    const peripheralDesiredPrint =
        \\
        \\/// per comment
        \\pub const per_name = struct {
        \\    pub const base_address = 0x24000;
        \\
        \\/// register comment
        \\pub const reg_name = struct {
        \\    pub const address = 0x24000 + 0x100;
        \\    pub const size_type = u32;
        \\    pub const reset_value: size_type = 0x0;
        \\    const write_mask = 0xfffffffb;
        \\    pub fn write(setting: size_type) void {
        \\        const mmio_ptr = @intToPtr(*volatile size_type, address);
        \\        mmio.ptr.* = setting & write_mask;
        \\    }
        \\    pub fn read() size_type {
        \\        const mmio_ptr = @intToPtr(*volatile size_type, address);
        \\        return mmio.ptr.*;
        \\    }
        \\
        \\/// rngen comment
        \\pub const rngen = struct {
        \\    pub const offset = 2;
        \\    pub const width = 1;
        \\    pub const mask = 0x1 << offset;
        \\    pub fn val(setting: u32) u32 {
        \\        return (setting & 0x1) << offset;
        \\    }
        \\};
        \\};
        \\};
        \\
    ;

    var output_buffer = try Buffer.init(allocator, "");
    defer output_buffer.deinit();

    var peripheral = try Peripheral.init(allocator);
    defer peripheral.deinit();
    try peripheral.name.append("per_name");
    try peripheral.description.append("per comment");
    peripheral.base_address = 0x24000;

    var register = try Register.init(allocator, peripheral.base_address.?, 0, 0x20);
    defer register.deinit();
    try register.name.append("reg_name");
    try register.description.append("register comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator);
    defer field.deinit();

    try field.name.append("rngen");
    try field.description.append("rngen comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadOnly;

    try register.fields.append(field);

    try peripheral.registers.append(register);

    try output_buffer.print("{}\n", .{peripheral});
    std.testing.expect(output_buffer.eql(peripheralDesiredPrint));
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
