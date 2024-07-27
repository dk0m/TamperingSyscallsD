
# TamperingSyscallsD

Tampering System Calls Using Hardware Breakpoints For Evasion In D.

## Acknowledgement
This project is based on [TamperingSyscalls](https://github.com/rad9800/TamperingSyscalls/) by rad9800, I have edited the code to be more friendly and evasive by allowing to pass NULL to every argument.


## Passing NULL To All Arguments

In the original [TamperingSyscalls](https://github.com/rad9800/TamperingSyscalls/), The first **4** arguments are passed as **NULL**, But what if the function takes more than 4 arguments? The other parameters are passed on the stack, Meaning we can modify them by using this line of code:
```d
*cast(ULONG_PTR*)(ctx.Rsp + (PARAM_INDEX * PVOID.sizeof)) = ARGUMENT;
```
Perfect! This means we can pass **NULL** to **ALL** arguments to be more evasive, Overall this is how the **NtAllocateVirtualMemory** case looks like:

```d
// Changing the first 4 arguments
ctx.R10 = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.ProcessHandle;
ctx.Rdx = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.BaseAddress;
ctx.R8 = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.ZeroBits;
ctx.R9 = cast(ULONG_PTR)state.NtAllocateVirtualMemoryArgs.RegionSize;

// The other 2 arguments are passed on the stack, Remember, We are passing NULL to everything, Due to AV/EDR's monitoring of the 'Protect' member.
*cast(ULONG_PTR*)(ctx.Rsp + (5 * PVOID.sizeof)) = state.NtAllocateVirtualMemoryArgs.AllocationType;
*cast(ULONG_PTR*)(ctx.Rsp + (6 * PVOID.sizeof)) = state.NtAllocateVirtualMemoryArgs.Protect;

```
