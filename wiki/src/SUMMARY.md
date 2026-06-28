# 内核设计 Wiki

[关于此 Wiki](index.md)

---
- [权限模型](permission/README.md)
  - [权限模型](permission/README.md)
  - [控制的三要素](permission/access-control-triple.md)
  - [最小权限原则](permission/least-privilege.md)
  - [权限的衰减](permission/attenuation.md)
  - [权限的传递：Move / Copy / Mint](permission/delegation.md)
  - [权限的撤销](permission/revocation.md)
  - [能力模型](permission/capability.md)
  - [ACL 模型](permission/acl.md)
  - [标签模型（MAC）](permission/label.md)
  - [信任锚](permission/root-of-trust.md)
- [调度模型](scheduling/README.md)
  - [Scheduling 模型](scheduling/README.md)
  - [RISC-V 中断入口 (M-mode)](scheduling/interrupts.md)
  - [调度模型](scheduling/scheduling.md)
  - [同步](scheduling/synchronization.md)
  - [死锁](scheduling/deadlock.md)
  - [内存调度](scheduling/memory-scheduling.md)
  - [EEVDF 调度器](scheduling/eevdf.md)
  - [上下文切换](scheduling/context-switch.md)
- [结构模型](structure/README.md)
  - [分层](structure/layering.md)
  - [结构模型](structure/README.md)
  - [模块化](structure/modularity.md)
  - [可扩展性](structure/extensibility.md)
- [资源模型](resource/README.md)
  - [Resource 模型](resource/README.md)
  - [伙伴系统](resource/buddy-system.md)
  - [Slab 分配器](resource/slab-allocator.md)
  - [进程间通信 (IPC)](resource/ipc.md)
  - [虚拟内存](resource/virtual-memory.md)

---

## 按系统浏览
- [seL4](systems/seL4.md)
- [Linux](systems/Linux.md)
- [HIC](systems/HIC.md)
- [QNX](systems/QNX.md)
- [MINIX](systems/MINIX.md)
- [CHERI](systems/CHERI.md)
- [L4](systems/L4.md)

---

- [贡献指南](CONTRIBUTING.md)
