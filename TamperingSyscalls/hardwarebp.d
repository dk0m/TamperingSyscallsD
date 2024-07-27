module hardwarebp;

import std.stdio;
import core.sys.windows.windows;

enum Drx {
    Dr0,
    Dr1,
    Dr2,
    Dr3,
}

ulong setDr7Bits(ulong currDr7, int startingBitPos, int nmberOfBitsToModify, ulong newDr7) {

    ulong mask = (1UL << nmberOfBitsToModify) - 1UL;
    ulong NewDr7Register = (currDr7 & ~(mask << startingBitPos)) | (newDr7 << startingBitPos);

    return NewDr7Register;

}

PVOID g_Veh;

BOOL setHwBp(PVOID pAddress, Drx drx) {

    CONTEXT threadCtx;
    threadCtx.ContextFlags = CONTEXT_DEBUG_REGISTERS;

    if (!GetThreadContext(cast(HANDLE)-2, &threadCtx)) {
        return FALSE;
    }

    switch(drx) {
        case Drx.Dr0:
            if (!threadCtx.Dr0) {
                threadCtx.Dr0 = cast(ulong)pAddress;
            }
            break;
        
        case Drx.Dr1:
            if (!threadCtx.Dr1) {
                
                threadCtx.Dr1 = cast(ulong)pAddress;
            }
            break;
        
        case Drx.Dr2:
            if (!threadCtx.Dr2) {
                threadCtx.Dr2 = cast(ulong)pAddress;
            }
            break;
        
        case Drx.Dr3:
            if (!threadCtx.Dr3) {
                threadCtx.Dr3 = cast(ulong)pAddress;
            }
            break;

        default:
            break;
    }

    threadCtx.Dr7 = setDr7Bits(threadCtx.Dr7, drx * 2, 1, 1);

    if (!SetThreadContext(cast(HANDLE)-2, &threadCtx)) {
        return FALSE;
    }

    return TRUE;
}

BOOL removeHwBp(Drx drx) {

    CONTEXT threadCtx;
    threadCtx.ContextFlags = CONTEXT_DEBUG_REGISTERS;

    if (!GetThreadContext(GetCurrentThread(), &threadCtx)) {
        return FALSE;
    }

    switch(drx) {
        case Drx.Dr0:
            threadCtx.Dr0 = 0x0;
            break;
        
        case Drx.Dr1:
            threadCtx.Dr1 = 0x0;
            break;
        
        case Drx.Dr2:
            threadCtx.Dr2 = 0x0;
            break;
        
        case Drx.Dr3:
            threadCtx.Dr3 = 0x0;
            break;

        default:
            break;
    }

    threadCtx.Dr7 = setDr7Bits(threadCtx.Dr7, drx * 2, 1, 0);

    if (!SetThreadContext(GetCurrentThread(), &threadCtx)) {
        return FALSE;
    }

    return TRUE;
}

bool initVeh(PVOID excepHandler) {
    
    if (!g_Veh) {
        g_Veh = AddVectoredExceptionHandler(1, cast(PVECTORED_EXCEPTION_HANDLER)excepHandler);
    }

    return g_Veh != NULL;
}

ULONG_PTR getFunctionArg(PCONTEXT threadCtx, DWORD dwParamIndex) {

    switch(dwParamIndex) {
        case 1:
            return cast(ULONG_PTR)threadCtx.Rcx;
        case 2:
            return cast(ULONG_PTR)threadCtx.Rdx;
        case 3:
            return cast(ULONG_PTR)threadCtx.R8;
        case 4:
            return cast(ULONG_PTR)threadCtx.R9;
        default:
            break;
    }

    return *cast(ULONG_PTR*)(threadCtx.Rsp + (dwParamIndex * PVOID.sizeof));

}
VOID setFunctionArg(PCONTEXT threadCtx, ULONG_PTR uVal, DWORD dwParamIndex) {

    switch(dwParamIndex) {
        case 1:
            threadCtx.Rcx = uVal;
            return;
        case 2:
            threadCtx.Rdx = uVal;
            return;
        case 3:
            threadCtx.R8 = uVal;
            return;
        case 4:
            threadCtx.R9 = uVal;
            return;

        default:
            break;
    }

    *cast(ULONG_PTR*)(threadCtx.Rsp + (dwParamIndex * PVOID.sizeof)) = uVal;

}

VOID CONTINUE_EXECUTION(PCONTEXT threadCtx) {
    threadCtx.EFlags = threadCtx.EFlags | (1 << 16);
}

VOID RETURN_VALUE(PCONTEXT ctx, ULONG_PTR value) {
    ctx.Rax = value;
}