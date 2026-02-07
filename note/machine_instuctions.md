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

#### **常用指令**

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