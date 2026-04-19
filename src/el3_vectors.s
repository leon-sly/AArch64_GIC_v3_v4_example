// ------------------------------------------------------------
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
// is provided 鎻硈 is? without warranty of any kind, express or implied. In no
// event shall the authors or copyright holders be liable for any claim, damages
// or other liability, whether in action or contract, tort or otherwise, arising
// from, out of or in connection with the Software or the use of Software.
//
// ------------------------------------------------------------

  // .section VECTORS,"ax"
  // 含义：
  // 把下面这段内容放进一个名字叫 VECTORS 的段(section)里。
  //
  // section 可以先粗暴理解成“代码/数据分组”。
  // 你可以把它想成：先给这段内容贴一个分类标签，告诉汇编器：
  // “这部分是向量表，请放到 VECTORS 这一组里。”
  //
  // "ax" 的意思：
  // a = alloc，表示链接后需要给它分配内存空间
  // x = executable，表示这段内容可执行
  //
  // 后面链接时，链接器会根据 scatter.txt 的布局规则，
  // 决定 VECTORS 这一整段最终被放到哪个实际地址。
  .section  VECTORS,"ax"
  .align 12


  // .global el3_vectors
  // 含义：
  // 把符号 el3_vectors 导出成全局符号，让别的文件也能引用它。
  // 比如 startup.s 里就会写：
  //   LDR x0, =el3_vectors
  // 这要求链接器能认识 el3_vectors 这个名字。
  .global el3_vectors

  // el3_vectors:
  // 这不是变量定义，而是一个“标签(label)”。
  // 标签的意思可以理解成：
  // “从当前位置开始，这个地址的名字叫 el3_vectors”
  //
  // 所以 el3_vectors 本身代表的是“这里的地址”。
  // 汇编阶段它先是一个符号；链接阶段链接器会把它解析成实际地址。
  //
  // 也就是说：
  // - 这里先把向量表放进 VECTORS 段
  // - 链接器再根据 scatter.txt 决定 VECTORS 段放到哪里
  // - 最终 el3_vectors 就自然拥有一个真实地址
  //
  // 所以后面 startup.s 里：
  //   LDR x0, =el3_vectors
  // 取到的不是“变量内容”，而是这个标签最后对应的真实地址。
el3_vectors:

  .global fiqHandler

// ------------------------------------------------------------
// Current EL with SP0
// ------------------------------------------------------------
	.balign 128
sync_current_el_sp0:
  B        .                    //        Synchronous

	.balign 128
irq_current_el_sp0:
  B        .                    //        IRQ

	.balign 128
fiq_current_el_sp0:
  B        fiqFirstLevelHandler //        FIQ

	.balign 128
serror_current_el_sp0:
  B        .                    //        SError

// ------------------------------------------------------------
// Current EL with SPx
// ------------------------------------------------------------

	.balign 128
sync_current_el_spx:
  B        .                    //        Synchronous

	.balign 128
irq_current_el_spx:
  B        .                    //        IRQ

	.balign 128
fiq_current_el_spx:
  B        fiqFirstLevelHandler //        FIQ

	.balign 128
serror_current_el_spx:
  B        .                    //        SError

// ------------------------------------------------------------
// Lower EL using AArch64
// ------------------------------------------------------------

	.balign 128
sync_lower_el_aarch64:
   B        .                    

	.balign 128
irq_lower_el_aarch64:
  B        .                    //        IRQ

	.balign 128
fiq_lower_el_aarch64:
  B        fiqFirstLevelHandler //        FIQ

	.balign 128
serror_lower_el_aarch64:
  B        .                    //        SError

// ------------------------------------------------------------
// Lower EL using AArch32
// ------------------------------------------------------------

	.balign 128
sync_lower_el_aarch32:
   B        .

	.balign 128
irq_lower_el_aarch32:
  B        .                    //        IRQ

	.balign 128
fiq_lower_el_aarch32:
  B        fiqFirstLevelHandler //        FIQ

	.balign 128
serror_lower_el_aarch32:
  B        .                    //        SError


// ------------------------------------------------------------

fiqFirstLevelHandler:
  STP      x29, x30, [sp, #-16]!
  STP      x18, x19, [sp, #-16]!
  STP      x16, x17, [sp, #-16]!
  STP      x14, x15, [sp, #-16]!
  STP      x12, x13, [sp, #-16]!
  STP      x10, x11, [sp, #-16]!
  STP      x8, x9, [sp, #-16]!
  STP      x6, x7, [sp, #-16]!
  STP      x4, x5, [sp, #-16]!
  STP      x2, x3, [sp, #-16]!
  STP      x0, x1, [sp, #-16]!

  BL       fiqHandler

  LDP      x0, x1, [sp], #16
  LDP      x2, x3, [sp], #16
  LDP      x4, x5, [sp], #16
  LDP      x6, x7, [sp], #16
  LDP      x8, x9, [sp], #16
  LDP      x10, x11, [sp], #16
  LDP      x12, x13, [sp], #16
  LDP      x14, x15, [sp], #16
  LDP      x16, x17, [sp], #16
  LDP      x18, x19, [sp], #16
  LDP      x29, x30, [sp], #16
  ERET

// ------------------------------------------------------------
// End of file
// ------------------------------------------------------------

