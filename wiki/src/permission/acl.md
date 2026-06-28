# ACL 模型

访问控制列表（Access Control List）是最直观的权限管理方式——每个客体附带一个列表，记录谁可以对它做什么。

## 系统对比

| 方面 | 常规 POSIX | Linux | FreeBSD UFS | Windows NTFS | NFSv4/ZFS |
|------|-----------|-------|-------------|-------------|-----------|
| ACL 存储 | inode 权限位 | `posix_acl` 结构体 + EA | 扩展属性 (EA) | Security Descriptor | ZFS 自身 ACL |
| 条目类型 | USER/GROUP/OTHER | + MASK, 命名用户/组 | 同 POSIX.1e | Allow/Deny 显式 | Allow/Deny + 继承标记 |
| 继承 | 无 | 默认 ACL (目录) | 同 Linux | 完整继承链 | FILE_INHERIT/DIR_INHERIT |
| 回退 | mode bits | ACL→mode | ACL→mode | 最后检查 | everyone@ 条目 |
| 内核文件 | — | `fs/posix_acl.c` | `ufs/ufs_acl.c` | `ntos/ob/ob.c` | ZFS 模块 |

## Linux POSIX ACL 实现

### 数据结构

```c
// include/linux/posix_acl.h
struct posix_acl {
    refcount_t      a_refcount;   // 引用计数
    unsigned int    a_count;      // 条目数
    struct posix_acl_entry a_entries[];  // 弹性数组
};

struct posix_acl_entry {
    short           e_tag;        // 条目类型
    unsigned short  e_perm;       // 权限位
    union {
        kuid_t      e_uid;        // ACL_USER 的 UID
        kgid_t      e_gid;        // ACL_GROUP 的 GID
    };
};
```

### 条目类型与顺序

```c
// include/uapi/linux/posix_acl.h
#define ACL_USER_OBJ    0x01  // 文件属主
#define ACL_USER        0x02  // 命名用户
#define ACL_GROUP_OBJ   0x04  // 文件属组
#define ACL_GROUP       0x08  // 命名组
#define ACL_MASK        0x10  // 最大权限掩码
#define ACL_OTHER       0x20  // 其他人

// 有效 ACL 必须按此顺序排列，且每个类型最多一条：
// USER_OBJ → [USER...] → GROUP_OBJ → [GROUP...] → [MASK] → OTHER
```

### 权限检查核心

```c
// fs/posix_acl.c
int posix_acl_permission(struct inode *inode, const struct posix_acl *acl,
                          int mask) {
    const struct posix_acl_entry *pa, *pe;
    int found = 0;

    // 遍历 ACL 条目
    FOREACH_ACL_ENTRY(pa, pe, acl, inode->i_uid) {
        switch (pa->e_tag) {
        case ACL_USER_OBJ:
            if (uid_eq(current_fsuid(), inode->i_uid))
                goto check;
            break;
        case ACL_USER:
            if (uid_eq(pa->e_uid, current_fsuid()))
                goto check;
            break;
        case ACL_GROUP_OBJ:
            if (in_group_p(inode->i_gid)) {
                found = 1;
                if ((pa->e_perm & mask) == mask)
                    goto mask_check;
            }
            break;
        case ACL_GROUP:
            if (in_group_p(pa->e_gid)) {
                found = 1;
                if ((pa->e_perm & mask) == mask)
                    goto mask_check;
            }
            break;
        case ACL_OTHER:
            if (found)
                goto mask_check;
            else
                goto check;
        }
    }
    return -EACCES;

check:
    return (pa->e_perm & mask) ? 0 : -EACCES;
mask_check:
    // 存在 MASK 条目时，权限受 MASK 限制
    return (acl->a_entries[acl->a_count-1].e_perm & mask) ? 0 : -EACCES;
}
```

### ACL 缓存 (RCU)

```c
// fs/posix_acl.c — RCU 缓存层
struct posix_acl *get_cached_acl(struct inode *inode, int type) {
    struct posix_acl *acl = rcu_dereference(inode->i_acl);
    if (acl == ACL_NOT_CACHED) {
        // 从文件系统加载 ACL
        acl = inode->i_op->get_acl(inode, type);
        // 写入缓存
        cmpxchg(inode->i_acl, ACL_NOT_CACHED, acl);
    }
    return acl;
}
```

## FreeBSD UFS ACL 实现

```c
// sys/ufs/ufs/ufs_acl.c
struct acl {
    unsigned int     acl_maxcnt;
    unsigned int     acl_cnt;
    struct acl_entry acl_entry[ACL_MAX_ENTRIES];  // 254 条
};

struct acl_entry {
    ae_tag_t     ae_tag;     // ACL_USER_OBJ / ACL_USER / ...
    ae_perm_t    ae_perm;    // 权限位
    uid_t        ae_id;      // UID/GID
};
```

FreeBSD 使用 `vaccess_acl_posix1e()` 进行 ACL 权限检查，UFS 通过 `ufs_access()` 调用，优先检查 ACL，无 ACL 时回退到传统 UNIX 权限。

## 参考文献

- Linux kernel source: `fs/posix_acl.c`, `include/linux/posix_acl.h`
- FreeBSD kernel source: `sys/ufs/ufs/ufs_acl.c`, `sys/kern/kern_acl.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.8 (ACL implementation)
- FreeBSD Handbook §16.11 Access Control Lists
- Windows Security Descriptor specification (MSDN)

> 对应书籍：第 11 章
