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

![屏幕截图 2026-02-14 160815](D:/dev/csapp/note/img/屏幕截图 2026-02-14 160815.png)

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

![](D:/dev/csapp/note/img/屏幕截图 2026-02-14 202157.png)

应该是必须按照"%d %d %s"格式输入后验证字符串是否与"DrEvil"相同，其中0x603870是第四题的输入串地址<input_strings+240>，因此在第四题后加上"DrEvil"即可进入secret_phase

### 解答

调用一个递归函数func7

```c
struct treeNode {
    int data;
    struct treeNode *left;
    struct treeNode *right;
};

int func7(struct treeNode *p, int v) {
    if (p == NULL) return -1;
    else if (v < p->data) return 2 *func7(p->left, v));
    else if (v == p->data) return 0;
    else return 2 * func7(p->right, v) + 1;
}
```

0x6030f0处的内存如下

```
              36
            /   \
          /       \
        /           \
      8               50
    /    \          /    \
   /      \        /      \
  6       22      45      107
 / \     /  \    /  \    /   \
1   7   20  35  40  47  99  1001
```

所以答案是22或者20