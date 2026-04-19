# AArch64 GIC Example Notes

## 参考资料

- Arm AArch64 GIC system registers summary:
  https://developer.arm.com/documentation/102670/0301/AArch64-registers/AArch64-register-summaries/AArch64-GIC-system-registers-summary?lang=en

---

## 一、怎么读这个仓库

### 1. 先看什么

- 先看 `Makefile`，确认会生成哪些镜像
- 再看最简单入口：`src/main_basic.c`
- 然后顺着主线补：
  - `src/startup.s`
  - `src/el3_vectors.s`
  - `src/gicv3_basic.c`
  - `src/gicv3_cpuif.S`
  - `src/sp804_timer.c`

### 2. 代码阅读顺序

- 先看主流程，不要一上来读完所有文件
- 先分段，再追关键函数
- 先抓主线，再回头补参数和寄存器细节

### 3. VS Code 常用快捷键

- `Ctrl+P`：找文件
- `Ctrl+Shift+F`：全局搜索
- `Ctrl+F`：当前文件搜索
- `F12`：跳到定义
- `Alt+F12`：Peek Definition
- `Shift+F12`：找引用
- `Ctrl+Shift+O`：当前文件符号
- `Ctrl+T`：全局符号搜索
- `Ctrl+G`：跳行

### 4. 搜函数时的注意点

- 不要只搜 `name(`
- 优先搜完整符号名，例如 `getAffinity`
- 底层函数实现可能不在 `.c`，也可能在 `.s` / `.S`
- 还可能来自运行时库，比如 `__main`

---

## 二、程序是怎么跑起来的

### 1. 启动主线

```text
上电/复位
  -> start64                [src/startup.s]
  -> __main                 [工具链运行时]
  -> main                   [src/main_basic.c]
```

### 2. `startup.s` 做了什么

- 清通用寄存器
- 判断当前核是否是 `0.0.0.0`
- 让非主核 `WFI` 睡眠
- 配置 EL3 运行环境
- 打开 GIC system register interface（SRE）
- 安装异常向量表到 `VBAR_EL3`
- 清 `PSTATE` 里的 IRQ/FIQ mask
- 跳到 `__main`

### 3. `__main` 是什么

- 不是本仓库自己实现的函数
- 来自 Arm 编译器运行时
- 负责 C 运行时初始化
- 之后再调用真正的 `main()`

---

## 三、中断是怎么进来的

### 1. 向量表在哪里定义和加载

- 定义位置：`src/el3_vectors.s`
- 加载位置：`src/startup.s`

关键代码：

```asm
LDR x0, =el3_vectors
MSR VBAR_EL3, x0
```

含义：

- `el3_vectors` 是一个标签，不是变量
- 标签也有地址，因为标签就是“当前位置的名字”
- 启动代码把这个地址写进 `VBAR_EL3`

### 2. 从异常到处理函数的链路

```text
外设/定时器触发中断
  -> GIC 仲裁并分发
  -> CPU 进入 EL3 向量表
  -> fiqFirstLevelHandler
  -> fiqHandler()
  -> readIAR / 清中断源 / writeEOI
```

### 3. 为什么 `main_basic.c` 能直接等中断

因为启动代码已经提前做好了前提条件：

- IRQ/FIQ 已经路由到正确的 EL
- 向量表已经安装
- `PSTATE` 的中断 mask 已经清掉

所以 `main_basic.c` 里那段 NOTE 是在说明“运行前提”，不是在说“这里还没做”。

---

## 四、GIC 架构怎么分工

### 1. Distributor

- 管全局共享中断
- 常见用于 SPI

### 2. Redistributor

- 每个 CPU 对应一个
- 管本地相关中断
- 常见用于 SGI / PPI / LPI 相关配置

### 3. CPU interface

- CPU 自己从 GIC 取中断、回 EOI、设优先级门槛
- 这个工程主要通过 AArch64 系统寄存器访问

---

## 五、中断类型和编号区间

### 1. 常见类型

- SGI：软件生成中断
- PPI：每个 CPU 私有中断
- SPI：共享外设中断
- Extended PPI：GICv3.1 扩展本地中断
- Extended SPI：GICv3.1 扩展共享中断

### 2. 代码里常见的区间判断

- 普通 SGI/PPI：低编号，本地侧处理
- 普通 SPI：`ID < 1020`
- 扩展 PPI：`1056..1119`
- 扩展 SPI：`4096..5119`

结论：

- 不同编号区间，对应不同寄存器区
- 所以不能把所有中断都用一套固定公式处理

---

## 六、`main_basic.c` 主流程总结

### 1. 主流程

1. `getAffinity()`：拿当前核的 affinity
2. `setGICAddr()`：告诉驱动 GIC 基地址
3. `enableGIC()`：打开 GIC Distributor
4. `getRedistID()`：找到当前核对应的 Redistributor
5. `wakeUpRedist()`：唤醒这个 Redistributor
6. `setPriorityMask()` / `enableGroup*()`：打开 CPU interface 接收条件
7. 配 3 个中断源：
   - PPI 29
   - PPI 30
   - SPI 34
8. 配真正发中断的硬件：
   - Generic Timer
   - SP804
9. `while(flag < 3)` 等待三次中断都处理完

### 2. 为什么 `enableInt(34, 0)` 第二个参数是 `0`

- `34` 是 SPI
- SPI 走 Distributor，不需要 Redistributor 索引
- 所以 `rd` 参数在 SPI 分支里被忽略
- 这里的 `0` 只是占位值

---

## 七、`gicv3_basic.c` 里最关键的理解点

### 1. `setGICAddr()`

- 记录 Distributor / Redistributor 基地址
- 顺手扫描出当前实现里一共有多少个 Redistributor

### 2. `getRedistID()`

- 通过比对 `GICR_TYPER`
- 找到 affinity 对应的 Redistributor
- 返回值 `rd` 是软件索引，不是硬件写进去的“编号字段”

### 3. `wakeUpRedist()`

- 先写 `GICR_WAKER` 清掉 `ProcessorSleep`
- 再轮询 `ChildrenAsleep`
- 本质：发唤醒请求，再等硬件真的醒来

### 4. `enableInt()` 的 SPI 分支为什么要 `ID/32` 和 `ID & 0x1f`

因为：

- `GICD_ISENABLER[]` 是 32 位寄存器数组
- 一个寄存器控制 32 个中断

所以：

- `bank = ID / 32`
  - 算出该访问第几个寄存器
- `ID & 0x1f`
  - 算出在该寄存器里的第几位
- `1 << bit`
  - 生成位掩码

### 5. 为什么 `setIntPriority()` 还要判断扩展 PPI / 扩展 SPI

因为：

- 不同 INTID 区间，优先级寄存器不在同一片区域
- 扩展 PPI / 扩展 SPI 已经进入 GICv3.1 的扩展寄存器布局
- 所以必须换一套索引方式

---

## 八、CPU interface 和中断组

### 1. 为什么有 `enableGroup0Ints()` 和 `enableGroup1Ints()`

因为 GIC 把中断按组管理：

- Group0
- Group1

CPU 是否接收它们，要分别打开。

### 2. 当前工程里的直观理解

- 这个示例里的几个中断都被设成了 `GICV3_GROUP0`
- 所以最关键的是 `enableGroup0Ints()`
- 代码里把 Group1 也打开，是偏通用的初始化写法

### 3. `enableNSGroup1Ints()`

作用：

- 由 EL3 打开 Non-secure Group1 中断接收开关

对应寄存器：

- `ICC_IGRPEN1_EL3`

---

## 九、优先级和门槛

### 1. `setPriorityMask(0xFF)` 是什么意思

- 设置 CPU interface 的优先级门槛
- `0xFF` 是最低优先级值，表示最宽松
- 教学代码里这样写，相当于先别用门槛把中断挡掉

### 2. GIC 优先级的直觉

- 数值越小，优先级越高
- 数值越大，优先级越低

---

## 十、触发方式

### 1. 电平触发（level-triggered）

- 只要信号一直有效，中断就一直算成立
- 如果不清外设状态，可能会反复进中断

### 2. 边沿触发（edge-triggered）

- 只在信号发生跳变的瞬间触发

### 3. 这个工程里 GIC 配的是哪一层

代码里只有：

- `GICV3_CONFIG_LEVEL`
- `GICV3_CONFIG_EDGE`

结论：

- GIC 这里只区分 level / edge
- 不区分高电平 / 低电平极性
- 极性通常是外设或平台设计层决定的

---

## 十一、外设、中断源、GIC 三者关系

### 1. 外设配置不等于 GIC 配置

必须分两边看：

- 外设侧：会不会真正拉起中断线
- GIC 侧：能不能正确接收、分发、送到 CPU

### 2. SP804 例子

- `SP804_BASE_ADDR` 表示它的寄存器已经在地址空间里
- `setTimerBaseAddress()` 不是“创建映射”
- 而是把一个已知的 memory-mapped I/O 地址交给驱动

### 3. 这个“映射”是谁决定的

- 在这个裸机/FVP 示例里，是平台/FVP 内存地图预先定义好的
- 不是 `setTimerBaseAddress()` 在运行时现做出来的

---

## 十二、汇编、标签、section、地址

### 1. `.section VECTORS,"ax"` 是什么

- 把后面的内容放进名为 `VECTORS` 的段
- `a`：需要分配内存
- `x`：可执行

### 2. `.global el3_vectors` 是什么

- 导出全局符号
- 让别的文件能引用它

### 3. `el3_vectors:` 是什么

- 不是变量
- 是标签（label）
- 本质是“当前位置的名字”

### 4. 标签为什么会有地址

因为：

- 汇编和链接最终都要把代码/数据放进内存布局
- 标签标记的是“这段内容从哪里开始”
- 所以标签天然就对应一个地址

### 5. 真实地址是什么时候确定的

- 汇编阶段：知道有这个符号，但通常还不是最终绝对地址
- 链接阶段：链接器根据 `scatter.txt` 决定段放哪
- 运行阶段：程序使用这个已经确定好的地址

结论：

- `el3_vectors` 自己不会被“覆盖”
- 被写入的是 `VBAR_EL3`

---

## 十三、`PSTATE`、`DAIF` 和 mask

### 1. `PSTATE`

- 全称：Processor State
- 是处理器当前状态的一组位

### 2. 哪些和中断最相关

- `I`：IRQ mask
- `F`：FIQ mask
- `A`：SError mask
- `D`：Debug mask

### 3. “mask clear” 是什么意思

- 清掉屏蔽位
- 让对应中断不再被屏蔽

### 4. 本工程里的代码依据

在 `startup.s` 里：

```asm
MSR DAIFClr, 0x3
```

含义：

- 清 IRQ/FIQ mask
- 允许 IRQ/FIQ 进入

---

## 十四、这轮出现过的关键寄存器

以下寄存器名和功能说明，参考 Arm 官方 AArch64 GIC system registers summary，以及本工程代码语境整理。

### 1. `VBAR_EL3`

- 全称：Vector Base Address Register, EL3
- 功能：保存 EL3 异常向量表基地址

### 2. `MPIDR_EL1`

- 全称：Multiprocessor Affinity Register
- 功能：标识当前 CPU 的 affinity

### 3. `SCR_EL3`

- 全称：Secure Configuration Register, EL3
- 功能：控制安全态视角、异常路由等

### 4. `ICC_SRE_EL1` / `ICC_SRE_EL2` / `ICC_SRE_EL3`

- 全称：Interrupt Controller System Register Enable Register
- 功能：允许通过系统寄存器访问 GIC CPU interface

### 5. `ICC_PMR_EL1`

- 全称：Interrupt Priority Mask Register
- 功能：设置当前 CPU 接收中断的优先级门槛

### 6. `ICC_IGRPEN0_EL1`

- 全称：Interrupt Group 0 Enable Register
- 功能：打开 Group0 中断接收

### 7. `ICC_IGRPEN1_EL1`

- 全称：Interrupt Group 1 Enable Register
- 功能：打开当前安全状态下的 Group1 中断接收

### 8. `ICC_IGRPEN1_EL3`

- 全称：Interrupt Group 1 Enable Register, EL3 view
- 功能：由 EL3 控制 Non-secure Group1 中断接收

### 9. `ICC_IAR0_EL1`

- 全称：Interrupt Acknowledge Register for Group 0
- 功能：读取当前 Group0 中断的 INTID

### 10. `ICC_IAR1_EL1`

- 全称：Interrupt Acknowledge Register for Group 1
- 功能：读取当前 Group1 中断的 INTID

### 11. `ICC_EOIR0_EL1`

- 全称：End Of Interrupt Register for Group 0
- 功能：向 GIC 报告 Group0 中断处理结束

### 12. `ICC_EOIR1_EL1`

- 全称：End Of Interrupt Register for Group 1
- 功能：向 GIC 报告 Group1 中断处理结束

### 13. `ICC_DIR_EL1`

- 全称：Deactivate Interrupt Register
- 功能：显式 de-activate 某个中断

### 14. `GICR_WAKER`

- 功能：控制/反映 Redistributor 的睡眠与唤醒状态

### 15. `GICR_TYPER`

- 功能：描述 Redistributor 属性，例如 affinity、是否是最后一个 RD、扩展 PPI 能力等

### 16. `GICD_CTLR`

- 功能：Distributor 主控制寄存器

### 17. `GICD_ISENABLER[]`

- 功能：使能 SPI 等共享中断
- 组织方式：一个 32 位寄存器控制 32 个中断

### 18. `GICR_ISENABLER[]`

- 功能：使能 SGI/PPI 等本地中断
- 位于 Redistributor 的 SGI/PPI 区域

### 19. `GICD_IPRIORITYR[]`

- 功能：设置普通 SPI 的优先级

### 20. `GICR_IPRIORITYR[]`

- 功能：设置本地中断（如 SGI/PPI、扩展 PPI）的优先级

### 21. `GICD_ROUTER[]`

- 功能：配置 SPI 路由到哪个 affinity/PE

---

## 十五、当前已经建立的分析方法

### 1. 看函数时优先问四件事

1. 它是谁定义的
2. 它里面做什么
3. 它返回/修改了什么
4. 为什么这里要调用它

### 2. 看一个调用时，先分清它属于哪类

- 地址初始化：`setXxxAddr`
- 硬件初始化：`initXxx`
- GIC 配置：`setIntXxx` / `enableInt`
- CPU interface：`readIAR` / `writeEOI` / `setPriorityMask`

### 3. 看不懂时先抓主线

- 先看“程序怎么跑”
- 再看“中断怎么进”
- 再看“一个关键函数怎么实现”
- 最后补参数和寄存器位细节

---

## 十六、下一步建议

后续如果继续深入，建议顺序：

1. `src/gicv3_basic.c`
2. `src/gicv3_cpuif.S`
3. `src/sp804_timer.c`
4. `src/main_lpi.c`
