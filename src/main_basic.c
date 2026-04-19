// AArch64 下的基础 GIC 中断示例
//
// 这个示例一次演示三类中断源：
// 1. Secure Physical Timer   -> PPI, INTID 29
// 2. Non-secure EL1 Timer    -> PPI, INTID 30
// 3. SP804 外设计时器         -> SPI, INTID 34
//
// 重点不是“定时器怎么用”，而是展示一条完整的中断路径：
// 外设/定时器产生中断 -> GIC 分发 -> CPU 进入异常 -> 软件识别 INTID
// -> 清除中断源 -> 向 GIC 写 EOI 表示处理结束
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
// is provided as is? without warranty of any kind, express or implied. In no
// event shall the authors or copyright holders be liable for any claim, damages
// or other liability, whether in action or contract, tort or otherwise, arising
// from, out of or in connection with the Software or the use of Software.
//
// ------------------------------------------------------------

#include <stdio.h>
#include "gicv3_basic.h"
#include "generic_timer.h"
#include "system_counter.h"
#include "sp804_timer.h"

// 由启动代码提供，返回当前 CPU 的 Affinity 值
// 在多核系统里，GIC 需要用这个值找到当前核对应的 Redistributor
extern uint32_t getAffinity(void);

// 统计已经处理了多少次预期中断
// main() 通过轮询它来判断测试是否结束
volatile unsigned int flag;

// --------------------------------------------------------

// 下面这些地址来自 Base Platform FVP 的内存映射
#define DIST_BASE_ADDR     (0x2F000000)  // GIC Distributor 基地址
#define RD_BASE_ADDR       (0x2F100000)  // GIC Redistributor 基地址
#define SYS_CONT_BASE_ADDR (0x2A430000)  // System Counter 基地址
#define SP804_BASE_ADDR    (0x1C110000)  // SP804 定时器基地址

// --------------------------------------------------------

int main(void)
{
  uint64_t current_time;
  uint32_t rd, affinity;
  
  // 获取当前核的 MPIDR/Affinity 信息
  // 后面 SPI 路由时会把中断路由到当前核
  affinity = getAffinity();

  //
  // 第 1 步：配置 GIC
  //
  // 告诉驱动代码 GIC Distributor / Redistributor 的寄存器在哪里
  setGICAddr((void*)DIST_BASE_ADDR, (void*)RD_BASE_ADDR);

  // 打开 GIC Distributor 的中断分发能力
  enableGIC();

  // 根据当前 CPU 的 affinity，找到它对应的 Redistributor 编号
  rd = getRedistID(getAffinity());

  // 唤醒当前核的 Redistributor
  // 如果 Redistributor 还在休眠，这个核就收不到本地中断
  wakeUpRedist(rd);

  // 配置 CPU interface
  // 这里默认启动代码已经提前打开 SRE，允许通过系统寄存器访问 GIC CPU IF
  setPriorityMask(0xFF);
  enableGroup0Ints();
  enableGroup1Ints();
  enableNSGroup1Ints();  // 示例运行在 EL3，因此可以顺手打开 NS Group1

  //
  // 第 2 步：在 GIC 里配置中断源
  //

  // Secure Physical Timer -> PPI 29
  // PPI 是每个 CPU 私有的中断，因此需要传入当前核对应的 rd
  setIntPriority(29, rd, 0);
  setIntGroup(29, rd, GICV3_GROUP0);
  enableInt(29, rd);

  // Non-secure EL1 Physical Timer -> PPI 30
  setIntPriority(30, rd, 0);
  setIntGroup(30, rd, GICV3_GROUP0);
  enableInt(30, rd);

  // SP804 Timer -> SPI 34
  // SPI 是共享外设中断，不挂在某个特定 Redistributor 上
  setIntPriority(34, 0, 0);
  setIntGroup(34, 0, GICV3_GROUP0);
  setIntRoute(34, GICV3_ROUTE_MODE_COORDINATE, affinity); // 路由到当前核
  setIntType(34, 0, GICV3_CONFIG_LEVEL);                  // 配成电平触发
  enableInt(34, 0);

  // 注意：SPI 不需要 rd 参数，因为它不是某个核私有的中断

  //
  // 第 3 步：配置能真正“发出中断”的硬件
  // 先配置 System Counter / Generic Timer，用来触发两个 PPI
  //
  setSystemCounterBaseAddr(SYS_CONT_BASE_ADDR);  // 指定 System Counter 基地址
  initSystemCounter(SYSTEM_COUNTER_CNTCR_nHDBG,
                    SYSTEM_COUNTER_CNTCR_FREQ0,
                    SYSTEM_COUNTER_CNTCR_nSCALE);

  // 配置 Secure Physical Timer
  // 用绝对时间比较方式：当前计数 + 10000 tick 时触发中断
  current_time = getPhysicalCount();
  setSEL1PhysicalCompValue(current_time + 10000);
  setSEL1PhysicalTimerCtrl(CNTPS_CTL_ENABLE);

  // 配置 Non-secure Physical Timer
  // 用相对时间方式：再过 20000 tick 触发中断
  setNSEL1PhysicalTimerValue(20000);
  setNSEL1PhysicalTimerCtrl(CNTP_CTL_ENABLE);

  //
  // 再配置 SP804 外设计时器，用来触发一个 SPI
  //

  // 指定 SP804 寄存器基地址
  setTimerBaseAddress(SP804_BASE_ADDR);
  // 装载初值、配置成单次模式、打开“产生中断”功能
  initTimer(0x1, SP804_SINGLESHOT, SP804_GENERATE_IRQ);
  // 启动 SP804，计数到点后会拉起中断线
  startTimer();


  // NOTE:
  // This code assumes that the IRQ and FIQ exceptions
  // have been routed to the appropriate Exception level
  // and that the PSTATE masks are clear.  In this example
  // this is done in the startup.s file

  //
  // Spin until interrupt
  //
  // 等待 3 个预期中断都被处理完成：29、30、34 各一次
  while(flag < 3)
  {}
  
  printf("Main(): Test end\n");

  return 1;
}

// --------------------------------------------------------

void fiqHandler(void)
{
  unsigned int ID;

  // 从 GIC 的 IAR 中读取当前中断号
  // 这是“先问 GIC 到底是谁打断了我”的标准做法
  ID = readIARGrp0();

  printf("FIQ: Received INTID %d\n", ID);

  switch (ID)
  {
    case 29:
      // 关闭 Secure Physical Timer，相当于清除中断源
      setSEL1PhysicalTimerCtrl(0);
      printf("FIQ: Secure Physical Timer\n");
      break;
    case 30:
      // 关闭 Non-secure Physical Timer，相当于清除中断源
      setNSEL1PhysicalTimerCtrl(0);
      printf("FIQ: Non-secure EL1 Physical Timer\n");
      break;
    case 34:
      // 清除 SP804 自己内部的中断状态
      // 如果不清，电平中断可能会一直挂着，导致反复进入中断
      clearTimerIrq();
      printf("FIQ: SP804 timer\n");
      break;
    case 1023:
      // 1023 表示伪中断 / spurious interrupt
      printf("FIQ: Interrupt was spurious\n");
      return;
    default:
      printf("FIQ: Panic, unexpected INTID\n");
  }

  // 告诉 GIC：这个中断已经处理完了
  // 外设侧的清中断 和 GIC 侧的 EOI 是两回事，通常都要做
  writeEOIGrp0(ID);

  // 统计已处理的中断次数
  flag++;
  return;
}
