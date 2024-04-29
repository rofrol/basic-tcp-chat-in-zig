// For Zig 0.12

const std = @import("std");
const net = std.net;

const ArenaAllocator = std.heap.ArenaAllocator;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const address = try net.Address.parseIp("127.0.0.1", 5501);
    var listener = try address.listen(.{
        .reuse_address = true,
        .kernel_backlog = 1024,
    });
    defer listener.deinit();
    std.log.info("listening at {any}\n", .{address});

    var room = Room{ .lock = .{}, .clients = std.AutoHashMap(*Client, void).init(allocator) };

    while (true) {
        if (listener.accept()) |conn| {
            var client_arena = ArenaAllocator.init(allocator);
            const client = try client_arena.allocator().create(Client);
            errdefer client_arena.deinit();

            client.* = Client.init(client_arena, conn.stream, &room);

            const thread = try std.Thread.spawn(.{}, Client.run, .{client});
            thread.detach();
        } else |err| {
            std.log.err("failed to accept connection {}", .{err});
        }
    }
}

var id_counter: u32 = 0;

const Client = struct {
    room: *Room,
    arena: ArenaAllocator,
    stream: net.Stream,
    id: u32,

    pub fn init(arena: ArenaAllocator, stream: net.Stream, room: *Room) Client {
        id_counter += 1;
        return .{
            .room = room,
            .stream = stream,
            .arena = arena,
            .id = id_counter,
        };
    }

    fn run(self: *Client) !void {
        defer self.arena.deinit();
        try self.room.add(self);
        defer {
            self.room.remove(self);
            self.stream.close();
        }

        const stream = self.stream;
        _ = try stream.write("server: welcome to the chat server\n");
        while (true) {
            var buf: [100]u8 = undefined;
            const n = try stream.read(&buf);
            if (n == 0) {
                return;
            }

            const alloc = self.arena.allocator();
            const alloc_buf = try std.fmt.allocPrint(alloc, "Client {d}> {s}", .{ self.id, buf[0..n] });
            self.room.broadcast(alloc_buf, self);
        }
    }
};
const Room = struct {
    lock: std.Thread.RwLock,
    clients: std.AutoHashMap(*Client, void),

    pub fn add(self: *Room, client: *Client) !void {
        self.lock.lock();
        defer self.lock.unlock();
        try self.clients.put(client, {});
    }

    pub fn remove(self: *Room, client: *Client) void {
        self.lock.lock();
        defer self.lock.unlock();
        _ = self.clients.remove(client);
    }

    fn broadcast(self: *Room, msg: []const u8, sender: *Client) void {
        self.lock.lockShared();
        defer self.lock.unlockShared();

        std.debug.print("{s}", .{msg});
        var it = self.clients.keyIterator();
        while (it.next()) |key_ptr| {
            const client = key_ptr.*;
            if (client == sender) continue;
            _ = client.stream.write(msg) catch |e| std.log.warn("unable to send: {}\n", .{e});
        }
    }
};
