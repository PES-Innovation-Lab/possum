const std = @import("std");
const p = @import("../common/common.zig").p;
const common = @import("../common/common.zig");
const task = @import("../task/task.zig");

const QueueError = error{
    Full,
    Empty,
};

const Queue = struct {
    front: ?*task.Task,
    rear: ?*task.Task,
    size: usize,

    // queue priority level
    priority: f32,
    time_slice: u32,

    const Self = @This();

    pub fn init(priority: f32, time_slice: u32) Queue {
        return Queue{
            .front = null,
            .rear = null,
            .size = 0,
            .priority = priority,
            .time_slice = time_slice,
        };
    }

    pub fn display(self: *Self) void {
        var ptr = self.front;
        while (ptr) |value| {
            _ = p.printf(
                "[%p {%p, %p, %f}], ",
                @intFromPtr(value),
                @intFromPtr(value.queue_info.prev),
                @intFromPtr(value.queue_info.next),
                value.priority,
            );
            ptr = ptr.?.queue_info.next;
        }
        _ = p.printf("\r\n");
    }

    pub fn enqueue(self: *Self, ntask: *task.Task) void {
        ntask.priority = self.priority;

        if (self.front == null or self.rear == null) {
            self.front = ntask;
            self.rear = ntask;
        } else {
            self.rear.?.queue_info.next = ntask;
            ntask.queue_info.prev = self.rear;
            self.rear = ntask;
            self.rear.?.queue_info.next = null;
        }
    }

    pub fn dequeue(self: *Self) QueueError!*task.Task {
        if (self.front == null or self.rear == null) {
            return QueueError.Empty;
        }

        const ret = self.front.?;

        if (self.front.?.queue_info.next) |next| {
            next.queue_info.prev = null;
            self.front = next;
        } else {
            self.front = null;
            self.rear = null;
        }

        return ret;
    }

    // Pop the task given the task pointer
    // pub fn pop(self: *@This(), taski: *task.Task) QueueError!void {
    //     if (self.front == null or self.rear == null) {
    //         return QueueError.Empty;
    //     }

    //     if (self.front == taski) {
    //         _ = self.dequeue();
    //         return;
    //     } else if (self.rear == taski) {
    //         self.rear = self.rear.?.queue_info.prev;
    //         self.rear.?.queue_info.next = null;
    //         taski.queue_info.prev = null;
    //         return;
    //     }

    //     // if the task is in the middle of the queue
    //     taski.queue_info.prev.?.queue_info.next = taski.queue_info.next;
    //     taski.queue_info.next.?.queue_info.prev = taski.queue_info.prev;

    //     taski.queue_info.prev = null;
    //     taski.queue_info.next = null;
    //     return;
    // }
};

pub const Levels = struct {
    levels: [common.SCHEDULER_LEVELS]Queue,
    /// current execution level
    current_level: usize,
    /// highest level which is not empty, updated on envets such as
    /// task creation and task inversion to a higher level
    highest_level: usize,
    /// pointer to the currently executing task
    current_task: ?*task.Task,
    last_task: ?*task.Task,

    const Self = @This();

    pub fn init(timeslice: [common.SCHEDULER_LEVELS]u32) Levels {
        var queue_levels: [common.SCHEDULER_LEVELS]Queue = undefined;

        for (0..common.SCHEDULER_LEVELS) |i| {
            queue_levels[i] = Queue.init(@as(f32, i + 1), timeslice[i]);
            // _ = p.printf("[DEBUG] level with p = %f, ts = %d\r\n", levels[i].priority, levels[i].time_slice);
        }

        const levels = Levels{
            .levels = queue_levels,
            .current_level = common.SCHEDULER_LEVELS - 1,
            .highest_level = common.SCHEDULER_LEVELS - 1,
            .current_task = null,
            .last_task = null,
        };

        return levels;
    }

    pub fn push_new(self: *Self, taski: *task.Task) void {
        // make the new task inherit the priority of the
        // top most queue
        // const inherited_priority: f32 = self.levels[common.SCHEDULER_LEVELS - 1].priority;
        // taski.priority = inherited_priority;

        self.levels[common.SCHEDULER_LEVELS - 1].enqueue(taski);
        _ = p.printf(
            "[DEBUG] task %p, priority %f, level %d\r\n",
            @intFromPtr(taski),
            taski.priority,
            common.SCHEDULER_LEVELS - 1,
        );
        _ = p.printf("front [%p] and rear [%p]\r\n", @intFromPtr(self.*.levels[self.*.current_level].front), @intFromPtr(self.*.levels[self.*.current_level].rear));
        // if (self.*.levels[self.*.current_level].rear != null or self.*.levels[self.*.current_level].front != null) {
        //     _ = p.printf("front [%p] and rear [%p]\r\n", @intFromPtr(self.*.levels[self.*.current_level].front.?.callback), @intFromPtr(self.*.levels[self.*.current_level].rear.?.callback));
        // }

        // if the current level is the top most level where the
        // task is enqueued, we move the rear of the queue to the
        // new task
        if (self.*.current_level == common.SCHEDULER_LEVELS - 1) {
            self.*.last_task = self.*.levels[self.*.current_level].rear;
            // _ = p.printf("[DEBUG] current level is same as top, making rear as the first element\r\n");
        }

        self.*.highest_level = common.SCHEDULER_LEVELS - 1;
        // _ = p.printf("[DEBUG] highest level %d\r\n", self.*.highest_level);
    }

    pub fn get_current(self: *Self) *task.Task {
        const task_front = self.levels[self.current_level].front.?;
        _ = p.printf(
            "[DEBUG] Task %p(%f) at front of queue %d\r\n",
            @intFromPtr(task_front),
            task_front.*.priority,
            self.current_level,
        );
        return task_front;
    }

    pub fn get_next(self: *@This()) void {
        // move the task based on the decay result on
        // the current task
        const old_priority = self.*.current_task.?.priority;
        const decay_result = self.*.current_task.?.decay();
        const new_priority = self.*.current_task.?.priority;
        _ = p.printf(
            "[INFO] After decay -> old %f, new %f",
            old_priority,
            new_priority,
        );
        switch (decay_result) {
            // if the task just decays, we dequeue it and
            // push it to the back of the queue and the new
            // current task would be in the front
            task.DecayResult.Decay => {
                _ = self.*.levels[self.*.current_level].dequeue() catch {};
                self.*.levels[self.*.current_level].enqueue(self.*.current_task.?);
                self.*.current_task = self.*.levels[self.*.current_level].front;
            },

            // it the task inverts to a higher level, or if it
            // decays to a lower level, we dequeue it and enqueue
            // the task to its new level
            task.DecayResult.InverseDecay, task.DecayResult.LevelDecay => {
                _ = self.*.levels[self.*.current_level].dequeue() catch {};
                const new_level_usize: usize = @intFromFloat(@ceil(self.*.current_task.?.priority));
                self.*.levels[new_level_usize - 1].enqueue(self.*.current_task.?);

                // if the task moves to a level which is higher than the
                // current level, then we update self.highest_level
                if (new_level_usize > self.*.highest_level) {
                    self.*.highest_level = new_level_usize;
                }
            },
        }

        // select the queue from where it is supposed to execute
        // if the current queue is null or, if we reach the end of
        // the queue
        if (self.*.levels[self.*.current_level].front == null or self.*.current_task == self.*.last_task) {
            // the level is empty, search for the next level
            // from the top of the queue high to low priority
            var i: usize = common.SCHEDULER_LEVELS - 1;

            while (i >= 0) : (i -= 1) {
                if (self.*.levels[i].front) |taski| {
                    self.*.current_level = i;
                    self.*.current_task = taski;
                    self.*.last_task = self.*.levels[i].rear;
                }
            }
        } else {
            // continue if the current level is not empty, or
            // if we have not reached the last_task in the queue
            self.*.current_task = self.*.levels[self.*.current_level].front;
        }
    }
};

/// NOTE (from the arm docs)
/// when the processor takes an exception (tail chained
/// or if its late arrival) it pushes the following onto
/// the stack (going down memory addresses)
///
/// ```text
/// <previous>
/// SP + 0x1c xPSR
/// SP + 0x18 PC (R15) -> next instr of the interrupted
///                       program
/// SP + 0x14 LR (R14)
/// SP + 0x10 R12 <- intra procedure call
/// SP + 0x0c R3
/// SP + 0x08 R2
/// SP + 0x04 R1
/// SP + 0x00 R0 <- this is where SP will be at the intr.
/// ```
///
/// hence the hardware already saves these parts for us,
/// while servicing an interrupt, for a context switch
/// we would need to store the remaining R4-R11(FP) to
/// be pushed onto the stack
///
/// while the processor executes the except. handler
/// it writes the EXC_RETURN address to LR, which
/// signifies which SP corresponds to the stack frame
/// and the opr. mode of the processor
///
/// the EXC_RETURN value is used by the processor to
/// check if it has completed an exception. [31:4] bits
/// being 0xFFFFFFF, when loaded to PC, its not a regular
/// branch opr, rather exception is complete
///
/// ```text
/// 0xFFFFFFF1 -> ret to handler, MSP used and state
///               is retrieved from MSP
/// 0xFFFFFFF9 -> ret to thread, MSP used and state
///               is retrieved from MSP
///
/// 0xFFFFFFFD -> ret to handler, PSP used and state
///               is retrieved from PSP
/// ```
///
/// from `src/switch.s` the pop {pc} attempts to load
/// 0xFFFFFFFD into the pc
///
pub const Scheduler = struct {
    stacks: [common.TOTAL_TASKS][common.PSTACK_SIZE]u32,
    // tasks: [TOTAL_TASKS]*u32,
    tasks: [common.TOTAL_TASKS]task.Task,

    task_count: usize,
    // current_task: usize,

    // current: *task.Task,

    levels: Levels,

    scheduler_lock: std.atomic.Value(bool),

    const Self = @This();

    pub fn new(timeslices: [common.SCHEDULER_LEVELS]u32) Self {
        const ret = Scheduler{
            .stacks = .{.{0} ** common.PSTACK_SIZE} ** common.TOTAL_TASKS,
            .tasks = undefined,
            .task_count = 0,
            .scheduler_lock = std.atomic.Value(bool).init(false),

            .levels = Levels.init(timeslices),
        };

        return ret;
    }

    pub fn create_task(
        self: *Self,
        task_func: common.generic_func,
        data: ?*anyopaque,
        multiplier: f32,
    ) void {
        // we mimick the stack frame
        // 256 - 17 -> how much we are pushing to the stack
        const offset: usize = common.PSTACK_SIZE - 17;

        const n = self.task_count;

        // return to thread mode with PSP
        self.stacks[n][offset + 8] = 0xFFFFFFFD;
        self.stacks[n][offset + 15] = @as(u32, @intFromPtr(task_func));

        // PSR thumb bit
        // SPSEL bit [1] of CONTROL reg defines the stack to
        // be used
        //      - 0 = MSP
        //      - 1 = PSP
        // "In Handler mode this bit reads as zero and ignores
        // writes."
        self.stacks[n][offset + 16] = 0x01000000;

        const new_task = task.Task.new(task_func, data, &self.stacks[n][offset], multiplier);
        self.tasks[n] = new_task;
        // self.tasks[n] = &self.stacks[n][offset];

        self.task_count += 1;

        _ = p.printf("[DEBUG] task callback address %p with task id %d\r\n", @intFromPtr(&self.tasks[n]), self.task_count - 1);
        // this should be the PSP
        // _ = p.printf("base addr of task %d: %p\r\n", n, &self.tasks[n]);
        //
        // const excep_ret: *u32 = @ptrFromInt(@intFromPtr(self.tasks[n]) + @sizeOf(u32) * 8);
        // _ = p.printf("exception return addr for task %p\r\n", excep_ret.*);

        _ = p.printf("previous rear [%p]\r\n", @intFromPtr(self.levels.levels[common.SCHEDULER_LEVELS - 1].rear));
        // self.levels.levels[common.SCHEDULER_LEVELS - 1].display();
        self.levels.push_new(&self.tasks[n]);
        // self.levels.levels[common.SCHEDULER_LEVELS - 1].display();
    }

    pub fn get_current_task(self: *Self) *task.Task {
        const current = self.levels.get_current();
        // _ = p.printf("[DEBUG] current task [%p] priority: %d, current\r\n", @intFromPtr(current.*.callback), current.*.priority);
        _ = p.printf(
            "[DEBUG] current task %p with priority %f\r\n",
            @intFromPtr(self.levels.levels[self.levels.current_level].front),
            self.levels.levels[self.levels.current_level].front.?.priority,
        );

        return current;
    }

    pub fn get_queue_timeslice(self: *Self) u32 {
        _ = p.printf(
            "[DEBUG] level %d time slice %d\r\n",
            self.*.levels.current_level,
            self.*.levels.levels[self.*.levels.current_level].time_slice,
        );
        // _ = p.printf("[DEBUG] current level's time slice %d\r\n", levels.levels[levels.current_level].priority);
        return self.*.levels.levels[self.*.levels.current_level].time_slice;
    }

    pub fn next(self: *Self) void {
        // const current = self.get_current();
        _ = p.printf("[INFO] priority of current task %f\r\n", self.get_current_task().*.priority);
        self.levels.get_next();

        // self.current_task = (self.current_task + 1) % self.task_count;
        // return self.tasks[self.current_task];
    }

    // scheduler locking
    pub fn lock(self: *Self) void {
        while (self.scheduler_lock.swap(true, .acq_rel)) {
            // spin
        }
    }

    pub fn unlock(self: *Self) void {
        self.scheduler_lock.store(false, .release);
    }
};
