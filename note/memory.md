# 内存层次结构 (Memory Hierarchy)

## 1. 存储技术 (Storage Technologies)

### 随机访问存储器 (RAM)
RAM 分为两类：静态 RAM (SRAM) 和动态 RAM (DRAM)。

*   **SRAM (Static RAM)**:
    *   **更极**: 速度快，价格贵，功耗高。
    *   **结构**: 每个位存储在一个双稳态存储器单元中（通常是 6 个晶体管）。
    *   **用途**: 用于 CPU 高速缓存 (Cache L1, L2, L3)。
    *   **特性**: 只要有电，数据就会保持，不需要刷新。对干扰不敏感。

*   **DRAM (Dynamic RAM)**:
    *   **更极**: 速度较慢，价格便宜，密度高。
    *   **结构**: 每个位存储为电容上的电荷（1 个晶体管 + 1 个电容）。
    *   **用途**: 用于主存 (Main Memory)。
    *   **特性**: 对干扰非常敏感。电荷会泄漏，需要通过内存控制器定期**刷新** (Refresh)。

### 非易失性存储器 (Non-volatile Memory)
断电后数据依然存在。
*   **ROM (Read-Only Memory)**: 只读存储器。
*   **Flash Memory (闪存)**: 电可擦除可编程 ROM (EEPROM) 的一种。用于 SSD, USB 驱动器。
*   **Firmware (固件)**: 存储在 ROM 中的程序（如 BIOS）。

### 磁盘存储 (Disk Storage)
*   **机械硬盘 (HDD)**:
    *   **结构**: 盘片 (Platter), 表面 (Surface), 磁道 (Track), 扇区 (Sector), 柱面 (Cylinder)。
    *   **访问时间** = 寻道时间 (Seek time) + 旋转延迟 (Rotational latency) + 传输时间 (Transfer time)。
    *   寻道时间通常是瓶颈。

*   **固态硬盘 (SSD)**:
    *   基于闪存技术。
    *   **优点**: 无移动部件，读写速度快，随机访问性能好，能耗低。
    *   **缺点**: 随着写操作次数增加，闪存块会磨损。

## 2. 局部性 (Locality)

程序倾向于引用**最近引用过的数据项**，或者**邻近的数据项**。这是硬件和软件优化的基础。

*   **时间局部性 (Temporal Locality)**:
    *   如果一个内存位置被引用，它很可能在不久的将来再次被引用。
    *   例子：循环中的变量 `sum`。
*   **空间局部性 (Spatial Locality)**:
    *   如果一个内存位置被引用，由于程序很可能引用其附近的内存位置。
    *   例子：按顺序遍历数组。

**编写局部性良好的代码**:
*   重复引用相同的变量（时间局部性）。
*   步长为 1 的引用模式（stride-1 reference pattern）访问数组（空间局部性）。
*   对于二维数组 `a[N][N]`，使用 `a[i][j]` (按行) 访问比 `a[j][i]` (按列) 访问快得多，因为 C 数组按行存储，这最大化了空间局部性。

## 3. 存储器层次结构 (The Memory Hierarchy)

计算机系统使用不同技术、不同容量、不同速度的存储设备组成一个层次结构。

*   **L0**: 寄存器 (Registers) - CPU 内部，最快，容量最小。
*   **L1**: L1 Cache (SRAM) - 几周期访问。
*   **L2**: L2 Cache (SRAM).
*   **L3**: L3 Cache (SRAM).
*   **L4**: 主存 (Main Memory - DRAM) - 几百周期访问。
*   **L5**: 本地二级存储 (Local Secondary Storage - Disk/SSD) - 几百万周期访问。
*   **L6**: 远程二级存储 (Remote Secondary Storage - Distributed Systems, Web Servers)。

**核心思想**:
*   层次结构中的每一层都是下一层（更慢、更大）的**缓存 (Cache)**。
*   数据以**块 (Block)** 为单位在层级之间传输。

---

# 高速缓存 (Cache Memories)

## 1. 通用缓存组织结构 (General Cache Organization)

一个计算机系统的缓存被组织成 $S$ 个**组 (Cache Sets)** 的数组。
每个组包含 $E$ 个**行 (Cache Lines)**。
每个行包含一个 $B$ 字节的**数据块 (Block)**。
此外，每个行还有一个**有效位 (Valid bit)** 和 **标记位 (Tag bits)**。

地址被划分为三部分（从高位到低位）：
1.  **Tag (标记)**: $t$ 位。用于标识组内匹配的行。
    *   如果 Tag 匹配且 Valid=1，则缓存**命中 (Hit)**。
2.  **Set Index (组索引)**: $s$ 位。用于选择组 ($S = 2^s$)。
3.  **Block Offset (块偏移)**: $b$ 位。用于选择块内的字节 ($B = 2^b$)。

缓存总数据容量 $C = S \times E \times B$。

## 2. 缓存分类

### 直接映射缓存 (Direct Mapped Cache)
*   **$E = 1$**: 每个组只有一行。
*   **冲突不命中 (Conflict Miss)**: 即使缓存有空闲空间，如果多个活跃对象映射到同一个组（即它们的 Set Index 相同），它们会互相驱逐。
    *   例如：如果是 2 的幂次大小的数组，很容易发生这种冲突。
*   **查找过程**:
    1.  用 Set Index 找到唯一的行。
    2.  检查 Valid 位和 Tag 是否匹配。

### 组相联缓存 (Set Associative Cache)
*   **$1 < E < C/B$**: 每个组有多行（例如 2-way, 4-way, 8-way）。
*   需要匹配组内的 Tag。
*   大大减少了冲突不命中。
*   **查找过程**:
    1.  用 Set Index 找到组。
    2.  在组内的 E 行中并行搜索 Tag。

### 全相联缓存 (Fully Associative Cache)
*   **$S = 1, E = C/B$**: 只有一个组，包含所有行。
*   没有组索引，地址只分为 Tag 和 Offset。
*   非常昂贵，通常只用于极其重要的缓存（如 TLB - Translation Lookaside Buffer），因为需要并行比较所有行的 Tag。

## 3. 缓存写策略 (Writes)

### 写命中 (Write Hit)
1.  **Write-through (直写)**: 立即将数据写回低一层存储器。
    *   优点：简单，低一层始终包含最新数据。
    *   缺点：每一次写都会导致总线流量，可能会造成瓶颈。
2.  **Write-back (回写)**: 只有当该行被驱逐 (evicted) 时才写回低一层。
    *   需要一个 dirty bit 来记录该块是否被修改过。
    *   优点：显著减少总线流量。

### 写不命中 (Write Miss)
1.  **Write-allocate (写分配)**: 将块加载到缓存中，然后更新。
    *   通常与 Write-back 搭配。
    *   利用空间局部性（如果你写了它，你可能很快会读它）。
2.  **No-write-allocate (非写分配)**: 直接写入低一层存储器，不加载到缓存。
    *   通常与 Write-through 搭配。

**典型搭配**:
*   Write-through + No-write-allocate
*   Write-back + Write-allocate (现代 CPU 常用)。

## 4. 缓存性能指标

*   **命中率 (Hit Rate)**: 命中次数 / 总访问次数。
    *   即使 99% 的命中率也是不够的，因为不命中的代价非常高。
*   **不命中率 (Miss Rate)**: 1 - Hit Rate。
*   **命中时间 (Hit Time)**: 从缓存传递一个字到 CPU 所需时间。
    *   L1 cache: 1-4 个时钟周期。
*   **不命中惩罚 (Miss Penalty)**: 由于不命中所需的额外时间（从主存加载）。
    *   Main Memory: 50-200 个时钟周期。

**平均内存访问时间 (AMAT)**:
$AMAT = T_{hit} + (Miss Rate \times T_{miss\_penalty})$

## 5. 编写缓存友好的代码 (Writing Cache Friendly Code)

1.  **关注核心循环**: 大部分时间花在少数循环上。
2.  **让常见情况运行得快**: 优化最内层循环。
3.  **减少不命中**:
    *   **重复使用变量**: 编译器会将其放入寄存器。
    *   **按内存存储顺序访问**: 行优先遍历二维数组（C 语言中 `a[i][j]` 是行优先，`j` 变化最快时步长为 1，利用了空间局部性）。
4.  **分块 (Blocking)**:
    *   对于矩阵乘法等操作，将数据分成能装入 L1 缓存的小块，以提高时间局部性。
    *   这是一种通过改变内存访问模式来提高局部性的通用技术。
