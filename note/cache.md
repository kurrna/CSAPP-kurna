# 高速缓存 (Cache) 笔记

本文基于 [【读薄 CSAPP】叁 内存与缓存](https://www.wdxtub.com/blog/csapp/thin-csapp-3) 整理，并补充了计算机组成原理与操作系统相关知识点。

## 1. 存储体系与局部性原理

### 1.1 存储技术概览

* **RAM**:
  * **SRAM (静态)**: 快、贵、无需刷新、抗干扰。用于 CPU Cache (L1/L2/L3)。
  * **DRAM (动态)**: 慢、便宜、需刷新(电容漏电)。用于主存 (Main Memory)。
* **磁盘 (Disk)**:
  * **HDD (机械硬盘)**: 盘片(Platter)、磁道(Track)、扇区(Sector)。
    * 访问时间 = 寻道时间 (Seek) + 旋转延迟 (Rotation) + 传输时间 (Transfer)。
    * 瓶颈在于机械运动 (ms 级)，比 RAM 慢 10^5 倍以上。
  * **SSD (固态硬盘)**: 基于 Flash，无机械部件。读写快，但存在**写入放大**和**磨损**问题 (Block 擦除)。

### 1.2 局部性原理 (Locality)

* **时间局部性 (Temporal Locality)**: 最近访问过的数据很可能再次被访问 (e.g., 循环变量)。
* **空间局部性 (Spatial Locality)**: 地址临近的数据很可能被访问 (e.g., 数组遍历)。
  * **优化技巧**: 多维数组按**行优先** (C语言) 遍历；利用**分块 (Blocking)** 技术提高局部性。

### 1.3 存储体系金字塔

利用局部性，将更快、更小的存储设备作为更大、更慢设备的**缓存**。

* 寄存器 -> L1/L2/L3 Cache (SRAM) -> 主存 (DRAM) -> 本地磁盘 -> 远程存储（分布式系统，web服务器）。

---

## 2. 硬件缓存架构

### 2.1 缓存结构参数

缓存被组织成 $S$ 个**组 (Set)**，每个组包含 $E$ 个**行 (Line)**，每行包含 $B$ 字节的**块 (Block)**。

* **容量 (Capacity)**: $C = S \times E \times B$
* **地址划分**:
  * **Tag (标记)**: 用于匹配。
  * **Set Index (组索引)**: 定位组 ($S = 2^s$)。
  * **Block Offset (块偏移)**: 定位数据 ($B = 2^b$)。

### 2.2 映射策略 (Mapping Policies)

1. **直接映射 (Direct Mapped)** ($E=1$):
   * 每个地址只能映射到唯一的组和唯一的行。
   * **冲突**严重：若两个活跃变量映射到同一 Set，会不断发生冲突不命中 (Thrashing)。
2. **组相联 (Set Associative)** ($1 < E < C/B$):
   * 每个地址映射到唯一的组，但可以放在组内的任意 $E$ 行中。
   * 减少了冲突不命中，但硬件成本增加 (需并行比较 Tag)。
3. **全相联 (Fully Associative)** ($S=1$):
   * 任意块可以放在任意行。只用于小容量的高级缓存 (如 TLB)。

### 2.3 缓存未命中类型 (The 3 C's)

1. **强制性 (Compulsory/Cold)**: 数据第一次被访问，必然不命中。
2. **冲突性 (Conflict)**: 映射到同一组的数据超过了关联度 $E$ (主要发生在直接映射或低关联度缓存)。
3. **容量性 (Capacity)**: 工作集 (Working Set) 大小超过了缓存总容量。

### 2.4 替换策略 (Replacement Policies)

当组满时，需要驱逐一行：

* **LRU (Least Recently Used)**: 替换最久未使用的。需要硬件维护时间戳或链表，开销大。
* **LFU (Least Frequently Used)**: 替换访问频率最低的。
* **Random**: 随机替换。硬件实现简单，性能在某些场景下出人意料地好。

### 2.5 写策略 (Write Policies)

| 场景                 | 策略 A (简单/高一致性)                                                  | 策略 B (高性能)                                                                |
| :------------------- | :---------------------------------------------------------------------- | :----------------------------------------------------------------------------- |
| **Write Hit**  | **Write-through (直写)**: 同时写 Cache 和 Memory。                | **Write-back (回写)**: 只写 Cache，设 Dirty Bit。被驱逐时才写回 Memory。 |
| **Write Miss** | **No-write-allocate (非写分配)**: 直接写 Memory，不加载到 Cache。 | **Write-allocate (写分配)**: 先读入 Cache，再写入。                      |
| **常见组合**   | Write-through + No-write-allocate                                       | Write-back + Write-allocate (现代 CPU 主流)                                    |

---

## 3. 操作系统与缓存 (OS & Cache Integration)

### 3.1 虚拟内存与缓存 (Virtual Memory & Cache)

CPU 发出的地址是**虚拟地址 (VA)**，而缓存可以使用 VA 或物理地址 (PA) 索引。

1. **TLB (Translation Lookaside Buffer)**:

   * **页表的高速缓存**。
   * 全相联结构，用于加速 VA 到 PA 的转换。
   * **OS 职责**: 进程切换 (Context Switch) 时，如果 ASID (Address Space ID) 不支持，可能需要**冲刷 (Flush) TLB**。
2. **物理缓存 (PIPT - Physically Indexed, Physically Tagged)**:

   * 先通过 TLB 转换成 PA，再查 Cache。
   * 优点：简单，无别名问题 (Aliasing)。
   * 缺点：速度慢 (需等待 TLB)。
3. **虚拟缓存 (VIVT - Virtually Indexed, Virtually Tagged)**:

   * 直接用 VA 查 Cache。
   * 优点：速度极快。
   * 缺点：
     * **别名 (Aliasing)**: 不同 VA 映射到同一 PA，导致多份数据副本。
     * **安全**: 进程切换需冲刷 Cache (除非有 PID 标记)。
4. **VIPT (Virtually Indexed, Physically Tagged)**:

   * 现代 CPU 主流方案。
   * 并行查找：利用 Page Offset 不变的特性，用 VA 的 Index 查找 Set，同时查 TLB 获取 PA 的 Tag 进行比对。

### 3.2 软件层面的缓存

操作系统利用未使用的 RAM 作为磁盘数据的缓存。

1. **Page Cache (页缓存)**:

   * Linux 内核会将读写的文件页缓存在内存中。
   * **mmap**: 内存映射文件直接通过 Page Cache 操作。
   * **Write-back**: OS 并不立即将数据写回磁盘，而是由 `pdflush` 线程定期回写 (或调用 `fsync`)。
2. **Buffer Cache (块缓存)**:

   * 早期 Linux 用于缓存磁盘块 (元数据、superblock 等)。现在大多已与 Page Cache 合并。
3. **Swap (交换空间)**:

   * 从某种意义上说，主存是磁盘的缓存。当内存不足时，OS 将不活跃的页置换 (Swap out) 到磁盘，腾出空间。

### 3.3 缓存一致性 (Cache Coherence)

在多核系统中，OS 和硬件需要共同维护一致性。

* **总线窥探 (Bus Snooping) / MESI 协议**: 硬件自动处理多核 L1/L2 间的数据一致性。
* **DMA 一致性**: 当设备 (如网卡) 通过 DMA 直接读写内存时，可能绕过 CPU Cache。OS 需要在 DMA 传输前后执行 **Cache Flushing** 或 **Invalidation** 操作，或者使用如果不缓存 (Uncached) 的内存区域。
