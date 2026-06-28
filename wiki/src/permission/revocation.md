# 权限的撤销

权限一旦被授予，能否收回？这是访问控制系统中最难解决的问题之一。

## 为什么撤销困难

根本原因在于**权限的传播**。如果一个权限被复制或派生给多个主体，撤销必须"追上"所有副本。

**ACL 系统：** 撤销简单——删除客体 ACL 中的条目即可，因为权限集中存储在客体上。

**能力系统：** 撤销困难——能力已被复制到各个主体的能力空间中，必须追踪所有副本。

## seL4 递归撤销算法

seL4 通过能力派生树管理撤销。每个能力节点记录父指针，撤销时递归遍历子树：

```
revoke(cap):
    for each child in cap.children:
        revoke(child)        // 递归撤销子能力
        cspace_clear(child)  // 清空能力槽
    cap.permissions = 0      // 标记失效
```

**派生树结构（双向链表）：**
```c
struct cap_node {
    cap_t cap;
    struct cap_node *parent;   // 父能力
    struct cap_node *children; // 子能力链表头
    struct cap_node *sibling;  // 兄弟节点
    int depth;                 // 派生深度
};
```

撤销遍历从目标节点开始，沿 `children` 指针向下递归，时间复杂度 O(n)，n 为派生子树大小。

**MCS 扩展中的撤销优化：** 分阶段处理，避免撤销低优先级能力时意外阻塞高优先级线程。

## HIC 的撤销

HIC 使用全局能力 ID 表集中管理，撤销即 ID 表条目的原子更新：

```c
// HIC 撤销伪代码
void hic_revoke(cap_id_t id) {
    Core0: disable_interrupts();
    cap_table[id].owner = NULL;     // 清除归属
    cap_table[id].valid = false;    // 标记失效
    for each child in cap_tree[id]:
        cap_table[child].valid = false;
    Core0: enable_interrupts();
}
```

由于所有能力通过全局表统一管理，撤销不需要跨能力空间遍历副本。Core-0 在禁用中断的上下文中原子性地完成能力表更新，不存在竞态条件。

## 撤销方式对比

| 方式 | ACL | seL4 能力树 | HIC 全局表 |
|------|-----|-------------|-----------|
| 撤销路径 | 修改客体 ACL | 遍历派生子树 | 更新 ID 表条目 |
| 复杂度 | O(1) | O(n) | O(1) |
| 原子性 | 依赖文件系统锁 | 内核串行化 | 关中断 |
| 传递性 | 只影响当前主体 | 递归所有子能力 | 递归子树 |

> 对应书籍：第 15 章
