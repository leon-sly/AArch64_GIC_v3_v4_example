# AArch64 GIC Example Notes

## 启动图

```text
上电 / 复位
   |
   v
start64
[src/startup.s]
   |
   |-- 清寄存器
   |-- 判断当前核是不是 0.0.0.0
   |-- 配置 EL3 环境
   |-- 打开 GIC system register interface(SRE)
   |-- 安装异常向量表 VBAR_EL3 = el3_vectors
   |-- 允许 IRQ/FIQ
   |
   v
__main
(C 运行时初始化，库代码)
   |
   v
main()
[src/main_basic.c]
```

要点：

- 真正第一段代码不是 `main()`，是 `start64`
- `startup.s` 先把 CPU 和异常环境准备好
- 然后进入 `__main`
- 再由 `__main` 进入 `main()`

## 中断图

```text
定时器/外设触发中断
   |
   |-- Secure Physical Timer -> INTID 29
   |-- Non-secure Physical Timer -> INTID 30
   |-- SP804 Timer -> INTID 34
   |
   v
GIC 接收并仲裁中断
   |
   |-- Distributor / Redistributor 已经在 main() 中配置好
   |-- CPU interface 已经允许接收中断
   |
   v
CPU 进入 EL3 异常向量
[src/el3_vectors.s]
   |
   v
fiqFirstLevelHandler
[src/el3_vectors.s]
   |
   |-- 保存现场
   |-- BL fiqHandler
   |
   v
fiqHandler()
[src/main_basic.c]
   |
   |-- readIARGrp0()       读取当前中断号
   |-- switch(INTID)       判断是谁来的中断
   |-- 清除对应外设/定时器中断源
   |-- writeEOIGrp0(ID)    通知 GIC 处理结束
   |
   v
返回被打断的位置继续执行
```

要点：

- 进异常
- 读 `IAR`
- 清外设中断
- 写 `EOI`

## 模块图

```text
                    +----------------------+
                    |   src/main_basic.c   |
                    | 主流程 / 示例入口     |
                    +----------+-----------+
                               |
         +---------------------+----------------------+
         |                     |                      |
         v                     v                      v
+------------------+  +-------------------+  +------------------+
| src/gicv3_basic.c|  | src/gicv3_cpuif.S |  | src/sp804_timer.c|
| GIC基础配置       |  | CPU IF系统寄存器封装| | SP804外设访问     |
| Distributor/RD   |  | readIAR/writeEOI  |  | 清中断/启动定时器  |
+------------------+  +-------------------+  +------------------+
         |                     |
         |                     |
         v                     v
+------------------+  +-------------------+
|src/startup.s     |  |src/el3_vectors.s  |
| 启动代码          |  | 异常向量与一级入口  |
+------------------+  +-------------------+
         |
         v
+------------------+
| system_counter.c |
| generic_timer.s  |
| 通用计时器相关    |
+------------------+
```

简化理解：

- `main_basic.c`：总流程
- `startup.s`：程序怎么启动
- `el3_vectors.s`：中断怎么接进来
- `gicv3_basic.c`：GIC 怎么配置
- `gicv3_cpuif.S`：CPU 怎么拿中断、回中断
- `sp804_timer.c`：外设怎么触发和清中断
- `system_counter.c` / `generic_timer.s`：通用计时器支持

## 下一步

后续先只看 `src/gicv3_basic.c`。
