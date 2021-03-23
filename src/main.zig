const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;
const fmt = std.fmt;
const warn = std.debug.warn;

const svd = @import("svd.zig");

var line_buffer: [1024 * 1024]u8 = undefined;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var args = std.process.args();

    _ = args.next(allocator); // skip application name
    // Note memory will be freed on exit since using arena

    const file_name = try args.next(allocator) orelse return error.MandatoryFilenameArgumentNotGiven;
    const file = try std.fs.cwd().openFile(file_name, .{ .read = true, .write = false });

    const stream = &file.reader();

    var state = SvdParseState.Device;
    var dev = try svd.Device.init(allocator);
    while (try stream.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        if (line.len == 0) {
            break;
        }
        var chunk = getChunk(line) orelse continue;
        switch (state) {
            .Device => {
                if (ascii.eqlIgnoreCase(chunk.tag, "/device")) {
                    state = .Finished;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "name")) {
                    if (chunk.data) |data| {
                        try dev.name.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "version")) {
                    if (chunk.data) |data| {
                        try dev.version.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "description")) {
                    if (chunk.data) |data| {
                        try dev.description.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "cpu")) {
                    var cpu = try svd.Cpu.init(allocator);
                    dev.cpu = cpu;
                    state = .Cpu;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "addressUnitBits")) {
                    if (chunk.data) |data| {
                        dev.address_unit_bits = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "width")) {
                    if (chunk.data) |data| {
                        dev.max_bit_width = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "size")) {
                    if (chunk.data) |data| {
                        dev.reg_default_size = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "resetValue")) {
                    if (chunk.data) |data| {
                        dev.reg_default_reset_value = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "resetMask")) {
                    if (chunk.data) |data| {
                        dev.reg_default_reset_mask = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "peripherals")) {
                    state = .Peripherals;
                }
            },
            .Cpu => {
                if (ascii.eqlIgnoreCase(chunk.tag, "/cpu")) {
                    state = .Device;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "name")) {
                    if (chunk.data) |data| {
                        try dev.cpu.?.name.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "revision")) {
                    if (chunk.data) |data| {
                        try dev.cpu.?.revision.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "endian")) {
                    if (chunk.data) |data| {
                        try dev.cpu.?.endian.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "mpuPresent")) {
                    if (chunk.data) |data| {
                        dev.cpu.?.mpu_present = textToBool(data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "fpuPresent")) {
                    if (chunk.data) |data| {
                        dev.cpu.?.fpu_present = textToBool(data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "nvicPrioBits")) {
                    if (chunk.data) |data| {
                        dev.cpu.?.nvic_prio_bits = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "vendorSystickConfig")) {
                    if (chunk.data) |data| {
                        dev.cpu.?.vendor_systick_config = textToBool(data);
                    }
                }
            },
            .Peripherals => {
                if (ascii.eqlIgnoreCase(chunk.tag, "/peripherals")) {
                    state = .Device;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "peripheral")) {
                    if (chunk.derivedFrom) |derivedFrom| {
                        for (dev.peripherals.items) |periph_being_checked| {
                            if (mem.eql(u8, periph_being_checked.name.items, derivedFrom)) {
                                try dev.peripherals.append(try periph_being_checked.copy(allocator));
                                state = .Peripheral;
                                break;
                            }
                        }
                    } else {
                        var periph = try svd.Peripheral.init(allocator);
                        try dev.peripherals.append(periph);
                        state = .Peripheral;
                    }
                }
            },
            .Peripheral => {
                var cur_periph = &dev.peripherals.items[dev.peripherals.items.len - 1];
                if (ascii.eqlIgnoreCase(chunk.tag, "/peripheral")) {
                    state = .Peripherals;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "name")) {
                    if (chunk.data) |data| {
                        // periph could be copy, must update periph name in sub-fields
                        try cur_periph.name.insertSlice(0, data);
                        for (cur_periph.registers.items) |*reg| {
                            try reg.periph_containing.insertSlice(0, data);
                            for (reg.fields.items) |*field| {
                                try field.periph.insertSlice(0, data);
                            }
                        }
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "description")) {
                    if (chunk.data) |data| {
                        try cur_periph.description.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "groupName")) {
                    if (chunk.data) |data| {
                        try cur_periph.group_name.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "baseAddress")) {
                    if (chunk.data) |data| {
                        cur_periph.base_address = parseHexLiteral(data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "addressBlock")) {
                    if (cur_periph.address_block) |x| {
                        // do nothing
                    } else {
                        var block = try svd.AddressBlock.init(allocator);
                        cur_periph.address_block = block;
                    }
                    state = .AddressBlock;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "interrupt")) {
                    var interrupt = try svd.Interrupt.init(allocator);
                    try dev.interrupts.append(interrupt);
                    state = .Interrupt;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "registers")) {
                    state = .Registers;
                }
            },
            .AddressBlock => {
                var cur_periph = &dev.peripherals.items[dev.peripherals.items.len - 1];
                var address_block = &cur_periph.address_block.?;
                if (ascii.eqlIgnoreCase(chunk.tag, "/addressBlock")) {
                    state = .Peripheral;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "offset")) {
                    if (chunk.data) |data| {
                        address_block.offset = parseHexLiteral(data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "size")) {
                    if (chunk.data) |data| {
                        address_block.size = parseHexLiteral(data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "usage")) {
                    if (chunk.data) |data| {
                        try address_block.usage.insertSlice(0, data);
                    }
                }
            },
            .Interrupt => {
                var cur_interrupt = &dev.interrupts.items[dev.interrupts.items.len - 1];

                if (ascii.eqlIgnoreCase(chunk.tag, "/interrupt")) {
                    state = .Peripheral;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "name")) {
                    if (chunk.data) |data| {
                        try cur_interrupt.name.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "description")) {
                    if (chunk.data) |data| {
                        try cur_interrupt.description.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "value")) {
                    if (chunk.data) |data| {
                        cur_interrupt.value = fmt.parseInt(u32, data, 10) catch null;
                    }
                }
            },
            .Registers => {
                var cur_periph = &dev.peripherals.items[dev.peripherals.items.len - 1];
                if (ascii.eqlIgnoreCase(chunk.tag, "/registers")) {
                    state = .Peripheral;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "register")) {
                    if (cur_periph.base_address == null) break;
                    const base_address = cur_periph.base_address.?;

                    const reset_value = dev.reg_default_reset_value orelse 0;
                    const size = dev.reg_default_size orelse 32;
                    var register = try svd.Register.init(allocator, cur_periph.name.items, base_address, reset_value, size);
                    try cur_periph.registers.append(register);
                    state = .Register;
                }
            },
            .Register => {
                var cur_periph = &dev.peripherals.items[dev.peripherals.items.len - 1];
                var cur_reg = &cur_periph.registers.items[cur_periph.registers.items.len - 1];
                if (ascii.eqlIgnoreCase(chunk.tag, "/register")) {
                    state = .Registers;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "name")) {
                    if (chunk.data) |data| {
                        try cur_reg.name.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "displayName")) {
                    if (chunk.data) |data| {
                        try cur_reg.display_name.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "description")) {
                    if (chunk.data) |data| {
                        try cur_reg.description.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "addressOffset")) {
                    if (chunk.data) |data| {
                        cur_reg.address_offset = parseHexLiteral(data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "size")) {
                    if (chunk.data) |data| {
                        cur_reg.size = parseHexLiteral(data) orelse cur_reg.size;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "access")) {
                    if (chunk.data) |data| {
                        cur_reg.access = parseAccessValue(data) orelse cur_reg.access;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "resetValue")) {
                    if (chunk.data) |data| {
                        cur_reg.reset_value = parseHexLiteral(data) orelse cur_reg.reset_value; // TODO: test orelse break
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "fields")) {
                    state = .Fields;
                }
            },
            .Fields => {
                var cur_periph = &dev.peripherals.items[dev.peripherals.items.len - 1];
                var cur_reg = &cur_periph.registers.items[cur_periph.registers.items.len - 1];
                if (ascii.eqlIgnoreCase(chunk.tag, "/fields")) {
                    state = .Register;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "field")) {
                    var field = try svd.Field.init(allocator, cur_periph.name.items, cur_reg.name.items);
                    try cur_reg.fields.append(field);
                    state = .Field;
                }
            },
            .Field => {
                var cur_periph = &dev.peripherals.items[dev.peripherals.items.len - 1];
                var cur_reg = &cur_periph.registers.items[cur_periph.registers.items.len - 1];
                var cur_field = &cur_reg.fields.items[cur_reg.fields.items.len - 1];
                if (ascii.eqlIgnoreCase(chunk.tag, "/field")) {
                    state = .Fields;
                } else if (ascii.eqlIgnoreCase(chunk.tag, "name")) {
                    if (chunk.data) |data| {
                        try cur_field.name.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "description")) {
                    if (chunk.data) |data| {
                        try cur_field.description.insertSlice(0, data);
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "bitOffset")) {
                    if (chunk.data) |data| {
                        cur_field.bit_offset = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "bitWidth")) {
                    if (chunk.data) |data| {
                        cur_field.bit_width = fmt.parseInt(u32, data, 10) catch null;
                    }
                } else if (ascii.eqlIgnoreCase(chunk.tag, "access")) {
                    if (chunk.data) |data| {
                        cur_field.access = parseAccessValue(data) orelse cur_field.access;
                    }
                }
            },
            .Finished => {
                // wait for EOF
            },
        }
    }
    if (state == .Finished) {
        try std.io.getStdOut().writer().print("{}\n", .{dev});
    } else {
        return error.InvalidXML;
    }
}

const SvdParseState = enum {
    Device,
    Cpu,
    Peripherals,
    Peripheral,
    AddressBlock,
    Interrupt,
    Registers,
    Register,
    Fields,
    Field,
    Finished,
};

const XmlChunk = struct {
    tag: []const u8,
    data: ?[]const u8,
    derivedFrom: ?[]const u8,
};

fn getChunk(line: []const u8) ?XmlChunk {
    var chunk = XmlChunk{
        .tag = undefined,
        .data = null,
        .derivedFrom = null,
    };

    var trimmed = mem.trim(u8, line, " \n");
    var toker = mem.tokenize(trimmed, "<>"); //" =\n<>\"");

    if (toker.next()) |maybe_tag| {
        var tag_toker = mem.tokenize(maybe_tag, " =\"");
        chunk.tag = tag_toker.next() orelse return null;
        if (tag_toker.next()) |maybe_tag_property| {
            if (ascii.eqlIgnoreCase(maybe_tag_property, "derivedFrom")) {
                chunk.derivedFrom = tag_toker.next();
            }
        }
    } else {
        return null;
    }

    if (toker.next()) |chunk_data| {
        chunk.data = chunk_data;
    }

    return chunk;
}

test "getChunk" {
    const valid_xml = "  <name>STM32F7x7</name>  \n";
    const expected_chunk = XmlChunk{ .tag = "name", .data = "STM32F7x7", .derivedFrom = null };

    const chunk = getChunk(valid_xml).?;
    std.testing.expectEqualSlices(u8, chunk.tag, expected_chunk.tag);
    std.testing.expectEqualSlices(u8, chunk.data.?, expected_chunk.data.?);

    const no_data_xml = "  <name> \n";
    const expected_no_data_chunk = XmlChunk{ .tag = "name", .data = null, .derivedFrom = null };
    const no_data_chunk = getChunk(no_data_xml).?;
    std.testing.expectEqualSlices(u8, no_data_chunk.tag, expected_no_data_chunk.tag);
    std.testing.expectEqual(no_data_chunk.data, expected_no_data_chunk.data);

    const comments_xml = "<description>Auxiliary Cache Control register</description>";
    const expected_comments_chunk = XmlChunk{ .tag = "description", .data = "Auxiliary Cache Control register", .derivedFrom = null };
    const comments_chunk = getChunk(comments_xml).?;
    std.testing.expectEqualSlices(u8, comments_chunk.tag, expected_comments_chunk.tag);
    std.testing.expectEqualSlices(u8, comments_chunk.data.?, expected_comments_chunk.data.?);

    const derived = "   <peripheral derivedFrom=\"TIM10\">";
    const expected_derived_chunk = XmlChunk{ .tag = "peripheral", .data = null, .derivedFrom = "TIM10" };
    const derived_chunk = getChunk(derived).?;
    std.testing.expectEqualSlices(u8, derived_chunk.tag, expected_derived_chunk.tag);
    std.testing.expectEqualSlices(u8, derived_chunk.derivedFrom.?, expected_derived_chunk.derivedFrom.?);
    std.testing.expectEqual(derived_chunk.data, expected_derived_chunk.data);
}

fn textToBool(data: []const u8) ?bool {
    if (ascii.eqlIgnoreCase(data, "true")) {
        return true;
    } else if (ascii.eqlIgnoreCase(data, "false")) {
        return false;
    } else {
        return null;
    }
}

fn parseHexLiteral(data: []const u8) ?u32 {
    if (data.len <= 2) return null;
    return fmt.parseInt(u32, data[2..], 16) catch null;
}

fn parseAccessValue(data: []const u8) ?svd.Access {
    if (ascii.eqlIgnoreCase(data, "read-write")) {
        return .ReadWrite;
    } else if (ascii.eqlIgnoreCase(data, "read-only")) {
        return .ReadOnly;
    } else if (ascii.eqlIgnoreCase(data, "write-only")) {
        return .WriteOnly;
    }
    return null;
}
