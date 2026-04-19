# Makefile 构建说明

## 1. `Makefile` 在这个仓库里负责什么

- 指定编译器、汇编器、链接器
- 定义编译参数
- 生成多个示例镜像
- 区分 GICv3 / GICv4 的构建方式
- 兼容 Windows / Unix 命令行环境

## 2. 这个工程用的工具链

```make
CC=armclang
AS=armclang
LD=armlink
```

含义：

- `CC`：C 编译器
- `AS`：汇编器
- `LD`：链接器

这里默认使用 Arm Compiler 6 工具链。

## 3. 常见编译变量

```make
ASFLAGS= -gdwarf-3 -c --target=aarch64-arm-none-eabi
CFLAGS=  -gdwarf-3 -c --target=aarch64-arm-none-eabi -I"./headers" -O1
```

先粗暴理解成：

- `-gdwarf-3`：生成调试信息
- `-c`：只编译，不链接
- `--target=aarch64-arm-none-eabi`：目标平台是 AArch64 裸机
- `-I"./headers"`：头文件目录
- `-O1`：优化级别

## 4. `GIC?= GICV3` 是什么

意思是：

- 如果外部没有传入 `GIC`
- 那默认按 `GICV3` 构建

比如：

```bash
make GIC=GICV4
```

会覆盖默认值。

## 5. 条件编译是怎么接进源码的

```make
ifeq "$(GIC)" "GICV4"
    CFLAGS += -DGICV4=TRUE
endif
```

意思是：

- 如果当前构建目标是 `GICV4`
- 就给源码额外定义 `GICV4` 宏

这样源码里可以通过：

```c
#ifdef GICV4
```

走不同分支。

## 6. `DEBUG=TRUE` 的作用

```make
ifeq "$(DEBUG)" "TRUE"
    CFLAGS += -DDEBUG
endif
```

意思是：

- 如果命令行传 `DEBUG=TRUE`
- 就定义 `DEBUG` 宏
- 这样源码里的调试打印会打开

## 7. 为什么 `Makefile` 里要区分 Windows / Unix

因为：

- 删除命令不同
- shell 路径不同

所以它按环境选择：

- Windows：`del`
- Unix：`rm -f`

## 8. 默认会生成哪些镜像

默认目标：

```make
all: image_basic.axf image_lpi.axf image_gicv31.axf
```

表示默认构建：

- `image_basic.axf`
- `image_lpi.axf`
- `image_gicv31.axf`

## 9. `gicv4` 目标是什么

```make
gicv4: image_vlpi.axf image_vsgi.axf
```

表示只有显式指定时，才额外构建：

- `image_vlpi.axf`
- `image_vsgi.axf`

## 10. `clean` / `rebuild`

- `clean`：删除中间文件和输出镜像
- `rebuild`：先 `clean` 再 `all`

## 11. 一个镜像是怎么链接出来的

例如：

```make
image_basic.axf: main_basic.o generic_timer.o system_counter.o sp804_timer.o startup.o gicv3_basic.o gicv3_cpuif.o el3_vectors.o scatter.txt
    $(LD) --scatter=scatter.txt ... -o image_basic.axf --entry=start64
```

这说明：

- `image_basic.axf` 由这些 `.o` 文件链接而成
- 使用 `scatter.txt` 作为链接布局文件
- 程序入口是 `start64`

## 12. `--entry=start64` 的意义

表示镜像启动入口不是 `main()`，而是：

```text
start64
```

也就是先执行启动汇编，再进入 C 运行时和 `main()`

## 13. `scatter.txt` / `scatter_virt.txt` 的作用

它们是链接布局文件。

作用：

- 决定各个 section 最终放到内存哪里
- 决定代码、向量表、数据段的地址布局

其中：

- `scatter.txt`：普通示例使用
- `scatter_virt.txt`：GICv4.1 虚拟化示例使用

## 14. 为什么 GIC 版本会影响构建

因为：

- GICv3 和 GICv4 的 Redistributor 地址布局不同
- 所以构建时要知道当前按哪种 GIC 版本处理

这也是为什么常见命令是：

```bash
make
make GIC=GICV4
make GIC=GICV4 gicv4
```

## 15. 新人看 `Makefile` 时最先抓什么

优先看这几类信息：

1. 默认构建目标是什么
2. 哪些源文件组成哪个镜像
3. 入口符号是谁
4. 用了哪个链接脚本
5. 有哪些条件编译宏

对这个仓库来说，最关键的结论是：

- `image_basic.axf` 最适合入门
- 入口是 `start64`
- `main_basic.c` 只是入口之后的主流程，不是程序最早开始执行的位置
