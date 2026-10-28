// Two common entries + a static stub table.
// 0) unimpl_stubs: named stubs for unimplemented imports, the k-th = movz x9,#k; b unimpl_entry (static code; iOS does not allow runtime generation)
// 1) unimpl_entry: stub entry for unimplemented imports, x9 = stub number; save x0-x8+lr and call unimpl_c(idx, regs).
// 2) dm_gate: the rewriter replaces svc / cntpct reads with "bl to this entry". On entry lr = the gate block return point (gate_dispatch uses it to look up which gate this is),
//    save x0-x30 to a contiguous area on this thread's gate stack, call gate_dispatch(ret, regs), write back x0 (gate return value), return.
// The TSD key of the gate stack slot (dm_gate_key below): _dm_gate has one free register, so it reads the slot at a fixed offset from tpidrro_el0 (the host claims this key at start, loader.c)
#define GATE_KEY 384
    .section __TEXT,__const
    .globl _dm_gate_key
    .p2align 3
_dm_gate_key:
    .quad GATE_KEY
    .text
    .globl _unimpl_stubs
    .p2align 3
_unimpl_stubs:
    .set k, 0
    .rept 4096                // = hle.c MAX_STUB
    movz x9, #k
    b _unimpl_entry
    .set k, k + 1
    .endr

    .globl _unimpl_entry
    .p2align 2
_unimpl_entry:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x0, x1, [sp, #16]
    stp x2, x3, [sp, #32]
    stp x4, x5, [sp, #48]
    stp x6, x7, [sp, #64]
    str x8, [sp, #80]
    mov x0, x9
    add x1, sp, #16
    bl _unimpl_c
    ldp x29, x30, [sp], #96
    ret

    .globl _dm_gate
    .p2align 2
_dm_gate:
    // The frame (816 bytes: x0..x30 at +0, q0..q31 at +256, nzcv / fpsr / fpcr at +768 / +776 / +784, the guest's sp at +792, the slot's value at +800) and gate_dispatch go on
    // this thread's gate stack, not below the guest's sp. On Horizon an SVC keeps the thread's registers in the kernel and writes nothing below the user's sp, and a game can rely
    // on that: Streets of Rage 4's Boehm collector (BRUTE) scans a thread blocked in an SVC from just below the frame that entered the blocking state, whose callee-saved spill
    // is gone once that frame returns; the 800-byte frame overwrote that spill and saved the registers below the scanned range, so live objects were freed (docs/reference/threads.md).
    // Only the gate block's own push of x29 / x30 (16 bytes) stays on the guest stack.
    // The gate stack is the slot at GATE_KEY: the host stack a guest thread left in dm_thread_enter, the main thread's own mapping (thread.c), or 0 while a gate already runs on it
    // (a nested gate pushes its frame below the current sp) and for a thread the host gave none (the frame goes below the guest's sp, as before)
    // x29 is free here: the gate block saved the guest's x29 at [sp] and loaded it back from there
    mrs x29, tpidrro_el0
    ldr x29, [x29, #(GATE_KEY * 8)]
    cbz x29, 1f
    sub x29, x29, #816
    stp x0, x1, [x29, #0]
    add x1, x29, #816        // the slot's value, put back on the way out
    b 2f
1:  sub x29, sp, #816
    stp x0, x1, [x29, #0]
    mov x1, #0
2:  mov x0, sp
    str x0, [x29, #792]
    str x1, [x29, #800]
    mov sp, x29
    mrs x0, tpidrro_el0
    str xzr, [x0, #(GATE_KEY * 8)]
    ldr x29, [sp, #792]
    ldr x29, [x29]           // the guest's x29 again: the frame keeps it, and crash backtraces walk the x29 chain from gate_dispatch into the guest
    stp x2, x3, [sp, #16]
    stp x4, x5, [sp, #32]
    stp x6, x7, [sp, #48]
    stp x8, x9, [sp, #64]
    stp x10, x11, [sp, #80]
    stp x12, x13, [sp, #96]
    stp x14, x15, [sp, #112]
    stp x16, x17, [sp, #128]
    stp x18, x19, [sp, #144]
    stp x20, x21, [sp, #160]
    stp x22, x23, [sp, #176]
    stp x24, x25, [sp, #192]
    stp x26, x27, [sp, #208]
    stp x28, x29, [sp, #224]
    str x30, [sp, #240]
    stp q0, q1, [sp, #256]
    stp q2, q3, [sp, #288]
    stp q4, q5, [sp, #320]
    stp q6, q7, [sp, #352]
    stp q8, q9, [sp, #384]
    stp q10, q11, [sp, #416]
    stp q12, q13, [sp, #448]
    stp q14, q15, [sp, #480]
    stp q16, q17, [sp, #512]
    stp q18, q19, [sp, #544]
    stp q20, q21, [sp, #576]
    stp q22, q23, [sp, #608]
    stp q24, q25, [sp, #640]
    stp q26, q27, [sp, #672]
    stp q28, q29, [sp, #704]
    stp q30, q31, [sp, #736]
    mrs x9, nzcv
    str x9, [sp, #768]
    mrs x9, fpsr
    str x9, [sp, #776]
    mrs x9, fpcr
    str x9, [sp, #784]
    mov x0, x30              // Return point = gate identifier
    mov x1, sp               // regs
    bl _gate_dispatch
    ldr x9, [sp, #784]
    msr fpcr, x9
    ldr x9, [sp, #776]
    msr fpsr, x9
    ldr x9, [sp, #768]
    msr nzcv, x9
    ldp q0, q1, [sp, #256]
    ldp q2, q3, [sp, #288]
    ldp q4, q5, [sp, #320]
    ldp q6, q7, [sp, #352]
    ldp q8, q9, [sp, #384]
    ldp q10, q11, [sp, #416]
    ldp q12, q13, [sp, #448]
    ldp q14, q15, [sp, #480]
    ldp q16, q17, [sp, #512]
    ldp q18, q19, [sp, #544]
    ldp q20, q21, [sp, #576]
    ldp q22, q23, [sp, #608]
    ldp q24, q25, [sp, #640]
    ldp q26, q27, [sp, #672]
    ldp q28, q29, [sp, #704]
    ldp q30, q31, [sp, #736]
    // A gate may modify any general-purpose register: svc out-parameters are in x0..x8, and the target of mrs cntpct can be any xN (14 of the 33 sites in sdk are x19..x23)
    // ⇒ read back all of x0..x29 (x18 is the Apple platform register; the guest's x18 has been rewritten to the thread slot, so skip it and leave it alone)
    ldr x1, [sp, #800]
    mrs x2, tpidrro_el0
    str x1, [x2, #(GATE_KEY * 8)]
    ldp x2, x3, [sp, #16]
    ldp x4, x5, [sp, #32]
    ldp x6, x7, [sp, #48]
    ldp x8, x9, [sp, #64]
    ldp x10, x11, [sp, #80]
    ldp x12, x13, [sp, #96]
    ldp x14, x15, [sp, #112]
    ldp x16, x17, [sp, #128]
    ldr x19, [sp, #152]
    ldp x20, x21, [sp, #160]
    ldp x22, x23, [sp, #176]
    ldp x24, x25, [sp, #192]
    ldp x26, x27, [sp, #208]
    ldp x28, x29, [sp, #224]
    ldr x30, [sp, #240]
    mov x1, sp
    ldr x0, [x1, #792]
    mov sp, x0
    ldp x0, x1, [x1, #0]
    ret

// 3) dm_thread_enter(entry, arg, sp): guest thread start. Switch to the guest stack given by the SDK and call entry with x0 = argument;
//    Horizon threads must exit via ExitThread; returning from entry is reported as an error.
//    The host stack it leaves becomes the thread's gate stack (nothing above this sp is used again: ExitThread ends the thread from inside a gate)
    .globl _dm_thread_enter
    .p2align 2
_dm_thread_enter:
    mrs x9, tpidrro_el0
    mov x10, sp
    str x10, [x9, #(GATE_KEY * 8)]
    mov sp, x2
    mov x29, #0
    mov x16, x0
    mov x0, x1
    adr x30, 1f
    br x16
1:  bl _dm_thread_returned
    brk #0
