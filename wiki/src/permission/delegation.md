# 权限的传递：Move / Copy / Mint

权限在系统中的流动方式决定了安全模型的强度。能力系统中，权限通过三种基本操作传递。

## Move（移动）

转移能力的所有权。移动后源能力槽为空，系统中只有一个副本。

**seL4 的 Move 实现：**
```c
// seL4_CNode_Move 的核心逻辑
int seL4_CNode_Move(cspace_t *dest_cspace, cptr_t dest_slot,
                    cspace_t *src_cspace, cptr_t src_slot) {
    cap_t cap = cspace_get_cap(src_cspace, src_slot);
    if (cap == NULL) return -1;         // 源槽为空
    if (cspace_get_cap(dest_cspace, dest_slot) != NULL)
        return -2;                      // 目标槽已被占用
    cspace_put_cap(dest_cspace, dest_slot, cap);
    cspace_clear_slot(src_cspace, src_slot);
    return 0;
}
```

**撤销复杂度：** O(1)。能力在系统中只有一个副本，撤销不需要扫描。

## Copy（复制）

创建能力的精确副本，原持有者保留权限。

**seL4 的 Copy 实现要点：**
1. 从源能力槽读取能力
2. 检查目标槽是否为空
3. 创建能力的副本（增加引用计数）
4. 将副本写入目标槽

撤销时需要遍历所有副本，复杂度 O(n)。seL4 通过能力派生树（双向链表）追踪副本关系。

## Mint（铸造）

带衰减的复制。新能力是原能力的权限子集。

**Mint 的权限衰减算法：**
```
Mint(cap_original, new_permissions) → cap_new
前提：new_permissions ⊆ cap_original.permissions
效果：cap_new.permissions = new_permissions
保证：cap_new 不能派生超出自身权限的能力
```

## HIC 中的全局能力表传递

HIC 使用全局 ID 表管理所有能力，非 seL4 的每个线程独立能力空间。传递是 ID 表中的归属变更：

```
  before:       after:
  Table[0x42]   Table[0x42]
    owner: A      owner: B      ← 只改归属字段
    perms: RW     perms: RW
```

传递是原子性的——Core-0 在禁用中断的上下文中完成归属更新，不存在中间状态。

## 三种操作对比

| 操作 | 引用计数变化 | 撤销复杂度 | 适用场景 |
|------|------------|-----------|---------|
| Move | 不变 | O(1) | 独占资源移交 |
| Copy | +1 | O(n) | 权限共享 |
| Mint | +1（受限） | O(n) | 最小权限委托 |

> 对应书籍：第 14 章  
> 参考文献：seL4 Manual §2.2, HIC IPC 3.0 规范
