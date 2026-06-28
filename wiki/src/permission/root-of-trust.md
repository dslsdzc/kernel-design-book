# 信任锚

信任锚（Root of Trust）是访问控制系统中权限链条的起点——一个被假定为不可篡改的权威实体，所有信任关系都从它开始衍生。

## 信任链模型

```
硬件信任锚 → 启动ROM → 引导加载程序 → 内核 → init → 服务
    ↓           ↓           ↓           ↓      ↓      ↓
  不可篡改     验证签名     验证签名    验证签名 验证  持有能力
```

每个环节验证下一个环节的数字签名后移交控制权，形成逐级验证的链条。

## 系统对比

| 方面 | 常规 | Linux (IMA) | seL4 | HIC | CHERI |
|------|------|-------------|------|-----|-------|
| 信任锚 | 硬件 Root of Trust (RoT) | TPM PCR 度量 | bootloader 初始化能力 | Core-0 硬件信任根 | CPU 初始能力寄存器 |
| 度量方式 | 哈希度量 | IMA 完整性度量 | 形式化验证 | 能力树继承 | 硬件标签位 |
| 启动验证 | Secure Boot | IMA + EVM | 验证 bootloader | 能力表静态初始化 | 硬件强制 |
| 策略 | 固定信任链 | IMA 策略 LSM | 形式化证明 | 能力派生树 | 单调递减 |

## HIC 信任链实现

```c
// src/Core-0/trust_root.c — HIC 信任根
void trust_root_init(void) {
    // Core-0 从硬件信任锚获得最高特权
    // Privileged-1 服务启动时只获得极小初始能力集

    // 为 Core-0 域初始化密钥
    g_domain_keys[HIC_DOMAIN_CORE].seed = 0x12345678;
    g_domain_keys[HIC_DOMAIN_CORE].multiplier = 0x9E3779B9;

    // 初始化能力表，Core-0 持有全部能力
    boot_capabilities_init();
}

// 能力继承规则：每个能力的来源可回溯到更高权威
// 所有授权的起点收敛于 Core-0
// Core-0 的能力由硬件信任锚保证
```

## 参考文献

- TCG Trusted Platform Module Specification, "TPM 2.0 Library"
- Linux kernel source: `security/integrity/ima/`
- seL4 Manual, §2.4 Bootup
- CHERI ISA Specification, "Root of Trust"

> 对应书籍：第 74 章
