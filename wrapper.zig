const std = @import("std");
pub const LUA_BYTECODE = @embedFile("luac.out");

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
