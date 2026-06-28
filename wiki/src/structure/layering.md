# 分层

分层将系统划分为若干层次，每层建立在下一层之上，核心规则是**单向调用**——上层可以调用下层，下层不能调用上层。

## Linux VFS 分层架构

VFS（Virtual File System）是 Linux 文件系统的分层抽象。它在用户态系统调用与具体文件系统实现之间插入统一接口层。

```
用户空间（open / read / write / close）
       │
       ▼
┌─────────────────────────────────┐
│         VFS 层                   │
│  super_block  inode  dentry  file│
│  super_ops    inode_op  dentry_op│
│            file_operations       │
└──────────────┬──────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│   具体文件系统（ext4 / xfs / btrfs）│
└──────────────┬──────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│      块 I/O 层 / 设备驱动       │
└─────────────────────────────────┘
```

### 核心数据结构

```c
// include/linux/fs.h

// 超级块：代表已挂载的文件系统
struct super_block {
    struct list_head    s_list;          // 超级块链表
    dev_t              s_dev;           // 设备标识
    unsigned long      s_blocksize;     // 块大小
    const struct super_operations *s_op; // 超级块操作函数表
    // ...
};

// inode：代表文件/目录的元数据
struct inode {
    unsigned long       i_ino;          // inode 编号
    umode_t             i_mode;         // 权限
    uid_t               i_uid;          // 属主
    loff_t              i_size;         // 文件大小
    const struct inode_operations  *i_op;
    const struct file_operations   *i_fop;
    struct super_block              *i_sb;
    struct address_space            *i_mapping;  // 页缓存
};

// dentry：目录项（路径缓存）
struct dentry {
    struct dentry       *d_parent;      // 父目录
    struct qstr         d_name;         // 文件名
    struct inode        *d_inode;       // 指向的 inode
    struct list_head    d_child;        // 兄弟链表
};

// file：进程打开的文件实例
struct file {
    const struct file_operations *f_op;  // 文件操作函数表
    struct path         f_path;         // 路径
    loff_t              f_pos;          // 读写偏移
    struct address_space *f_mapping;    // 页缓存映射
};
```

### file_operations：函数表实现多态

```c
struct file_operations {
    ssize_t (*read)    (struct file *, char __user *, size_t, loff_t *);
    ssize_t (*write)   (struct file *, const char __user *, size_t, loff_t *);
    int     (*open)    (struct inode *, struct file *);
    int     (*release) (struct inode *, struct file *);
    int     (*mmap)    (struct file *, struct vm_area_struct *);
    int     (*fsync)   (struct file *, loff_t, loff_t, int);
};

// 例：ramfs 的实现
const struct file_operations ramfs_file_operations = {
    .read   = ramfs_read,
    .write  = ramfs_write,
    .mmap   = ramfs_mmap,
};

// 例：ext4 的实现
const struct file_operations ext4_file_operations = {
    .read_iter  = ext4_file_read_iter,
    .write_iter = ext4_file_write_iter,
    .mmap       = ext4_file_mmap,
    .fsync      = ext4_fsync,
};
```

### 系统调用路径

```
read(fd, buf, 1024)
  → sys_read(fd, buf, 1024)          // 系统调用入口
    → vfs_read(file, buf, 1024)      // VFS 层（通用逻辑）
      → file->f_op->read(file, buf)  // 具体文件系统
        → ext4_file_read()           // ext4 实现
          → generic_file_read()      // 通用页缓存逻辑
```

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | MINIX 3 |
|------|------|-------|------|-----|---------|
| 内核层数 | 2-3 层 | 3 层（sys/VFS/FS） | 1 层（微内核） | 3 层（Core-0/P-1/App-3） | 4 层 |
| 层间通信 | 函数调用 | 直接函数调用 | IPC | 入口页自检（bt） | IPC |
| 跨层代价 | 低 | 函数调用开销 | IPC 200-500ns | 1.5-2.25ns | 5-50μs |

## 参考文献

- Linux kernel source: `include/linux/fs.h`, `fs/read_write.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.11 (VFS)
- "The Linux Virtual File System", Linux Journal 1996
- Dijkstra, "The Structure of the THE-Multiprogramming System", CACM 1968

> 对应书籍：第 52 章
