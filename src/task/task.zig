const std = @import("std");
const p = @import("../common/common.zig").p;
const common = @import("../common/common.zig");
const uart = @import("../uart/uart.zig");
// const sched = common.sched;

pub const Task = struct {
    callback: common.generic_func,
    data: ?*anyopaque,
    stack_start: *u32,
    priority: usize,
    identifier: [8]u8,
    killed: bool = false,

    const Self = @This();

    pub fn new(
        task_func: common.generic_func,
        data: ?*anyopaque,
        stack_start: *u32,
        priority: usize,
        identifier: [8]u8,
    ) Task {
        return Task{
            .callback = task_func,
            .data = data,
            .stack_start = stack_start,
            .priority = priority,
            .identifier = identifier,
        };
    }
};

pub const ProgramData = struct {
    data: [*]u8,
    entry_offset: usize,
    identifier: [8]u8,
};

pub fn handle_directives() void {
    _ = p.printf("[CORE1] Waiting for LOADPROG keyword\r\n");

    var keyword_buf: [8]u8 = undefined;
    while (true) {
        _ = p.scanf("%8s", &keyword_buf);
        if (std.mem.eql(u8, &keyword_buf, common.LOAD_DIRECTIVE)) {
            _ = p.printf("[CORE1] LOADPROG received!\r\n");
            receive_program_uart();
            // return prog_data_opt;
        } else if (std.mem.eql(u8, &keyword_buf, common.KILL_DIRECTIVE)) {
            _ = p.printf("[CORE1] KILLTASK received!\r\n");
            kill_task();
            break;
        } else if (std.mem.eql(u8, &keyword_buf, common.RELAUNCH_DIRECTIVE)) {
            _ = p.printf("[CORE1] RELAUNCH received!\r\n");
            reload_task();
            break;
        } else if (std.mem.eql(u8, &keyword_buf, common.LIST_DIRECTIVE)) {
            _ = p.printf("[CORE1] Keyword received: '%.8s'\r\n", &keyword_buf);
            _ = p.printf("[CORE1] LIST received!\r\n");
            list_task();
            break;
        } else {
            _ = p.printf("[CORE1] Unknown keyword: %s\r\n", &keyword_buf);
        }
    }
}

pub fn receive_program_uart() void {
    var size_buf: [8]u8 = undefined;
    uart.uart_read_exact(size_buf[0..8]);
    const prog_size: usize = @intCast(std.mem.bytesToValue(u64, size_buf[0..8]));
    _ = p.printf("[CORE1] Program size: %d bytes\r\n", prog_size);

    if (prog_size == 0 or prog_size > 65536) {
        _ = p.printf("[CORE1] Invalid program size!\r\n");
        return;
    }

    var entry_buf: [8]u8 = undefined;
    uart.uart_read_exact(entry_buf[0..8]);
    const entry_offset: usize = @intCast(std.mem.bytesToValue(u64, entry_buf[0..8]));
    _ = p.printf("[CORE1] Entry offset: 0x%x\r\n", entry_offset);

    var identifier: [8]u8 = undefined;
    uart.uart_read_exact(identifier[0..8]);
    _ = p.printf("[CORE1] Program identifier: %s\r\n", &identifier);

    const prog_bytes_alloc = p.malloc(prog_size);
    if (prog_bytes_alloc) |prog_bytes_heap| {
        var prog_bytes: [*]u8 = @ptrCast(@alignCast(prog_bytes_heap));
        uart.uart_read_exact(prog_bytes[0..prog_size]);
        _ = p.printf("[CORE1] Program received!\r\n");

        var prog_data = ProgramData{
            .data = prog_bytes,
            .entry_offset = entry_offset,
            .identifier = identifier,
        };
        const prog_ptr: *const fn (*anyopaque) void = @ptrFromInt(@intFromPtr(&prog_data.data[0]) + prog_data.entry_offset);
        common.sched.lock();
        common.sched.create_task(
            prog_ptr,
            null,
            0,
            identifier,
        );
        common.sched.unlock();
    }

    return;
}

pub fn kill_task() void {
    var identifier: [8]u8 = undefined;
    uart.uart_read_exact(identifier[0..8]);
    common.sched.lock();
    const killed = common.sched.kill_task(identifier);
    common.sched.unlock();
    if (killed) {
        _ = p.printf("[CORE1] Task killed: %s\r\n", &identifier);
    } else {
        _ = p.printf("[CORE1] Task not found: %s\r\n", &identifier);
    }
}

pub fn reload_task() void {
    var identifier: [8]u8 = undefined;
    uart.uart_read_exact(identifier[0..8]);
    common.sched.lock();
    const success = common.sched.relaunch_task(identifier);
    common.sched.unlock();
    if (success) {
        _ = p.printf("[CORE1] Task re-launched: %s\r\n", &identifier);
    } else {
        _ = p.printf("[CORE1] Task not found: %s\r\n", &identifier);
    }
}

pub fn list_task() void {
    //var identifier: [8]u8 = undefined;
    //uart.uart_read_exact(identifier[0..8]);
    common.sched.lock();
    common.sched.list_tasks(); //here it shud ideally print off
    common.sched.unlock();
}
