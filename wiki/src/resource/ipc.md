# 进程间通信 (IPC)

IPC 是模块间连接的核心方式，不同内核的 IPC 机制差异显著。

## 系统对比

| 方面 | 常规 | Linux | seL4 | HIC | QNX | MINIX 3 |
|------|------|-------|------|-----|------|---------|
| 基础原语 | 消息队列 | pipe/socket/FIFO | Send/Recv/Call | 入口页 bt 自检 | Send/Receive/Reply | IPC sendrec |
| 同步模型 | 阻塞 | 阻塞/非阻塞 | 同步 IPC | 同步（入口页） | 同步 + 异步脉冲 | 同步 |
| 数据传递 | 内核拷贝 | 内核拷贝 | 寄存器 + IPC 缓冲区 | 寄存器/共享内存 | 零拷贝共享内存 | 内核拷贝 |
| 跨节点 | 网络栈 | TCP/IP | 无原生 | 无原生 | 透明网络代理 | 无 |
| 延迟 | 微秒级 | 50-100ns (pipe) | 200-500ns | 1.5-2.25ns | 5-15μs | 5-50μs |

## Linux Pipe 实现

```c
// fs/pipe.c — 管道读写
struct pipe_inode_info {
    struct pipe_buffer *bufs;     // 环形缓冲区
    unsigned int head;            // 写位置
    unsigned int tail;            // 读位置
    unsigned int max_usage;
    wait_queue_head_t wait;       // 等待队列
};

// 写端：数据写入环形缓冲区，唤醒读者
static ssize_t pipe_write(struct kiocb *iocb, struct iov_iter *from) {
    struct pipe_inode_info *pipe = filp->private_data;
    struct pipe_buffer *buf;

    head = pipe->head;
    buf = &pipe->bufs[head & mask];
    buf->page = page;
    buf->len = copied;
    pipe->head = head + 1;

    wake_up_interruptible(&pipe->wait);   // 唤醒读者
    return copied;
}
```

## seL4 同步 IPC

seL4 的 IPC 由内核完全管理，Send + Call 是阻塞的：

```c
// seL4_Send 发送后阻塞直到被接收
// seL4_Call 发送后阻塞直到收到回复（RPC 语义）
// seL4_Wait 阻塞直到收到消息

// IPC 缓冲区（寄存器传入）
typedef struct seL4_IPC_Message {
    seL4_Word label;         // 消息标签
    seL4_Word caps[2];       // 最多 2 个能力引用
    seL4_Word words[120];    // 最多 120 字数据
} seL4_IPC_Message;
```

## HIC IPC 3.0

HIC IPC 3.0 将跨域调用收敛为 `call + bt + jmp`，热路径无内核介入：

```asm
// 入口页自检（位于独立 4KB 页，调用者映射为 RX）
bt  [bitmap], ecx      ; ecx = 硬件域 ID (GS.base)
jnc .fail              ; 未授权 → ud2 陷阱
jmp [real_service]     ; 跨页跳转至业务页
```

## 参考文献

- Linux kernel source: `fs/pipe.c`, `net/ipv4/tcp.c`
- "Understanding the Linux Kernel", 3rd Ed., Ch.16 (IPC)
- seL4 Manual, §2.3 IPC
- HIC IPC 3.0 设计文档

> 对应书籍：第 56 章
