# 最小权限原则

**最小权限原则**（Principle of Least Privilege）由 Saltzer 和 Schroeder 在 1975 年的经典论文中提出，是安全系统设计的核心原则之一。

## 定义

> 系统中的每个程序和每个用户都应只使用完成其任务所必需的最小权限集合。

## 实现方式

### Linux Capabilities

Linux 将 root 的全权限拆分为约 40 个独立的能力单元。进程可以持有其任务所需的最小能力集。

**示例：** ping 需要原始套接字能力：

```bash
sudo setcap cap_net_raw+ep /bin/ping
```

### seL4 的 Mint 操作

seL4 通过 Mint（铸造）操作从现有能力派生出权限子集。父能力可以派生出只读子能力，子能力不能超出父能力的权限范围。

### HIC 的能力衰减

HIC 的能力系统允许从现有能力派生出权限子集，新能力继承原能力的部分权限，原能力不受影响。

## 挑战

- **确定"最小"困难**：复杂系统中难以精确判断所需权限
- **动态性**：程序在不同阶段需要不同权限集
- **安全性与可用性的张力**：权限过严影响用户体验

> 对应书籍：第 19 章  
> 参考文献：Saltzer & Schroeder, "The Protection of Information in Computer Systems", 1975
