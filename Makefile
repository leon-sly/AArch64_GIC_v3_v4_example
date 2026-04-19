# =========================================================
# ARMv8 AArch64 裸机 + GICv3/GICv4 示例工程 Makefile
# =========================================================
#
# 作用：
#   这个 Makefile 用 GNU make 驱动 ARM Compiler 6 工具链，
#   把多个 C / 汇编源文件分别编译成 .o，再链接成不同功能的 .axf 镜像。
#
# 你可以把它理解成：
#   “这个 GIC 示例仓库的命令行构建入口”
#
# 产物：
#   image_basic.axf   -> 基础中断示例（PPI / SPI）
#   image_lpi.axf     -> 物理 LPI + ITS 示例
#   image_gicv31.axf  -> GICv3.1 扩展 PPI / SPI 范围示例
#   image_vlpi.axf    -> GICv4.1 虚拟 LPI 示例
#   image_vsgi.axf    -> GICv4.1 虚拟 SGI 示例
#
# 背景知识：
#   - .o   : 目标文件（编译或汇编后的中间产物）
#   - .axf : ARM Executable Format，可执行镜像文件
#   - scatter.txt : ARM 链接脚本，决定代码/数据放到什么地址
#   - --entry=start64 : 指定程序入口符号为 start64
#
# 构建工具要求：
#   - GNU make
#   - Arm Compiler 6
#   - armclang / armlink 可在命令行直接找到
#
# 默认行为：
#   直接执行 make 时，会构建 3 个最常用示例：
#     image_basic.axf
#     image_lpi.axf
#     image_gicv31.axf
#
# 可选行为：
#   make GIC=GICV4 gicv4
#   -> 额外构建 GICv4.1 的虚拟化示例
#
# =========================================================
# Copyright (C) ARM Limited, 2013. All rights reserved.
# =========================================================

# ---------------------------------------------------------
# 工具链相关说明
# ---------------------------------------------------------
# 本 Makefile 设计给 GNU make 使用
# 示例默认使用 ARM Compiler 6 工具链
#
# CC : C 编译器
# AS : 汇编器（这里也用 armclang 处理 .s/.S）
# LD : 链接器
#
# 注意：
#   armclang 既可编译 C，也可汇编 .s/.S 文件
#   armlink 负责把多个 .o 和 scatter 文件链接成 .axf
CC = armclang
AS = armclang
LD = armlink

# ---------------------------------------------------------
# 编译选项
# ---------------------------------------------------------
# ASFLAGS:
#   -gdwarf-3                    生成 DWARF v3 调试信息，方便调试器识别源码/符号
#   -c                           只汇编生成目标文件，不进行链接
#   --target=aarch64-arm-none-eabi
#                                目标平台为 AArch64 裸机环境
#
# CFLAGS:
#   -gdwarf-3                    生成调试信息
#   -c                           只编译，不链接
#   --target=aarch64-arm-none-eabi
#                                面向 AArch64 裸机目标
#   -I"./headers"                头文件搜索路径
#   -O1                          打开较轻量优化，兼顾可调试性和代码质量
ASFLAGS = -gdwarf-3 -c --target=aarch64-arm-none-eabi
CFLAGS  = -gdwarf-3 -c --target=aarch64-arm-none-eabi -I"./headers" -O1

# ---------------------------------------------------------
# 可选构建参数
# ---------------------------------------------------------
# GIC:
#   默认按 GICV3 构建
#   用户可在命令行覆盖，例如：
#       make GIC=GICV4
#
# "?=" 的含义：
#   只有在 GIC 没被外部传入时，才给它默认值 GICV3
GIC ?= GICV3

# 如果命令行指定 GIC=GICV4
# 则在编译 C 文件时增加宏定义 GICV4=TRUE
# 这样源码里可以用 #ifdef / #if 控制 GICv4 相关代码路径
ifeq "$(GIC)" "GICV4"
	CFLAGS += -DGICV4=TRUE
endif

# 如果命令行指定 DEBUG=TRUE
# 则增加 -DDEBUG，让源码里打开额外日志或调试输出
#
# 例如：
#   make DEBUG=TRUE
ifeq "$(DEBUG)" "TRUE"
	CFLAGS += -DDEBUG
endif

# ---------------------------------------------------------
# 跨平台 shell / 删除命令适配
# ---------------------------------------------------------
# 这一段是为了兼容 Windows 和类 Unix 环境。
#
# WINDIR / windir 常常能用来判断当前是不是 Windows 命令行环境。
#
# DONE:
#   构建完成时的提示逻辑
#
# RM:
#   删除文件命令
#
# SHELL:
#   指定 make 调用的 shell
ifdef WINDIR

# Windows 情况
# $(1), $(2) 是 make 的 call 参数占位符
# 这里表示：如果两个文件都存在，就打印 Build completed.
DONE = @if exist $(1) if exist $(2) echo Build completed.

# Windows 删除命令
RM = if exist $(1) del /q $(1)

# 指定使用 cmd.exe 作为 make 的 shell
SHELL = $(WINDIR)\system32\cmd.exe

else
ifdef windir

# 某些环境变量名可能是小写 windir，这里也兼容
DONE = @if exist $(1) if exist $(2) echo Build completed.
RM = if exist $(1) del /q $(1)
SHELL = $(windir)\system32\cmd.exe

else

# Unix / Linux / macOS 情况
# 如果两个文件都存在，就打印 Build completed.
DONE = @if [ -f $(1) ]; then if [ -f $(2) ]; then echo Build completed.; fi; fi

# Unix 删除命令
RM = rm -f $(1)

endif
endif

# ---------------------------------------------------------
# 默认目标
# ---------------------------------------------------------
# make 不带参数时，会执行第一个目标，这里就是 all
#
# all 依赖 3 个最常用示例镜像：
#   1) 基础中断示例
#   2) LPI 示例
#   3) GICv3.1 扩展示例
#
# 只有当这些 .axf 不存在，或者依赖文件有更新时，make 才会重新构建
all: image_basic.axf image_lpi.axf image_gicv31.axf
	$(call DONE,$(EXECUTABLE))

# ---------------------------------------------------------
# 额外目标：GICv4.1 虚拟化示例
# ---------------------------------------------------------
# 这个目标默认不会随 all 一起构建
# 只有手动执行时才构建：
#   make GIC=GICV4 gicv4
gicv4: image_vlpi.axf image_vsgi.axf

# ---------------------------------------------------------
# rebuild：强制重建
# ---------------------------------------------------------
# 先 clean 删除旧产物，再执行 all 重新构建
rebuild: clean all

# ---------------------------------------------------------
# clean：清理中间文件和镜像
# ---------------------------------------------------------
# 用于回到“未构建”状态
# 典型用途：
#   make clean
#   make rebuild
clean:
	$(call RM,*.o)
	$(call RM,image_basic.axf)
	$(call RM,image_lpi.axf)
	$(call RM,image_gicv31.axf)
	$(call RM,image_vlpi.axf)
	$(call RM,image_vsgi.axf)

# =========================================================
# 各源文件的编译 / 汇编规则
# =========================================================
#
# 规则格式：
#   目标文件: 依赖源文件
#       命令
#
# 含义：
#   当源文件更新时，对应 .o 会重新生成
#
# 注意：
#   这里多数规则写得比较“显式”，方便教学理解；
#   实际工程里也常用模式规则减少重复。
# =========================================================

# ---------- C 源文件编译规则 ----------

# 基础中断演示主程序
main_basic.o: ./src/main_basic.c
	$(CC) ${CFLAGS} ./src/main_basic.c

# GICv3.1 扩展中断范围演示主程序
main_gicv31.o: ./src/main_gicv31.c
	$(CC) ${CFLAGS} ./src/main_gicv31.c

# 物理 LPI 演示主程序
main_lpi.o: ./src/main_lpi.c
	$(CC) ${CFLAGS} ./src/main_lpi.c

# GICv4.1 虚拟 LPI 演示主程序
main_vlpi.o: ./src/main_vlpi.c
	$(CC) ${CFLAGS} ./src/main_vlpi.c

# GICv4.1 虚拟 SGI 演示主程序
main_vsgi.o: ./src/main_vsgi.c
	$(CC) ${CFLAGS} ./src/main_vsgi.c

# GICv3 基础配置 / 操作辅助函数
gicv3_basic.o: ./src/gicv3_basic.c
	$(CC) ${CFLAGS} ./src/gicv3_basic.c

# GICv3 LPI / ITS 相关辅助函数
gicv3_lpis.o: ./src/gicv3_lpis.c
	$(CC) ${CFLAGS} ./src/gicv3_lpis.c

# GICv4 虚拟化相关辅助函数
gicv4_virt.o: ./src/gicv4_virt.c
	$(CC) ${CFLAGS} ./src/gicv4_virt.c

# 系统计数器访问/配置代码
system_counter.o: ./src/system_counter.c
	$(CC) ${CFLAGS} ./src/system_counter.c

# SP804 定时器驱动/示例代码
sp804_timer.o: ./src/sp804_timer.c
	$(CC) ${CFLAGS} ./src/sp804_timer.c

# ---------- 汇编源文件规则 ----------
#
# 这些文件通常负责：
#   - 启动入口
#   - 异常向量表
#   - EL 切换
#   - 访问系统寄存器
#   - 次级核启动
#

# 普通启动代码
startup.o: ./src/startup.s
	$(AS) ${ASFLAGS} ./src/startup.s

# 虚拟化场景使用的启动代码
startup_virt.o: ./src/startup_virt.s
	$(AS) ${ASFLAGS} ./src/startup_virt.s

# 次级核（secondary core）启动汇编
secondary_virt.o: ./src/secondary_virt.s
	$(AS) ${ASFLAGS} ./src/secondary_virt.s

# EL3 异常向量表
el3_vectors.o: ./src/el3_vectors.s
	$(AS) ${ASFLAGS} ./src/el3_vectors.s

# Generic Timer 访问辅助汇编
generic_timer.o: ./src/generic_timer.s
	$(AS) ${ASFLAGS} ./src/generic_timer.s

# GIC CPU interface / system register 访问汇编
# 注意这里是 .S，大写 S 一般意味着可能会经过预处理器
gicv3_cpuif.o: ./src/gicv3_cpuif.S
	$(AS) ${ASFLAGS} ./src/gicv3_cpuif.S

# =========================================================
# 各镜像的链接规则
# =========================================================
#
# 规则本质：
#   把对应的 .o 文件 + scatter 文件交给 armlink，
#   生成最终的 .axf 可执行镜像。
#
# 共通项：
#   --scatter=xxx     指定内存布局文件
#   -o xxx.axf        指定输出镜像名
#   --entry=start64   指定程序入口函数/符号
#
# 为什么每个镜像依赖不同的 .o？
#   因为每个示例演示的功能不同，所以链接进去的模块不同。
# =========================================================

# ---------------------------------------------------------
# 基础示例：PPI + SPI
# ---------------------------------------------------------
# 包含：
#   - main_basic.o      主逻辑
#   - generic_timer.o   通用定时器
#   - system_counter.o  系统计数器
#   - sp804_timer.o     SP804 定时器
#   - startup.o         启动入口
#   - gicv3_basic.o     GICv3 基础操作
#   - gicv3_cpuif.o     CPU 接口访问
#   - el3_vectors.o     异常向量
#
# 这个镜像最适合拿来学习“中断最小闭环”
image_basic.axf: main_basic.o generic_timer.o system_counter.o sp804_timer.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter.txt main_basic.o generic_timer.o system_counter.o sp804_timer.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o -o image_basic.axf --entry=start64

# ---------------------------------------------------------
# GICv3.1 扩展 PPI / SPI 示例
# ---------------------------------------------------------
# 用来演示 GICv3.1 的 extended PPI / SPI range
# 不需要 LPI / ITS 相关模块，因此依赖较少
image_gicv31.axf: main_gicv31.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter.txt main_gicv31.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o -o image_gicv31.axf --entry=start64

# ---------------------------------------------------------
# 物理 LPI 示例
# ---------------------------------------------------------
# 比基础示例多了：
#   - gicv3_lpis.o
# 说明此镜像除了普通 GIC 配置外，还演示 ITS / LPI 机制
image_lpi.axf: main_lpi.o generic_timer.o system_counter.o startup.o gicv3_basic.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter.txt main_lpi.o generic_timer.o system_counter.o startup.o gicv3_basic.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o -o image_lpi.axf --entry=start64

# ---------------------------------------------------------
# GICv4.1 vLPI 示例
# ---------------------------------------------------------
# 与前面几个示例不同点：
#   - 使用 startup_virt.o / secondary_virt.o
#   - 使用 gicv4_virt.o
#   - 使用 scatter_virt.txt（虚拟化场景专用布局）
#
# 说明：
#   这个镜像进入了更复杂的 GICv4.1 虚拟化使用方式
image_vlpi.axf: main_vlpi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv4_virt.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter_virt.txt main_vlpi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv3_lpis.o gicv4_virt.o gicv3_cpuif.o el3_vectors.o -o image_vlpi.axf --entry=start64

# ---------------------------------------------------------
# GICv4.1 vSGI 示例
# ---------------------------------------------------------
# 与 image_vlpi.axf 类似，但主程序换成 main_vsgi.o
# 用于演示虚拟 SGI 的场景
image_vsgi.axf: main_vsgi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv4_virt.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter_virt.txt main_vsgi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv3_lpis.o gicv4_virt.o gicv3_cpuif.o el3_vectors.o -o image_vsgi.axf --entry=start64