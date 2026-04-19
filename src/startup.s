//==================================================================
// Armv8-A Startup Code
//
// 中文说明：
// 这是这个示例工程的最早启动代码。
// CPU 复位后，先执行这里，而不是直接进入 C 语言的 main()。
//
// 这个文件主要做几件事：
// 1. 清空通用寄存器
// 2. 判断当前是哪个核在运行
// 3. 只允许主核继续跑，其他核先 WFI 睡眠
// 4. 配置 EL3 环境和 GIC 的系统寄存器接口
// 5. 安装异常向量表
// 6. 打开 IRQ/FIQ
// 7. 跳转到 __main，再进入 C 世界
//
// Copyright (C) Arm Limited, 2019 All rights reserved.
//
// The example code is provided to you as an aid to learning when working
// with Arm-based technology, including but not limited to programming tutorials.
// Arm hereby grants to you, subject to the terms and conditions of this Licence,
// a non-exclusive, non-transferable, non-sub-licensable, free-of-charge licence,
// to use and copy the Software solely for the purpose of demonstration and
// evaluation.
//
// You accept that the Software has not been tested by Arm therefore the Software
// is provided 锟絘s is锟? without warranty of any kind, express or implied. In no
// event shall the authors or copyright holders be liable for any claim, damages
// or other liability, whether in action or contract, tort or otherwise, arising
// from, out of or in connection with the Software or the use of Software.
//
// ------------------------------------------------------------

  .section  BOOT,"ax"
  .align 3

// ------------------------------------------------------------

  .global start64
  .type start64, @function
start64:

  // start64 是程序的第一个入口点
  // ".global start64" 表示这个符号对链接器可见
  // ".type start64, @function" 表示把它标记成函数

  // Clear registers
  // ---------------
  // This is primarily for RTL simulators, to avoid
  // possibility of X propagation
  //
  // 中文说明：
  // 这里把 x0~x30 全部清零。
  // 对初学者来说，可以把 x0~x30 理解成 CPU 的通用寄存器。
  //
  // MOV 指令：
  //   MOV x0, #0
  // 含义是：把立即数 0 写到 x0 里。
  //
  // AArch64 里常见两种寄存器名字：
  // - xN：64 位寄存器
  // - wN：对应 xN 的低 32 位
  //
  // 比如 x0 是 64 位，w0 是它的低 32 位视图。
  MOV      x0, #0
  MOV      x1, #0
  MOV      x2, #0
  MOV      x3, #0
  MOV      x4, #0
  MOV      x5, #0
  MOV      x6, #0
  MOV      x7, #0
  MOV      x8, #0
  MOV      x9, #0
  MOV      x10, #0
  MOV      x11, #0
  MOV      x12, #0
  MOV      x13, #0
  MOV      x14, #0
  MOV      x15, #0
  MOV      x16, #0
  MOV      x17, #0
  MOV      x18, #0
  MOV      x19, #0
  MOV      x20, #0
  MOV      x21, #0
  MOV      x22, #0
  MOV      x23, #0
  MOV      x24, #0
  MOV      x25, #0
  MOV      x26, #0
  MOV      x27, #0
  MOV      x28, #0
  MOV      x29, #0
  MOV      x30, #0

  // Check which core is running
  // ----------------------------
  // Core 0.0.0.0 should continue to execute
  // All other cores should be put into sleep (WFI)
  //
  // 中文说明：
  // 在多核系统里，复位后可能不止一个核开始执行。
  // 这个示例只想让主核继续跑，其他核先睡眠。
  //
  // MPIDR_EL1：
  //   Multiprocessor Affinity Register
  //   用来标识“我当前是哪个核”
  //
  // MRS 指令：
  //   MRS x0, MPIDR_EL1
  // 含义是：从系统寄存器 MPIDR_EL1 读值到 x0。
  MRS      x0, MPIDR_EL1

  // UBFX：Unsigned Bit Field Extract
  // 从 x0 中抽取一段位字段，放到 x1
  // 这里是取出 Aff3
  UBFX     x1, x0, #32, #8     // Extract Aff3

  // BFI：Bit Field Insert
  // 把 x1 中的某些位插入到 w0 指定位置
  // 这里的目的，是把 Aff3 拼回到 32 位结果里，
  // 最后让 w0 变成 Aff3.Aff2.Aff1.Aff0 的形式
  BFI      w0, w1, #24, #8     // Insert Aff3 into bits [31:24], so that [31:0]
                               // is now Aff3.Aff2.Aff1.Aff0
                               // Using w register means bits [63:32] are zeroed

  // CBZ：Compare and Branch on Zero
  // 如果 w0 == 0，就跳到 primary_core
  // 也就是只有 affinity 为 0.0.0.0 的核继续执行
  CBZ      w0, primary_core    // If 0.0.0.0, branch to code for primary core
1:
  // WFI：Wait For Interrupt
  // 让 CPU 进入等待状态，直到有中断到来
  WFI                          // If not 0.0.0.0, then go to sleep
  // B 1b：跳回前面名为 1 的局部标签
  // 这里形成一个死循环，让非主核持续等待
  B        1b
primary_core:


  // Disable trapping of CPTR_EL3 accesses or use of Adv.SIMD/FPU
  // -------------------------------------------------------------
  //
  // CPTR_EL3：
  //   Architectural Feature Trap Register, EL3
  //   控制 EL3 是否对某些功能访问进行 trap（陷入）
  //
  // 这里写 0，表示清除相关 trap 位
  MOV      x0, #0                           // Clear all trap bits
  MSR      CPTR_EL3, x0
  //
  // MSR 指令：
  //   MSR CPTR_EL3, x0
  // 含义是：把 x0 的值写到系统寄存器 CPTR_EL3。


  // Install vector table
  // ---------------------
  //
  // VBAR_EL3：
  //   Vector Base Address Register, EL3
  //   它保存 EL3 异常向量表的基地址。
  //
  // LDR x0, =el3_vectors
  // 这里不是普通“读内存”，而是伪指令，意思是把符号 el3_vectors 的地址装到 x0。
  .global  el3_vectors
  LDR      x0, =el3_vectors
  MSR      VBAR_EL3, x0


  // Configure GIC CPU IF
  // -------------------
  // For processors that do not support legacy operation
  // these steps could be omitted.
  //
  // 中文说明：
  // GICv3 的 CPU interface 可以通过系统寄存器访问。
  // 但前提是要打开 SRE（System Register Enable）。
  //
  // SCR_EL3：
  //   Secure Configuration Register, EL3
  //   控制安全状态、异常路由等行为
  //
  // 先把 SCR_EL3 清零，确保处于 secure 访问视角
  MSR      SCR_EL3, xzr                      // Ensure NS bit is clear

  // ISB：Instruction Synchronization Barrier
  // 指令同步屏障，确保前面的系统寄存器修改生效后，
  // 后续指令再按新的状态执行
  ISB
  MOV      x0, #1

  // ICC_SRE_EL3 / ICC_SRE_EL1：
  // GIC CPU interface 的 System Register Enable 寄存器
  // 写 1 表示允许通过系统寄存器访问 GIC CPU interface
  MSR      ICC_SRE_EL3, x0
  ISB
  MSR      ICC_SRE_EL1, x0

  // Now do the NS SRE bits

  // 把 SCR_EL3.NS 置 1，切到 Non-secure 访问视角
  MOV      x1, #1                            // Set NS bit, to access Non-secure registers
  MSR      SCR_EL3, x1
  ISB

  // 给 NS 世界下的 EL2 / EL1 也打开 SRE
  MSR      ICC_SRE_EL2, x0
  ISB
  MSR      ICC_SRE_EL1, x0


  // Configure SCR_EL3
  // ------------------
  // Have interrupts routed to EL3
  //
  // 这里重新构造 SCR_EL3 的值。
  // ORR 是按位或，经常用来“置位某一位”
  //
  // ORR w1, w1, #(1 << n)
  // 含义：把第 n 位置 1，其他位保持不变
  MOV      w1, #0              // Initial value of register is unknown
  ORR      w1, w1, #(1 << 11)  // Set ST bit (Secure EL1 can access CNTPS_TVAL_EL1, CNTPS_CTL_EL1 & CNTPS_CVAL_EL1)
  ORR      w1, w1, #(1 << 10)  // Set RW bit (EL1 is AArch64, as this is the Secure world)
  ORR      w1, w1, #(1 << 3)   // Set EA bit (SError routed to EL3)
  ORR      w1, w1, #(1 << 2)   // Set FIQ bit (FIQs routed to EL3)
  ORR      w1, w1, #(1 << 1)   // Set IRQ bit (IRQs routed to EL3)
  MSR      SCR_EL3, x1

  // 这一步之后，IRQ/FIQ/SError 会被路由到 EL3 处理。
  // 这也是为什么这个示例里的异常向量表装在 VBAR_EL3。

  //
  // Cortex-A35/53/57/72/73 series specific configuration
  //
  .ifdef CORTEXA
    // Configure ACTLR_EL1
    // --------------------
    // These bits are IMP DEF, so need to different for different
    // processors
    //MRS      x1, ACTLR_EL1
    //ORR      x1, x1, #1          // Enable EL1 access to ACTLR_EL1
    //ORR      x1, x1, #(1 << 1)   // Enable EL1 access to CPUECTLR_EL1
    //ORR      x1, x1, #(1 << 4)   // Enable EL1 access to L2CTLR_EL1
    //ORR      x1, x1, #(1 << 5)   // Enable EL1 access to L2ECTLR_EL1
    //ORR      x1, x1, #(1 << 6)   // Enable EL1 access to L2ACTLR_EL1
    //MSR      ACTLR_EL1, x1

    // Configure CPUECTLR_EL1
    // -----------------------
    // These bits are IMP DEF, so need to different for different
    // processors
    // SMPEN - bit 6 - Enables the processor to receive cache
    //                 and TLB maintenance operations
    //
    // NOTE: For Cortex-A57/53 CPUEN should be set before
    //       enabling the caches and MMU, or performing any cache
    //       and TLB maintenance operations.
    //MRS      x0, S3_1_c15_c2_1  // Read EL1 CPU Extended Control Register
    //ORR      x0, x0, #(1 << 6)  // Set the SMPEN bit
    //MSR      S3_1_c15_c2_1, x0  // Write EL1 CPU Extended Control Register
    //ISB
  .endif


  // Ensure changes to system register are visible
  ISB


  // Enable Interrupts
  // ------------------
  //
  // DAIF 是中断屏蔽相关位集合：
  // D = Debug
  // A = SError
  // I = IRQ
  // F = FIQ
  //
  // DAIFClr 是“清这些屏蔽位”
  // 0x3 对应清 I 和 F，也就是允许 IRQ / FIQ 进入
  MSR      DAIFClr, 0x3


  // Branch to scatter loading and C library init code
  // -------------------------------------------------
  //
  // __main 不是你的 main()，而是运行时入口。
  // 它会做 C 运行时初始化，例如数据段/零初始化等，
  // 然后再调用真正的 main()。
  //
  // B 指令：无条件跳转
  .global  __main
  B        __main

// ------------------------------------------------------------

  .type getAffinity, "function"
  .cfi_startproc
  .global getAffinity
getAffinity:
  // 这个辅助函数返回当前核的 affinity 值
  // C 代码里会调用它，拿去匹配 Redistributor，或者做中断路由
  MRS      x0, MPIDR_EL1

  // UBFX：提取 Aff3
  UBFX     x1, x0, #32, #8

  // BFI：把 Aff3 塞回低 32 位对应位置
  BFI      w0, w1, #24, #8

  // RET：函数返回
  RET
  .cfi_endproc

// ------------------------------------------------------------
// End of file
// ------------------------------------------------------------
