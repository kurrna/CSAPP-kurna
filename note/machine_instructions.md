# 机器指令与程序优化

## x86汇编

#### **寄存器**

- 六个寄存器(%rax, %rbx, %rcx, %rdx, %rsi, %rdi)称为通用寄存器，有其『特定』的用途：

  - %rax(%eax) 用于做累加

  - %rcx(%ecx) 用于计数

  - %rdx(%edx) 用于保存数据
  - %rbx(%ebx) 用于做内存查找的基础地址

  - %rsi(%esi) 用于保存源索引值

  - %rdi(%edi) 用于保存目标索引值

- %rsp(%esp) 和 %rbp(%ebp) 则是作为栈指针和基指针来使用的。

- 函数调用中会利用%rax来保存过程调用的返回值；过程调用的参数若不超过六个，那么会放在：%rdi, %rsi, %rdx, %rcx, %r8,%r9中，若超过了，会放在另外一个栈中。

#### **寻址**

 `D(Rb, Ri, S)` -> `Mem[Reg[Rb]+S*Reg[Ri]+D]`，其中：

- `D` - 常数偏移量
- `Rb` - 基寄存器
- `Ri` - 索引寄存器，不能是 `%rsp`
- `S` - 系数

除此之外，还有如下三种特殊情况

- `(Rb, Ri)` -> `Mem[Reg[Rb]+Reg[Ri]]`
- `D(Rb, Ri)` -> `Mem[Reg[Rb]+Reg[Ri]+D]`
- `(Rb, Ri, S)` -> `Mem[Reg[Rb]+S*Reg[Ri]]`

#### **常用指令**(AT&T格式)

- `leaq Src, Dest`：将Src地址表达式计算的结果存入Dest中
  - `leaq (%rdi, %rdi, 2), %rax`对%rdi寄存器中存的数据进行计算，然后赋值给%rax
- `addq Src, Dest`：`Dest = Dest + Src`
- `subq Src, Dest`：`Dest = Dest - Src`
- `imulq Src, Dest`：`Dest = Dest * Src`
- `salq Src, Dest`：`Dest = Dest << Src`
- `sarq Src, Dest`：`Dest = Dest >> Src` # 算术右移 补符号位
- `shrq Src, Dest`：`Dest = Dest >> Src` # 逻辑右移 全部补0
- `xorq Src, Dest`：`Dest = Dest ^ Src`
- `andq Src, Dest`：`Dest = Dest & Src`
- `orq Src, Dest`：`Dest = Dest | Src`
- `incq Dest`：`Dest = Dest + 1`
- `decq Dest`：`Dest = Dest - 1`
- `negq Dest`：`Dest = -Dest`
- `notq Dest`：`Dest = ~Dest`

## 流程控制

寄存器中存储着当前正在执行的程序的相关信息：

- 临时数据存放在(%rax, ...)
- 运行时栈的地址存储在(%rsp)中
- 目前的代码控制点存储在(%rip, ...)中（即指令指针，PC）
- 目前测试的状态放在CF，ZF，SF，OF（条件代码）

### **条件代码与跳转**

#### **条件代码**

四个标识位（CF，ZF，SF，OF）是用来辅助程序的流程控制的，意思是：

- CF：Carry Flag（针对无符号数）
- ZF：Zero Flag
- SF：Sign Flag（针对有符号数）
- OF：Overflow Flag（针对有符号数）

这四个条件代码是用来标记上一条命令的结果的各种可能的，在命令执行时自动进行设置，称为隐式设置（使用`leaq`指令的话不会进行设置）

除了隐式设置，还可以使用`cmpq`进行显示设置：`cmpq Src2(b), Src1(a)`等同于计算`a-b`，然后利用`a-b`的结果来对应进行条件代码的设置

或者`testq Src2(b), Src1(a)`，等同于计算`a&b`然后利用其结果进行条件代码的设置

- 如果在最高位还需要进位，设置CF
- 结果等于0，设置ZF
- 结果小于0，设置SF
- 如果2进制补码移除，设置OF

#### **跳转**

根据条件代码的不同来进行不同的操作

| instr   | 效果               | instr | 效果                        |
| ------- | ------------------ | ----- | --------------------------- |
| jmp     | Always jump        | ja    | Jump if above(`unsigned >`) |
| je/jz   | Jump if eq/zero    | jae   | Jump if above/equal         |
| jne/jnz | Jum if neq/nzero   | jb    | Jump if below(`unsigned <`) |
| jg      | Jump if greater    | jbe   | Jump if below/equal         |
| jge     | Jump if greater/eq | js    | Jump if sign bits is 1(neg) |
| jl      | Jump if less       | jns   | Jump if sign bit is 0(pos)  |
| jle     | Jump if less/eq    |       |                             |

#### **循环**

先来看看并不那么常用的 Do-While 语句以及对应使用 goto 语句进行跳转的版本：

```c
// Do While 的 C 语言代码
long pcount_do(unsigned long x)
{
    long result = 0;
    do {
        result += x & 0x1;
        x >>= 1;
    } while (x);
    return result;
}

// Goto 版本
long pcount_goto(unsigned long x)
{
    long result = 0;
loop:
    result += x & 0x1;
    x >>= 1;
    if (x) goto loop;
    return result;
}
```

这个函数计算参数 x 中有多少位是 1，翻译成汇编如下：

```asm
    movl    $0, %eax    # result = 0
.L2:                    # loop:
    movq    %rdi, %rdx
    andl    $1, %edx    # t = x & 0x1
    addq    %rdx, %rax  # result += t
    shrq    %rdi        # x >>= 1
    jne     .L2         # if (x) goto loop
    rep; ret
```

其中 %rdi 中存储的是参数 x，%rax 存储的是返回值。换成更通用的形式如下：

```c
// C Code
do
	Body
	while (Test);

// Goto Version
loop:
	Body
	if (Test)
		goto loop
```

而对于 While 语句的转换，会直接跳到中间，如：

```c
// C While version
while (Test)
	Body

// Goto Version
	goto test;
loop:
	Body
test:
	if (Test)
		goto loop;
done:
```

如果在编译器中开启 `-O1` 优化，那么会把 While 先翻译成 Do-While，然后再转换成对应的 Goto 版本，因为 Do-While 语句执行起来更快，更符合 CPU 的运算模型。

接着来看看最常用的 For 循环，也可以一步一步转换成 While 的形式，如下

```c
// For
for (Init; Test; Update)
	Body
	
// While Version
Init;
while (Test) {
	Body
	Update;
}
```

### Switch 语句

最后我们来看看最复杂的 switch 语句，这种类型的语句一次判断会有多种可能的跳转路径（知道 CPU 的分支预测会多抓狂吗）。这里用一个具体的例子来进行讲解：

```c
long switch_eg (long x, long y, long z){
	long w = 1;
	switch (x) {
		case 1:
			w = y*z;
			break;
		case 2:
			w = y/z;
			// fall through
		case 3:
			w += z;
			break;
		case 5:
		case 6:
			w -= z;
			break;
		default:
			w = 2;
	}
	return w;
}
```

这个例子中包含了大部分比较特殊的情况：

- 共享的条件：5 和 6
- fall through：2 也会执行 3 的部分（这个要小心，一般来说不这么搞，如果确定要用，务必写上注释）
- 缺失的条件：4

具体怎么办呢？简单来说，使用跳转表（你会发现表的解决方式在很多地方都有用：虚函数，继承甚至动态规划），可能会类似如下汇编代码，这里 %rdi 是参数 x，%rsi 是参数 y，%rdx 是参数 z, %rax 是返回值

```asm
switch_eg:
    movq    %rdx, %rcx
    cmpq    $6, %rdi    # x:6
    ja      .L8
    jmp     *.L4(, %rdi, 8)
```

跳转表为

```asm
.section    .rodata
    .align 8
.L4:
    .quad   .L8 # x = 0
    .quad   .L3 # x = 1
    .quad   .L5 # x = 2
    .quad   .L9 # x = 3
    .quad   .L8 # x = 4
    .quad   .L7 # x = 5
    .quad   .L7 # x = 6
```

这里需要注意，我们先跟 6 进行比较（因为 6 是最大的），然后利用 `ja` 指令进行跳转，为什么，因为如果是负数的话，`ja` 是处理无符号数的，所以负数情况肯定大于 6，于是直接利用 `ja` 跳转到 default 的分支。

然后下一句 `jmp *.L4(,%rdi, 8) # goto *JTab[x]`，是一个间接跳转，通过看上面的跳转列表来进行跳转。

比如说，直接跳转 `jmp .L8`，就直接跳到 `.L8` 所在的标签，也就是 x = 0

如果是 `jmp *.L4(,%rdi,8)` 那么就先找到 `.L4` 然后往后找 8 个字节（或 8 的倍数），于是就是 0~6 的范围。

通过上面的例子，我们可以大概了解处理 switch 语句的方式：大的 switch 语句会用跳转表，具体跳转时可能会用到决策树（if-elseif-elseif-else）

## 过程调用（函数调用）

涉及三个方面：

1. 传递控制：包括如何开始执行代码，以及如何返回到开始的地方
2. 传递数据：包括过程需要的参数以及过程的返回值
3. 内存管理：如何再过程执行的时候分配内存，以及在返回之后释放内存

### 栈结构

越新入栈的数据地址越低，栈顶地址最小

对于`pushq Src`指令：1. 从地址`Src`中取出操作数；2. 把%rsp中的地址减去8（也就是到下一个位置）；3. 把操作数写入到%rsp的新地址中

对于`popq Dest`指令：1. 从%rsp中存储的地址中读入数据；2. 把%rsp中的地址增加8（回到上一个位置）；3. 把刚才取出来的值放到`Dest`中（必须是寄存器）

### 调用方式

通过`callq label`来进行调用（先把返回地址入栈，然后跳转到对应的label），返回的地址是下一条指令的地址，通过`retq`来进行返回（把地址从栈中弹出，然后跳转到对应地址）

函数调用中会利用%rax来保存过程调用的返回值；过程调用的参数若不超过六个，那么会放在：%rdi, %rsi, %rdx, %rcx, %r8,%r9中，若超过了，会放在另外一个栈中。

对于每一个过程调用，都会在栈中分配一个帧Frames，每一帧中需要包含：

- 返回信息
- 本地存储（如果需要）
- 临时空间（如果需要）

每个栈帧会在过程调用的时候进行空间分配，然后再返回时进行回收，在x64中，当前要执行的栈中包括：

- 需要使用的参数
- 如果不能保存在寄存器中，会把一些本地变量放在这里
- 已保存的寄存器上下文
- 老的栈帧的指针

而调用者的栈帧包括：

- 返回地址（因为`call`指令被压入栈中的）
- 调用所需的参数

### 数据存储

| 数据类型    | 32位 | 64位 | x86-64 |
| ----------- | ---- | ---- | ------ |
| char        | 1    | 1    | 1      |
| short       | 2    | 2    | 2      |
| int         | 4    | 4    | 4      |
| long        | 4    | 8    | 8      |
| float       | 4    | 4    | 4      |
| double      | 8    | 8    | 8      |
| long double | -    |      |        |

### 结构体

设计结构体时由于对齐的要求要将大的数据类型放在前面

## 缓存区溢出

通过栈溢出来修改另一个程序的内存

## 程序优化

**算法**

**代码移动**

**减少计算强度**

**公共子表达式**

**小心过程调用**

**注意内存问题**

**处理条件分支**

# Bomb lab

学到了不少gdb的操作和x86汇编的皮毛

## phase_1

从内存中读一个字符串

## phase_2

循环，从小到大输入6个2的幂即可

## phase_3

switch-case，好像有多个答案，随便写了一个

## phase_4

目前最复杂的一个，二分搜索，下半部分返回`2*$eax`，上部分返回`2*$eax+1`，mid返回0，找0到14之间能返回0的数字，可能是0，1，3，7

## phase_5

通过一个数组来给输入的字符串加密，最后加密后的字符串为"flyers"

加密数组是char[16] = "maduiersnfotvbyl"，索引是input[i] & 0xf

所以只需要凑出"flyers"就行了，索引是：9->f->e->5->6->7

答案为

| 1    | 2    | 3    | 4    | 5    | 6    |
| ---- | ---- | ---- | ---- | ---- | ---- |
| i或y | o    | n    | e或u | f或v | g或w |

## phase_6

更复杂了，这次还有结构体和栈上数组，我根本看不懂在干啥

尝试输入`1 2 3 4 5 6`

![屏幕截图 2026-02-14 160815](.\img\屏幕截图 2026-02-14 160815.png)

因此为类似以下的结构体

```c
struct Node {
    int val;
    int order;
    node *next;
} node;
```

| value | 0x14c | 0x0a8 | 0x39c | 0x2b3 | 0x1dd | 0x1bb |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| 大小  | 5th   | 6th   | 1st   | 2nd   | 3rd   | 4th   |

要求处理后的数组为递减，因此答案为7 - (3 4 5 6 1 2) = 4 3 2 1 6 5

phase_6的大概流程为：

1. 输入六个数字`4 3 2 1 6 5`并校验有效性（范围1<=x<=6，且互不重复）
2. input[i] = 7 - input[i]，处理后为`3 4 5 6 1 2`
3. 按照input[i]将对应结构体对象存在栈上数组中
4. 按照`3 4 5 6 1 2`的顺序将结构体相连，这一步后结构体对象的order变成降序，变为环状
5. 检查处理过的链表是否递减

## phase_secret

>  在做phase_5的时候不小心使用x/s 0x402450得到了"secret stage!"，把内存dump下来才发现是0x402438的"Wow! You've defused the secret stage!"，我还以为我自己找到了secret stage（

### 入口

在phase_defused函数中调用了secret_phase，在前面的汇编中出现了0x402619, 0x603870, 0x402622, 0x4024f8, 0x402520等地址，逐个查看

![](.\img\屏幕截图 2026-02-14 202157.png)

应该是必须按照"%d %d %s"格式输入后验证字符串是否与"DrEvil"相同，其中0x603870是第四题的输入串地址<input_strings+240>，因此在第四题后加上"DrEvil"即可进入secret_phase

### 解答