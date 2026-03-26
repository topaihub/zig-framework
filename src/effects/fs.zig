const std = @import("std");

pub const FsEntryKind = enum {
    file,
    directory,
    sym_link,
    other,

    pub fn asText(self: FsEntryKind) []const u8 {
        return switch (self) {
            .file => "file",
            .directory => "directory",
            .sym_link => "sym_link",
            .other => "other",
        };
    }
};

pub const FsEntry = struct {
    name: []u8,
    kind: FsEntryKind,

    pub fn deinit(self: *FsEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

pub const FileSystem = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        read_file_alloc: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) anyerror![]u8,
        write_file: *const fn (ptr: *anyopaque, path: []const u8, bytes: []const u8) anyerror!void,
        atomic_write_file: *const fn (ptr: *anyopaque, path: []const u8, bytes: []const u8) anyerror!void,
        list_dir: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) anyerror![]FsEntry,
        delete_file: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        move_file: *const fn (ptr: *anyopaque, old_path: []const u8, new_path: []const u8) anyerror!void,
        make_path: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        name: *const fn (ptr: *anyopaque) []const u8,
        deinit: ?*const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void = null,
    };

    pub fn readFileAlloc(self: FileSystem, allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) anyerror![]u8 {
        return self.vtable.read_file_alloc(self.ptr, allocator, path, max_bytes);
    }

    pub fn writeFile(self: FileSystem, path: []const u8, bytes: []const u8) anyerror!void {
        return self.vtable.write_file(self.ptr, path, bytes);
    }

    pub fn atomicWriteFile(self: FileSystem, path: []const u8, bytes: []const u8) anyerror!void {
        return self.vtable.atomic_write_file(self.ptr, path, bytes);
    }

    pub fn listDir(self: FileSystem, allocator: std.mem.Allocator, path: []const u8) anyerror![]FsEntry {
        return self.vtable.list_dir(self.ptr, allocator, path);
    }

    pub fn deleteFile(self: FileSystem, path: []const u8) anyerror!void {
        return self.vtable.delete_file(self.ptr, path);
    }

    pub fn moveFile(self: FileSystem, old_path: []const u8, new_path: []const u8) anyerror!void {
        return self.vtable.move_file(self.ptr, old_path, new_path);
    }

    pub fn makePath(self: FileSystem, path: []const u8) anyerror!void {
        return self.vtable.make_path(self.ptr, path);
    }

    pub fn name(self: FileSystem) []const u8 {
        return self.vtable.name(self.ptr);
    }

    pub fn deinit(self: FileSystem, allocator: std.mem.Allocator) void {
        if (self.vtable.deinit) |deinit_fn| deinit_fn(self.ptr, allocator);
    }
};

pub const NativeFileSystem = struct {
    const vtable = FileSystem.VTable{
        .read_file_alloc = readFileAllocErased,
        .write_file = writeFileErased,
        .atomic_write_file = atomicWriteFileErased,
        .list_dir = listDirErased,
        .delete_file = deleteFileErased,
        .move_file = moveFileErased,
        .make_path = makePathErased,
        .name = nameErased,
        .deinit = null,
    };

    pub fn init() NativeFileSystem {
        return .{};
    }

    pub fn fileSystem(self: *NativeFileSystem) FileSystem {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn fileSystemName() []const u8 {
        return "native";
    }

    pub fn readFileAlloc(_: *NativeFileSystem, allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) ![]u8 {
        return std.fs.cwd().readFileAlloc(allocator, path, max_bytes);
    }

    pub fn writeFile(_: *NativeFileSystem, path: []const u8, bytes: []const u8) !void {
        if (std.fs.path.dirname(path)) |dir_name| {
            try std.fs.cwd().makePath(dir_name);
        }
        var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();
        try file.writeAll(bytes);
    }

    pub fn atomicWriteFile(_: *NativeFileSystem, path: []const u8, bytes: []const u8) !void {
        var write_buffer: [4096]u8 = undefined;
        var atomic = try std.fs.cwd().atomicFile(path, .{
            .make_path = true,
            .write_buffer = write_buffer[0..],
        });
        defer atomic.deinit();
        try atomic.file_writer.interface.writeAll(bytes);
        try atomic.finish();
    }

    pub fn listDir(_: *NativeFileSystem, allocator: std.mem.Allocator, path: []const u8) ![]FsEntry {
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();

        var items: std.ArrayListUnmanaged(FsEntry) = .empty;
        errdefer {
            for (items.items) |*item| item.deinit(allocator);
            items.deinit(allocator);
        }

        var it = dir.iterate();
        while (try it.next()) |entry| {
            try items.append(allocator, .{
                .name = try allocator.dupe(u8, entry.name),
                .kind = kindFromEntry(entry.kind),
            });
        }

        return try items.toOwnedSlice(allocator);
    }

    pub fn deleteFile(_: *NativeFileSystem, path: []const u8) !void {
        try std.fs.cwd().deleteFile(path);
    }

    pub fn moveFile(_: *NativeFileSystem, old_path: []const u8, new_path: []const u8) !void {
        if (std.fs.path.dirname(new_path)) |dir_name| {
            try std.fs.cwd().makePath(dir_name);
        }
        try std.fs.cwd().rename(old_path, new_path);
    }

    pub fn makePath(_: *NativeFileSystem, path: []const u8) !void {
        try std.fs.cwd().makePath(path);
    }

    fn readFileAllocErased(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) anyerror![]u8 {
        const self: *NativeFileSystem = @ptrCast(@alignCast(ptr));
        return self.readFileAlloc(allocator, path, max_bytes);
    }

    fn writeFileErased(ptr: *anyopaque, path: []const u8, bytes: []const u8) anyerror!void {
        const self: *NativeFileSystem = @ptrCast(@alignCast(ptr));
        return self.writeFile(path, bytes);
    }

    fn atomicWriteFileErased(ptr: *anyopaque, path: []const u8, bytes: []const u8) anyerror!void {
        const self: *NativeFileSystem = @ptrCast(@alignCast(ptr));
        return self.atomicWriteFile(path, bytes);
    }

    fn listDirErased(ptr: *anyopaque, allocator: std.mem.Allocator, path: []const u8) anyerror![]FsEntry {
        const self: *NativeFileSystem = @ptrCast(@alignCast(ptr));
        return self.listDir(allocator, path);
    }

    fn deleteFileErased(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *NativeFileSystem = @ptrCast(@alignCast(ptr));
        return self.deleteFile(path);
    }

    fn moveFileErased(ptr: *anyopaque, old_path: []const u8, new_path: []const u8) anyerror!void {
        const self: *NativeFileSystem = @ptrCast(@alignCast(ptr));
        return self.moveFile(old_path, new_path);
    }

    fn makePathErased(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *NativeFileSystem = @ptrCast(@alignCast(ptr));
        return self.makePath(path);
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return fileSystemName();
    }
};

fn kindFromEntry(kind: std.fs.Dir.Entry.Kind) FsEntryKind {
    return switch (kind) {
        .file => .file,
        .directory => .directory,
        .sym_link => .sym_link,
        else => .other,
    };
}

fn hasEntry(entries: []const FsEntry, name: []const u8, kind: FsEntryKind) bool {
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.name, name) and entry.kind == kind) return true;
    }
    return false;
}

test "native file system fails when reading a missing file" {
    var fs_native = NativeFileSystem.init();
    try std.testing.expectError(error.FileNotFound, fs_native.readFileAlloc(std.testing.allocator, "missing-file-does-not-exist.txt", 1024));
}

test "native file system writes and reads a file" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);
    const file_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "sample.txt" });
    defer std.testing.allocator.free(file_path);

    var fs_native = NativeFileSystem.init();
    try fs_native.writeFile(file_path, "hello");

    const loaded = try fs_native.readFileAlloc(std.testing.allocator, file_path, 1024);
    defer std.testing.allocator.free(loaded);
    try std.testing.expectEqualStrings("hello", loaded);
}

test "native file system atomic write replaces old content" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);
    const file_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "atomic.txt" });
    defer std.testing.allocator.free(file_path);

    var fs_native = NativeFileSystem.init();
    try fs_native.writeFile(file_path, "old");
    try fs_native.atomicWriteFile(file_path, "new");

    const loaded = try fs_native.readFileAlloc(std.testing.allocator, file_path, 1024);
    defer std.testing.allocator.free(loaded);
    try std.testing.expectEqualStrings("new", loaded);
}

test "native file system lists directory entries" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);
    const nested_dir = try std.fs.path.join(std.testing.allocator, &.{ root_path, "nested" });
    defer std.testing.allocator.free(nested_dir);
    const file_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "hello.txt" });
    defer std.testing.allocator.free(file_path);

    var fs_native = NativeFileSystem.init();
    try fs_native.makePath(nested_dir);
    try fs_native.writeFile(file_path, "hi");

    const entries = try fs_native.listDir(std.testing.allocator, root_path);
    defer {
        for (entries) |*entry| entry.deinit(std.testing.allocator);
        std.testing.allocator.free(entries);
    }

    try std.testing.expect(hasEntry(entries, "nested", .directory));
    try std.testing.expect(hasEntry(entries, "hello.txt", .file));
}

test "native file system deletes a file" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);
    const file_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "delete-me.txt" });
    defer std.testing.allocator.free(file_path);

    var fs_native = NativeFileSystem.init();
    try fs_native.writeFile(file_path, "bye");
    try fs_native.deleteFile(file_path);
    try std.testing.expectError(error.FileNotFound, fs_native.readFileAlloc(std.testing.allocator, file_path, 1024));
}

test "native file system moves a file" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);
    const old_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "old.txt" });
    defer std.testing.allocator.free(old_path);
    const new_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "moved", "new.txt" });
    defer std.testing.allocator.free(new_path);

    var fs_native = NativeFileSystem.init();
    try fs_native.writeFile(old_path, "move");
    try fs_native.moveFile(old_path, new_path);

    const loaded = try fs_native.readFileAlloc(std.testing.allocator, new_path, 1024);
    defer std.testing.allocator.free(loaded);
    try std.testing.expectEqualStrings("move", loaded);
    try std.testing.expectError(error.FileNotFound, fs_native.readFileAlloc(std.testing.allocator, old_path, 1024));
}
