# 附录：汇编、PSTATE、关键寄存器

## 1. 汇编、标签、section、地址

### 1.1 `.section VECTORS,"ax"` 是什么

- 把后面的内容放进名为 `VECTORS` 的段
- `a`：需要分配内存
- `x`：可执行

### 1.2 `.global el3_vectors` 是什么

- 导出全局符号
- 让别的文件能引用它

### 1.3 `el3_vectors:` 是什么

- 不是变量
- 是标签（label）
- 本质是“当前位置的名字”

### 1.4 标签为什么会有地址

因为：

- 汇编和链接最终都要把代码/数据放进内存布局
- 标签标记的是“这段内容从哪里开始”
- 所以标签天然就对应一个地址

### 1.5 真实地址是什么时候确定的

- 汇编阶段：知道有这个符号，但通常还不是最终绝对地址
- 链接阶段：链接器根据 `scatter.txt` 决定段放哪
- 运行阶段：程序使用这个已经确定好的地址

结论：

- `el3_vectors` 自己不会被“覆盖”
- 被写入的是 `VBAR_EL3`

## 2. `PSTATE`、`DAIF` 和 mask

### 2.1 `PSTATE`

- 全称：Processor State
- 是处理器当前状态的一组位

### 2.2 哪些和中断最相关

- `I`：IRQ mask
- `F`：FIQ mask
- `A`：SError mask
- `D`：Debug mask

### 2.3 “mask clear” 是什么意思

- 清掉屏蔽位
- 让对应中断不再被屏蔽

### 2.4 本工程里的代码依据

在 `startup.s` 里：

```asm
MSR DAIFClr, 0x3
```

含义：

- 清 IRQ/FIQ mask
- 允许 IRQ/FIQ 进入

## 3. 这轮出现过的关键寄存器

以下寄存器名和功能说明，参考 Arm 官方 AArch64 GIC system registers summary，以及本工程代码语境整理。

### 3.1 `VBAR_EL3`

- 全称：Vector Base Address Register, EL3
- 功能：保存 EL3 异常向量表基地址

### 3.2 `MPIDR_EL1`

- 全称：Multiprocessor Affinity Register
- 功能：标识当前 CPU 的 affinity

### 3.3 `SCR_EL3`

- 全称：Secure Configuration Register, EL3
- 功能：控制安全态视角、异常路由等

### 3.4 `ICC_SRE_EL1` / `ICC_SRE_EL2` / `ICC_SRE_EL3`

- 全称：Interrupt Controller System Register Enable Register
- 功能：允许通过系统寄存器访问 GIC CPU interface

### 3.5 `ICC_PMR_EL1`

- 全称：Interrupt Priority Mask Register
- 功能：设置当前 CPU 接收中断的优先级门槛

### 3.6 `ICC_IGRPEN0_EL1`

- 全称：Interrupt Group 0 Enable Register
- 功能：打开 Group0 中断接收

### 3.7 `ICC_IGRPEN1_EL1`

- 全称：Interrupt Group 1 Enable Register
- 功能：打开当前安全状态下的 Group1 中断接收

### 3.8 `ICC_IGRPEN1_EL3`

- 全称：Interrupt Group 1 Enable Register, EL3 view
- 功能：由 EL3 控制 Non-secure Group1 中断接收

### 3.9 `ICC_IAR0_EL1`

- 全称：Interrupt Acknowledge Register for Group 0
- 功能：读取当前 Group0 中断的 INTID

### 3.10 `ICC_IAR1_EL1`

- 全称：Interrupt Acknowledge Register for Group 1
- 功能：读取当前 Group1 中断的 INTID

### 3.11 `ICC_EOIR0_EL1`

- 全称：End Of Interrupt Register for Group 0
- 功能：向 GIC 报告 Group0 中断处理结束

### 3.12 `ICC_EOIR1_EL1`

- 全称：End Of Interrupt Register for Group 1
- 功能：向 GIC 报告 Group1 中断处理结束

### 3.13 `ICC_DIR_EL1`

- 全称：Deactivate Interrupt Register
- 功能：显式 de-activate 某个中断

### 3.14 `GICR_WAKER`

- 功能：控制/反映 Redistributor 的睡眠与唤醒状态

### 3.15 `GICR_TYPER`

- 功能：描述 Redistributor 属性，例如 affinity、是否是最后一个 RD、扩展 PPI 能力等

### 3.16 `GICD_CTLR`

- 功能：Distributor 主控制寄存器

### 3.17 `GICD_ISENABLER[]`

- 功能：使能 SPI 等共享中断
- 组织方式：一个 32 位寄存器控制 32 个中断

### 3.18 `GICR_ISENABLER[]`

- 功能：使能 SGI/PPI 等本地中断
- 位于 Redistributor 的 SGI/PPI 区域

### 3.19 `GICD_IPRIORITYR[]`

- 功能：设置普通 SPI 的优先级

### 3.20 `GICR_IPRIORITYR[]`

- 功能：设置本地中断（如 SGI/PPI、扩展 PPI）的优先级

### 3.21 `GICD_ROUTER[]`

- 功能：配置 SPI 路由到哪个 affinity/PE
