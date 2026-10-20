/* MIT - Copyright (c) 2026 AKIE contributors.
 * Thai uses left-to-right layout. Deliberately omit the upstream RTL helper.
 * This compatibility export performs no patching and imports no Windows APIs.
 * tools/build_stub.py emits the equivalent x64 RET implementation as a
 * deterministic, import-free PE DLL, so no native compiler is needed.
 */
__declspec(dllexport) void RtlCompanionInit(void) {}
