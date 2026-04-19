# AArch64 GIC Example Notes（拆分版）

这组文档按主题拆分，便于顺着主线阅读，而不是按问答碎片跳读。

## 建议阅读顺序

1. `01_如何读这个仓库.md`
2. `02_程序启动与中断主线.md`
3. `03_GIC架构与中断分类.md`
4. `04_主流程与关键函数.md`
5. `05_中断配置关键点.md`
6. `06_附录_汇编_PSTATE_寄存器.md`

## 参考资料

- Arm AArch64 GIC system registers summary:  
  https://developer.arm.com/documentation/102670/0301/AArch64-registers/AArch64-register-summaries/AArch64-GIC-system-registers-summary?lang=en

## 拆分原则

- 尽量按“阅读主线”和“主题边界”整理
- 以重排和归并为主，不额外引入不必要的新实体
- 保留原文中的关键结论、术语和代码落点
