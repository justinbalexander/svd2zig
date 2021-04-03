const std = @import("std");
const builtin = @import("builtin");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const warn = std.debug.warn;

/// Top Level
pub const Device = struct {
    name: ArrayList(u8),
    version: ArrayList(u8),
    description: ArrayList(u8),
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
        var name = ArrayList(u8).init(allocator);
        errdefer name.deinit();
        var version = ArrayList(u8).init(allocator);
        errdefer version.deinit();
        var description = ArrayList(u8).init(allocator);
        errdefer description.deinit();
        var peripherals = Peripherals.init(allocator);
        errdefer peripherals.deinit();
        var interrupts = Interrupts.init(allocator);
        errdefer interrupts.deinit();

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

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        const name = if (self.name.items.len == 0) "unknown" else self.name.items;
        const version = if (self.version.items.len == 0) "unknown" else self.version.items;
        const description = if (self.description.items.len == 0) "unknown" else self.description.items;

        try out_stream.print(
            \\pub const device_name = "{s}";
            \\pub const device_revision = "{s}";
            \\pub const device_description = "{s}";
            \\
        , .{ name, version, description });
        if (self.cpu) |the_cpu| {
            try out_stream.print("{}\n", .{the_cpu});
        }
        // now print peripherals
        for (self.peripherals.items) |peripheral| {
            try out_stream.print("{}\n", .{peripheral});
        }
        // now print interrupt table
        try out_stream.writeAll("pub const interrupts = struct {\n");
        var iter = self.interrupts.iterator();
        while (iter.next()) |entry| {
            var interrupt = entry.value;
            if (interrupt.value) |int_value| {
                try out_stream.print(
                    "pub const {s} = {};\n",
                    .{ interrupt.name.items, int_value },
                );
            }
        }
        try out_stream.writeAll("};");
        return;
    }
};

pub const Cpu = struct {
    name: ArrayList(u8),
    revision: ArrayList(u8),
    endian: ArrayList(u8),
    mpu_present: ?bool,
    fpu_present: ?bool,
    nvic_prio_bits: ?u32,
    vendor_systick_config: ?bool,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = ArrayList(u8).init(allocator);
        errdefer name.deinit();
        var revision = ArrayList(u8).init(allocator);
        errdefer revision.deinit();
        var endian = ArrayList(u8).init(allocator);
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

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        try out_stream.writeAll("\n");

        const name = if (self.name.items.len == 0) "unknown" else self.name.items;
        const revision = if (self.revision.items.len == 0) "unknown" else self.revision.items;
        const endian = if (self.endian.items.len == 0) "unknown" else self.endian.items;
        const mpu_present = self.mpu_present orelse false;
        const fpu_present = self.mpu_present orelse false;
        const vendor_systick_config = self.vendor_systick_config orelse false;
        try out_stream.print(
            \\pub const cpu = struct {{
            \\    pub const name = "{s}";
            \\    pub const revision = "{s}";
            \\    pub const endian = "{s}";
            \\    pub const mpu_present = {};
            \\    pub const fpu_present = {};
            \\    pub const vendor_systick_config = {};
            \\
        , .{ name, revision, endian, mpu_present, fpu_present, vendor_systick_config });
        if (self.nvic_prio_bits) |prio_bits| {
            try out_stream.print(
                \\    pub const nvic_prio_bits = {};
                \\
            , .{prio_bits});
        }
        try out_stream.writeAll("};");
        return;
    }
};

pub const Peripherals = ArrayList(Peripheral);

pub const Peripheral = struct {
    name: ArrayList(u8),
    group_name: ArrayList(u8),
    description: ArrayList(u8),
    base_address: ?u32,
    address_block: ?AddressBlock,
    registers: Registers,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = ArrayList(u8).init(allocator);
        errdefer name.deinit();
        var group_name = ArrayList(u8).init(allocator);
        errdefer group_name.deinit();
        var description = ArrayList(u8).init(allocator);
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

        try the_copy.name.appendSlice(self.name.items);
        try the_copy.group_name.appendSlice(self.group_name.items);
        try the_copy.description.appendSlice(self.description.items);
        the_copy.base_address = self.base_address;
        the_copy.address_block = self.address_block;
        for (self.registers.items) |self_register| {
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
        if (self.name.items.len == 0) {
            return false;
        }
        _ = self.base_address orelse return false;

        return true;
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        try out_stream.writeAll("\n");
        if (!self.isValid()) {
            try out_stream.writeAll("// Not enough info to print register value\n");
            return;
        }
        const name = self.name.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        try out_stream.print(
            \\/// {s}
            \\pub const {s}_Base_Address = 0x{x};
            \\
        , .{ description, name, self.base_address.? });
        // now print registers
        for (self.registers.items) |register| {
            try out_stream.print("{}\n", .{register});
        }

        return;
    }
};

pub const AddressBlock = struct {
    offset: ?u32,
    size: ?u32,
    usage: ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var usage = ArrayList(u8).init(allocator);
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

pub const Interrupts = AutoHashMap(u32, Interrupt);

pub const Interrupt = struct {
    name: ArrayList(u8),
    description: ArrayList(u8),
    value: ?u32,

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var name = ArrayList(u8).init(allocator);
        errdefer name.deinit();
        var description = ArrayList(u8).init(allocator);
        errdefer description.deinit();

        return Self{
            .name = name,
            .description = description,
            .value = null,
        };
    }

    pub fn copy(self: Self, allocator: *Allocator) !Self {
        var the_copy = try Self.init(allocator);

        try the_copy.name.append(self.name.items);
        try the_copy.description.append(self.description.items);
        the_copy.value = self.value;

        return the_copy;
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.description.deinit();
    }

    pub fn isValid(self: Self) bool {
        if (self.name.items.len == 0) {
            return false;
        }
        _ = self.value orelse return false;

        return true;
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        try out_stream.writeAll("\n");
        if (!self.isValid()) {
            try output(context, "// Not enough info to print interrupt value\n");
            return;
        }
        const name = self.name.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        try out_stream.print(
            \\/// {s}
            \\pub const {s} = {s};
            \\
        , .{ description, name, value.? });
    }
};

const Registers = ArrayList(Register);

pub const Register = struct {
    periph_containing: ArrayList(u8),
    name: ArrayList(u8),
    display_name: ArrayList(u8),
    description: ArrayList(u8),
    address_offset: ?u32,
    size: u32,
    reset_value: u32,
    fields: Fields,

    access: Access = .ReadWrite,

    const Self = @This();

    pub fn init(allocator: *Allocator, periph: []const u8, reset_value: u32, size: u32) !Self {
        var prefix = ArrayList(u8).init(allocator);
        errdefer prefix.deinit();
        try prefix.appendSlice(periph);
        var name = ArrayList(u8).init(allocator);
        errdefer name.deinit();
        var display_name = ArrayList(u8).init(allocator);
        errdefer display_name.deinit();
        var description = ArrayList(u8).init(allocator);
        errdefer description.deinit();
        var fields = Fields.init(allocator);
        errdefer fields.deinit();

        return Self{
            .periph_containing = prefix,
            .name = name,
            .display_name = display_name,
            .description = description,
            .address_offset = null,
            .size = size,
            .reset_value = reset_value,
            .fields = fields,
        };
    }

    pub fn copy(self: Self, allocator: *Allocator) !Self {
        var the_copy = try Self.init(allocator, self.periph_containing.items, self.reset_value, self.size);

        try the_copy.name.appendSlice(self.name.items);
        try the_copy.display_name.appendSlice(self.display_name.items);
        try the_copy.description.appendSlice(self.description.items);
        the_copy.address_offset = self.address_offset;
        the_copy.access = self.access;
        for (self.fields.items) |self_field| {
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
        if (self.name.items.len == 0) {
            return false;
        }
        _ = self.address_offset orelse return false;

        return true;
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        try out_stream.writeAll("\n");
        if (!self.isValid()) {
            try out_stream.writeAll("// Not enough info to print register value\n");
            return;
        }
        const name = self.name.items;
        const periph = self.periph_containing.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        try out_stream.print(
            \\/// {s}
            \\
        , .{description});
        try out_stream.print(
            \\pub const {s}_{s}_Address = {s}_Base_Address + 0x{x};
            \\pub const {s}_{s}_Reset_Value = 0x{x};
            \\
        , .{
            // address
            periph,
            name,
            periph,
            self.address_offset.?,
            // reset value
            periph,
            name,
            self.reset_value,
        });
        var write_mask: u32 = 0;
        for (self.fields.items) |field| {
            if (field.bit_offset) |def_offset| {
                if (field.bit_width) |def_width| {
                    if (field.access != .ReadOnly) {
                        write_mask |= bitWidthToMask(def_width) << @truncate(u5, def_offset);
                    }
                }
            }
        }
        const ptr_str =
            \\pub const {s}_{s}_Write_Mask = 0x{x};
            \\pub const {s}_{s}_Ptr = @intToPtr(*volatile u{}, {s}_{s}_Address);
            \\
        ;

        try out_stream.print(ptr_str, .{
            periph,
            name,
            write_mask,
            periph,
            name,
            self.size,
            periph,
            name,
        });
        // now print fields
        for (self.fields.items) |field| {
            try out_stream.print("{}\n", .{field});
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
    periph: ArrayList(u8),
    register: ArrayList(u8),
    name: ArrayList(u8),
    description: ArrayList(u8),
    bit_offset: ?u32,
    bit_width: ?u32,

    access: Access = .ReadWrite,

    const Self = @This();

    pub fn init(allocator: *Allocator, periph_containing: []const u8, register_containing: []const u8) !Self {
        var periph = ArrayList(u8).init(allocator);
        try periph.appendSlice(periph_containing);
        errdefer periph.deinit();
        var register = ArrayList(u8).init(allocator);
        try register.appendSlice(register_containing);
        errdefer register.deinit();
        var name = ArrayList(u8).init(allocator);
        errdefer name.deinit();
        var description = ArrayList(u8).init(allocator);
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
        var the_copy = try Self.init(allocator, self.periph.items, self.register.items);

        try the_copy.name.appendSlice(self.name.items);
        try the_copy.description.appendSlice(self.description.items);
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

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        try out_stream.writeAll("\n");
        if (self.name.items.len == 0) {
            try out_stream.writeAll("// No name to print field value\n");
            return;
        }
        if ((self.bit_offset == null) or (self.bit_width == null)) {
            try out_stream.writeAll("// Not enough info to print field\n");
            return;
        }
        const name = self.name.items;
        const periph = self.periph.items;
        const register = self.register.items;
        const description = if (self.description.items.len == 0) "No description" else self.description.items;
        const offset = self.bit_offset.?;
        const base_mask = bitWidthToMask(self.bit_width.?);
        try out_stream.print(
            \\/// {s}
            \\pub const {s}_{s}_{s}_Offset = {};
            \\pub const {s}_{s}_{s}_Mask = 0x{x} << {s}_{s}_{s}_Offset;
            \\pub inline fn {s}_{s}_{s}(setting: u32) u32 {{
            \\    return (setting & 0x{x}) << {s}_{s}_{s}_Offset;
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

    var output_buffer = ArrayList(u8).init(allocator);
    defer output_buffer.deinit();
    var buf_stream = output_buffer.writer();

    var field = try Field.init(allocator, "PERIPH", "RND");
    defer field.deinit();

    try field.name.appendSlice("RNGEN");
    try field.description.appendSlice("RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;

    try buf_stream.print("{}\n", .{field});
    std.testing.expect(std.mem.eql(u8, output_buffer.items, fieldDesiredPrint));
}

test "Register Print" {
    var allocator = std.testing.allocator;
    const registerDesiredPrint =
        \\
        \\/// RND comment
        \\pub const PERIPH_RND_Address = PERIPH_Base_Address + 0x100;
        \\pub const PERIPH_RND_Reset_Value = 0x0;
        \\pub const PERIPH_RND_Write_Mask = 0x4;
        \\pub const PERIPH_RND_Ptr = @intToPtr(*volatile u32, PERIPH_RND_Address);
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

    var output_buffer = ArrayList(u8).init(allocator);
    defer output_buffer.deinit();
    var buf_stream = output_buffer.writer();

    var register = try Register.init(allocator, "PERIPH", 0, 0x20);
    defer register.deinit();
    try register.name.appendSlice("RND");
    try register.description.appendSlice("RND comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator, "PERIPH", "RND");
    defer field.deinit();

    try field.name.appendSlice("RNGEN");
    try field.description.appendSlice("RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadWrite; // write field will exist

    try register.fields.append(field);

    try buf_stream.print("{}\n", .{register});
    std.testing.expectEqualSlices(u8, output_buffer.items, registerDesiredPrint);
}

test "Peripheral Print" {
    var allocator = std.testing.allocator;
    const peripheralDesiredPrint =
        \\
        \\/// PERIPH comment
        \\pub const PERIPH_Base_Address = 0x24000;
        \\
        \\/// RND comment
        \\pub const PERIPH_RND_Address = PERIPH_Base_Address + 0x100;
        \\pub const PERIPH_RND_Reset_Value = 0x0;
        \\pub const PERIPH_RND_Write_Mask = 0x0;
        \\pub const PERIPH_RND_Ptr = @intToPtr(*volatile u32, PERIPH_RND_Address);
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

    var output_buffer = ArrayList(u8).init(allocator);
    defer output_buffer.deinit();
    var buf_stream = output_buffer.writer();

    var peripheral = try Peripheral.init(allocator);
    defer peripheral.deinit();
    try peripheral.name.appendSlice("PERIPH");
    try peripheral.description.appendSlice("PERIPH comment");
    peripheral.base_address = 0x24000;

    var register = try Register.init(allocator, "PERIPH", 0, 0x20);
    defer register.deinit();
    try register.name.appendSlice("RND");
    try register.description.appendSlice("RND comment");
    register.address_offset = 0x100;
    register.size = 0x20;

    var field = try Field.init(allocator, "PERIPH", "RND");
    defer field.deinit();

    try field.name.appendSlice("RNGEN");
    try field.description.appendSlice("RNGEN comment");
    field.bit_offset = 2;
    field.bit_width = 1;
    field.access = .ReadOnly; // since only register, write field will not exist

    try register.fields.append(field);

    try peripheral.registers.append(register);

    try buf_stream.print("{}\n", .{peripheral});
    std.testing.expectEqualSlices(u8, peripheralDesiredPrint, output_buffer.items);
}
fn bitWidthToMask(width: u32) u32 {
    const max_supported_bits = 32;
    const width_to_mask = blk: {
        comptime var mask_array: [max_supported_bits + 1]u32 = undefined;
        inline for (mask_array) |*item, i| {
            const i_use = if (i == 0) max_supported_bits else i;
            // This is needed to support both Zig 0.7 and 0.8
            const int_type_info =
                if (@hasField(builtin.TypeInfo.Int, "signedness"))
            .{ .signedness = .unsigned, .bits = i_use } else .{ .is_signed = false, .bits = i_use };

            item.* = std.math.maxInt(@Type(builtin.TypeInfo{ .Int = int_type_info }));
        }
        break :blk mask_array;
    };
    const width_to_mask_slice = width_to_mask[0..];

    return width_to_mask_slice[if (width > max_supported_bits) 0 else width];
}
