"""Build our own minimal x64 no-op DLL from the documented RET implementation.

No third-party DLL bytes are read or copied. The sole export is equivalent to
src/rtlcompanion.c; no entry point, imports, RTL layout, font changes or patching.
"""
import struct


def build_stub():
    dll_name = b'rtlcompanion.dll\0'
    function_name = b'RtlCompanionInit\0'
    functions = 40 + len(dll_name)
    names = functions + 4
    ordinals = names + 4
    symbol = ordinals + 2
    exports = struct.pack('<IIHHIIIIIII', 0, 0, 0, 0, 0x2000 + 40, 1, 1, 1,
                          0x2000 + functions, 0x2000 + names, 0x2000 + ordinals)
    exports += dll_name + struct.pack('<IIH', 0x1000, 0x2000 + symbol, 0) + function_name
    dos = bytearray(0x80)
    dos[:2] = b'MZ'
    struct.pack_into('<I', dos, 0x3c, 0x80)
    coff = struct.pack('<HHIIIHH', 0x8664, 2, 0, 0, 0, 240, 0x2022)
    opt = bytearray(240)
    struct.pack_into('<HBBIIIIIQII', opt, 0, 0x20b, 0, 0, 512, 512, 0, 0, 0x1000, 0x180000000, 0x1000, 0x200)
    struct.pack_into('<HHHHHH', opt, 40, 6, 0, 1, 0, 6, 0)
    struct.pack_into('<IIIHH', opt, 56, 0x3000, 0x200, 0, 3, 0x160)
    struct.pack_into('<QQQQII', opt, 72, 0x100000, 0x1000, 0x100000, 0x1000, 0, 16)
    struct.pack_into('<II', opt, 112, 0x2000, len(exports))

    def section(name, size, va, raw, flags):
        return struct.pack('<8sIIIIIIHHI', name, size, va, 512, raw, 0, 0, 0, 0, flags)

    headers = bytes(dos) + b'PE\0\0' + coff + bytes(opt)
    headers += section(b'.text', 1, 0x1000, 0x200, 0x60000020)
    headers += section(b'.rdata', len(exports), 0x2000, 0x400, 0x40000040)
    return headers.ljust(512, b'\0') + b'\xc3'.ljust(512, b'\0') + exports.ljust(512, b'\0')
