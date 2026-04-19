# ARMv8 启动与 GIC 示例工程的 Makefile
#
# 中文说明：
# 这个文件负责把多个示例源码编译并链接成不同的 axf 镜像。
# 你可以把它理解成“这个仓库的命令行构建脚本”。
#
# Copyright (C) ARM Limited, 2013. All rights reserved.
#
# This makefile is intended for use with GNU make
# This example is intended to be built with ARM Compiler 6
# 中文说明：默认使用 ARM Compiler 6 工具链

# 汇编选项：生成调试信息，只编译，不链接，目标为 AArch64 裸机
ASFLAGS= -gdwarf-3 -c --target=aarch64-arm-none-eabi
# C 编译选项：生成调试信息，包含头文件目录，并做 O1 优化
CFLAGS=  -gdwarf-3 -c --target=aarch64-arm-none-eabi -I"./headers" -O1

# ARM Compiler 6 工具链程序名
CC=armclang
AS=armclang
LD=armlink

# 默认按 GICv3 构建；也可以通过命令行传入 GIC=GICV4
GIC?=	GICV3

ifeq "$(GIC)" "GICV4"
	# 打开源码中的 GICV4 条件编译
	CFLAGS += -DGICV4=TRUE
endif

ifeq "$(DEBUG)" "TRUE"
    # 打开额外调试日志
    CFLAGS += -DDEBUG
endif

# 根据 Windows / Unix 环境选择不同的 shell 和删除命令
ifdef WINDIR
DONE=@if exist $(1) if exist $(2) echo Build completed.
RM=if exist $(1) del /q $(1)
SHELL=$(WINDIR)\system32\cmd.exe
else
ifdef windir
DONE=@if exist $(1) if exist $(2) echo Build completed.
RM=if exist $(1) del /q $(1)
SHELL=$(windir)\system32\cmd.exe
else
DONE=@if [ -f $(1) ]; then if [ -f $(2) ]; then echo Build completed.; fi; fi
RM=rm -f $(1)
endif
endif

# 默认目标：构建最常用的 3 个示例
all: image_basic.axf image_lpi.axf image_gicv31.axf
	$(call DONE,$(EXECUTABLE))

# 额外目标：只有显式指定时才构建 GICv4.1 的虚拟化示例
gicv4: image_vlpi.axf image_vsgi.axf

# 先清理再构建
rebuild: clean all

# 清理中间文件和输出镜像
clean:
	$(call RM,*.o)
	$(call RM,image_basic.axf)
	$(call RM,image_lpi.axf)
	$(call RM,image_gicv31.axf)
	$(call RM,image_vlpi.axf)
	$(call RM,image_vsgi.axf)

# 下面是每个源文件的编译规则
main_basic.o: ./src/main_basic.c
	$(CC) ${CFLAGS} ./src/main_basic.c

main_gicv31.o: ./src/main_gicv31.c
	$(CC) ${CFLAGS} ./src/main_gicv31.c

main_lpi.o: ./src/main_lpi.c
	$(CC) ${CFLAGS} ./src/main_lpi.c

main_vlpi.o: ./src/main_vlpi.c
	$(CC) ${CFLAGS} ./src/main_vlpi.c

main_vsgi.o: ./src/main_vsgi.c
	$(CC) ${CFLAGS} ./src/main_vsgi.c

gicv3_basic.o: ./src/gicv3_basic.c
	$(CC) ${CFLAGS} ./src/gicv3_basic.c

gicv3_lpis.o: ./src/gicv3_lpis.c
	$(CC) ${CFLAGS} ./src/gicv3_lpis.c

gicv4_virt.o: ./src/gicv4_virt.c
	$(CC) ${CFLAGS} ./src/gicv4_virt.c

system_counter.o: ./src/system_counter.c
	$(CC) ${CFLAGS} ./src/system_counter.c

sp804_timer.o: ./src/sp804_timer.c
	$(CC) ${CFLAGS} ./src/sp804_timer.c

startup.o: ./src/startup.s
	$(AS) ${ASFLAGS} ./src/startup.s

startup_virt.o: ./src/startup_virt.s
	$(AS) ${ASFLAGS} ./src/startup_virt.s

secondary_virt.o: ./src/secondary_virt.s
	$(AS) ${ASFLAGS} ./src/secondary_virt.s

el3_vectors.o: ./src/el3_vectors.s
	$(AS) ${ASFLAGS} ./src/el3_vectors.s

generic_timer.o: ./src/generic_timer.s
	$(AS) ${ASFLAGS} ./src/generic_timer.s

gicv3_cpuif.o: ./src/gicv3_cpuif.S
	$(AS) ${ASFLAGS} ./src/gicv3_cpuif.S

# 基础示例：PPI + SPI，包括 Generic Timer 和 SP804
image_basic.axf: main_basic.o generic_timer.o system_counter.o sp804_timer.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter.txt main_basic.o generic_timer.o system_counter.o sp804_timer.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o -o image_basic.axf --entry=start64

# GICv3.1 示例：扩展 PPI / SPI 范围
image_gicv31.axf: main_gicv31.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter.txt main_gicv31.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o -o image_gicv31.axf --entry=start64

# 物理 LPI 示例：需要 ITS 和 LPI 相关模块
image_lpi.axf: main_lpi.o generic_timer.o system_counter.o startup.o gicv3_basic.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter.txt main_lpi.o  generic_timer.o system_counter.o               startup.o gicv3_basic.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o -o image_lpi.axf --entry=start64

# GICv4.1 vLPI 示例：使用虚拟化启动代码和专用 scatter 文件
image_vlpi.axf: main_vlpi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv4_virt.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter_virt.txt main_vlpi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv3_lpis.o gicv4_virt.o gicv3_cpuif.o el3_vectors.o -o image_vlpi.axf --entry=start64

# GICv4.1 vSGI 示例：同样依赖虚拟化相关对象文件
image_vsgi.axf: main_vsgi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv4_virt.o gicv3_lpis.o gicv3_cpuif.o el3_vectors.o scatter.txt
	$(LD) --scatter=scatter_virt.txt main_vsgi.o generic_timer.o system_counter.o startup_virt.o secondary_virt.o gicv3_basic.o gicv3_lpis.o gicv4_virt.o gicv3_cpuif.o el3_vectors.o -o image_vsgi.axf --entry=start64
