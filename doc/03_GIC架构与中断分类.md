# GIC 架构与中断分类

## 1. GIC 架构怎么分工

### 1.1 Distributor

- 管全局共享中断
- 常见用于 SPI

### 1.2 Redistributor

- 每个 CPU 对应一个
- 管本地相关中断
- 常见用于 SGI / PPI / LPI 相关配置

### 1.3 CPU interface

- CPU 自己从 GIC 取中断、回 EOI、设优先级门槛
- 这个工程主要通过 AArch64 系统寄存器访问

## 2. 中断类型和编号区间

### 2.1 常见类型

- SGI：软件生成中断
- PPI：每个 CPU 私有中断
- SPI：共享外设中断
- Extended PPI：GICv3.1 扩展本地中断
- Extended SPI：GICv3.1 扩展共享中断

### 2.2 代码里常见的区间判断

- 普通 SGI/PPI：低编号，本地侧处理
- 普通 SPI：`ID < 1020`
- 扩展 PPI：`1056..1119`
- 扩展 SPI：`4096..5119`

结论：

- 不同编号区间，对应不同寄存器区
- 所以不能把所有中断都用一套固定公式处理
