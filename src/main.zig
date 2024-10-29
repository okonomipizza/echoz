const std = @import("std");

const WriteError = error{
    NoFileArgError,
};

const Arg = struct {
    option: bool = false,
    text: ?[]u8 = null,
    file: ?[]u8 = null,

    /// This function sets the properties of `Arg` based on the provided command-line arguments.
    fn fromArgs(self: *Arg, args: [][]u8) void {
        // Check if the "-n" option is provided
        if (std.mem.eql(u8, args[1], "-n")) {
            self.option = true;
            // Ignore any arguments after the fourth
            if (args.len > 3) {
                self.text = args[2];
                self.file = args[3];
            } else if (args.len == 3) {
                self.text = args[2];
            }
        } else {
            if (args.len > 2) {
                self.text = args[1];
                self.file = args[2];
            } else if (args.len == 2) {
                self.text = args[1];
            }
        }
    }

    fn writeFile(self: *Arg) !void {
        if (self.file == null) {
            return error.NoFileArgError;
        }

        _ = std.fs.cwd().makeDir("./outputs") catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
        };

        const outputDir = try std.fs.cwd().openDir("./outputs", .{});

        const filenameWithExtension = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.txt", .{self.file.?});

        const file = try outputDir.createFile(
            filenameWithExtension,
            .{ .read = true },
        );
        defer file.close();

        if (self.text) |text| {
            if (!self.option) {
                var textWithN = std.ArrayList(u8).init(std.heap.page_allocator);
                defer textWithN.deinit();

                try textWithN.appendSlice(text);
                try textWithN.appendSlice("\n");
                const finalString = textWithN.items;

                try file.writeAll(finalString);
            } else {
                try file.writeAll(text);
            }
        } else {
            return error.WriterError;
        }
    }

    fn printText(self: *Arg, writer: anytype) !void {
        if (self.text) |text| {
            if (self.option) {
                try writer.print("{s}", .{text});
            } else {
                try writer.print("{s}\n", .{text});
            }
        }
    }

    fn printFmt(self: *Arg, writer: anytype) !void {
        try writer.print("option: {}\n", .{self.option});

        if (self.text) |text| {
            try writer.print("text: {s}\n", .{text});
        } else {
            try writer.print("text: (none)\n", .{});
        }

        if (self.file) |file| {
            try writer.print("file: {s}\n", .{file});
        } else {
            try writer.print("file: (none)\n", .{});
        }
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    // Exit if no arguments are provided
    if (args.len < 2) {
        std.posix.exit(0);
    }

    var arg = Arg{};
    arg.fromArgs(args);

    if (arg.file != null) {
        _ = try arg.writeFile();
    }

    _ = try arg.printText(stdout);
}
