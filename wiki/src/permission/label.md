# 标签模型（MAC）

标签模型为每个主体和客体分配安全标签，通过策略规则判断访问是否允许。SELinux 是标签模型在 Linux 中的完整实现。

## 系统对比

| 方面 | 常规 MAC | SELinux | AppArmor | SMACK | TOMOYO |
|------|---------|--------|---------|-------|--------|
| 标签位置 | 主体/客体 inode | 扩展属性 `security.selinux` | 路径配置 | 扩展属性 | 进程执行历史 |
| 策略 | 全局规则 | 类型强制 (TE) + RBAC | 路径 + 能力 | 标签对规则 | 域 + 操作 |
| 默认行为 | 拒绝 | 拒绝 | 拒绝 | 拒绝 | 拒绝 |
| 内核组件 | — | `security/selinux/` | `security/apparmor/` | `security/smack/` | `security/tomoyo/` |

## SELinux 实现

### 安全上下文格式

```
user:role:type:level
  ↑    ↑    ↑     ↑
 用户  角色  类型  多级安全 (MLS)

示例：system_u:object_r:httpd_sys_content_t:s0
```

每个进程和文件都有一个安全上下文，存储在 inode 的扩展属性 `security.selinux` 中。

### AVC (Access Vector Cache)

```c
// security/selinux/avc.c — 权限检查缓存
struct avc_entry {
    u16         ssid;       // 主体 SID
    u16         tsid;       // 客体 SID
    u16         tclass;     // 客体类别
    struct av_decision  avd;
};

int avc_has_perm(u32 ssid, u32 tsid, u16 tclass, u32 requested,
                 struct avc_entry_ref *aeref, void *auditdata) {
    // 1. 查 AVC 缓存
    // 2. 未命中 → security_compute_av() 策略查找
    // 3. 写入缓存
    // 4. 检查 allowed & requested
    // 5. 拒绝则 avc_audit()
}
```

### LSM 钩子

```c
// security/selinux/hooks.c
static int selinux_file_open(struct file *file, const struct cred *cred) {
    struct inode *inode = file_inode(file);
    u32 sid = cred_sid(cred);
    return avc_has_perm(sid, isec->sid, isec->sclass,
                        FILE__OPEN, NULL, NULL);
}
```

## AppArmor 实现

按程序路径配置权限，不需文件系统标签：

```
/etc/apparmor.d/usr.sbin.nginx:
  /usr/sbin/nginx {
    /etc/nginx/* r,
    /var/log/nginx/* w,
    network inet stream,
  }
```

## 参考文献

- Linux kernel source: `security/selinux/avc.c`, `security/selinux/hooks.c`
- Linux kernel source: `security/apparmor/`, `security/smack/`
- "Understanding the Linux Kernel", 3rd Ed., Ch.8
- SELinux Notebook (selinuxproject.github.io)

> 对应书籍：第 11 章、第 18 章
