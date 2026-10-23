"""Run tests/run.lua with a Lua 5.1 DLL. Dev-only.

Example:
  python tools/run_tests.py F:\\Download\\aviutl2_v2.1.14\\lua.dll
"""

import ctypes
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    if len(sys.argv) != 2:
        print("usage: python tools/run_tests.py path\\to\\lua.dll", file=sys.stderr)
        return 2
    dll = ctypes.CDLL(sys.argv[1])
    dll.luaL_newstate.restype = ctypes.c_void_p
    dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
    dll.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    dll.luaL_loadfile.restype = ctypes.c_int
    dll.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    dll.lua_pcall.restype = ctypes.c_int
    dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    dll.lua_tolstring.restype = ctypes.c_char_p
    state = dll.luaL_newstate()
    dll.luaL_openlibs(state)
    script = str(ROOT / "tests" / "run.lua").encode("mbcs")
    if dll.luaL_loadfile(state, script) != 0:
        err = dll.lua_tolstring(state, -1, None)
        print(err.decode("utf-8", "replace") if err else "load failed", file=sys.stderr)
        return 1
    if dll.lua_pcall(state, 0, 0, 0) != 0:
        err = dll.lua_tolstring(state, -1, None)
        print(err.decode("utf-8", "replace") if err else "runtime failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
