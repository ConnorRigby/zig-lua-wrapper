# Using Zig to build Native Lua Scripts

I've been playing with [Zig](https://ziglang.org/) a lot lately.
It's one of my favorite pieces of tech I've found in
the last few years. One of my favorite features is how easy it
is to compile C libraries with it. Of course
when I think "C libraries", the first that comes to mind is `Lua`.

Lua is a really cool "embeddable" progrramming language. It's
made to be put "inside" larger projects primarily. Some examples
of things that use Lua include

* [LÖVE](https://love2d.org/)
* [Nginx](https://www.nginx.com/resources/wiki/modules/lua/)
* [World of Warcraft](https://wowwiki-archive.fandom.com/wiki/Lua)

So of course, to run in so many places, Lua itself has been built
from the ground up to be "embedded". It is distributed as an archive
C source files and documentation. This is great news for us with Zig,
since [Zig is a c compiler](https://andrewkelley.me/post/zig-cc-powerful-drop-in-replacement-gcc-clang.html)!

Getting Lua to compile inside a Zig project is *really* easy! easier than
C/C++ in my opinion. I'll glaze the details, plucking the important parts

First, in `build.zig`, we need to link libc, and add it's source files.
This looks like:

```zig
const exe = b.addExecutable("wrapper", "wrapper.zig");
exe.setTarget(target);
exe.setBuildMode(mode);
exe.linkLibC();
exe.addIncludeDir("lua-5.3.4/src");

const lua_c_files = [_][]const u8{
    "lapi.c",
    "lauxlib.c",
    "lbaselib.c",
    "lbitlib.c",
    "lcode.c",
    "lcorolib.c",
    "lctype.c",
    "ldblib.c",
    "ldebug.c",
    "ldo.c",
    "ldump.c",
    "lfunc.c",
    "lgc.c",
    "linit.c",
    "liolib.c",
    "llex.c",
    "lmathlib.c",
    "lmem.c",
    "loadlib.c",
    "lobject.c",
    "lopcodes.c",
    "loslib.c",
    "lparser.c",
    "lstate.c",
    "lstring.c",
    "lstrlib.c",
    "ltable.c",
    "ltablib.c",
    "ltm.c",
    "lundump.c",
    "lutf8lib.c",
    "lvm.c",
    "lzio.c",
};

if(target.os_tag == std.Target.Os.Tag.windows) {
    const c_flags = [_][]const u8{
        "-std=c99",
        "-O2",
        "-DLUA_USE_WINDOWS"
    };
    inline for (lua_c_files) |c_file| {
        exe.addCSourceFile("lua-5.3.4/src/" ++ c_file, &c_flags);
    }
} else {
    const c_flags = [_][]const u8{
        "-std=c99",
        "-O2",
        "-DLUA_USE_POSIX",
    };
    inline for (lua_c_files) |c_file| {
        exe.addCSourceFile("lua-5.3.4/src/" ++ c_file, &c_flags);
    }
}
exe.install();
```

That's really it! It even adds support for Windows. All that's
left is to just use it. This works like any other C library with Zig.
For this project, I decided I would make a single executable out of a
Lua script. Here's the source of the Lua script to give additional context:

```lua
print("press Y")

local input = "\0"

while(input ~= 'y' and input ~= 'Y') do
  input = io.read(1)
end

print("🥧")
```

So all the Zig code needs to do is somehow "embed" that script, and execute it
inside of the Lua VM. Lua offers a `luac` executable to compile a script file
into a chunk of Lua bytecode that can then be executed. This isn't strictly
necessary, but i compiled the `luac` executable with Zig:

```bash
make -C lua-5.3.4/ generic CC="zig cc"
```

Next I compiled my script:

```bash
./lua-5.3.4/src/luac main.lua
```

Which outputs a `luac.out` file. This itself obviously isn't an executable tho.
Luckily, Zig has a built-in for us to use:

```zig
pub const LUA_BYTECODE = @embedFile("luac.out");
```

Finally, all that's left is to execute the bytecode with `lua_pcallk`:

```zig
const lua = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

pub fn main() anyerror!void {
    var s = lua.luaL_newstate();
    lua.luaL_openlibs(s);
    const load_status = lua.luaL_loadbufferx(s, LUA_BYTECODE, LUA_BYTECODE.len, "main.lua", "bt");
    if (load_status != 0) {
        std.log.info("Couldn't load lua bytecode: {s}", .{lua.lua_tolstring(s, -1, null)});
        return;
    }
    const call_status = lua.lua_pcallk(s, 0, lua.LUA_MULTRET, 0, 0, null);
    if (call_status != 0) {
        std.log.info("{s}", .{lua.lua_tolstring(s, -1, null)});
        return;
    }
}
```

I tested this out on my arm Mac, an x86 Mac, my Windows PC, WSL, and on several
Linux installations and it works great!

Compiling is done with:

```bash
zig build -Drelease-small -Dtarget=<target>
```

Where target can be one of:

* `x86_64-windows`
* `x86_64-macos`
* `aarch64-macos`
* `aarch64-linux-musl`
* `x86_64-linux-musl`

I'm sure there are other targets that work, but those are the ones
I tested.

All the source for this project is [On Github](https://github.com/ConnorRigby/zig-lua-wrapper)
