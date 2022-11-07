
bin/kernel_nopage：     文件格式 elf32-i386


Disassembly of section .text:

00100000 <kern_entry>:
#而且临时建立了一个段映射关系，为之后建立分页机制的过程做一个准备
.text
.globl kern_entry
kern_entry:
    # load pa of boot pgdir
    movl $REALLOC(__boot_pgdir), %eax
  100000:	b8 00 90 11 40       	mov    $0x40119000,%eax
    movl %eax, %cr3   #指令把页目录表的起始地址存入CR3寄存器中；
  100005:	0f 22 d8             	mov    %eax,%cr3

    # enable paging
    movl %cr0, %eax
  100008:	0f 20 c0             	mov    %cr0,%eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
  10000b:	0d 2f 00 05 80       	or     $0x8005002f,%eax
    andl $~(CR0_TS | CR0_EM), %eax
  100010:	83 e0 f3             	and    $0xfffffff3,%eax
    movl %eax, %cr0   #指令把cr0中的CR0_PG标志位设置上。
  100013:	0f 22 c0             	mov    %eax,%cr0

    # update eip  需要使用一个绝对跳转来使内核跳转到高虚拟地址
    # now, eip = 0x1.....
    leal next, %eax
  100016:	8d 05 1e 00 10 00    	lea    0x10001e,%eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
  10001c:	ff e0                	jmp    *%eax

0010001e <next>:
next:

    #跳转完毕后，通过把boot_pgdir[0]对应的第一个页目录表项（0~4MB）清零来取消了临时的页映射关系：
    # unmap va 0 ~ 4M, it's temporary mapping 
    xorl %eax, %eax
  10001e:	31 c0                	xor    %eax,%eax
    movl %eax, __boot_pgdir
  100020:	a3 00 90 11 00       	mov    %eax,0x119000

    # set ebp, esp
    movl $0x0, %ebp
  100025:	bd 00 00 00 00       	mov    $0x0,%ebp
    # the kernel stack region is from bootstack -- bootstacktop,
    # the kernel stack size is KSTACKSIZE (8KB)defined in memlayout.h
    movl $bootstacktop, %esp
  10002a:	bc 00 80 11 00       	mov    $0x118000,%esp
    # now kernel stack is ready , call the first C function
    call kern_init
  10002f:	e8 02 00 00 00       	call   100036 <kern_init>

00100034 <spin>:

# should never get here
spin:
    jmp spin
  100034:	eb fe                	jmp    100034 <spin>

00100036 <kern_init>:
//不像lab1那样，直接调用kern_init函数，而是先调用位于kern_entry函数。
//kern_entry函数的主要任务是为执行kern_init建立一个良好的C语言运行环境（设置堆栈），
//而且临时建立了一个段映射关系，为之后建立分页机制的过程做一个准备
//完成这些工作后，才调用kern_init函数
int
kern_init(void) {
  100036:	55                   	push   %ebp
  100037:	89 e5                	mov    %esp,%ebp
  100039:	83 ec 28             	sub    $0x28,%esp
    extern char edata[], end[];
    memset(edata, 0, end - edata);
  10003c:	ba 88 bf 11 00       	mov    $0x11bf88,%edx
  100041:	b8 36 8a 11 00       	mov    $0x118a36,%eax
  100046:	29 c2                	sub    %eax,%edx
  100048:	89 d0                	mov    %edx,%eax
  10004a:	89 44 24 08          	mov    %eax,0x8(%esp)
  10004e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  100055:	00 
  100056:	c7 04 24 36 8a 11 00 	movl   $0x118a36,(%esp)
  10005d:	e8 22 59 00 00       	call   105984 <memset>

    cons_init();                // init the console
  100062:	e8 90 15 00 00       	call   1015f7 <cons_init>

    const char *message = "(THU.CST) os is loading ...";
  100067:	c7 45 f4 80 61 10 00 	movl   $0x106180,-0xc(%ebp)
    cprintf("%s\n\n", message);
  10006e:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100071:	89 44 24 04          	mov    %eax,0x4(%esp)
  100075:	c7 04 24 9c 61 10 00 	movl   $0x10619c,(%esp)
  10007c:	e8 21 02 00 00       	call   1002a2 <cprintf>

    print_kerninfo();
  100081:	e8 c2 08 00 00       	call   100948 <print_kerninfo>

    grade_backtrace();
  100086:	e8 8e 00 00 00       	call   100119 <grade_backtrace>

    //调用pmm_init函数完成物理内存的管理
    pmm_init();                 // init physical memory management
  10008b:	e8 ad 32 00 00       	call   10333d <pmm_init>

    //调用pic_init函数和idt_init函数执行中断和异常相关的初始化工作，这些工作与lab1的中断异常初始化工作的内容是相同的。
    pic_init();                 // init interrupt controller
  100090:	e8 c7 16 00 00       	call   10175c <pic_init>
    idt_init();                 // init interrupt descriptor table
  100095:	e8 4c 18 00 00       	call   1018e6 <idt_init>

    clock_init();               // init clock interrupt
  10009a:	e8 fb 0c 00 00       	call   100d9a <clock_init>
    intr_enable();              // enable irq interrupt
  10009f:	e8 f2 17 00 00       	call   101896 <intr_enable>

    //LAB1: CAHLLENGE 1 If you try to do it, uncomment lab1_switch_test()
    // user/kernel mode switch test
    lab1_switch_test(); 
  1000a4:	e8 6b 01 00 00       	call   100214 <lab1_switch_test>

    /* do nothing */
    while (1);
  1000a9:	eb fe                	jmp    1000a9 <kern_init+0x73>

001000ab <grade_backtrace2>:
}

void __attribute__((noinline))
grade_backtrace2(int arg0, int arg1, int arg2, int arg3) {
  1000ab:	55                   	push   %ebp
  1000ac:	89 e5                	mov    %esp,%ebp
  1000ae:	83 ec 18             	sub    $0x18,%esp
    mon_backtrace(0, NULL, NULL);
  1000b1:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  1000b8:	00 
  1000b9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  1000c0:	00 
  1000c1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
  1000c8:	e8 bb 0c 00 00       	call   100d88 <mon_backtrace>
}
  1000cd:	90                   	nop
  1000ce:	c9                   	leave  
  1000cf:	c3                   	ret    

001000d0 <grade_backtrace1>:

void __attribute__((noinline))
grade_backtrace1(int arg0, int arg1) {
  1000d0:	55                   	push   %ebp
  1000d1:	89 e5                	mov    %esp,%ebp
  1000d3:	53                   	push   %ebx
  1000d4:	83 ec 14             	sub    $0x14,%esp
    grade_backtrace2(arg0, (int)&arg0, arg1, (int)&arg1);
  1000d7:	8d 4d 0c             	lea    0xc(%ebp),%ecx
  1000da:	8b 55 0c             	mov    0xc(%ebp),%edx
  1000dd:	8d 5d 08             	lea    0x8(%ebp),%ebx
  1000e0:	8b 45 08             	mov    0x8(%ebp),%eax
  1000e3:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
  1000e7:	89 54 24 08          	mov    %edx,0x8(%esp)
  1000eb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
  1000ef:	89 04 24             	mov    %eax,(%esp)
  1000f2:	e8 b4 ff ff ff       	call   1000ab <grade_backtrace2>
}
  1000f7:	90                   	nop
  1000f8:	83 c4 14             	add    $0x14,%esp
  1000fb:	5b                   	pop    %ebx
  1000fc:	5d                   	pop    %ebp
  1000fd:	c3                   	ret    

001000fe <grade_backtrace0>:

void __attribute__((noinline))
grade_backtrace0(int arg0, int arg1, int arg2) {
  1000fe:	55                   	push   %ebp
  1000ff:	89 e5                	mov    %esp,%ebp
  100101:	83 ec 18             	sub    $0x18,%esp
    grade_backtrace1(arg0, arg2);
  100104:	8b 45 10             	mov    0x10(%ebp),%eax
  100107:	89 44 24 04          	mov    %eax,0x4(%esp)
  10010b:	8b 45 08             	mov    0x8(%ebp),%eax
  10010e:	89 04 24             	mov    %eax,(%esp)
  100111:	e8 ba ff ff ff       	call   1000d0 <grade_backtrace1>
}
  100116:	90                   	nop
  100117:	c9                   	leave  
  100118:	c3                   	ret    

00100119 <grade_backtrace>:

void
grade_backtrace(void) {
  100119:	55                   	push   %ebp
  10011a:	89 e5                	mov    %esp,%ebp
  10011c:	83 ec 18             	sub    $0x18,%esp
    grade_backtrace0(0, (int)kern_init, 0xffff0000);
  10011f:	b8 36 00 10 00       	mov    $0x100036,%eax
  100124:	c7 44 24 08 00 00 ff 	movl   $0xffff0000,0x8(%esp)
  10012b:	ff 
  10012c:	89 44 24 04          	mov    %eax,0x4(%esp)
  100130:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
  100137:	e8 c2 ff ff ff       	call   1000fe <grade_backtrace0>
}
  10013c:	90                   	nop
  10013d:	c9                   	leave  
  10013e:	c3                   	ret    

0010013f <lab1_print_cur_status>:

static void
lab1_print_cur_status(void) {
  10013f:	55                   	push   %ebp
  100140:	89 e5                	mov    %esp,%ebp
  100142:	83 ec 28             	sub    $0x28,%esp
    static int round = 0;
    uint16_t reg1, reg2, reg3, reg4;
    asm volatile (
  100145:	8c 4d f6             	mov    %cs,-0xa(%ebp)
  100148:	8c 5d f4             	mov    %ds,-0xc(%ebp)
  10014b:	8c 45 f2             	mov    %es,-0xe(%ebp)
  10014e:	8c 55 f0             	mov    %ss,-0x10(%ebp)
            "mov %%cs, %0;"
            "mov %%ds, %1;"
            "mov %%es, %2;"
            "mov %%ss, %3;"
            : "=m"(reg1), "=m"(reg2), "=m"(reg3), "=m"(reg4));
    cprintf("%d: @ring %d\n", round, reg1 & 3);
  100151:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
  100155:	83 e0 03             	and    $0x3,%eax
  100158:	89 c2                	mov    %eax,%edx
  10015a:	a1 00 b0 11 00       	mov    0x11b000,%eax
  10015f:	89 54 24 08          	mov    %edx,0x8(%esp)
  100163:	89 44 24 04          	mov    %eax,0x4(%esp)
  100167:	c7 04 24 a1 61 10 00 	movl   $0x1061a1,(%esp)
  10016e:	e8 2f 01 00 00       	call   1002a2 <cprintf>
    cprintf("%d:  cs = %x\n", round, reg1);
  100173:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
  100177:	89 c2                	mov    %eax,%edx
  100179:	a1 00 b0 11 00       	mov    0x11b000,%eax
  10017e:	89 54 24 08          	mov    %edx,0x8(%esp)
  100182:	89 44 24 04          	mov    %eax,0x4(%esp)
  100186:	c7 04 24 af 61 10 00 	movl   $0x1061af,(%esp)
  10018d:	e8 10 01 00 00       	call   1002a2 <cprintf>
    cprintf("%d:  ds = %x\n", round, reg2);
  100192:	0f b7 45 f4          	movzwl -0xc(%ebp),%eax
  100196:	89 c2                	mov    %eax,%edx
  100198:	a1 00 b0 11 00       	mov    0x11b000,%eax
  10019d:	89 54 24 08          	mov    %edx,0x8(%esp)
  1001a1:	89 44 24 04          	mov    %eax,0x4(%esp)
  1001a5:	c7 04 24 bd 61 10 00 	movl   $0x1061bd,(%esp)
  1001ac:	e8 f1 00 00 00       	call   1002a2 <cprintf>
    cprintf("%d:  es = %x\n", round, reg3);
  1001b1:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
  1001b5:	89 c2                	mov    %eax,%edx
  1001b7:	a1 00 b0 11 00       	mov    0x11b000,%eax
  1001bc:	89 54 24 08          	mov    %edx,0x8(%esp)
  1001c0:	89 44 24 04          	mov    %eax,0x4(%esp)
  1001c4:	c7 04 24 cb 61 10 00 	movl   $0x1061cb,(%esp)
  1001cb:	e8 d2 00 00 00       	call   1002a2 <cprintf>
    cprintf("%d:  ss = %x\n", round, reg4);
  1001d0:	0f b7 45 f0          	movzwl -0x10(%ebp),%eax
  1001d4:	89 c2                	mov    %eax,%edx
  1001d6:	a1 00 b0 11 00       	mov    0x11b000,%eax
  1001db:	89 54 24 08          	mov    %edx,0x8(%esp)
  1001df:	89 44 24 04          	mov    %eax,0x4(%esp)
  1001e3:	c7 04 24 d9 61 10 00 	movl   $0x1061d9,(%esp)
  1001ea:	e8 b3 00 00 00       	call   1002a2 <cprintf>
    round ++;
  1001ef:	a1 00 b0 11 00       	mov    0x11b000,%eax
  1001f4:	40                   	inc    %eax
  1001f5:	a3 00 b0 11 00       	mov    %eax,0x11b000
}
  1001fa:	90                   	nop
  1001fb:	c9                   	leave  
  1001fc:	c3                   	ret    

001001fd <lab1_switch_to_user>:

static void
lab1_switch_to_user(void) {
  1001fd:	55                   	push   %ebp
  1001fe:	89 e5                	mov    %esp,%ebp
    //LAB1 CHALLENGE 1 : TODO
    asm volatile (
  100200:	83 ec 08             	sub    $0x8,%esp
  100203:	cd 78                	int    $0x78
  100205:	89 ec                	mov    %ebp,%esp
	    "int %0 \n"
	    "movl %%ebp, %%esp"
	    : 
	    : "i"(T_SWITCH_TOU)
	);
}
  100207:	90                   	nop
  100208:	5d                   	pop    %ebp
  100209:	c3                   	ret    

0010020a <lab1_switch_to_kernel>:

static void
lab1_switch_to_kernel(void) {
  10020a:	55                   	push   %ebp
  10020b:	89 e5                	mov    %esp,%ebp
    //LAB1 CHALLENGE 1 :  TODO
    asm volatile (
  10020d:	cd 79                	int    $0x79
  10020f:	89 ec                	mov    %ebp,%esp
	    "int %0 \n"
	    "movl %%ebp, %%esp \n"
	    : 
	    : "i"(T_SWITCH_TOK)
	);
}
  100211:	90                   	nop
  100212:	5d                   	pop    %ebp
  100213:	c3                   	ret    

00100214 <lab1_switch_test>:

static void
lab1_switch_test(void) {
  100214:	55                   	push   %ebp
  100215:	89 e5                	mov    %esp,%ebp
  100217:	83 ec 18             	sub    $0x18,%esp
    lab1_print_cur_status();
  10021a:	e8 20 ff ff ff       	call   10013f <lab1_print_cur_status>
    cprintf("+++ switch to  user  mode +++\n");
  10021f:	c7 04 24 e8 61 10 00 	movl   $0x1061e8,(%esp)
  100226:	e8 77 00 00 00       	call   1002a2 <cprintf>
    lab1_switch_to_user();
  10022b:	e8 cd ff ff ff       	call   1001fd <lab1_switch_to_user>
    lab1_print_cur_status();
  100230:	e8 0a ff ff ff       	call   10013f <lab1_print_cur_status>
    cprintf("+++ switch to kernel mode +++\n");
  100235:	c7 04 24 08 62 10 00 	movl   $0x106208,(%esp)
  10023c:	e8 61 00 00 00       	call   1002a2 <cprintf>
    lab1_switch_to_kernel();
  100241:	e8 c4 ff ff ff       	call   10020a <lab1_switch_to_kernel>
    lab1_print_cur_status();
  100246:	e8 f4 fe ff ff       	call   10013f <lab1_print_cur_status>
}
  10024b:	90                   	nop
  10024c:	c9                   	leave  
  10024d:	c3                   	ret    

0010024e <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
  10024e:	55                   	push   %ebp
  10024f:	89 e5                	mov    %esp,%ebp
  100251:	83 ec 18             	sub    $0x18,%esp
    cons_putc(c);
  100254:	8b 45 08             	mov    0x8(%ebp),%eax
  100257:	89 04 24             	mov    %eax,(%esp)
  10025a:	e8 c5 13 00 00       	call   101624 <cons_putc>
    (*cnt) ++;
  10025f:	8b 45 0c             	mov    0xc(%ebp),%eax
  100262:	8b 00                	mov    (%eax),%eax
  100264:	8d 50 01             	lea    0x1(%eax),%edx
  100267:	8b 45 0c             	mov    0xc(%ebp),%eax
  10026a:	89 10                	mov    %edx,(%eax)
}
  10026c:	90                   	nop
  10026d:	c9                   	leave  
  10026e:	c3                   	ret    

0010026f <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
  10026f:	55                   	push   %ebp
  100270:	89 e5                	mov    %esp,%ebp
  100272:	83 ec 28             	sub    $0x28,%esp
    int cnt = 0;
  100275:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
  10027c:	8b 45 0c             	mov    0xc(%ebp),%eax
  10027f:	89 44 24 0c          	mov    %eax,0xc(%esp)
  100283:	8b 45 08             	mov    0x8(%ebp),%eax
  100286:	89 44 24 08          	mov    %eax,0x8(%esp)
  10028a:	8d 45 f4             	lea    -0xc(%ebp),%eax
  10028d:	89 44 24 04          	mov    %eax,0x4(%esp)
  100291:	c7 04 24 4e 02 10 00 	movl   $0x10024e,(%esp)
  100298:	e8 3a 5a 00 00       	call   105cd7 <vprintfmt>
    return cnt;
  10029d:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  1002a0:	c9                   	leave  
  1002a1:	c3                   	ret    

001002a2 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
  1002a2:	55                   	push   %ebp
  1002a3:	89 e5                	mov    %esp,%ebp
  1002a5:	83 ec 28             	sub    $0x28,%esp
    va_list ap;
    int cnt;
    va_start(ap, fmt);
  1002a8:	8d 45 0c             	lea    0xc(%ebp),%eax
  1002ab:	89 45 f0             	mov    %eax,-0x10(%ebp)
    cnt = vcprintf(fmt, ap);
  1002ae:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1002b1:	89 44 24 04          	mov    %eax,0x4(%esp)
  1002b5:	8b 45 08             	mov    0x8(%ebp),%eax
  1002b8:	89 04 24             	mov    %eax,(%esp)
  1002bb:	e8 af ff ff ff       	call   10026f <vcprintf>
  1002c0:	89 45 f4             	mov    %eax,-0xc(%ebp)
    va_end(ap);
    return cnt;
  1002c3:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  1002c6:	c9                   	leave  
  1002c7:	c3                   	ret    

001002c8 <cputchar>:

/* cputchar - writes a single character to stdout */
void
cputchar(int c) {
  1002c8:	55                   	push   %ebp
  1002c9:	89 e5                	mov    %esp,%ebp
  1002cb:	83 ec 18             	sub    $0x18,%esp
    cons_putc(c);
  1002ce:	8b 45 08             	mov    0x8(%ebp),%eax
  1002d1:	89 04 24             	mov    %eax,(%esp)
  1002d4:	e8 4b 13 00 00       	call   101624 <cons_putc>
}
  1002d9:	90                   	nop
  1002da:	c9                   	leave  
  1002db:	c3                   	ret    

001002dc <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
  1002dc:	55                   	push   %ebp
  1002dd:	89 e5                	mov    %esp,%ebp
  1002df:	83 ec 28             	sub    $0x28,%esp
    int cnt = 0;
  1002e2:	c7 45 f0 00 00 00 00 	movl   $0x0,-0x10(%ebp)
    char c;
    while ((c = *str ++) != '\0') {
  1002e9:	eb 13                	jmp    1002fe <cputs+0x22>
        cputch(c, &cnt);
  1002eb:	0f be 45 f7          	movsbl -0x9(%ebp),%eax
  1002ef:	8d 55 f0             	lea    -0x10(%ebp),%edx
  1002f2:	89 54 24 04          	mov    %edx,0x4(%esp)
  1002f6:	89 04 24             	mov    %eax,(%esp)
  1002f9:	e8 50 ff ff ff       	call   10024e <cputch>
    while ((c = *str ++) != '\0') {
  1002fe:	8b 45 08             	mov    0x8(%ebp),%eax
  100301:	8d 50 01             	lea    0x1(%eax),%edx
  100304:	89 55 08             	mov    %edx,0x8(%ebp)
  100307:	0f b6 00             	movzbl (%eax),%eax
  10030a:	88 45 f7             	mov    %al,-0x9(%ebp)
  10030d:	80 7d f7 00          	cmpb   $0x0,-0x9(%ebp)
  100311:	75 d8                	jne    1002eb <cputs+0xf>
    }
    cputch('\n', &cnt);
  100313:	8d 45 f0             	lea    -0x10(%ebp),%eax
  100316:	89 44 24 04          	mov    %eax,0x4(%esp)
  10031a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
  100321:	e8 28 ff ff ff       	call   10024e <cputch>
    return cnt;
  100326:	8b 45 f0             	mov    -0x10(%ebp),%eax
}
  100329:	c9                   	leave  
  10032a:	c3                   	ret    

0010032b <getchar>:

/* getchar - reads a single non-zero character from stdin */
int
getchar(void) {
  10032b:	55                   	push   %ebp
  10032c:	89 e5                	mov    %esp,%ebp
  10032e:	83 ec 18             	sub    $0x18,%esp
    int c;
    while ((c = cons_getc()) == 0)
  100331:	e8 2b 13 00 00       	call   101661 <cons_getc>
  100336:	89 45 f4             	mov    %eax,-0xc(%ebp)
  100339:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  10033d:	74 f2                	je     100331 <getchar+0x6>
        /* do nothing */;
    return c;
  10033f:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  100342:	c9                   	leave  
  100343:	c3                   	ret    

00100344 <readline>:
 * The readline() function returns the text of the line read. If some errors
 * are happened, NULL is returned. The return value is a global variable,
 * thus it should be copied before it is used.
 * */
char *
readline(const char *prompt) {
  100344:	55                   	push   %ebp
  100345:	89 e5                	mov    %esp,%ebp
  100347:	83 ec 28             	sub    $0x28,%esp
    if (prompt != NULL) {
  10034a:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
  10034e:	74 13                	je     100363 <readline+0x1f>
        cprintf("%s", prompt);
  100350:	8b 45 08             	mov    0x8(%ebp),%eax
  100353:	89 44 24 04          	mov    %eax,0x4(%esp)
  100357:	c7 04 24 27 62 10 00 	movl   $0x106227,(%esp)
  10035e:	e8 3f ff ff ff       	call   1002a2 <cprintf>
    }
    int i = 0, c;
  100363:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    while (1) {
        c = getchar();
  10036a:	e8 bc ff ff ff       	call   10032b <getchar>
  10036f:	89 45 f0             	mov    %eax,-0x10(%ebp)
        if (c < 0) {
  100372:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  100376:	79 07                	jns    10037f <readline+0x3b>
            return NULL;
  100378:	b8 00 00 00 00       	mov    $0x0,%eax
  10037d:	eb 78                	jmp    1003f7 <readline+0xb3>
        }
        else if (c >= ' ' && i < BUFSIZE - 1) {
  10037f:	83 7d f0 1f          	cmpl   $0x1f,-0x10(%ebp)
  100383:	7e 28                	jle    1003ad <readline+0x69>
  100385:	81 7d f4 fe 03 00 00 	cmpl   $0x3fe,-0xc(%ebp)
  10038c:	7f 1f                	jg     1003ad <readline+0x69>
            cputchar(c);
  10038e:	8b 45 f0             	mov    -0x10(%ebp),%eax
  100391:	89 04 24             	mov    %eax,(%esp)
  100394:	e8 2f ff ff ff       	call   1002c8 <cputchar>
            buf[i ++] = c;
  100399:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10039c:	8d 50 01             	lea    0x1(%eax),%edx
  10039f:	89 55 f4             	mov    %edx,-0xc(%ebp)
  1003a2:	8b 55 f0             	mov    -0x10(%ebp),%edx
  1003a5:	88 90 20 b0 11 00    	mov    %dl,0x11b020(%eax)
  1003ab:	eb 45                	jmp    1003f2 <readline+0xae>
        }
        else if (c == '\b' && i > 0) {
  1003ad:	83 7d f0 08          	cmpl   $0x8,-0x10(%ebp)
  1003b1:	75 16                	jne    1003c9 <readline+0x85>
  1003b3:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  1003b7:	7e 10                	jle    1003c9 <readline+0x85>
            cputchar(c);
  1003b9:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1003bc:	89 04 24             	mov    %eax,(%esp)
  1003bf:	e8 04 ff ff ff       	call   1002c8 <cputchar>
            i --;
  1003c4:	ff 4d f4             	decl   -0xc(%ebp)
  1003c7:	eb 29                	jmp    1003f2 <readline+0xae>
        }
        else if (c == '\n' || c == '\r') {
  1003c9:	83 7d f0 0a          	cmpl   $0xa,-0x10(%ebp)
  1003cd:	74 06                	je     1003d5 <readline+0x91>
  1003cf:	83 7d f0 0d          	cmpl   $0xd,-0x10(%ebp)
  1003d3:	75 95                	jne    10036a <readline+0x26>
            cputchar(c);
  1003d5:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1003d8:	89 04 24             	mov    %eax,(%esp)
  1003db:	e8 e8 fe ff ff       	call   1002c8 <cputchar>
            buf[i] = '\0';
  1003e0:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1003e3:	05 20 b0 11 00       	add    $0x11b020,%eax
  1003e8:	c6 00 00             	movb   $0x0,(%eax)
            return buf;
  1003eb:	b8 20 b0 11 00       	mov    $0x11b020,%eax
  1003f0:	eb 05                	jmp    1003f7 <readline+0xb3>
        c = getchar();
  1003f2:	e9 73 ff ff ff       	jmp    10036a <readline+0x26>
        }
    }
}
  1003f7:	c9                   	leave  
  1003f8:	c3                   	ret    

001003f9 <__panic>:
/* *
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
  1003f9:	55                   	push   %ebp
  1003fa:	89 e5                	mov    %esp,%ebp
  1003fc:	83 ec 28             	sub    $0x28,%esp
    if (is_panic) {
  1003ff:	a1 20 b4 11 00       	mov    0x11b420,%eax
  100404:	85 c0                	test   %eax,%eax
  100406:	75 5b                	jne    100463 <__panic+0x6a>
        goto panic_dead;
    }
    is_panic = 1;
  100408:	c7 05 20 b4 11 00 01 	movl   $0x1,0x11b420
  10040f:	00 00 00 

    // print the 'message'
    va_list ap;
    va_start(ap, fmt);
  100412:	8d 45 14             	lea    0x14(%ebp),%eax
  100415:	89 45 f4             	mov    %eax,-0xc(%ebp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
  100418:	8b 45 0c             	mov    0xc(%ebp),%eax
  10041b:	89 44 24 08          	mov    %eax,0x8(%esp)
  10041f:	8b 45 08             	mov    0x8(%ebp),%eax
  100422:	89 44 24 04          	mov    %eax,0x4(%esp)
  100426:	c7 04 24 2a 62 10 00 	movl   $0x10622a,(%esp)
  10042d:	e8 70 fe ff ff       	call   1002a2 <cprintf>
    vcprintf(fmt, ap);
  100432:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100435:	89 44 24 04          	mov    %eax,0x4(%esp)
  100439:	8b 45 10             	mov    0x10(%ebp),%eax
  10043c:	89 04 24             	mov    %eax,(%esp)
  10043f:	e8 2b fe ff ff       	call   10026f <vcprintf>
    cprintf("\n");
  100444:	c7 04 24 46 62 10 00 	movl   $0x106246,(%esp)
  10044b:	e8 52 fe ff ff       	call   1002a2 <cprintf>
    
    cprintf("stack trackback:\n");
  100450:	c7 04 24 48 62 10 00 	movl   $0x106248,(%esp)
  100457:	e8 46 fe ff ff       	call   1002a2 <cprintf>
    print_stackframe();
  10045c:	e8 32 06 00 00       	call   100a93 <print_stackframe>
  100461:	eb 01                	jmp    100464 <__panic+0x6b>
        goto panic_dead;
  100463:	90                   	nop
    
    va_end(ap);

panic_dead:
    intr_disable();
  100464:	e8 34 14 00 00       	call   10189d <intr_disable>
    while (1) {
        kmonitor(NULL);
  100469:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
  100470:	e8 46 08 00 00       	call   100cbb <kmonitor>
  100475:	eb f2                	jmp    100469 <__panic+0x70>

00100477 <__warn>:
    }
}

/* __warn - like panic, but don't */
void
__warn(const char *file, int line, const char *fmt, ...) {
  100477:	55                   	push   %ebp
  100478:	89 e5                	mov    %esp,%ebp
  10047a:	83 ec 28             	sub    $0x28,%esp
    va_list ap;
    va_start(ap, fmt);
  10047d:	8d 45 14             	lea    0x14(%ebp),%eax
  100480:	89 45 f4             	mov    %eax,-0xc(%ebp)
    cprintf("kernel warning at %s:%d:\n    ", file, line);
  100483:	8b 45 0c             	mov    0xc(%ebp),%eax
  100486:	89 44 24 08          	mov    %eax,0x8(%esp)
  10048a:	8b 45 08             	mov    0x8(%ebp),%eax
  10048d:	89 44 24 04          	mov    %eax,0x4(%esp)
  100491:	c7 04 24 5a 62 10 00 	movl   $0x10625a,(%esp)
  100498:	e8 05 fe ff ff       	call   1002a2 <cprintf>
    vcprintf(fmt, ap);
  10049d:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1004a0:	89 44 24 04          	mov    %eax,0x4(%esp)
  1004a4:	8b 45 10             	mov    0x10(%ebp),%eax
  1004a7:	89 04 24             	mov    %eax,(%esp)
  1004aa:	e8 c0 fd ff ff       	call   10026f <vcprintf>
    cprintf("\n");
  1004af:	c7 04 24 46 62 10 00 	movl   $0x106246,(%esp)
  1004b6:	e8 e7 fd ff ff       	call   1002a2 <cprintf>
    va_end(ap);
}
  1004bb:	90                   	nop
  1004bc:	c9                   	leave  
  1004bd:	c3                   	ret    

001004be <is_kernel_panic>:

bool
is_kernel_panic(void) {
  1004be:	55                   	push   %ebp
  1004bf:	89 e5                	mov    %esp,%ebp
    return is_panic;
  1004c1:	a1 20 b4 11 00       	mov    0x11b420,%eax
}
  1004c6:	5d                   	pop    %ebp
  1004c7:	c3                   	ret    

001004c8 <stab_binsearch>:
 *      stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
 * will exit setting left = 118, right = 554.
 * */
static void
stab_binsearch(const struct stab *stabs, int *region_left, int *region_right,
           int type, uintptr_t addr) {
  1004c8:	55                   	push   %ebp
  1004c9:	89 e5                	mov    %esp,%ebp
  1004cb:	83 ec 20             	sub    $0x20,%esp
    int l = *region_left, r = *region_right, any_matches = 0;
  1004ce:	8b 45 0c             	mov    0xc(%ebp),%eax
  1004d1:	8b 00                	mov    (%eax),%eax
  1004d3:	89 45 fc             	mov    %eax,-0x4(%ebp)
  1004d6:	8b 45 10             	mov    0x10(%ebp),%eax
  1004d9:	8b 00                	mov    (%eax),%eax
  1004db:	89 45 f8             	mov    %eax,-0x8(%ebp)
  1004de:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

    while (l <= r) {
  1004e5:	e9 ca 00 00 00       	jmp    1005b4 <stab_binsearch+0xec>
        int true_m = (l + r) / 2, m = true_m;
  1004ea:	8b 55 fc             	mov    -0x4(%ebp),%edx
  1004ed:	8b 45 f8             	mov    -0x8(%ebp),%eax
  1004f0:	01 d0                	add    %edx,%eax
  1004f2:	89 c2                	mov    %eax,%edx
  1004f4:	c1 ea 1f             	shr    $0x1f,%edx
  1004f7:	01 d0                	add    %edx,%eax
  1004f9:	d1 f8                	sar    %eax
  1004fb:	89 45 ec             	mov    %eax,-0x14(%ebp)
  1004fe:	8b 45 ec             	mov    -0x14(%ebp),%eax
  100501:	89 45 f0             	mov    %eax,-0x10(%ebp)

        // search for earliest stab with right type
        while (m >= l && stabs[m].n_type != type) {
  100504:	eb 03                	jmp    100509 <stab_binsearch+0x41>
            m --;
  100506:	ff 4d f0             	decl   -0x10(%ebp)
        while (m >= l && stabs[m].n_type != type) {
  100509:	8b 45 f0             	mov    -0x10(%ebp),%eax
  10050c:	3b 45 fc             	cmp    -0x4(%ebp),%eax
  10050f:	7c 1f                	jl     100530 <stab_binsearch+0x68>
  100511:	8b 55 f0             	mov    -0x10(%ebp),%edx
  100514:	89 d0                	mov    %edx,%eax
  100516:	01 c0                	add    %eax,%eax
  100518:	01 d0                	add    %edx,%eax
  10051a:	c1 e0 02             	shl    $0x2,%eax
  10051d:	89 c2                	mov    %eax,%edx
  10051f:	8b 45 08             	mov    0x8(%ebp),%eax
  100522:	01 d0                	add    %edx,%eax
  100524:	0f b6 40 04          	movzbl 0x4(%eax),%eax
  100528:	0f b6 c0             	movzbl %al,%eax
  10052b:	39 45 14             	cmp    %eax,0x14(%ebp)
  10052e:	75 d6                	jne    100506 <stab_binsearch+0x3e>
        }
        if (m < l) {    // no match in [l, m]
  100530:	8b 45 f0             	mov    -0x10(%ebp),%eax
  100533:	3b 45 fc             	cmp    -0x4(%ebp),%eax
  100536:	7d 09                	jge    100541 <stab_binsearch+0x79>
            l = true_m + 1;
  100538:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10053b:	40                   	inc    %eax
  10053c:	89 45 fc             	mov    %eax,-0x4(%ebp)
            continue;
  10053f:	eb 73                	jmp    1005b4 <stab_binsearch+0xec>
        }

        // actual binary search
        any_matches = 1;
  100541:	c7 45 f4 01 00 00 00 	movl   $0x1,-0xc(%ebp)
        if (stabs[m].n_value < addr) {
  100548:	8b 55 f0             	mov    -0x10(%ebp),%edx
  10054b:	89 d0                	mov    %edx,%eax
  10054d:	01 c0                	add    %eax,%eax
  10054f:	01 d0                	add    %edx,%eax
  100551:	c1 e0 02             	shl    $0x2,%eax
  100554:	89 c2                	mov    %eax,%edx
  100556:	8b 45 08             	mov    0x8(%ebp),%eax
  100559:	01 d0                	add    %edx,%eax
  10055b:	8b 40 08             	mov    0x8(%eax),%eax
  10055e:	39 45 18             	cmp    %eax,0x18(%ebp)
  100561:	76 11                	jbe    100574 <stab_binsearch+0xac>
            *region_left = m;
  100563:	8b 45 0c             	mov    0xc(%ebp),%eax
  100566:	8b 55 f0             	mov    -0x10(%ebp),%edx
  100569:	89 10                	mov    %edx,(%eax)
            l = true_m + 1;
  10056b:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10056e:	40                   	inc    %eax
  10056f:	89 45 fc             	mov    %eax,-0x4(%ebp)
  100572:	eb 40                	jmp    1005b4 <stab_binsearch+0xec>
        } else if (stabs[m].n_value > addr) {
  100574:	8b 55 f0             	mov    -0x10(%ebp),%edx
  100577:	89 d0                	mov    %edx,%eax
  100579:	01 c0                	add    %eax,%eax
  10057b:	01 d0                	add    %edx,%eax
  10057d:	c1 e0 02             	shl    $0x2,%eax
  100580:	89 c2                	mov    %eax,%edx
  100582:	8b 45 08             	mov    0x8(%ebp),%eax
  100585:	01 d0                	add    %edx,%eax
  100587:	8b 40 08             	mov    0x8(%eax),%eax
  10058a:	39 45 18             	cmp    %eax,0x18(%ebp)
  10058d:	73 14                	jae    1005a3 <stab_binsearch+0xdb>
            *region_right = m - 1;
  10058f:	8b 45 f0             	mov    -0x10(%ebp),%eax
  100592:	8d 50 ff             	lea    -0x1(%eax),%edx
  100595:	8b 45 10             	mov    0x10(%ebp),%eax
  100598:	89 10                	mov    %edx,(%eax)
            r = m - 1;
  10059a:	8b 45 f0             	mov    -0x10(%ebp),%eax
  10059d:	48                   	dec    %eax
  10059e:	89 45 f8             	mov    %eax,-0x8(%ebp)
  1005a1:	eb 11                	jmp    1005b4 <stab_binsearch+0xec>
        } else {
            // exact match for 'addr', but continue loop to find
            // *region_right
            *region_left = m;
  1005a3:	8b 45 0c             	mov    0xc(%ebp),%eax
  1005a6:	8b 55 f0             	mov    -0x10(%ebp),%edx
  1005a9:	89 10                	mov    %edx,(%eax)
            l = m;
  1005ab:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1005ae:	89 45 fc             	mov    %eax,-0x4(%ebp)
            addr ++;
  1005b1:	ff 45 18             	incl   0x18(%ebp)
    while (l <= r) {
  1005b4:	8b 45 fc             	mov    -0x4(%ebp),%eax
  1005b7:	3b 45 f8             	cmp    -0x8(%ebp),%eax
  1005ba:	0f 8e 2a ff ff ff    	jle    1004ea <stab_binsearch+0x22>
        }
    }

    if (!any_matches) {
  1005c0:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  1005c4:	75 0f                	jne    1005d5 <stab_binsearch+0x10d>
        *region_right = *region_left - 1;
  1005c6:	8b 45 0c             	mov    0xc(%ebp),%eax
  1005c9:	8b 00                	mov    (%eax),%eax
  1005cb:	8d 50 ff             	lea    -0x1(%eax),%edx
  1005ce:	8b 45 10             	mov    0x10(%ebp),%eax
  1005d1:	89 10                	mov    %edx,(%eax)
        l = *region_right;
        for (; l > *region_left && stabs[l].n_type != type; l --)
            /* do nothing */;
        *region_left = l;
    }
}
  1005d3:	eb 3e                	jmp    100613 <stab_binsearch+0x14b>
        l = *region_right;
  1005d5:	8b 45 10             	mov    0x10(%ebp),%eax
  1005d8:	8b 00                	mov    (%eax),%eax
  1005da:	89 45 fc             	mov    %eax,-0x4(%ebp)
        for (; l > *region_left && stabs[l].n_type != type; l --)
  1005dd:	eb 03                	jmp    1005e2 <stab_binsearch+0x11a>
  1005df:	ff 4d fc             	decl   -0x4(%ebp)
  1005e2:	8b 45 0c             	mov    0xc(%ebp),%eax
  1005e5:	8b 00                	mov    (%eax),%eax
  1005e7:	39 45 fc             	cmp    %eax,-0x4(%ebp)
  1005ea:	7e 1f                	jle    10060b <stab_binsearch+0x143>
  1005ec:	8b 55 fc             	mov    -0x4(%ebp),%edx
  1005ef:	89 d0                	mov    %edx,%eax
  1005f1:	01 c0                	add    %eax,%eax
  1005f3:	01 d0                	add    %edx,%eax
  1005f5:	c1 e0 02             	shl    $0x2,%eax
  1005f8:	89 c2                	mov    %eax,%edx
  1005fa:	8b 45 08             	mov    0x8(%ebp),%eax
  1005fd:	01 d0                	add    %edx,%eax
  1005ff:	0f b6 40 04          	movzbl 0x4(%eax),%eax
  100603:	0f b6 c0             	movzbl %al,%eax
  100606:	39 45 14             	cmp    %eax,0x14(%ebp)
  100609:	75 d4                	jne    1005df <stab_binsearch+0x117>
        *region_left = l;
  10060b:	8b 45 0c             	mov    0xc(%ebp),%eax
  10060e:	8b 55 fc             	mov    -0x4(%ebp),%edx
  100611:	89 10                	mov    %edx,(%eax)
}
  100613:	90                   	nop
  100614:	c9                   	leave  
  100615:	c3                   	ret    

00100616 <debuginfo_eip>:
 * the specified instruction address, @addr.  Returns 0 if information
 * was found, and negative if not.  But even if it returns negative it
 * has stored some information into '*info'.
 * */
int
debuginfo_eip(uintptr_t addr, struct eipdebuginfo *info) {
  100616:	55                   	push   %ebp
  100617:	89 e5                	mov    %esp,%ebp
  100619:	83 ec 58             	sub    $0x58,%esp
    const struct stab *stabs, *stab_end;
    const char *stabstr, *stabstr_end;

    info->eip_file = "<unknown>";
  10061c:	8b 45 0c             	mov    0xc(%ebp),%eax
  10061f:	c7 00 78 62 10 00    	movl   $0x106278,(%eax)
    info->eip_line = 0;
  100625:	8b 45 0c             	mov    0xc(%ebp),%eax
  100628:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
    info->eip_fn_name = "<unknown>";
  10062f:	8b 45 0c             	mov    0xc(%ebp),%eax
  100632:	c7 40 08 78 62 10 00 	movl   $0x106278,0x8(%eax)
    info->eip_fn_namelen = 9;
  100639:	8b 45 0c             	mov    0xc(%ebp),%eax
  10063c:	c7 40 0c 09 00 00 00 	movl   $0x9,0xc(%eax)
    info->eip_fn_addr = addr;
  100643:	8b 45 0c             	mov    0xc(%ebp),%eax
  100646:	8b 55 08             	mov    0x8(%ebp),%edx
  100649:	89 50 10             	mov    %edx,0x10(%eax)
    info->eip_fn_narg = 0;
  10064c:	8b 45 0c             	mov    0xc(%ebp),%eax
  10064f:	c7 40 14 00 00 00 00 	movl   $0x0,0x14(%eax)

    stabs = __STAB_BEGIN__;
  100656:	c7 45 f4 f0 74 10 00 	movl   $0x1074f0,-0xc(%ebp)
    stab_end = __STAB_END__;
  10065d:	c7 45 f0 0c 28 11 00 	movl   $0x11280c,-0x10(%ebp)
    stabstr = __STABSTR_BEGIN__;
  100664:	c7 45 ec 0d 28 11 00 	movl   $0x11280d,-0x14(%ebp)
    stabstr_end = __STABSTR_END__;
  10066b:	c7 45 e8 2e 53 11 00 	movl   $0x11532e,-0x18(%ebp)

    // String table validity checks
    if (stabstr_end <= stabstr || stabstr_end[-1] != 0) {
  100672:	8b 45 e8             	mov    -0x18(%ebp),%eax
  100675:	3b 45 ec             	cmp    -0x14(%ebp),%eax
  100678:	76 0b                	jbe    100685 <debuginfo_eip+0x6f>
  10067a:	8b 45 e8             	mov    -0x18(%ebp),%eax
  10067d:	48                   	dec    %eax
  10067e:	0f b6 00             	movzbl (%eax),%eax
  100681:	84 c0                	test   %al,%al
  100683:	74 0a                	je     10068f <debuginfo_eip+0x79>
        return -1;
  100685:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  10068a:	e9 b7 02 00 00       	jmp    100946 <debuginfo_eip+0x330>
    // 'eip'.  First, we find the basic source file containing 'eip'.
    // Then, we look in that source file for the function.  Then we look
    // for the line number.

    // Search the entire set of stabs for the source file (type N_SO).
    int lfile = 0, rfile = (stab_end - stabs) - 1;
  10068f:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
  100696:	8b 55 f0             	mov    -0x10(%ebp),%edx
  100699:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10069c:	29 c2                	sub    %eax,%edx
  10069e:	89 d0                	mov    %edx,%eax
  1006a0:	c1 f8 02             	sar    $0x2,%eax
  1006a3:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
  1006a9:	48                   	dec    %eax
  1006aa:	89 45 e0             	mov    %eax,-0x20(%ebp)
    stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
  1006ad:	8b 45 08             	mov    0x8(%ebp),%eax
  1006b0:	89 44 24 10          	mov    %eax,0x10(%esp)
  1006b4:	c7 44 24 0c 64 00 00 	movl   $0x64,0xc(%esp)
  1006bb:	00 
  1006bc:	8d 45 e0             	lea    -0x20(%ebp),%eax
  1006bf:	89 44 24 08          	mov    %eax,0x8(%esp)
  1006c3:	8d 45 e4             	lea    -0x1c(%ebp),%eax
  1006c6:	89 44 24 04          	mov    %eax,0x4(%esp)
  1006ca:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1006cd:	89 04 24             	mov    %eax,(%esp)
  1006d0:	e8 f3 fd ff ff       	call   1004c8 <stab_binsearch>
    if (lfile == 0)
  1006d5:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  1006d8:	85 c0                	test   %eax,%eax
  1006da:	75 0a                	jne    1006e6 <debuginfo_eip+0xd0>
        return -1;
  1006dc:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  1006e1:	e9 60 02 00 00       	jmp    100946 <debuginfo_eip+0x330>

    // Search within that file's stabs for the function definition
    // (N_FUN).
    int lfun = lfile, rfun = rfile;
  1006e6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  1006e9:	89 45 dc             	mov    %eax,-0x24(%ebp)
  1006ec:	8b 45 e0             	mov    -0x20(%ebp),%eax
  1006ef:	89 45 d8             	mov    %eax,-0x28(%ebp)
    int lline, rline;
    stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
  1006f2:	8b 45 08             	mov    0x8(%ebp),%eax
  1006f5:	89 44 24 10          	mov    %eax,0x10(%esp)
  1006f9:	c7 44 24 0c 24 00 00 	movl   $0x24,0xc(%esp)
  100700:	00 
  100701:	8d 45 d8             	lea    -0x28(%ebp),%eax
  100704:	89 44 24 08          	mov    %eax,0x8(%esp)
  100708:	8d 45 dc             	lea    -0x24(%ebp),%eax
  10070b:	89 44 24 04          	mov    %eax,0x4(%esp)
  10070f:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100712:	89 04 24             	mov    %eax,(%esp)
  100715:	e8 ae fd ff ff       	call   1004c8 <stab_binsearch>

    if (lfun <= rfun) {
  10071a:	8b 55 dc             	mov    -0x24(%ebp),%edx
  10071d:	8b 45 d8             	mov    -0x28(%ebp),%eax
  100720:	39 c2                	cmp    %eax,%edx
  100722:	7f 7c                	jg     1007a0 <debuginfo_eip+0x18a>
        // stabs[lfun] points to the function name
        // in the string table, but check bounds just in case.
        if (stabs[lfun].n_strx < stabstr_end - stabstr) {
  100724:	8b 45 dc             	mov    -0x24(%ebp),%eax
  100727:	89 c2                	mov    %eax,%edx
  100729:	89 d0                	mov    %edx,%eax
  10072b:	01 c0                	add    %eax,%eax
  10072d:	01 d0                	add    %edx,%eax
  10072f:	c1 e0 02             	shl    $0x2,%eax
  100732:	89 c2                	mov    %eax,%edx
  100734:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100737:	01 d0                	add    %edx,%eax
  100739:	8b 00                	mov    (%eax),%eax
  10073b:	8b 4d e8             	mov    -0x18(%ebp),%ecx
  10073e:	8b 55 ec             	mov    -0x14(%ebp),%edx
  100741:	29 d1                	sub    %edx,%ecx
  100743:	89 ca                	mov    %ecx,%edx
  100745:	39 d0                	cmp    %edx,%eax
  100747:	73 22                	jae    10076b <debuginfo_eip+0x155>
            info->eip_fn_name = stabstr + stabs[lfun].n_strx;
  100749:	8b 45 dc             	mov    -0x24(%ebp),%eax
  10074c:	89 c2                	mov    %eax,%edx
  10074e:	89 d0                	mov    %edx,%eax
  100750:	01 c0                	add    %eax,%eax
  100752:	01 d0                	add    %edx,%eax
  100754:	c1 e0 02             	shl    $0x2,%eax
  100757:	89 c2                	mov    %eax,%edx
  100759:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10075c:	01 d0                	add    %edx,%eax
  10075e:	8b 10                	mov    (%eax),%edx
  100760:	8b 45 ec             	mov    -0x14(%ebp),%eax
  100763:	01 c2                	add    %eax,%edx
  100765:	8b 45 0c             	mov    0xc(%ebp),%eax
  100768:	89 50 08             	mov    %edx,0x8(%eax)
        }
        info->eip_fn_addr = stabs[lfun].n_value;
  10076b:	8b 45 dc             	mov    -0x24(%ebp),%eax
  10076e:	89 c2                	mov    %eax,%edx
  100770:	89 d0                	mov    %edx,%eax
  100772:	01 c0                	add    %eax,%eax
  100774:	01 d0                	add    %edx,%eax
  100776:	c1 e0 02             	shl    $0x2,%eax
  100779:	89 c2                	mov    %eax,%edx
  10077b:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10077e:	01 d0                	add    %edx,%eax
  100780:	8b 50 08             	mov    0x8(%eax),%edx
  100783:	8b 45 0c             	mov    0xc(%ebp),%eax
  100786:	89 50 10             	mov    %edx,0x10(%eax)
        addr -= info->eip_fn_addr;
  100789:	8b 45 0c             	mov    0xc(%ebp),%eax
  10078c:	8b 40 10             	mov    0x10(%eax),%eax
  10078f:	29 45 08             	sub    %eax,0x8(%ebp)
        // Search within the function definition for the line number.
        lline = lfun;
  100792:	8b 45 dc             	mov    -0x24(%ebp),%eax
  100795:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        rline = rfun;
  100798:	8b 45 d8             	mov    -0x28(%ebp),%eax
  10079b:	89 45 d0             	mov    %eax,-0x30(%ebp)
  10079e:	eb 15                	jmp    1007b5 <debuginfo_eip+0x19f>
    } else {
        // Couldn't find function stab!  Maybe we're in an assembly
        // file.  Search the whole file for the line number.
        info->eip_fn_addr = addr;
  1007a0:	8b 45 0c             	mov    0xc(%ebp),%eax
  1007a3:	8b 55 08             	mov    0x8(%ebp),%edx
  1007a6:	89 50 10             	mov    %edx,0x10(%eax)
        lline = lfile;
  1007a9:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  1007ac:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        rline = rfile;
  1007af:	8b 45 e0             	mov    -0x20(%ebp),%eax
  1007b2:	89 45 d0             	mov    %eax,-0x30(%ebp)
    }
    info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
  1007b5:	8b 45 0c             	mov    0xc(%ebp),%eax
  1007b8:	8b 40 08             	mov    0x8(%eax),%eax
  1007bb:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
  1007c2:	00 
  1007c3:	89 04 24             	mov    %eax,(%esp)
  1007c6:	e8 35 50 00 00       	call   105800 <strfind>
  1007cb:	89 c2                	mov    %eax,%edx
  1007cd:	8b 45 0c             	mov    0xc(%ebp),%eax
  1007d0:	8b 40 08             	mov    0x8(%eax),%eax
  1007d3:	29 c2                	sub    %eax,%edx
  1007d5:	8b 45 0c             	mov    0xc(%ebp),%eax
  1007d8:	89 50 0c             	mov    %edx,0xc(%eax)

    // Search within [lline, rline] for the line number stab.
    // If found, set info->eip_line to the right line number.
    // If not found, return -1.
    stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
  1007db:	8b 45 08             	mov    0x8(%ebp),%eax
  1007de:	89 44 24 10          	mov    %eax,0x10(%esp)
  1007e2:	c7 44 24 0c 44 00 00 	movl   $0x44,0xc(%esp)
  1007e9:	00 
  1007ea:	8d 45 d0             	lea    -0x30(%ebp),%eax
  1007ed:	89 44 24 08          	mov    %eax,0x8(%esp)
  1007f1:	8d 45 d4             	lea    -0x2c(%ebp),%eax
  1007f4:	89 44 24 04          	mov    %eax,0x4(%esp)
  1007f8:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1007fb:	89 04 24             	mov    %eax,(%esp)
  1007fe:	e8 c5 fc ff ff       	call   1004c8 <stab_binsearch>
    if (lline <= rline) {
  100803:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  100806:	8b 45 d0             	mov    -0x30(%ebp),%eax
  100809:	39 c2                	cmp    %eax,%edx
  10080b:	7f 23                	jg     100830 <debuginfo_eip+0x21a>
        info->eip_line = stabs[rline].n_desc;
  10080d:	8b 45 d0             	mov    -0x30(%ebp),%eax
  100810:	89 c2                	mov    %eax,%edx
  100812:	89 d0                	mov    %edx,%eax
  100814:	01 c0                	add    %eax,%eax
  100816:	01 d0                	add    %edx,%eax
  100818:	c1 e0 02             	shl    $0x2,%eax
  10081b:	89 c2                	mov    %eax,%edx
  10081d:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100820:	01 d0                	add    %edx,%eax
  100822:	0f b7 40 06          	movzwl 0x6(%eax),%eax
  100826:	89 c2                	mov    %eax,%edx
  100828:	8b 45 0c             	mov    0xc(%ebp),%eax
  10082b:	89 50 04             	mov    %edx,0x4(%eax)

    // Search backwards from the line number for the relevant filename stab.
    // We can't just use the "lfile" stab because inlined functions
    // can interpolate code from a different file!
    // Such included source files use the N_SOL stab type.
    while (lline >= lfile
  10082e:	eb 11                	jmp    100841 <debuginfo_eip+0x22b>
        return -1;
  100830:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  100835:	e9 0c 01 00 00       	jmp    100946 <debuginfo_eip+0x330>
           && stabs[lline].n_type != N_SOL
           && (stabs[lline].n_type != N_SO || !stabs[lline].n_value)) {
        lline --;
  10083a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  10083d:	48                   	dec    %eax
  10083e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
    while (lline >= lfile
  100841:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  100844:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  100847:	39 c2                	cmp    %eax,%edx
  100849:	7c 56                	jl     1008a1 <debuginfo_eip+0x28b>
           && stabs[lline].n_type != N_SOL
  10084b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  10084e:	89 c2                	mov    %eax,%edx
  100850:	89 d0                	mov    %edx,%eax
  100852:	01 c0                	add    %eax,%eax
  100854:	01 d0                	add    %edx,%eax
  100856:	c1 e0 02             	shl    $0x2,%eax
  100859:	89 c2                	mov    %eax,%edx
  10085b:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10085e:	01 d0                	add    %edx,%eax
  100860:	0f b6 40 04          	movzbl 0x4(%eax),%eax
  100864:	3c 84                	cmp    $0x84,%al
  100866:	74 39                	je     1008a1 <debuginfo_eip+0x28b>
           && (stabs[lline].n_type != N_SO || !stabs[lline].n_value)) {
  100868:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  10086b:	89 c2                	mov    %eax,%edx
  10086d:	89 d0                	mov    %edx,%eax
  10086f:	01 c0                	add    %eax,%eax
  100871:	01 d0                	add    %edx,%eax
  100873:	c1 e0 02             	shl    $0x2,%eax
  100876:	89 c2                	mov    %eax,%edx
  100878:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10087b:	01 d0                	add    %edx,%eax
  10087d:	0f b6 40 04          	movzbl 0x4(%eax),%eax
  100881:	3c 64                	cmp    $0x64,%al
  100883:	75 b5                	jne    10083a <debuginfo_eip+0x224>
  100885:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  100888:	89 c2                	mov    %eax,%edx
  10088a:	89 d0                	mov    %edx,%eax
  10088c:	01 c0                	add    %eax,%eax
  10088e:	01 d0                	add    %edx,%eax
  100890:	c1 e0 02             	shl    $0x2,%eax
  100893:	89 c2                	mov    %eax,%edx
  100895:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100898:	01 d0                	add    %edx,%eax
  10089a:	8b 40 08             	mov    0x8(%eax),%eax
  10089d:	85 c0                	test   %eax,%eax
  10089f:	74 99                	je     10083a <debuginfo_eip+0x224>
    }
    if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr) {
  1008a1:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  1008a4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  1008a7:	39 c2                	cmp    %eax,%edx
  1008a9:	7c 46                	jl     1008f1 <debuginfo_eip+0x2db>
  1008ab:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  1008ae:	89 c2                	mov    %eax,%edx
  1008b0:	89 d0                	mov    %edx,%eax
  1008b2:	01 c0                	add    %eax,%eax
  1008b4:	01 d0                	add    %edx,%eax
  1008b6:	c1 e0 02             	shl    $0x2,%eax
  1008b9:	89 c2                	mov    %eax,%edx
  1008bb:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1008be:	01 d0                	add    %edx,%eax
  1008c0:	8b 00                	mov    (%eax),%eax
  1008c2:	8b 4d e8             	mov    -0x18(%ebp),%ecx
  1008c5:	8b 55 ec             	mov    -0x14(%ebp),%edx
  1008c8:	29 d1                	sub    %edx,%ecx
  1008ca:	89 ca                	mov    %ecx,%edx
  1008cc:	39 d0                	cmp    %edx,%eax
  1008ce:	73 21                	jae    1008f1 <debuginfo_eip+0x2db>
        info->eip_file = stabstr + stabs[lline].n_strx;
  1008d0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  1008d3:	89 c2                	mov    %eax,%edx
  1008d5:	89 d0                	mov    %edx,%eax
  1008d7:	01 c0                	add    %eax,%eax
  1008d9:	01 d0                	add    %edx,%eax
  1008db:	c1 e0 02             	shl    $0x2,%eax
  1008de:	89 c2                	mov    %eax,%edx
  1008e0:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1008e3:	01 d0                	add    %edx,%eax
  1008e5:	8b 10                	mov    (%eax),%edx
  1008e7:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1008ea:	01 c2                	add    %eax,%edx
  1008ec:	8b 45 0c             	mov    0xc(%ebp),%eax
  1008ef:	89 10                	mov    %edx,(%eax)
    }

    // Set eip_fn_narg to the number of arguments taken by the function,
    // or 0 if there was no containing function.
    if (lfun < rfun) {
  1008f1:	8b 55 dc             	mov    -0x24(%ebp),%edx
  1008f4:	8b 45 d8             	mov    -0x28(%ebp),%eax
  1008f7:	39 c2                	cmp    %eax,%edx
  1008f9:	7d 46                	jge    100941 <debuginfo_eip+0x32b>
        for (lline = lfun + 1;
  1008fb:	8b 45 dc             	mov    -0x24(%ebp),%eax
  1008fe:	40                   	inc    %eax
  1008ff:	89 45 d4             	mov    %eax,-0x2c(%ebp)
  100902:	eb 16                	jmp    10091a <debuginfo_eip+0x304>
             lline < rfun && stabs[lline].n_type == N_PSYM;
             lline ++) {
            info->eip_fn_narg ++;
  100904:	8b 45 0c             	mov    0xc(%ebp),%eax
  100907:	8b 40 14             	mov    0x14(%eax),%eax
  10090a:	8d 50 01             	lea    0x1(%eax),%edx
  10090d:	8b 45 0c             	mov    0xc(%ebp),%eax
  100910:	89 50 14             	mov    %edx,0x14(%eax)
             lline ++) {
  100913:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  100916:	40                   	inc    %eax
  100917:	89 45 d4             	mov    %eax,-0x2c(%ebp)
             lline < rfun && stabs[lline].n_type == N_PSYM;
  10091a:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  10091d:	8b 45 d8             	mov    -0x28(%ebp),%eax
        for (lline = lfun + 1;
  100920:	39 c2                	cmp    %eax,%edx
  100922:	7d 1d                	jge    100941 <debuginfo_eip+0x32b>
             lline < rfun && stabs[lline].n_type == N_PSYM;
  100924:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  100927:	89 c2                	mov    %eax,%edx
  100929:	89 d0                	mov    %edx,%eax
  10092b:	01 c0                	add    %eax,%eax
  10092d:	01 d0                	add    %edx,%eax
  10092f:	c1 e0 02             	shl    $0x2,%eax
  100932:	89 c2                	mov    %eax,%edx
  100934:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100937:	01 d0                	add    %edx,%eax
  100939:	0f b6 40 04          	movzbl 0x4(%eax),%eax
  10093d:	3c a0                	cmp    $0xa0,%al
  10093f:	74 c3                	je     100904 <debuginfo_eip+0x2ee>
        }
    }
    return 0;
  100941:	b8 00 00 00 00       	mov    $0x0,%eax
}
  100946:	c9                   	leave  
  100947:	c3                   	ret    

00100948 <print_kerninfo>:
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void
print_kerninfo(void) {
  100948:	55                   	push   %ebp
  100949:	89 e5                	mov    %esp,%ebp
  10094b:	83 ec 18             	sub    $0x18,%esp
    extern char etext[], edata[], end[], kern_init[];
    cprintf("Special kernel symbols:\n");
  10094e:	c7 04 24 82 62 10 00 	movl   $0x106282,(%esp)
  100955:	e8 48 f9 ff ff       	call   1002a2 <cprintf>
    cprintf("  entry  0x%08x (phys)\n", kern_init);
  10095a:	c7 44 24 04 36 00 10 	movl   $0x100036,0x4(%esp)
  100961:	00 
  100962:	c7 04 24 9b 62 10 00 	movl   $0x10629b,(%esp)
  100969:	e8 34 f9 ff ff       	call   1002a2 <cprintf>
    cprintf("  etext  0x%08x (phys)\n", etext);
  10096e:	c7 44 24 04 7e 61 10 	movl   $0x10617e,0x4(%esp)
  100975:	00 
  100976:	c7 04 24 b3 62 10 00 	movl   $0x1062b3,(%esp)
  10097d:	e8 20 f9 ff ff       	call   1002a2 <cprintf>
    cprintf("  edata  0x%08x (phys)\n", edata);
  100982:	c7 44 24 04 36 8a 11 	movl   $0x118a36,0x4(%esp)
  100989:	00 
  10098a:	c7 04 24 cb 62 10 00 	movl   $0x1062cb,(%esp)
  100991:	e8 0c f9 ff ff       	call   1002a2 <cprintf>
    cprintf("  end    0x%08x (phys)\n", end);
  100996:	c7 44 24 04 88 bf 11 	movl   $0x11bf88,0x4(%esp)
  10099d:	00 
  10099e:	c7 04 24 e3 62 10 00 	movl   $0x1062e3,(%esp)
  1009a5:	e8 f8 f8 ff ff       	call   1002a2 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n", (end - kern_init + 1023)/1024);
  1009aa:	b8 88 bf 11 00       	mov    $0x11bf88,%eax
  1009af:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
  1009b5:	b8 36 00 10 00       	mov    $0x100036,%eax
  1009ba:	29 c2                	sub    %eax,%edx
  1009bc:	89 d0                	mov    %edx,%eax
  1009be:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
  1009c4:	85 c0                	test   %eax,%eax
  1009c6:	0f 48 c2             	cmovs  %edx,%eax
  1009c9:	c1 f8 0a             	sar    $0xa,%eax
  1009cc:	89 44 24 04          	mov    %eax,0x4(%esp)
  1009d0:	c7 04 24 fc 62 10 00 	movl   $0x1062fc,(%esp)
  1009d7:	e8 c6 f8 ff ff       	call   1002a2 <cprintf>
}
  1009dc:	90                   	nop
  1009dd:	c9                   	leave  
  1009de:	c3                   	ret    

001009df <print_debuginfo>:
/* *
 * print_debuginfo - read and print the stat information for the address @eip,
 * and info.eip_fn_addr should be the first address of the related function.
 * */
void
print_debuginfo(uintptr_t eip) {
  1009df:	55                   	push   %ebp
  1009e0:	89 e5                	mov    %esp,%ebp
  1009e2:	81 ec 48 01 00 00    	sub    $0x148,%esp
    struct eipdebuginfo info;
    if (debuginfo_eip(eip, &info) != 0) {
  1009e8:	8d 45 dc             	lea    -0x24(%ebp),%eax
  1009eb:	89 44 24 04          	mov    %eax,0x4(%esp)
  1009ef:	8b 45 08             	mov    0x8(%ebp),%eax
  1009f2:	89 04 24             	mov    %eax,(%esp)
  1009f5:	e8 1c fc ff ff       	call   100616 <debuginfo_eip>
  1009fa:	85 c0                	test   %eax,%eax
  1009fc:	74 15                	je     100a13 <print_debuginfo+0x34>
        cprintf("    <unknow>: -- 0x%08x --\n", eip);
  1009fe:	8b 45 08             	mov    0x8(%ebp),%eax
  100a01:	89 44 24 04          	mov    %eax,0x4(%esp)
  100a05:	c7 04 24 26 63 10 00 	movl   $0x106326,(%esp)
  100a0c:	e8 91 f8 ff ff       	call   1002a2 <cprintf>
        }
        fnname[j] = '\0';
        cprintf("    %s:%d: %s+%d\n", info.eip_file, info.eip_line,
                fnname, eip - info.eip_fn_addr);
    }
}
  100a11:	eb 6c                	jmp    100a7f <print_debuginfo+0xa0>
        for (j = 0; j < info.eip_fn_namelen; j ++) {
  100a13:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
  100a1a:	eb 1b                	jmp    100a37 <print_debuginfo+0x58>
            fnname[j] = info.eip_fn_name[j];
  100a1c:	8b 55 e4             	mov    -0x1c(%ebp),%edx
  100a1f:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100a22:	01 d0                	add    %edx,%eax
  100a24:	0f b6 00             	movzbl (%eax),%eax
  100a27:	8d 8d dc fe ff ff    	lea    -0x124(%ebp),%ecx
  100a2d:	8b 55 f4             	mov    -0xc(%ebp),%edx
  100a30:	01 ca                	add    %ecx,%edx
  100a32:	88 02                	mov    %al,(%edx)
        for (j = 0; j < info.eip_fn_namelen; j ++) {
  100a34:	ff 45 f4             	incl   -0xc(%ebp)
  100a37:	8b 45 e8             	mov    -0x18(%ebp),%eax
  100a3a:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  100a3d:	7c dd                	jl     100a1c <print_debuginfo+0x3d>
        fnname[j] = '\0';
  100a3f:	8d 95 dc fe ff ff    	lea    -0x124(%ebp),%edx
  100a45:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100a48:	01 d0                	add    %edx,%eax
  100a4a:	c6 00 00             	movb   $0x0,(%eax)
                fnname, eip - info.eip_fn_addr);
  100a4d:	8b 45 ec             	mov    -0x14(%ebp),%eax
        cprintf("    %s:%d: %s+%d\n", info.eip_file, info.eip_line,
  100a50:	8b 55 08             	mov    0x8(%ebp),%edx
  100a53:	89 d1                	mov    %edx,%ecx
  100a55:	29 c1                	sub    %eax,%ecx
  100a57:	8b 55 e0             	mov    -0x20(%ebp),%edx
  100a5a:	8b 45 dc             	mov    -0x24(%ebp),%eax
  100a5d:	89 4c 24 10          	mov    %ecx,0x10(%esp)
  100a61:	8d 8d dc fe ff ff    	lea    -0x124(%ebp),%ecx
  100a67:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
  100a6b:	89 54 24 08          	mov    %edx,0x8(%esp)
  100a6f:	89 44 24 04          	mov    %eax,0x4(%esp)
  100a73:	c7 04 24 42 63 10 00 	movl   $0x106342,(%esp)
  100a7a:	e8 23 f8 ff ff       	call   1002a2 <cprintf>
}
  100a7f:	90                   	nop
  100a80:	c9                   	leave  
  100a81:	c3                   	ret    

00100a82 <read_eip>:

static __noinline uint32_t
read_eip(void) {
  100a82:	55                   	push   %ebp
  100a83:	89 e5                	mov    %esp,%ebp
  100a85:	83 ec 10             	sub    $0x10,%esp
    uint32_t eip;
    asm volatile("movl 4(%%ebp), %0" : "=r" (eip));
  100a88:	8b 45 04             	mov    0x4(%ebp),%eax
  100a8b:	89 45 fc             	mov    %eax,-0x4(%ebp)
    return eip;
  100a8e:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
  100a91:	c9                   	leave  
  100a92:	c3                   	ret    

00100a93 <print_stackframe>:
 *
 * Note that, the length of ebp-chain is limited. In boot/bootasm.S, before jumping
 * to the kernel entry, the value of ebp has been set to zero, that's the boundary.
 * */
void
print_stackframe(void) {
  100a93:	55                   	push   %ebp
  100a94:	89 e5                	mov    %esp,%ebp
  100a96:	83 ec 38             	sub    $0x38,%esp
}

static inline uint32_t
read_ebp(void) {
    uint32_t ebp;
    asm volatile ("movl %%ebp, %0" : "=r" (ebp));
  100a99:	89 e8                	mov    %ebp,%eax
  100a9b:	89 45 e0             	mov    %eax,-0x20(%ebp)
    return ebp;
  100a9e:	8b 45 e0             	mov    -0x20(%ebp),%eax
      *    (3.4) call print_debuginfo(eip-1) to print the C calling function name and line number, etc.
      *    (3.5) popup a calling stackframe
      *           NOTICE: the calling funciton's return addr eip  = ss:[ebp+4]
      *                   the calling funciton's ebp = ss:[ebp]
      */
     uint32_t ebp = read_ebp(); //获取ebp的值
  100aa1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    uint32_t eip = read_eip(); //获取eip的值
  100aa4:	e8 d9 ff ff ff       	call   100a82 <read_eip>
  100aa9:	89 45 f0             	mov    %eax,-0x10(%ebp)
    int i , j ;
    for (i = 0; ebp != 0 && i < STACKFRAME_DEPTH; i ++) {
  100aac:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
  100ab3:	e9 84 00 00 00       	jmp    100b3c <print_stackframe+0xa9>
        cprintf("ebp:0x%08x eip:0x%08x args:", ebp, eip); 
  100ab8:	8b 45 f0             	mov    -0x10(%ebp),%eax
  100abb:	89 44 24 08          	mov    %eax,0x8(%esp)
  100abf:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100ac2:	89 44 24 04          	mov    %eax,0x4(%esp)
  100ac6:	c7 04 24 54 63 10 00 	movl   $0x106354,(%esp)
  100acd:	e8 d0 f7 ff ff       	call   1002a2 <cprintf>
        uint32_t *args = (uint32_t *)ebp + 2; //参数的首地址
  100ad2:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100ad5:	83 c0 08             	add    $0x8,%eax
  100ad8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
        for (j = 0; j < 4; j ++) {
  100adb:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
  100ae2:	eb 24                	jmp    100b08 <print_stackframe+0x75>
            cprintf("0x%08x ", args[j]); //打印4个参数
  100ae4:	8b 45 e8             	mov    -0x18(%ebp),%eax
  100ae7:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
  100aee:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  100af1:	01 d0                	add    %edx,%eax
  100af3:	8b 00                	mov    (%eax),%eax
  100af5:	89 44 24 04          	mov    %eax,0x4(%esp)
  100af9:	c7 04 24 70 63 10 00 	movl   $0x106370,(%esp)
  100b00:	e8 9d f7 ff ff       	call   1002a2 <cprintf>
        for (j = 0; j < 4; j ++) {
  100b05:	ff 45 e8             	incl   -0x18(%ebp)
  100b08:	83 7d e8 03          	cmpl   $0x3,-0x18(%ebp)
  100b0c:	7e d6                	jle    100ae4 <print_stackframe+0x51>
        }
        cprintf("\n");
  100b0e:	c7 04 24 78 63 10 00 	movl   $0x106378,(%esp)
  100b15:	e8 88 f7 ff ff       	call   1002a2 <cprintf>
        print_debuginfo(eip - 1);  //打印函数信息
  100b1a:	8b 45 f0             	mov    -0x10(%ebp),%eax
  100b1d:	48                   	dec    %eax
  100b1e:	89 04 24             	mov    %eax,(%esp)
  100b21:	e8 b9 fe ff ff       	call   1009df <print_debuginfo>
        eip = ((uint32_t *)ebp)[1]; //更新eip
  100b26:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100b29:	83 c0 04             	add    $0x4,%eax
  100b2c:	8b 00                	mov    (%eax),%eax
  100b2e:	89 45 f0             	mov    %eax,-0x10(%ebp)
        ebp = ((uint32_t *)ebp)[0]; //更新ebp
  100b31:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100b34:	8b 00                	mov    (%eax),%eax
  100b36:	89 45 f4             	mov    %eax,-0xc(%ebp)
    for (i = 0; ebp != 0 && i < STACKFRAME_DEPTH; i ++) {
  100b39:	ff 45 ec             	incl   -0x14(%ebp)
  100b3c:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  100b40:	74 0a                	je     100b4c <print_stackframe+0xb9>
  100b42:	83 7d ec 13          	cmpl   $0x13,-0x14(%ebp)
  100b46:	0f 8e 6c ff ff ff    	jle    100ab8 <print_stackframe+0x25>
    }
}
  100b4c:	90                   	nop
  100b4d:	c9                   	leave  
  100b4e:	c3                   	ret    

00100b4f <parse>:
#define MAXARGS         16
#define WHITESPACE      " \t\n\r"

/* parse - parse the command buffer into whitespace-separated arguments */
static int
parse(char *buf, char **argv) {
  100b4f:	55                   	push   %ebp
  100b50:	89 e5                	mov    %esp,%ebp
  100b52:	83 ec 28             	sub    $0x28,%esp
    int argc = 0;
  100b55:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    while (1) {
        // find global whitespace
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
  100b5c:	eb 0c                	jmp    100b6a <parse+0x1b>
            *buf ++ = '\0';
  100b5e:	8b 45 08             	mov    0x8(%ebp),%eax
  100b61:	8d 50 01             	lea    0x1(%eax),%edx
  100b64:	89 55 08             	mov    %edx,0x8(%ebp)
  100b67:	c6 00 00             	movb   $0x0,(%eax)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
  100b6a:	8b 45 08             	mov    0x8(%ebp),%eax
  100b6d:	0f b6 00             	movzbl (%eax),%eax
  100b70:	84 c0                	test   %al,%al
  100b72:	74 1d                	je     100b91 <parse+0x42>
  100b74:	8b 45 08             	mov    0x8(%ebp),%eax
  100b77:	0f b6 00             	movzbl (%eax),%eax
  100b7a:	0f be c0             	movsbl %al,%eax
  100b7d:	89 44 24 04          	mov    %eax,0x4(%esp)
  100b81:	c7 04 24 fc 63 10 00 	movl   $0x1063fc,(%esp)
  100b88:	e8 41 4c 00 00       	call   1057ce <strchr>
  100b8d:	85 c0                	test   %eax,%eax
  100b8f:	75 cd                	jne    100b5e <parse+0xf>
        }
        if (*buf == '\0') {
  100b91:	8b 45 08             	mov    0x8(%ebp),%eax
  100b94:	0f b6 00             	movzbl (%eax),%eax
  100b97:	84 c0                	test   %al,%al
  100b99:	74 65                	je     100c00 <parse+0xb1>
            break;
        }

        // save and scan past next arg
        if (argc == MAXARGS - 1) {
  100b9b:	83 7d f4 0f          	cmpl   $0xf,-0xc(%ebp)
  100b9f:	75 14                	jne    100bb5 <parse+0x66>
            cprintf("Too many arguments (max %d).\n", MAXARGS);
  100ba1:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
  100ba8:	00 
  100ba9:	c7 04 24 01 64 10 00 	movl   $0x106401,(%esp)
  100bb0:	e8 ed f6 ff ff       	call   1002a2 <cprintf>
        }
        argv[argc ++] = buf;
  100bb5:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100bb8:	8d 50 01             	lea    0x1(%eax),%edx
  100bbb:	89 55 f4             	mov    %edx,-0xc(%ebp)
  100bbe:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
  100bc5:	8b 45 0c             	mov    0xc(%ebp),%eax
  100bc8:	01 c2                	add    %eax,%edx
  100bca:	8b 45 08             	mov    0x8(%ebp),%eax
  100bcd:	89 02                	mov    %eax,(%edx)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
  100bcf:	eb 03                	jmp    100bd4 <parse+0x85>
            buf ++;
  100bd1:	ff 45 08             	incl   0x8(%ebp)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
  100bd4:	8b 45 08             	mov    0x8(%ebp),%eax
  100bd7:	0f b6 00             	movzbl (%eax),%eax
  100bda:	84 c0                	test   %al,%al
  100bdc:	74 8c                	je     100b6a <parse+0x1b>
  100bde:	8b 45 08             	mov    0x8(%ebp),%eax
  100be1:	0f b6 00             	movzbl (%eax),%eax
  100be4:	0f be c0             	movsbl %al,%eax
  100be7:	89 44 24 04          	mov    %eax,0x4(%esp)
  100beb:	c7 04 24 fc 63 10 00 	movl   $0x1063fc,(%esp)
  100bf2:	e8 d7 4b 00 00       	call   1057ce <strchr>
  100bf7:	85 c0                	test   %eax,%eax
  100bf9:	74 d6                	je     100bd1 <parse+0x82>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
  100bfb:	e9 6a ff ff ff       	jmp    100b6a <parse+0x1b>
            break;
  100c00:	90                   	nop
        }
    }
    return argc;
  100c01:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  100c04:	c9                   	leave  
  100c05:	c3                   	ret    

00100c06 <runcmd>:
/* *
 * runcmd - parse the input string, split it into separated arguments
 * and then lookup and invoke some related commands/
 * */
static int
runcmd(char *buf, struct trapframe *tf) {
  100c06:	55                   	push   %ebp
  100c07:	89 e5                	mov    %esp,%ebp
  100c09:	53                   	push   %ebx
  100c0a:	83 ec 64             	sub    $0x64,%esp
    char *argv[MAXARGS];
    int argc = parse(buf, argv);
  100c0d:	8d 45 b0             	lea    -0x50(%ebp),%eax
  100c10:	89 44 24 04          	mov    %eax,0x4(%esp)
  100c14:	8b 45 08             	mov    0x8(%ebp),%eax
  100c17:	89 04 24             	mov    %eax,(%esp)
  100c1a:	e8 30 ff ff ff       	call   100b4f <parse>
  100c1f:	89 45 f0             	mov    %eax,-0x10(%ebp)
    if (argc == 0) {
  100c22:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  100c26:	75 0a                	jne    100c32 <runcmd+0x2c>
        return 0;
  100c28:	b8 00 00 00 00       	mov    $0x0,%eax
  100c2d:	e9 83 00 00 00       	jmp    100cb5 <runcmd+0xaf>
    }
    int i;
    for (i = 0; i < NCOMMANDS; i ++) {
  100c32:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
  100c39:	eb 5a                	jmp    100c95 <runcmd+0x8f>
        if (strcmp(commands[i].name, argv[0]) == 0) {
  100c3b:	8b 4d b0             	mov    -0x50(%ebp),%ecx
  100c3e:	8b 55 f4             	mov    -0xc(%ebp),%edx
  100c41:	89 d0                	mov    %edx,%eax
  100c43:	01 c0                	add    %eax,%eax
  100c45:	01 d0                	add    %edx,%eax
  100c47:	c1 e0 02             	shl    $0x2,%eax
  100c4a:	05 00 80 11 00       	add    $0x118000,%eax
  100c4f:	8b 00                	mov    (%eax),%eax
  100c51:	89 4c 24 04          	mov    %ecx,0x4(%esp)
  100c55:	89 04 24             	mov    %eax,(%esp)
  100c58:	e8 d4 4a 00 00       	call   105731 <strcmp>
  100c5d:	85 c0                	test   %eax,%eax
  100c5f:	75 31                	jne    100c92 <runcmd+0x8c>
            return commands[i].func(argc - 1, argv + 1, tf);
  100c61:	8b 55 f4             	mov    -0xc(%ebp),%edx
  100c64:	89 d0                	mov    %edx,%eax
  100c66:	01 c0                	add    %eax,%eax
  100c68:	01 d0                	add    %edx,%eax
  100c6a:	c1 e0 02             	shl    $0x2,%eax
  100c6d:	05 08 80 11 00       	add    $0x118008,%eax
  100c72:	8b 10                	mov    (%eax),%edx
  100c74:	8d 45 b0             	lea    -0x50(%ebp),%eax
  100c77:	83 c0 04             	add    $0x4,%eax
  100c7a:	8b 4d f0             	mov    -0x10(%ebp),%ecx
  100c7d:	8d 59 ff             	lea    -0x1(%ecx),%ebx
  100c80:	8b 4d 0c             	mov    0xc(%ebp),%ecx
  100c83:	89 4c 24 08          	mov    %ecx,0x8(%esp)
  100c87:	89 44 24 04          	mov    %eax,0x4(%esp)
  100c8b:	89 1c 24             	mov    %ebx,(%esp)
  100c8e:	ff d2                	call   *%edx
  100c90:	eb 23                	jmp    100cb5 <runcmd+0xaf>
    for (i = 0; i < NCOMMANDS; i ++) {
  100c92:	ff 45 f4             	incl   -0xc(%ebp)
  100c95:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100c98:	83 f8 02             	cmp    $0x2,%eax
  100c9b:	76 9e                	jbe    100c3b <runcmd+0x35>
        }
    }
    cprintf("Unknown command '%s'\n", argv[0]);
  100c9d:	8b 45 b0             	mov    -0x50(%ebp),%eax
  100ca0:	89 44 24 04          	mov    %eax,0x4(%esp)
  100ca4:	c7 04 24 1f 64 10 00 	movl   $0x10641f,(%esp)
  100cab:	e8 f2 f5 ff ff       	call   1002a2 <cprintf>
    return 0;
  100cb0:	b8 00 00 00 00       	mov    $0x0,%eax
}
  100cb5:	83 c4 64             	add    $0x64,%esp
  100cb8:	5b                   	pop    %ebx
  100cb9:	5d                   	pop    %ebp
  100cba:	c3                   	ret    

00100cbb <kmonitor>:

/***** Implementations of basic kernel monitor commands *****/

void
kmonitor(struct trapframe *tf) {
  100cbb:	55                   	push   %ebp
  100cbc:	89 e5                	mov    %esp,%ebp
  100cbe:	83 ec 28             	sub    $0x28,%esp
    cprintf("Welcome to the kernel debug monitor!!\n");
  100cc1:	c7 04 24 38 64 10 00 	movl   $0x106438,(%esp)
  100cc8:	e8 d5 f5 ff ff       	call   1002a2 <cprintf>
    cprintf("Type 'help' for a list of commands.\n");
  100ccd:	c7 04 24 60 64 10 00 	movl   $0x106460,(%esp)
  100cd4:	e8 c9 f5 ff ff       	call   1002a2 <cprintf>

    if (tf != NULL) {
  100cd9:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
  100cdd:	74 0b                	je     100cea <kmonitor+0x2f>
        print_trapframe(tf);
  100cdf:	8b 45 08             	mov    0x8(%ebp),%eax
  100ce2:	89 04 24             	mov    %eax,(%esp)
  100ce5:	e8 b4 0d 00 00       	call   101a9e <print_trapframe>
    }

    char *buf;
    while (1) {
        if ((buf = readline("K> ")) != NULL) {
  100cea:	c7 04 24 85 64 10 00 	movl   $0x106485,(%esp)
  100cf1:	e8 4e f6 ff ff       	call   100344 <readline>
  100cf6:	89 45 f4             	mov    %eax,-0xc(%ebp)
  100cf9:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  100cfd:	74 eb                	je     100cea <kmonitor+0x2f>
            if (runcmd(buf, tf) < 0) {
  100cff:	8b 45 08             	mov    0x8(%ebp),%eax
  100d02:	89 44 24 04          	mov    %eax,0x4(%esp)
  100d06:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100d09:	89 04 24             	mov    %eax,(%esp)
  100d0c:	e8 f5 fe ff ff       	call   100c06 <runcmd>
  100d11:	85 c0                	test   %eax,%eax
  100d13:	78 02                	js     100d17 <kmonitor+0x5c>
        if ((buf = readline("K> ")) != NULL) {
  100d15:	eb d3                	jmp    100cea <kmonitor+0x2f>
                break;
  100d17:	90                   	nop
            }
        }
    }
}
  100d18:	90                   	nop
  100d19:	c9                   	leave  
  100d1a:	c3                   	ret    

00100d1b <mon_help>:

/* mon_help - print the information about mon_* functions */
int
mon_help(int argc, char **argv, struct trapframe *tf) {
  100d1b:	55                   	push   %ebp
  100d1c:	89 e5                	mov    %esp,%ebp
  100d1e:	83 ec 28             	sub    $0x28,%esp
    int i;
    for (i = 0; i < NCOMMANDS; i ++) {
  100d21:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
  100d28:	eb 3d                	jmp    100d67 <mon_help+0x4c>
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
  100d2a:	8b 55 f4             	mov    -0xc(%ebp),%edx
  100d2d:	89 d0                	mov    %edx,%eax
  100d2f:	01 c0                	add    %eax,%eax
  100d31:	01 d0                	add    %edx,%eax
  100d33:	c1 e0 02             	shl    $0x2,%eax
  100d36:	05 04 80 11 00       	add    $0x118004,%eax
  100d3b:	8b 08                	mov    (%eax),%ecx
  100d3d:	8b 55 f4             	mov    -0xc(%ebp),%edx
  100d40:	89 d0                	mov    %edx,%eax
  100d42:	01 c0                	add    %eax,%eax
  100d44:	01 d0                	add    %edx,%eax
  100d46:	c1 e0 02             	shl    $0x2,%eax
  100d49:	05 00 80 11 00       	add    $0x118000,%eax
  100d4e:	8b 00                	mov    (%eax),%eax
  100d50:	89 4c 24 08          	mov    %ecx,0x8(%esp)
  100d54:	89 44 24 04          	mov    %eax,0x4(%esp)
  100d58:	c7 04 24 89 64 10 00 	movl   $0x106489,(%esp)
  100d5f:	e8 3e f5 ff ff       	call   1002a2 <cprintf>
    for (i = 0; i < NCOMMANDS; i ++) {
  100d64:	ff 45 f4             	incl   -0xc(%ebp)
  100d67:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100d6a:	83 f8 02             	cmp    $0x2,%eax
  100d6d:	76 bb                	jbe    100d2a <mon_help+0xf>
    }
    return 0;
  100d6f:	b8 00 00 00 00       	mov    $0x0,%eax
}
  100d74:	c9                   	leave  
  100d75:	c3                   	ret    

00100d76 <mon_kerninfo>:
/* *
 * mon_kerninfo - call print_kerninfo in kern/debug/kdebug.c to
 * print the memory occupancy in kernel.
 * */
int
mon_kerninfo(int argc, char **argv, struct trapframe *tf) {
  100d76:	55                   	push   %ebp
  100d77:	89 e5                	mov    %esp,%ebp
  100d79:	83 ec 08             	sub    $0x8,%esp
    print_kerninfo();
  100d7c:	e8 c7 fb ff ff       	call   100948 <print_kerninfo>
    return 0;
  100d81:	b8 00 00 00 00       	mov    $0x0,%eax
}
  100d86:	c9                   	leave  
  100d87:	c3                   	ret    

00100d88 <mon_backtrace>:
/* *
 * mon_backtrace - call print_stackframe in kern/debug/kdebug.c to
 * print a backtrace of the stack.
 * */
int
mon_backtrace(int argc, char **argv, struct trapframe *tf) {
  100d88:	55                   	push   %ebp
  100d89:	89 e5                	mov    %esp,%ebp
  100d8b:	83 ec 08             	sub    $0x8,%esp
    print_stackframe();
  100d8e:	e8 00 fd ff ff       	call   100a93 <print_stackframe>
    return 0;
  100d93:	b8 00 00 00 00       	mov    $0x0,%eax
}
  100d98:	c9                   	leave  
  100d99:	c3                   	ret    

00100d9a <clock_init>:
/* *
 * clock_init - initialize 8253 clock to interrupt 100 times per second,
 * and then enable IRQ_TIMER.
 * */
void
clock_init(void) {
  100d9a:	55                   	push   %ebp
  100d9b:	89 e5                	mov    %esp,%ebp
  100d9d:	83 ec 28             	sub    $0x28,%esp
  100da0:	66 c7 45 ee 43 00    	movw   $0x43,-0x12(%ebp)
  100da6:	c6 45 ed 34          	movb   $0x34,-0x13(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
  100daa:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
  100dae:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
  100db2:	ee                   	out    %al,(%dx)
  100db3:	66 c7 45 f2 40 00    	movw   $0x40,-0xe(%ebp)
  100db9:	c6 45 f1 9c          	movb   $0x9c,-0xf(%ebp)
  100dbd:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
  100dc1:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
  100dc5:	ee                   	out    %al,(%dx)
  100dc6:	66 c7 45 f6 40 00    	movw   $0x40,-0xa(%ebp)
  100dcc:	c6 45 f5 2e          	movb   $0x2e,-0xb(%ebp)
  100dd0:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
  100dd4:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
  100dd8:	ee                   	out    %al,(%dx)
    outb(TIMER_MODE, TIMER_SEL0 | TIMER_RATEGEN | TIMER_16BIT);
    outb(IO_TIMER1, TIMER_DIV(100) % 256);
    outb(IO_TIMER1, TIMER_DIV(100) / 256);

    // initialize time counter 'ticks' to zero
    ticks = 0;
  100dd9:	c7 05 0c bf 11 00 00 	movl   $0x0,0x11bf0c
  100de0:	00 00 00 

    cprintf("++ setup timer interrupts\n");
  100de3:	c7 04 24 92 64 10 00 	movl   $0x106492,(%esp)
  100dea:	e8 b3 f4 ff ff       	call   1002a2 <cprintf>
    pic_enable(IRQ_TIMER);
  100def:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
  100df6:	e8 2e 09 00 00       	call   101729 <pic_enable>
}
  100dfb:	90                   	nop
  100dfc:	c9                   	leave  
  100dfd:	c3                   	ret    

00100dfe <__intr_save>:
#include <x86.h>
#include <intr.h>
#include <mmu.h>

static inline bool
__intr_save(void) {
  100dfe:	55                   	push   %ebp
  100dff:	89 e5                	mov    %esp,%ebp
  100e01:	83 ec 18             	sub    $0x18,%esp
}

static inline uint32_t
read_eflags(void) {
    uint32_t eflags;
    asm volatile ("pushfl; popl %0" : "=r" (eflags));
  100e04:	9c                   	pushf  
  100e05:	58                   	pop    %eax
  100e06:	89 45 f4             	mov    %eax,-0xc(%ebp)
    return eflags;
  100e09:	8b 45 f4             	mov    -0xc(%ebp),%eax
    if (read_eflags() & FL_IF) {
  100e0c:	25 00 02 00 00       	and    $0x200,%eax
  100e11:	85 c0                	test   %eax,%eax
  100e13:	74 0c                	je     100e21 <__intr_save+0x23>
        intr_disable();
  100e15:	e8 83 0a 00 00       	call   10189d <intr_disable>
        return 1;
  100e1a:	b8 01 00 00 00       	mov    $0x1,%eax
  100e1f:	eb 05                	jmp    100e26 <__intr_save+0x28>
    }
    return 0;
  100e21:	b8 00 00 00 00       	mov    $0x0,%eax
}
  100e26:	c9                   	leave  
  100e27:	c3                   	ret    

00100e28 <__intr_restore>:

static inline void
__intr_restore(bool flag) {
  100e28:	55                   	push   %ebp
  100e29:	89 e5                	mov    %esp,%ebp
  100e2b:	83 ec 08             	sub    $0x8,%esp
    if (flag) {
  100e2e:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
  100e32:	74 05                	je     100e39 <__intr_restore+0x11>
        intr_enable();
  100e34:	e8 5d 0a 00 00       	call   101896 <intr_enable>
    }
}
  100e39:	90                   	nop
  100e3a:	c9                   	leave  
  100e3b:	c3                   	ret    

00100e3c <delay>:
#include <memlayout.h>
#include <sync.h>

/* stupid I/O delay routine necessitated by historical PC design flaws */
static void
delay(void) {
  100e3c:	55                   	push   %ebp
  100e3d:	89 e5                	mov    %esp,%ebp
  100e3f:	83 ec 10             	sub    $0x10,%esp
  100e42:	66 c7 45 f2 84 00    	movw   $0x84,-0xe(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  100e48:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
  100e4c:	89 c2                	mov    %eax,%edx
  100e4e:	ec                   	in     (%dx),%al
  100e4f:	88 45 f1             	mov    %al,-0xf(%ebp)
  100e52:	66 c7 45 f6 84 00    	movw   $0x84,-0xa(%ebp)
  100e58:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
  100e5c:	89 c2                	mov    %eax,%edx
  100e5e:	ec                   	in     (%dx),%al
  100e5f:	88 45 f5             	mov    %al,-0xb(%ebp)
  100e62:	66 c7 45 fa 84 00    	movw   $0x84,-0x6(%ebp)
  100e68:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
  100e6c:	89 c2                	mov    %eax,%edx
  100e6e:	ec                   	in     (%dx),%al
  100e6f:	88 45 f9             	mov    %al,-0x7(%ebp)
  100e72:	66 c7 45 fe 84 00    	movw   $0x84,-0x2(%ebp)
  100e78:	0f b7 45 fe          	movzwl -0x2(%ebp),%eax
  100e7c:	89 c2                	mov    %eax,%edx
  100e7e:	ec                   	in     (%dx),%al
  100e7f:	88 45 fd             	mov    %al,-0x3(%ebp)
    inb(0x84);
    inb(0x84);
    inb(0x84);
    inb(0x84);
}
  100e82:	90                   	nop
  100e83:	c9                   	leave  
  100e84:	c3                   	ret    

00100e85 <cga_init>:
static uint16_t addr_6845;

/* TEXT-mode CGA/VGA display output */

static void
cga_init(void) {
  100e85:	55                   	push   %ebp
  100e86:	89 e5                	mov    %esp,%ebp
  100e88:	83 ec 20             	sub    $0x20,%esp
    volatile uint16_t *cp = (uint16_t *)(CGA_BUF + KERNBASE);
  100e8b:	c7 45 fc 00 80 0b c0 	movl   $0xc00b8000,-0x4(%ebp)
    uint16_t was = *cp;
  100e92:	8b 45 fc             	mov    -0x4(%ebp),%eax
  100e95:	0f b7 00             	movzwl (%eax),%eax
  100e98:	66 89 45 fa          	mov    %ax,-0x6(%ebp)
    *cp = (uint16_t) 0xA55A;
  100e9c:	8b 45 fc             	mov    -0x4(%ebp),%eax
  100e9f:	66 c7 00 5a a5       	movw   $0xa55a,(%eax)
    if (*cp != 0xA55A) {
  100ea4:	8b 45 fc             	mov    -0x4(%ebp),%eax
  100ea7:	0f b7 00             	movzwl (%eax),%eax
  100eaa:	0f b7 c0             	movzwl %ax,%eax
  100ead:	3d 5a a5 00 00       	cmp    $0xa55a,%eax
  100eb2:	74 12                	je     100ec6 <cga_init+0x41>
        cp = (uint16_t*)(MONO_BUF + KERNBASE);
  100eb4:	c7 45 fc 00 00 0b c0 	movl   $0xc00b0000,-0x4(%ebp)
        addr_6845 = MONO_BASE;
  100ebb:	66 c7 05 46 b4 11 00 	movw   $0x3b4,0x11b446
  100ec2:	b4 03 
  100ec4:	eb 13                	jmp    100ed9 <cga_init+0x54>
    } else {
        *cp = was;
  100ec6:	8b 45 fc             	mov    -0x4(%ebp),%eax
  100ec9:	0f b7 55 fa          	movzwl -0x6(%ebp),%edx
  100ecd:	66 89 10             	mov    %dx,(%eax)
        addr_6845 = CGA_BASE;
  100ed0:	66 c7 05 46 b4 11 00 	movw   $0x3d4,0x11b446
  100ed7:	d4 03 
    }

    // Extract cursor location
    uint32_t pos;
    outb(addr_6845, 14);
  100ed9:	0f b7 05 46 b4 11 00 	movzwl 0x11b446,%eax
  100ee0:	66 89 45 e6          	mov    %ax,-0x1a(%ebp)
  100ee4:	c6 45 e5 0e          	movb   $0xe,-0x1b(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
  100ee8:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
  100eec:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
  100ef0:	ee                   	out    %al,(%dx)
    pos = inb(addr_6845 + 1) << 8;
  100ef1:	0f b7 05 46 b4 11 00 	movzwl 0x11b446,%eax
  100ef8:	40                   	inc    %eax
  100ef9:	0f b7 c0             	movzwl %ax,%eax
  100efc:	66 89 45 ea          	mov    %ax,-0x16(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  100f00:	0f b7 45 ea          	movzwl -0x16(%ebp),%eax
  100f04:	89 c2                	mov    %eax,%edx
  100f06:	ec                   	in     (%dx),%al
  100f07:	88 45 e9             	mov    %al,-0x17(%ebp)
    return data;
  100f0a:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
  100f0e:	0f b6 c0             	movzbl %al,%eax
  100f11:	c1 e0 08             	shl    $0x8,%eax
  100f14:	89 45 f4             	mov    %eax,-0xc(%ebp)
    outb(addr_6845, 15);
  100f17:	0f b7 05 46 b4 11 00 	movzwl 0x11b446,%eax
  100f1e:	66 89 45 ee          	mov    %ax,-0x12(%ebp)
  100f22:	c6 45 ed 0f          	movb   $0xf,-0x13(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
  100f26:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
  100f2a:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
  100f2e:	ee                   	out    %al,(%dx)
    pos |= inb(addr_6845 + 1);
  100f2f:	0f b7 05 46 b4 11 00 	movzwl 0x11b446,%eax
  100f36:	40                   	inc    %eax
  100f37:	0f b7 c0             	movzwl %ax,%eax
  100f3a:	66 89 45 f2          	mov    %ax,-0xe(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  100f3e:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
  100f42:	89 c2                	mov    %eax,%edx
  100f44:	ec                   	in     (%dx),%al
  100f45:	88 45 f1             	mov    %al,-0xf(%ebp)
    return data;
  100f48:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
  100f4c:	0f b6 c0             	movzbl %al,%eax
  100f4f:	09 45 f4             	or     %eax,-0xc(%ebp)

    crt_buf = (uint16_t*) cp;
  100f52:	8b 45 fc             	mov    -0x4(%ebp),%eax
  100f55:	a3 40 b4 11 00       	mov    %eax,0x11b440
    crt_pos = pos;
  100f5a:	8b 45 f4             	mov    -0xc(%ebp),%eax
  100f5d:	0f b7 c0             	movzwl %ax,%eax
  100f60:	66 a3 44 b4 11 00    	mov    %ax,0x11b444
}
  100f66:	90                   	nop
  100f67:	c9                   	leave  
  100f68:	c3                   	ret    

00100f69 <serial_init>:

static bool serial_exists = 0;

static void
serial_init(void) {
  100f69:	55                   	push   %ebp
  100f6a:	89 e5                	mov    %esp,%ebp
  100f6c:	83 ec 48             	sub    $0x48,%esp
  100f6f:	66 c7 45 d2 fa 03    	movw   $0x3fa,-0x2e(%ebp)
  100f75:	c6 45 d1 00          	movb   $0x0,-0x2f(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
  100f79:	0f b6 45 d1          	movzbl -0x2f(%ebp),%eax
  100f7d:	0f b7 55 d2          	movzwl -0x2e(%ebp),%edx
  100f81:	ee                   	out    %al,(%dx)
  100f82:	66 c7 45 d6 fb 03    	movw   $0x3fb,-0x2a(%ebp)
  100f88:	c6 45 d5 80          	movb   $0x80,-0x2b(%ebp)
  100f8c:	0f b6 45 d5          	movzbl -0x2b(%ebp),%eax
  100f90:	0f b7 55 d6          	movzwl -0x2a(%ebp),%edx
  100f94:	ee                   	out    %al,(%dx)
  100f95:	66 c7 45 da f8 03    	movw   $0x3f8,-0x26(%ebp)
  100f9b:	c6 45 d9 0c          	movb   $0xc,-0x27(%ebp)
  100f9f:	0f b6 45 d9          	movzbl -0x27(%ebp),%eax
  100fa3:	0f b7 55 da          	movzwl -0x26(%ebp),%edx
  100fa7:	ee                   	out    %al,(%dx)
  100fa8:	66 c7 45 de f9 03    	movw   $0x3f9,-0x22(%ebp)
  100fae:	c6 45 dd 00          	movb   $0x0,-0x23(%ebp)
  100fb2:	0f b6 45 dd          	movzbl -0x23(%ebp),%eax
  100fb6:	0f b7 55 de          	movzwl -0x22(%ebp),%edx
  100fba:	ee                   	out    %al,(%dx)
  100fbb:	66 c7 45 e2 fb 03    	movw   $0x3fb,-0x1e(%ebp)
  100fc1:	c6 45 e1 03          	movb   $0x3,-0x1f(%ebp)
  100fc5:	0f b6 45 e1          	movzbl -0x1f(%ebp),%eax
  100fc9:	0f b7 55 e2          	movzwl -0x1e(%ebp),%edx
  100fcd:	ee                   	out    %al,(%dx)
  100fce:	66 c7 45 e6 fc 03    	movw   $0x3fc,-0x1a(%ebp)
  100fd4:	c6 45 e5 00          	movb   $0x0,-0x1b(%ebp)
  100fd8:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
  100fdc:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
  100fe0:	ee                   	out    %al,(%dx)
  100fe1:	66 c7 45 ea f9 03    	movw   $0x3f9,-0x16(%ebp)
  100fe7:	c6 45 e9 01          	movb   $0x1,-0x17(%ebp)
  100feb:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
  100fef:	0f b7 55 ea          	movzwl -0x16(%ebp),%edx
  100ff3:	ee                   	out    %al,(%dx)
  100ff4:	66 c7 45 ee fd 03    	movw   $0x3fd,-0x12(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  100ffa:	0f b7 45 ee          	movzwl -0x12(%ebp),%eax
  100ffe:	89 c2                	mov    %eax,%edx
  101000:	ec                   	in     (%dx),%al
  101001:	88 45 ed             	mov    %al,-0x13(%ebp)
    return data;
  101004:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
    // Enable rcv interrupts
    outb(COM1 + COM_IER, COM_IER_RDI);

    // Clear any preexisting overrun indications and interrupts
    // Serial port doesn't exist if COM_LSR returns 0xFF
    serial_exists = (inb(COM1 + COM_LSR) != 0xFF);
  101008:	3c ff                	cmp    $0xff,%al
  10100a:	0f 95 c0             	setne  %al
  10100d:	0f b6 c0             	movzbl %al,%eax
  101010:	a3 48 b4 11 00       	mov    %eax,0x11b448
  101015:	66 c7 45 f2 fa 03    	movw   $0x3fa,-0xe(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  10101b:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
  10101f:	89 c2                	mov    %eax,%edx
  101021:	ec                   	in     (%dx),%al
  101022:	88 45 f1             	mov    %al,-0xf(%ebp)
  101025:	66 c7 45 f6 f8 03    	movw   $0x3f8,-0xa(%ebp)
  10102b:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
  10102f:	89 c2                	mov    %eax,%edx
  101031:	ec                   	in     (%dx),%al
  101032:	88 45 f5             	mov    %al,-0xb(%ebp)
    (void) inb(COM1+COM_IIR);
    (void) inb(COM1+COM_RX);

    if (serial_exists) {
  101035:	a1 48 b4 11 00       	mov    0x11b448,%eax
  10103a:	85 c0                	test   %eax,%eax
  10103c:	74 0c                	je     10104a <serial_init+0xe1>
        pic_enable(IRQ_COM1);
  10103e:	c7 04 24 04 00 00 00 	movl   $0x4,(%esp)
  101045:	e8 df 06 00 00       	call   101729 <pic_enable>
    }
}
  10104a:	90                   	nop
  10104b:	c9                   	leave  
  10104c:	c3                   	ret    

0010104d <lpt_putc_sub>:

static void
lpt_putc_sub(int c) {
  10104d:	55                   	push   %ebp
  10104e:	89 e5                	mov    %esp,%ebp
  101050:	83 ec 20             	sub    $0x20,%esp
    int i;
    for (i = 0; !(inb(LPTPORT + 1) & 0x80) && i < 12800; i ++) {
  101053:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
  10105a:	eb 08                	jmp    101064 <lpt_putc_sub+0x17>
        delay();
  10105c:	e8 db fd ff ff       	call   100e3c <delay>
    for (i = 0; !(inb(LPTPORT + 1) & 0x80) && i < 12800; i ++) {
  101061:	ff 45 fc             	incl   -0x4(%ebp)
  101064:	66 c7 45 fa 79 03    	movw   $0x379,-0x6(%ebp)
  10106a:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
  10106e:	89 c2                	mov    %eax,%edx
  101070:	ec                   	in     (%dx),%al
  101071:	88 45 f9             	mov    %al,-0x7(%ebp)
    return data;
  101074:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
  101078:	84 c0                	test   %al,%al
  10107a:	78 09                	js     101085 <lpt_putc_sub+0x38>
  10107c:	81 7d fc ff 31 00 00 	cmpl   $0x31ff,-0x4(%ebp)
  101083:	7e d7                	jle    10105c <lpt_putc_sub+0xf>
    }
    outb(LPTPORT + 0, c);
  101085:	8b 45 08             	mov    0x8(%ebp),%eax
  101088:	0f b6 c0             	movzbl %al,%eax
  10108b:	66 c7 45 ee 78 03    	movw   $0x378,-0x12(%ebp)
  101091:	88 45 ed             	mov    %al,-0x13(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
  101094:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
  101098:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
  10109c:	ee                   	out    %al,(%dx)
  10109d:	66 c7 45 f2 7a 03    	movw   $0x37a,-0xe(%ebp)
  1010a3:	c6 45 f1 0d          	movb   $0xd,-0xf(%ebp)
  1010a7:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
  1010ab:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
  1010af:	ee                   	out    %al,(%dx)
  1010b0:	66 c7 45 f6 7a 03    	movw   $0x37a,-0xa(%ebp)
  1010b6:	c6 45 f5 08          	movb   $0x8,-0xb(%ebp)
  1010ba:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
  1010be:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
  1010c2:	ee                   	out    %al,(%dx)
    outb(LPTPORT + 2, 0x08 | 0x04 | 0x01);
    outb(LPTPORT + 2, 0x08);
}
  1010c3:	90                   	nop
  1010c4:	c9                   	leave  
  1010c5:	c3                   	ret    

001010c6 <lpt_putc>:

/* lpt_putc - copy console output to parallel port */
static void
lpt_putc(int c) {
  1010c6:	55                   	push   %ebp
  1010c7:	89 e5                	mov    %esp,%ebp
  1010c9:	83 ec 04             	sub    $0x4,%esp
    if (c != '\b') {
  1010cc:	83 7d 08 08          	cmpl   $0x8,0x8(%ebp)
  1010d0:	74 0d                	je     1010df <lpt_putc+0x19>
        lpt_putc_sub(c);
  1010d2:	8b 45 08             	mov    0x8(%ebp),%eax
  1010d5:	89 04 24             	mov    %eax,(%esp)
  1010d8:	e8 70 ff ff ff       	call   10104d <lpt_putc_sub>
    else {
        lpt_putc_sub('\b');
        lpt_putc_sub(' ');
        lpt_putc_sub('\b');
    }
}
  1010dd:	eb 24                	jmp    101103 <lpt_putc+0x3d>
        lpt_putc_sub('\b');
  1010df:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
  1010e6:	e8 62 ff ff ff       	call   10104d <lpt_putc_sub>
        lpt_putc_sub(' ');
  1010eb:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
  1010f2:	e8 56 ff ff ff       	call   10104d <lpt_putc_sub>
        lpt_putc_sub('\b');
  1010f7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
  1010fe:	e8 4a ff ff ff       	call   10104d <lpt_putc_sub>
}
  101103:	90                   	nop
  101104:	c9                   	leave  
  101105:	c3                   	ret    

00101106 <cga_putc>:

/* cga_putc - print character to console */
static void
cga_putc(int c) {
  101106:	55                   	push   %ebp
  101107:	89 e5                	mov    %esp,%ebp
  101109:	53                   	push   %ebx
  10110a:	83 ec 34             	sub    $0x34,%esp
    // set black on white
    if (!(c & ~0xFF)) {
  10110d:	8b 45 08             	mov    0x8(%ebp),%eax
  101110:	25 00 ff ff ff       	and    $0xffffff00,%eax
  101115:	85 c0                	test   %eax,%eax
  101117:	75 07                	jne    101120 <cga_putc+0x1a>
        c |= 0x0700;
  101119:	81 4d 08 00 07 00 00 	orl    $0x700,0x8(%ebp)
    }

    switch (c & 0xff) {
  101120:	8b 45 08             	mov    0x8(%ebp),%eax
  101123:	0f b6 c0             	movzbl %al,%eax
  101126:	83 f8 0a             	cmp    $0xa,%eax
  101129:	74 55                	je     101180 <cga_putc+0x7a>
  10112b:	83 f8 0d             	cmp    $0xd,%eax
  10112e:	74 63                	je     101193 <cga_putc+0x8d>
  101130:	83 f8 08             	cmp    $0x8,%eax
  101133:	0f 85 94 00 00 00    	jne    1011cd <cga_putc+0xc7>
    case '\b':
        if (crt_pos > 0) {
  101139:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  101140:	85 c0                	test   %eax,%eax
  101142:	0f 84 af 00 00 00    	je     1011f7 <cga_putc+0xf1>
            crt_pos --;
  101148:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  10114f:	48                   	dec    %eax
  101150:	0f b7 c0             	movzwl %ax,%eax
  101153:	66 a3 44 b4 11 00    	mov    %ax,0x11b444
            crt_buf[crt_pos] = (c & ~0xff) | ' ';
  101159:	8b 45 08             	mov    0x8(%ebp),%eax
  10115c:	98                   	cwtl   
  10115d:	25 00 ff ff ff       	and    $0xffffff00,%eax
  101162:	98                   	cwtl   
  101163:	83 c8 20             	or     $0x20,%eax
  101166:	98                   	cwtl   
  101167:	8b 15 40 b4 11 00    	mov    0x11b440,%edx
  10116d:	0f b7 0d 44 b4 11 00 	movzwl 0x11b444,%ecx
  101174:	01 c9                	add    %ecx,%ecx
  101176:	01 ca                	add    %ecx,%edx
  101178:	0f b7 c0             	movzwl %ax,%eax
  10117b:	66 89 02             	mov    %ax,(%edx)
        }
        break;
  10117e:	eb 77                	jmp    1011f7 <cga_putc+0xf1>
    case '\n':
        crt_pos += CRT_COLS;
  101180:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  101187:	83 c0 50             	add    $0x50,%eax
  10118a:	0f b7 c0             	movzwl %ax,%eax
  10118d:	66 a3 44 b4 11 00    	mov    %ax,0x11b444
    case '\r':
        crt_pos -= (crt_pos % CRT_COLS);
  101193:	0f b7 1d 44 b4 11 00 	movzwl 0x11b444,%ebx
  10119a:	0f b7 0d 44 b4 11 00 	movzwl 0x11b444,%ecx
  1011a1:	ba cd cc cc cc       	mov    $0xcccccccd,%edx
  1011a6:	89 c8                	mov    %ecx,%eax
  1011a8:	f7 e2                	mul    %edx
  1011aa:	c1 ea 06             	shr    $0x6,%edx
  1011ad:	89 d0                	mov    %edx,%eax
  1011af:	c1 e0 02             	shl    $0x2,%eax
  1011b2:	01 d0                	add    %edx,%eax
  1011b4:	c1 e0 04             	shl    $0x4,%eax
  1011b7:	29 c1                	sub    %eax,%ecx
  1011b9:	89 c8                	mov    %ecx,%eax
  1011bb:	0f b7 c0             	movzwl %ax,%eax
  1011be:	29 c3                	sub    %eax,%ebx
  1011c0:	89 d8                	mov    %ebx,%eax
  1011c2:	0f b7 c0             	movzwl %ax,%eax
  1011c5:	66 a3 44 b4 11 00    	mov    %ax,0x11b444
        break;
  1011cb:	eb 2b                	jmp    1011f8 <cga_putc+0xf2>
    default:
        crt_buf[crt_pos ++] = c;     // write the character
  1011cd:	8b 0d 40 b4 11 00    	mov    0x11b440,%ecx
  1011d3:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  1011da:	8d 50 01             	lea    0x1(%eax),%edx
  1011dd:	0f b7 d2             	movzwl %dx,%edx
  1011e0:	66 89 15 44 b4 11 00 	mov    %dx,0x11b444
  1011e7:	01 c0                	add    %eax,%eax
  1011e9:	8d 14 01             	lea    (%ecx,%eax,1),%edx
  1011ec:	8b 45 08             	mov    0x8(%ebp),%eax
  1011ef:	0f b7 c0             	movzwl %ax,%eax
  1011f2:	66 89 02             	mov    %ax,(%edx)
        break;
  1011f5:	eb 01                	jmp    1011f8 <cga_putc+0xf2>
        break;
  1011f7:	90                   	nop
    }

    // What is the purpose of this?
    if (crt_pos >= CRT_SIZE) {
  1011f8:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  1011ff:	3d cf 07 00 00       	cmp    $0x7cf,%eax
  101204:	76 5d                	jbe    101263 <cga_putc+0x15d>
        int i;
        memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
  101206:	a1 40 b4 11 00       	mov    0x11b440,%eax
  10120b:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
  101211:	a1 40 b4 11 00       	mov    0x11b440,%eax
  101216:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
  10121d:	00 
  10121e:	89 54 24 04          	mov    %edx,0x4(%esp)
  101222:	89 04 24             	mov    %eax,(%esp)
  101225:	e8 9a 47 00 00       	call   1059c4 <memmove>
        for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i ++) {
  10122a:	c7 45 f4 80 07 00 00 	movl   $0x780,-0xc(%ebp)
  101231:	eb 14                	jmp    101247 <cga_putc+0x141>
            crt_buf[i] = 0x0700 | ' ';
  101233:	a1 40 b4 11 00       	mov    0x11b440,%eax
  101238:	8b 55 f4             	mov    -0xc(%ebp),%edx
  10123b:	01 d2                	add    %edx,%edx
  10123d:	01 d0                	add    %edx,%eax
  10123f:	66 c7 00 20 07       	movw   $0x720,(%eax)
        for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i ++) {
  101244:	ff 45 f4             	incl   -0xc(%ebp)
  101247:	81 7d f4 cf 07 00 00 	cmpl   $0x7cf,-0xc(%ebp)
  10124e:	7e e3                	jle    101233 <cga_putc+0x12d>
        }
        crt_pos -= CRT_COLS;
  101250:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  101257:	83 e8 50             	sub    $0x50,%eax
  10125a:	0f b7 c0             	movzwl %ax,%eax
  10125d:	66 a3 44 b4 11 00    	mov    %ax,0x11b444
    }

    // move that little blinky thing
    outb(addr_6845, 14);
  101263:	0f b7 05 46 b4 11 00 	movzwl 0x11b446,%eax
  10126a:	66 89 45 e6          	mov    %ax,-0x1a(%ebp)
  10126e:	c6 45 e5 0e          	movb   $0xe,-0x1b(%ebp)
  101272:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
  101276:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
  10127a:	ee                   	out    %al,(%dx)
    outb(addr_6845 + 1, crt_pos >> 8);
  10127b:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  101282:	c1 e8 08             	shr    $0x8,%eax
  101285:	0f b7 c0             	movzwl %ax,%eax
  101288:	0f b6 c0             	movzbl %al,%eax
  10128b:	0f b7 15 46 b4 11 00 	movzwl 0x11b446,%edx
  101292:	42                   	inc    %edx
  101293:	0f b7 d2             	movzwl %dx,%edx
  101296:	66 89 55 ea          	mov    %dx,-0x16(%ebp)
  10129a:	88 45 e9             	mov    %al,-0x17(%ebp)
  10129d:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
  1012a1:	0f b7 55 ea          	movzwl -0x16(%ebp),%edx
  1012a5:	ee                   	out    %al,(%dx)
    outb(addr_6845, 15);
  1012a6:	0f b7 05 46 b4 11 00 	movzwl 0x11b446,%eax
  1012ad:	66 89 45 ee          	mov    %ax,-0x12(%ebp)
  1012b1:	c6 45 ed 0f          	movb   $0xf,-0x13(%ebp)
  1012b5:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
  1012b9:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
  1012bd:	ee                   	out    %al,(%dx)
    outb(addr_6845 + 1, crt_pos);
  1012be:	0f b7 05 44 b4 11 00 	movzwl 0x11b444,%eax
  1012c5:	0f b6 c0             	movzbl %al,%eax
  1012c8:	0f b7 15 46 b4 11 00 	movzwl 0x11b446,%edx
  1012cf:	42                   	inc    %edx
  1012d0:	0f b7 d2             	movzwl %dx,%edx
  1012d3:	66 89 55 f2          	mov    %dx,-0xe(%ebp)
  1012d7:	88 45 f1             	mov    %al,-0xf(%ebp)
  1012da:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
  1012de:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
  1012e2:	ee                   	out    %al,(%dx)
}
  1012e3:	90                   	nop
  1012e4:	83 c4 34             	add    $0x34,%esp
  1012e7:	5b                   	pop    %ebx
  1012e8:	5d                   	pop    %ebp
  1012e9:	c3                   	ret    

001012ea <serial_putc_sub>:

static void
serial_putc_sub(int c) {
  1012ea:	55                   	push   %ebp
  1012eb:	89 e5                	mov    %esp,%ebp
  1012ed:	83 ec 10             	sub    $0x10,%esp
    int i;
    for (i = 0; !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800; i ++) {
  1012f0:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
  1012f7:	eb 08                	jmp    101301 <serial_putc_sub+0x17>
        delay();
  1012f9:	e8 3e fb ff ff       	call   100e3c <delay>
    for (i = 0; !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800; i ++) {
  1012fe:	ff 45 fc             	incl   -0x4(%ebp)
  101301:	66 c7 45 fa fd 03    	movw   $0x3fd,-0x6(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  101307:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
  10130b:	89 c2                	mov    %eax,%edx
  10130d:	ec                   	in     (%dx),%al
  10130e:	88 45 f9             	mov    %al,-0x7(%ebp)
    return data;
  101311:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
  101315:	0f b6 c0             	movzbl %al,%eax
  101318:	83 e0 20             	and    $0x20,%eax
  10131b:	85 c0                	test   %eax,%eax
  10131d:	75 09                	jne    101328 <serial_putc_sub+0x3e>
  10131f:	81 7d fc ff 31 00 00 	cmpl   $0x31ff,-0x4(%ebp)
  101326:	7e d1                	jle    1012f9 <serial_putc_sub+0xf>
    }
    outb(COM1 + COM_TX, c);
  101328:	8b 45 08             	mov    0x8(%ebp),%eax
  10132b:	0f b6 c0             	movzbl %al,%eax
  10132e:	66 c7 45 f6 f8 03    	movw   $0x3f8,-0xa(%ebp)
  101334:	88 45 f5             	mov    %al,-0xb(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
  101337:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
  10133b:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
  10133f:	ee                   	out    %al,(%dx)
}
  101340:	90                   	nop
  101341:	c9                   	leave  
  101342:	c3                   	ret    

00101343 <serial_putc>:

/* serial_putc - print character to serial port */
static void
serial_putc(int c) {
  101343:	55                   	push   %ebp
  101344:	89 e5                	mov    %esp,%ebp
  101346:	83 ec 04             	sub    $0x4,%esp
    if (c != '\b') {
  101349:	83 7d 08 08          	cmpl   $0x8,0x8(%ebp)
  10134d:	74 0d                	je     10135c <serial_putc+0x19>
        serial_putc_sub(c);
  10134f:	8b 45 08             	mov    0x8(%ebp),%eax
  101352:	89 04 24             	mov    %eax,(%esp)
  101355:	e8 90 ff ff ff       	call   1012ea <serial_putc_sub>
    else {
        serial_putc_sub('\b');
        serial_putc_sub(' ');
        serial_putc_sub('\b');
    }
}
  10135a:	eb 24                	jmp    101380 <serial_putc+0x3d>
        serial_putc_sub('\b');
  10135c:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
  101363:	e8 82 ff ff ff       	call   1012ea <serial_putc_sub>
        serial_putc_sub(' ');
  101368:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
  10136f:	e8 76 ff ff ff       	call   1012ea <serial_putc_sub>
        serial_putc_sub('\b');
  101374:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
  10137b:	e8 6a ff ff ff       	call   1012ea <serial_putc_sub>
}
  101380:	90                   	nop
  101381:	c9                   	leave  
  101382:	c3                   	ret    

00101383 <cons_intr>:
/* *
 * cons_intr - called by device interrupt routines to feed input
 * characters into the circular console input buffer.
 * */
static void
cons_intr(int (*proc)(void)) {
  101383:	55                   	push   %ebp
  101384:	89 e5                	mov    %esp,%ebp
  101386:	83 ec 18             	sub    $0x18,%esp
    int c;
    while ((c = (*proc)()) != -1) {
  101389:	eb 33                	jmp    1013be <cons_intr+0x3b>
        if (c != 0) {
  10138b:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  10138f:	74 2d                	je     1013be <cons_intr+0x3b>
            cons.buf[cons.wpos ++] = c;
  101391:	a1 64 b6 11 00       	mov    0x11b664,%eax
  101396:	8d 50 01             	lea    0x1(%eax),%edx
  101399:	89 15 64 b6 11 00    	mov    %edx,0x11b664
  10139f:	8b 55 f4             	mov    -0xc(%ebp),%edx
  1013a2:	88 90 60 b4 11 00    	mov    %dl,0x11b460(%eax)
            if (cons.wpos == CONSBUFSIZE) {
  1013a8:	a1 64 b6 11 00       	mov    0x11b664,%eax
  1013ad:	3d 00 02 00 00       	cmp    $0x200,%eax
  1013b2:	75 0a                	jne    1013be <cons_intr+0x3b>
                cons.wpos = 0;
  1013b4:	c7 05 64 b6 11 00 00 	movl   $0x0,0x11b664
  1013bb:	00 00 00 
    while ((c = (*proc)()) != -1) {
  1013be:	8b 45 08             	mov    0x8(%ebp),%eax
  1013c1:	ff d0                	call   *%eax
  1013c3:	89 45 f4             	mov    %eax,-0xc(%ebp)
  1013c6:	83 7d f4 ff          	cmpl   $0xffffffff,-0xc(%ebp)
  1013ca:	75 bf                	jne    10138b <cons_intr+0x8>
            }
        }
    }
}
  1013cc:	90                   	nop
  1013cd:	c9                   	leave  
  1013ce:	c3                   	ret    

001013cf <serial_proc_data>:

/* serial_proc_data - get data from serial port */
static int
serial_proc_data(void) {
  1013cf:	55                   	push   %ebp
  1013d0:	89 e5                	mov    %esp,%ebp
  1013d2:	83 ec 10             	sub    $0x10,%esp
  1013d5:	66 c7 45 fa fd 03    	movw   $0x3fd,-0x6(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  1013db:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
  1013df:	89 c2                	mov    %eax,%edx
  1013e1:	ec                   	in     (%dx),%al
  1013e2:	88 45 f9             	mov    %al,-0x7(%ebp)
    return data;
  1013e5:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
    if (!(inb(COM1 + COM_LSR) & COM_LSR_DATA)) {
  1013e9:	0f b6 c0             	movzbl %al,%eax
  1013ec:	83 e0 01             	and    $0x1,%eax
  1013ef:	85 c0                	test   %eax,%eax
  1013f1:	75 07                	jne    1013fa <serial_proc_data+0x2b>
        return -1;
  1013f3:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  1013f8:	eb 2a                	jmp    101424 <serial_proc_data+0x55>
  1013fa:	66 c7 45 f6 f8 03    	movw   $0x3f8,-0xa(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  101400:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
  101404:	89 c2                	mov    %eax,%edx
  101406:	ec                   	in     (%dx),%al
  101407:	88 45 f5             	mov    %al,-0xb(%ebp)
    return data;
  10140a:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
    }
    int c = inb(COM1 + COM_RX);
  10140e:	0f b6 c0             	movzbl %al,%eax
  101411:	89 45 fc             	mov    %eax,-0x4(%ebp)
    if (c == 127) {
  101414:	83 7d fc 7f          	cmpl   $0x7f,-0x4(%ebp)
  101418:	75 07                	jne    101421 <serial_proc_data+0x52>
        c = '\b';
  10141a:	c7 45 fc 08 00 00 00 	movl   $0x8,-0x4(%ebp)
    }
    return c;
  101421:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
  101424:	c9                   	leave  
  101425:	c3                   	ret    

00101426 <serial_intr>:

/* serial_intr - try to feed input characters from serial port */
void
serial_intr(void) {
  101426:	55                   	push   %ebp
  101427:	89 e5                	mov    %esp,%ebp
  101429:	83 ec 18             	sub    $0x18,%esp
    if (serial_exists) {
  10142c:	a1 48 b4 11 00       	mov    0x11b448,%eax
  101431:	85 c0                	test   %eax,%eax
  101433:	74 0c                	je     101441 <serial_intr+0x1b>
        cons_intr(serial_proc_data);
  101435:	c7 04 24 cf 13 10 00 	movl   $0x1013cf,(%esp)
  10143c:	e8 42 ff ff ff       	call   101383 <cons_intr>
    }
}
  101441:	90                   	nop
  101442:	c9                   	leave  
  101443:	c3                   	ret    

00101444 <kbd_proc_data>:
 *
 * The kbd_proc_data() function gets data from the keyboard.
 * If we finish a character, return it, else 0. And return -1 if no data.
 * */
static int
kbd_proc_data(void) {
  101444:	55                   	push   %ebp
  101445:	89 e5                	mov    %esp,%ebp
  101447:	83 ec 38             	sub    $0x38,%esp
  10144a:	66 c7 45 f0 64 00    	movw   $0x64,-0x10(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  101450:	8b 45 f0             	mov    -0x10(%ebp),%eax
  101453:	89 c2                	mov    %eax,%edx
  101455:	ec                   	in     (%dx),%al
  101456:	88 45 ef             	mov    %al,-0x11(%ebp)
    return data;
  101459:	0f b6 45 ef          	movzbl -0x11(%ebp),%eax
    int c;
    uint8_t data;
    static uint32_t shift;

    if ((inb(KBSTATP) & KBS_DIB) == 0) {
  10145d:	0f b6 c0             	movzbl %al,%eax
  101460:	83 e0 01             	and    $0x1,%eax
  101463:	85 c0                	test   %eax,%eax
  101465:	75 0a                	jne    101471 <kbd_proc_data+0x2d>
        return -1;
  101467:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
  10146c:	e9 55 01 00 00       	jmp    1015c6 <kbd_proc_data+0x182>
  101471:	66 c7 45 ec 60 00    	movw   $0x60,-0x14(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
  101477:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10147a:	89 c2                	mov    %eax,%edx
  10147c:	ec                   	in     (%dx),%al
  10147d:	88 45 eb             	mov    %al,-0x15(%ebp)
    return data;
  101480:	0f b6 45 eb          	movzbl -0x15(%ebp),%eax
    }

    data = inb(KBDATAP);
  101484:	88 45 f3             	mov    %al,-0xd(%ebp)

    if (data == 0xE0) {
  101487:	80 7d f3 e0          	cmpb   $0xe0,-0xd(%ebp)
  10148b:	75 17                	jne    1014a4 <kbd_proc_data+0x60>
        // E0 escape character
        shift |= E0ESC;
  10148d:	a1 68 b6 11 00       	mov    0x11b668,%eax
  101492:	83 c8 40             	or     $0x40,%eax
  101495:	a3 68 b6 11 00       	mov    %eax,0x11b668
        return 0;
  10149a:	b8 00 00 00 00       	mov    $0x0,%eax
  10149f:	e9 22 01 00 00       	jmp    1015c6 <kbd_proc_data+0x182>
    } else if (data & 0x80) {
  1014a4:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
  1014a8:	84 c0                	test   %al,%al
  1014aa:	79 45                	jns    1014f1 <kbd_proc_data+0xad>
        // Key released
        data = (shift & E0ESC ? data : data & 0x7F);
  1014ac:	a1 68 b6 11 00       	mov    0x11b668,%eax
  1014b1:	83 e0 40             	and    $0x40,%eax
  1014b4:	85 c0                	test   %eax,%eax
  1014b6:	75 08                	jne    1014c0 <kbd_proc_data+0x7c>
  1014b8:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
  1014bc:	24 7f                	and    $0x7f,%al
  1014be:	eb 04                	jmp    1014c4 <kbd_proc_data+0x80>
  1014c0:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
  1014c4:	88 45 f3             	mov    %al,-0xd(%ebp)
        shift &= ~(shiftcode[data] | E0ESC);
  1014c7:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
  1014cb:	0f b6 80 40 80 11 00 	movzbl 0x118040(%eax),%eax
  1014d2:	0c 40                	or     $0x40,%al
  1014d4:	0f b6 c0             	movzbl %al,%eax
  1014d7:	f7 d0                	not    %eax
  1014d9:	89 c2                	mov    %eax,%edx
  1014db:	a1 68 b6 11 00       	mov    0x11b668,%eax
  1014e0:	21 d0                	and    %edx,%eax
  1014e2:	a3 68 b6 11 00       	mov    %eax,0x11b668
        return 0;
  1014e7:	b8 00 00 00 00       	mov    $0x0,%eax
  1014ec:	e9 d5 00 00 00       	jmp    1015c6 <kbd_proc_data+0x182>
    } else if (shift & E0ESC) {
  1014f1:	a1 68 b6 11 00       	mov    0x11b668,%eax
  1014f6:	83 e0 40             	and    $0x40,%eax
  1014f9:	85 c0                	test   %eax,%eax
  1014fb:	74 11                	je     10150e <kbd_proc_data+0xca>
        // Last character was an E0 escape; or with 0x80
        data |= 0x80;
  1014fd:	80 4d f3 80          	orb    $0x80,-0xd(%ebp)
        shift &= ~E0ESC;
  101501:	a1 68 b6 11 00       	mov    0x11b668,%eax
  101506:	83 e0 bf             	and    $0xffffffbf,%eax
  101509:	a3 68 b6 11 00       	mov    %eax,0x11b668
    }

    shift |= shiftcode[data];
  10150e:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
  101512:	0f b6 80 40 80 11 00 	movzbl 0x118040(%eax),%eax
  101519:	0f b6 d0             	movzbl %al,%edx
  10151c:	a1 68 b6 11 00       	mov    0x11b668,%eax
  101521:	09 d0                	or     %edx,%eax
  101523:	a3 68 b6 11 00       	mov    %eax,0x11b668
    shift ^= togglecode[data];
  101528:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
  10152c:	0f b6 80 40 81 11 00 	movzbl 0x118140(%eax),%eax
  101533:	0f b6 d0             	movzbl %al,%edx
  101536:	a1 68 b6 11 00       	mov    0x11b668,%eax
  10153b:	31 d0                	xor    %edx,%eax
  10153d:	a3 68 b6 11 00       	mov    %eax,0x11b668

    c = charcode[shift & (CTL | SHIFT)][data];
  101542:	a1 68 b6 11 00       	mov    0x11b668,%eax
  101547:	83 e0 03             	and    $0x3,%eax
  10154a:	8b 14 85 40 85 11 00 	mov    0x118540(,%eax,4),%edx
  101551:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
  101555:	01 d0                	add    %edx,%eax
  101557:	0f b6 00             	movzbl (%eax),%eax
  10155a:	0f b6 c0             	movzbl %al,%eax
  10155d:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (shift & CAPSLOCK) {
  101560:	a1 68 b6 11 00       	mov    0x11b668,%eax
  101565:	83 e0 08             	and    $0x8,%eax
  101568:	85 c0                	test   %eax,%eax
  10156a:	74 22                	je     10158e <kbd_proc_data+0x14a>
        if ('a' <= c && c <= 'z')
  10156c:	83 7d f4 60          	cmpl   $0x60,-0xc(%ebp)
  101570:	7e 0c                	jle    10157e <kbd_proc_data+0x13a>
  101572:	83 7d f4 7a          	cmpl   $0x7a,-0xc(%ebp)
  101576:	7f 06                	jg     10157e <kbd_proc_data+0x13a>
            c += 'A' - 'a';
  101578:	83 6d f4 20          	subl   $0x20,-0xc(%ebp)
  10157c:	eb 10                	jmp    10158e <kbd_proc_data+0x14a>
        else if ('A' <= c && c <= 'Z')
  10157e:	83 7d f4 40          	cmpl   $0x40,-0xc(%ebp)
  101582:	7e 0a                	jle    10158e <kbd_proc_data+0x14a>
  101584:	83 7d f4 5a          	cmpl   $0x5a,-0xc(%ebp)
  101588:	7f 04                	jg     10158e <kbd_proc_data+0x14a>
            c += 'a' - 'A';
  10158a:	83 45 f4 20          	addl   $0x20,-0xc(%ebp)
    }

    // Process special keys
    // Ctrl-Alt-Del: reboot
    if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
  10158e:	a1 68 b6 11 00       	mov    0x11b668,%eax
  101593:	f7 d0                	not    %eax
  101595:	83 e0 06             	and    $0x6,%eax
  101598:	85 c0                	test   %eax,%eax
  10159a:	75 27                	jne    1015c3 <kbd_proc_data+0x17f>
  10159c:	81 7d f4 e9 00 00 00 	cmpl   $0xe9,-0xc(%ebp)
  1015a3:	75 1e                	jne    1015c3 <kbd_proc_data+0x17f>
        cprintf("Rebooting!\n");
  1015a5:	c7 04 24 ad 64 10 00 	movl   $0x1064ad,(%esp)
  1015ac:	e8 f1 ec ff ff       	call   1002a2 <cprintf>
  1015b1:	66 c7 45 e8 92 00    	movw   $0x92,-0x18(%ebp)
  1015b7:	c6 45 e7 03          	movb   $0x3,-0x19(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
  1015bb:	0f b6 45 e7          	movzbl -0x19(%ebp),%eax
  1015bf:	8b 55 e8             	mov    -0x18(%ebp),%edx
  1015c2:	ee                   	out    %al,(%dx)
        outb(0x92, 0x3); // courtesy of Chris Frost
    }
    return c;
  1015c3:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  1015c6:	c9                   	leave  
  1015c7:	c3                   	ret    

001015c8 <kbd_intr>:

/* kbd_intr - try to feed input characters from keyboard */
static void
kbd_intr(void) {
  1015c8:	55                   	push   %ebp
  1015c9:	89 e5                	mov    %esp,%ebp
  1015cb:	83 ec 18             	sub    $0x18,%esp
    cons_intr(kbd_proc_data);
  1015ce:	c7 04 24 44 14 10 00 	movl   $0x101444,(%esp)
  1015d5:	e8 a9 fd ff ff       	call   101383 <cons_intr>
}
  1015da:	90                   	nop
  1015db:	c9                   	leave  
  1015dc:	c3                   	ret    

001015dd <kbd_init>:

static void
kbd_init(void) {
  1015dd:	55                   	push   %ebp
  1015de:	89 e5                	mov    %esp,%ebp
  1015e0:	83 ec 18             	sub    $0x18,%esp
    // drain the kbd buffer
    kbd_intr();
  1015e3:	e8 e0 ff ff ff       	call   1015c8 <kbd_intr>
    pic_enable(IRQ_KBD);
  1015e8:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  1015ef:	e8 35 01 00 00       	call   101729 <pic_enable>
}
  1015f4:	90                   	nop
  1015f5:	c9                   	leave  
  1015f6:	c3                   	ret    

001015f7 <cons_init>:

/* cons_init - initializes the console devices */
void
cons_init(void) {
  1015f7:	55                   	push   %ebp
  1015f8:	89 e5                	mov    %esp,%ebp
  1015fa:	83 ec 18             	sub    $0x18,%esp
    cga_init();
  1015fd:	e8 83 f8 ff ff       	call   100e85 <cga_init>
    serial_init();
  101602:	e8 62 f9 ff ff       	call   100f69 <serial_init>
    kbd_init();
  101607:	e8 d1 ff ff ff       	call   1015dd <kbd_init>
    if (!serial_exists) {
  10160c:	a1 48 b4 11 00       	mov    0x11b448,%eax
  101611:	85 c0                	test   %eax,%eax
  101613:	75 0c                	jne    101621 <cons_init+0x2a>
        cprintf("serial port does not exist!!\n");
  101615:	c7 04 24 b9 64 10 00 	movl   $0x1064b9,(%esp)
  10161c:	e8 81 ec ff ff       	call   1002a2 <cprintf>
    }
}
  101621:	90                   	nop
  101622:	c9                   	leave  
  101623:	c3                   	ret    

00101624 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void
cons_putc(int c) {
  101624:	55                   	push   %ebp
  101625:	89 e5                	mov    %esp,%ebp
  101627:	83 ec 28             	sub    $0x28,%esp
    bool intr_flag;
    local_intr_save(intr_flag);
  10162a:	e8 cf f7 ff ff       	call   100dfe <__intr_save>
  10162f:	89 45 f4             	mov    %eax,-0xc(%ebp)
    {
        lpt_putc(c);
  101632:	8b 45 08             	mov    0x8(%ebp),%eax
  101635:	89 04 24             	mov    %eax,(%esp)
  101638:	e8 89 fa ff ff       	call   1010c6 <lpt_putc>
        cga_putc(c);
  10163d:	8b 45 08             	mov    0x8(%ebp),%eax
  101640:	89 04 24             	mov    %eax,(%esp)
  101643:	e8 be fa ff ff       	call   101106 <cga_putc>
        serial_putc(c);
  101648:	8b 45 08             	mov    0x8(%ebp),%eax
  10164b:	89 04 24             	mov    %eax,(%esp)
  10164e:	e8 f0 fc ff ff       	call   101343 <serial_putc>
    }
    local_intr_restore(intr_flag);
  101653:	8b 45 f4             	mov    -0xc(%ebp),%eax
  101656:	89 04 24             	mov    %eax,(%esp)
  101659:	e8 ca f7 ff ff       	call   100e28 <__intr_restore>
}
  10165e:	90                   	nop
  10165f:	c9                   	leave  
  101660:	c3                   	ret    

00101661 <cons_getc>:
/* *
 * cons_getc - return the next input character from console,
 * or 0 if none waiting.
 * */
int
cons_getc(void) {
  101661:	55                   	push   %ebp
  101662:	89 e5                	mov    %esp,%ebp
  101664:	83 ec 28             	sub    $0x28,%esp
    int c = 0;
  101667:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    bool intr_flag;
    local_intr_save(intr_flag);
  10166e:	e8 8b f7 ff ff       	call   100dfe <__intr_save>
  101673:	89 45 f0             	mov    %eax,-0x10(%ebp)
    {
        // poll for any pending input characters,
        // so that this function works even when interrupts are disabled
        // (e.g., when called from the kernel monitor).
        serial_intr();
  101676:	e8 ab fd ff ff       	call   101426 <serial_intr>
        kbd_intr();
  10167b:	e8 48 ff ff ff       	call   1015c8 <kbd_intr>

        // grab the next character from the input buffer.
        if (cons.rpos != cons.wpos) {
  101680:	8b 15 60 b6 11 00    	mov    0x11b660,%edx
  101686:	a1 64 b6 11 00       	mov    0x11b664,%eax
  10168b:	39 c2                	cmp    %eax,%edx
  10168d:	74 31                	je     1016c0 <cons_getc+0x5f>
            c = cons.buf[cons.rpos ++];
  10168f:	a1 60 b6 11 00       	mov    0x11b660,%eax
  101694:	8d 50 01             	lea    0x1(%eax),%edx
  101697:	89 15 60 b6 11 00    	mov    %edx,0x11b660
  10169d:	0f b6 80 60 b4 11 00 	movzbl 0x11b460(%eax),%eax
  1016a4:	0f b6 c0             	movzbl %al,%eax
  1016a7:	89 45 f4             	mov    %eax,-0xc(%ebp)
            if (cons.rpos == CONSBUFSIZE) {
  1016aa:	a1 60 b6 11 00       	mov    0x11b660,%eax
  1016af:	3d 00 02 00 00       	cmp    $0x200,%eax
  1016b4:	75 0a                	jne    1016c0 <cons_getc+0x5f>
                cons.rpos = 0;
  1016b6:	c7 05 60 b6 11 00 00 	movl   $0x0,0x11b660
  1016bd:	00 00 00 
            }
        }
    }
    local_intr_restore(intr_flag);
  1016c0:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1016c3:	89 04 24             	mov    %eax,(%esp)
  1016c6:	e8 5d f7 ff ff       	call   100e28 <__intr_restore>
    return c;
  1016cb:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  1016ce:	c9                   	leave  
  1016cf:	c3                   	ret    

001016d0 <pic_setmask>:
// Initial IRQ mask has interrupt 2 enabled (for slave 8259A).
static uint16_t irq_mask = 0xFFFF & ~(1 << IRQ_SLAVE);
static bool did_init = 0;

static void
pic_setmask(uint16_t mask) {
  1016d0:	55                   	push   %ebp
  1016d1:	89 e5                	mov    %esp,%ebp
  1016d3:	83 ec 14             	sub    $0x14,%esp
  1016d6:	8b 45 08             	mov    0x8(%ebp),%eax
  1016d9:	66 89 45 ec          	mov    %ax,-0x14(%ebp)
    irq_mask = mask;
  1016dd:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1016e0:	66 a3 50 85 11 00    	mov    %ax,0x118550
    if (did_init) {
  1016e6:	a1 6c b6 11 00       	mov    0x11b66c,%eax
  1016eb:	85 c0                	test   %eax,%eax
  1016ed:	74 37                	je     101726 <pic_setmask+0x56>
        outb(IO_PIC1 + 1, mask);
  1016ef:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1016f2:	0f b6 c0             	movzbl %al,%eax
  1016f5:	66 c7 45 fa 21 00    	movw   $0x21,-0x6(%ebp)
  1016fb:	88 45 f9             	mov    %al,-0x7(%ebp)
  1016fe:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
  101702:	0f b7 55 fa          	movzwl -0x6(%ebp),%edx
  101706:	ee                   	out    %al,(%dx)
        outb(IO_PIC2 + 1, mask >> 8);
  101707:	0f b7 45 ec          	movzwl -0x14(%ebp),%eax
  10170b:	c1 e8 08             	shr    $0x8,%eax
  10170e:	0f b7 c0             	movzwl %ax,%eax
  101711:	0f b6 c0             	movzbl %al,%eax
  101714:	66 c7 45 fe a1 00    	movw   $0xa1,-0x2(%ebp)
  10171a:	88 45 fd             	mov    %al,-0x3(%ebp)
  10171d:	0f b6 45 fd          	movzbl -0x3(%ebp),%eax
  101721:	0f b7 55 fe          	movzwl -0x2(%ebp),%edx
  101725:	ee                   	out    %al,(%dx)
    }
}
  101726:	90                   	nop
  101727:	c9                   	leave  
  101728:	c3                   	ret    

00101729 <pic_enable>:

void
pic_enable(unsigned int irq) {
  101729:	55                   	push   %ebp
  10172a:	89 e5                	mov    %esp,%ebp
  10172c:	83 ec 04             	sub    $0x4,%esp
    pic_setmask(irq_mask & ~(1 << irq));
  10172f:	8b 45 08             	mov    0x8(%ebp),%eax
  101732:	ba 01 00 00 00       	mov    $0x1,%edx
  101737:	88 c1                	mov    %al,%cl
  101739:	d3 e2                	shl    %cl,%edx
  10173b:	89 d0                	mov    %edx,%eax
  10173d:	98                   	cwtl   
  10173e:	f7 d0                	not    %eax
  101740:	0f bf d0             	movswl %ax,%edx
  101743:	0f b7 05 50 85 11 00 	movzwl 0x118550,%eax
  10174a:	98                   	cwtl   
  10174b:	21 d0                	and    %edx,%eax
  10174d:	98                   	cwtl   
  10174e:	0f b7 c0             	movzwl %ax,%eax
  101751:	89 04 24             	mov    %eax,(%esp)
  101754:	e8 77 ff ff ff       	call   1016d0 <pic_setmask>
}
  101759:	90                   	nop
  10175a:	c9                   	leave  
  10175b:	c3                   	ret    

0010175c <pic_init>:

/* pic_init - initialize the 8259A interrupt controllers */
void
pic_init(void) {
  10175c:	55                   	push   %ebp
  10175d:	89 e5                	mov    %esp,%ebp
  10175f:	83 ec 44             	sub    $0x44,%esp
    did_init = 1;
  101762:	c7 05 6c b6 11 00 01 	movl   $0x1,0x11b66c
  101769:	00 00 00 
  10176c:	66 c7 45 ca 21 00    	movw   $0x21,-0x36(%ebp)
  101772:	c6 45 c9 ff          	movb   $0xff,-0x37(%ebp)
  101776:	0f b6 45 c9          	movzbl -0x37(%ebp),%eax
  10177a:	0f b7 55 ca          	movzwl -0x36(%ebp),%edx
  10177e:	ee                   	out    %al,(%dx)
  10177f:	66 c7 45 ce a1 00    	movw   $0xa1,-0x32(%ebp)
  101785:	c6 45 cd ff          	movb   $0xff,-0x33(%ebp)
  101789:	0f b6 45 cd          	movzbl -0x33(%ebp),%eax
  10178d:	0f b7 55 ce          	movzwl -0x32(%ebp),%edx
  101791:	ee                   	out    %al,(%dx)
  101792:	66 c7 45 d2 20 00    	movw   $0x20,-0x2e(%ebp)
  101798:	c6 45 d1 11          	movb   $0x11,-0x2f(%ebp)
  10179c:	0f b6 45 d1          	movzbl -0x2f(%ebp),%eax
  1017a0:	0f b7 55 d2          	movzwl -0x2e(%ebp),%edx
  1017a4:	ee                   	out    %al,(%dx)
  1017a5:	66 c7 45 d6 21 00    	movw   $0x21,-0x2a(%ebp)
  1017ab:	c6 45 d5 20          	movb   $0x20,-0x2b(%ebp)
  1017af:	0f b6 45 d5          	movzbl -0x2b(%ebp),%eax
  1017b3:	0f b7 55 d6          	movzwl -0x2a(%ebp),%edx
  1017b7:	ee                   	out    %al,(%dx)
  1017b8:	66 c7 45 da 21 00    	movw   $0x21,-0x26(%ebp)
  1017be:	c6 45 d9 04          	movb   $0x4,-0x27(%ebp)
  1017c2:	0f b6 45 d9          	movzbl -0x27(%ebp),%eax
  1017c6:	0f b7 55 da          	movzwl -0x26(%ebp),%edx
  1017ca:	ee                   	out    %al,(%dx)
  1017cb:	66 c7 45 de 21 00    	movw   $0x21,-0x22(%ebp)
  1017d1:	c6 45 dd 03          	movb   $0x3,-0x23(%ebp)
  1017d5:	0f b6 45 dd          	movzbl -0x23(%ebp),%eax
  1017d9:	0f b7 55 de          	movzwl -0x22(%ebp),%edx
  1017dd:	ee                   	out    %al,(%dx)
  1017de:	66 c7 45 e2 a0 00    	movw   $0xa0,-0x1e(%ebp)
  1017e4:	c6 45 e1 11          	movb   $0x11,-0x1f(%ebp)
  1017e8:	0f b6 45 e1          	movzbl -0x1f(%ebp),%eax
  1017ec:	0f b7 55 e2          	movzwl -0x1e(%ebp),%edx
  1017f0:	ee                   	out    %al,(%dx)
  1017f1:	66 c7 45 e6 a1 00    	movw   $0xa1,-0x1a(%ebp)
  1017f7:	c6 45 e5 28          	movb   $0x28,-0x1b(%ebp)
  1017fb:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
  1017ff:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
  101803:	ee                   	out    %al,(%dx)
  101804:	66 c7 45 ea a1 00    	movw   $0xa1,-0x16(%ebp)
  10180a:	c6 45 e9 02          	movb   $0x2,-0x17(%ebp)
  10180e:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
  101812:	0f b7 55 ea          	movzwl -0x16(%ebp),%edx
  101816:	ee                   	out    %al,(%dx)
  101817:	66 c7 45 ee a1 00    	movw   $0xa1,-0x12(%ebp)
  10181d:	c6 45 ed 03          	movb   $0x3,-0x13(%ebp)
  101821:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
  101825:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
  101829:	ee                   	out    %al,(%dx)
  10182a:	66 c7 45 f2 20 00    	movw   $0x20,-0xe(%ebp)
  101830:	c6 45 f1 68          	movb   $0x68,-0xf(%ebp)
  101834:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
  101838:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
  10183c:	ee                   	out    %al,(%dx)
  10183d:	66 c7 45 f6 20 00    	movw   $0x20,-0xa(%ebp)
  101843:	c6 45 f5 0a          	movb   $0xa,-0xb(%ebp)
  101847:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
  10184b:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
  10184f:	ee                   	out    %al,(%dx)
  101850:	66 c7 45 fa a0 00    	movw   $0xa0,-0x6(%ebp)
  101856:	c6 45 f9 68          	movb   $0x68,-0x7(%ebp)
  10185a:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
  10185e:	0f b7 55 fa          	movzwl -0x6(%ebp),%edx
  101862:	ee                   	out    %al,(%dx)
  101863:	66 c7 45 fe a0 00    	movw   $0xa0,-0x2(%ebp)
  101869:	c6 45 fd 0a          	movb   $0xa,-0x3(%ebp)
  10186d:	0f b6 45 fd          	movzbl -0x3(%ebp),%eax
  101871:	0f b7 55 fe          	movzwl -0x2(%ebp),%edx
  101875:	ee                   	out    %al,(%dx)
    outb(IO_PIC1, 0x0a);    // read IRR by default

    outb(IO_PIC2, 0x68);    // OCW3
    outb(IO_PIC2, 0x0a);    // OCW3

    if (irq_mask != 0xFFFF) {
  101876:	0f b7 05 50 85 11 00 	movzwl 0x118550,%eax
  10187d:	3d ff ff 00 00       	cmp    $0xffff,%eax
  101882:	74 0f                	je     101893 <pic_init+0x137>
        pic_setmask(irq_mask);
  101884:	0f b7 05 50 85 11 00 	movzwl 0x118550,%eax
  10188b:	89 04 24             	mov    %eax,(%esp)
  10188e:	e8 3d fe ff ff       	call   1016d0 <pic_setmask>
    }
}
  101893:	90                   	nop
  101894:	c9                   	leave  
  101895:	c3                   	ret    

00101896 <intr_enable>:
#include <x86.h>
#include <intr.h>

/* intr_enable - enable irq interrupt */
void
intr_enable(void) {
  101896:	55                   	push   %ebp
  101897:	89 e5                	mov    %esp,%ebp
    asm volatile ("sti");
  101899:	fb                   	sti    
    sti();
}
  10189a:	90                   	nop
  10189b:	5d                   	pop    %ebp
  10189c:	c3                   	ret    

0010189d <intr_disable>:

/* intr_disable - disable irq interrupt */
void
intr_disable(void) {
  10189d:	55                   	push   %ebp
  10189e:	89 e5                	mov    %esp,%ebp
    asm volatile ("cli" ::: "memory");
  1018a0:	fa                   	cli    
    cli();
}
  1018a1:	90                   	nop
  1018a2:	5d                   	pop    %ebp
  1018a3:	c3                   	ret    

001018a4 <print_ticks>:
#include <console.h>
#include <kdebug.h>

#define TICK_NUM 100

static void print_ticks() {
  1018a4:	55                   	push   %ebp
  1018a5:	89 e5                	mov    %esp,%ebp
  1018a7:	83 ec 18             	sub    $0x18,%esp
    cprintf("%d ticks\n",TICK_NUM);
  1018aa:	c7 44 24 04 64 00 00 	movl   $0x64,0x4(%esp)
  1018b1:	00 
  1018b2:	c7 04 24 e0 64 10 00 	movl   $0x1064e0,(%esp)
  1018b9:	e8 e4 e9 ff ff       	call   1002a2 <cprintf>
#ifdef DEBUG_GRADE
    cprintf("End of Test.\n");
  1018be:	c7 04 24 ea 64 10 00 	movl   $0x1064ea,(%esp)
  1018c5:	e8 d8 e9 ff ff       	call   1002a2 <cprintf>
    panic("EOT: kernel seems ok.");
  1018ca:	c7 44 24 08 f8 64 10 	movl   $0x1064f8,0x8(%esp)
  1018d1:	00 
  1018d2:	c7 44 24 04 12 00 00 	movl   $0x12,0x4(%esp)
  1018d9:	00 
  1018da:	c7 04 24 0e 65 10 00 	movl   $0x10650e,(%esp)
  1018e1:	e8 13 eb ff ff       	call   1003f9 <__panic>

001018e6 <idt_init>:
    sizeof(idt) - 1, (uintptr_t)idt
};

/* idt_init - initialize IDT to each of the entry points in kern/trap/vectors.S */
void
idt_init(void) {
  1018e6:	55                   	push   %ebp
  1018e7:	89 e5                	mov    %esp,%ebp
  1018e9:	83 ec 10             	sub    $0x10,%esp
      *     You don't know the meaning of this instruction? just google it! and check the libs/x86.h to know more.
      *     Notice: the argument of lidt is idt_pd. try to find it!
      */
      extern uintptr_t __vectors[];
    int i;
    for (i = 0; i < sizeof(idt) / sizeof(struct gatedesc); i ++) {
  1018ec:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
  1018f3:	e9 c4 00 00 00       	jmp    1019bc <idt_init+0xd6>
        SETGATE(idt[i], 0, GD_KTEXT, __vectors[i], DPL_KERNEL);
  1018f8:	8b 45 fc             	mov    -0x4(%ebp),%eax
  1018fb:	8b 04 85 e0 85 11 00 	mov    0x1185e0(,%eax,4),%eax
  101902:	0f b7 d0             	movzwl %ax,%edx
  101905:	8b 45 fc             	mov    -0x4(%ebp),%eax
  101908:	66 89 14 c5 80 b6 11 	mov    %dx,0x11b680(,%eax,8)
  10190f:	00 
  101910:	8b 45 fc             	mov    -0x4(%ebp),%eax
  101913:	66 c7 04 c5 82 b6 11 	movw   $0x8,0x11b682(,%eax,8)
  10191a:	00 08 00 
  10191d:	8b 45 fc             	mov    -0x4(%ebp),%eax
  101920:	0f b6 14 c5 84 b6 11 	movzbl 0x11b684(,%eax,8),%edx
  101927:	00 
  101928:	80 e2 e0             	and    $0xe0,%dl
  10192b:	88 14 c5 84 b6 11 00 	mov    %dl,0x11b684(,%eax,8)
  101932:	8b 45 fc             	mov    -0x4(%ebp),%eax
  101935:	0f b6 14 c5 84 b6 11 	movzbl 0x11b684(,%eax,8),%edx
  10193c:	00 
  10193d:	80 e2 1f             	and    $0x1f,%dl
  101940:	88 14 c5 84 b6 11 00 	mov    %dl,0x11b684(,%eax,8)
  101947:	8b 45 fc             	mov    -0x4(%ebp),%eax
  10194a:	0f b6 14 c5 85 b6 11 	movzbl 0x11b685(,%eax,8),%edx
  101951:	00 
  101952:	80 e2 f0             	and    $0xf0,%dl
  101955:	80 ca 0e             	or     $0xe,%dl
  101958:	88 14 c5 85 b6 11 00 	mov    %dl,0x11b685(,%eax,8)
  10195f:	8b 45 fc             	mov    -0x4(%ebp),%eax
  101962:	0f b6 14 c5 85 b6 11 	movzbl 0x11b685(,%eax,8),%edx
  101969:	00 
  10196a:	80 e2 ef             	and    $0xef,%dl
  10196d:	88 14 c5 85 b6 11 00 	mov    %dl,0x11b685(,%eax,8)
  101974:	8b 45 fc             	mov    -0x4(%ebp),%eax
  101977:	0f b6 14 c5 85 b6 11 	movzbl 0x11b685(,%eax,8),%edx
  10197e:	00 
  10197f:	80 e2 9f             	and    $0x9f,%dl
  101982:	88 14 c5 85 b6 11 00 	mov    %dl,0x11b685(,%eax,8)
  101989:	8b 45 fc             	mov    -0x4(%ebp),%eax
  10198c:	0f b6 14 c5 85 b6 11 	movzbl 0x11b685(,%eax,8),%edx
  101993:	00 
  101994:	80 ca 80             	or     $0x80,%dl
  101997:	88 14 c5 85 b6 11 00 	mov    %dl,0x11b685(,%eax,8)
  10199e:	8b 45 fc             	mov    -0x4(%ebp),%eax
  1019a1:	8b 04 85 e0 85 11 00 	mov    0x1185e0(,%eax,4),%eax
  1019a8:	c1 e8 10             	shr    $0x10,%eax
  1019ab:	0f b7 d0             	movzwl %ax,%edx
  1019ae:	8b 45 fc             	mov    -0x4(%ebp),%eax
  1019b1:	66 89 14 c5 86 b6 11 	mov    %dx,0x11b686(,%eax,8)
  1019b8:	00 
    for (i = 0; i < sizeof(idt) / sizeof(struct gatedesc); i ++) {
  1019b9:	ff 45 fc             	incl   -0x4(%ebp)
  1019bc:	8b 45 fc             	mov    -0x4(%ebp),%eax
  1019bf:	3d ff 00 00 00       	cmp    $0xff,%eax
  1019c4:	0f 86 2e ff ff ff    	jbe    1018f8 <idt_init+0x12>
    }
	// set for switch from user to kernel
    SETGATE(idt[T_SWITCH_TOK], 0, GD_KTEXT, __vectors[T_SWITCH_TOK], DPL_USER);
  1019ca:	a1 c4 87 11 00       	mov    0x1187c4,%eax
  1019cf:	0f b7 c0             	movzwl %ax,%eax
  1019d2:	66 a3 48 ba 11 00    	mov    %ax,0x11ba48
  1019d8:	66 c7 05 4a ba 11 00 	movw   $0x8,0x11ba4a
  1019df:	08 00 
  1019e1:	0f b6 05 4c ba 11 00 	movzbl 0x11ba4c,%eax
  1019e8:	24 e0                	and    $0xe0,%al
  1019ea:	a2 4c ba 11 00       	mov    %al,0x11ba4c
  1019ef:	0f b6 05 4c ba 11 00 	movzbl 0x11ba4c,%eax
  1019f6:	24 1f                	and    $0x1f,%al
  1019f8:	a2 4c ba 11 00       	mov    %al,0x11ba4c
  1019fd:	0f b6 05 4d ba 11 00 	movzbl 0x11ba4d,%eax
  101a04:	24 f0                	and    $0xf0,%al
  101a06:	0c 0e                	or     $0xe,%al
  101a08:	a2 4d ba 11 00       	mov    %al,0x11ba4d
  101a0d:	0f b6 05 4d ba 11 00 	movzbl 0x11ba4d,%eax
  101a14:	24 ef                	and    $0xef,%al
  101a16:	a2 4d ba 11 00       	mov    %al,0x11ba4d
  101a1b:	0f b6 05 4d ba 11 00 	movzbl 0x11ba4d,%eax
  101a22:	0c 60                	or     $0x60,%al
  101a24:	a2 4d ba 11 00       	mov    %al,0x11ba4d
  101a29:	0f b6 05 4d ba 11 00 	movzbl 0x11ba4d,%eax
  101a30:	0c 80                	or     $0x80,%al
  101a32:	a2 4d ba 11 00       	mov    %al,0x11ba4d
  101a37:	a1 c4 87 11 00       	mov    0x1187c4,%eax
  101a3c:	c1 e8 10             	shr    $0x10,%eax
  101a3f:	0f b7 c0             	movzwl %ax,%eax
  101a42:	66 a3 4e ba 11 00    	mov    %ax,0x11ba4e
  101a48:	c7 45 f8 60 85 11 00 	movl   $0x118560,-0x8(%ebp)
    asm volatile ("lidt (%0)" :: "r" (pd) : "memory");
  101a4f:	8b 45 f8             	mov    -0x8(%ebp),%eax
  101a52:	0f 01 18             	lidtl  (%eax)
	// load the IDT
    lidt(&idt_pd);
}
  101a55:	90                   	nop
  101a56:	c9                   	leave  
  101a57:	c3                   	ret    

00101a58 <trapname>:

static const char *
trapname(int trapno) {
  101a58:	55                   	push   %ebp
  101a59:	89 e5                	mov    %esp,%ebp
        "Alignment Check",
        "Machine-Check",
        "SIMD Floating-Point Exception"
    };

    if (trapno < sizeof(excnames)/sizeof(const char * const)) {
  101a5b:	8b 45 08             	mov    0x8(%ebp),%eax
  101a5e:	83 f8 13             	cmp    $0x13,%eax
  101a61:	77 0c                	ja     101a6f <trapname+0x17>
        return excnames[trapno];
  101a63:	8b 45 08             	mov    0x8(%ebp),%eax
  101a66:	8b 04 85 60 68 10 00 	mov    0x106860(,%eax,4),%eax
  101a6d:	eb 18                	jmp    101a87 <trapname+0x2f>
    }
    if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16) {
  101a6f:	83 7d 08 1f          	cmpl   $0x1f,0x8(%ebp)
  101a73:	7e 0d                	jle    101a82 <trapname+0x2a>
  101a75:	83 7d 08 2f          	cmpl   $0x2f,0x8(%ebp)
  101a79:	7f 07                	jg     101a82 <trapname+0x2a>
        return "Hardware Interrupt";
  101a7b:	b8 1f 65 10 00       	mov    $0x10651f,%eax
  101a80:	eb 05                	jmp    101a87 <trapname+0x2f>
    }
    return "(unknown trap)";
  101a82:	b8 32 65 10 00       	mov    $0x106532,%eax
}
  101a87:	5d                   	pop    %ebp
  101a88:	c3                   	ret    

00101a89 <trap_in_kernel>:

/* trap_in_kernel - test if trap happened in kernel */
bool
trap_in_kernel(struct trapframe *tf) {
  101a89:	55                   	push   %ebp
  101a8a:	89 e5                	mov    %esp,%ebp
    return (tf->tf_cs == (uint16_t)KERNEL_CS);
  101a8c:	8b 45 08             	mov    0x8(%ebp),%eax
  101a8f:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
  101a93:	83 f8 08             	cmp    $0x8,%eax
  101a96:	0f 94 c0             	sete   %al
  101a99:	0f b6 c0             	movzbl %al,%eax
}
  101a9c:	5d                   	pop    %ebp
  101a9d:	c3                   	ret    

00101a9e <print_trapframe>:
    "TF", "IF", "DF", "OF", NULL, NULL, "NT", NULL,
    "RF", "VM", "AC", "VIF", "VIP", "ID", NULL, NULL,
};

void
print_trapframe(struct trapframe *tf) {
  101a9e:	55                   	push   %ebp
  101a9f:	89 e5                	mov    %esp,%ebp
  101aa1:	83 ec 28             	sub    $0x28,%esp
    cprintf("trapframe at %p\n", tf);
  101aa4:	8b 45 08             	mov    0x8(%ebp),%eax
  101aa7:	89 44 24 04          	mov    %eax,0x4(%esp)
  101aab:	c7 04 24 73 65 10 00 	movl   $0x106573,(%esp)
  101ab2:	e8 eb e7 ff ff       	call   1002a2 <cprintf>
    print_regs(&tf->tf_regs);
  101ab7:	8b 45 08             	mov    0x8(%ebp),%eax
  101aba:	89 04 24             	mov    %eax,(%esp)
  101abd:	e8 8f 01 00 00       	call   101c51 <print_regs>
    cprintf("  ds   0x----%04x\n", tf->tf_ds);
  101ac2:	8b 45 08             	mov    0x8(%ebp),%eax
  101ac5:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
  101ac9:	89 44 24 04          	mov    %eax,0x4(%esp)
  101acd:	c7 04 24 84 65 10 00 	movl   $0x106584,(%esp)
  101ad4:	e8 c9 e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  es   0x----%04x\n", tf->tf_es);
  101ad9:	8b 45 08             	mov    0x8(%ebp),%eax
  101adc:	0f b7 40 28          	movzwl 0x28(%eax),%eax
  101ae0:	89 44 24 04          	mov    %eax,0x4(%esp)
  101ae4:	c7 04 24 97 65 10 00 	movl   $0x106597,(%esp)
  101aeb:	e8 b2 e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  fs   0x----%04x\n", tf->tf_fs);
  101af0:	8b 45 08             	mov    0x8(%ebp),%eax
  101af3:	0f b7 40 24          	movzwl 0x24(%eax),%eax
  101af7:	89 44 24 04          	mov    %eax,0x4(%esp)
  101afb:	c7 04 24 aa 65 10 00 	movl   $0x1065aa,(%esp)
  101b02:	e8 9b e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  gs   0x----%04x\n", tf->tf_gs);
  101b07:	8b 45 08             	mov    0x8(%ebp),%eax
  101b0a:	0f b7 40 20          	movzwl 0x20(%eax),%eax
  101b0e:	89 44 24 04          	mov    %eax,0x4(%esp)
  101b12:	c7 04 24 bd 65 10 00 	movl   $0x1065bd,(%esp)
  101b19:	e8 84 e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
  101b1e:	8b 45 08             	mov    0x8(%ebp),%eax
  101b21:	8b 40 30             	mov    0x30(%eax),%eax
  101b24:	89 04 24             	mov    %eax,(%esp)
  101b27:	e8 2c ff ff ff       	call   101a58 <trapname>
  101b2c:	89 c2                	mov    %eax,%edx
  101b2e:	8b 45 08             	mov    0x8(%ebp),%eax
  101b31:	8b 40 30             	mov    0x30(%eax),%eax
  101b34:	89 54 24 08          	mov    %edx,0x8(%esp)
  101b38:	89 44 24 04          	mov    %eax,0x4(%esp)
  101b3c:	c7 04 24 d0 65 10 00 	movl   $0x1065d0,(%esp)
  101b43:	e8 5a e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  err  0x%08x\n", tf->tf_err);
  101b48:	8b 45 08             	mov    0x8(%ebp),%eax
  101b4b:	8b 40 34             	mov    0x34(%eax),%eax
  101b4e:	89 44 24 04          	mov    %eax,0x4(%esp)
  101b52:	c7 04 24 e2 65 10 00 	movl   $0x1065e2,(%esp)
  101b59:	e8 44 e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  eip  0x%08x\n", tf->tf_eip);
  101b5e:	8b 45 08             	mov    0x8(%ebp),%eax
  101b61:	8b 40 38             	mov    0x38(%eax),%eax
  101b64:	89 44 24 04          	mov    %eax,0x4(%esp)
  101b68:	c7 04 24 f1 65 10 00 	movl   $0x1065f1,(%esp)
  101b6f:	e8 2e e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  cs   0x----%04x\n", tf->tf_cs);
  101b74:	8b 45 08             	mov    0x8(%ebp),%eax
  101b77:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
  101b7b:	89 44 24 04          	mov    %eax,0x4(%esp)
  101b7f:	c7 04 24 00 66 10 00 	movl   $0x106600,(%esp)
  101b86:	e8 17 e7 ff ff       	call   1002a2 <cprintf>
    cprintf("  flag 0x%08x ", tf->tf_eflags);
  101b8b:	8b 45 08             	mov    0x8(%ebp),%eax
  101b8e:	8b 40 40             	mov    0x40(%eax),%eax
  101b91:	89 44 24 04          	mov    %eax,0x4(%esp)
  101b95:	c7 04 24 13 66 10 00 	movl   $0x106613,(%esp)
  101b9c:	e8 01 e7 ff ff       	call   1002a2 <cprintf>

    int i, j;
    for (i = 0, j = 1; i < sizeof(IA32flags) / sizeof(IA32flags[0]); i ++, j <<= 1) {
  101ba1:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
  101ba8:	c7 45 f0 01 00 00 00 	movl   $0x1,-0x10(%ebp)
  101baf:	eb 3d                	jmp    101bee <print_trapframe+0x150>
        if ((tf->tf_eflags & j) && IA32flags[i] != NULL) {
  101bb1:	8b 45 08             	mov    0x8(%ebp),%eax
  101bb4:	8b 50 40             	mov    0x40(%eax),%edx
  101bb7:	8b 45 f0             	mov    -0x10(%ebp),%eax
  101bba:	21 d0                	and    %edx,%eax
  101bbc:	85 c0                	test   %eax,%eax
  101bbe:	74 28                	je     101be8 <print_trapframe+0x14a>
  101bc0:	8b 45 f4             	mov    -0xc(%ebp),%eax
  101bc3:	8b 04 85 80 85 11 00 	mov    0x118580(,%eax,4),%eax
  101bca:	85 c0                	test   %eax,%eax
  101bcc:	74 1a                	je     101be8 <print_trapframe+0x14a>
            cprintf("%s,", IA32flags[i]);
  101bce:	8b 45 f4             	mov    -0xc(%ebp),%eax
  101bd1:	8b 04 85 80 85 11 00 	mov    0x118580(,%eax,4),%eax
  101bd8:	89 44 24 04          	mov    %eax,0x4(%esp)
  101bdc:	c7 04 24 22 66 10 00 	movl   $0x106622,(%esp)
  101be3:	e8 ba e6 ff ff       	call   1002a2 <cprintf>
    for (i = 0, j = 1; i < sizeof(IA32flags) / sizeof(IA32flags[0]); i ++, j <<= 1) {
  101be8:	ff 45 f4             	incl   -0xc(%ebp)
  101beb:	d1 65 f0             	shll   -0x10(%ebp)
  101bee:	8b 45 f4             	mov    -0xc(%ebp),%eax
  101bf1:	83 f8 17             	cmp    $0x17,%eax
  101bf4:	76 bb                	jbe    101bb1 <print_trapframe+0x113>
        }
    }
    cprintf("IOPL=%d\n", (tf->tf_eflags & FL_IOPL_MASK) >> 12);
  101bf6:	8b 45 08             	mov    0x8(%ebp),%eax
  101bf9:	8b 40 40             	mov    0x40(%eax),%eax
  101bfc:	c1 e8 0c             	shr    $0xc,%eax
  101bff:	83 e0 03             	and    $0x3,%eax
  101c02:	89 44 24 04          	mov    %eax,0x4(%esp)
  101c06:	c7 04 24 26 66 10 00 	movl   $0x106626,(%esp)
  101c0d:	e8 90 e6 ff ff       	call   1002a2 <cprintf>

    if (!trap_in_kernel(tf)) {
  101c12:	8b 45 08             	mov    0x8(%ebp),%eax
  101c15:	89 04 24             	mov    %eax,(%esp)
  101c18:	e8 6c fe ff ff       	call   101a89 <trap_in_kernel>
  101c1d:	85 c0                	test   %eax,%eax
  101c1f:	75 2d                	jne    101c4e <print_trapframe+0x1b0>
        cprintf("  esp  0x%08x\n", tf->tf_esp);
  101c21:	8b 45 08             	mov    0x8(%ebp),%eax
  101c24:	8b 40 44             	mov    0x44(%eax),%eax
  101c27:	89 44 24 04          	mov    %eax,0x4(%esp)
  101c2b:	c7 04 24 2f 66 10 00 	movl   $0x10662f,(%esp)
  101c32:	e8 6b e6 ff ff       	call   1002a2 <cprintf>
        cprintf("  ss   0x----%04x\n", tf->tf_ss);
  101c37:	8b 45 08             	mov    0x8(%ebp),%eax
  101c3a:	0f b7 40 48          	movzwl 0x48(%eax),%eax
  101c3e:	89 44 24 04          	mov    %eax,0x4(%esp)
  101c42:	c7 04 24 3e 66 10 00 	movl   $0x10663e,(%esp)
  101c49:	e8 54 e6 ff ff       	call   1002a2 <cprintf>
    }
}
  101c4e:	90                   	nop
  101c4f:	c9                   	leave  
  101c50:	c3                   	ret    

00101c51 <print_regs>:

void
print_regs(struct pushregs *regs) {
  101c51:	55                   	push   %ebp
  101c52:	89 e5                	mov    %esp,%ebp
  101c54:	83 ec 18             	sub    $0x18,%esp
    cprintf("  edi  0x%08x\n", regs->reg_edi);
  101c57:	8b 45 08             	mov    0x8(%ebp),%eax
  101c5a:	8b 00                	mov    (%eax),%eax
  101c5c:	89 44 24 04          	mov    %eax,0x4(%esp)
  101c60:	c7 04 24 51 66 10 00 	movl   $0x106651,(%esp)
  101c67:	e8 36 e6 ff ff       	call   1002a2 <cprintf>
    cprintf("  esi  0x%08x\n", regs->reg_esi);
  101c6c:	8b 45 08             	mov    0x8(%ebp),%eax
  101c6f:	8b 40 04             	mov    0x4(%eax),%eax
  101c72:	89 44 24 04          	mov    %eax,0x4(%esp)
  101c76:	c7 04 24 60 66 10 00 	movl   $0x106660,(%esp)
  101c7d:	e8 20 e6 ff ff       	call   1002a2 <cprintf>
    cprintf("  ebp  0x%08x\n", regs->reg_ebp);
  101c82:	8b 45 08             	mov    0x8(%ebp),%eax
  101c85:	8b 40 08             	mov    0x8(%eax),%eax
  101c88:	89 44 24 04          	mov    %eax,0x4(%esp)
  101c8c:	c7 04 24 6f 66 10 00 	movl   $0x10666f,(%esp)
  101c93:	e8 0a e6 ff ff       	call   1002a2 <cprintf>
    cprintf("  oesp 0x%08x\n", regs->reg_oesp);
  101c98:	8b 45 08             	mov    0x8(%ebp),%eax
  101c9b:	8b 40 0c             	mov    0xc(%eax),%eax
  101c9e:	89 44 24 04          	mov    %eax,0x4(%esp)
  101ca2:	c7 04 24 7e 66 10 00 	movl   $0x10667e,(%esp)
  101ca9:	e8 f4 e5 ff ff       	call   1002a2 <cprintf>
    cprintf("  ebx  0x%08x\n", regs->reg_ebx);
  101cae:	8b 45 08             	mov    0x8(%ebp),%eax
  101cb1:	8b 40 10             	mov    0x10(%eax),%eax
  101cb4:	89 44 24 04          	mov    %eax,0x4(%esp)
  101cb8:	c7 04 24 8d 66 10 00 	movl   $0x10668d,(%esp)
  101cbf:	e8 de e5 ff ff       	call   1002a2 <cprintf>
    cprintf("  edx  0x%08x\n", regs->reg_edx);
  101cc4:	8b 45 08             	mov    0x8(%ebp),%eax
  101cc7:	8b 40 14             	mov    0x14(%eax),%eax
  101cca:	89 44 24 04          	mov    %eax,0x4(%esp)
  101cce:	c7 04 24 9c 66 10 00 	movl   $0x10669c,(%esp)
  101cd5:	e8 c8 e5 ff ff       	call   1002a2 <cprintf>
    cprintf("  ecx  0x%08x\n", regs->reg_ecx);
  101cda:	8b 45 08             	mov    0x8(%ebp),%eax
  101cdd:	8b 40 18             	mov    0x18(%eax),%eax
  101ce0:	89 44 24 04          	mov    %eax,0x4(%esp)
  101ce4:	c7 04 24 ab 66 10 00 	movl   $0x1066ab,(%esp)
  101ceb:	e8 b2 e5 ff ff       	call   1002a2 <cprintf>
    cprintf("  eax  0x%08x\n", regs->reg_eax);
  101cf0:	8b 45 08             	mov    0x8(%ebp),%eax
  101cf3:	8b 40 1c             	mov    0x1c(%eax),%eax
  101cf6:	89 44 24 04          	mov    %eax,0x4(%esp)
  101cfa:	c7 04 24 ba 66 10 00 	movl   $0x1066ba,(%esp)
  101d01:	e8 9c e5 ff ff       	call   1002a2 <cprintf>
}
  101d06:	90                   	nop
  101d07:	c9                   	leave  
  101d08:	c3                   	ret    

00101d09 <trap_dispatch>:
/* temporary trapframe or pointer to trapframe */
struct trapframe switchk2u, *switchu2k;

/* trap_dispatch - dispatch based on what type of trap occurred */
static void
trap_dispatch(struct trapframe *tf) {
  101d09:	55                   	push   %ebp
  101d0a:	89 e5                	mov    %esp,%ebp
  101d0c:	57                   	push   %edi
  101d0d:	56                   	push   %esi
  101d0e:	53                   	push   %ebx
  101d0f:	83 ec 2c             	sub    $0x2c,%esp
    char c;

    switch (tf->tf_trapno) {
  101d12:	8b 45 08             	mov    0x8(%ebp),%eax
  101d15:	8b 40 30             	mov    0x30(%eax),%eax
  101d18:	83 f8 2f             	cmp    $0x2f,%eax
  101d1b:	77 21                	ja     101d3e <trap_dispatch+0x35>
  101d1d:	83 f8 2e             	cmp    $0x2e,%eax
  101d20:	0f 83 5d 02 00 00    	jae    101f83 <trap_dispatch+0x27a>
  101d26:	83 f8 21             	cmp    $0x21,%eax
  101d29:	0f 84 95 00 00 00    	je     101dc4 <trap_dispatch+0xbb>
  101d2f:	83 f8 24             	cmp    $0x24,%eax
  101d32:	74 67                	je     101d9b <trap_dispatch+0x92>
  101d34:	83 f8 20             	cmp    $0x20,%eax
  101d37:	74 1c                	je     101d55 <trap_dispatch+0x4c>
  101d39:	e9 10 02 00 00       	jmp    101f4e <trap_dispatch+0x245>
  101d3e:	83 f8 78             	cmp    $0x78,%eax
  101d41:	0f 84 a6 00 00 00    	je     101ded <trap_dispatch+0xe4>
  101d47:	83 f8 79             	cmp    $0x79,%eax
  101d4a:	0f 84 81 01 00 00    	je     101ed1 <trap_dispatch+0x1c8>
  101d50:	e9 f9 01 00 00       	jmp    101f4e <trap_dispatch+0x245>
        /* handle the timer interrupt */
        /* (1) After a timer interrupt, you should record this event using a global variable (increase it), such as ticks in kern/driver/clock.c
         * (2) Every TICK_NUM cycle, you can print some info using a funciton, such as print_ticks().
         * (3) Too Simple? Yes, I think so!
         */
        ticks ++;
  101d55:	a1 0c bf 11 00       	mov    0x11bf0c,%eax
  101d5a:	40                   	inc    %eax
  101d5b:	a3 0c bf 11 00       	mov    %eax,0x11bf0c
        if (ticks % TICK_NUM == 0) {
  101d60:	8b 0d 0c bf 11 00    	mov    0x11bf0c,%ecx
  101d66:	ba 1f 85 eb 51       	mov    $0x51eb851f,%edx
  101d6b:	89 c8                	mov    %ecx,%eax
  101d6d:	f7 e2                	mul    %edx
  101d6f:	c1 ea 05             	shr    $0x5,%edx
  101d72:	89 d0                	mov    %edx,%eax
  101d74:	c1 e0 02             	shl    $0x2,%eax
  101d77:	01 d0                	add    %edx,%eax
  101d79:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
  101d80:	01 d0                	add    %edx,%eax
  101d82:	c1 e0 02             	shl    $0x2,%eax
  101d85:	29 c1                	sub    %eax,%ecx
  101d87:	89 ca                	mov    %ecx,%edx
  101d89:	85 d2                	test   %edx,%edx
  101d8b:	0f 85 f5 01 00 00    	jne    101f86 <trap_dispatch+0x27d>
            print_ticks();
  101d91:	e8 0e fb ff ff       	call   1018a4 <print_ticks>
        }
        break;
  101d96:	e9 eb 01 00 00       	jmp    101f86 <trap_dispatch+0x27d>
    case IRQ_OFFSET + IRQ_COM1:
        c = cons_getc();
  101d9b:	e8 c1 f8 ff ff       	call   101661 <cons_getc>
  101da0:	88 45 e7             	mov    %al,-0x19(%ebp)
        cprintf("serial [%03d] %c\n", c, c);
  101da3:	0f be 55 e7          	movsbl -0x19(%ebp),%edx
  101da7:	0f be 45 e7          	movsbl -0x19(%ebp),%eax
  101dab:	89 54 24 08          	mov    %edx,0x8(%esp)
  101daf:	89 44 24 04          	mov    %eax,0x4(%esp)
  101db3:	c7 04 24 c9 66 10 00 	movl   $0x1066c9,(%esp)
  101dba:	e8 e3 e4 ff ff       	call   1002a2 <cprintf>
        break;
  101dbf:	e9 c9 01 00 00       	jmp    101f8d <trap_dispatch+0x284>
    case IRQ_OFFSET + IRQ_KBD:
        c = cons_getc();
  101dc4:	e8 98 f8 ff ff       	call   101661 <cons_getc>
  101dc9:	88 45 e7             	mov    %al,-0x19(%ebp)
        cprintf("kbd [%03d] %c\n", c, c);
  101dcc:	0f be 55 e7          	movsbl -0x19(%ebp),%edx
  101dd0:	0f be 45 e7          	movsbl -0x19(%ebp),%eax
  101dd4:	89 54 24 08          	mov    %edx,0x8(%esp)
  101dd8:	89 44 24 04          	mov    %eax,0x4(%esp)
  101ddc:	c7 04 24 db 66 10 00 	movl   $0x1066db,(%esp)
  101de3:	e8 ba e4 ff ff       	call   1002a2 <cprintf>
        break;
  101de8:	e9 a0 01 00 00       	jmp    101f8d <trap_dispatch+0x284>
    //LAB1 CHALLENGE 1 : YOUR CODE you should modify below codes.
    case T_SWITCH_TOU:
        if (tf->tf_cs != USER_CS) {
  101ded:	8b 45 08             	mov    0x8(%ebp),%eax
  101df0:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
  101df4:	83 f8 1b             	cmp    $0x1b,%eax
  101df7:	0f 84 8c 01 00 00    	je     101f89 <trap_dispatch+0x280>
            switchk2u = *tf;
  101dfd:	8b 55 08             	mov    0x8(%ebp),%edx
  101e00:	b8 20 bf 11 00       	mov    $0x11bf20,%eax
  101e05:	bb 4c 00 00 00       	mov    $0x4c,%ebx
  101e0a:	89 c1                	mov    %eax,%ecx
  101e0c:	83 e1 01             	and    $0x1,%ecx
  101e0f:	85 c9                	test   %ecx,%ecx
  101e11:	74 0c                	je     101e1f <trap_dispatch+0x116>
  101e13:	0f b6 0a             	movzbl (%edx),%ecx
  101e16:	88 08                	mov    %cl,(%eax)
  101e18:	8d 40 01             	lea    0x1(%eax),%eax
  101e1b:	8d 52 01             	lea    0x1(%edx),%edx
  101e1e:	4b                   	dec    %ebx
  101e1f:	89 c1                	mov    %eax,%ecx
  101e21:	83 e1 02             	and    $0x2,%ecx
  101e24:	85 c9                	test   %ecx,%ecx
  101e26:	74 0f                	je     101e37 <trap_dispatch+0x12e>
  101e28:	0f b7 0a             	movzwl (%edx),%ecx
  101e2b:	66 89 08             	mov    %cx,(%eax)
  101e2e:	8d 40 02             	lea    0x2(%eax),%eax
  101e31:	8d 52 02             	lea    0x2(%edx),%edx
  101e34:	83 eb 02             	sub    $0x2,%ebx
  101e37:	89 df                	mov    %ebx,%edi
  101e39:	83 e7 fc             	and    $0xfffffffc,%edi
  101e3c:	b9 00 00 00 00       	mov    $0x0,%ecx
  101e41:	8b 34 0a             	mov    (%edx,%ecx,1),%esi
  101e44:	89 34 08             	mov    %esi,(%eax,%ecx,1)
  101e47:	83 c1 04             	add    $0x4,%ecx
  101e4a:	39 f9                	cmp    %edi,%ecx
  101e4c:	72 f3                	jb     101e41 <trap_dispatch+0x138>
  101e4e:	01 c8                	add    %ecx,%eax
  101e50:	01 ca                	add    %ecx,%edx
  101e52:	b9 00 00 00 00       	mov    $0x0,%ecx
  101e57:	89 de                	mov    %ebx,%esi
  101e59:	83 e6 02             	and    $0x2,%esi
  101e5c:	85 f6                	test   %esi,%esi
  101e5e:	74 0b                	je     101e6b <trap_dispatch+0x162>
  101e60:	0f b7 34 0a          	movzwl (%edx,%ecx,1),%esi
  101e64:	66 89 34 08          	mov    %si,(%eax,%ecx,1)
  101e68:	83 c1 02             	add    $0x2,%ecx
  101e6b:	83 e3 01             	and    $0x1,%ebx
  101e6e:	85 db                	test   %ebx,%ebx
  101e70:	74 07                	je     101e79 <trap_dispatch+0x170>
  101e72:	0f b6 14 0a          	movzbl (%edx,%ecx,1),%edx
  101e76:	88 14 08             	mov    %dl,(%eax,%ecx,1)
            switchk2u.tf_cs = USER_CS;
  101e79:	66 c7 05 5c bf 11 00 	movw   $0x1b,0x11bf5c
  101e80:	1b 00 
            switchk2u.tf_ds = switchk2u.tf_es = switchk2u.tf_ss = USER_DS;
  101e82:	66 c7 05 68 bf 11 00 	movw   $0x23,0x11bf68
  101e89:	23 00 
  101e8b:	0f b7 05 68 bf 11 00 	movzwl 0x11bf68,%eax
  101e92:	66 a3 48 bf 11 00    	mov    %ax,0x11bf48
  101e98:	0f b7 05 48 bf 11 00 	movzwl 0x11bf48,%eax
  101e9f:	66 a3 4c bf 11 00    	mov    %ax,0x11bf4c
            switchk2u.tf_esp = (uint32_t)tf + sizeof(struct trapframe) - 8;
  101ea5:	8b 45 08             	mov    0x8(%ebp),%eax
  101ea8:	83 c0 44             	add    $0x44,%eax
  101eab:	a3 64 bf 11 00       	mov    %eax,0x11bf64
		
            // set eflags, make sure ucore can use io under user mode.
            // if CPL > IOPL, then cpu will generate a general protection.
            switchk2u.tf_eflags |= FL_IOPL_MASK;
  101eb0:	a1 60 bf 11 00       	mov    0x11bf60,%eax
  101eb5:	0d 00 30 00 00       	or     $0x3000,%eax
  101eba:	a3 60 bf 11 00       	mov    %eax,0x11bf60
		
            // set temporary stack
            // then iret will jump to the right stack
            *((uint32_t *)tf - 1) = (uint32_t)&switchk2u;
  101ebf:	8b 45 08             	mov    0x8(%ebp),%eax
  101ec2:	83 e8 04             	sub    $0x4,%eax
  101ec5:	ba 20 bf 11 00       	mov    $0x11bf20,%edx
  101eca:	89 10                	mov    %edx,(%eax)
        }
        break;
  101ecc:	e9 b8 00 00 00       	jmp    101f89 <trap_dispatch+0x280>
    case T_SWITCH_TOK:
         if (tf->tf_cs != KERNEL_CS) {
  101ed1:	8b 45 08             	mov    0x8(%ebp),%eax
  101ed4:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
  101ed8:	83 f8 08             	cmp    $0x8,%eax
  101edb:	0f 84 ab 00 00 00    	je     101f8c <trap_dispatch+0x283>
            tf->tf_cs = KERNEL_CS;
  101ee1:	8b 45 08             	mov    0x8(%ebp),%eax
  101ee4:	66 c7 40 3c 08 00    	movw   $0x8,0x3c(%eax)
            tf->tf_ds = tf->tf_es = KERNEL_DS;
  101eea:	8b 45 08             	mov    0x8(%ebp),%eax
  101eed:	66 c7 40 28 10 00    	movw   $0x10,0x28(%eax)
  101ef3:	8b 45 08             	mov    0x8(%ebp),%eax
  101ef6:	0f b7 50 28          	movzwl 0x28(%eax),%edx
  101efa:	8b 45 08             	mov    0x8(%ebp),%eax
  101efd:	66 89 50 2c          	mov    %dx,0x2c(%eax)
            tf->tf_eflags &= ~FL_IOPL_MASK;
  101f01:	8b 45 08             	mov    0x8(%ebp),%eax
  101f04:	8b 40 40             	mov    0x40(%eax),%eax
  101f07:	25 ff cf ff ff       	and    $0xffffcfff,%eax
  101f0c:	89 c2                	mov    %eax,%edx
  101f0e:	8b 45 08             	mov    0x8(%ebp),%eax
  101f11:	89 50 40             	mov    %edx,0x40(%eax)
            switchu2k = (struct trapframe *)(tf->tf_esp - (sizeof(struct trapframe) - 8));
  101f14:	8b 45 08             	mov    0x8(%ebp),%eax
  101f17:	8b 40 44             	mov    0x44(%eax),%eax
  101f1a:	83 e8 44             	sub    $0x44,%eax
  101f1d:	a3 6c bf 11 00       	mov    %eax,0x11bf6c
            memmove(switchu2k, tf, sizeof(struct trapframe) - 8);
  101f22:	a1 6c bf 11 00       	mov    0x11bf6c,%eax
  101f27:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
  101f2e:	00 
  101f2f:	8b 55 08             	mov    0x8(%ebp),%edx
  101f32:	89 54 24 04          	mov    %edx,0x4(%esp)
  101f36:	89 04 24             	mov    %eax,(%esp)
  101f39:	e8 86 3a 00 00       	call   1059c4 <memmove>
            *((uint32_t *)tf - 1) = (uint32_t)switchu2k;
  101f3e:	8b 15 6c bf 11 00    	mov    0x11bf6c,%edx
  101f44:	8b 45 08             	mov    0x8(%ebp),%eax
  101f47:	83 e8 04             	sub    $0x4,%eax
  101f4a:	89 10                	mov    %edx,(%eax)
        }
        break;
  101f4c:	eb 3e                	jmp    101f8c <trap_dispatch+0x283>
    case IRQ_OFFSET + IRQ_IDE2:
        /* do nothing */
        break;
    default:
        // in kernel, it must be a mistake
        if ((tf->tf_cs & 3) == 0) {
  101f4e:	8b 45 08             	mov    0x8(%ebp),%eax
  101f51:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
  101f55:	83 e0 03             	and    $0x3,%eax
  101f58:	85 c0                	test   %eax,%eax
  101f5a:	75 31                	jne    101f8d <trap_dispatch+0x284>
            print_trapframe(tf);
  101f5c:	8b 45 08             	mov    0x8(%ebp),%eax
  101f5f:	89 04 24             	mov    %eax,(%esp)
  101f62:	e8 37 fb ff ff       	call   101a9e <print_trapframe>
            panic("unexpected trap in kernel.\n");
  101f67:	c7 44 24 08 ea 66 10 	movl   $0x1066ea,0x8(%esp)
  101f6e:	00 
  101f6f:	c7 44 24 04 d4 00 00 	movl   $0xd4,0x4(%esp)
  101f76:	00 
  101f77:	c7 04 24 0e 65 10 00 	movl   $0x10650e,(%esp)
  101f7e:	e8 76 e4 ff ff       	call   1003f9 <__panic>
        break;
  101f83:	90                   	nop
  101f84:	eb 07                	jmp    101f8d <trap_dispatch+0x284>
        break;
  101f86:	90                   	nop
  101f87:	eb 04                	jmp    101f8d <trap_dispatch+0x284>
        break;
  101f89:	90                   	nop
  101f8a:	eb 01                	jmp    101f8d <trap_dispatch+0x284>
        break;
  101f8c:	90                   	nop
        }
    }
}
  101f8d:	90                   	nop
  101f8e:	83 c4 2c             	add    $0x2c,%esp
  101f91:	5b                   	pop    %ebx
  101f92:	5e                   	pop    %esi
  101f93:	5f                   	pop    %edi
  101f94:	5d                   	pop    %ebp
  101f95:	c3                   	ret    

00101f96 <trap>:
 * trap - handles or dispatches an exception/interrupt. if and when trap() returns,
 * the code in kern/trap/trapentry.S restores the old CPU state saved in the
 * trapframe and then uses the iret instruction to return from the exception.
 * */
void
trap(struct trapframe *tf) {
  101f96:	55                   	push   %ebp
  101f97:	89 e5                	mov    %esp,%ebp
  101f99:	83 ec 18             	sub    $0x18,%esp
    // dispatch based on what type of trap occurred
    trap_dispatch(tf);
  101f9c:	8b 45 08             	mov    0x8(%ebp),%eax
  101f9f:	89 04 24             	mov    %eax,(%esp)
  101fa2:	e8 62 fd ff ff       	call   101d09 <trap_dispatch>
}
  101fa7:	90                   	nop
  101fa8:	c9                   	leave  
  101fa9:	c3                   	ret    

00101faa <vector0>:
# handler
.text
.globl __alltraps
.globl vector0
vector0:
  pushl $0
  101faa:	6a 00                	push   $0x0
  pushl $0
  101fac:	6a 00                	push   $0x0
  jmp __alltraps
  101fae:	e9 69 0a 00 00       	jmp    102a1c <__alltraps>

00101fb3 <vector1>:
.globl vector1
vector1:
  pushl $0
  101fb3:	6a 00                	push   $0x0
  pushl $1
  101fb5:	6a 01                	push   $0x1
  jmp __alltraps
  101fb7:	e9 60 0a 00 00       	jmp    102a1c <__alltraps>

00101fbc <vector2>:
.globl vector2
vector2:
  pushl $0
  101fbc:	6a 00                	push   $0x0
  pushl $2
  101fbe:	6a 02                	push   $0x2
  jmp __alltraps
  101fc0:	e9 57 0a 00 00       	jmp    102a1c <__alltraps>

00101fc5 <vector3>:
.globl vector3
vector3:
  pushl $0
  101fc5:	6a 00                	push   $0x0
  pushl $3
  101fc7:	6a 03                	push   $0x3
  jmp __alltraps
  101fc9:	e9 4e 0a 00 00       	jmp    102a1c <__alltraps>

00101fce <vector4>:
.globl vector4
vector4:
  pushl $0
  101fce:	6a 00                	push   $0x0
  pushl $4
  101fd0:	6a 04                	push   $0x4
  jmp __alltraps
  101fd2:	e9 45 0a 00 00       	jmp    102a1c <__alltraps>

00101fd7 <vector5>:
.globl vector5
vector5:
  pushl $0
  101fd7:	6a 00                	push   $0x0
  pushl $5
  101fd9:	6a 05                	push   $0x5
  jmp __alltraps
  101fdb:	e9 3c 0a 00 00       	jmp    102a1c <__alltraps>

00101fe0 <vector6>:
.globl vector6
vector6:
  pushl $0
  101fe0:	6a 00                	push   $0x0
  pushl $6
  101fe2:	6a 06                	push   $0x6
  jmp __alltraps
  101fe4:	e9 33 0a 00 00       	jmp    102a1c <__alltraps>

00101fe9 <vector7>:
.globl vector7
vector7:
  pushl $0
  101fe9:	6a 00                	push   $0x0
  pushl $7
  101feb:	6a 07                	push   $0x7
  jmp __alltraps
  101fed:	e9 2a 0a 00 00       	jmp    102a1c <__alltraps>

00101ff2 <vector8>:
.globl vector8
vector8:
  pushl $8
  101ff2:	6a 08                	push   $0x8
  jmp __alltraps
  101ff4:	e9 23 0a 00 00       	jmp    102a1c <__alltraps>

00101ff9 <vector9>:
.globl vector9
vector9:
  pushl $0
  101ff9:	6a 00                	push   $0x0
  pushl $9
  101ffb:	6a 09                	push   $0x9
  jmp __alltraps
  101ffd:	e9 1a 0a 00 00       	jmp    102a1c <__alltraps>

00102002 <vector10>:
.globl vector10
vector10:
  pushl $10
  102002:	6a 0a                	push   $0xa
  jmp __alltraps
  102004:	e9 13 0a 00 00       	jmp    102a1c <__alltraps>

00102009 <vector11>:
.globl vector11
vector11:
  pushl $11
  102009:	6a 0b                	push   $0xb
  jmp __alltraps
  10200b:	e9 0c 0a 00 00       	jmp    102a1c <__alltraps>

00102010 <vector12>:
.globl vector12
vector12:
  pushl $12
  102010:	6a 0c                	push   $0xc
  jmp __alltraps
  102012:	e9 05 0a 00 00       	jmp    102a1c <__alltraps>

00102017 <vector13>:
.globl vector13
vector13:
  pushl $13
  102017:	6a 0d                	push   $0xd
  jmp __alltraps
  102019:	e9 fe 09 00 00       	jmp    102a1c <__alltraps>

0010201e <vector14>:
.globl vector14
vector14:
  pushl $14
  10201e:	6a 0e                	push   $0xe
  jmp __alltraps
  102020:	e9 f7 09 00 00       	jmp    102a1c <__alltraps>

00102025 <vector15>:
.globl vector15
vector15:
  pushl $0
  102025:	6a 00                	push   $0x0
  pushl $15
  102027:	6a 0f                	push   $0xf
  jmp __alltraps
  102029:	e9 ee 09 00 00       	jmp    102a1c <__alltraps>

0010202e <vector16>:
.globl vector16
vector16:
  pushl $0
  10202e:	6a 00                	push   $0x0
  pushl $16
  102030:	6a 10                	push   $0x10
  jmp __alltraps
  102032:	e9 e5 09 00 00       	jmp    102a1c <__alltraps>

00102037 <vector17>:
.globl vector17
vector17:
  pushl $17
  102037:	6a 11                	push   $0x11
  jmp __alltraps
  102039:	e9 de 09 00 00       	jmp    102a1c <__alltraps>

0010203e <vector18>:
.globl vector18
vector18:
  pushl $0
  10203e:	6a 00                	push   $0x0
  pushl $18
  102040:	6a 12                	push   $0x12
  jmp __alltraps
  102042:	e9 d5 09 00 00       	jmp    102a1c <__alltraps>

00102047 <vector19>:
.globl vector19
vector19:
  pushl $0
  102047:	6a 00                	push   $0x0
  pushl $19
  102049:	6a 13                	push   $0x13
  jmp __alltraps
  10204b:	e9 cc 09 00 00       	jmp    102a1c <__alltraps>

00102050 <vector20>:
.globl vector20
vector20:
  pushl $0
  102050:	6a 00                	push   $0x0
  pushl $20
  102052:	6a 14                	push   $0x14
  jmp __alltraps
  102054:	e9 c3 09 00 00       	jmp    102a1c <__alltraps>

00102059 <vector21>:
.globl vector21
vector21:
  pushl $0
  102059:	6a 00                	push   $0x0
  pushl $21
  10205b:	6a 15                	push   $0x15
  jmp __alltraps
  10205d:	e9 ba 09 00 00       	jmp    102a1c <__alltraps>

00102062 <vector22>:
.globl vector22
vector22:
  pushl $0
  102062:	6a 00                	push   $0x0
  pushl $22
  102064:	6a 16                	push   $0x16
  jmp __alltraps
  102066:	e9 b1 09 00 00       	jmp    102a1c <__alltraps>

0010206b <vector23>:
.globl vector23
vector23:
  pushl $0
  10206b:	6a 00                	push   $0x0
  pushl $23
  10206d:	6a 17                	push   $0x17
  jmp __alltraps
  10206f:	e9 a8 09 00 00       	jmp    102a1c <__alltraps>

00102074 <vector24>:
.globl vector24
vector24:
  pushl $0
  102074:	6a 00                	push   $0x0
  pushl $24
  102076:	6a 18                	push   $0x18
  jmp __alltraps
  102078:	e9 9f 09 00 00       	jmp    102a1c <__alltraps>

0010207d <vector25>:
.globl vector25
vector25:
  pushl $0
  10207d:	6a 00                	push   $0x0
  pushl $25
  10207f:	6a 19                	push   $0x19
  jmp __alltraps
  102081:	e9 96 09 00 00       	jmp    102a1c <__alltraps>

00102086 <vector26>:
.globl vector26
vector26:
  pushl $0
  102086:	6a 00                	push   $0x0
  pushl $26
  102088:	6a 1a                	push   $0x1a
  jmp __alltraps
  10208a:	e9 8d 09 00 00       	jmp    102a1c <__alltraps>

0010208f <vector27>:
.globl vector27
vector27:
  pushl $0
  10208f:	6a 00                	push   $0x0
  pushl $27
  102091:	6a 1b                	push   $0x1b
  jmp __alltraps
  102093:	e9 84 09 00 00       	jmp    102a1c <__alltraps>

00102098 <vector28>:
.globl vector28
vector28:
  pushl $0
  102098:	6a 00                	push   $0x0
  pushl $28
  10209a:	6a 1c                	push   $0x1c
  jmp __alltraps
  10209c:	e9 7b 09 00 00       	jmp    102a1c <__alltraps>

001020a1 <vector29>:
.globl vector29
vector29:
  pushl $0
  1020a1:	6a 00                	push   $0x0
  pushl $29
  1020a3:	6a 1d                	push   $0x1d
  jmp __alltraps
  1020a5:	e9 72 09 00 00       	jmp    102a1c <__alltraps>

001020aa <vector30>:
.globl vector30
vector30:
  pushl $0
  1020aa:	6a 00                	push   $0x0
  pushl $30
  1020ac:	6a 1e                	push   $0x1e
  jmp __alltraps
  1020ae:	e9 69 09 00 00       	jmp    102a1c <__alltraps>

001020b3 <vector31>:
.globl vector31
vector31:
  pushl $0
  1020b3:	6a 00                	push   $0x0
  pushl $31
  1020b5:	6a 1f                	push   $0x1f
  jmp __alltraps
  1020b7:	e9 60 09 00 00       	jmp    102a1c <__alltraps>

001020bc <vector32>:
.globl vector32
vector32:
  pushl $0
  1020bc:	6a 00                	push   $0x0
  pushl $32
  1020be:	6a 20                	push   $0x20
  jmp __alltraps
  1020c0:	e9 57 09 00 00       	jmp    102a1c <__alltraps>

001020c5 <vector33>:
.globl vector33
vector33:
  pushl $0
  1020c5:	6a 00                	push   $0x0
  pushl $33
  1020c7:	6a 21                	push   $0x21
  jmp __alltraps
  1020c9:	e9 4e 09 00 00       	jmp    102a1c <__alltraps>

001020ce <vector34>:
.globl vector34
vector34:
  pushl $0
  1020ce:	6a 00                	push   $0x0
  pushl $34
  1020d0:	6a 22                	push   $0x22
  jmp __alltraps
  1020d2:	e9 45 09 00 00       	jmp    102a1c <__alltraps>

001020d7 <vector35>:
.globl vector35
vector35:
  pushl $0
  1020d7:	6a 00                	push   $0x0
  pushl $35
  1020d9:	6a 23                	push   $0x23
  jmp __alltraps
  1020db:	e9 3c 09 00 00       	jmp    102a1c <__alltraps>

001020e0 <vector36>:
.globl vector36
vector36:
  pushl $0
  1020e0:	6a 00                	push   $0x0
  pushl $36
  1020e2:	6a 24                	push   $0x24
  jmp __alltraps
  1020e4:	e9 33 09 00 00       	jmp    102a1c <__alltraps>

001020e9 <vector37>:
.globl vector37
vector37:
  pushl $0
  1020e9:	6a 00                	push   $0x0
  pushl $37
  1020eb:	6a 25                	push   $0x25
  jmp __alltraps
  1020ed:	e9 2a 09 00 00       	jmp    102a1c <__alltraps>

001020f2 <vector38>:
.globl vector38
vector38:
  pushl $0
  1020f2:	6a 00                	push   $0x0
  pushl $38
  1020f4:	6a 26                	push   $0x26
  jmp __alltraps
  1020f6:	e9 21 09 00 00       	jmp    102a1c <__alltraps>

001020fb <vector39>:
.globl vector39
vector39:
  pushl $0
  1020fb:	6a 00                	push   $0x0
  pushl $39
  1020fd:	6a 27                	push   $0x27
  jmp __alltraps
  1020ff:	e9 18 09 00 00       	jmp    102a1c <__alltraps>

00102104 <vector40>:
.globl vector40
vector40:
  pushl $0
  102104:	6a 00                	push   $0x0
  pushl $40
  102106:	6a 28                	push   $0x28
  jmp __alltraps
  102108:	e9 0f 09 00 00       	jmp    102a1c <__alltraps>

0010210d <vector41>:
.globl vector41
vector41:
  pushl $0
  10210d:	6a 00                	push   $0x0
  pushl $41
  10210f:	6a 29                	push   $0x29
  jmp __alltraps
  102111:	e9 06 09 00 00       	jmp    102a1c <__alltraps>

00102116 <vector42>:
.globl vector42
vector42:
  pushl $0
  102116:	6a 00                	push   $0x0
  pushl $42
  102118:	6a 2a                	push   $0x2a
  jmp __alltraps
  10211a:	e9 fd 08 00 00       	jmp    102a1c <__alltraps>

0010211f <vector43>:
.globl vector43
vector43:
  pushl $0
  10211f:	6a 00                	push   $0x0
  pushl $43
  102121:	6a 2b                	push   $0x2b
  jmp __alltraps
  102123:	e9 f4 08 00 00       	jmp    102a1c <__alltraps>

00102128 <vector44>:
.globl vector44
vector44:
  pushl $0
  102128:	6a 00                	push   $0x0
  pushl $44
  10212a:	6a 2c                	push   $0x2c
  jmp __alltraps
  10212c:	e9 eb 08 00 00       	jmp    102a1c <__alltraps>

00102131 <vector45>:
.globl vector45
vector45:
  pushl $0
  102131:	6a 00                	push   $0x0
  pushl $45
  102133:	6a 2d                	push   $0x2d
  jmp __alltraps
  102135:	e9 e2 08 00 00       	jmp    102a1c <__alltraps>

0010213a <vector46>:
.globl vector46
vector46:
  pushl $0
  10213a:	6a 00                	push   $0x0
  pushl $46
  10213c:	6a 2e                	push   $0x2e
  jmp __alltraps
  10213e:	e9 d9 08 00 00       	jmp    102a1c <__alltraps>

00102143 <vector47>:
.globl vector47
vector47:
  pushl $0
  102143:	6a 00                	push   $0x0
  pushl $47
  102145:	6a 2f                	push   $0x2f
  jmp __alltraps
  102147:	e9 d0 08 00 00       	jmp    102a1c <__alltraps>

0010214c <vector48>:
.globl vector48
vector48:
  pushl $0
  10214c:	6a 00                	push   $0x0
  pushl $48
  10214e:	6a 30                	push   $0x30
  jmp __alltraps
  102150:	e9 c7 08 00 00       	jmp    102a1c <__alltraps>

00102155 <vector49>:
.globl vector49
vector49:
  pushl $0
  102155:	6a 00                	push   $0x0
  pushl $49
  102157:	6a 31                	push   $0x31
  jmp __alltraps
  102159:	e9 be 08 00 00       	jmp    102a1c <__alltraps>

0010215e <vector50>:
.globl vector50
vector50:
  pushl $0
  10215e:	6a 00                	push   $0x0
  pushl $50
  102160:	6a 32                	push   $0x32
  jmp __alltraps
  102162:	e9 b5 08 00 00       	jmp    102a1c <__alltraps>

00102167 <vector51>:
.globl vector51
vector51:
  pushl $0
  102167:	6a 00                	push   $0x0
  pushl $51
  102169:	6a 33                	push   $0x33
  jmp __alltraps
  10216b:	e9 ac 08 00 00       	jmp    102a1c <__alltraps>

00102170 <vector52>:
.globl vector52
vector52:
  pushl $0
  102170:	6a 00                	push   $0x0
  pushl $52
  102172:	6a 34                	push   $0x34
  jmp __alltraps
  102174:	e9 a3 08 00 00       	jmp    102a1c <__alltraps>

00102179 <vector53>:
.globl vector53
vector53:
  pushl $0
  102179:	6a 00                	push   $0x0
  pushl $53
  10217b:	6a 35                	push   $0x35
  jmp __alltraps
  10217d:	e9 9a 08 00 00       	jmp    102a1c <__alltraps>

00102182 <vector54>:
.globl vector54
vector54:
  pushl $0
  102182:	6a 00                	push   $0x0
  pushl $54
  102184:	6a 36                	push   $0x36
  jmp __alltraps
  102186:	e9 91 08 00 00       	jmp    102a1c <__alltraps>

0010218b <vector55>:
.globl vector55
vector55:
  pushl $0
  10218b:	6a 00                	push   $0x0
  pushl $55
  10218d:	6a 37                	push   $0x37
  jmp __alltraps
  10218f:	e9 88 08 00 00       	jmp    102a1c <__alltraps>

00102194 <vector56>:
.globl vector56
vector56:
  pushl $0
  102194:	6a 00                	push   $0x0
  pushl $56
  102196:	6a 38                	push   $0x38
  jmp __alltraps
  102198:	e9 7f 08 00 00       	jmp    102a1c <__alltraps>

0010219d <vector57>:
.globl vector57
vector57:
  pushl $0
  10219d:	6a 00                	push   $0x0
  pushl $57
  10219f:	6a 39                	push   $0x39
  jmp __alltraps
  1021a1:	e9 76 08 00 00       	jmp    102a1c <__alltraps>

001021a6 <vector58>:
.globl vector58
vector58:
  pushl $0
  1021a6:	6a 00                	push   $0x0
  pushl $58
  1021a8:	6a 3a                	push   $0x3a
  jmp __alltraps
  1021aa:	e9 6d 08 00 00       	jmp    102a1c <__alltraps>

001021af <vector59>:
.globl vector59
vector59:
  pushl $0
  1021af:	6a 00                	push   $0x0
  pushl $59
  1021b1:	6a 3b                	push   $0x3b
  jmp __alltraps
  1021b3:	e9 64 08 00 00       	jmp    102a1c <__alltraps>

001021b8 <vector60>:
.globl vector60
vector60:
  pushl $0
  1021b8:	6a 00                	push   $0x0
  pushl $60
  1021ba:	6a 3c                	push   $0x3c
  jmp __alltraps
  1021bc:	e9 5b 08 00 00       	jmp    102a1c <__alltraps>

001021c1 <vector61>:
.globl vector61
vector61:
  pushl $0
  1021c1:	6a 00                	push   $0x0
  pushl $61
  1021c3:	6a 3d                	push   $0x3d
  jmp __alltraps
  1021c5:	e9 52 08 00 00       	jmp    102a1c <__alltraps>

001021ca <vector62>:
.globl vector62
vector62:
  pushl $0
  1021ca:	6a 00                	push   $0x0
  pushl $62
  1021cc:	6a 3e                	push   $0x3e
  jmp __alltraps
  1021ce:	e9 49 08 00 00       	jmp    102a1c <__alltraps>

001021d3 <vector63>:
.globl vector63
vector63:
  pushl $0
  1021d3:	6a 00                	push   $0x0
  pushl $63
  1021d5:	6a 3f                	push   $0x3f
  jmp __alltraps
  1021d7:	e9 40 08 00 00       	jmp    102a1c <__alltraps>

001021dc <vector64>:
.globl vector64
vector64:
  pushl $0
  1021dc:	6a 00                	push   $0x0
  pushl $64
  1021de:	6a 40                	push   $0x40
  jmp __alltraps
  1021e0:	e9 37 08 00 00       	jmp    102a1c <__alltraps>

001021e5 <vector65>:
.globl vector65
vector65:
  pushl $0
  1021e5:	6a 00                	push   $0x0
  pushl $65
  1021e7:	6a 41                	push   $0x41
  jmp __alltraps
  1021e9:	e9 2e 08 00 00       	jmp    102a1c <__alltraps>

001021ee <vector66>:
.globl vector66
vector66:
  pushl $0
  1021ee:	6a 00                	push   $0x0
  pushl $66
  1021f0:	6a 42                	push   $0x42
  jmp __alltraps
  1021f2:	e9 25 08 00 00       	jmp    102a1c <__alltraps>

001021f7 <vector67>:
.globl vector67
vector67:
  pushl $0
  1021f7:	6a 00                	push   $0x0
  pushl $67
  1021f9:	6a 43                	push   $0x43
  jmp __alltraps
  1021fb:	e9 1c 08 00 00       	jmp    102a1c <__alltraps>

00102200 <vector68>:
.globl vector68
vector68:
  pushl $0
  102200:	6a 00                	push   $0x0
  pushl $68
  102202:	6a 44                	push   $0x44
  jmp __alltraps
  102204:	e9 13 08 00 00       	jmp    102a1c <__alltraps>

00102209 <vector69>:
.globl vector69
vector69:
  pushl $0
  102209:	6a 00                	push   $0x0
  pushl $69
  10220b:	6a 45                	push   $0x45
  jmp __alltraps
  10220d:	e9 0a 08 00 00       	jmp    102a1c <__alltraps>

00102212 <vector70>:
.globl vector70
vector70:
  pushl $0
  102212:	6a 00                	push   $0x0
  pushl $70
  102214:	6a 46                	push   $0x46
  jmp __alltraps
  102216:	e9 01 08 00 00       	jmp    102a1c <__alltraps>

0010221b <vector71>:
.globl vector71
vector71:
  pushl $0
  10221b:	6a 00                	push   $0x0
  pushl $71
  10221d:	6a 47                	push   $0x47
  jmp __alltraps
  10221f:	e9 f8 07 00 00       	jmp    102a1c <__alltraps>

00102224 <vector72>:
.globl vector72
vector72:
  pushl $0
  102224:	6a 00                	push   $0x0
  pushl $72
  102226:	6a 48                	push   $0x48
  jmp __alltraps
  102228:	e9 ef 07 00 00       	jmp    102a1c <__alltraps>

0010222d <vector73>:
.globl vector73
vector73:
  pushl $0
  10222d:	6a 00                	push   $0x0
  pushl $73
  10222f:	6a 49                	push   $0x49
  jmp __alltraps
  102231:	e9 e6 07 00 00       	jmp    102a1c <__alltraps>

00102236 <vector74>:
.globl vector74
vector74:
  pushl $0
  102236:	6a 00                	push   $0x0
  pushl $74
  102238:	6a 4a                	push   $0x4a
  jmp __alltraps
  10223a:	e9 dd 07 00 00       	jmp    102a1c <__alltraps>

0010223f <vector75>:
.globl vector75
vector75:
  pushl $0
  10223f:	6a 00                	push   $0x0
  pushl $75
  102241:	6a 4b                	push   $0x4b
  jmp __alltraps
  102243:	e9 d4 07 00 00       	jmp    102a1c <__alltraps>

00102248 <vector76>:
.globl vector76
vector76:
  pushl $0
  102248:	6a 00                	push   $0x0
  pushl $76
  10224a:	6a 4c                	push   $0x4c
  jmp __alltraps
  10224c:	e9 cb 07 00 00       	jmp    102a1c <__alltraps>

00102251 <vector77>:
.globl vector77
vector77:
  pushl $0
  102251:	6a 00                	push   $0x0
  pushl $77
  102253:	6a 4d                	push   $0x4d
  jmp __alltraps
  102255:	e9 c2 07 00 00       	jmp    102a1c <__alltraps>

0010225a <vector78>:
.globl vector78
vector78:
  pushl $0
  10225a:	6a 00                	push   $0x0
  pushl $78
  10225c:	6a 4e                	push   $0x4e
  jmp __alltraps
  10225e:	e9 b9 07 00 00       	jmp    102a1c <__alltraps>

00102263 <vector79>:
.globl vector79
vector79:
  pushl $0
  102263:	6a 00                	push   $0x0
  pushl $79
  102265:	6a 4f                	push   $0x4f
  jmp __alltraps
  102267:	e9 b0 07 00 00       	jmp    102a1c <__alltraps>

0010226c <vector80>:
.globl vector80
vector80:
  pushl $0
  10226c:	6a 00                	push   $0x0
  pushl $80
  10226e:	6a 50                	push   $0x50
  jmp __alltraps
  102270:	e9 a7 07 00 00       	jmp    102a1c <__alltraps>

00102275 <vector81>:
.globl vector81
vector81:
  pushl $0
  102275:	6a 00                	push   $0x0
  pushl $81
  102277:	6a 51                	push   $0x51
  jmp __alltraps
  102279:	e9 9e 07 00 00       	jmp    102a1c <__alltraps>

0010227e <vector82>:
.globl vector82
vector82:
  pushl $0
  10227e:	6a 00                	push   $0x0
  pushl $82
  102280:	6a 52                	push   $0x52
  jmp __alltraps
  102282:	e9 95 07 00 00       	jmp    102a1c <__alltraps>

00102287 <vector83>:
.globl vector83
vector83:
  pushl $0
  102287:	6a 00                	push   $0x0
  pushl $83
  102289:	6a 53                	push   $0x53
  jmp __alltraps
  10228b:	e9 8c 07 00 00       	jmp    102a1c <__alltraps>

00102290 <vector84>:
.globl vector84
vector84:
  pushl $0
  102290:	6a 00                	push   $0x0
  pushl $84
  102292:	6a 54                	push   $0x54
  jmp __alltraps
  102294:	e9 83 07 00 00       	jmp    102a1c <__alltraps>

00102299 <vector85>:
.globl vector85
vector85:
  pushl $0
  102299:	6a 00                	push   $0x0
  pushl $85
  10229b:	6a 55                	push   $0x55
  jmp __alltraps
  10229d:	e9 7a 07 00 00       	jmp    102a1c <__alltraps>

001022a2 <vector86>:
.globl vector86
vector86:
  pushl $0
  1022a2:	6a 00                	push   $0x0
  pushl $86
  1022a4:	6a 56                	push   $0x56
  jmp __alltraps
  1022a6:	e9 71 07 00 00       	jmp    102a1c <__alltraps>

001022ab <vector87>:
.globl vector87
vector87:
  pushl $0
  1022ab:	6a 00                	push   $0x0
  pushl $87
  1022ad:	6a 57                	push   $0x57
  jmp __alltraps
  1022af:	e9 68 07 00 00       	jmp    102a1c <__alltraps>

001022b4 <vector88>:
.globl vector88
vector88:
  pushl $0
  1022b4:	6a 00                	push   $0x0
  pushl $88
  1022b6:	6a 58                	push   $0x58
  jmp __alltraps
  1022b8:	e9 5f 07 00 00       	jmp    102a1c <__alltraps>

001022bd <vector89>:
.globl vector89
vector89:
  pushl $0
  1022bd:	6a 00                	push   $0x0
  pushl $89
  1022bf:	6a 59                	push   $0x59
  jmp __alltraps
  1022c1:	e9 56 07 00 00       	jmp    102a1c <__alltraps>

001022c6 <vector90>:
.globl vector90
vector90:
  pushl $0
  1022c6:	6a 00                	push   $0x0
  pushl $90
  1022c8:	6a 5a                	push   $0x5a
  jmp __alltraps
  1022ca:	e9 4d 07 00 00       	jmp    102a1c <__alltraps>

001022cf <vector91>:
.globl vector91
vector91:
  pushl $0
  1022cf:	6a 00                	push   $0x0
  pushl $91
  1022d1:	6a 5b                	push   $0x5b
  jmp __alltraps
  1022d3:	e9 44 07 00 00       	jmp    102a1c <__alltraps>

001022d8 <vector92>:
.globl vector92
vector92:
  pushl $0
  1022d8:	6a 00                	push   $0x0
  pushl $92
  1022da:	6a 5c                	push   $0x5c
  jmp __alltraps
  1022dc:	e9 3b 07 00 00       	jmp    102a1c <__alltraps>

001022e1 <vector93>:
.globl vector93
vector93:
  pushl $0
  1022e1:	6a 00                	push   $0x0
  pushl $93
  1022e3:	6a 5d                	push   $0x5d
  jmp __alltraps
  1022e5:	e9 32 07 00 00       	jmp    102a1c <__alltraps>

001022ea <vector94>:
.globl vector94
vector94:
  pushl $0
  1022ea:	6a 00                	push   $0x0
  pushl $94
  1022ec:	6a 5e                	push   $0x5e
  jmp __alltraps
  1022ee:	e9 29 07 00 00       	jmp    102a1c <__alltraps>

001022f3 <vector95>:
.globl vector95
vector95:
  pushl $0
  1022f3:	6a 00                	push   $0x0
  pushl $95
  1022f5:	6a 5f                	push   $0x5f
  jmp __alltraps
  1022f7:	e9 20 07 00 00       	jmp    102a1c <__alltraps>

001022fc <vector96>:
.globl vector96
vector96:
  pushl $0
  1022fc:	6a 00                	push   $0x0
  pushl $96
  1022fe:	6a 60                	push   $0x60
  jmp __alltraps
  102300:	e9 17 07 00 00       	jmp    102a1c <__alltraps>

00102305 <vector97>:
.globl vector97
vector97:
  pushl $0
  102305:	6a 00                	push   $0x0
  pushl $97
  102307:	6a 61                	push   $0x61
  jmp __alltraps
  102309:	e9 0e 07 00 00       	jmp    102a1c <__alltraps>

0010230e <vector98>:
.globl vector98
vector98:
  pushl $0
  10230e:	6a 00                	push   $0x0
  pushl $98
  102310:	6a 62                	push   $0x62
  jmp __alltraps
  102312:	e9 05 07 00 00       	jmp    102a1c <__alltraps>

00102317 <vector99>:
.globl vector99
vector99:
  pushl $0
  102317:	6a 00                	push   $0x0
  pushl $99
  102319:	6a 63                	push   $0x63
  jmp __alltraps
  10231b:	e9 fc 06 00 00       	jmp    102a1c <__alltraps>

00102320 <vector100>:
.globl vector100
vector100:
  pushl $0
  102320:	6a 00                	push   $0x0
  pushl $100
  102322:	6a 64                	push   $0x64
  jmp __alltraps
  102324:	e9 f3 06 00 00       	jmp    102a1c <__alltraps>

00102329 <vector101>:
.globl vector101
vector101:
  pushl $0
  102329:	6a 00                	push   $0x0
  pushl $101
  10232b:	6a 65                	push   $0x65
  jmp __alltraps
  10232d:	e9 ea 06 00 00       	jmp    102a1c <__alltraps>

00102332 <vector102>:
.globl vector102
vector102:
  pushl $0
  102332:	6a 00                	push   $0x0
  pushl $102
  102334:	6a 66                	push   $0x66
  jmp __alltraps
  102336:	e9 e1 06 00 00       	jmp    102a1c <__alltraps>

0010233b <vector103>:
.globl vector103
vector103:
  pushl $0
  10233b:	6a 00                	push   $0x0
  pushl $103
  10233d:	6a 67                	push   $0x67
  jmp __alltraps
  10233f:	e9 d8 06 00 00       	jmp    102a1c <__alltraps>

00102344 <vector104>:
.globl vector104
vector104:
  pushl $0
  102344:	6a 00                	push   $0x0
  pushl $104
  102346:	6a 68                	push   $0x68
  jmp __alltraps
  102348:	e9 cf 06 00 00       	jmp    102a1c <__alltraps>

0010234d <vector105>:
.globl vector105
vector105:
  pushl $0
  10234d:	6a 00                	push   $0x0
  pushl $105
  10234f:	6a 69                	push   $0x69
  jmp __alltraps
  102351:	e9 c6 06 00 00       	jmp    102a1c <__alltraps>

00102356 <vector106>:
.globl vector106
vector106:
  pushl $0
  102356:	6a 00                	push   $0x0
  pushl $106
  102358:	6a 6a                	push   $0x6a
  jmp __alltraps
  10235a:	e9 bd 06 00 00       	jmp    102a1c <__alltraps>

0010235f <vector107>:
.globl vector107
vector107:
  pushl $0
  10235f:	6a 00                	push   $0x0
  pushl $107
  102361:	6a 6b                	push   $0x6b
  jmp __alltraps
  102363:	e9 b4 06 00 00       	jmp    102a1c <__alltraps>

00102368 <vector108>:
.globl vector108
vector108:
  pushl $0
  102368:	6a 00                	push   $0x0
  pushl $108
  10236a:	6a 6c                	push   $0x6c
  jmp __alltraps
  10236c:	e9 ab 06 00 00       	jmp    102a1c <__alltraps>

00102371 <vector109>:
.globl vector109
vector109:
  pushl $0
  102371:	6a 00                	push   $0x0
  pushl $109
  102373:	6a 6d                	push   $0x6d
  jmp __alltraps
  102375:	e9 a2 06 00 00       	jmp    102a1c <__alltraps>

0010237a <vector110>:
.globl vector110
vector110:
  pushl $0
  10237a:	6a 00                	push   $0x0
  pushl $110
  10237c:	6a 6e                	push   $0x6e
  jmp __alltraps
  10237e:	e9 99 06 00 00       	jmp    102a1c <__alltraps>

00102383 <vector111>:
.globl vector111
vector111:
  pushl $0
  102383:	6a 00                	push   $0x0
  pushl $111
  102385:	6a 6f                	push   $0x6f
  jmp __alltraps
  102387:	e9 90 06 00 00       	jmp    102a1c <__alltraps>

0010238c <vector112>:
.globl vector112
vector112:
  pushl $0
  10238c:	6a 00                	push   $0x0
  pushl $112
  10238e:	6a 70                	push   $0x70
  jmp __alltraps
  102390:	e9 87 06 00 00       	jmp    102a1c <__alltraps>

00102395 <vector113>:
.globl vector113
vector113:
  pushl $0
  102395:	6a 00                	push   $0x0
  pushl $113
  102397:	6a 71                	push   $0x71
  jmp __alltraps
  102399:	e9 7e 06 00 00       	jmp    102a1c <__alltraps>

0010239e <vector114>:
.globl vector114
vector114:
  pushl $0
  10239e:	6a 00                	push   $0x0
  pushl $114
  1023a0:	6a 72                	push   $0x72
  jmp __alltraps
  1023a2:	e9 75 06 00 00       	jmp    102a1c <__alltraps>

001023a7 <vector115>:
.globl vector115
vector115:
  pushl $0
  1023a7:	6a 00                	push   $0x0
  pushl $115
  1023a9:	6a 73                	push   $0x73
  jmp __alltraps
  1023ab:	e9 6c 06 00 00       	jmp    102a1c <__alltraps>

001023b0 <vector116>:
.globl vector116
vector116:
  pushl $0
  1023b0:	6a 00                	push   $0x0
  pushl $116
  1023b2:	6a 74                	push   $0x74
  jmp __alltraps
  1023b4:	e9 63 06 00 00       	jmp    102a1c <__alltraps>

001023b9 <vector117>:
.globl vector117
vector117:
  pushl $0
  1023b9:	6a 00                	push   $0x0
  pushl $117
  1023bb:	6a 75                	push   $0x75
  jmp __alltraps
  1023bd:	e9 5a 06 00 00       	jmp    102a1c <__alltraps>

001023c2 <vector118>:
.globl vector118
vector118:
  pushl $0
  1023c2:	6a 00                	push   $0x0
  pushl $118
  1023c4:	6a 76                	push   $0x76
  jmp __alltraps
  1023c6:	e9 51 06 00 00       	jmp    102a1c <__alltraps>

001023cb <vector119>:
.globl vector119
vector119:
  pushl $0
  1023cb:	6a 00                	push   $0x0
  pushl $119
  1023cd:	6a 77                	push   $0x77
  jmp __alltraps
  1023cf:	e9 48 06 00 00       	jmp    102a1c <__alltraps>

001023d4 <vector120>:
.globl vector120
vector120:
  pushl $0
  1023d4:	6a 00                	push   $0x0
  pushl $120
  1023d6:	6a 78                	push   $0x78
  jmp __alltraps
  1023d8:	e9 3f 06 00 00       	jmp    102a1c <__alltraps>

001023dd <vector121>:
.globl vector121
vector121:
  pushl $0
  1023dd:	6a 00                	push   $0x0
  pushl $121
  1023df:	6a 79                	push   $0x79
  jmp __alltraps
  1023e1:	e9 36 06 00 00       	jmp    102a1c <__alltraps>

001023e6 <vector122>:
.globl vector122
vector122:
  pushl $0
  1023e6:	6a 00                	push   $0x0
  pushl $122
  1023e8:	6a 7a                	push   $0x7a
  jmp __alltraps
  1023ea:	e9 2d 06 00 00       	jmp    102a1c <__alltraps>

001023ef <vector123>:
.globl vector123
vector123:
  pushl $0
  1023ef:	6a 00                	push   $0x0
  pushl $123
  1023f1:	6a 7b                	push   $0x7b
  jmp __alltraps
  1023f3:	e9 24 06 00 00       	jmp    102a1c <__alltraps>

001023f8 <vector124>:
.globl vector124
vector124:
  pushl $0
  1023f8:	6a 00                	push   $0x0
  pushl $124
  1023fa:	6a 7c                	push   $0x7c
  jmp __alltraps
  1023fc:	e9 1b 06 00 00       	jmp    102a1c <__alltraps>

00102401 <vector125>:
.globl vector125
vector125:
  pushl $0
  102401:	6a 00                	push   $0x0
  pushl $125
  102403:	6a 7d                	push   $0x7d
  jmp __alltraps
  102405:	e9 12 06 00 00       	jmp    102a1c <__alltraps>

0010240a <vector126>:
.globl vector126
vector126:
  pushl $0
  10240a:	6a 00                	push   $0x0
  pushl $126
  10240c:	6a 7e                	push   $0x7e
  jmp __alltraps
  10240e:	e9 09 06 00 00       	jmp    102a1c <__alltraps>

00102413 <vector127>:
.globl vector127
vector127:
  pushl $0
  102413:	6a 00                	push   $0x0
  pushl $127
  102415:	6a 7f                	push   $0x7f
  jmp __alltraps
  102417:	e9 00 06 00 00       	jmp    102a1c <__alltraps>

0010241c <vector128>:
.globl vector128
vector128:
  pushl $0
  10241c:	6a 00                	push   $0x0
  pushl $128
  10241e:	68 80 00 00 00       	push   $0x80
  jmp __alltraps
  102423:	e9 f4 05 00 00       	jmp    102a1c <__alltraps>

00102428 <vector129>:
.globl vector129
vector129:
  pushl $0
  102428:	6a 00                	push   $0x0
  pushl $129
  10242a:	68 81 00 00 00       	push   $0x81
  jmp __alltraps
  10242f:	e9 e8 05 00 00       	jmp    102a1c <__alltraps>

00102434 <vector130>:
.globl vector130
vector130:
  pushl $0
  102434:	6a 00                	push   $0x0
  pushl $130
  102436:	68 82 00 00 00       	push   $0x82
  jmp __alltraps
  10243b:	e9 dc 05 00 00       	jmp    102a1c <__alltraps>

00102440 <vector131>:
.globl vector131
vector131:
  pushl $0
  102440:	6a 00                	push   $0x0
  pushl $131
  102442:	68 83 00 00 00       	push   $0x83
  jmp __alltraps
  102447:	e9 d0 05 00 00       	jmp    102a1c <__alltraps>

0010244c <vector132>:
.globl vector132
vector132:
  pushl $0
  10244c:	6a 00                	push   $0x0
  pushl $132
  10244e:	68 84 00 00 00       	push   $0x84
  jmp __alltraps
  102453:	e9 c4 05 00 00       	jmp    102a1c <__alltraps>

00102458 <vector133>:
.globl vector133
vector133:
  pushl $0
  102458:	6a 00                	push   $0x0
  pushl $133
  10245a:	68 85 00 00 00       	push   $0x85
  jmp __alltraps
  10245f:	e9 b8 05 00 00       	jmp    102a1c <__alltraps>

00102464 <vector134>:
.globl vector134
vector134:
  pushl $0
  102464:	6a 00                	push   $0x0
  pushl $134
  102466:	68 86 00 00 00       	push   $0x86
  jmp __alltraps
  10246b:	e9 ac 05 00 00       	jmp    102a1c <__alltraps>

00102470 <vector135>:
.globl vector135
vector135:
  pushl $0
  102470:	6a 00                	push   $0x0
  pushl $135
  102472:	68 87 00 00 00       	push   $0x87
  jmp __alltraps
  102477:	e9 a0 05 00 00       	jmp    102a1c <__alltraps>

0010247c <vector136>:
.globl vector136
vector136:
  pushl $0
  10247c:	6a 00                	push   $0x0
  pushl $136
  10247e:	68 88 00 00 00       	push   $0x88
  jmp __alltraps
  102483:	e9 94 05 00 00       	jmp    102a1c <__alltraps>

00102488 <vector137>:
.globl vector137
vector137:
  pushl $0
  102488:	6a 00                	push   $0x0
  pushl $137
  10248a:	68 89 00 00 00       	push   $0x89
  jmp __alltraps
  10248f:	e9 88 05 00 00       	jmp    102a1c <__alltraps>

00102494 <vector138>:
.globl vector138
vector138:
  pushl $0
  102494:	6a 00                	push   $0x0
  pushl $138
  102496:	68 8a 00 00 00       	push   $0x8a
  jmp __alltraps
  10249b:	e9 7c 05 00 00       	jmp    102a1c <__alltraps>

001024a0 <vector139>:
.globl vector139
vector139:
  pushl $0
  1024a0:	6a 00                	push   $0x0
  pushl $139
  1024a2:	68 8b 00 00 00       	push   $0x8b
  jmp __alltraps
  1024a7:	e9 70 05 00 00       	jmp    102a1c <__alltraps>

001024ac <vector140>:
.globl vector140
vector140:
  pushl $0
  1024ac:	6a 00                	push   $0x0
  pushl $140
  1024ae:	68 8c 00 00 00       	push   $0x8c
  jmp __alltraps
  1024b3:	e9 64 05 00 00       	jmp    102a1c <__alltraps>

001024b8 <vector141>:
.globl vector141
vector141:
  pushl $0
  1024b8:	6a 00                	push   $0x0
  pushl $141
  1024ba:	68 8d 00 00 00       	push   $0x8d
  jmp __alltraps
  1024bf:	e9 58 05 00 00       	jmp    102a1c <__alltraps>

001024c4 <vector142>:
.globl vector142
vector142:
  pushl $0
  1024c4:	6a 00                	push   $0x0
  pushl $142
  1024c6:	68 8e 00 00 00       	push   $0x8e
  jmp __alltraps
  1024cb:	e9 4c 05 00 00       	jmp    102a1c <__alltraps>

001024d0 <vector143>:
.globl vector143
vector143:
  pushl $0
  1024d0:	6a 00                	push   $0x0
  pushl $143
  1024d2:	68 8f 00 00 00       	push   $0x8f
  jmp __alltraps
  1024d7:	e9 40 05 00 00       	jmp    102a1c <__alltraps>

001024dc <vector144>:
.globl vector144
vector144:
  pushl $0
  1024dc:	6a 00                	push   $0x0
  pushl $144
  1024de:	68 90 00 00 00       	push   $0x90
  jmp __alltraps
  1024e3:	e9 34 05 00 00       	jmp    102a1c <__alltraps>

001024e8 <vector145>:
.globl vector145
vector145:
  pushl $0
  1024e8:	6a 00                	push   $0x0
  pushl $145
  1024ea:	68 91 00 00 00       	push   $0x91
  jmp __alltraps
  1024ef:	e9 28 05 00 00       	jmp    102a1c <__alltraps>

001024f4 <vector146>:
.globl vector146
vector146:
  pushl $0
  1024f4:	6a 00                	push   $0x0
  pushl $146
  1024f6:	68 92 00 00 00       	push   $0x92
  jmp __alltraps
  1024fb:	e9 1c 05 00 00       	jmp    102a1c <__alltraps>

00102500 <vector147>:
.globl vector147
vector147:
  pushl $0
  102500:	6a 00                	push   $0x0
  pushl $147
  102502:	68 93 00 00 00       	push   $0x93
  jmp __alltraps
  102507:	e9 10 05 00 00       	jmp    102a1c <__alltraps>

0010250c <vector148>:
.globl vector148
vector148:
  pushl $0
  10250c:	6a 00                	push   $0x0
  pushl $148
  10250e:	68 94 00 00 00       	push   $0x94
  jmp __alltraps
  102513:	e9 04 05 00 00       	jmp    102a1c <__alltraps>

00102518 <vector149>:
.globl vector149
vector149:
  pushl $0
  102518:	6a 00                	push   $0x0
  pushl $149
  10251a:	68 95 00 00 00       	push   $0x95
  jmp __alltraps
  10251f:	e9 f8 04 00 00       	jmp    102a1c <__alltraps>

00102524 <vector150>:
.globl vector150
vector150:
  pushl $0
  102524:	6a 00                	push   $0x0
  pushl $150
  102526:	68 96 00 00 00       	push   $0x96
  jmp __alltraps
  10252b:	e9 ec 04 00 00       	jmp    102a1c <__alltraps>

00102530 <vector151>:
.globl vector151
vector151:
  pushl $0
  102530:	6a 00                	push   $0x0
  pushl $151
  102532:	68 97 00 00 00       	push   $0x97
  jmp __alltraps
  102537:	e9 e0 04 00 00       	jmp    102a1c <__alltraps>

0010253c <vector152>:
.globl vector152
vector152:
  pushl $0
  10253c:	6a 00                	push   $0x0
  pushl $152
  10253e:	68 98 00 00 00       	push   $0x98
  jmp __alltraps
  102543:	e9 d4 04 00 00       	jmp    102a1c <__alltraps>

00102548 <vector153>:
.globl vector153
vector153:
  pushl $0
  102548:	6a 00                	push   $0x0
  pushl $153
  10254a:	68 99 00 00 00       	push   $0x99
  jmp __alltraps
  10254f:	e9 c8 04 00 00       	jmp    102a1c <__alltraps>

00102554 <vector154>:
.globl vector154
vector154:
  pushl $0
  102554:	6a 00                	push   $0x0
  pushl $154
  102556:	68 9a 00 00 00       	push   $0x9a
  jmp __alltraps
  10255b:	e9 bc 04 00 00       	jmp    102a1c <__alltraps>

00102560 <vector155>:
.globl vector155
vector155:
  pushl $0
  102560:	6a 00                	push   $0x0
  pushl $155
  102562:	68 9b 00 00 00       	push   $0x9b
  jmp __alltraps
  102567:	e9 b0 04 00 00       	jmp    102a1c <__alltraps>

0010256c <vector156>:
.globl vector156
vector156:
  pushl $0
  10256c:	6a 00                	push   $0x0
  pushl $156
  10256e:	68 9c 00 00 00       	push   $0x9c
  jmp __alltraps
  102573:	e9 a4 04 00 00       	jmp    102a1c <__alltraps>

00102578 <vector157>:
.globl vector157
vector157:
  pushl $0
  102578:	6a 00                	push   $0x0
  pushl $157
  10257a:	68 9d 00 00 00       	push   $0x9d
  jmp __alltraps
  10257f:	e9 98 04 00 00       	jmp    102a1c <__alltraps>

00102584 <vector158>:
.globl vector158
vector158:
  pushl $0
  102584:	6a 00                	push   $0x0
  pushl $158
  102586:	68 9e 00 00 00       	push   $0x9e
  jmp __alltraps
  10258b:	e9 8c 04 00 00       	jmp    102a1c <__alltraps>

00102590 <vector159>:
.globl vector159
vector159:
  pushl $0
  102590:	6a 00                	push   $0x0
  pushl $159
  102592:	68 9f 00 00 00       	push   $0x9f
  jmp __alltraps
  102597:	e9 80 04 00 00       	jmp    102a1c <__alltraps>

0010259c <vector160>:
.globl vector160
vector160:
  pushl $0
  10259c:	6a 00                	push   $0x0
  pushl $160
  10259e:	68 a0 00 00 00       	push   $0xa0
  jmp __alltraps
  1025a3:	e9 74 04 00 00       	jmp    102a1c <__alltraps>

001025a8 <vector161>:
.globl vector161
vector161:
  pushl $0
  1025a8:	6a 00                	push   $0x0
  pushl $161
  1025aa:	68 a1 00 00 00       	push   $0xa1
  jmp __alltraps
  1025af:	e9 68 04 00 00       	jmp    102a1c <__alltraps>

001025b4 <vector162>:
.globl vector162
vector162:
  pushl $0
  1025b4:	6a 00                	push   $0x0
  pushl $162
  1025b6:	68 a2 00 00 00       	push   $0xa2
  jmp __alltraps
  1025bb:	e9 5c 04 00 00       	jmp    102a1c <__alltraps>

001025c0 <vector163>:
.globl vector163
vector163:
  pushl $0
  1025c0:	6a 00                	push   $0x0
  pushl $163
  1025c2:	68 a3 00 00 00       	push   $0xa3
  jmp __alltraps
  1025c7:	e9 50 04 00 00       	jmp    102a1c <__alltraps>

001025cc <vector164>:
.globl vector164
vector164:
  pushl $0
  1025cc:	6a 00                	push   $0x0
  pushl $164
  1025ce:	68 a4 00 00 00       	push   $0xa4
  jmp __alltraps
  1025d3:	e9 44 04 00 00       	jmp    102a1c <__alltraps>

001025d8 <vector165>:
.globl vector165
vector165:
  pushl $0
  1025d8:	6a 00                	push   $0x0
  pushl $165
  1025da:	68 a5 00 00 00       	push   $0xa5
  jmp __alltraps
  1025df:	e9 38 04 00 00       	jmp    102a1c <__alltraps>

001025e4 <vector166>:
.globl vector166
vector166:
  pushl $0
  1025e4:	6a 00                	push   $0x0
  pushl $166
  1025e6:	68 a6 00 00 00       	push   $0xa6
  jmp __alltraps
  1025eb:	e9 2c 04 00 00       	jmp    102a1c <__alltraps>

001025f0 <vector167>:
.globl vector167
vector167:
  pushl $0
  1025f0:	6a 00                	push   $0x0
  pushl $167
  1025f2:	68 a7 00 00 00       	push   $0xa7
  jmp __alltraps
  1025f7:	e9 20 04 00 00       	jmp    102a1c <__alltraps>

001025fc <vector168>:
.globl vector168
vector168:
  pushl $0
  1025fc:	6a 00                	push   $0x0
  pushl $168
  1025fe:	68 a8 00 00 00       	push   $0xa8
  jmp __alltraps
  102603:	e9 14 04 00 00       	jmp    102a1c <__alltraps>

00102608 <vector169>:
.globl vector169
vector169:
  pushl $0
  102608:	6a 00                	push   $0x0
  pushl $169
  10260a:	68 a9 00 00 00       	push   $0xa9
  jmp __alltraps
  10260f:	e9 08 04 00 00       	jmp    102a1c <__alltraps>

00102614 <vector170>:
.globl vector170
vector170:
  pushl $0
  102614:	6a 00                	push   $0x0
  pushl $170
  102616:	68 aa 00 00 00       	push   $0xaa
  jmp __alltraps
  10261b:	e9 fc 03 00 00       	jmp    102a1c <__alltraps>

00102620 <vector171>:
.globl vector171
vector171:
  pushl $0
  102620:	6a 00                	push   $0x0
  pushl $171
  102622:	68 ab 00 00 00       	push   $0xab
  jmp __alltraps
  102627:	e9 f0 03 00 00       	jmp    102a1c <__alltraps>

0010262c <vector172>:
.globl vector172
vector172:
  pushl $0
  10262c:	6a 00                	push   $0x0
  pushl $172
  10262e:	68 ac 00 00 00       	push   $0xac
  jmp __alltraps
  102633:	e9 e4 03 00 00       	jmp    102a1c <__alltraps>

00102638 <vector173>:
.globl vector173
vector173:
  pushl $0
  102638:	6a 00                	push   $0x0
  pushl $173
  10263a:	68 ad 00 00 00       	push   $0xad
  jmp __alltraps
  10263f:	e9 d8 03 00 00       	jmp    102a1c <__alltraps>

00102644 <vector174>:
.globl vector174
vector174:
  pushl $0
  102644:	6a 00                	push   $0x0
  pushl $174
  102646:	68 ae 00 00 00       	push   $0xae
  jmp __alltraps
  10264b:	e9 cc 03 00 00       	jmp    102a1c <__alltraps>

00102650 <vector175>:
.globl vector175
vector175:
  pushl $0
  102650:	6a 00                	push   $0x0
  pushl $175
  102652:	68 af 00 00 00       	push   $0xaf
  jmp __alltraps
  102657:	e9 c0 03 00 00       	jmp    102a1c <__alltraps>

0010265c <vector176>:
.globl vector176
vector176:
  pushl $0
  10265c:	6a 00                	push   $0x0
  pushl $176
  10265e:	68 b0 00 00 00       	push   $0xb0
  jmp __alltraps
  102663:	e9 b4 03 00 00       	jmp    102a1c <__alltraps>

00102668 <vector177>:
.globl vector177
vector177:
  pushl $0
  102668:	6a 00                	push   $0x0
  pushl $177
  10266a:	68 b1 00 00 00       	push   $0xb1
  jmp __alltraps
  10266f:	e9 a8 03 00 00       	jmp    102a1c <__alltraps>

00102674 <vector178>:
.globl vector178
vector178:
  pushl $0
  102674:	6a 00                	push   $0x0
  pushl $178
  102676:	68 b2 00 00 00       	push   $0xb2
  jmp __alltraps
  10267b:	e9 9c 03 00 00       	jmp    102a1c <__alltraps>

00102680 <vector179>:
.globl vector179
vector179:
  pushl $0
  102680:	6a 00                	push   $0x0
  pushl $179
  102682:	68 b3 00 00 00       	push   $0xb3
  jmp __alltraps
  102687:	e9 90 03 00 00       	jmp    102a1c <__alltraps>

0010268c <vector180>:
.globl vector180
vector180:
  pushl $0
  10268c:	6a 00                	push   $0x0
  pushl $180
  10268e:	68 b4 00 00 00       	push   $0xb4
  jmp __alltraps
  102693:	e9 84 03 00 00       	jmp    102a1c <__alltraps>

00102698 <vector181>:
.globl vector181
vector181:
  pushl $0
  102698:	6a 00                	push   $0x0
  pushl $181
  10269a:	68 b5 00 00 00       	push   $0xb5
  jmp __alltraps
  10269f:	e9 78 03 00 00       	jmp    102a1c <__alltraps>

001026a4 <vector182>:
.globl vector182
vector182:
  pushl $0
  1026a4:	6a 00                	push   $0x0
  pushl $182
  1026a6:	68 b6 00 00 00       	push   $0xb6
  jmp __alltraps
  1026ab:	e9 6c 03 00 00       	jmp    102a1c <__alltraps>

001026b0 <vector183>:
.globl vector183
vector183:
  pushl $0
  1026b0:	6a 00                	push   $0x0
  pushl $183
  1026b2:	68 b7 00 00 00       	push   $0xb7
  jmp __alltraps
  1026b7:	e9 60 03 00 00       	jmp    102a1c <__alltraps>

001026bc <vector184>:
.globl vector184
vector184:
  pushl $0
  1026bc:	6a 00                	push   $0x0
  pushl $184
  1026be:	68 b8 00 00 00       	push   $0xb8
  jmp __alltraps
  1026c3:	e9 54 03 00 00       	jmp    102a1c <__alltraps>

001026c8 <vector185>:
.globl vector185
vector185:
  pushl $0
  1026c8:	6a 00                	push   $0x0
  pushl $185
  1026ca:	68 b9 00 00 00       	push   $0xb9
  jmp __alltraps
  1026cf:	e9 48 03 00 00       	jmp    102a1c <__alltraps>

001026d4 <vector186>:
.globl vector186
vector186:
  pushl $0
  1026d4:	6a 00                	push   $0x0
  pushl $186
  1026d6:	68 ba 00 00 00       	push   $0xba
  jmp __alltraps
  1026db:	e9 3c 03 00 00       	jmp    102a1c <__alltraps>

001026e0 <vector187>:
.globl vector187
vector187:
  pushl $0
  1026e0:	6a 00                	push   $0x0
  pushl $187
  1026e2:	68 bb 00 00 00       	push   $0xbb
  jmp __alltraps
  1026e7:	e9 30 03 00 00       	jmp    102a1c <__alltraps>

001026ec <vector188>:
.globl vector188
vector188:
  pushl $0
  1026ec:	6a 00                	push   $0x0
  pushl $188
  1026ee:	68 bc 00 00 00       	push   $0xbc
  jmp __alltraps
  1026f3:	e9 24 03 00 00       	jmp    102a1c <__alltraps>

001026f8 <vector189>:
.globl vector189
vector189:
  pushl $0
  1026f8:	6a 00                	push   $0x0
  pushl $189
  1026fa:	68 bd 00 00 00       	push   $0xbd
  jmp __alltraps
  1026ff:	e9 18 03 00 00       	jmp    102a1c <__alltraps>

00102704 <vector190>:
.globl vector190
vector190:
  pushl $0
  102704:	6a 00                	push   $0x0
  pushl $190
  102706:	68 be 00 00 00       	push   $0xbe
  jmp __alltraps
  10270b:	e9 0c 03 00 00       	jmp    102a1c <__alltraps>

00102710 <vector191>:
.globl vector191
vector191:
  pushl $0
  102710:	6a 00                	push   $0x0
  pushl $191
  102712:	68 bf 00 00 00       	push   $0xbf
  jmp __alltraps
  102717:	e9 00 03 00 00       	jmp    102a1c <__alltraps>

0010271c <vector192>:
.globl vector192
vector192:
  pushl $0
  10271c:	6a 00                	push   $0x0
  pushl $192
  10271e:	68 c0 00 00 00       	push   $0xc0
  jmp __alltraps
  102723:	e9 f4 02 00 00       	jmp    102a1c <__alltraps>

00102728 <vector193>:
.globl vector193
vector193:
  pushl $0
  102728:	6a 00                	push   $0x0
  pushl $193
  10272a:	68 c1 00 00 00       	push   $0xc1
  jmp __alltraps
  10272f:	e9 e8 02 00 00       	jmp    102a1c <__alltraps>

00102734 <vector194>:
.globl vector194
vector194:
  pushl $0
  102734:	6a 00                	push   $0x0
  pushl $194
  102736:	68 c2 00 00 00       	push   $0xc2
  jmp __alltraps
  10273b:	e9 dc 02 00 00       	jmp    102a1c <__alltraps>

00102740 <vector195>:
.globl vector195
vector195:
  pushl $0
  102740:	6a 00                	push   $0x0
  pushl $195
  102742:	68 c3 00 00 00       	push   $0xc3
  jmp __alltraps
  102747:	e9 d0 02 00 00       	jmp    102a1c <__alltraps>

0010274c <vector196>:
.globl vector196
vector196:
  pushl $0
  10274c:	6a 00                	push   $0x0
  pushl $196
  10274e:	68 c4 00 00 00       	push   $0xc4
  jmp __alltraps
  102753:	e9 c4 02 00 00       	jmp    102a1c <__alltraps>

00102758 <vector197>:
.globl vector197
vector197:
  pushl $0
  102758:	6a 00                	push   $0x0
  pushl $197
  10275a:	68 c5 00 00 00       	push   $0xc5
  jmp __alltraps
  10275f:	e9 b8 02 00 00       	jmp    102a1c <__alltraps>

00102764 <vector198>:
.globl vector198
vector198:
  pushl $0
  102764:	6a 00                	push   $0x0
  pushl $198
  102766:	68 c6 00 00 00       	push   $0xc6
  jmp __alltraps
  10276b:	e9 ac 02 00 00       	jmp    102a1c <__alltraps>

00102770 <vector199>:
.globl vector199
vector199:
  pushl $0
  102770:	6a 00                	push   $0x0
  pushl $199
  102772:	68 c7 00 00 00       	push   $0xc7
  jmp __alltraps
  102777:	e9 a0 02 00 00       	jmp    102a1c <__alltraps>

0010277c <vector200>:
.globl vector200
vector200:
  pushl $0
  10277c:	6a 00                	push   $0x0
  pushl $200
  10277e:	68 c8 00 00 00       	push   $0xc8
  jmp __alltraps
  102783:	e9 94 02 00 00       	jmp    102a1c <__alltraps>

00102788 <vector201>:
.globl vector201
vector201:
  pushl $0
  102788:	6a 00                	push   $0x0
  pushl $201
  10278a:	68 c9 00 00 00       	push   $0xc9
  jmp __alltraps
  10278f:	e9 88 02 00 00       	jmp    102a1c <__alltraps>

00102794 <vector202>:
.globl vector202
vector202:
  pushl $0
  102794:	6a 00                	push   $0x0
  pushl $202
  102796:	68 ca 00 00 00       	push   $0xca
  jmp __alltraps
  10279b:	e9 7c 02 00 00       	jmp    102a1c <__alltraps>

001027a0 <vector203>:
.globl vector203
vector203:
  pushl $0
  1027a0:	6a 00                	push   $0x0
  pushl $203
  1027a2:	68 cb 00 00 00       	push   $0xcb
  jmp __alltraps
  1027a7:	e9 70 02 00 00       	jmp    102a1c <__alltraps>

001027ac <vector204>:
.globl vector204
vector204:
  pushl $0
  1027ac:	6a 00                	push   $0x0
  pushl $204
  1027ae:	68 cc 00 00 00       	push   $0xcc
  jmp __alltraps
  1027b3:	e9 64 02 00 00       	jmp    102a1c <__alltraps>

001027b8 <vector205>:
.globl vector205
vector205:
  pushl $0
  1027b8:	6a 00                	push   $0x0
  pushl $205
  1027ba:	68 cd 00 00 00       	push   $0xcd
  jmp __alltraps
  1027bf:	e9 58 02 00 00       	jmp    102a1c <__alltraps>

001027c4 <vector206>:
.globl vector206
vector206:
  pushl $0
  1027c4:	6a 00                	push   $0x0
  pushl $206
  1027c6:	68 ce 00 00 00       	push   $0xce
  jmp __alltraps
  1027cb:	e9 4c 02 00 00       	jmp    102a1c <__alltraps>

001027d0 <vector207>:
.globl vector207
vector207:
  pushl $0
  1027d0:	6a 00                	push   $0x0
  pushl $207
  1027d2:	68 cf 00 00 00       	push   $0xcf
  jmp __alltraps
  1027d7:	e9 40 02 00 00       	jmp    102a1c <__alltraps>

001027dc <vector208>:
.globl vector208
vector208:
  pushl $0
  1027dc:	6a 00                	push   $0x0
  pushl $208
  1027de:	68 d0 00 00 00       	push   $0xd0
  jmp __alltraps
  1027e3:	e9 34 02 00 00       	jmp    102a1c <__alltraps>

001027e8 <vector209>:
.globl vector209
vector209:
  pushl $0
  1027e8:	6a 00                	push   $0x0
  pushl $209
  1027ea:	68 d1 00 00 00       	push   $0xd1
  jmp __alltraps
  1027ef:	e9 28 02 00 00       	jmp    102a1c <__alltraps>

001027f4 <vector210>:
.globl vector210
vector210:
  pushl $0
  1027f4:	6a 00                	push   $0x0
  pushl $210
  1027f6:	68 d2 00 00 00       	push   $0xd2
  jmp __alltraps
  1027fb:	e9 1c 02 00 00       	jmp    102a1c <__alltraps>

00102800 <vector211>:
.globl vector211
vector211:
  pushl $0
  102800:	6a 00                	push   $0x0
  pushl $211
  102802:	68 d3 00 00 00       	push   $0xd3
  jmp __alltraps
  102807:	e9 10 02 00 00       	jmp    102a1c <__alltraps>

0010280c <vector212>:
.globl vector212
vector212:
  pushl $0
  10280c:	6a 00                	push   $0x0
  pushl $212
  10280e:	68 d4 00 00 00       	push   $0xd4
  jmp __alltraps
  102813:	e9 04 02 00 00       	jmp    102a1c <__alltraps>

00102818 <vector213>:
.globl vector213
vector213:
  pushl $0
  102818:	6a 00                	push   $0x0
  pushl $213
  10281a:	68 d5 00 00 00       	push   $0xd5
  jmp __alltraps
  10281f:	e9 f8 01 00 00       	jmp    102a1c <__alltraps>

00102824 <vector214>:
.globl vector214
vector214:
  pushl $0
  102824:	6a 00                	push   $0x0
  pushl $214
  102826:	68 d6 00 00 00       	push   $0xd6
  jmp __alltraps
  10282b:	e9 ec 01 00 00       	jmp    102a1c <__alltraps>

00102830 <vector215>:
.globl vector215
vector215:
  pushl $0
  102830:	6a 00                	push   $0x0
  pushl $215
  102832:	68 d7 00 00 00       	push   $0xd7
  jmp __alltraps
  102837:	e9 e0 01 00 00       	jmp    102a1c <__alltraps>

0010283c <vector216>:
.globl vector216
vector216:
  pushl $0
  10283c:	6a 00                	push   $0x0
  pushl $216
  10283e:	68 d8 00 00 00       	push   $0xd8
  jmp __alltraps
  102843:	e9 d4 01 00 00       	jmp    102a1c <__alltraps>

00102848 <vector217>:
.globl vector217
vector217:
  pushl $0
  102848:	6a 00                	push   $0x0
  pushl $217
  10284a:	68 d9 00 00 00       	push   $0xd9
  jmp __alltraps
  10284f:	e9 c8 01 00 00       	jmp    102a1c <__alltraps>

00102854 <vector218>:
.globl vector218
vector218:
  pushl $0
  102854:	6a 00                	push   $0x0
  pushl $218
  102856:	68 da 00 00 00       	push   $0xda
  jmp __alltraps
  10285b:	e9 bc 01 00 00       	jmp    102a1c <__alltraps>

00102860 <vector219>:
.globl vector219
vector219:
  pushl $0
  102860:	6a 00                	push   $0x0
  pushl $219
  102862:	68 db 00 00 00       	push   $0xdb
  jmp __alltraps
  102867:	e9 b0 01 00 00       	jmp    102a1c <__alltraps>

0010286c <vector220>:
.globl vector220
vector220:
  pushl $0
  10286c:	6a 00                	push   $0x0
  pushl $220
  10286e:	68 dc 00 00 00       	push   $0xdc
  jmp __alltraps
  102873:	e9 a4 01 00 00       	jmp    102a1c <__alltraps>

00102878 <vector221>:
.globl vector221
vector221:
  pushl $0
  102878:	6a 00                	push   $0x0
  pushl $221
  10287a:	68 dd 00 00 00       	push   $0xdd
  jmp __alltraps
  10287f:	e9 98 01 00 00       	jmp    102a1c <__alltraps>

00102884 <vector222>:
.globl vector222
vector222:
  pushl $0
  102884:	6a 00                	push   $0x0
  pushl $222
  102886:	68 de 00 00 00       	push   $0xde
  jmp __alltraps
  10288b:	e9 8c 01 00 00       	jmp    102a1c <__alltraps>

00102890 <vector223>:
.globl vector223
vector223:
  pushl $0
  102890:	6a 00                	push   $0x0
  pushl $223
  102892:	68 df 00 00 00       	push   $0xdf
  jmp __alltraps
  102897:	e9 80 01 00 00       	jmp    102a1c <__alltraps>

0010289c <vector224>:
.globl vector224
vector224:
  pushl $0
  10289c:	6a 00                	push   $0x0
  pushl $224
  10289e:	68 e0 00 00 00       	push   $0xe0
  jmp __alltraps
  1028a3:	e9 74 01 00 00       	jmp    102a1c <__alltraps>

001028a8 <vector225>:
.globl vector225
vector225:
  pushl $0
  1028a8:	6a 00                	push   $0x0
  pushl $225
  1028aa:	68 e1 00 00 00       	push   $0xe1
  jmp __alltraps
  1028af:	e9 68 01 00 00       	jmp    102a1c <__alltraps>

001028b4 <vector226>:
.globl vector226
vector226:
  pushl $0
  1028b4:	6a 00                	push   $0x0
  pushl $226
  1028b6:	68 e2 00 00 00       	push   $0xe2
  jmp __alltraps
  1028bb:	e9 5c 01 00 00       	jmp    102a1c <__alltraps>

001028c0 <vector227>:
.globl vector227
vector227:
  pushl $0
  1028c0:	6a 00                	push   $0x0
  pushl $227
  1028c2:	68 e3 00 00 00       	push   $0xe3
  jmp __alltraps
  1028c7:	e9 50 01 00 00       	jmp    102a1c <__alltraps>

001028cc <vector228>:
.globl vector228
vector228:
  pushl $0
  1028cc:	6a 00                	push   $0x0
  pushl $228
  1028ce:	68 e4 00 00 00       	push   $0xe4
  jmp __alltraps
  1028d3:	e9 44 01 00 00       	jmp    102a1c <__alltraps>

001028d8 <vector229>:
.globl vector229
vector229:
  pushl $0
  1028d8:	6a 00                	push   $0x0
  pushl $229
  1028da:	68 e5 00 00 00       	push   $0xe5
  jmp __alltraps
  1028df:	e9 38 01 00 00       	jmp    102a1c <__alltraps>

001028e4 <vector230>:
.globl vector230
vector230:
  pushl $0
  1028e4:	6a 00                	push   $0x0
  pushl $230
  1028e6:	68 e6 00 00 00       	push   $0xe6
  jmp __alltraps
  1028eb:	e9 2c 01 00 00       	jmp    102a1c <__alltraps>

001028f0 <vector231>:
.globl vector231
vector231:
  pushl $0
  1028f0:	6a 00                	push   $0x0
  pushl $231
  1028f2:	68 e7 00 00 00       	push   $0xe7
  jmp __alltraps
  1028f7:	e9 20 01 00 00       	jmp    102a1c <__alltraps>

001028fc <vector232>:
.globl vector232
vector232:
  pushl $0
  1028fc:	6a 00                	push   $0x0
  pushl $232
  1028fe:	68 e8 00 00 00       	push   $0xe8
  jmp __alltraps
  102903:	e9 14 01 00 00       	jmp    102a1c <__alltraps>

00102908 <vector233>:
.globl vector233
vector233:
  pushl $0
  102908:	6a 00                	push   $0x0
  pushl $233
  10290a:	68 e9 00 00 00       	push   $0xe9
  jmp __alltraps
  10290f:	e9 08 01 00 00       	jmp    102a1c <__alltraps>

00102914 <vector234>:
.globl vector234
vector234:
  pushl $0
  102914:	6a 00                	push   $0x0
  pushl $234
  102916:	68 ea 00 00 00       	push   $0xea
  jmp __alltraps
  10291b:	e9 fc 00 00 00       	jmp    102a1c <__alltraps>

00102920 <vector235>:
.globl vector235
vector235:
  pushl $0
  102920:	6a 00                	push   $0x0
  pushl $235
  102922:	68 eb 00 00 00       	push   $0xeb
  jmp __alltraps
  102927:	e9 f0 00 00 00       	jmp    102a1c <__alltraps>

0010292c <vector236>:
.globl vector236
vector236:
  pushl $0
  10292c:	6a 00                	push   $0x0
  pushl $236
  10292e:	68 ec 00 00 00       	push   $0xec
  jmp __alltraps
  102933:	e9 e4 00 00 00       	jmp    102a1c <__alltraps>

00102938 <vector237>:
.globl vector237
vector237:
  pushl $0
  102938:	6a 00                	push   $0x0
  pushl $237
  10293a:	68 ed 00 00 00       	push   $0xed
  jmp __alltraps
  10293f:	e9 d8 00 00 00       	jmp    102a1c <__alltraps>

00102944 <vector238>:
.globl vector238
vector238:
  pushl $0
  102944:	6a 00                	push   $0x0
  pushl $238
  102946:	68 ee 00 00 00       	push   $0xee
  jmp __alltraps
  10294b:	e9 cc 00 00 00       	jmp    102a1c <__alltraps>

00102950 <vector239>:
.globl vector239
vector239:
  pushl $0
  102950:	6a 00                	push   $0x0
  pushl $239
  102952:	68 ef 00 00 00       	push   $0xef
  jmp __alltraps
  102957:	e9 c0 00 00 00       	jmp    102a1c <__alltraps>

0010295c <vector240>:
.globl vector240
vector240:
  pushl $0
  10295c:	6a 00                	push   $0x0
  pushl $240
  10295e:	68 f0 00 00 00       	push   $0xf0
  jmp __alltraps
  102963:	e9 b4 00 00 00       	jmp    102a1c <__alltraps>

00102968 <vector241>:
.globl vector241
vector241:
  pushl $0
  102968:	6a 00                	push   $0x0
  pushl $241
  10296a:	68 f1 00 00 00       	push   $0xf1
  jmp __alltraps
  10296f:	e9 a8 00 00 00       	jmp    102a1c <__alltraps>

00102974 <vector242>:
.globl vector242
vector242:
  pushl $0
  102974:	6a 00                	push   $0x0
  pushl $242
  102976:	68 f2 00 00 00       	push   $0xf2
  jmp __alltraps
  10297b:	e9 9c 00 00 00       	jmp    102a1c <__alltraps>

00102980 <vector243>:
.globl vector243
vector243:
  pushl $0
  102980:	6a 00                	push   $0x0
  pushl $243
  102982:	68 f3 00 00 00       	push   $0xf3
  jmp __alltraps
  102987:	e9 90 00 00 00       	jmp    102a1c <__alltraps>

0010298c <vector244>:
.globl vector244
vector244:
  pushl $0
  10298c:	6a 00                	push   $0x0
  pushl $244
  10298e:	68 f4 00 00 00       	push   $0xf4
  jmp __alltraps
  102993:	e9 84 00 00 00       	jmp    102a1c <__alltraps>

00102998 <vector245>:
.globl vector245
vector245:
  pushl $0
  102998:	6a 00                	push   $0x0
  pushl $245
  10299a:	68 f5 00 00 00       	push   $0xf5
  jmp __alltraps
  10299f:	e9 78 00 00 00       	jmp    102a1c <__alltraps>

001029a4 <vector246>:
.globl vector246
vector246:
  pushl $0
  1029a4:	6a 00                	push   $0x0
  pushl $246
  1029a6:	68 f6 00 00 00       	push   $0xf6
  jmp __alltraps
  1029ab:	e9 6c 00 00 00       	jmp    102a1c <__alltraps>

001029b0 <vector247>:
.globl vector247
vector247:
  pushl $0
  1029b0:	6a 00                	push   $0x0
  pushl $247
  1029b2:	68 f7 00 00 00       	push   $0xf7
  jmp __alltraps
  1029b7:	e9 60 00 00 00       	jmp    102a1c <__alltraps>

001029bc <vector248>:
.globl vector248
vector248:
  pushl $0
  1029bc:	6a 00                	push   $0x0
  pushl $248
  1029be:	68 f8 00 00 00       	push   $0xf8
  jmp __alltraps
  1029c3:	e9 54 00 00 00       	jmp    102a1c <__alltraps>

001029c8 <vector249>:
.globl vector249
vector249:
  pushl $0
  1029c8:	6a 00                	push   $0x0
  pushl $249
  1029ca:	68 f9 00 00 00       	push   $0xf9
  jmp __alltraps
  1029cf:	e9 48 00 00 00       	jmp    102a1c <__alltraps>

001029d4 <vector250>:
.globl vector250
vector250:
  pushl $0
  1029d4:	6a 00                	push   $0x0
  pushl $250
  1029d6:	68 fa 00 00 00       	push   $0xfa
  jmp __alltraps
  1029db:	e9 3c 00 00 00       	jmp    102a1c <__alltraps>

001029e0 <vector251>:
.globl vector251
vector251:
  pushl $0
  1029e0:	6a 00                	push   $0x0
  pushl $251
  1029e2:	68 fb 00 00 00       	push   $0xfb
  jmp __alltraps
  1029e7:	e9 30 00 00 00       	jmp    102a1c <__alltraps>

001029ec <vector252>:
.globl vector252
vector252:
  pushl $0
  1029ec:	6a 00                	push   $0x0
  pushl $252
  1029ee:	68 fc 00 00 00       	push   $0xfc
  jmp __alltraps
  1029f3:	e9 24 00 00 00       	jmp    102a1c <__alltraps>

001029f8 <vector253>:
.globl vector253
vector253:
  pushl $0
  1029f8:	6a 00                	push   $0x0
  pushl $253
  1029fa:	68 fd 00 00 00       	push   $0xfd
  jmp __alltraps
  1029ff:	e9 18 00 00 00       	jmp    102a1c <__alltraps>

00102a04 <vector254>:
.globl vector254
vector254:
  pushl $0
  102a04:	6a 00                	push   $0x0
  pushl $254
  102a06:	68 fe 00 00 00       	push   $0xfe
  jmp __alltraps
  102a0b:	e9 0c 00 00 00       	jmp    102a1c <__alltraps>

00102a10 <vector255>:
.globl vector255
vector255:
  pushl $0
  102a10:	6a 00                	push   $0x0
  pushl $255
  102a12:	68 ff 00 00 00       	push   $0xff
  jmp __alltraps
  102a17:	e9 00 00 00 00       	jmp    102a1c <__alltraps>

00102a1c <__alltraps>:
.text
.globl __alltraps
__alltraps:
    # push registers to build a trap frame
    # therefore make the stack look like a struct trapframe
    pushl %ds
  102a1c:	1e                   	push   %ds
    pushl %es
  102a1d:	06                   	push   %es
    pushl %fs
  102a1e:	0f a0                	push   %fs
    pushl %gs
  102a20:	0f a8                	push   %gs
    pushal
  102a22:	60                   	pusha  

    # load GD_KDATA into %ds and %es to set up data segments for kernel
    movl $GD_KDATA, %eax
  102a23:	b8 10 00 00 00       	mov    $0x10,%eax
    movw %ax, %ds
  102a28:	8e d8                	mov    %eax,%ds
    movw %ax, %es
  102a2a:	8e c0                	mov    %eax,%es

    # push %esp to pass a pointer to the trapframe as an argument to trap()
    pushl %esp
  102a2c:	54                   	push   %esp

    # call trap(tf), where tf=%esp
    call trap
  102a2d:	e8 64 f5 ff ff       	call   101f96 <trap>

    # pop the pushed stack pointer
    popl %esp
  102a32:	5c                   	pop    %esp

00102a33 <__trapret>:

    # return falls through to trapret...
.globl __trapret
__trapret:
    # restore registers from stack
    popal
  102a33:	61                   	popa   

    # restore %ds, %es, %fs and %gs
    popl %gs
  102a34:	0f a9                	pop    %gs
    popl %fs
  102a36:	0f a1                	pop    %fs
    popl %es
  102a38:	07                   	pop    %es
    popl %ds
  102a39:	1f                   	pop    %ds

    # get rid of the trap number and error code
    addl $0x8, %esp
  102a3a:	83 c4 08             	add    $0x8,%esp
    iret
  102a3d:	cf                   	iret   

00102a3e <page2ppn>:

extern struct Page *pages;
extern size_t npage;

static inline ppn_t
page2ppn(struct Page *page) {
  102a3e:	55                   	push   %ebp
  102a3f:	89 e5                	mov    %esp,%ebp
    return page - pages;
  102a41:	8b 45 08             	mov    0x8(%ebp),%eax
  102a44:	8b 15 78 bf 11 00    	mov    0x11bf78,%edx
  102a4a:	29 d0                	sub    %edx,%eax
  102a4c:	c1 f8 02             	sar    $0x2,%eax
  102a4f:	69 c0 cd cc cc cc    	imul   $0xcccccccd,%eax,%eax
}
  102a55:	5d                   	pop    %ebp
  102a56:	c3                   	ret    

00102a57 <page2pa>:

static inline uintptr_t
page2pa(struct Page *page) {
  102a57:	55                   	push   %ebp
  102a58:	89 e5                	mov    %esp,%ebp
  102a5a:	83 ec 04             	sub    $0x4,%esp
    return page2ppn(page) << PGSHIFT;
  102a5d:	8b 45 08             	mov    0x8(%ebp),%eax
  102a60:	89 04 24             	mov    %eax,(%esp)
  102a63:	e8 d6 ff ff ff       	call   102a3e <page2ppn>
  102a68:	c1 e0 0c             	shl    $0xc,%eax
}
  102a6b:	c9                   	leave  
  102a6c:	c3                   	ret    

00102a6d <pa2page>:

static inline struct Page *
pa2page(uintptr_t pa) {
  102a6d:	55                   	push   %ebp
  102a6e:	89 e5                	mov    %esp,%ebp
  102a70:	83 ec 18             	sub    $0x18,%esp
    if (PPN(pa) >= npage) {
  102a73:	8b 45 08             	mov    0x8(%ebp),%eax
  102a76:	c1 e8 0c             	shr    $0xc,%eax
  102a79:	89 c2                	mov    %eax,%edx
  102a7b:	a1 80 be 11 00       	mov    0x11be80,%eax
  102a80:	39 c2                	cmp    %eax,%edx
  102a82:	72 1c                	jb     102aa0 <pa2page+0x33>
        panic("pa2page called with invalid pa");
  102a84:	c7 44 24 08 b0 68 10 	movl   $0x1068b0,0x8(%esp)
  102a8b:	00 
  102a8c:	c7 44 24 04 5b 00 00 	movl   $0x5b,0x4(%esp)
  102a93:	00 
  102a94:	c7 04 24 cf 68 10 00 	movl   $0x1068cf,(%esp)
  102a9b:	e8 59 d9 ff ff       	call   1003f9 <__panic>
    }
    return &pages[PPN(pa)];
  102aa0:	8b 0d 78 bf 11 00    	mov    0x11bf78,%ecx
  102aa6:	8b 45 08             	mov    0x8(%ebp),%eax
  102aa9:	c1 e8 0c             	shr    $0xc,%eax
  102aac:	89 c2                	mov    %eax,%edx
  102aae:	89 d0                	mov    %edx,%eax
  102ab0:	c1 e0 02             	shl    $0x2,%eax
  102ab3:	01 d0                	add    %edx,%eax
  102ab5:	c1 e0 02             	shl    $0x2,%eax
  102ab8:	01 c8                	add    %ecx,%eax
}
  102aba:	c9                   	leave  
  102abb:	c3                   	ret    

00102abc <page2kva>:

static inline void *
page2kva(struct Page *page) {
  102abc:	55                   	push   %ebp
  102abd:	89 e5                	mov    %esp,%ebp
  102abf:	83 ec 28             	sub    $0x28,%esp
    return KADDR(page2pa(page));
  102ac2:	8b 45 08             	mov    0x8(%ebp),%eax
  102ac5:	89 04 24             	mov    %eax,(%esp)
  102ac8:	e8 8a ff ff ff       	call   102a57 <page2pa>
  102acd:	89 45 f4             	mov    %eax,-0xc(%ebp)
  102ad0:	8b 45 f4             	mov    -0xc(%ebp),%eax
  102ad3:	c1 e8 0c             	shr    $0xc,%eax
  102ad6:	89 45 f0             	mov    %eax,-0x10(%ebp)
  102ad9:	a1 80 be 11 00       	mov    0x11be80,%eax
  102ade:	39 45 f0             	cmp    %eax,-0x10(%ebp)
  102ae1:	72 23                	jb     102b06 <page2kva+0x4a>
  102ae3:	8b 45 f4             	mov    -0xc(%ebp),%eax
  102ae6:	89 44 24 0c          	mov    %eax,0xc(%esp)
  102aea:	c7 44 24 08 e0 68 10 	movl   $0x1068e0,0x8(%esp)
  102af1:	00 
  102af2:	c7 44 24 04 62 00 00 	movl   $0x62,0x4(%esp)
  102af9:	00 
  102afa:	c7 04 24 cf 68 10 00 	movl   $0x1068cf,(%esp)
  102b01:	e8 f3 d8 ff ff       	call   1003f9 <__panic>
  102b06:	8b 45 f4             	mov    -0xc(%ebp),%eax
  102b09:	2d 00 00 00 40       	sub    $0x40000000,%eax
}
  102b0e:	c9                   	leave  
  102b0f:	c3                   	ret    

00102b10 <pte2page>:
kva2page(void *kva) {
    return pa2page(PADDR(kva));
}

static inline struct Page *
pte2page(pte_t pte) {
  102b10:	55                   	push   %ebp
  102b11:	89 e5                	mov    %esp,%ebp
  102b13:	83 ec 18             	sub    $0x18,%esp
    if (!(pte & PTE_P)) {
  102b16:	8b 45 08             	mov    0x8(%ebp),%eax
  102b19:	83 e0 01             	and    $0x1,%eax
  102b1c:	85 c0                	test   %eax,%eax
  102b1e:	75 1c                	jne    102b3c <pte2page+0x2c>
        panic("pte2page called with invalid pte");
  102b20:	c7 44 24 08 04 69 10 	movl   $0x106904,0x8(%esp)
  102b27:	00 
  102b28:	c7 44 24 04 6d 00 00 	movl   $0x6d,0x4(%esp)
  102b2f:	00 
  102b30:	c7 04 24 cf 68 10 00 	movl   $0x1068cf,(%esp)
  102b37:	e8 bd d8 ff ff       	call   1003f9 <__panic>
    }
    return pa2page(PTE_ADDR(pte));
  102b3c:	8b 45 08             	mov    0x8(%ebp),%eax
  102b3f:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  102b44:	89 04 24             	mov    %eax,(%esp)
  102b47:	e8 21 ff ff ff       	call   102a6d <pa2page>
}
  102b4c:	c9                   	leave  
  102b4d:	c3                   	ret    

00102b4e <pde2page>:

static inline struct Page *
pde2page(pde_t pde) {
  102b4e:	55                   	push   %ebp
  102b4f:	89 e5                	mov    %esp,%ebp
  102b51:	83 ec 18             	sub    $0x18,%esp
    return pa2page(PDE_ADDR(pde));
  102b54:	8b 45 08             	mov    0x8(%ebp),%eax
  102b57:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  102b5c:	89 04 24             	mov    %eax,(%esp)
  102b5f:	e8 09 ff ff ff       	call   102a6d <pa2page>
}
  102b64:	c9                   	leave  
  102b65:	c3                   	ret    

00102b66 <page_ref>:

static inline int
page_ref(struct Page *page) {
  102b66:	55                   	push   %ebp
  102b67:	89 e5                	mov    %esp,%ebp
    return page->ref;
  102b69:	8b 45 08             	mov    0x8(%ebp),%eax
  102b6c:	8b 00                	mov    (%eax),%eax
}
  102b6e:	5d                   	pop    %ebp
  102b6f:	c3                   	ret    

00102b70 <set_page_ref>:

static inline void
set_page_ref(struct Page *page, int val) {
  102b70:	55                   	push   %ebp
  102b71:	89 e5                	mov    %esp,%ebp
    page->ref = val;
  102b73:	8b 45 08             	mov    0x8(%ebp),%eax
  102b76:	8b 55 0c             	mov    0xc(%ebp),%edx
  102b79:	89 10                	mov    %edx,(%eax)
}
  102b7b:	90                   	nop
  102b7c:	5d                   	pop    %ebp
  102b7d:	c3                   	ret    

00102b7e <page_ref_inc>:

static inline int
page_ref_inc(struct Page *page) {
  102b7e:	55                   	push   %ebp
  102b7f:	89 e5                	mov    %esp,%ebp
    page->ref += 1;
  102b81:	8b 45 08             	mov    0x8(%ebp),%eax
  102b84:	8b 00                	mov    (%eax),%eax
  102b86:	8d 50 01             	lea    0x1(%eax),%edx
  102b89:	8b 45 08             	mov    0x8(%ebp),%eax
  102b8c:	89 10                	mov    %edx,(%eax)
    return page->ref;
  102b8e:	8b 45 08             	mov    0x8(%ebp),%eax
  102b91:	8b 00                	mov    (%eax),%eax
}
  102b93:	5d                   	pop    %ebp
  102b94:	c3                   	ret    

00102b95 <page_ref_dec>:

static inline int
page_ref_dec(struct Page *page) {
  102b95:	55                   	push   %ebp
  102b96:	89 e5                	mov    %esp,%ebp
    page->ref -= 1;
  102b98:	8b 45 08             	mov    0x8(%ebp),%eax
  102b9b:	8b 00                	mov    (%eax),%eax
  102b9d:	8d 50 ff             	lea    -0x1(%eax),%edx
  102ba0:	8b 45 08             	mov    0x8(%ebp),%eax
  102ba3:	89 10                	mov    %edx,(%eax)
    return page->ref;
  102ba5:	8b 45 08             	mov    0x8(%ebp),%eax
  102ba8:	8b 00                	mov    (%eax),%eax
}
  102baa:	5d                   	pop    %ebp
  102bab:	c3                   	ret    

00102bac <__intr_save>:
__intr_save(void) {
  102bac:	55                   	push   %ebp
  102bad:	89 e5                	mov    %esp,%ebp
  102baf:	83 ec 18             	sub    $0x18,%esp
    asm volatile ("pushfl; popl %0" : "=r" (eflags));
  102bb2:	9c                   	pushf  
  102bb3:	58                   	pop    %eax
  102bb4:	89 45 f4             	mov    %eax,-0xc(%ebp)
    return eflags;
  102bb7:	8b 45 f4             	mov    -0xc(%ebp),%eax
    if (read_eflags() & FL_IF) {
  102bba:	25 00 02 00 00       	and    $0x200,%eax
  102bbf:	85 c0                	test   %eax,%eax
  102bc1:	74 0c                	je     102bcf <__intr_save+0x23>
        intr_disable();
  102bc3:	e8 d5 ec ff ff       	call   10189d <intr_disable>
        return 1;
  102bc8:	b8 01 00 00 00       	mov    $0x1,%eax
  102bcd:	eb 05                	jmp    102bd4 <__intr_save+0x28>
    return 0;
  102bcf:	b8 00 00 00 00       	mov    $0x0,%eax
}
  102bd4:	c9                   	leave  
  102bd5:	c3                   	ret    

00102bd6 <__intr_restore>:
__intr_restore(bool flag) {
  102bd6:	55                   	push   %ebp
  102bd7:	89 e5                	mov    %esp,%ebp
  102bd9:	83 ec 08             	sub    $0x8,%esp
    if (flag) {
  102bdc:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
  102be0:	74 05                	je     102be7 <__intr_restore+0x11>
        intr_enable();
  102be2:	e8 af ec ff ff       	call   101896 <intr_enable>
}
  102be7:	90                   	nop
  102be8:	c9                   	leave  
  102be9:	c3                   	ret    

00102bea <lgdt>:
/* *
 * lgdt - load the global descriptor table register and reset the
 * data/code segement registers for kernel.
 * */
static inline void
lgdt(struct pseudodesc *pd) {
  102bea:	55                   	push   %ebp
  102beb:	89 e5                	mov    %esp,%ebp
    asm volatile ("lgdt (%0)" :: "r" (pd));
  102bed:	8b 45 08             	mov    0x8(%ebp),%eax
  102bf0:	0f 01 10             	lgdtl  (%eax)
    asm volatile ("movw %%ax, %%gs" :: "a" (USER_DS));
  102bf3:	b8 23 00 00 00       	mov    $0x23,%eax
  102bf8:	8e e8                	mov    %eax,%gs
    asm volatile ("movw %%ax, %%fs" :: "a" (USER_DS));
  102bfa:	b8 23 00 00 00       	mov    $0x23,%eax
  102bff:	8e e0                	mov    %eax,%fs
    asm volatile ("movw %%ax, %%es" :: "a" (KERNEL_DS));
  102c01:	b8 10 00 00 00       	mov    $0x10,%eax
  102c06:	8e c0                	mov    %eax,%es
    asm volatile ("movw %%ax, %%ds" :: "a" (KERNEL_DS));
  102c08:	b8 10 00 00 00       	mov    $0x10,%eax
  102c0d:	8e d8                	mov    %eax,%ds
    asm volatile ("movw %%ax, %%ss" :: "a" (KERNEL_DS));
  102c0f:	b8 10 00 00 00       	mov    $0x10,%eax
  102c14:	8e d0                	mov    %eax,%ss
    // reload cs
    asm volatile ("ljmp %0, $1f\n 1:\n" :: "i" (KERNEL_CS));
  102c16:	ea 1d 2c 10 00 08 00 	ljmp   $0x8,$0x102c1d
}
  102c1d:	90                   	nop
  102c1e:	5d                   	pop    %ebp
  102c1f:	c3                   	ret    

00102c20 <load_esp0>:
 * load_esp0 - change the ESP0 in default task state segment,
 * so that we can use different kernel stack when we trap frame
 * user to kernel.
 * */
void
load_esp0(uintptr_t esp0) {
  102c20:	55                   	push   %ebp
  102c21:	89 e5                	mov    %esp,%ebp
    ts.ts_esp0 = esp0;
  102c23:	8b 45 08             	mov    0x8(%ebp),%eax
  102c26:	a3 a4 be 11 00       	mov    %eax,0x11bea4
}
  102c2b:	90                   	nop
  102c2c:	5d                   	pop    %ebp
  102c2d:	c3                   	ret    

00102c2e <gdt_init>:

/* gdt_init - initialize the default GDT and TSS */
static void
gdt_init(void) {
  102c2e:	55                   	push   %ebp
  102c2f:	89 e5                	mov    %esp,%ebp
  102c31:	83 ec 14             	sub    $0x14,%esp
    // set boot kernel stack and default SS0
    load_esp0((uintptr_t)bootstacktop);
  102c34:	b8 00 80 11 00       	mov    $0x118000,%eax
  102c39:	89 04 24             	mov    %eax,(%esp)
  102c3c:	e8 df ff ff ff       	call   102c20 <load_esp0>
    ts.ts_ss0 = KERNEL_DS;
  102c41:	66 c7 05 a8 be 11 00 	movw   $0x10,0x11bea8
  102c48:	10 00 

    // initialize the TSS filed of the gdt
    gdt[SEG_TSS] = SEGTSS(STS_T32A, (uintptr_t)&ts, sizeof(ts), DPL_KERNEL);
  102c4a:	66 c7 05 28 8a 11 00 	movw   $0x68,0x118a28
  102c51:	68 00 
  102c53:	b8 a0 be 11 00       	mov    $0x11bea0,%eax
  102c58:	0f b7 c0             	movzwl %ax,%eax
  102c5b:	66 a3 2a 8a 11 00    	mov    %ax,0x118a2a
  102c61:	b8 a0 be 11 00       	mov    $0x11bea0,%eax
  102c66:	c1 e8 10             	shr    $0x10,%eax
  102c69:	a2 2c 8a 11 00       	mov    %al,0x118a2c
  102c6e:	0f b6 05 2d 8a 11 00 	movzbl 0x118a2d,%eax
  102c75:	24 f0                	and    $0xf0,%al
  102c77:	0c 09                	or     $0x9,%al
  102c79:	a2 2d 8a 11 00       	mov    %al,0x118a2d
  102c7e:	0f b6 05 2d 8a 11 00 	movzbl 0x118a2d,%eax
  102c85:	24 ef                	and    $0xef,%al
  102c87:	a2 2d 8a 11 00       	mov    %al,0x118a2d
  102c8c:	0f b6 05 2d 8a 11 00 	movzbl 0x118a2d,%eax
  102c93:	24 9f                	and    $0x9f,%al
  102c95:	a2 2d 8a 11 00       	mov    %al,0x118a2d
  102c9a:	0f b6 05 2d 8a 11 00 	movzbl 0x118a2d,%eax
  102ca1:	0c 80                	or     $0x80,%al
  102ca3:	a2 2d 8a 11 00       	mov    %al,0x118a2d
  102ca8:	0f b6 05 2e 8a 11 00 	movzbl 0x118a2e,%eax
  102caf:	24 f0                	and    $0xf0,%al
  102cb1:	a2 2e 8a 11 00       	mov    %al,0x118a2e
  102cb6:	0f b6 05 2e 8a 11 00 	movzbl 0x118a2e,%eax
  102cbd:	24 ef                	and    $0xef,%al
  102cbf:	a2 2e 8a 11 00       	mov    %al,0x118a2e
  102cc4:	0f b6 05 2e 8a 11 00 	movzbl 0x118a2e,%eax
  102ccb:	24 df                	and    $0xdf,%al
  102ccd:	a2 2e 8a 11 00       	mov    %al,0x118a2e
  102cd2:	0f b6 05 2e 8a 11 00 	movzbl 0x118a2e,%eax
  102cd9:	0c 40                	or     $0x40,%al
  102cdb:	a2 2e 8a 11 00       	mov    %al,0x118a2e
  102ce0:	0f b6 05 2e 8a 11 00 	movzbl 0x118a2e,%eax
  102ce7:	24 7f                	and    $0x7f,%al
  102ce9:	a2 2e 8a 11 00       	mov    %al,0x118a2e
  102cee:	b8 a0 be 11 00       	mov    $0x11bea0,%eax
  102cf3:	c1 e8 18             	shr    $0x18,%eax
  102cf6:	a2 2f 8a 11 00       	mov    %al,0x118a2f

    // reload all segment registers
    lgdt(&gdt_pd);
  102cfb:	c7 04 24 30 8a 11 00 	movl   $0x118a30,(%esp)
  102d02:	e8 e3 fe ff ff       	call   102bea <lgdt>
  102d07:	66 c7 45 fe 28 00    	movw   $0x28,-0x2(%ebp)
    asm volatile ("ltr %0" :: "r" (sel) : "memory");
  102d0d:	0f b7 45 fe          	movzwl -0x2(%ebp),%eax
  102d11:	0f 00 d8             	ltr    %ax

    // load the TSS
    ltr(GD_TSS);
}
  102d14:	90                   	nop
  102d15:	c9                   	leave  
  102d16:	c3                   	ret    

00102d17 <init_pmm_manager>:

//init_pmm_manager - initialize a pmm_manager instance
static void
init_pmm_manager(void) {
  102d17:	55                   	push   %ebp
  102d18:	89 e5                	mov    %esp,%ebp
  102d1a:	83 ec 18             	sub    $0x18,%esp
    pmm_manager = &default_pmm_manager;
  102d1d:	c7 05 70 bf 11 00 d8 	movl   $0x1072d8,0x11bf70
  102d24:	72 10 00 
    cprintf("memory management: %s\n", pmm_manager->name);
  102d27:	a1 70 bf 11 00       	mov    0x11bf70,%eax
  102d2c:	8b 00                	mov    (%eax),%eax
  102d2e:	89 44 24 04          	mov    %eax,0x4(%esp)
  102d32:	c7 04 24 30 69 10 00 	movl   $0x106930,(%esp)
  102d39:	e8 64 d5 ff ff       	call   1002a2 <cprintf>
    pmm_manager->init();
  102d3e:	a1 70 bf 11 00       	mov    0x11bf70,%eax
  102d43:	8b 40 04             	mov    0x4(%eax),%eax
  102d46:	ff d0                	call   *%eax
}
  102d48:	90                   	nop
  102d49:	c9                   	leave  
  102d4a:	c3                   	ret    

00102d4b <init_memmap>:

//init_memmap - call pmm->init_memmap to build Page struct for free memory  
static void
init_memmap(struct Page *base, size_t n) {
  102d4b:	55                   	push   %ebp
  102d4c:	89 e5                	mov    %esp,%ebp
  102d4e:	83 ec 18             	sub    $0x18,%esp
    pmm_manager->init_memmap(base, n);
  102d51:	a1 70 bf 11 00       	mov    0x11bf70,%eax
  102d56:	8b 40 08             	mov    0x8(%eax),%eax
  102d59:	8b 55 0c             	mov    0xc(%ebp),%edx
  102d5c:	89 54 24 04          	mov    %edx,0x4(%esp)
  102d60:	8b 55 08             	mov    0x8(%ebp),%edx
  102d63:	89 14 24             	mov    %edx,(%esp)
  102d66:	ff d0                	call   *%eax
}
  102d68:	90                   	nop
  102d69:	c9                   	leave  
  102d6a:	c3                   	ret    

00102d6b <alloc_pages>:

//alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE memory 
struct Page *
alloc_pages(size_t n) {
  102d6b:	55                   	push   %ebp
  102d6c:	89 e5                	mov    %esp,%ebp
  102d6e:	83 ec 28             	sub    $0x28,%esp
    struct Page *page=NULL;
  102d71:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    bool intr_flag;
    local_intr_save(intr_flag);
  102d78:	e8 2f fe ff ff       	call   102bac <__intr_save>
  102d7d:	89 45 f0             	mov    %eax,-0x10(%ebp)
    {
        page = pmm_manager->alloc_pages(n);
  102d80:	a1 70 bf 11 00       	mov    0x11bf70,%eax
  102d85:	8b 40 0c             	mov    0xc(%eax),%eax
  102d88:	8b 55 08             	mov    0x8(%ebp),%edx
  102d8b:	89 14 24             	mov    %edx,(%esp)
  102d8e:	ff d0                	call   *%eax
  102d90:	89 45 f4             	mov    %eax,-0xc(%ebp)
    }
    local_intr_restore(intr_flag);
  102d93:	8b 45 f0             	mov    -0x10(%ebp),%eax
  102d96:	89 04 24             	mov    %eax,(%esp)
  102d99:	e8 38 fe ff ff       	call   102bd6 <__intr_restore>
    return page;
  102d9e:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  102da1:	c9                   	leave  
  102da2:	c3                   	ret    

00102da3 <free_pages>:

//free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory 
void
free_pages(struct Page *base, size_t n) {
  102da3:	55                   	push   %ebp
  102da4:	89 e5                	mov    %esp,%ebp
  102da6:	83 ec 28             	sub    $0x28,%esp
    bool intr_flag;
    local_intr_save(intr_flag);
  102da9:	e8 fe fd ff ff       	call   102bac <__intr_save>
  102dae:	89 45 f4             	mov    %eax,-0xc(%ebp)
    {
        pmm_manager->free_pages(base, n);
  102db1:	a1 70 bf 11 00       	mov    0x11bf70,%eax
  102db6:	8b 40 10             	mov    0x10(%eax),%eax
  102db9:	8b 55 0c             	mov    0xc(%ebp),%edx
  102dbc:	89 54 24 04          	mov    %edx,0x4(%esp)
  102dc0:	8b 55 08             	mov    0x8(%ebp),%edx
  102dc3:	89 14 24             	mov    %edx,(%esp)
  102dc6:	ff d0                	call   *%eax
    }
    local_intr_restore(intr_flag);
  102dc8:	8b 45 f4             	mov    -0xc(%ebp),%eax
  102dcb:	89 04 24             	mov    %eax,(%esp)
  102dce:	e8 03 fe ff ff       	call   102bd6 <__intr_restore>
}
  102dd3:	90                   	nop
  102dd4:	c9                   	leave  
  102dd5:	c3                   	ret    

00102dd6 <nr_free_pages>:

//nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE) 
//of current free memory
size_t
nr_free_pages(void) {
  102dd6:	55                   	push   %ebp
  102dd7:	89 e5                	mov    %esp,%ebp
  102dd9:	83 ec 28             	sub    $0x28,%esp
    size_t ret;
    bool intr_flag;
    local_intr_save(intr_flag);
  102ddc:	e8 cb fd ff ff       	call   102bac <__intr_save>
  102de1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    {
        ret = pmm_manager->nr_free_pages();
  102de4:	a1 70 bf 11 00       	mov    0x11bf70,%eax
  102de9:	8b 40 14             	mov    0x14(%eax),%eax
  102dec:	ff d0                	call   *%eax
  102dee:	89 45 f0             	mov    %eax,-0x10(%ebp)
    }
    local_intr_restore(intr_flag);
  102df1:	8b 45 f4             	mov    -0xc(%ebp),%eax
  102df4:	89 04 24             	mov    %eax,(%esp)
  102df7:	e8 da fd ff ff       	call   102bd6 <__intr_restore>
    return ret;
  102dfc:	8b 45 f0             	mov    -0x10(%ebp),%eax
}
  102dff:	c9                   	leave  
  102e00:	c3                   	ret    

00102e01 <page_init>:

/* pmm_init - initialize the physical memory management */
//主要是完成了一个整体物理地址的初始化过程，包括设置标记位，探测物理内存布局等操作
//页初始化，交给了init_memmap函数处理。
static void
page_init(void) {
  102e01:	55                   	push   %ebp
  102e02:	89 e5                	mov    %esp,%ebp
  102e04:	57                   	push   %edi
  102e05:	56                   	push   %esi
  102e06:	53                   	push   %ebx
  102e07:	81 ec 9c 00 00 00    	sub    $0x9c,%esp
    struct e820map *memmap = (struct e820map *)(0x8000 + KERNBASE);
  102e0d:	c7 45 c4 00 80 00 c0 	movl   $0xc0008000,-0x3c(%ebp)
    uint64_t maxpa = 0;
  102e14:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
  102e1b:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)

    cprintf("e820map:\n");
  102e22:	c7 04 24 47 69 10 00 	movl   $0x106947,(%esp)
  102e29:	e8 74 d4 ff ff       	call   1002a2 <cprintf>
    int i;
    for (i = 0; i < memmap->nr_map; i ++) {
  102e2e:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
  102e35:	e9 22 01 00 00       	jmp    102f5c <page_init+0x15b>
        uint64_t begin = memmap->map[i].addr, end = begin + memmap->map[i].size;
  102e3a:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  102e3d:	8b 55 dc             	mov    -0x24(%ebp),%edx
  102e40:	89 d0                	mov    %edx,%eax
  102e42:	c1 e0 02             	shl    $0x2,%eax
  102e45:	01 d0                	add    %edx,%eax
  102e47:	c1 e0 02             	shl    $0x2,%eax
  102e4a:	01 c8                	add    %ecx,%eax
  102e4c:	8b 50 08             	mov    0x8(%eax),%edx
  102e4f:	8b 40 04             	mov    0x4(%eax),%eax
  102e52:	89 45 a0             	mov    %eax,-0x60(%ebp)
  102e55:	89 55 a4             	mov    %edx,-0x5c(%ebp)
  102e58:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  102e5b:	8b 55 dc             	mov    -0x24(%ebp),%edx
  102e5e:	89 d0                	mov    %edx,%eax
  102e60:	c1 e0 02             	shl    $0x2,%eax
  102e63:	01 d0                	add    %edx,%eax
  102e65:	c1 e0 02             	shl    $0x2,%eax
  102e68:	01 c8                	add    %ecx,%eax
  102e6a:	8b 48 0c             	mov    0xc(%eax),%ecx
  102e6d:	8b 58 10             	mov    0x10(%eax),%ebx
  102e70:	8b 45 a0             	mov    -0x60(%ebp),%eax
  102e73:	8b 55 a4             	mov    -0x5c(%ebp),%edx
  102e76:	01 c8                	add    %ecx,%eax
  102e78:	11 da                	adc    %ebx,%edx
  102e7a:	89 45 98             	mov    %eax,-0x68(%ebp)
  102e7d:	89 55 9c             	mov    %edx,-0x64(%ebp)
        cprintf("  memory: %08llx, [%08llx, %08llx], type = %d.\n",
  102e80:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  102e83:	8b 55 dc             	mov    -0x24(%ebp),%edx
  102e86:	89 d0                	mov    %edx,%eax
  102e88:	c1 e0 02             	shl    $0x2,%eax
  102e8b:	01 d0                	add    %edx,%eax
  102e8d:	c1 e0 02             	shl    $0x2,%eax
  102e90:	01 c8                	add    %ecx,%eax
  102e92:	83 c0 14             	add    $0x14,%eax
  102e95:	8b 00                	mov    (%eax),%eax
  102e97:	89 45 84             	mov    %eax,-0x7c(%ebp)
  102e9a:	8b 45 98             	mov    -0x68(%ebp),%eax
  102e9d:	8b 55 9c             	mov    -0x64(%ebp),%edx
  102ea0:	83 c0 ff             	add    $0xffffffff,%eax
  102ea3:	83 d2 ff             	adc    $0xffffffff,%edx
  102ea6:	89 85 78 ff ff ff    	mov    %eax,-0x88(%ebp)
  102eac:	89 95 7c ff ff ff    	mov    %edx,-0x84(%ebp)
  102eb2:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  102eb5:	8b 55 dc             	mov    -0x24(%ebp),%edx
  102eb8:	89 d0                	mov    %edx,%eax
  102eba:	c1 e0 02             	shl    $0x2,%eax
  102ebd:	01 d0                	add    %edx,%eax
  102ebf:	c1 e0 02             	shl    $0x2,%eax
  102ec2:	01 c8                	add    %ecx,%eax
  102ec4:	8b 48 0c             	mov    0xc(%eax),%ecx
  102ec7:	8b 58 10             	mov    0x10(%eax),%ebx
  102eca:	8b 55 84             	mov    -0x7c(%ebp),%edx
  102ecd:	89 54 24 1c          	mov    %edx,0x1c(%esp)
  102ed1:	8b 85 78 ff ff ff    	mov    -0x88(%ebp),%eax
  102ed7:	8b 95 7c ff ff ff    	mov    -0x84(%ebp),%edx
  102edd:	89 44 24 14          	mov    %eax,0x14(%esp)
  102ee1:	89 54 24 18          	mov    %edx,0x18(%esp)
  102ee5:	8b 45 a0             	mov    -0x60(%ebp),%eax
  102ee8:	8b 55 a4             	mov    -0x5c(%ebp),%edx
  102eeb:	89 44 24 0c          	mov    %eax,0xc(%esp)
  102eef:	89 54 24 10          	mov    %edx,0x10(%esp)
  102ef3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
  102ef7:	89 5c 24 08          	mov    %ebx,0x8(%esp)
  102efb:	c7 04 24 54 69 10 00 	movl   $0x106954,(%esp)
  102f02:	e8 9b d3 ff ff       	call   1002a2 <cprintf>
                memmap->map[i].size, begin, end - 1, memmap->map[i].type);
        if (memmap->map[i].type == E820_ARM) {
  102f07:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  102f0a:	8b 55 dc             	mov    -0x24(%ebp),%edx
  102f0d:	89 d0                	mov    %edx,%eax
  102f0f:	c1 e0 02             	shl    $0x2,%eax
  102f12:	01 d0                	add    %edx,%eax
  102f14:	c1 e0 02             	shl    $0x2,%eax
  102f17:	01 c8                	add    %ecx,%eax
  102f19:	83 c0 14             	add    $0x14,%eax
  102f1c:	8b 00                	mov    (%eax),%eax
  102f1e:	83 f8 01             	cmp    $0x1,%eax
  102f21:	75 36                	jne    102f59 <page_init+0x158>
            if (maxpa < end && begin < KMEMSIZE) {
  102f23:	8b 45 e0             	mov    -0x20(%ebp),%eax
  102f26:	8b 55 e4             	mov    -0x1c(%ebp),%edx
  102f29:	3b 55 9c             	cmp    -0x64(%ebp),%edx
  102f2c:	77 2b                	ja     102f59 <page_init+0x158>
  102f2e:	3b 55 9c             	cmp    -0x64(%ebp),%edx
  102f31:	72 05                	jb     102f38 <page_init+0x137>
  102f33:	3b 45 98             	cmp    -0x68(%ebp),%eax
  102f36:	73 21                	jae    102f59 <page_init+0x158>
  102f38:	83 7d a4 00          	cmpl   $0x0,-0x5c(%ebp)
  102f3c:	77 1b                	ja     102f59 <page_init+0x158>
  102f3e:	83 7d a4 00          	cmpl   $0x0,-0x5c(%ebp)
  102f42:	72 09                	jb     102f4d <page_init+0x14c>
  102f44:	81 7d a0 ff ff ff 37 	cmpl   $0x37ffffff,-0x60(%ebp)
  102f4b:	77 0c                	ja     102f59 <page_init+0x158>
                maxpa = end;
  102f4d:	8b 45 98             	mov    -0x68(%ebp),%eax
  102f50:	8b 55 9c             	mov    -0x64(%ebp),%edx
  102f53:	89 45 e0             	mov    %eax,-0x20(%ebp)
  102f56:	89 55 e4             	mov    %edx,-0x1c(%ebp)
    for (i = 0; i < memmap->nr_map; i ++) {
  102f59:	ff 45 dc             	incl   -0x24(%ebp)
  102f5c:	8b 45 c4             	mov    -0x3c(%ebp),%eax
  102f5f:	8b 00                	mov    (%eax),%eax
  102f61:	39 45 dc             	cmp    %eax,-0x24(%ebp)
  102f64:	0f 8c d0 fe ff ff    	jl     102e3a <page_init+0x39>
            }
        }
    }
    if (maxpa > KMEMSIZE) {
  102f6a:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
  102f6e:	72 1d                	jb     102f8d <page_init+0x18c>
  102f70:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
  102f74:	77 09                	ja     102f7f <page_init+0x17e>
  102f76:	81 7d e0 00 00 00 38 	cmpl   $0x38000000,-0x20(%ebp)
  102f7d:	76 0e                	jbe    102f8d <page_init+0x18c>
        maxpa = KMEMSIZE;
  102f7f:	c7 45 e0 00 00 00 38 	movl   $0x38000000,-0x20(%ebp)
  102f86:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
    }

    extern char end[];

    npage = maxpa / PGSIZE; //需要管理的物理页个数为
  102f8d:	8b 45 e0             	mov    -0x20(%ebp),%eax
  102f90:	8b 55 e4             	mov    -0x1c(%ebp),%edx
  102f93:	0f ac d0 0c          	shrd   $0xc,%edx,%eax
  102f97:	c1 ea 0c             	shr    $0xc,%edx
  102f9a:	89 c1                	mov    %eax,%ecx
  102f9c:	89 d3                	mov    %edx,%ebx
  102f9e:	89 c8                	mov    %ecx,%eax
  102fa0:	a3 80 be 11 00       	mov    %eax,0x11be80
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);  //由于bootloader加载ucore的结束地址（用全局指针变量end记录）
  102fa5:	c7 45 c0 00 10 00 00 	movl   $0x1000,-0x40(%ebp)
  102fac:	b8 88 bf 11 00       	mov    $0x11bf88,%eax
  102fb1:	8d 50 ff             	lea    -0x1(%eax),%edx
  102fb4:	8b 45 c0             	mov    -0x40(%ebp),%eax
  102fb7:	01 d0                	add    %edx,%eax
  102fb9:	89 45 bc             	mov    %eax,-0x44(%ebp)
  102fbc:	8b 45 bc             	mov    -0x44(%ebp),%eax
  102fbf:	ba 00 00 00 00       	mov    $0x0,%edx
  102fc4:	f7 75 c0             	divl   -0x40(%ebp)
  102fc7:	8b 45 bc             	mov    -0x44(%ebp),%eax
  102fca:	29 d0                	sub    %edx,%eax
  102fcc:	a3 78 bf 11 00       	mov    %eax,0x11bf78
                    //以上的空间没有被使用，所以我们可以把end按页大小为边界取整后，作为管理页级物理内存空间所需的Page结构的内存空间


    //首先，对于所有物理空间，通过如下语句即可实现占用标记
    for (i = 0; i < npage; i ++) {
  102fd1:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
  102fd8:	eb 2e                	jmp    103008 <page_init+0x207>
        SetPageReserved(pages + i);
  102fda:	8b 0d 78 bf 11 00    	mov    0x11bf78,%ecx
  102fe0:	8b 55 dc             	mov    -0x24(%ebp),%edx
  102fe3:	89 d0                	mov    %edx,%eax
  102fe5:	c1 e0 02             	shl    $0x2,%eax
  102fe8:	01 d0                	add    %edx,%eax
  102fea:	c1 e0 02             	shl    $0x2,%eax
  102fed:	01 c8                	add    %ecx,%eax
  102fef:	83 c0 04             	add    $0x4,%eax
  102ff2:	c7 45 94 00 00 00 00 	movl   $0x0,-0x6c(%ebp)
  102ff9:	89 45 90             	mov    %eax,-0x70(%ebp)
 * Note that @nr may be almost arbitrarily large; this function is not
 * restricted to acting on a single-word quantity.
 * */
static inline void
set_bit(int nr, volatile void *addr) {
    asm volatile ("btsl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
  102ffc:	8b 45 90             	mov    -0x70(%ebp),%eax
  102fff:	8b 55 94             	mov    -0x6c(%ebp),%edx
  103002:	0f ab 10             	bts    %edx,(%eax)
    for (i = 0; i < npage; i ++) {
  103005:	ff 45 dc             	incl   -0x24(%ebp)
  103008:	8b 55 dc             	mov    -0x24(%ebp),%edx
  10300b:	a1 80 be 11 00       	mov    0x11be80,%eax
  103010:	39 c2                	cmp    %eax,%edx
  103012:	72 c6                	jb     102fda <page_init+0x1d9>
    }
    //SetPageReserved只需把物理地址对应的Page结构中的flags标志设置为PG_reserved ，表示这些页已经被使用了，将来不能被用于分配。

    //为了简化起见，从地址0到地址pages+ sizeof(struct Page) * npage)结束的物理内存空间设定为已占用物理内存空间
    //（起始0~640KB的空间是空闲的），地址pages+ sizeof(struct Page) * npage)以上的空间为空闲物理内存空间，这时的空闲空间起始地址为
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * npage);
  103014:	8b 15 80 be 11 00    	mov    0x11be80,%edx
  10301a:	89 d0                	mov    %edx,%eax
  10301c:	c1 e0 02             	shl    $0x2,%eax
  10301f:	01 d0                	add    %edx,%eax
  103021:	c1 e0 02             	shl    $0x2,%eax
  103024:	89 c2                	mov    %eax,%edx
  103026:	a1 78 bf 11 00       	mov    0x11bf78,%eax
  10302b:	01 d0                	add    %edx,%eax
  10302d:	89 45 b8             	mov    %eax,-0x48(%ebp)
  103030:	81 7d b8 ff ff ff bf 	cmpl   $0xbfffffff,-0x48(%ebp)
  103037:	77 23                	ja     10305c <page_init+0x25b>
  103039:	8b 45 b8             	mov    -0x48(%ebp),%eax
  10303c:	89 44 24 0c          	mov    %eax,0xc(%esp)
  103040:	c7 44 24 08 84 69 10 	movl   $0x106984,0x8(%esp)
  103047:	00 
  103048:	c7 44 24 04 e6 00 00 	movl   $0xe6,0x4(%esp)
  10304f:	00 
  103050:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103057:	e8 9d d3 ff ff       	call   1003f9 <__panic>
  10305c:	8b 45 b8             	mov    -0x48(%ebp),%eax
  10305f:	05 00 00 00 40       	add    $0x40000000,%eax
  103064:	89 45 b4             	mov    %eax,-0x4c(%ebp)

    for (i = 0; i < memmap->nr_map; i ++) {
  103067:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
  10306e:	e9 69 01 00 00       	jmp    1031dc <page_init+0x3db>
        uint64_t begin = memmap->map[i].addr, end = begin + memmap->map[i].size;
  103073:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  103076:	8b 55 dc             	mov    -0x24(%ebp),%edx
  103079:	89 d0                	mov    %edx,%eax
  10307b:	c1 e0 02             	shl    $0x2,%eax
  10307e:	01 d0                	add    %edx,%eax
  103080:	c1 e0 02             	shl    $0x2,%eax
  103083:	01 c8                	add    %ecx,%eax
  103085:	8b 50 08             	mov    0x8(%eax),%edx
  103088:	8b 40 04             	mov    0x4(%eax),%eax
  10308b:	89 45 d0             	mov    %eax,-0x30(%ebp)
  10308e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
  103091:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  103094:	8b 55 dc             	mov    -0x24(%ebp),%edx
  103097:	89 d0                	mov    %edx,%eax
  103099:	c1 e0 02             	shl    $0x2,%eax
  10309c:	01 d0                	add    %edx,%eax
  10309e:	c1 e0 02             	shl    $0x2,%eax
  1030a1:	01 c8                	add    %ecx,%eax
  1030a3:	8b 48 0c             	mov    0xc(%eax),%ecx
  1030a6:	8b 58 10             	mov    0x10(%eax),%ebx
  1030a9:	8b 45 d0             	mov    -0x30(%ebp),%eax
  1030ac:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  1030af:	01 c8                	add    %ecx,%eax
  1030b1:	11 da                	adc    %ebx,%edx
  1030b3:	89 45 c8             	mov    %eax,-0x38(%ebp)
  1030b6:	89 55 cc             	mov    %edx,-0x34(%ebp)
        if (memmap->map[i].type == E820_ARM) {//获得空闲空间的起始地址begin和结束地址end
  1030b9:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
  1030bc:	8b 55 dc             	mov    -0x24(%ebp),%edx
  1030bf:	89 d0                	mov    %edx,%eax
  1030c1:	c1 e0 02             	shl    $0x2,%eax
  1030c4:	01 d0                	add    %edx,%eax
  1030c6:	c1 e0 02             	shl    $0x2,%eax
  1030c9:	01 c8                	add    %ecx,%eax
  1030cb:	83 c0 14             	add    $0x14,%eax
  1030ce:	8b 00                	mov    (%eax),%eax
  1030d0:	83 f8 01             	cmp    $0x1,%eax
  1030d3:	0f 85 00 01 00 00    	jne    1031d9 <page_init+0x3d8>
            if (begin < freemem) {
  1030d9:	8b 45 b4             	mov    -0x4c(%ebp),%eax
  1030dc:	ba 00 00 00 00       	mov    $0x0,%edx
  1030e1:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
  1030e4:	77 17                	ja     1030fd <page_init+0x2fc>
  1030e6:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
  1030e9:	72 05                	jb     1030f0 <page_init+0x2ef>
  1030eb:	39 45 d0             	cmp    %eax,-0x30(%ebp)
  1030ee:	73 0d                	jae    1030fd <page_init+0x2fc>
                begin = freemem;
  1030f0:	8b 45 b4             	mov    -0x4c(%ebp),%eax
  1030f3:	89 45 d0             	mov    %eax,-0x30(%ebp)
  1030f6:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%ebp)
            }
            if (end > KMEMSIZE) {
  1030fd:	83 7d cc 00          	cmpl   $0x0,-0x34(%ebp)
  103101:	72 1d                	jb     103120 <page_init+0x31f>
  103103:	83 7d cc 00          	cmpl   $0x0,-0x34(%ebp)
  103107:	77 09                	ja     103112 <page_init+0x311>
  103109:	81 7d c8 00 00 00 38 	cmpl   $0x38000000,-0x38(%ebp)
  103110:	76 0e                	jbe    103120 <page_init+0x31f>
                end = KMEMSIZE;
  103112:	c7 45 c8 00 00 00 38 	movl   $0x38000000,-0x38(%ebp)
  103119:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
            }
            if (begin < end) {
  103120:	8b 45 d0             	mov    -0x30(%ebp),%eax
  103123:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  103126:	3b 55 cc             	cmp    -0x34(%ebp),%edx
  103129:	0f 87 aa 00 00 00    	ja     1031d9 <page_init+0x3d8>
  10312f:	3b 55 cc             	cmp    -0x34(%ebp),%edx
  103132:	72 09                	jb     10313d <page_init+0x33c>
  103134:	3b 45 c8             	cmp    -0x38(%ebp),%eax
  103137:	0f 83 9c 00 00 00    	jae    1031d9 <page_init+0x3d8>
                begin = ROUNDUP(begin, PGSIZE);
  10313d:	c7 45 b0 00 10 00 00 	movl   $0x1000,-0x50(%ebp)
  103144:	8b 55 d0             	mov    -0x30(%ebp),%edx
  103147:	8b 45 b0             	mov    -0x50(%ebp),%eax
  10314a:	01 d0                	add    %edx,%eax
  10314c:	48                   	dec    %eax
  10314d:	89 45 ac             	mov    %eax,-0x54(%ebp)
  103150:	8b 45 ac             	mov    -0x54(%ebp),%eax
  103153:	ba 00 00 00 00       	mov    $0x0,%edx
  103158:	f7 75 b0             	divl   -0x50(%ebp)
  10315b:	8b 45 ac             	mov    -0x54(%ebp),%eax
  10315e:	29 d0                	sub    %edx,%eax
  103160:	ba 00 00 00 00       	mov    $0x0,%edx
  103165:	89 45 d0             	mov    %eax,-0x30(%ebp)
  103168:	89 55 d4             	mov    %edx,-0x2c(%ebp)
                end = ROUNDDOWN(end, PGSIZE);
  10316b:	8b 45 c8             	mov    -0x38(%ebp),%eax
  10316e:	89 45 a8             	mov    %eax,-0x58(%ebp)
  103171:	8b 45 a8             	mov    -0x58(%ebp),%eax
  103174:	ba 00 00 00 00       	mov    $0x0,%edx
  103179:	89 c3                	mov    %eax,%ebx
  10317b:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
  103181:	89 de                	mov    %ebx,%esi
  103183:	89 d0                	mov    %edx,%eax
  103185:	83 e0 00             	and    $0x0,%eax
  103188:	89 c7                	mov    %eax,%edi
  10318a:	89 75 c8             	mov    %esi,-0x38(%ebp)
  10318d:	89 7d cc             	mov    %edi,-0x34(%ebp)
                if (begin < end) {
  103190:	8b 45 d0             	mov    -0x30(%ebp),%eax
  103193:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  103196:	3b 55 cc             	cmp    -0x34(%ebp),%edx
  103199:	77 3e                	ja     1031d9 <page_init+0x3d8>
  10319b:	3b 55 cc             	cmp    -0x34(%ebp),%edx
  10319e:	72 05                	jb     1031a5 <page_init+0x3a4>
  1031a0:	3b 45 c8             	cmp    -0x38(%ebp),%eax
  1031a3:	73 34                	jae    1031d9 <page_init+0x3d8>
                    //然后，根据探测到的空闲物理空间，通过如下语句即可实现空闲标记：
                    init_memmap(pa2page(begin), (end - begin) / PGSIZE);
  1031a5:	8b 45 c8             	mov    -0x38(%ebp),%eax
  1031a8:	8b 55 cc             	mov    -0x34(%ebp),%edx
  1031ab:	2b 45 d0             	sub    -0x30(%ebp),%eax
  1031ae:	1b 55 d4             	sbb    -0x2c(%ebp),%edx
  1031b1:	89 c1                	mov    %eax,%ecx
  1031b3:	89 d3                	mov    %edx,%ebx
  1031b5:	89 c8                	mov    %ecx,%eax
  1031b7:	89 da                	mov    %ebx,%edx
  1031b9:	0f ac d0 0c          	shrd   $0xc,%edx,%eax
  1031bd:	c1 ea 0c             	shr    $0xc,%edx
  1031c0:	89 c3                	mov    %eax,%ebx
  1031c2:	8b 45 d0             	mov    -0x30(%ebp),%eax
  1031c5:	89 04 24             	mov    %eax,(%esp)
  1031c8:	e8 a0 f8 ff ff       	call   102a6d <pa2page>
  1031cd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
  1031d1:	89 04 24             	mov    %eax,(%esp)
  1031d4:	e8 72 fb ff ff       	call   102d4b <init_memmap>
    for (i = 0; i < memmap->nr_map; i ++) {
  1031d9:	ff 45 dc             	incl   -0x24(%ebp)
  1031dc:	8b 45 c4             	mov    -0x3c(%ebp),%eax
  1031df:	8b 00                	mov    (%eax),%eax
  1031e1:	39 45 dc             	cmp    %eax,-0x24(%ebp)
  1031e4:	0f 8c 89 fe ff ff    	jl     103073 <page_init+0x272>
                    //init_memmap函数则是把空闲物理页对应的Page结构中的flags和引用计数ref清零，并加到free_area.free_list指向的双向列表中，为将来的空闲页管理做好初始化准备工作。
                }
            }
        }
    }
}
  1031ea:	90                   	nop
  1031eb:	81 c4 9c 00 00 00    	add    $0x9c,%esp
  1031f1:	5b                   	pop    %ebx
  1031f2:	5e                   	pop    %esi
  1031f3:	5f                   	pop    %edi
  1031f4:	5d                   	pop    %ebp
  1031f5:	c3                   	ret    

001031f6 <boot_map_segment>:
//  size: memory size
//  pa:   physical address of this memory
//  perm: permission of this memory  
//完成页表和页表项建立
static void
boot_map_segment(pde_t *pgdir, uintptr_t la, size_t size, uintptr_t pa, uint32_t perm) {
  1031f6:	55                   	push   %ebp
  1031f7:	89 e5                	mov    %esp,%ebp
  1031f9:	83 ec 38             	sub    $0x38,%esp
    assert(PGOFF(la) == PGOFF(pa));
  1031fc:	8b 45 0c             	mov    0xc(%ebp),%eax
  1031ff:	33 45 14             	xor    0x14(%ebp),%eax
  103202:	25 ff 0f 00 00       	and    $0xfff,%eax
  103207:	85 c0                	test   %eax,%eax
  103209:	74 24                	je     10322f <boot_map_segment+0x39>
  10320b:	c7 44 24 0c b6 69 10 	movl   $0x1069b6,0xc(%esp)
  103212:	00 
  103213:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  10321a:	00 
  10321b:	c7 44 24 04 07 01 00 	movl   $0x107,0x4(%esp)
  103222:	00 
  103223:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  10322a:	e8 ca d1 ff ff       	call   1003f9 <__panic>
    size_t n = ROUNDUP(size + PGOFF(la), PGSIZE) / PGSIZE;
  10322f:	c7 45 f0 00 10 00 00 	movl   $0x1000,-0x10(%ebp)
  103236:	8b 45 0c             	mov    0xc(%ebp),%eax
  103239:	25 ff 0f 00 00       	and    $0xfff,%eax
  10323e:	89 c2                	mov    %eax,%edx
  103240:	8b 45 10             	mov    0x10(%ebp),%eax
  103243:	01 c2                	add    %eax,%edx
  103245:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103248:	01 d0                	add    %edx,%eax
  10324a:	48                   	dec    %eax
  10324b:	89 45 ec             	mov    %eax,-0x14(%ebp)
  10324e:	8b 45 ec             	mov    -0x14(%ebp),%eax
  103251:	ba 00 00 00 00       	mov    $0x0,%edx
  103256:	f7 75 f0             	divl   -0x10(%ebp)
  103259:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10325c:	29 d0                	sub    %edx,%eax
  10325e:	c1 e8 0c             	shr    $0xc,%eax
  103261:	89 45 f4             	mov    %eax,-0xc(%ebp)
    la = ROUNDDOWN(la, PGSIZE);
  103264:	8b 45 0c             	mov    0xc(%ebp),%eax
  103267:	89 45 e8             	mov    %eax,-0x18(%ebp)
  10326a:	8b 45 e8             	mov    -0x18(%ebp),%eax
  10326d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  103272:	89 45 0c             	mov    %eax,0xc(%ebp)
    pa = ROUNDDOWN(pa, PGSIZE);
  103275:	8b 45 14             	mov    0x14(%ebp),%eax
  103278:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  10327b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  10327e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  103283:	89 45 14             	mov    %eax,0x14(%ebp)
    for (; n > 0; n --, la += PGSIZE, pa += PGSIZE) {
  103286:	eb 68                	jmp    1032f0 <boot_map_segment+0xfa>
        pte_t *ptep = get_pte(pgdir, la, 1);
  103288:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
  10328f:	00 
  103290:	8b 45 0c             	mov    0xc(%ebp),%eax
  103293:	89 44 24 04          	mov    %eax,0x4(%esp)
  103297:	8b 45 08             	mov    0x8(%ebp),%eax
  10329a:	89 04 24             	mov    %eax,(%esp)
  10329d:	e8 81 01 00 00       	call   103423 <get_pte>
  1032a2:	89 45 e0             	mov    %eax,-0x20(%ebp)
        assert(ptep != NULL);
  1032a5:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
  1032a9:	75 24                	jne    1032cf <boot_map_segment+0xd9>
  1032ab:	c7 44 24 0c e2 69 10 	movl   $0x1069e2,0xc(%esp)
  1032b2:	00 
  1032b3:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  1032ba:	00 
  1032bb:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
  1032c2:	00 
  1032c3:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1032ca:	e8 2a d1 ff ff       	call   1003f9 <__panic>
        *ptep = pa | PTE_P | perm;
  1032cf:	8b 45 14             	mov    0x14(%ebp),%eax
  1032d2:	0b 45 18             	or     0x18(%ebp),%eax
  1032d5:	83 c8 01             	or     $0x1,%eax
  1032d8:	89 c2                	mov    %eax,%edx
  1032da:	8b 45 e0             	mov    -0x20(%ebp),%eax
  1032dd:	89 10                	mov    %edx,(%eax)
    for (; n > 0; n --, la += PGSIZE, pa += PGSIZE) {
  1032df:	ff 4d f4             	decl   -0xc(%ebp)
  1032e2:	81 45 0c 00 10 00 00 	addl   $0x1000,0xc(%ebp)
  1032e9:	81 45 14 00 10 00 00 	addl   $0x1000,0x14(%ebp)
  1032f0:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  1032f4:	75 92                	jne    103288 <boot_map_segment+0x92>
    }
}
  1032f6:	90                   	nop
  1032f7:	c9                   	leave  
  1032f8:	c3                   	ret    

001032f9 <boot_alloc_page>:

//boot_alloc_page - allocate one page using pmm->alloc_pages(1) 
// return value: the kernel virtual address of this allocated page
//note: this function is used to get the memory for PDT(Page Directory Table)&PT(Page Table)
static void *
boot_alloc_page(void) {
  1032f9:	55                   	push   %ebp
  1032fa:	89 e5                	mov    %esp,%ebp
  1032fc:	83 ec 28             	sub    $0x28,%esp
    struct Page *p = alloc_page();
  1032ff:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  103306:	e8 60 fa ff ff       	call   102d6b <alloc_pages>
  10330b:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (p == NULL) {
  10330e:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  103312:	75 1c                	jne    103330 <boot_alloc_page+0x37>
        panic("boot_alloc_page failed.\n");
  103314:	c7 44 24 08 ef 69 10 	movl   $0x1069ef,0x8(%esp)
  10331b:	00 
  10331c:	c7 44 24 04 19 01 00 	movl   $0x119,0x4(%esp)
  103323:	00 
  103324:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  10332b:	e8 c9 d0 ff ff       	call   1003f9 <__panic>
    }
    return page2kva(p);
  103330:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103333:	89 04 24             	mov    %eax,(%esp)
  103336:	e8 81 f7 ff ff       	call   102abc <page2kva>
}
  10333b:	c9                   	leave  
  10333c:	c3                   	ret    

0010333d <pmm_init>:
//7、从新设置全局段描述符表；
//8、取消临时二级页表；
//9、检查页表建立是否正确；
//10、通过自映射机制完成页表的打印输出（这部分是扩展知识）
void
pmm_init(void) {
  10333d:	55                   	push   %ebp
  10333e:	89 e5                	mov    %esp,%ebp
  103340:	83 ec 38             	sub    $0x38,%esp
    // We've already enabled paging
    boot_cr3 = PADDR(boot_pgdir);
  103343:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103348:	89 45 f4             	mov    %eax,-0xc(%ebp)
  10334b:	81 7d f4 ff ff ff bf 	cmpl   $0xbfffffff,-0xc(%ebp)
  103352:	77 23                	ja     103377 <pmm_init+0x3a>
  103354:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103357:	89 44 24 0c          	mov    %eax,0xc(%esp)
  10335b:	c7 44 24 08 84 69 10 	movl   $0x106984,0x8(%esp)
  103362:	00 
  103363:	c7 44 24 04 2e 01 00 	movl   $0x12e,0x4(%esp)
  10336a:	00 
  10336b:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103372:	e8 82 d0 ff ff       	call   1003f9 <__panic>
  103377:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10337a:	05 00 00 00 40       	add    $0x40000000,%eax
  10337f:	a3 74 bf 11 00       	mov    %eax,0x11bf74
    //So a framework of physical memory manager (struct pmm_manager)is defined in pmm.h
    //First we should init a physical memory manager(pmm) based on the framework.
    //Then pmm can alloc/free the physical memory. 
    //Now the first_fit/best_fit/worst_fit/buddy_system pmm are available.
    //1、初始化物理内存页管理器框架pmm_manager；
    init_pmm_manager();
  103384:	e8 8e f9 ff ff       	call   102d17 <init_pmm_manager>

    // detect physical memory space, reserve already used memory,
    // then use pmm->init_memmap to create free page list
    //2、建立空闲的page链表，这样就可以分配以页（4KB）为单位的空闲内存了；
    page_init();
  103389:	e8 73 fa ff ff       	call   102e01 <page_init>

    //use pmm->check to verify the correctness of the alloc/free function in a pmm
   // 3、检查物理内存页分配算法；
    check_alloc_page();
  10338e:	e8 de 03 00 00       	call   103771 <check_alloc_page>

    check_pgdir();
  103393:	e8 f8 03 00 00       	call   103790 <check_pgdir>

    static_assert(KERNBASE % PTSIZE == 0 && KERNTOP % PTSIZE == 0);

    // recursively insert boot_pgdir in itself
    // to form a virtual page table at virtual address VPT
    boot_pgdir[PDX(VPT)] = PADDR(boot_pgdir) | PTE_P | PTE_W;
  103398:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  10339d:	89 45 f0             	mov    %eax,-0x10(%ebp)
  1033a0:	81 7d f0 ff ff ff bf 	cmpl   $0xbfffffff,-0x10(%ebp)
  1033a7:	77 23                	ja     1033cc <pmm_init+0x8f>
  1033a9:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1033ac:	89 44 24 0c          	mov    %eax,0xc(%esp)
  1033b0:	c7 44 24 08 84 69 10 	movl   $0x106984,0x8(%esp)
  1033b7:	00 
  1033b8:	c7 44 24 04 47 01 00 	movl   $0x147,0x4(%esp)
  1033bf:	00 
  1033c0:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1033c7:	e8 2d d0 ff ff       	call   1003f9 <__panic>
  1033cc:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1033cf:	8d 90 00 00 00 40    	lea    0x40000000(%eax),%edx
  1033d5:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  1033da:	05 ac 0f 00 00       	add    $0xfac,%eax
  1033df:	83 ca 03             	or     $0x3,%edx
  1033e2:	89 10                	mov    %edx,(%eax)

    // map all physical memory to linear memory with base linear addr KERNBASE
    // linear_addr KERNBASE ~ KERNBASE + KMEMSIZE = phy_addr 0 ~ KMEMSIZE
    boot_map_segment(boot_pgdir, KERNBASE, KMEMSIZE, 0, PTE_W);
  1033e4:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  1033e9:	c7 44 24 10 02 00 00 	movl   $0x2,0x10(%esp)
  1033f0:	00 
  1033f1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
  1033f8:	00 
  1033f9:	c7 44 24 08 00 00 00 	movl   $0x38000000,0x8(%esp)
  103400:	38 
  103401:	c7 44 24 04 00 00 00 	movl   $0xc0000000,0x4(%esp)
  103408:	c0 
  103409:	89 04 24             	mov    %eax,(%esp)
  10340c:	e8 e5 fd ff ff       	call   1031f6 <boot_map_segment>

    // Since we are using bootloader's GDT,
    // we should reload gdt (second time, the last time) to get user segments and the TSS
    // map virtual_addr 0 ~ 4G = linear_addr 0 ~ 4G
    // then set kernel stack (ss:esp) in TSS, setup TSS in gdt, load TSS
    gdt_init();
  103411:	e8 18 f8 ff ff       	call   102c2e <gdt_init>

    //now the basic virtual memory map(see memalyout.h) is established.
    //check the correctness of the basic virtual memory map.
    //检查页表建立是否正确；
    check_boot_pgdir();
  103416:	e8 11 0a 00 00       	call   103e2c <check_boot_pgdir>

    //10、通过自映射机制完成页表的打印输出（这部分是扩展知识）
    print_pgdir();
  10341b:	e8 8a 0e 00 00       	call   1042aa <print_pgdir>

}
  103420:	90                   	nop
  103421:	c9                   	leave  
  103422:	c3                   	ret    

00103423 <get_pte>:
//  la:     the linear address need to map
//  create: a logical value to decide if alloc a page for PT
// return vaule: the kernel virtual address of this pte
//完成虚实映射
pte_t *
get_pte(pde_t *pgdir, uintptr_t la, bool create) {
  103423:	55                   	push   %ebp
  103424:	89 e5                	mov    %esp,%ebp
  103426:	83 ec 38             	sub    $0x38,%esp
                          // (6) clear page content using memset
                          // (7) set page directory entry's permission
    }
    return NULL;          // (8) return page table entry
#endif
 pde_t *pdep = &pgdir[PDX(la)];
  103429:	8b 45 0c             	mov    0xc(%ebp),%eax
  10342c:	c1 e8 16             	shr    $0x16,%eax
  10342f:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
  103436:	8b 45 08             	mov    0x8(%ebp),%eax
  103439:	01 d0                	add    %edx,%eax
  10343b:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (!(*pdep & PTE_P)) {
  10343e:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103441:	8b 00                	mov    (%eax),%eax
  103443:	83 e0 01             	and    $0x1,%eax
  103446:	85 c0                	test   %eax,%eax
  103448:	0f 85 af 00 00 00    	jne    1034fd <get_pte+0xda>
        struct Page *page;
        if (!create || (page = alloc_page()) == NULL) {
  10344e:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  103452:	74 15                	je     103469 <get_pte+0x46>
  103454:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  10345b:	e8 0b f9 ff ff       	call   102d6b <alloc_pages>
  103460:	89 45 f0             	mov    %eax,-0x10(%ebp)
  103463:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  103467:	75 0a                	jne    103473 <get_pte+0x50>
            return NULL;
  103469:	b8 00 00 00 00       	mov    $0x0,%eax
  10346e:	e9 e7 00 00 00       	jmp    10355a <get_pte+0x137>
        }
        set_page_ref(page, 1);
  103473:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  10347a:	00 
  10347b:	8b 45 f0             	mov    -0x10(%ebp),%eax
  10347e:	89 04 24             	mov    %eax,(%esp)
  103481:	e8 ea f6 ff ff       	call   102b70 <set_page_ref>
        uintptr_t pa = page2pa(page);
  103486:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103489:	89 04 24             	mov    %eax,(%esp)
  10348c:	e8 c6 f5 ff ff       	call   102a57 <page2pa>
  103491:	89 45 ec             	mov    %eax,-0x14(%ebp)
        memset(KADDR(pa), 0, PGSIZE);
  103494:	8b 45 ec             	mov    -0x14(%ebp),%eax
  103497:	89 45 e8             	mov    %eax,-0x18(%ebp)
  10349a:	8b 45 e8             	mov    -0x18(%ebp),%eax
  10349d:	c1 e8 0c             	shr    $0xc,%eax
  1034a0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  1034a3:	a1 80 be 11 00       	mov    0x11be80,%eax
  1034a8:	39 45 e4             	cmp    %eax,-0x1c(%ebp)
  1034ab:	72 23                	jb     1034d0 <get_pte+0xad>
  1034ad:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1034b0:	89 44 24 0c          	mov    %eax,0xc(%esp)
  1034b4:	c7 44 24 08 e0 68 10 	movl   $0x1068e0,0x8(%esp)
  1034bb:	00 
  1034bc:	c7 44 24 04 90 01 00 	movl   $0x190,0x4(%esp)
  1034c3:	00 
  1034c4:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1034cb:	e8 29 cf ff ff       	call   1003f9 <__panic>
  1034d0:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1034d3:	2d 00 00 00 40       	sub    $0x40000000,%eax
  1034d8:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
  1034df:	00 
  1034e0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  1034e7:	00 
  1034e8:	89 04 24             	mov    %eax,(%esp)
  1034eb:	e8 94 24 00 00       	call   105984 <memset>
        *pdep = pa | PTE_U | PTE_W | PTE_P;
  1034f0:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1034f3:	83 c8 07             	or     $0x7,%eax
  1034f6:	89 c2                	mov    %eax,%edx
  1034f8:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1034fb:	89 10                	mov    %edx,(%eax)
    }
    return &((pte_t *)KADDR(PDE_ADDR(*pdep)))[PTX(la)];
  1034fd:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103500:	8b 00                	mov    (%eax),%eax
  103502:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  103507:	89 45 e0             	mov    %eax,-0x20(%ebp)
  10350a:	8b 45 e0             	mov    -0x20(%ebp),%eax
  10350d:	c1 e8 0c             	shr    $0xc,%eax
  103510:	89 45 dc             	mov    %eax,-0x24(%ebp)
  103513:	a1 80 be 11 00       	mov    0x11be80,%eax
  103518:	39 45 dc             	cmp    %eax,-0x24(%ebp)
  10351b:	72 23                	jb     103540 <get_pte+0x11d>
  10351d:	8b 45 e0             	mov    -0x20(%ebp),%eax
  103520:	89 44 24 0c          	mov    %eax,0xc(%esp)
  103524:	c7 44 24 08 e0 68 10 	movl   $0x1068e0,0x8(%esp)
  10352b:	00 
  10352c:	c7 44 24 04 93 01 00 	movl   $0x193,0x4(%esp)
  103533:	00 
  103534:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  10353b:	e8 b9 ce ff ff       	call   1003f9 <__panic>
  103540:	8b 45 e0             	mov    -0x20(%ebp),%eax
  103543:	2d 00 00 00 40       	sub    $0x40000000,%eax
  103548:	89 c2                	mov    %eax,%edx
  10354a:	8b 45 0c             	mov    0xc(%ebp),%eax
  10354d:	c1 e8 0c             	shr    $0xc,%eax
  103550:	25 ff 03 00 00       	and    $0x3ff,%eax
  103555:	c1 e0 02             	shl    $0x2,%eax
  103558:	01 d0                	add    %edx,%eax
}
  10355a:	c9                   	leave  
  10355b:	c3                   	ret    

0010355c <get_page>:

//get_page - get related Page struct for linear address la using PDT pgdir
struct Page *
get_page(pde_t *pgdir, uintptr_t la, pte_t **ptep_store) {
  10355c:	55                   	push   %ebp
  10355d:	89 e5                	mov    %esp,%ebp
  10355f:	83 ec 28             	sub    $0x28,%esp
    pte_t *ptep = get_pte(pgdir, la, 0);
  103562:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  103569:	00 
  10356a:	8b 45 0c             	mov    0xc(%ebp),%eax
  10356d:	89 44 24 04          	mov    %eax,0x4(%esp)
  103571:	8b 45 08             	mov    0x8(%ebp),%eax
  103574:	89 04 24             	mov    %eax,(%esp)
  103577:	e8 a7 fe ff ff       	call   103423 <get_pte>
  10357c:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (ptep_store != NULL) {
  10357f:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  103583:	74 08                	je     10358d <get_page+0x31>
        *ptep_store = ptep;
  103585:	8b 45 10             	mov    0x10(%ebp),%eax
  103588:	8b 55 f4             	mov    -0xc(%ebp),%edx
  10358b:	89 10                	mov    %edx,(%eax)
    }
    if (ptep != NULL && *ptep & PTE_P) {
  10358d:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  103591:	74 1b                	je     1035ae <get_page+0x52>
  103593:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103596:	8b 00                	mov    (%eax),%eax
  103598:	83 e0 01             	and    $0x1,%eax
  10359b:	85 c0                	test   %eax,%eax
  10359d:	74 0f                	je     1035ae <get_page+0x52>
        return pte2page(*ptep);
  10359f:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1035a2:	8b 00                	mov    (%eax),%eax
  1035a4:	89 04 24             	mov    %eax,(%esp)
  1035a7:	e8 64 f5 ff ff       	call   102b10 <pte2page>
  1035ac:	eb 05                	jmp    1035b3 <get_page+0x57>
    }
    return NULL;
  1035ae:	b8 00 00 00 00       	mov    $0x0,%eax
}
  1035b3:	c9                   	leave  
  1035b4:	c3                   	ret    

001035b5 <page_remove_pte>:

//page_remove_pte - free an Page sturct which is related linear address la
//                - and clean(invalidate) pte which is related linear address la
//note: PT is changed, so the TLB need to be invalidate 
static inline void
page_remove_pte(pde_t *pgdir, uintptr_t la, pte_t *ptep) {
  1035b5:	55                   	push   %ebp
  1035b6:	89 e5                	mov    %esp,%ebp
  1035b8:	83 ec 28             	sub    $0x28,%esp
                                  //(4) and free this page when page reference reachs 0
                                  //(5) clear second page table entry
                                  //(6) flush tlb
    }
#endif
    if (*ptep & PTE_P) {
  1035bb:	8b 45 10             	mov    0x10(%ebp),%eax
  1035be:	8b 00                	mov    (%eax),%eax
  1035c0:	83 e0 01             	and    $0x1,%eax
  1035c3:	85 c0                	test   %eax,%eax
  1035c5:	74 4d                	je     103614 <page_remove_pte+0x5f>
        struct Page *page = pte2page(*ptep);
  1035c7:	8b 45 10             	mov    0x10(%ebp),%eax
  1035ca:	8b 00                	mov    (%eax),%eax
  1035cc:	89 04 24             	mov    %eax,(%esp)
  1035cf:	e8 3c f5 ff ff       	call   102b10 <pte2page>
  1035d4:	89 45 f4             	mov    %eax,-0xc(%ebp)
        if (page_ref_dec(page) == 0) {
  1035d7:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1035da:	89 04 24             	mov    %eax,(%esp)
  1035dd:	e8 b3 f5 ff ff       	call   102b95 <page_ref_dec>
  1035e2:	85 c0                	test   %eax,%eax
  1035e4:	75 13                	jne    1035f9 <page_remove_pte+0x44>
            free_page(page);
  1035e6:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  1035ed:	00 
  1035ee:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1035f1:	89 04 24             	mov    %eax,(%esp)
  1035f4:	e8 aa f7 ff ff       	call   102da3 <free_pages>
        }
        *ptep = 0;
  1035f9:	8b 45 10             	mov    0x10(%ebp),%eax
  1035fc:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
        tlb_invalidate(pgdir, la);
  103602:	8b 45 0c             	mov    0xc(%ebp),%eax
  103605:	89 44 24 04          	mov    %eax,0x4(%esp)
  103609:	8b 45 08             	mov    0x8(%ebp),%eax
  10360c:	89 04 24             	mov    %eax,(%esp)
  10360f:	e8 01 01 00 00       	call   103715 <tlb_invalidate>
    }
}
  103614:	90                   	nop
  103615:	c9                   	leave  
  103616:	c3                   	ret    

00103617 <page_remove>:

//page_remove - free an Page which is related linear address la and has an validated pte
void
page_remove(pde_t *pgdir, uintptr_t la) {
  103617:	55                   	push   %ebp
  103618:	89 e5                	mov    %esp,%ebp
  10361a:	83 ec 28             	sub    $0x28,%esp
    pte_t *ptep = get_pte(pgdir, la, 0);
  10361d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  103624:	00 
  103625:	8b 45 0c             	mov    0xc(%ebp),%eax
  103628:	89 44 24 04          	mov    %eax,0x4(%esp)
  10362c:	8b 45 08             	mov    0x8(%ebp),%eax
  10362f:	89 04 24             	mov    %eax,(%esp)
  103632:	e8 ec fd ff ff       	call   103423 <get_pte>
  103637:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (ptep != NULL) {
  10363a:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  10363e:	74 19                	je     103659 <page_remove+0x42>
        page_remove_pte(pgdir, la, ptep);
  103640:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103643:	89 44 24 08          	mov    %eax,0x8(%esp)
  103647:	8b 45 0c             	mov    0xc(%ebp),%eax
  10364a:	89 44 24 04          	mov    %eax,0x4(%esp)
  10364e:	8b 45 08             	mov    0x8(%ebp),%eax
  103651:	89 04 24             	mov    %eax,(%esp)
  103654:	e8 5c ff ff ff       	call   1035b5 <page_remove_pte>
    }
}
  103659:	90                   	nop
  10365a:	c9                   	leave  
  10365b:	c3                   	ret    

0010365c <page_insert>:
//  la:    the linear address need to map
//  perm:  the permission of this Page which is setted in related pte
// return value: always 0
//note: PT is changed, so the TLB need to be invalidate 
int
page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm) {
  10365c:	55                   	push   %ebp
  10365d:	89 e5                	mov    %esp,%ebp
  10365f:	83 ec 28             	sub    $0x28,%esp
    pte_t *ptep = get_pte(pgdir, la, 1);
  103662:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
  103669:	00 
  10366a:	8b 45 10             	mov    0x10(%ebp),%eax
  10366d:	89 44 24 04          	mov    %eax,0x4(%esp)
  103671:	8b 45 08             	mov    0x8(%ebp),%eax
  103674:	89 04 24             	mov    %eax,(%esp)
  103677:	e8 a7 fd ff ff       	call   103423 <get_pte>
  10367c:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (ptep == NULL) {
  10367f:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  103683:	75 0a                	jne    10368f <page_insert+0x33>
        return -E_NO_MEM;
  103685:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
  10368a:	e9 84 00 00 00       	jmp    103713 <page_insert+0xb7>
    }
    page_ref_inc(page);
  10368f:	8b 45 0c             	mov    0xc(%ebp),%eax
  103692:	89 04 24             	mov    %eax,(%esp)
  103695:	e8 e4 f4 ff ff       	call   102b7e <page_ref_inc>
    if (*ptep & PTE_P) {
  10369a:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10369d:	8b 00                	mov    (%eax),%eax
  10369f:	83 e0 01             	and    $0x1,%eax
  1036a2:	85 c0                	test   %eax,%eax
  1036a4:	74 3e                	je     1036e4 <page_insert+0x88>
        struct Page *p = pte2page(*ptep);
  1036a6:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1036a9:	8b 00                	mov    (%eax),%eax
  1036ab:	89 04 24             	mov    %eax,(%esp)
  1036ae:	e8 5d f4 ff ff       	call   102b10 <pte2page>
  1036b3:	89 45 f0             	mov    %eax,-0x10(%ebp)
        if (p == page) {
  1036b6:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1036b9:	3b 45 0c             	cmp    0xc(%ebp),%eax
  1036bc:	75 0d                	jne    1036cb <page_insert+0x6f>
            page_ref_dec(page);
  1036be:	8b 45 0c             	mov    0xc(%ebp),%eax
  1036c1:	89 04 24             	mov    %eax,(%esp)
  1036c4:	e8 cc f4 ff ff       	call   102b95 <page_ref_dec>
  1036c9:	eb 19                	jmp    1036e4 <page_insert+0x88>
        }
        else {
            page_remove_pte(pgdir, la, ptep);
  1036cb:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1036ce:	89 44 24 08          	mov    %eax,0x8(%esp)
  1036d2:	8b 45 10             	mov    0x10(%ebp),%eax
  1036d5:	89 44 24 04          	mov    %eax,0x4(%esp)
  1036d9:	8b 45 08             	mov    0x8(%ebp),%eax
  1036dc:	89 04 24             	mov    %eax,(%esp)
  1036df:	e8 d1 fe ff ff       	call   1035b5 <page_remove_pte>
        }
    }
    *ptep = page2pa(page) | PTE_P | perm;
  1036e4:	8b 45 0c             	mov    0xc(%ebp),%eax
  1036e7:	89 04 24             	mov    %eax,(%esp)
  1036ea:	e8 68 f3 ff ff       	call   102a57 <page2pa>
  1036ef:	0b 45 14             	or     0x14(%ebp),%eax
  1036f2:	83 c8 01             	or     $0x1,%eax
  1036f5:	89 c2                	mov    %eax,%edx
  1036f7:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1036fa:	89 10                	mov    %edx,(%eax)
    tlb_invalidate(pgdir, la);
  1036fc:	8b 45 10             	mov    0x10(%ebp),%eax
  1036ff:	89 44 24 04          	mov    %eax,0x4(%esp)
  103703:	8b 45 08             	mov    0x8(%ebp),%eax
  103706:	89 04 24             	mov    %eax,(%esp)
  103709:	e8 07 00 00 00       	call   103715 <tlb_invalidate>
    return 0;
  10370e:	b8 00 00 00 00       	mov    $0x0,%eax
}
  103713:	c9                   	leave  
  103714:	c3                   	ret    

00103715 <tlb_invalidate>:

// invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
void
tlb_invalidate(pde_t *pgdir, uintptr_t la) {
  103715:	55                   	push   %ebp
  103716:	89 e5                	mov    %esp,%ebp
  103718:	83 ec 28             	sub    $0x28,%esp
}

static inline uintptr_t
rcr3(void) {
    uintptr_t cr3;
    asm volatile ("mov %%cr3, %0" : "=r" (cr3) :: "memory");
  10371b:	0f 20 d8             	mov    %cr3,%eax
  10371e:	89 45 f0             	mov    %eax,-0x10(%ebp)
    return cr3;
  103721:	8b 55 f0             	mov    -0x10(%ebp),%edx
    if (rcr3() == PADDR(pgdir)) {
  103724:	8b 45 08             	mov    0x8(%ebp),%eax
  103727:	89 45 f4             	mov    %eax,-0xc(%ebp)
  10372a:	81 7d f4 ff ff ff bf 	cmpl   $0xbfffffff,-0xc(%ebp)
  103731:	77 23                	ja     103756 <tlb_invalidate+0x41>
  103733:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103736:	89 44 24 0c          	mov    %eax,0xc(%esp)
  10373a:	c7 44 24 08 84 69 10 	movl   $0x106984,0x8(%esp)
  103741:	00 
  103742:	c7 44 24 04 f5 01 00 	movl   $0x1f5,0x4(%esp)
  103749:	00 
  10374a:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103751:	e8 a3 cc ff ff       	call   1003f9 <__panic>
  103756:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103759:	05 00 00 00 40       	add    $0x40000000,%eax
  10375e:	39 d0                	cmp    %edx,%eax
  103760:	75 0c                	jne    10376e <tlb_invalidate+0x59>
        invlpg((void *)la);
  103762:	8b 45 0c             	mov    0xc(%ebp),%eax
  103765:	89 45 ec             	mov    %eax,-0x14(%ebp)
}

static inline void
invlpg(void *addr) {
    asm volatile ("invlpg (%0)" :: "r" (addr) : "memory");
  103768:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10376b:	0f 01 38             	invlpg (%eax)
    }
}
  10376e:	90                   	nop
  10376f:	c9                   	leave  
  103770:	c3                   	ret    

00103771 <check_alloc_page>:

static void
check_alloc_page(void) {
  103771:	55                   	push   %ebp
  103772:	89 e5                	mov    %esp,%ebp
  103774:	83 ec 18             	sub    $0x18,%esp
    pmm_manager->check();
  103777:	a1 70 bf 11 00       	mov    0x11bf70,%eax
  10377c:	8b 40 18             	mov    0x18(%eax),%eax
  10377f:	ff d0                	call   *%eax
    cprintf("check_alloc_page() succeeded!\n");
  103781:	c7 04 24 08 6a 10 00 	movl   $0x106a08,(%esp)
  103788:	e8 15 cb ff ff       	call   1002a2 <cprintf>
}
  10378d:	90                   	nop
  10378e:	c9                   	leave  
  10378f:	c3                   	ret    

00103790 <check_pgdir>:

static void
check_pgdir(void) {
  103790:	55                   	push   %ebp
  103791:	89 e5                	mov    %esp,%ebp
  103793:	83 ec 38             	sub    $0x38,%esp
    assert(npage <= KMEMSIZE / PGSIZE);
  103796:	a1 80 be 11 00       	mov    0x11be80,%eax
  10379b:	3d 00 80 03 00       	cmp    $0x38000,%eax
  1037a0:	76 24                	jbe    1037c6 <check_pgdir+0x36>
  1037a2:	c7 44 24 0c 27 6a 10 	movl   $0x106a27,0xc(%esp)
  1037a9:	00 
  1037aa:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  1037b1:	00 
  1037b2:	c7 44 24 04 02 02 00 	movl   $0x202,0x4(%esp)
  1037b9:	00 
  1037ba:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1037c1:	e8 33 cc ff ff       	call   1003f9 <__panic>
    assert(boot_pgdir != NULL && (uint32_t)PGOFF(boot_pgdir) == 0);
  1037c6:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  1037cb:	85 c0                	test   %eax,%eax
  1037cd:	74 0e                	je     1037dd <check_pgdir+0x4d>
  1037cf:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  1037d4:	25 ff 0f 00 00       	and    $0xfff,%eax
  1037d9:	85 c0                	test   %eax,%eax
  1037db:	74 24                	je     103801 <check_pgdir+0x71>
  1037dd:	c7 44 24 0c 44 6a 10 	movl   $0x106a44,0xc(%esp)
  1037e4:	00 
  1037e5:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  1037ec:	00 
  1037ed:	c7 44 24 04 03 02 00 	movl   $0x203,0x4(%esp)
  1037f4:	00 
  1037f5:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1037fc:	e8 f8 cb ff ff       	call   1003f9 <__panic>
    assert(get_page(boot_pgdir, 0x0, NULL) == NULL);
  103801:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103806:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  10380d:	00 
  10380e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  103815:	00 
  103816:	89 04 24             	mov    %eax,(%esp)
  103819:	e8 3e fd ff ff       	call   10355c <get_page>
  10381e:	85 c0                	test   %eax,%eax
  103820:	74 24                	je     103846 <check_pgdir+0xb6>
  103822:	c7 44 24 0c 7c 6a 10 	movl   $0x106a7c,0xc(%esp)
  103829:	00 
  10382a:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103831:	00 
  103832:	c7 44 24 04 04 02 00 	movl   $0x204,0x4(%esp)
  103839:	00 
  10383a:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103841:	e8 b3 cb ff ff       	call   1003f9 <__panic>

    struct Page *p1, *p2;
    p1 = alloc_page();
  103846:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  10384d:	e8 19 f5 ff ff       	call   102d6b <alloc_pages>
  103852:	89 45 f4             	mov    %eax,-0xc(%ebp)
    assert(page_insert(boot_pgdir, p1, 0x0, 0) == 0);
  103855:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  10385a:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
  103861:	00 
  103862:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  103869:	00 
  10386a:	8b 55 f4             	mov    -0xc(%ebp),%edx
  10386d:	89 54 24 04          	mov    %edx,0x4(%esp)
  103871:	89 04 24             	mov    %eax,(%esp)
  103874:	e8 e3 fd ff ff       	call   10365c <page_insert>
  103879:	85 c0                	test   %eax,%eax
  10387b:	74 24                	je     1038a1 <check_pgdir+0x111>
  10387d:	c7 44 24 0c a4 6a 10 	movl   $0x106aa4,0xc(%esp)
  103884:	00 
  103885:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  10388c:	00 
  10388d:	c7 44 24 04 08 02 00 	movl   $0x208,0x4(%esp)
  103894:	00 
  103895:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  10389c:	e8 58 cb ff ff       	call   1003f9 <__panic>

    pte_t *ptep;
    assert((ptep = get_pte(boot_pgdir, 0x0, 0)) != NULL);
  1038a1:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  1038a6:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  1038ad:	00 
  1038ae:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  1038b5:	00 
  1038b6:	89 04 24             	mov    %eax,(%esp)
  1038b9:	e8 65 fb ff ff       	call   103423 <get_pte>
  1038be:	89 45 f0             	mov    %eax,-0x10(%ebp)
  1038c1:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  1038c5:	75 24                	jne    1038eb <check_pgdir+0x15b>
  1038c7:	c7 44 24 0c d0 6a 10 	movl   $0x106ad0,0xc(%esp)
  1038ce:	00 
  1038cf:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  1038d6:	00 
  1038d7:	c7 44 24 04 0b 02 00 	movl   $0x20b,0x4(%esp)
  1038de:	00 
  1038df:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1038e6:	e8 0e cb ff ff       	call   1003f9 <__panic>
    assert(pte2page(*ptep) == p1);
  1038eb:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1038ee:	8b 00                	mov    (%eax),%eax
  1038f0:	89 04 24             	mov    %eax,(%esp)
  1038f3:	e8 18 f2 ff ff       	call   102b10 <pte2page>
  1038f8:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  1038fb:	74 24                	je     103921 <check_pgdir+0x191>
  1038fd:	c7 44 24 0c fd 6a 10 	movl   $0x106afd,0xc(%esp)
  103904:	00 
  103905:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  10390c:	00 
  10390d:	c7 44 24 04 0c 02 00 	movl   $0x20c,0x4(%esp)
  103914:	00 
  103915:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  10391c:	e8 d8 ca ff ff       	call   1003f9 <__panic>
    assert(page_ref(p1) == 1);
  103921:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103924:	89 04 24             	mov    %eax,(%esp)
  103927:	e8 3a f2 ff ff       	call   102b66 <page_ref>
  10392c:	83 f8 01             	cmp    $0x1,%eax
  10392f:	74 24                	je     103955 <check_pgdir+0x1c5>
  103931:	c7 44 24 0c 13 6b 10 	movl   $0x106b13,0xc(%esp)
  103938:	00 
  103939:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103940:	00 
  103941:	c7 44 24 04 0d 02 00 	movl   $0x20d,0x4(%esp)
  103948:	00 
  103949:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103950:	e8 a4 ca ff ff       	call   1003f9 <__panic>

    ptep = &((pte_t *)KADDR(PDE_ADDR(boot_pgdir[0])))[1];
  103955:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  10395a:	8b 00                	mov    (%eax),%eax
  10395c:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  103961:	89 45 ec             	mov    %eax,-0x14(%ebp)
  103964:	8b 45 ec             	mov    -0x14(%ebp),%eax
  103967:	c1 e8 0c             	shr    $0xc,%eax
  10396a:	89 45 e8             	mov    %eax,-0x18(%ebp)
  10396d:	a1 80 be 11 00       	mov    0x11be80,%eax
  103972:	39 45 e8             	cmp    %eax,-0x18(%ebp)
  103975:	72 23                	jb     10399a <check_pgdir+0x20a>
  103977:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10397a:	89 44 24 0c          	mov    %eax,0xc(%esp)
  10397e:	c7 44 24 08 e0 68 10 	movl   $0x1068e0,0x8(%esp)
  103985:	00 
  103986:	c7 44 24 04 0f 02 00 	movl   $0x20f,0x4(%esp)
  10398d:	00 
  10398e:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103995:	e8 5f ca ff ff       	call   1003f9 <__panic>
  10399a:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10399d:	2d 00 00 00 40       	sub    $0x40000000,%eax
  1039a2:	83 c0 04             	add    $0x4,%eax
  1039a5:	89 45 f0             	mov    %eax,-0x10(%ebp)
    assert(get_pte(boot_pgdir, PGSIZE, 0) == ptep);
  1039a8:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  1039ad:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  1039b4:	00 
  1039b5:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
  1039bc:	00 
  1039bd:	89 04 24             	mov    %eax,(%esp)
  1039c0:	e8 5e fa ff ff       	call   103423 <get_pte>
  1039c5:	39 45 f0             	cmp    %eax,-0x10(%ebp)
  1039c8:	74 24                	je     1039ee <check_pgdir+0x25e>
  1039ca:	c7 44 24 0c 28 6b 10 	movl   $0x106b28,0xc(%esp)
  1039d1:	00 
  1039d2:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  1039d9:	00 
  1039da:	c7 44 24 04 10 02 00 	movl   $0x210,0x4(%esp)
  1039e1:	00 
  1039e2:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1039e9:	e8 0b ca ff ff       	call   1003f9 <__panic>

    p2 = alloc_page();
  1039ee:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  1039f5:	e8 71 f3 ff ff       	call   102d6b <alloc_pages>
  1039fa:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    assert(page_insert(boot_pgdir, p2, PGSIZE, PTE_U | PTE_W) == 0);
  1039fd:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103a02:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
  103a09:	00 
  103a0a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
  103a11:	00 
  103a12:	8b 55 e4             	mov    -0x1c(%ebp),%edx
  103a15:	89 54 24 04          	mov    %edx,0x4(%esp)
  103a19:	89 04 24             	mov    %eax,(%esp)
  103a1c:	e8 3b fc ff ff       	call   10365c <page_insert>
  103a21:	85 c0                	test   %eax,%eax
  103a23:	74 24                	je     103a49 <check_pgdir+0x2b9>
  103a25:	c7 44 24 0c 50 6b 10 	movl   $0x106b50,0xc(%esp)
  103a2c:	00 
  103a2d:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103a34:	00 
  103a35:	c7 44 24 04 13 02 00 	movl   $0x213,0x4(%esp)
  103a3c:	00 
  103a3d:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103a44:	e8 b0 c9 ff ff       	call   1003f9 <__panic>
    assert((ptep = get_pte(boot_pgdir, PGSIZE, 0)) != NULL);
  103a49:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103a4e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  103a55:	00 
  103a56:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
  103a5d:	00 
  103a5e:	89 04 24             	mov    %eax,(%esp)
  103a61:	e8 bd f9 ff ff       	call   103423 <get_pte>
  103a66:	89 45 f0             	mov    %eax,-0x10(%ebp)
  103a69:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  103a6d:	75 24                	jne    103a93 <check_pgdir+0x303>
  103a6f:	c7 44 24 0c 88 6b 10 	movl   $0x106b88,0xc(%esp)
  103a76:	00 
  103a77:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103a7e:	00 
  103a7f:	c7 44 24 04 14 02 00 	movl   $0x214,0x4(%esp)
  103a86:	00 
  103a87:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103a8e:	e8 66 c9 ff ff       	call   1003f9 <__panic>
    assert(*ptep & PTE_U);
  103a93:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103a96:	8b 00                	mov    (%eax),%eax
  103a98:	83 e0 04             	and    $0x4,%eax
  103a9b:	85 c0                	test   %eax,%eax
  103a9d:	75 24                	jne    103ac3 <check_pgdir+0x333>
  103a9f:	c7 44 24 0c b8 6b 10 	movl   $0x106bb8,0xc(%esp)
  103aa6:	00 
  103aa7:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103aae:	00 
  103aaf:	c7 44 24 04 15 02 00 	movl   $0x215,0x4(%esp)
  103ab6:	00 
  103ab7:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103abe:	e8 36 c9 ff ff       	call   1003f9 <__panic>
    assert(*ptep & PTE_W);
  103ac3:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103ac6:	8b 00                	mov    (%eax),%eax
  103ac8:	83 e0 02             	and    $0x2,%eax
  103acb:	85 c0                	test   %eax,%eax
  103acd:	75 24                	jne    103af3 <check_pgdir+0x363>
  103acf:	c7 44 24 0c c6 6b 10 	movl   $0x106bc6,0xc(%esp)
  103ad6:	00 
  103ad7:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103ade:	00 
  103adf:	c7 44 24 04 16 02 00 	movl   $0x216,0x4(%esp)
  103ae6:	00 
  103ae7:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103aee:	e8 06 c9 ff ff       	call   1003f9 <__panic>
    assert(boot_pgdir[0] & PTE_U);
  103af3:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103af8:	8b 00                	mov    (%eax),%eax
  103afa:	83 e0 04             	and    $0x4,%eax
  103afd:	85 c0                	test   %eax,%eax
  103aff:	75 24                	jne    103b25 <check_pgdir+0x395>
  103b01:	c7 44 24 0c d4 6b 10 	movl   $0x106bd4,0xc(%esp)
  103b08:	00 
  103b09:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103b10:	00 
  103b11:	c7 44 24 04 17 02 00 	movl   $0x217,0x4(%esp)
  103b18:	00 
  103b19:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103b20:	e8 d4 c8 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p2) == 1);
  103b25:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  103b28:	89 04 24             	mov    %eax,(%esp)
  103b2b:	e8 36 f0 ff ff       	call   102b66 <page_ref>
  103b30:	83 f8 01             	cmp    $0x1,%eax
  103b33:	74 24                	je     103b59 <check_pgdir+0x3c9>
  103b35:	c7 44 24 0c ea 6b 10 	movl   $0x106bea,0xc(%esp)
  103b3c:	00 
  103b3d:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103b44:	00 
  103b45:	c7 44 24 04 18 02 00 	movl   $0x218,0x4(%esp)
  103b4c:	00 
  103b4d:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103b54:	e8 a0 c8 ff ff       	call   1003f9 <__panic>

    assert(page_insert(boot_pgdir, p1, PGSIZE, 0) == 0);
  103b59:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103b5e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
  103b65:	00 
  103b66:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
  103b6d:	00 
  103b6e:	8b 55 f4             	mov    -0xc(%ebp),%edx
  103b71:	89 54 24 04          	mov    %edx,0x4(%esp)
  103b75:	89 04 24             	mov    %eax,(%esp)
  103b78:	e8 df fa ff ff       	call   10365c <page_insert>
  103b7d:	85 c0                	test   %eax,%eax
  103b7f:	74 24                	je     103ba5 <check_pgdir+0x415>
  103b81:	c7 44 24 0c fc 6b 10 	movl   $0x106bfc,0xc(%esp)
  103b88:	00 
  103b89:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103b90:	00 
  103b91:	c7 44 24 04 1a 02 00 	movl   $0x21a,0x4(%esp)
  103b98:	00 
  103b99:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103ba0:	e8 54 c8 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p1) == 2);
  103ba5:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103ba8:	89 04 24             	mov    %eax,(%esp)
  103bab:	e8 b6 ef ff ff       	call   102b66 <page_ref>
  103bb0:	83 f8 02             	cmp    $0x2,%eax
  103bb3:	74 24                	je     103bd9 <check_pgdir+0x449>
  103bb5:	c7 44 24 0c 28 6c 10 	movl   $0x106c28,0xc(%esp)
  103bbc:	00 
  103bbd:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103bc4:	00 
  103bc5:	c7 44 24 04 1b 02 00 	movl   $0x21b,0x4(%esp)
  103bcc:	00 
  103bcd:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103bd4:	e8 20 c8 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p2) == 0);
  103bd9:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  103bdc:	89 04 24             	mov    %eax,(%esp)
  103bdf:	e8 82 ef ff ff       	call   102b66 <page_ref>
  103be4:	85 c0                	test   %eax,%eax
  103be6:	74 24                	je     103c0c <check_pgdir+0x47c>
  103be8:	c7 44 24 0c 3a 6c 10 	movl   $0x106c3a,0xc(%esp)
  103bef:	00 
  103bf0:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103bf7:	00 
  103bf8:	c7 44 24 04 1c 02 00 	movl   $0x21c,0x4(%esp)
  103bff:	00 
  103c00:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103c07:	e8 ed c7 ff ff       	call   1003f9 <__panic>
    assert((ptep = get_pte(boot_pgdir, PGSIZE, 0)) != NULL);
  103c0c:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103c11:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  103c18:	00 
  103c19:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
  103c20:	00 
  103c21:	89 04 24             	mov    %eax,(%esp)
  103c24:	e8 fa f7 ff ff       	call   103423 <get_pte>
  103c29:	89 45 f0             	mov    %eax,-0x10(%ebp)
  103c2c:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  103c30:	75 24                	jne    103c56 <check_pgdir+0x4c6>
  103c32:	c7 44 24 0c 88 6b 10 	movl   $0x106b88,0xc(%esp)
  103c39:	00 
  103c3a:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103c41:	00 
  103c42:	c7 44 24 04 1d 02 00 	movl   $0x21d,0x4(%esp)
  103c49:	00 
  103c4a:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103c51:	e8 a3 c7 ff ff       	call   1003f9 <__panic>
    assert(pte2page(*ptep) == p1);
  103c56:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103c59:	8b 00                	mov    (%eax),%eax
  103c5b:	89 04 24             	mov    %eax,(%esp)
  103c5e:	e8 ad ee ff ff       	call   102b10 <pte2page>
  103c63:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  103c66:	74 24                	je     103c8c <check_pgdir+0x4fc>
  103c68:	c7 44 24 0c fd 6a 10 	movl   $0x106afd,0xc(%esp)
  103c6f:	00 
  103c70:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103c77:	00 
  103c78:	c7 44 24 04 1e 02 00 	movl   $0x21e,0x4(%esp)
  103c7f:	00 
  103c80:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103c87:	e8 6d c7 ff ff       	call   1003f9 <__panic>
    assert((*ptep & PTE_U) == 0);
  103c8c:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103c8f:	8b 00                	mov    (%eax),%eax
  103c91:	83 e0 04             	and    $0x4,%eax
  103c94:	85 c0                	test   %eax,%eax
  103c96:	74 24                	je     103cbc <check_pgdir+0x52c>
  103c98:	c7 44 24 0c 4c 6c 10 	movl   $0x106c4c,0xc(%esp)
  103c9f:	00 
  103ca0:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103ca7:	00 
  103ca8:	c7 44 24 04 1f 02 00 	movl   $0x21f,0x4(%esp)
  103caf:	00 
  103cb0:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103cb7:	e8 3d c7 ff ff       	call   1003f9 <__panic>

    page_remove(boot_pgdir, 0x0);
  103cbc:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103cc1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  103cc8:	00 
  103cc9:	89 04 24             	mov    %eax,(%esp)
  103ccc:	e8 46 f9 ff ff       	call   103617 <page_remove>
    assert(page_ref(p1) == 1);
  103cd1:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103cd4:	89 04 24             	mov    %eax,(%esp)
  103cd7:	e8 8a ee ff ff       	call   102b66 <page_ref>
  103cdc:	83 f8 01             	cmp    $0x1,%eax
  103cdf:	74 24                	je     103d05 <check_pgdir+0x575>
  103ce1:	c7 44 24 0c 13 6b 10 	movl   $0x106b13,0xc(%esp)
  103ce8:	00 
  103ce9:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103cf0:	00 
  103cf1:	c7 44 24 04 22 02 00 	movl   $0x222,0x4(%esp)
  103cf8:	00 
  103cf9:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103d00:	e8 f4 c6 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p2) == 0);
  103d05:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  103d08:	89 04 24             	mov    %eax,(%esp)
  103d0b:	e8 56 ee ff ff       	call   102b66 <page_ref>
  103d10:	85 c0                	test   %eax,%eax
  103d12:	74 24                	je     103d38 <check_pgdir+0x5a8>
  103d14:	c7 44 24 0c 3a 6c 10 	movl   $0x106c3a,0xc(%esp)
  103d1b:	00 
  103d1c:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103d23:	00 
  103d24:	c7 44 24 04 23 02 00 	movl   $0x223,0x4(%esp)
  103d2b:	00 
  103d2c:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103d33:	e8 c1 c6 ff ff       	call   1003f9 <__panic>

    page_remove(boot_pgdir, PGSIZE);
  103d38:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103d3d:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
  103d44:	00 
  103d45:	89 04 24             	mov    %eax,(%esp)
  103d48:	e8 ca f8 ff ff       	call   103617 <page_remove>
    assert(page_ref(p1) == 0);
  103d4d:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103d50:	89 04 24             	mov    %eax,(%esp)
  103d53:	e8 0e ee ff ff       	call   102b66 <page_ref>
  103d58:	85 c0                	test   %eax,%eax
  103d5a:	74 24                	je     103d80 <check_pgdir+0x5f0>
  103d5c:	c7 44 24 0c 61 6c 10 	movl   $0x106c61,0xc(%esp)
  103d63:	00 
  103d64:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103d6b:	00 
  103d6c:	c7 44 24 04 26 02 00 	movl   $0x226,0x4(%esp)
  103d73:	00 
  103d74:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103d7b:	e8 79 c6 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p2) == 0);
  103d80:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  103d83:	89 04 24             	mov    %eax,(%esp)
  103d86:	e8 db ed ff ff       	call   102b66 <page_ref>
  103d8b:	85 c0                	test   %eax,%eax
  103d8d:	74 24                	je     103db3 <check_pgdir+0x623>
  103d8f:	c7 44 24 0c 3a 6c 10 	movl   $0x106c3a,0xc(%esp)
  103d96:	00 
  103d97:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103d9e:	00 
  103d9f:	c7 44 24 04 27 02 00 	movl   $0x227,0x4(%esp)
  103da6:	00 
  103da7:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103dae:	e8 46 c6 ff ff       	call   1003f9 <__panic>

    assert(page_ref(pde2page(boot_pgdir[0])) == 1);
  103db3:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103db8:	8b 00                	mov    (%eax),%eax
  103dba:	89 04 24             	mov    %eax,(%esp)
  103dbd:	e8 8c ed ff ff       	call   102b4e <pde2page>
  103dc2:	89 04 24             	mov    %eax,(%esp)
  103dc5:	e8 9c ed ff ff       	call   102b66 <page_ref>
  103dca:	83 f8 01             	cmp    $0x1,%eax
  103dcd:	74 24                	je     103df3 <check_pgdir+0x663>
  103dcf:	c7 44 24 0c 74 6c 10 	movl   $0x106c74,0xc(%esp)
  103dd6:	00 
  103dd7:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103dde:	00 
  103ddf:	c7 44 24 04 29 02 00 	movl   $0x229,0x4(%esp)
  103de6:	00 
  103de7:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103dee:	e8 06 c6 ff ff       	call   1003f9 <__panic>
    free_page(pde2page(boot_pgdir[0]));
  103df3:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103df8:	8b 00                	mov    (%eax),%eax
  103dfa:	89 04 24             	mov    %eax,(%esp)
  103dfd:	e8 4c ed ff ff       	call   102b4e <pde2page>
  103e02:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  103e09:	00 
  103e0a:	89 04 24             	mov    %eax,(%esp)
  103e0d:	e8 91 ef ff ff       	call   102da3 <free_pages>
    boot_pgdir[0] = 0;
  103e12:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103e17:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

    cprintf("check_pgdir() succeeded!\n");
  103e1d:	c7 04 24 9b 6c 10 00 	movl   $0x106c9b,(%esp)
  103e24:	e8 79 c4 ff ff       	call   1002a2 <cprintf>
}
  103e29:	90                   	nop
  103e2a:	c9                   	leave  
  103e2b:	c3                   	ret    

00103e2c <check_boot_pgdir>:

static void
check_boot_pgdir(void) {
  103e2c:	55                   	push   %ebp
  103e2d:	89 e5                	mov    %esp,%ebp
  103e2f:	83 ec 38             	sub    $0x38,%esp
    pte_t *ptep;
    int i;
    for (i = 0; i < npage; i += PGSIZE) {
  103e32:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
  103e39:	e9 ca 00 00 00       	jmp    103f08 <check_boot_pgdir+0xdc>
        assert((ptep = get_pte(boot_pgdir, (uintptr_t)KADDR(i), 0)) != NULL);
  103e3e:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103e41:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  103e44:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  103e47:	c1 e8 0c             	shr    $0xc,%eax
  103e4a:	89 45 e0             	mov    %eax,-0x20(%ebp)
  103e4d:	a1 80 be 11 00       	mov    0x11be80,%eax
  103e52:	39 45 e0             	cmp    %eax,-0x20(%ebp)
  103e55:	72 23                	jb     103e7a <check_boot_pgdir+0x4e>
  103e57:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  103e5a:	89 44 24 0c          	mov    %eax,0xc(%esp)
  103e5e:	c7 44 24 08 e0 68 10 	movl   $0x1068e0,0x8(%esp)
  103e65:	00 
  103e66:	c7 44 24 04 35 02 00 	movl   $0x235,0x4(%esp)
  103e6d:	00 
  103e6e:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103e75:	e8 7f c5 ff ff       	call   1003f9 <__panic>
  103e7a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  103e7d:	2d 00 00 00 40       	sub    $0x40000000,%eax
  103e82:	89 c2                	mov    %eax,%edx
  103e84:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103e89:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
  103e90:	00 
  103e91:	89 54 24 04          	mov    %edx,0x4(%esp)
  103e95:	89 04 24             	mov    %eax,(%esp)
  103e98:	e8 86 f5 ff ff       	call   103423 <get_pte>
  103e9d:	89 45 dc             	mov    %eax,-0x24(%ebp)
  103ea0:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
  103ea4:	75 24                	jne    103eca <check_boot_pgdir+0x9e>
  103ea6:	c7 44 24 0c b8 6c 10 	movl   $0x106cb8,0xc(%esp)
  103ead:	00 
  103eae:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103eb5:	00 
  103eb6:	c7 44 24 04 35 02 00 	movl   $0x235,0x4(%esp)
  103ebd:	00 
  103ebe:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103ec5:	e8 2f c5 ff ff       	call   1003f9 <__panic>
        assert(PTE_ADDR(*ptep) == i);
  103eca:	8b 45 dc             	mov    -0x24(%ebp),%eax
  103ecd:	8b 00                	mov    (%eax),%eax
  103ecf:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  103ed4:	89 c2                	mov    %eax,%edx
  103ed6:	8b 45 f4             	mov    -0xc(%ebp),%eax
  103ed9:	39 c2                	cmp    %eax,%edx
  103edb:	74 24                	je     103f01 <check_boot_pgdir+0xd5>
  103edd:	c7 44 24 0c f5 6c 10 	movl   $0x106cf5,0xc(%esp)
  103ee4:	00 
  103ee5:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103eec:	00 
  103eed:	c7 44 24 04 36 02 00 	movl   $0x236,0x4(%esp)
  103ef4:	00 
  103ef5:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103efc:	e8 f8 c4 ff ff       	call   1003f9 <__panic>
    for (i = 0; i < npage; i += PGSIZE) {
  103f01:	81 45 f4 00 10 00 00 	addl   $0x1000,-0xc(%ebp)
  103f08:	8b 55 f4             	mov    -0xc(%ebp),%edx
  103f0b:	a1 80 be 11 00       	mov    0x11be80,%eax
  103f10:	39 c2                	cmp    %eax,%edx
  103f12:	0f 82 26 ff ff ff    	jb     103e3e <check_boot_pgdir+0x12>
    }

    assert(PDE_ADDR(boot_pgdir[PDX(VPT)]) == PADDR(boot_pgdir));
  103f18:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103f1d:	05 ac 0f 00 00       	add    $0xfac,%eax
  103f22:	8b 00                	mov    (%eax),%eax
  103f24:	25 00 f0 ff ff       	and    $0xfffff000,%eax
  103f29:	89 c2                	mov    %eax,%edx
  103f2b:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103f30:	89 45 f0             	mov    %eax,-0x10(%ebp)
  103f33:	81 7d f0 ff ff ff bf 	cmpl   $0xbfffffff,-0x10(%ebp)
  103f3a:	77 23                	ja     103f5f <check_boot_pgdir+0x133>
  103f3c:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103f3f:	89 44 24 0c          	mov    %eax,0xc(%esp)
  103f43:	c7 44 24 08 84 69 10 	movl   $0x106984,0x8(%esp)
  103f4a:	00 
  103f4b:	c7 44 24 04 39 02 00 	movl   $0x239,0x4(%esp)
  103f52:	00 
  103f53:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103f5a:	e8 9a c4 ff ff       	call   1003f9 <__panic>
  103f5f:	8b 45 f0             	mov    -0x10(%ebp),%eax
  103f62:	05 00 00 00 40       	add    $0x40000000,%eax
  103f67:	39 d0                	cmp    %edx,%eax
  103f69:	74 24                	je     103f8f <check_boot_pgdir+0x163>
  103f6b:	c7 44 24 0c 0c 6d 10 	movl   $0x106d0c,0xc(%esp)
  103f72:	00 
  103f73:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103f7a:	00 
  103f7b:	c7 44 24 04 39 02 00 	movl   $0x239,0x4(%esp)
  103f82:	00 
  103f83:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103f8a:	e8 6a c4 ff ff       	call   1003f9 <__panic>

    assert(boot_pgdir[0] == 0);
  103f8f:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103f94:	8b 00                	mov    (%eax),%eax
  103f96:	85 c0                	test   %eax,%eax
  103f98:	74 24                	je     103fbe <check_boot_pgdir+0x192>
  103f9a:	c7 44 24 0c 40 6d 10 	movl   $0x106d40,0xc(%esp)
  103fa1:	00 
  103fa2:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  103fa9:	00 
  103faa:	c7 44 24 04 3b 02 00 	movl   $0x23b,0x4(%esp)
  103fb1:	00 
  103fb2:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  103fb9:	e8 3b c4 ff ff       	call   1003f9 <__panic>

    struct Page *p;
    p = alloc_page();
  103fbe:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  103fc5:	e8 a1 ed ff ff       	call   102d6b <alloc_pages>
  103fca:	89 45 ec             	mov    %eax,-0x14(%ebp)
    assert(page_insert(boot_pgdir, p, 0x100, PTE_W) == 0);
  103fcd:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  103fd2:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
  103fd9:	00 
  103fda:	c7 44 24 08 00 01 00 	movl   $0x100,0x8(%esp)
  103fe1:	00 
  103fe2:	8b 55 ec             	mov    -0x14(%ebp),%edx
  103fe5:	89 54 24 04          	mov    %edx,0x4(%esp)
  103fe9:	89 04 24             	mov    %eax,(%esp)
  103fec:	e8 6b f6 ff ff       	call   10365c <page_insert>
  103ff1:	85 c0                	test   %eax,%eax
  103ff3:	74 24                	je     104019 <check_boot_pgdir+0x1ed>
  103ff5:	c7 44 24 0c 54 6d 10 	movl   $0x106d54,0xc(%esp)
  103ffc:	00 
  103ffd:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  104004:	00 
  104005:	c7 44 24 04 3f 02 00 	movl   $0x23f,0x4(%esp)
  10400c:	00 
  10400d:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  104014:	e8 e0 c3 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p) == 1);
  104019:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10401c:	89 04 24             	mov    %eax,(%esp)
  10401f:	e8 42 eb ff ff       	call   102b66 <page_ref>
  104024:	83 f8 01             	cmp    $0x1,%eax
  104027:	74 24                	je     10404d <check_boot_pgdir+0x221>
  104029:	c7 44 24 0c 82 6d 10 	movl   $0x106d82,0xc(%esp)
  104030:	00 
  104031:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  104038:	00 
  104039:	c7 44 24 04 40 02 00 	movl   $0x240,0x4(%esp)
  104040:	00 
  104041:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  104048:	e8 ac c3 ff ff       	call   1003f9 <__panic>
    assert(page_insert(boot_pgdir, p, 0x100 + PGSIZE, PTE_W) == 0);
  10404d:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  104052:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
  104059:	00 
  10405a:	c7 44 24 08 00 11 00 	movl   $0x1100,0x8(%esp)
  104061:	00 
  104062:	8b 55 ec             	mov    -0x14(%ebp),%edx
  104065:	89 54 24 04          	mov    %edx,0x4(%esp)
  104069:	89 04 24             	mov    %eax,(%esp)
  10406c:	e8 eb f5 ff ff       	call   10365c <page_insert>
  104071:	85 c0                	test   %eax,%eax
  104073:	74 24                	je     104099 <check_boot_pgdir+0x26d>
  104075:	c7 44 24 0c 94 6d 10 	movl   $0x106d94,0xc(%esp)
  10407c:	00 
  10407d:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  104084:	00 
  104085:	c7 44 24 04 41 02 00 	movl   $0x241,0x4(%esp)
  10408c:	00 
  10408d:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  104094:	e8 60 c3 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p) == 2);
  104099:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10409c:	89 04 24             	mov    %eax,(%esp)
  10409f:	e8 c2 ea ff ff       	call   102b66 <page_ref>
  1040a4:	83 f8 02             	cmp    $0x2,%eax
  1040a7:	74 24                	je     1040cd <check_boot_pgdir+0x2a1>
  1040a9:	c7 44 24 0c cb 6d 10 	movl   $0x106dcb,0xc(%esp)
  1040b0:	00 
  1040b1:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  1040b8:	00 
  1040b9:	c7 44 24 04 42 02 00 	movl   $0x242,0x4(%esp)
  1040c0:	00 
  1040c1:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  1040c8:	e8 2c c3 ff ff       	call   1003f9 <__panic>

    const char *str = "ucore: Hello world!!";
  1040cd:	c7 45 e8 dc 6d 10 00 	movl   $0x106ddc,-0x18(%ebp)
    strcpy((void *)0x100, str);
  1040d4:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1040d7:	89 44 24 04          	mov    %eax,0x4(%esp)
  1040db:	c7 04 24 00 01 00 00 	movl   $0x100,(%esp)
  1040e2:	e8 d3 15 00 00       	call   1056ba <strcpy>
    assert(strcmp((void *)0x100, (void *)(0x100 + PGSIZE)) == 0);
  1040e7:	c7 44 24 04 00 11 00 	movl   $0x1100,0x4(%esp)
  1040ee:	00 
  1040ef:	c7 04 24 00 01 00 00 	movl   $0x100,(%esp)
  1040f6:	e8 36 16 00 00       	call   105731 <strcmp>
  1040fb:	85 c0                	test   %eax,%eax
  1040fd:	74 24                	je     104123 <check_boot_pgdir+0x2f7>
  1040ff:	c7 44 24 0c f4 6d 10 	movl   $0x106df4,0xc(%esp)
  104106:	00 
  104107:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  10410e:	00 
  10410f:	c7 44 24 04 46 02 00 	movl   $0x246,0x4(%esp)
  104116:	00 
  104117:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  10411e:	e8 d6 c2 ff ff       	call   1003f9 <__panic>

    *(char *)(page2kva(p) + 0x100) = '\0';
  104123:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104126:	89 04 24             	mov    %eax,(%esp)
  104129:	e8 8e e9 ff ff       	call   102abc <page2kva>
  10412e:	05 00 01 00 00       	add    $0x100,%eax
  104133:	c6 00 00             	movb   $0x0,(%eax)
    assert(strlen((const char *)0x100) == 0);
  104136:	c7 04 24 00 01 00 00 	movl   $0x100,(%esp)
  10413d:	e8 22 15 00 00       	call   105664 <strlen>
  104142:	85 c0                	test   %eax,%eax
  104144:	74 24                	je     10416a <check_boot_pgdir+0x33e>
  104146:	c7 44 24 0c 2c 6e 10 	movl   $0x106e2c,0xc(%esp)
  10414d:	00 
  10414e:	c7 44 24 08 cd 69 10 	movl   $0x1069cd,0x8(%esp)
  104155:	00 
  104156:	c7 44 24 04 49 02 00 	movl   $0x249,0x4(%esp)
  10415d:	00 
  10415e:	c7 04 24 a8 69 10 00 	movl   $0x1069a8,(%esp)
  104165:	e8 8f c2 ff ff       	call   1003f9 <__panic>

    free_page(p);
  10416a:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104171:	00 
  104172:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104175:	89 04 24             	mov    %eax,(%esp)
  104178:	e8 26 ec ff ff       	call   102da3 <free_pages>
    free_page(pde2page(boot_pgdir[0]));
  10417d:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  104182:	8b 00                	mov    (%eax),%eax
  104184:	89 04 24             	mov    %eax,(%esp)
  104187:	e8 c2 e9 ff ff       	call   102b4e <pde2page>
  10418c:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104193:	00 
  104194:	89 04 24             	mov    %eax,(%esp)
  104197:	e8 07 ec ff ff       	call   102da3 <free_pages>
    boot_pgdir[0] = 0;
  10419c:	a1 e0 89 11 00       	mov    0x1189e0,%eax
  1041a1:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

    cprintf("check_boot_pgdir() succeeded!\n");
  1041a7:	c7 04 24 50 6e 10 00 	movl   $0x106e50,(%esp)
  1041ae:	e8 ef c0 ff ff       	call   1002a2 <cprintf>
}
  1041b3:	90                   	nop
  1041b4:	c9                   	leave  
  1041b5:	c3                   	ret    

001041b6 <perm2str>:

//perm2str - use string 'u,r,w,-' to present the permission
static const char *
perm2str(int perm) {
  1041b6:	55                   	push   %ebp
  1041b7:	89 e5                	mov    %esp,%ebp
    static char str[4];
    str[0] = (perm & PTE_U) ? 'u' : '-';
  1041b9:	8b 45 08             	mov    0x8(%ebp),%eax
  1041bc:	83 e0 04             	and    $0x4,%eax
  1041bf:	85 c0                	test   %eax,%eax
  1041c1:	74 04                	je     1041c7 <perm2str+0x11>
  1041c3:	b0 75                	mov    $0x75,%al
  1041c5:	eb 02                	jmp    1041c9 <perm2str+0x13>
  1041c7:	b0 2d                	mov    $0x2d,%al
  1041c9:	a2 08 bf 11 00       	mov    %al,0x11bf08
    str[1] = 'r';
  1041ce:	c6 05 09 bf 11 00 72 	movb   $0x72,0x11bf09
    str[2] = (perm & PTE_W) ? 'w' : '-';
  1041d5:	8b 45 08             	mov    0x8(%ebp),%eax
  1041d8:	83 e0 02             	and    $0x2,%eax
  1041db:	85 c0                	test   %eax,%eax
  1041dd:	74 04                	je     1041e3 <perm2str+0x2d>
  1041df:	b0 77                	mov    $0x77,%al
  1041e1:	eb 02                	jmp    1041e5 <perm2str+0x2f>
  1041e3:	b0 2d                	mov    $0x2d,%al
  1041e5:	a2 0a bf 11 00       	mov    %al,0x11bf0a
    str[3] = '\0';
  1041ea:	c6 05 0b bf 11 00 00 	movb   $0x0,0x11bf0b
    return str;
  1041f1:	b8 08 bf 11 00       	mov    $0x11bf08,%eax
}
  1041f6:	5d                   	pop    %ebp
  1041f7:	c3                   	ret    

001041f8 <get_pgtable_items>:
//  table:       the beginning addr of table
//  left_store:  the pointer of the high side of table's next range
//  right_store: the pointer of the low side of table's next range
// return value: 0 - not a invalid item range, perm - a valid item range with perm permission 
static int
get_pgtable_items(size_t left, size_t right, size_t start, uintptr_t *table, size_t *left_store, size_t *right_store) {
  1041f8:	55                   	push   %ebp
  1041f9:	89 e5                	mov    %esp,%ebp
  1041fb:	83 ec 10             	sub    $0x10,%esp
    if (start >= right) {
  1041fe:	8b 45 10             	mov    0x10(%ebp),%eax
  104201:	3b 45 0c             	cmp    0xc(%ebp),%eax
  104204:	72 0d                	jb     104213 <get_pgtable_items+0x1b>
        return 0;
  104206:	b8 00 00 00 00       	mov    $0x0,%eax
  10420b:	e9 98 00 00 00       	jmp    1042a8 <get_pgtable_items+0xb0>
    }
    while (start < right && !(table[start] & PTE_P)) {
        start ++;
  104210:	ff 45 10             	incl   0x10(%ebp)
    while (start < right && !(table[start] & PTE_P)) {
  104213:	8b 45 10             	mov    0x10(%ebp),%eax
  104216:	3b 45 0c             	cmp    0xc(%ebp),%eax
  104219:	73 18                	jae    104233 <get_pgtable_items+0x3b>
  10421b:	8b 45 10             	mov    0x10(%ebp),%eax
  10421e:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
  104225:	8b 45 14             	mov    0x14(%ebp),%eax
  104228:	01 d0                	add    %edx,%eax
  10422a:	8b 00                	mov    (%eax),%eax
  10422c:	83 e0 01             	and    $0x1,%eax
  10422f:	85 c0                	test   %eax,%eax
  104231:	74 dd                	je     104210 <get_pgtable_items+0x18>
    }
    if (start < right) {
  104233:	8b 45 10             	mov    0x10(%ebp),%eax
  104236:	3b 45 0c             	cmp    0xc(%ebp),%eax
  104239:	73 68                	jae    1042a3 <get_pgtable_items+0xab>
        if (left_store != NULL) {
  10423b:	83 7d 18 00          	cmpl   $0x0,0x18(%ebp)
  10423f:	74 08                	je     104249 <get_pgtable_items+0x51>
            *left_store = start;
  104241:	8b 45 18             	mov    0x18(%ebp),%eax
  104244:	8b 55 10             	mov    0x10(%ebp),%edx
  104247:	89 10                	mov    %edx,(%eax)
        }
        int perm = (table[start ++] & PTE_USER);
  104249:	8b 45 10             	mov    0x10(%ebp),%eax
  10424c:	8d 50 01             	lea    0x1(%eax),%edx
  10424f:	89 55 10             	mov    %edx,0x10(%ebp)
  104252:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
  104259:	8b 45 14             	mov    0x14(%ebp),%eax
  10425c:	01 d0                	add    %edx,%eax
  10425e:	8b 00                	mov    (%eax),%eax
  104260:	83 e0 07             	and    $0x7,%eax
  104263:	89 45 fc             	mov    %eax,-0x4(%ebp)
        while (start < right && (table[start] & PTE_USER) == perm) {
  104266:	eb 03                	jmp    10426b <get_pgtable_items+0x73>
            start ++;
  104268:	ff 45 10             	incl   0x10(%ebp)
        while (start < right && (table[start] & PTE_USER) == perm) {
  10426b:	8b 45 10             	mov    0x10(%ebp),%eax
  10426e:	3b 45 0c             	cmp    0xc(%ebp),%eax
  104271:	73 1d                	jae    104290 <get_pgtable_items+0x98>
  104273:	8b 45 10             	mov    0x10(%ebp),%eax
  104276:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
  10427d:	8b 45 14             	mov    0x14(%ebp),%eax
  104280:	01 d0                	add    %edx,%eax
  104282:	8b 00                	mov    (%eax),%eax
  104284:	83 e0 07             	and    $0x7,%eax
  104287:	89 c2                	mov    %eax,%edx
  104289:	8b 45 fc             	mov    -0x4(%ebp),%eax
  10428c:	39 c2                	cmp    %eax,%edx
  10428e:	74 d8                	je     104268 <get_pgtable_items+0x70>
        }
        if (right_store != NULL) {
  104290:	83 7d 1c 00          	cmpl   $0x0,0x1c(%ebp)
  104294:	74 08                	je     10429e <get_pgtable_items+0xa6>
            *right_store = start;
  104296:	8b 45 1c             	mov    0x1c(%ebp),%eax
  104299:	8b 55 10             	mov    0x10(%ebp),%edx
  10429c:	89 10                	mov    %edx,(%eax)
        }
        return perm;
  10429e:	8b 45 fc             	mov    -0x4(%ebp),%eax
  1042a1:	eb 05                	jmp    1042a8 <get_pgtable_items+0xb0>
    }
    return 0;
  1042a3:	b8 00 00 00 00       	mov    $0x0,%eax
}
  1042a8:	c9                   	leave  
  1042a9:	c3                   	ret    

001042aa <print_pgdir>:

//print_pgdir - print the PDT&PT
void
print_pgdir(void) {
  1042aa:	55                   	push   %ebp
  1042ab:	89 e5                	mov    %esp,%ebp
  1042ad:	57                   	push   %edi
  1042ae:	56                   	push   %esi
  1042af:	53                   	push   %ebx
  1042b0:	83 ec 4c             	sub    $0x4c,%esp
    cprintf("-------------------- BEGIN --------------------\n");
  1042b3:	c7 04 24 70 6e 10 00 	movl   $0x106e70,(%esp)
  1042ba:	e8 e3 bf ff ff       	call   1002a2 <cprintf>
    size_t left, right = 0, perm;
  1042bf:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
    while ((perm = get_pgtable_items(0, NPDEENTRY, right, vpd, &left, &right)) != 0) {
  1042c6:	e9 fa 00 00 00       	jmp    1043c5 <print_pgdir+0x11b>
        cprintf("PDE(%03x) %08x-%08x %08x %s\n", right - left,
  1042cb:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  1042ce:	89 04 24             	mov    %eax,(%esp)
  1042d1:	e8 e0 fe ff ff       	call   1041b6 <perm2str>
                left * PTSIZE, right * PTSIZE, (right - left) * PTSIZE, perm2str(perm));
  1042d6:	8b 4d dc             	mov    -0x24(%ebp),%ecx
  1042d9:	8b 55 e0             	mov    -0x20(%ebp),%edx
  1042dc:	29 d1                	sub    %edx,%ecx
  1042de:	89 ca                	mov    %ecx,%edx
        cprintf("PDE(%03x) %08x-%08x %08x %s\n", right - left,
  1042e0:	89 d6                	mov    %edx,%esi
  1042e2:	c1 e6 16             	shl    $0x16,%esi
  1042e5:	8b 55 dc             	mov    -0x24(%ebp),%edx
  1042e8:	89 d3                	mov    %edx,%ebx
  1042ea:	c1 e3 16             	shl    $0x16,%ebx
  1042ed:	8b 55 e0             	mov    -0x20(%ebp),%edx
  1042f0:	89 d1                	mov    %edx,%ecx
  1042f2:	c1 e1 16             	shl    $0x16,%ecx
  1042f5:	8b 7d dc             	mov    -0x24(%ebp),%edi
  1042f8:	8b 55 e0             	mov    -0x20(%ebp),%edx
  1042fb:	29 d7                	sub    %edx,%edi
  1042fd:	89 fa                	mov    %edi,%edx
  1042ff:	89 44 24 14          	mov    %eax,0x14(%esp)
  104303:	89 74 24 10          	mov    %esi,0x10(%esp)
  104307:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
  10430b:	89 4c 24 08          	mov    %ecx,0x8(%esp)
  10430f:	89 54 24 04          	mov    %edx,0x4(%esp)
  104313:	c7 04 24 a1 6e 10 00 	movl   $0x106ea1,(%esp)
  10431a:	e8 83 bf ff ff       	call   1002a2 <cprintf>
        size_t l, r = left * NPTEENTRY;
  10431f:	8b 45 e0             	mov    -0x20(%ebp),%eax
  104322:	c1 e0 0a             	shl    $0xa,%eax
  104325:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        while ((perm = get_pgtable_items(left * NPTEENTRY, right * NPTEENTRY, r, vpt, &l, &r)) != 0) {
  104328:	eb 54                	jmp    10437e <print_pgdir+0xd4>
            cprintf("  |-- PTE(%05x) %08x-%08x %08x %s\n", r - l,
  10432a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  10432d:	89 04 24             	mov    %eax,(%esp)
  104330:	e8 81 fe ff ff       	call   1041b6 <perm2str>
                    l * PGSIZE, r * PGSIZE, (r - l) * PGSIZE, perm2str(perm));
  104335:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
  104338:	8b 55 d8             	mov    -0x28(%ebp),%edx
  10433b:	29 d1                	sub    %edx,%ecx
  10433d:	89 ca                	mov    %ecx,%edx
            cprintf("  |-- PTE(%05x) %08x-%08x %08x %s\n", r - l,
  10433f:	89 d6                	mov    %edx,%esi
  104341:	c1 e6 0c             	shl    $0xc,%esi
  104344:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  104347:	89 d3                	mov    %edx,%ebx
  104349:	c1 e3 0c             	shl    $0xc,%ebx
  10434c:	8b 55 d8             	mov    -0x28(%ebp),%edx
  10434f:	89 d1                	mov    %edx,%ecx
  104351:	c1 e1 0c             	shl    $0xc,%ecx
  104354:	8b 7d d4             	mov    -0x2c(%ebp),%edi
  104357:	8b 55 d8             	mov    -0x28(%ebp),%edx
  10435a:	29 d7                	sub    %edx,%edi
  10435c:	89 fa                	mov    %edi,%edx
  10435e:	89 44 24 14          	mov    %eax,0x14(%esp)
  104362:	89 74 24 10          	mov    %esi,0x10(%esp)
  104366:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
  10436a:	89 4c 24 08          	mov    %ecx,0x8(%esp)
  10436e:	89 54 24 04          	mov    %edx,0x4(%esp)
  104372:	c7 04 24 c0 6e 10 00 	movl   $0x106ec0,(%esp)
  104379:	e8 24 bf ff ff       	call   1002a2 <cprintf>
        while ((perm = get_pgtable_items(left * NPTEENTRY, right * NPTEENTRY, r, vpt, &l, &r)) != 0) {
  10437e:	be 00 00 c0 fa       	mov    $0xfac00000,%esi
  104383:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  104386:	8b 55 dc             	mov    -0x24(%ebp),%edx
  104389:	89 d3                	mov    %edx,%ebx
  10438b:	c1 e3 0a             	shl    $0xa,%ebx
  10438e:	8b 55 e0             	mov    -0x20(%ebp),%edx
  104391:	89 d1                	mov    %edx,%ecx
  104393:	c1 e1 0a             	shl    $0xa,%ecx
  104396:	8d 55 d4             	lea    -0x2c(%ebp),%edx
  104399:	89 54 24 14          	mov    %edx,0x14(%esp)
  10439d:	8d 55 d8             	lea    -0x28(%ebp),%edx
  1043a0:	89 54 24 10          	mov    %edx,0x10(%esp)
  1043a4:	89 74 24 0c          	mov    %esi,0xc(%esp)
  1043a8:	89 44 24 08          	mov    %eax,0x8(%esp)
  1043ac:	89 5c 24 04          	mov    %ebx,0x4(%esp)
  1043b0:	89 0c 24             	mov    %ecx,(%esp)
  1043b3:	e8 40 fe ff ff       	call   1041f8 <get_pgtable_items>
  1043b8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  1043bb:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
  1043bf:	0f 85 65 ff ff ff    	jne    10432a <print_pgdir+0x80>
    while ((perm = get_pgtable_items(0, NPDEENTRY, right, vpd, &left, &right)) != 0) {
  1043c5:	b9 00 b0 fe fa       	mov    $0xfafeb000,%ecx
  1043ca:	8b 45 dc             	mov    -0x24(%ebp),%eax
  1043cd:	8d 55 dc             	lea    -0x24(%ebp),%edx
  1043d0:	89 54 24 14          	mov    %edx,0x14(%esp)
  1043d4:	8d 55 e0             	lea    -0x20(%ebp),%edx
  1043d7:	89 54 24 10          	mov    %edx,0x10(%esp)
  1043db:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
  1043df:	89 44 24 08          	mov    %eax,0x8(%esp)
  1043e3:	c7 44 24 04 00 04 00 	movl   $0x400,0x4(%esp)
  1043ea:	00 
  1043eb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
  1043f2:	e8 01 fe ff ff       	call   1041f8 <get_pgtable_items>
  1043f7:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  1043fa:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
  1043fe:	0f 85 c7 fe ff ff    	jne    1042cb <print_pgdir+0x21>
        }
    }
    cprintf("--------------------- END ---------------------\n");
  104404:	c7 04 24 e4 6e 10 00 	movl   $0x106ee4,(%esp)
  10440b:	e8 92 be ff ff       	call   1002a2 <cprintf>
}
  104410:	90                   	nop
  104411:	83 c4 4c             	add    $0x4c,%esp
  104414:	5b                   	pop    %ebx
  104415:	5e                   	pop    %esi
  104416:	5f                   	pop    %edi
  104417:	5d                   	pop    %ebp
  104418:	c3                   	ret    

00104419 <page2ppn>:
page2ppn(struct Page *page) {
  104419:	55                   	push   %ebp
  10441a:	89 e5                	mov    %esp,%ebp
    return page - pages;
  10441c:	8b 45 08             	mov    0x8(%ebp),%eax
  10441f:	8b 15 78 bf 11 00    	mov    0x11bf78,%edx
  104425:	29 d0                	sub    %edx,%eax
  104427:	c1 f8 02             	sar    $0x2,%eax
  10442a:	69 c0 cd cc cc cc    	imul   $0xcccccccd,%eax,%eax
}
  104430:	5d                   	pop    %ebp
  104431:	c3                   	ret    

00104432 <page2pa>:
page2pa(struct Page *page) {
  104432:	55                   	push   %ebp
  104433:	89 e5                	mov    %esp,%ebp
  104435:	83 ec 04             	sub    $0x4,%esp
    return page2ppn(page) << PGSHIFT;
  104438:	8b 45 08             	mov    0x8(%ebp),%eax
  10443b:	89 04 24             	mov    %eax,(%esp)
  10443e:	e8 d6 ff ff ff       	call   104419 <page2ppn>
  104443:	c1 e0 0c             	shl    $0xc,%eax
}
  104446:	c9                   	leave  
  104447:	c3                   	ret    

00104448 <page_ref>:
page_ref(struct Page *page) {
  104448:	55                   	push   %ebp
  104449:	89 e5                	mov    %esp,%ebp
    return page->ref;
  10444b:	8b 45 08             	mov    0x8(%ebp),%eax
  10444e:	8b 00                	mov    (%eax),%eax
}
  104450:	5d                   	pop    %ebp
  104451:	c3                   	ret    

00104452 <set_page_ref>:
set_page_ref(struct Page *page, int val) {
  104452:	55                   	push   %ebp
  104453:	89 e5                	mov    %esp,%ebp
    page->ref = val;
  104455:	8b 45 08             	mov    0x8(%ebp),%eax
  104458:	8b 55 0c             	mov    0xc(%ebp),%edx
  10445b:	89 10                	mov    %edx,(%eax)
}
  10445d:	90                   	nop
  10445e:	5d                   	pop    %ebp
  10445f:	c3                   	ret    

00104460 <default_init>:

#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

static void
default_init(void) {
  104460:	55                   	push   %ebp
  104461:	89 e5                	mov    %esp,%ebp
  104463:	83 ec 10             	sub    $0x10,%esp
  104466:	c7 45 fc 7c bf 11 00 	movl   $0x11bf7c,-0x4(%ebp)
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
  10446d:	8b 45 fc             	mov    -0x4(%ebp),%eax
  104470:	8b 55 fc             	mov    -0x4(%ebp),%edx
  104473:	89 50 04             	mov    %edx,0x4(%eax)
  104476:	8b 45 fc             	mov    -0x4(%ebp),%eax
  104479:	8b 50 04             	mov    0x4(%eax),%edx
  10447c:	8b 45 fc             	mov    -0x4(%ebp),%eax
  10447f:	89 10                	mov    %edx,(%eax)
    list_init(&free_list);
    nr_free = 0;
  104481:	c7 05 84 bf 11 00 00 	movl   $0x0,0x11bf84
  104488:	00 00 00 
}
  10448b:	90                   	nop
  10448c:	c9                   	leave  
  10448d:	c3                   	ret    

0010448e <default_init_memmap>:
// 2、将其连续空页数量设置为0，即p->property。
//3、映射到此物理页的虚拟页数量置为0，调用set_page_ref函数
//4、插入到双向链表中，free_list因为宏定义的原因，指的是free_area_t中的list结构。
//5、基地址连续空闲页数量加n，且空闲页数量加n。
static void
default_init_memmap(struct Page *base, size_t n) {
  10448e:	55                   	push   %ebp
  10448f:	89 e5                	mov    %esp,%ebp
  104491:	83 ec 48             	sub    $0x48,%esp
    assert(n > 0);
  104494:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
  104498:	75 24                	jne    1044be <default_init_memmap+0x30>
  10449a:	c7 44 24 0c 18 6f 10 	movl   $0x106f18,0xc(%esp)
  1044a1:	00 
  1044a2:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1044a9:	00 
  1044aa:	c7 44 24 04 7b 00 00 	movl   $0x7b,0x4(%esp)
  1044b1:	00 
  1044b2:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1044b9:	e8 3b bf ff ff       	call   1003f9 <__panic>
    struct Page *p = base;
  1044be:	8b 45 08             	mov    0x8(%ebp),%eax
  1044c1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    for (; p != base + n; p ++) {
  1044c4:	eb 7d                	jmp    104543 <default_init_memmap+0xb5>
        assert(PageReserved(p));
  1044c6:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1044c9:	83 c0 04             	add    $0x4,%eax
  1044cc:	c7 45 f0 00 00 00 00 	movl   $0x0,-0x10(%ebp)
  1044d3:	89 45 ec             	mov    %eax,-0x14(%ebp)
 * @addr:   the address to count from
 * */
static inline bool
test_bit(int nr, volatile void *addr) {
    int oldbit;
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  1044d6:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1044d9:	8b 55 f0             	mov    -0x10(%ebp),%edx
  1044dc:	0f a3 10             	bt     %edx,(%eax)
  1044df:	19 c0                	sbb    %eax,%eax
  1044e1:	89 45 e8             	mov    %eax,-0x18(%ebp)
    return oldbit != 0;
  1044e4:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  1044e8:	0f 95 c0             	setne  %al
  1044eb:	0f b6 c0             	movzbl %al,%eax
  1044ee:	85 c0                	test   %eax,%eax
  1044f0:	75 24                	jne    104516 <default_init_memmap+0x88>
  1044f2:	c7 44 24 0c 49 6f 10 	movl   $0x106f49,0xc(%esp)
  1044f9:	00 
  1044fa:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104501:	00 
  104502:	c7 44 24 04 7e 00 00 	movl   $0x7e,0x4(%esp)
  104509:	00 
  10450a:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104511:	e8 e3 be ff ff       	call   1003f9 <__panic>
        p->flags = p->property = 0;
  104516:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104519:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
  104520:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104523:	8b 50 08             	mov    0x8(%eax),%edx
  104526:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104529:	89 50 04             	mov    %edx,0x4(%eax)
        set_page_ref(p, 0);
  10452c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  104533:	00 
  104534:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104537:	89 04 24             	mov    %eax,(%esp)
  10453a:	e8 13 ff ff ff       	call   104452 <set_page_ref>
    for (; p != base + n; p ++) {
  10453f:	83 45 f4 14          	addl   $0x14,-0xc(%ebp)
  104543:	8b 55 0c             	mov    0xc(%ebp),%edx
  104546:	89 d0                	mov    %edx,%eax
  104548:	c1 e0 02             	shl    $0x2,%eax
  10454b:	01 d0                	add    %edx,%eax
  10454d:	c1 e0 02             	shl    $0x2,%eax
  104550:	89 c2                	mov    %eax,%edx
  104552:	8b 45 08             	mov    0x8(%ebp),%eax
  104555:	01 d0                	add    %edx,%eax
  104557:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  10455a:	0f 85 66 ff ff ff    	jne    1044c6 <default_init_memmap+0x38>
    }
    base->property = n;
  104560:	8b 45 08             	mov    0x8(%ebp),%eax
  104563:	8b 55 0c             	mov    0xc(%ebp),%edx
  104566:	89 50 08             	mov    %edx,0x8(%eax)
    SetPageProperty(base);
  104569:	8b 45 08             	mov    0x8(%ebp),%eax
  10456c:	83 c0 04             	add    $0x4,%eax
  10456f:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
  104576:	89 45 cc             	mov    %eax,-0x34(%ebp)
    asm volatile ("btsl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
  104579:	8b 45 cc             	mov    -0x34(%ebp),%eax
  10457c:	8b 55 d0             	mov    -0x30(%ebp),%edx
  10457f:	0f ab 10             	bts    %edx,(%eax)
    nr_free += n;
  104582:	8b 15 84 bf 11 00    	mov    0x11bf84,%edx
  104588:	8b 45 0c             	mov    0xc(%ebp),%eax
  10458b:	01 d0                	add    %edx,%eax
  10458d:	a3 84 bf 11 00       	mov    %eax,0x11bf84
    //下面这句要从list_add改成list_add_before
    list_add_before(&free_list, &(base->page_link));
  104592:	8b 45 08             	mov    0x8(%ebp),%eax
  104595:	83 c0 0c             	add    $0xc,%eax
  104598:	c7 45 e4 7c bf 11 00 	movl   $0x11bf7c,-0x1c(%ebp)
  10459f:	89 45 e0             	mov    %eax,-0x20(%ebp)
 * Insert the new element @elm *before* the element @listelm which
 * is already in the list.
 * */
static inline void
list_add_before(list_entry_t *listelm, list_entry_t *elm) {
    __list_add(elm, listelm->prev, listelm);
  1045a2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  1045a5:	8b 00                	mov    (%eax),%eax
  1045a7:	8b 55 e0             	mov    -0x20(%ebp),%edx
  1045aa:	89 55 dc             	mov    %edx,-0x24(%ebp)
  1045ad:	89 45 d8             	mov    %eax,-0x28(%ebp)
  1045b0:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  1045b3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
  1045b6:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  1045b9:	8b 55 dc             	mov    -0x24(%ebp),%edx
  1045bc:	89 10                	mov    %edx,(%eax)
  1045be:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  1045c1:	8b 10                	mov    (%eax),%edx
  1045c3:	8b 45 d8             	mov    -0x28(%ebp),%eax
  1045c6:	89 50 04             	mov    %edx,0x4(%eax)
    elm->next = next;
  1045c9:	8b 45 dc             	mov    -0x24(%ebp),%eax
  1045cc:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  1045cf:	89 50 04             	mov    %edx,0x4(%eax)
    elm->prev = prev;
  1045d2:	8b 45 dc             	mov    -0x24(%ebp),%eax
  1045d5:	8b 55 d8             	mov    -0x28(%ebp),%edx
  1045d8:	89 10                	mov    %edx,(%eax)
}
  1045da:	90                   	nop
  1045db:	c9                   	leave  
  1045dc:	c3                   	ret    

001045dd <default_alloc_pages>:
//firstfit需要从空闲链表头开始查找最小的地址，通过list_next找到下一个空闲块元素，
//通过le2page宏可以由链表元素获得对应的Page指针p。通过p->property可以了解此空闲块的大小。
//如果>=n，这就找到了！如果<n，则list_next，继续查找。直到list_next== &free_list，这表示找完了一遍了。
//找到后，就要从新组织空闲块，然后把找到的page返回。
static struct Page *
default_alloc_pages(size_t n) {//参数n表示要分配n个页
  1045dd:	55                   	push   %ebp
  1045de:	89 e5                	mov    %esp,%ebp
  1045e0:	83 ec 68             	sub    $0x68,%esp
    assert(n > 0);
  1045e3:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
  1045e7:	75 24                	jne    10460d <default_alloc_pages+0x30>
  1045e9:	c7 44 24 0c 18 6f 10 	movl   $0x106f18,0xc(%esp)
  1045f0:	00 
  1045f1:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1045f8:	00 
  1045f9:	c7 44 24 04 8f 00 00 	movl   $0x8f,0x4(%esp)
  104600:	00 
  104601:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104608:	e8 ec bd ff ff       	call   1003f9 <__panic>
    if (n > nr_free) {  //首先判断空闲页的大小是否大于所需的页块大小。 如果需要分配的页面数量n，已经大于了空闲页的数量，那么直接return NULL分配失败。
  10460d:	a1 84 bf 11 00       	mov    0x11bf84,%eax
  104612:	39 45 08             	cmp    %eax,0x8(%ebp)
  104615:	76 0a                	jbe    104621 <default_alloc_pages+0x44>
        return NULL;
  104617:	b8 00 00 00 00       	mov    $0x0,%eax
  10461c:	e9 3b 01 00 00       	jmp    10475c <default_alloc_pages+0x17f>
    }
    struct Page *page = NULL;
  104621:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    list_entry_t *le = &free_list;
  104628:	c7 45 f0 7c bf 11 00 	movl   $0x11bf7c,-0x10(%ebp)
    while ((le = list_next(le)) != &free_list) { //search the free list  寻找一个可分配的连续页
  10462f:	eb 1c                	jmp    10464d <default_alloc_pages+0x70>
        //遍历整个空闲链表。如果找到合适的空闲页，即p->property >= n（从该页开始，连续的空闲页数量大于n），
        //即可认为可分配，重新设置标志位。具体操作是调用SetPageReserved(pp)和ClearPageProperty(pp)，
        //设置当前页面预留，以及清空该页面的连续空闲页面数量值。
        struct Page *p = le2page(le, page_link);
  104631:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104634:	83 e8 0c             	sub    $0xc,%eax
  104637:	89 45 ec             	mov    %eax,-0x14(%ebp)
        if (p->property >= n) { // If we find this `p`, it means we've found a free block with its size>= n, whose first `n` pages can be malloced
  10463a:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10463d:	8b 40 08             	mov    0x8(%eax),%eax
  104640:	39 45 08             	cmp    %eax,0x8(%ebp)
  104643:	77 08                	ja     10464d <default_alloc_pages+0x70>
            page = p;  
  104645:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104648:	89 45 f4             	mov    %eax,-0xc(%ebp)
            break;
  10464b:	eb 18                	jmp    104665 <default_alloc_pages+0x88>
  10464d:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104650:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    return listelm->next;
  104653:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  104656:	8b 40 04             	mov    0x4(%eax),%eax
    while ((le = list_next(le)) != &free_list) { //search the free list  寻找一个可分配的连续页
  104659:	89 45 f0             	mov    %eax,-0x10(%ebp)
  10465c:	81 7d f0 7c bf 11 00 	cmpl   $0x11bf7c,-0x10(%ebp)
  104663:	75 cc                	jne    104631 <default_alloc_pages+0x54>
        }
    }
    if (page != NULL) { //若找到了空闲的页 `PG_reserved = 1`, `PG_property = 0`.，将这个页从free_list中卸下
  104665:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  104669:	0f 84 ea 00 00 00    	je     104759 <default_alloc_pages+0x17c>
    //如果当前空闲页的大小大于所需大小。则分割页块。具体操作就是，刚刚分配了n个页，如果分配完了，
    //还有连续的空间，则在最后分配的那个页的下一个页（未分配），更新它的连续空闲页值。如果正好合适，则不进行操作。
        if (page->property > n) { //重新计算剩余空闲页的数量
  10466f:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104672:	8b 40 08             	mov    0x8(%eax),%eax
  104675:	39 45 08             	cmp    %eax,0x8(%ebp)
  104678:	0f 83 8a 00 00 00    	jae    104708 <default_alloc_pages+0x12b>
            struct Page *p = page + n;
  10467e:	8b 55 08             	mov    0x8(%ebp),%edx
  104681:	89 d0                	mov    %edx,%eax
  104683:	c1 e0 02             	shl    $0x2,%eax
  104686:	01 d0                	add    %edx,%eax
  104688:	c1 e0 02             	shl    $0x2,%eax
  10468b:	89 c2                	mov    %eax,%edx
  10468d:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104690:	01 d0                	add    %edx,%eax
  104692:	89 45 e8             	mov    %eax,-0x18(%ebp)
            p->property = page->property - n;
  104695:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104698:	8b 40 08             	mov    0x8(%eax),%eax
  10469b:	2b 45 08             	sub    0x8(%ebp),%eax
  10469e:	89 c2                	mov    %eax,%edx
  1046a0:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1046a3:	89 50 08             	mov    %edx,0x8(%eax)
            //要加上下面这句
            SetPageProperty(p);
  1046a6:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1046a9:	83 c0 04             	add    $0x4,%eax
  1046ac:	c7 45 cc 01 00 00 00 	movl   $0x1,-0x34(%ebp)
  1046b3:	89 45 c8             	mov    %eax,-0x38(%ebp)
  1046b6:	8b 45 c8             	mov    -0x38(%ebp),%eax
  1046b9:	8b 55 cc             	mov    -0x34(%ebp),%edx
  1046bc:	0f ab 10             	bts    %edx,(%eax)
            //要把 list_add改成 list_add_after
            list_add_after(&free_list, &(p->page_link));
  1046bf:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1046c2:	83 c0 0c             	add    $0xc,%eax
  1046c5:	c7 45 e0 7c bf 11 00 	movl   $0x11bf7c,-0x20(%ebp)
  1046cc:	89 45 dc             	mov    %eax,-0x24(%ebp)
    __list_add(elm, listelm, listelm->next);
  1046cf:	8b 45 e0             	mov    -0x20(%ebp),%eax
  1046d2:	8b 40 04             	mov    0x4(%eax),%eax
  1046d5:	8b 55 dc             	mov    -0x24(%ebp),%edx
  1046d8:	89 55 d8             	mov    %edx,-0x28(%ebp)
  1046db:	8b 55 e0             	mov    -0x20(%ebp),%edx
  1046de:	89 55 d4             	mov    %edx,-0x2c(%ebp)
  1046e1:	89 45 d0             	mov    %eax,-0x30(%ebp)
    prev->next = next->prev = elm;
  1046e4:	8b 45 d0             	mov    -0x30(%ebp),%eax
  1046e7:	8b 55 d8             	mov    -0x28(%ebp),%edx
  1046ea:	89 10                	mov    %edx,(%eax)
  1046ec:	8b 45 d0             	mov    -0x30(%ebp),%eax
  1046ef:	8b 10                	mov    (%eax),%edx
  1046f1:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  1046f4:	89 50 04             	mov    %edx,0x4(%eax)
    elm->next = next;
  1046f7:	8b 45 d8             	mov    -0x28(%ebp),%eax
  1046fa:	8b 55 d0             	mov    -0x30(%ebp),%edx
  1046fd:	89 50 04             	mov    %edx,0x4(%eax)
    elm->prev = prev;
  104700:	8b 45 d8             	mov    -0x28(%ebp),%eax
  104703:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  104706:	89 10                	mov    %edx,(%eax)
        }
        list_del(&(page->page_link));
  104708:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10470b:	83 c0 0c             	add    $0xc,%eax
  10470e:	89 45 bc             	mov    %eax,-0x44(%ebp)
    __list_del(listelm->prev, listelm->next);
  104711:	8b 45 bc             	mov    -0x44(%ebp),%eax
  104714:	8b 40 04             	mov    0x4(%eax),%eax
  104717:	8b 55 bc             	mov    -0x44(%ebp),%edx
  10471a:	8b 12                	mov    (%edx),%edx
  10471c:	89 55 b8             	mov    %edx,-0x48(%ebp)
  10471f:	89 45 b4             	mov    %eax,-0x4c(%ebp)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
  104722:	8b 45 b8             	mov    -0x48(%ebp),%eax
  104725:	8b 55 b4             	mov    -0x4c(%ebp),%edx
  104728:	89 50 04             	mov    %edx,0x4(%eax)
    next->prev = prev;
  10472b:	8b 45 b4             	mov    -0x4c(%ebp),%eax
  10472e:	8b 55 b8             	mov    -0x48(%ebp),%edx
  104731:	89 10                	mov    %edx,(%eax)
        nr_free -= n;  //Re-caluclate `nr_free` (number of the the rest of all free block).
  104733:	a1 84 bf 11 00       	mov    0x11bf84,%eax
  104738:	2b 45 08             	sub    0x8(%ebp),%eax
  10473b:	a3 84 bf 11 00       	mov    %eax,0x11bf84
        ClearPageProperty(page);
  104740:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104743:	83 c0 04             	add    $0x4,%eax
  104746:	c7 45 c4 01 00 00 00 	movl   $0x1,-0x3c(%ebp)
  10474d:	89 45 c0             	mov    %eax,-0x40(%ebp)
    asm volatile ("btrl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
  104750:	8b 45 c0             	mov    -0x40(%ebp),%eax
  104753:	8b 55 c4             	mov    -0x3c(%ebp),%edx
  104756:	0f b3 10             	btr    %edx,(%eax)
    }
    return page;
  104759:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  10475c:	c9                   	leave  
  10475d:	c3                   	ret    

0010475e <default_free_pages>:

//default_free_pages函数的实现其实是default_alloc_pages的逆过程，不过需要考虑空闲块的合并问题
// re-link the pages into the free list, and may merge small free blocks into the big ones.
static void
default_free_pages(struct Page *base, size_t n) {
  10475e:	55                   	push   %ebp
  10475f:	89 e5                	mov    %esp,%ebp
  104761:	81 ec 98 00 00 00    	sub    $0x98,%esp
    assert(n > 0);
  104767:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
  10476b:	75 24                	jne    104791 <default_free_pages+0x33>
  10476d:	c7 44 24 0c 18 6f 10 	movl   $0x106f18,0xc(%esp)
  104774:	00 
  104775:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  10477c:	00 
  10477d:	c7 44 24 04 b5 00 00 	movl   $0xb5,0x4(%esp)
  104784:	00 
  104785:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  10478c:	e8 68 bc ff ff       	call   1003f9 <__panic>
    struct Page *p = base;
  104791:	8b 45 08             	mov    0x8(%ebp),%eax
  104794:	89 45 f4             	mov    %eax,-0xc(%ebp)
    for (; p != base + n; p ++) { // According to the base address of the withdrawed blocks, search the free
  104797:	e9 9d 00 00 00       	jmp    104839 <default_free_pages+0xdb>
                                                        // list for its correct position (with address from low to high), and insert the pages.
        assert(!PageReserved(p) && !PageProperty(p));
  10479c:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10479f:	83 c0 04             	add    $0x4,%eax
  1047a2:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
  1047a9:	89 45 e8             	mov    %eax,-0x18(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  1047ac:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1047af:	8b 55 ec             	mov    -0x14(%ebp),%edx
  1047b2:	0f a3 10             	bt     %edx,(%eax)
  1047b5:	19 c0                	sbb    %eax,%eax
  1047b7:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    return oldbit != 0;
  1047ba:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
  1047be:	0f 95 c0             	setne  %al
  1047c1:	0f b6 c0             	movzbl %al,%eax
  1047c4:	85 c0                	test   %eax,%eax
  1047c6:	75 2c                	jne    1047f4 <default_free_pages+0x96>
  1047c8:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1047cb:	83 c0 04             	add    $0x4,%eax
  1047ce:	c7 45 e0 01 00 00 00 	movl   $0x1,-0x20(%ebp)
  1047d5:	89 45 dc             	mov    %eax,-0x24(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  1047d8:	8b 45 dc             	mov    -0x24(%ebp),%eax
  1047db:	8b 55 e0             	mov    -0x20(%ebp),%edx
  1047de:	0f a3 10             	bt     %edx,(%eax)
  1047e1:	19 c0                	sbb    %eax,%eax
  1047e3:	89 45 d8             	mov    %eax,-0x28(%ebp)
    return oldbit != 0;
  1047e6:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
  1047ea:	0f 95 c0             	setne  %al
  1047ed:	0f b6 c0             	movzbl %al,%eax
  1047f0:	85 c0                	test   %eax,%eax
  1047f2:	74 24                	je     104818 <default_free_pages+0xba>
  1047f4:	c7 44 24 0c 5c 6f 10 	movl   $0x106f5c,0xc(%esp)
  1047fb:	00 
  1047fc:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104803:	00 
  104804:	c7 44 24 04 b9 00 00 	movl   $0xb9,0x4(%esp)
  10480b:	00 
  10480c:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104813:	e8 e1 bb ff ff       	call   1003f9 <__panic>
        p->flags = 0;
  104818:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10481b:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
        set_page_ref(p, 0);
  104822:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
  104829:	00 
  10482a:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10482d:	89 04 24             	mov    %eax,(%esp)
  104830:	e8 1d fc ff ff       	call   104452 <set_page_ref>
    for (; p != base + n; p ++) { // According to the base address of the withdrawed blocks, search the free
  104835:	83 45 f4 14          	addl   $0x14,-0xc(%ebp)
  104839:	8b 55 0c             	mov    0xc(%ebp),%edx
  10483c:	89 d0                	mov    %edx,%eax
  10483e:	c1 e0 02             	shl    $0x2,%eax
  104841:	01 d0                	add    %edx,%eax
  104843:	c1 e0 02             	shl    $0x2,%eax
  104846:	89 c2                	mov    %eax,%edx
  104848:	8b 45 08             	mov    0x8(%ebp),%eax
  10484b:	01 d0                	add    %edx,%eax
  10484d:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  104850:	0f 85 46 ff ff ff    	jne    10479c <default_free_pages+0x3e>
    }
    base->property = n;
  104856:	8b 45 08             	mov    0x8(%ebp),%eax
  104859:	8b 55 0c             	mov    0xc(%ebp),%edx
  10485c:	89 50 08             	mov    %edx,0x8(%eax)
    SetPageProperty(base);
  10485f:	8b 45 08             	mov    0x8(%ebp),%eax
  104862:	83 c0 04             	add    $0x4,%eax
  104865:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
  10486c:	89 45 cc             	mov    %eax,-0x34(%ebp)
    asm volatile ("btsl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
  10486f:	8b 45 cc             	mov    -0x34(%ebp),%eax
  104872:	8b 55 d0             	mov    -0x30(%ebp),%edx
  104875:	0f ab 10             	bts    %edx,(%eax)
  104878:	c7 45 d4 7c bf 11 00 	movl   $0x11bf7c,-0x2c(%ebp)
    return listelm->next;
  10487f:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  104882:	8b 40 04             	mov    0x4(%eax),%eax
    list_entry_t *le = list_next(&free_list);
  104885:	89 45 f0             	mov    %eax,-0x10(%ebp)
    while (le != &free_list) {
  104888:	e9 08 01 00 00       	jmp    104995 <default_free_pages+0x237>
        p = le2page(le, page_link);
  10488d:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104890:	83 e8 0c             	sub    $0xc,%eax
  104893:	89 45 f4             	mov    %eax,-0xc(%ebp)
  104896:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104899:	89 45 c8             	mov    %eax,-0x38(%ebp)
  10489c:	8b 45 c8             	mov    -0x38(%ebp),%eax
  10489f:	8b 40 04             	mov    0x4(%eax),%eax
        le = list_next(le);
  1048a2:	89 45 f0             	mov    %eax,-0x10(%ebp)
        if (base + base->property == p) {
  1048a5:	8b 45 08             	mov    0x8(%ebp),%eax
  1048a8:	8b 50 08             	mov    0x8(%eax),%edx
  1048ab:	89 d0                	mov    %edx,%eax
  1048ad:	c1 e0 02             	shl    $0x2,%eax
  1048b0:	01 d0                	add    %edx,%eax
  1048b2:	c1 e0 02             	shl    $0x2,%eax
  1048b5:	89 c2                	mov    %eax,%edx
  1048b7:	8b 45 08             	mov    0x8(%ebp),%eax
  1048ba:	01 d0                	add    %edx,%eax
  1048bc:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  1048bf:	75 5a                	jne    10491b <default_free_pages+0x1bd>
            base->property += p->property;
  1048c1:	8b 45 08             	mov    0x8(%ebp),%eax
  1048c4:	8b 50 08             	mov    0x8(%eax),%edx
  1048c7:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1048ca:	8b 40 08             	mov    0x8(%eax),%eax
  1048cd:	01 c2                	add    %eax,%edx
  1048cf:	8b 45 08             	mov    0x8(%ebp),%eax
  1048d2:	89 50 08             	mov    %edx,0x8(%eax)
            ClearPageProperty(p);
  1048d5:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1048d8:	83 c0 04             	add    $0x4,%eax
  1048db:	c7 45 b8 01 00 00 00 	movl   $0x1,-0x48(%ebp)
  1048e2:	89 45 b4             	mov    %eax,-0x4c(%ebp)
    asm volatile ("btrl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
  1048e5:	8b 45 b4             	mov    -0x4c(%ebp),%eax
  1048e8:	8b 55 b8             	mov    -0x48(%ebp),%edx
  1048eb:	0f b3 10             	btr    %edx,(%eax)
            list_del(&(p->page_link));
  1048ee:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1048f1:	83 c0 0c             	add    $0xc,%eax
  1048f4:	89 45 c4             	mov    %eax,-0x3c(%ebp)
    __list_del(listelm->prev, listelm->next);
  1048f7:	8b 45 c4             	mov    -0x3c(%ebp),%eax
  1048fa:	8b 40 04             	mov    0x4(%eax),%eax
  1048fd:	8b 55 c4             	mov    -0x3c(%ebp),%edx
  104900:	8b 12                	mov    (%edx),%edx
  104902:	89 55 c0             	mov    %edx,-0x40(%ebp)
  104905:	89 45 bc             	mov    %eax,-0x44(%ebp)
    prev->next = next;
  104908:	8b 45 c0             	mov    -0x40(%ebp),%eax
  10490b:	8b 55 bc             	mov    -0x44(%ebp),%edx
  10490e:	89 50 04             	mov    %edx,0x4(%eax)
    next->prev = prev;
  104911:	8b 45 bc             	mov    -0x44(%ebp),%eax
  104914:	8b 55 c0             	mov    -0x40(%ebp),%edx
  104917:	89 10                	mov    %edx,(%eax)
  104919:	eb 7a                	jmp    104995 <default_free_pages+0x237>
        }
        else if (p + p->property == base) {
  10491b:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10491e:	8b 50 08             	mov    0x8(%eax),%edx
  104921:	89 d0                	mov    %edx,%eax
  104923:	c1 e0 02             	shl    $0x2,%eax
  104926:	01 d0                	add    %edx,%eax
  104928:	c1 e0 02             	shl    $0x2,%eax
  10492b:	89 c2                	mov    %eax,%edx
  10492d:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104930:	01 d0                	add    %edx,%eax
  104932:	39 45 08             	cmp    %eax,0x8(%ebp)
  104935:	75 5e                	jne    104995 <default_free_pages+0x237>
            p->property += base->property;
  104937:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10493a:	8b 50 08             	mov    0x8(%eax),%edx
  10493d:	8b 45 08             	mov    0x8(%ebp),%eax
  104940:	8b 40 08             	mov    0x8(%eax),%eax
  104943:	01 c2                	add    %eax,%edx
  104945:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104948:	89 50 08             	mov    %edx,0x8(%eax)
            ClearPageProperty(base);
  10494b:	8b 45 08             	mov    0x8(%ebp),%eax
  10494e:	83 c0 04             	add    $0x4,%eax
  104951:	c7 45 a4 01 00 00 00 	movl   $0x1,-0x5c(%ebp)
  104958:	89 45 a0             	mov    %eax,-0x60(%ebp)
  10495b:	8b 45 a0             	mov    -0x60(%ebp),%eax
  10495e:	8b 55 a4             	mov    -0x5c(%ebp),%edx
  104961:	0f b3 10             	btr    %edx,(%eax)
            base = p;
  104964:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104967:	89 45 08             	mov    %eax,0x8(%ebp)
            list_del(&(p->page_link));
  10496a:	8b 45 f4             	mov    -0xc(%ebp),%eax
  10496d:	83 c0 0c             	add    $0xc,%eax
  104970:	89 45 b0             	mov    %eax,-0x50(%ebp)
    __list_del(listelm->prev, listelm->next);
  104973:	8b 45 b0             	mov    -0x50(%ebp),%eax
  104976:	8b 40 04             	mov    0x4(%eax),%eax
  104979:	8b 55 b0             	mov    -0x50(%ebp),%edx
  10497c:	8b 12                	mov    (%edx),%edx
  10497e:	89 55 ac             	mov    %edx,-0x54(%ebp)
  104981:	89 45 a8             	mov    %eax,-0x58(%ebp)
    prev->next = next;
  104984:	8b 45 ac             	mov    -0x54(%ebp),%eax
  104987:	8b 55 a8             	mov    -0x58(%ebp),%edx
  10498a:	89 50 04             	mov    %edx,0x4(%eax)
    next->prev = prev;
  10498d:	8b 45 a8             	mov    -0x58(%ebp),%eax
  104990:	8b 55 ac             	mov    -0x54(%ebp),%edx
  104993:	89 10                	mov    %edx,(%eax)
    while (le != &free_list) {
  104995:	81 7d f0 7c bf 11 00 	cmpl   $0x11bf7c,-0x10(%ebp)
  10499c:	0f 85 eb fe ff ff    	jne    10488d <default_free_pages+0x12f>
        }
    }
    nr_free += n;
  1049a2:	8b 15 84 bf 11 00    	mov    0x11bf84,%edx
  1049a8:	8b 45 0c             	mov    0xc(%ebp),%eax
  1049ab:	01 d0                	add    %edx,%eax
  1049ad:	a3 84 bf 11 00       	mov    %eax,0x11bf84
  1049b2:	c7 45 9c 7c bf 11 00 	movl   $0x11bf7c,-0x64(%ebp)
    return listelm->next;
  1049b9:	8b 45 9c             	mov    -0x64(%ebp),%eax
  1049bc:	8b 40 04             	mov    0x4(%eax),%eax
    
    //加下面这段(释放的这个page的后面是空闲的)
    le = list_next(&free_list);
  1049bf:	89 45 f0             	mov    %eax,-0x10(%ebp)
    while (le != &free_list) {
  1049c2:	eb 74                	jmp    104a38 <default_free_pages+0x2da>
        p = le2page(le, page_link);
  1049c4:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1049c7:	83 e8 0c             	sub    $0xc,%eax
  1049ca:	89 45 f4             	mov    %eax,-0xc(%ebp)
        if (base + base->property <= p) {
  1049cd:	8b 45 08             	mov    0x8(%ebp),%eax
  1049d0:	8b 50 08             	mov    0x8(%eax),%edx
  1049d3:	89 d0                	mov    %edx,%eax
  1049d5:	c1 e0 02             	shl    $0x2,%eax
  1049d8:	01 d0                	add    %edx,%eax
  1049da:	c1 e0 02             	shl    $0x2,%eax
  1049dd:	89 c2                	mov    %eax,%edx
  1049df:	8b 45 08             	mov    0x8(%ebp),%eax
  1049e2:	01 d0                	add    %edx,%eax
  1049e4:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  1049e7:	72 40                	jb     104a29 <default_free_pages+0x2cb>
            assert(base + base->property != p);
  1049e9:	8b 45 08             	mov    0x8(%ebp),%eax
  1049ec:	8b 50 08             	mov    0x8(%eax),%edx
  1049ef:	89 d0                	mov    %edx,%eax
  1049f1:	c1 e0 02             	shl    $0x2,%eax
  1049f4:	01 d0                	add    %edx,%eax
  1049f6:	c1 e0 02             	shl    $0x2,%eax
  1049f9:	89 c2                	mov    %eax,%edx
  1049fb:	8b 45 08             	mov    0x8(%ebp),%eax
  1049fe:	01 d0                	add    %edx,%eax
  104a00:	39 45 f4             	cmp    %eax,-0xc(%ebp)
  104a03:	75 3e                	jne    104a43 <default_free_pages+0x2e5>
  104a05:	c7 44 24 0c 81 6f 10 	movl   $0x106f81,0xc(%esp)
  104a0c:	00 
  104a0d:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104a14:	00 
  104a15:	c7 44 24 04 d6 00 00 	movl   $0xd6,0x4(%esp)
  104a1c:	00 
  104a1d:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104a24:	e8 d0 b9 ff ff       	call   1003f9 <__panic>
  104a29:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104a2c:	89 45 98             	mov    %eax,-0x68(%ebp)
  104a2f:	8b 45 98             	mov    -0x68(%ebp),%eax
  104a32:	8b 40 04             	mov    0x4(%eax),%eax
            break;
        }
        le = list_next(le);
  104a35:	89 45 f0             	mov    %eax,-0x10(%ebp)
    while (le != &free_list) {
  104a38:	81 7d f0 7c bf 11 00 	cmpl   $0x11bf7c,-0x10(%ebp)
  104a3f:	75 83                	jne    1049c4 <default_free_pages+0x266>
  104a41:	eb 01                	jmp    104a44 <default_free_pages+0x2e6>
            break;
  104a43:	90                   	nop
    }
    list_add_before(le, &(base->page_link));
  104a44:	8b 45 08             	mov    0x8(%ebp),%eax
  104a47:	8d 50 0c             	lea    0xc(%eax),%edx
  104a4a:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104a4d:	89 45 94             	mov    %eax,-0x6c(%ebp)
  104a50:	89 55 90             	mov    %edx,-0x70(%ebp)
    __list_add(elm, listelm->prev, listelm);
  104a53:	8b 45 94             	mov    -0x6c(%ebp),%eax
  104a56:	8b 00                	mov    (%eax),%eax
  104a58:	8b 55 90             	mov    -0x70(%ebp),%edx
  104a5b:	89 55 8c             	mov    %edx,-0x74(%ebp)
  104a5e:	89 45 88             	mov    %eax,-0x78(%ebp)
  104a61:	8b 45 94             	mov    -0x6c(%ebp),%eax
  104a64:	89 45 84             	mov    %eax,-0x7c(%ebp)
    prev->next = next->prev = elm;
  104a67:	8b 45 84             	mov    -0x7c(%ebp),%eax
  104a6a:	8b 55 8c             	mov    -0x74(%ebp),%edx
  104a6d:	89 10                	mov    %edx,(%eax)
  104a6f:	8b 45 84             	mov    -0x7c(%ebp),%eax
  104a72:	8b 10                	mov    (%eax),%edx
  104a74:	8b 45 88             	mov    -0x78(%ebp),%eax
  104a77:	89 50 04             	mov    %edx,0x4(%eax)
    elm->next = next;
  104a7a:	8b 45 8c             	mov    -0x74(%ebp),%eax
  104a7d:	8b 55 84             	mov    -0x7c(%ebp),%edx
  104a80:	89 50 04             	mov    %edx,0x4(%eax)
    elm->prev = prev;
  104a83:	8b 45 8c             	mov    -0x74(%ebp),%eax
  104a86:	8b 55 88             	mov    -0x78(%ebp),%edx
  104a89:	89 10                	mov    %edx,(%eax)
}
  104a8b:	90                   	nop
  104a8c:	c9                   	leave  
  104a8d:	c3                   	ret    

00104a8e <default_nr_free_pages>:

static size_t
default_nr_free_pages(void) {
  104a8e:	55                   	push   %ebp
  104a8f:	89 e5                	mov    %esp,%ebp
    return nr_free;
  104a91:	a1 84 bf 11 00       	mov    0x11bf84,%eax
}
  104a96:	5d                   	pop    %ebp
  104a97:	c3                   	ret    

00104a98 <basic_check>:

static void
basic_check(void) {
  104a98:	55                   	push   %ebp
  104a99:	89 e5                	mov    %esp,%ebp
  104a9b:	83 ec 48             	sub    $0x48,%esp
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;
  104a9e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
  104aa5:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104aa8:	89 45 f0             	mov    %eax,-0x10(%ebp)
  104aab:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104aae:	89 45 ec             	mov    %eax,-0x14(%ebp)
    assert((p0 = alloc_page()) != NULL);
  104ab1:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104ab8:	e8 ae e2 ff ff       	call   102d6b <alloc_pages>
  104abd:	89 45 ec             	mov    %eax,-0x14(%ebp)
  104ac0:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
  104ac4:	75 24                	jne    104aea <basic_check+0x52>
  104ac6:	c7 44 24 0c 9c 6f 10 	movl   $0x106f9c,0xc(%esp)
  104acd:	00 
  104ace:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104ad5:	00 
  104ad6:	c7 44 24 04 e7 00 00 	movl   $0xe7,0x4(%esp)
  104add:	00 
  104ade:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104ae5:	e8 0f b9 ff ff       	call   1003f9 <__panic>
    assert((p1 = alloc_page()) != NULL);
  104aea:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104af1:	e8 75 e2 ff ff       	call   102d6b <alloc_pages>
  104af6:	89 45 f0             	mov    %eax,-0x10(%ebp)
  104af9:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  104afd:	75 24                	jne    104b23 <basic_check+0x8b>
  104aff:	c7 44 24 0c b8 6f 10 	movl   $0x106fb8,0xc(%esp)
  104b06:	00 
  104b07:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104b0e:	00 
  104b0f:	c7 44 24 04 e8 00 00 	movl   $0xe8,0x4(%esp)
  104b16:	00 
  104b17:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104b1e:	e8 d6 b8 ff ff       	call   1003f9 <__panic>
    assert((p2 = alloc_page()) != NULL);
  104b23:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104b2a:	e8 3c e2 ff ff       	call   102d6b <alloc_pages>
  104b2f:	89 45 f4             	mov    %eax,-0xc(%ebp)
  104b32:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  104b36:	75 24                	jne    104b5c <basic_check+0xc4>
  104b38:	c7 44 24 0c d4 6f 10 	movl   $0x106fd4,0xc(%esp)
  104b3f:	00 
  104b40:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104b47:	00 
  104b48:	c7 44 24 04 e9 00 00 	movl   $0xe9,0x4(%esp)
  104b4f:	00 
  104b50:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104b57:	e8 9d b8 ff ff       	call   1003f9 <__panic>

    assert(p0 != p1 && p0 != p2 && p1 != p2);
  104b5c:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104b5f:	3b 45 f0             	cmp    -0x10(%ebp),%eax
  104b62:	74 10                	je     104b74 <basic_check+0xdc>
  104b64:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104b67:	3b 45 f4             	cmp    -0xc(%ebp),%eax
  104b6a:	74 08                	je     104b74 <basic_check+0xdc>
  104b6c:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104b6f:	3b 45 f4             	cmp    -0xc(%ebp),%eax
  104b72:	75 24                	jne    104b98 <basic_check+0x100>
  104b74:	c7 44 24 0c f0 6f 10 	movl   $0x106ff0,0xc(%esp)
  104b7b:	00 
  104b7c:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104b83:	00 
  104b84:	c7 44 24 04 eb 00 00 	movl   $0xeb,0x4(%esp)
  104b8b:	00 
  104b8c:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104b93:	e8 61 b8 ff ff       	call   1003f9 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
  104b98:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104b9b:	89 04 24             	mov    %eax,(%esp)
  104b9e:	e8 a5 f8 ff ff       	call   104448 <page_ref>
  104ba3:	85 c0                	test   %eax,%eax
  104ba5:	75 1e                	jne    104bc5 <basic_check+0x12d>
  104ba7:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104baa:	89 04 24             	mov    %eax,(%esp)
  104bad:	e8 96 f8 ff ff       	call   104448 <page_ref>
  104bb2:	85 c0                	test   %eax,%eax
  104bb4:	75 0f                	jne    104bc5 <basic_check+0x12d>
  104bb6:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104bb9:	89 04 24             	mov    %eax,(%esp)
  104bbc:	e8 87 f8 ff ff       	call   104448 <page_ref>
  104bc1:	85 c0                	test   %eax,%eax
  104bc3:	74 24                	je     104be9 <basic_check+0x151>
  104bc5:	c7 44 24 0c 14 70 10 	movl   $0x107014,0xc(%esp)
  104bcc:	00 
  104bcd:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104bd4:	00 
  104bd5:	c7 44 24 04 ec 00 00 	movl   $0xec,0x4(%esp)
  104bdc:	00 
  104bdd:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104be4:	e8 10 b8 ff ff       	call   1003f9 <__panic>

    assert(page2pa(p0) < npage * PGSIZE);
  104be9:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104bec:	89 04 24             	mov    %eax,(%esp)
  104bef:	e8 3e f8 ff ff       	call   104432 <page2pa>
  104bf4:	8b 15 80 be 11 00    	mov    0x11be80,%edx
  104bfa:	c1 e2 0c             	shl    $0xc,%edx
  104bfd:	39 d0                	cmp    %edx,%eax
  104bff:	72 24                	jb     104c25 <basic_check+0x18d>
  104c01:	c7 44 24 0c 50 70 10 	movl   $0x107050,0xc(%esp)
  104c08:	00 
  104c09:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104c10:	00 
  104c11:	c7 44 24 04 ee 00 00 	movl   $0xee,0x4(%esp)
  104c18:	00 
  104c19:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104c20:	e8 d4 b7 ff ff       	call   1003f9 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
  104c25:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104c28:	89 04 24             	mov    %eax,(%esp)
  104c2b:	e8 02 f8 ff ff       	call   104432 <page2pa>
  104c30:	8b 15 80 be 11 00    	mov    0x11be80,%edx
  104c36:	c1 e2 0c             	shl    $0xc,%edx
  104c39:	39 d0                	cmp    %edx,%eax
  104c3b:	72 24                	jb     104c61 <basic_check+0x1c9>
  104c3d:	c7 44 24 0c 6d 70 10 	movl   $0x10706d,0xc(%esp)
  104c44:	00 
  104c45:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104c4c:	00 
  104c4d:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
  104c54:	00 
  104c55:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104c5c:	e8 98 b7 ff ff       	call   1003f9 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
  104c61:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104c64:	89 04 24             	mov    %eax,(%esp)
  104c67:	e8 c6 f7 ff ff       	call   104432 <page2pa>
  104c6c:	8b 15 80 be 11 00    	mov    0x11be80,%edx
  104c72:	c1 e2 0c             	shl    $0xc,%edx
  104c75:	39 d0                	cmp    %edx,%eax
  104c77:	72 24                	jb     104c9d <basic_check+0x205>
  104c79:	c7 44 24 0c 8a 70 10 	movl   $0x10708a,0xc(%esp)
  104c80:	00 
  104c81:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104c88:	00 
  104c89:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
  104c90:	00 
  104c91:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104c98:	e8 5c b7 ff ff       	call   1003f9 <__panic>

    list_entry_t free_list_store = free_list;
  104c9d:	a1 7c bf 11 00       	mov    0x11bf7c,%eax
  104ca2:	8b 15 80 bf 11 00    	mov    0x11bf80,%edx
  104ca8:	89 45 d0             	mov    %eax,-0x30(%ebp)
  104cab:	89 55 d4             	mov    %edx,-0x2c(%ebp)
  104cae:	c7 45 dc 7c bf 11 00 	movl   $0x11bf7c,-0x24(%ebp)
    elm->prev = elm->next = elm;
  104cb5:	8b 45 dc             	mov    -0x24(%ebp),%eax
  104cb8:	8b 55 dc             	mov    -0x24(%ebp),%edx
  104cbb:	89 50 04             	mov    %edx,0x4(%eax)
  104cbe:	8b 45 dc             	mov    -0x24(%ebp),%eax
  104cc1:	8b 50 04             	mov    0x4(%eax),%edx
  104cc4:	8b 45 dc             	mov    -0x24(%ebp),%eax
  104cc7:	89 10                	mov    %edx,(%eax)
  104cc9:	c7 45 e0 7c bf 11 00 	movl   $0x11bf7c,-0x20(%ebp)
    return list->next == list;
  104cd0:	8b 45 e0             	mov    -0x20(%ebp),%eax
  104cd3:	8b 40 04             	mov    0x4(%eax),%eax
  104cd6:	39 45 e0             	cmp    %eax,-0x20(%ebp)
  104cd9:	0f 94 c0             	sete   %al
  104cdc:	0f b6 c0             	movzbl %al,%eax
    list_init(&free_list);
    assert(list_empty(&free_list));
  104cdf:	85 c0                	test   %eax,%eax
  104ce1:	75 24                	jne    104d07 <basic_check+0x26f>
  104ce3:	c7 44 24 0c a7 70 10 	movl   $0x1070a7,0xc(%esp)
  104cea:	00 
  104ceb:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104cf2:	00 
  104cf3:	c7 44 24 04 f4 00 00 	movl   $0xf4,0x4(%esp)
  104cfa:	00 
  104cfb:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104d02:	e8 f2 b6 ff ff       	call   1003f9 <__panic>

    unsigned int nr_free_store = nr_free;
  104d07:	a1 84 bf 11 00       	mov    0x11bf84,%eax
  104d0c:	89 45 e8             	mov    %eax,-0x18(%ebp)
    nr_free = 0;
  104d0f:	c7 05 84 bf 11 00 00 	movl   $0x0,0x11bf84
  104d16:	00 00 00 

    assert(alloc_page() == NULL);
  104d19:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104d20:	e8 46 e0 ff ff       	call   102d6b <alloc_pages>
  104d25:	85 c0                	test   %eax,%eax
  104d27:	74 24                	je     104d4d <basic_check+0x2b5>
  104d29:	c7 44 24 0c be 70 10 	movl   $0x1070be,0xc(%esp)
  104d30:	00 
  104d31:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104d38:	00 
  104d39:	c7 44 24 04 f9 00 00 	movl   $0xf9,0x4(%esp)
  104d40:	00 
  104d41:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104d48:	e8 ac b6 ff ff       	call   1003f9 <__panic>

    free_page(p0);
  104d4d:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104d54:	00 
  104d55:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104d58:	89 04 24             	mov    %eax,(%esp)
  104d5b:	e8 43 e0 ff ff       	call   102da3 <free_pages>
    free_page(p1);
  104d60:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104d67:	00 
  104d68:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104d6b:	89 04 24             	mov    %eax,(%esp)
  104d6e:	e8 30 e0 ff ff       	call   102da3 <free_pages>
    free_page(p2);
  104d73:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104d7a:	00 
  104d7b:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104d7e:	89 04 24             	mov    %eax,(%esp)
  104d81:	e8 1d e0 ff ff       	call   102da3 <free_pages>
    assert(nr_free == 3);
  104d86:	a1 84 bf 11 00       	mov    0x11bf84,%eax
  104d8b:	83 f8 03             	cmp    $0x3,%eax
  104d8e:	74 24                	je     104db4 <basic_check+0x31c>
  104d90:	c7 44 24 0c d3 70 10 	movl   $0x1070d3,0xc(%esp)
  104d97:	00 
  104d98:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104d9f:	00 
  104da0:	c7 44 24 04 fe 00 00 	movl   $0xfe,0x4(%esp)
  104da7:	00 
  104da8:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104daf:	e8 45 b6 ff ff       	call   1003f9 <__panic>

    assert((p0 = alloc_page()) != NULL);
  104db4:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104dbb:	e8 ab df ff ff       	call   102d6b <alloc_pages>
  104dc0:	89 45 ec             	mov    %eax,-0x14(%ebp)
  104dc3:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
  104dc7:	75 24                	jne    104ded <basic_check+0x355>
  104dc9:	c7 44 24 0c 9c 6f 10 	movl   $0x106f9c,0xc(%esp)
  104dd0:	00 
  104dd1:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104dd8:	00 
  104dd9:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
  104de0:	00 
  104de1:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104de8:	e8 0c b6 ff ff       	call   1003f9 <__panic>
    assert((p1 = alloc_page()) != NULL);
  104ded:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104df4:	e8 72 df ff ff       	call   102d6b <alloc_pages>
  104df9:	89 45 f0             	mov    %eax,-0x10(%ebp)
  104dfc:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  104e00:	75 24                	jne    104e26 <basic_check+0x38e>
  104e02:	c7 44 24 0c b8 6f 10 	movl   $0x106fb8,0xc(%esp)
  104e09:	00 
  104e0a:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104e11:	00 
  104e12:	c7 44 24 04 01 01 00 	movl   $0x101,0x4(%esp)
  104e19:	00 
  104e1a:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104e21:	e8 d3 b5 ff ff       	call   1003f9 <__panic>
    assert((p2 = alloc_page()) != NULL);
  104e26:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104e2d:	e8 39 df ff ff       	call   102d6b <alloc_pages>
  104e32:	89 45 f4             	mov    %eax,-0xc(%ebp)
  104e35:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  104e39:	75 24                	jne    104e5f <basic_check+0x3c7>
  104e3b:	c7 44 24 0c d4 6f 10 	movl   $0x106fd4,0xc(%esp)
  104e42:	00 
  104e43:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104e4a:	00 
  104e4b:	c7 44 24 04 02 01 00 	movl   $0x102,0x4(%esp)
  104e52:	00 
  104e53:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104e5a:	e8 9a b5 ff ff       	call   1003f9 <__panic>

    assert(alloc_page() == NULL);
  104e5f:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104e66:	e8 00 df ff ff       	call   102d6b <alloc_pages>
  104e6b:	85 c0                	test   %eax,%eax
  104e6d:	74 24                	je     104e93 <basic_check+0x3fb>
  104e6f:	c7 44 24 0c be 70 10 	movl   $0x1070be,0xc(%esp)
  104e76:	00 
  104e77:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104e7e:	00 
  104e7f:	c7 44 24 04 04 01 00 	movl   $0x104,0x4(%esp)
  104e86:	00 
  104e87:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104e8e:	e8 66 b5 ff ff       	call   1003f9 <__panic>

    free_page(p0);
  104e93:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104e9a:	00 
  104e9b:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104e9e:	89 04 24             	mov    %eax,(%esp)
  104ea1:	e8 fd de ff ff       	call   102da3 <free_pages>
  104ea6:	c7 45 d8 7c bf 11 00 	movl   $0x11bf7c,-0x28(%ebp)
  104ead:	8b 45 d8             	mov    -0x28(%ebp),%eax
  104eb0:	8b 40 04             	mov    0x4(%eax),%eax
  104eb3:	39 45 d8             	cmp    %eax,-0x28(%ebp)
  104eb6:	0f 94 c0             	sete   %al
  104eb9:	0f b6 c0             	movzbl %al,%eax
    assert(!list_empty(&free_list));
  104ebc:	85 c0                	test   %eax,%eax
  104ebe:	74 24                	je     104ee4 <basic_check+0x44c>
  104ec0:	c7 44 24 0c e0 70 10 	movl   $0x1070e0,0xc(%esp)
  104ec7:	00 
  104ec8:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104ecf:	00 
  104ed0:	c7 44 24 04 07 01 00 	movl   $0x107,0x4(%esp)
  104ed7:	00 
  104ed8:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104edf:	e8 15 b5 ff ff       	call   1003f9 <__panic>

    struct Page *p;
    assert((p = alloc_page()) == p0);
  104ee4:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104eeb:	e8 7b de ff ff       	call   102d6b <alloc_pages>
  104ef0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  104ef3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  104ef6:	3b 45 ec             	cmp    -0x14(%ebp),%eax
  104ef9:	74 24                	je     104f1f <basic_check+0x487>
  104efb:	c7 44 24 0c f8 70 10 	movl   $0x1070f8,0xc(%esp)
  104f02:	00 
  104f03:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104f0a:	00 
  104f0b:	c7 44 24 04 0a 01 00 	movl   $0x10a,0x4(%esp)
  104f12:	00 
  104f13:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104f1a:	e8 da b4 ff ff       	call   1003f9 <__panic>
    assert(alloc_page() == NULL);
  104f1f:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  104f26:	e8 40 de ff ff       	call   102d6b <alloc_pages>
  104f2b:	85 c0                	test   %eax,%eax
  104f2d:	74 24                	je     104f53 <basic_check+0x4bb>
  104f2f:	c7 44 24 0c be 70 10 	movl   $0x1070be,0xc(%esp)
  104f36:	00 
  104f37:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104f3e:	00 
  104f3f:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
  104f46:	00 
  104f47:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104f4e:	e8 a6 b4 ff ff       	call   1003f9 <__panic>

    assert(nr_free == 0);
  104f53:	a1 84 bf 11 00       	mov    0x11bf84,%eax
  104f58:	85 c0                	test   %eax,%eax
  104f5a:	74 24                	je     104f80 <basic_check+0x4e8>
  104f5c:	c7 44 24 0c 11 71 10 	movl   $0x107111,0xc(%esp)
  104f63:	00 
  104f64:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  104f6b:	00 
  104f6c:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
  104f73:	00 
  104f74:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  104f7b:	e8 79 b4 ff ff       	call   1003f9 <__panic>
    free_list = free_list_store;
  104f80:	8b 45 d0             	mov    -0x30(%ebp),%eax
  104f83:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  104f86:	a3 7c bf 11 00       	mov    %eax,0x11bf7c
  104f8b:	89 15 80 bf 11 00    	mov    %edx,0x11bf80
    nr_free = nr_free_store;
  104f91:	8b 45 e8             	mov    -0x18(%ebp),%eax
  104f94:	a3 84 bf 11 00       	mov    %eax,0x11bf84

    free_page(p);
  104f99:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104fa0:	00 
  104fa1:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  104fa4:	89 04 24             	mov    %eax,(%esp)
  104fa7:	e8 f7 dd ff ff       	call   102da3 <free_pages>
    free_page(p1);
  104fac:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104fb3:	00 
  104fb4:	8b 45 f0             	mov    -0x10(%ebp),%eax
  104fb7:	89 04 24             	mov    %eax,(%esp)
  104fba:	e8 e4 dd ff ff       	call   102da3 <free_pages>
    free_page(p2);
  104fbf:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  104fc6:	00 
  104fc7:	8b 45 f4             	mov    -0xc(%ebp),%eax
  104fca:	89 04 24             	mov    %eax,(%esp)
  104fcd:	e8 d1 dd ff ff       	call   102da3 <free_pages>
}
  104fd2:	90                   	nop
  104fd3:	c9                   	leave  
  104fd4:	c3                   	ret    

00104fd5 <default_check>:

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
default_check(void) {
  104fd5:	55                   	push   %ebp
  104fd6:	89 e5                	mov    %esp,%ebp
  104fd8:	81 ec 98 00 00 00    	sub    $0x98,%esp
    int count = 0, total = 0;
  104fde:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
  104fe5:	c7 45 f0 00 00 00 00 	movl   $0x0,-0x10(%ebp)
    list_entry_t *le = &free_list;
  104fec:	c7 45 ec 7c bf 11 00 	movl   $0x11bf7c,-0x14(%ebp)
    while ((le = list_next(le)) != &free_list) {
  104ff3:	eb 6a                	jmp    10505f <default_check+0x8a>
        struct Page *p = le2page(le, page_link);
  104ff5:	8b 45 ec             	mov    -0x14(%ebp),%eax
  104ff8:	83 e8 0c             	sub    $0xc,%eax
  104ffb:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        assert(PageProperty(p));
  104ffe:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  105001:	83 c0 04             	add    $0x4,%eax
  105004:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
  10500b:	89 45 cc             	mov    %eax,-0x34(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  10500e:	8b 45 cc             	mov    -0x34(%ebp),%eax
  105011:	8b 55 d0             	mov    -0x30(%ebp),%edx
  105014:	0f a3 10             	bt     %edx,(%eax)
  105017:	19 c0                	sbb    %eax,%eax
  105019:	89 45 c8             	mov    %eax,-0x38(%ebp)
    return oldbit != 0;
  10501c:	83 7d c8 00          	cmpl   $0x0,-0x38(%ebp)
  105020:	0f 95 c0             	setne  %al
  105023:	0f b6 c0             	movzbl %al,%eax
  105026:	85 c0                	test   %eax,%eax
  105028:	75 24                	jne    10504e <default_check+0x79>
  10502a:	c7 44 24 0c 1e 71 10 	movl   $0x10711e,0xc(%esp)
  105031:	00 
  105032:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105039:	00 
  10503a:	c7 44 24 04 1e 01 00 	movl   $0x11e,0x4(%esp)
  105041:	00 
  105042:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105049:	e8 ab b3 ff ff       	call   1003f9 <__panic>
        count ++, total += p->property;
  10504e:	ff 45 f4             	incl   -0xc(%ebp)
  105051:	8b 45 d4             	mov    -0x2c(%ebp),%eax
  105054:	8b 50 08             	mov    0x8(%eax),%edx
  105057:	8b 45 f0             	mov    -0x10(%ebp),%eax
  10505a:	01 d0                	add    %edx,%eax
  10505c:	89 45 f0             	mov    %eax,-0x10(%ebp)
  10505f:	8b 45 ec             	mov    -0x14(%ebp),%eax
  105062:	89 45 c4             	mov    %eax,-0x3c(%ebp)
    return listelm->next;
  105065:	8b 45 c4             	mov    -0x3c(%ebp),%eax
  105068:	8b 40 04             	mov    0x4(%eax),%eax
    while ((le = list_next(le)) != &free_list) {
  10506b:	89 45 ec             	mov    %eax,-0x14(%ebp)
  10506e:	81 7d ec 7c bf 11 00 	cmpl   $0x11bf7c,-0x14(%ebp)
  105075:	0f 85 7a ff ff ff    	jne    104ff5 <default_check+0x20>
    }
    assert(total == nr_free_pages());
  10507b:	e8 56 dd ff ff       	call   102dd6 <nr_free_pages>
  105080:	89 c2                	mov    %eax,%edx
  105082:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105085:	39 c2                	cmp    %eax,%edx
  105087:	74 24                	je     1050ad <default_check+0xd8>
  105089:	c7 44 24 0c 2e 71 10 	movl   $0x10712e,0xc(%esp)
  105090:	00 
  105091:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105098:	00 
  105099:	c7 44 24 04 21 01 00 	movl   $0x121,0x4(%esp)
  1050a0:	00 
  1050a1:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1050a8:	e8 4c b3 ff ff       	call   1003f9 <__panic>

    basic_check();
  1050ad:	e8 e6 f9 ff ff       	call   104a98 <basic_check>

    struct Page *p0 = alloc_pages(5), *p1, *p2;
  1050b2:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
  1050b9:	e8 ad dc ff ff       	call   102d6b <alloc_pages>
  1050be:	89 45 e8             	mov    %eax,-0x18(%ebp)
    assert(p0 != NULL);
  1050c1:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  1050c5:	75 24                	jne    1050eb <default_check+0x116>
  1050c7:	c7 44 24 0c 47 71 10 	movl   $0x107147,0xc(%esp)
  1050ce:	00 
  1050cf:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1050d6:	00 
  1050d7:	c7 44 24 04 26 01 00 	movl   $0x126,0x4(%esp)
  1050de:	00 
  1050df:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1050e6:	e8 0e b3 ff ff       	call   1003f9 <__panic>
    assert(!PageProperty(p0));
  1050eb:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1050ee:	83 c0 04             	add    $0x4,%eax
  1050f1:	c7 45 c0 01 00 00 00 	movl   $0x1,-0x40(%ebp)
  1050f8:	89 45 bc             	mov    %eax,-0x44(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  1050fb:	8b 45 bc             	mov    -0x44(%ebp),%eax
  1050fe:	8b 55 c0             	mov    -0x40(%ebp),%edx
  105101:	0f a3 10             	bt     %edx,(%eax)
  105104:	19 c0                	sbb    %eax,%eax
  105106:	89 45 b8             	mov    %eax,-0x48(%ebp)
    return oldbit != 0;
  105109:	83 7d b8 00          	cmpl   $0x0,-0x48(%ebp)
  10510d:	0f 95 c0             	setne  %al
  105110:	0f b6 c0             	movzbl %al,%eax
  105113:	85 c0                	test   %eax,%eax
  105115:	74 24                	je     10513b <default_check+0x166>
  105117:	c7 44 24 0c 52 71 10 	movl   $0x107152,0xc(%esp)
  10511e:	00 
  10511f:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105126:	00 
  105127:	c7 44 24 04 27 01 00 	movl   $0x127,0x4(%esp)
  10512e:	00 
  10512f:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105136:	e8 be b2 ff ff       	call   1003f9 <__panic>

    list_entry_t free_list_store = free_list;
  10513b:	a1 7c bf 11 00       	mov    0x11bf7c,%eax
  105140:	8b 15 80 bf 11 00    	mov    0x11bf80,%edx
  105146:	89 45 80             	mov    %eax,-0x80(%ebp)
  105149:	89 55 84             	mov    %edx,-0x7c(%ebp)
  10514c:	c7 45 b0 7c bf 11 00 	movl   $0x11bf7c,-0x50(%ebp)
    elm->prev = elm->next = elm;
  105153:	8b 45 b0             	mov    -0x50(%ebp),%eax
  105156:	8b 55 b0             	mov    -0x50(%ebp),%edx
  105159:	89 50 04             	mov    %edx,0x4(%eax)
  10515c:	8b 45 b0             	mov    -0x50(%ebp),%eax
  10515f:	8b 50 04             	mov    0x4(%eax),%edx
  105162:	8b 45 b0             	mov    -0x50(%ebp),%eax
  105165:	89 10                	mov    %edx,(%eax)
  105167:	c7 45 b4 7c bf 11 00 	movl   $0x11bf7c,-0x4c(%ebp)
    return list->next == list;
  10516e:	8b 45 b4             	mov    -0x4c(%ebp),%eax
  105171:	8b 40 04             	mov    0x4(%eax),%eax
  105174:	39 45 b4             	cmp    %eax,-0x4c(%ebp)
  105177:	0f 94 c0             	sete   %al
  10517a:	0f b6 c0             	movzbl %al,%eax
    list_init(&free_list);
    assert(list_empty(&free_list));
  10517d:	85 c0                	test   %eax,%eax
  10517f:	75 24                	jne    1051a5 <default_check+0x1d0>
  105181:	c7 44 24 0c a7 70 10 	movl   $0x1070a7,0xc(%esp)
  105188:	00 
  105189:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105190:	00 
  105191:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
  105198:	00 
  105199:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1051a0:	e8 54 b2 ff ff       	call   1003f9 <__panic>
    assert(alloc_page() == NULL);
  1051a5:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  1051ac:	e8 ba db ff ff       	call   102d6b <alloc_pages>
  1051b1:	85 c0                	test   %eax,%eax
  1051b3:	74 24                	je     1051d9 <default_check+0x204>
  1051b5:	c7 44 24 0c be 70 10 	movl   $0x1070be,0xc(%esp)
  1051bc:	00 
  1051bd:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1051c4:	00 
  1051c5:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
  1051cc:	00 
  1051cd:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1051d4:	e8 20 b2 ff ff       	call   1003f9 <__panic>

    unsigned int nr_free_store = nr_free;
  1051d9:	a1 84 bf 11 00       	mov    0x11bf84,%eax
  1051de:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    nr_free = 0;
  1051e1:	c7 05 84 bf 11 00 00 	movl   $0x0,0x11bf84
  1051e8:	00 00 00 

    free_pages(p0 + 2, 3);
  1051eb:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1051ee:	83 c0 28             	add    $0x28,%eax
  1051f1:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
  1051f8:	00 
  1051f9:	89 04 24             	mov    %eax,(%esp)
  1051fc:	e8 a2 db ff ff       	call   102da3 <free_pages>
    assert(alloc_pages(4) == NULL);
  105201:	c7 04 24 04 00 00 00 	movl   $0x4,(%esp)
  105208:	e8 5e db ff ff       	call   102d6b <alloc_pages>
  10520d:	85 c0                	test   %eax,%eax
  10520f:	74 24                	je     105235 <default_check+0x260>
  105211:	c7 44 24 0c 64 71 10 	movl   $0x107164,0xc(%esp)
  105218:	00 
  105219:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105220:	00 
  105221:	c7 44 24 04 32 01 00 	movl   $0x132,0x4(%esp)
  105228:	00 
  105229:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105230:	e8 c4 b1 ff ff       	call   1003f9 <__panic>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
  105235:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105238:	83 c0 28             	add    $0x28,%eax
  10523b:	83 c0 04             	add    $0x4,%eax
  10523e:	c7 45 ac 01 00 00 00 	movl   $0x1,-0x54(%ebp)
  105245:	89 45 a8             	mov    %eax,-0x58(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  105248:	8b 45 a8             	mov    -0x58(%ebp),%eax
  10524b:	8b 55 ac             	mov    -0x54(%ebp),%edx
  10524e:	0f a3 10             	bt     %edx,(%eax)
  105251:	19 c0                	sbb    %eax,%eax
  105253:	89 45 a4             	mov    %eax,-0x5c(%ebp)
    return oldbit != 0;
  105256:	83 7d a4 00          	cmpl   $0x0,-0x5c(%ebp)
  10525a:	0f 95 c0             	setne  %al
  10525d:	0f b6 c0             	movzbl %al,%eax
  105260:	85 c0                	test   %eax,%eax
  105262:	74 0e                	je     105272 <default_check+0x29d>
  105264:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105267:	83 c0 28             	add    $0x28,%eax
  10526a:	8b 40 08             	mov    0x8(%eax),%eax
  10526d:	83 f8 03             	cmp    $0x3,%eax
  105270:	74 24                	je     105296 <default_check+0x2c1>
  105272:	c7 44 24 0c 7c 71 10 	movl   $0x10717c,0xc(%esp)
  105279:	00 
  10527a:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105281:	00 
  105282:	c7 44 24 04 33 01 00 	movl   $0x133,0x4(%esp)
  105289:	00 
  10528a:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105291:	e8 63 b1 ff ff       	call   1003f9 <__panic>
    assert((p1 = alloc_pages(3)) != NULL);
  105296:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
  10529d:	e8 c9 da ff ff       	call   102d6b <alloc_pages>
  1052a2:	89 45 e0             	mov    %eax,-0x20(%ebp)
  1052a5:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
  1052a9:	75 24                	jne    1052cf <default_check+0x2fa>
  1052ab:	c7 44 24 0c a8 71 10 	movl   $0x1071a8,0xc(%esp)
  1052b2:	00 
  1052b3:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1052ba:	00 
  1052bb:	c7 44 24 04 34 01 00 	movl   $0x134,0x4(%esp)
  1052c2:	00 
  1052c3:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1052ca:	e8 2a b1 ff ff       	call   1003f9 <__panic>
    assert(alloc_page() == NULL);
  1052cf:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  1052d6:	e8 90 da ff ff       	call   102d6b <alloc_pages>
  1052db:	85 c0                	test   %eax,%eax
  1052dd:	74 24                	je     105303 <default_check+0x32e>
  1052df:	c7 44 24 0c be 70 10 	movl   $0x1070be,0xc(%esp)
  1052e6:	00 
  1052e7:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1052ee:	00 
  1052ef:	c7 44 24 04 35 01 00 	movl   $0x135,0x4(%esp)
  1052f6:	00 
  1052f7:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1052fe:	e8 f6 b0 ff ff       	call   1003f9 <__panic>
    assert(p0 + 2 == p1);
  105303:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105306:	83 c0 28             	add    $0x28,%eax
  105309:	39 45 e0             	cmp    %eax,-0x20(%ebp)
  10530c:	74 24                	je     105332 <default_check+0x35d>
  10530e:	c7 44 24 0c c6 71 10 	movl   $0x1071c6,0xc(%esp)
  105315:	00 
  105316:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  10531d:	00 
  10531e:	c7 44 24 04 36 01 00 	movl   $0x136,0x4(%esp)
  105325:	00 
  105326:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  10532d:	e8 c7 b0 ff ff       	call   1003f9 <__panic>

    p2 = p0 + 1;
  105332:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105335:	83 c0 14             	add    $0x14,%eax
  105338:	89 45 dc             	mov    %eax,-0x24(%ebp)
    free_page(p0);
  10533b:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  105342:	00 
  105343:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105346:	89 04 24             	mov    %eax,(%esp)
  105349:	e8 55 da ff ff       	call   102da3 <free_pages>
    free_pages(p1, 3);
  10534e:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
  105355:	00 
  105356:	8b 45 e0             	mov    -0x20(%ebp),%eax
  105359:	89 04 24             	mov    %eax,(%esp)
  10535c:	e8 42 da ff ff       	call   102da3 <free_pages>
    assert(PageProperty(p0) && p0->property == 1);
  105361:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105364:	83 c0 04             	add    $0x4,%eax
  105367:	c7 45 a0 01 00 00 00 	movl   $0x1,-0x60(%ebp)
  10536e:	89 45 9c             	mov    %eax,-0x64(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  105371:	8b 45 9c             	mov    -0x64(%ebp),%eax
  105374:	8b 55 a0             	mov    -0x60(%ebp),%edx
  105377:	0f a3 10             	bt     %edx,(%eax)
  10537a:	19 c0                	sbb    %eax,%eax
  10537c:	89 45 98             	mov    %eax,-0x68(%ebp)
    return oldbit != 0;
  10537f:	83 7d 98 00          	cmpl   $0x0,-0x68(%ebp)
  105383:	0f 95 c0             	setne  %al
  105386:	0f b6 c0             	movzbl %al,%eax
  105389:	85 c0                	test   %eax,%eax
  10538b:	74 0b                	je     105398 <default_check+0x3c3>
  10538d:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105390:	8b 40 08             	mov    0x8(%eax),%eax
  105393:	83 f8 01             	cmp    $0x1,%eax
  105396:	74 24                	je     1053bc <default_check+0x3e7>
  105398:	c7 44 24 0c d4 71 10 	movl   $0x1071d4,0xc(%esp)
  10539f:	00 
  1053a0:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1053a7:	00 
  1053a8:	c7 44 24 04 3b 01 00 	movl   $0x13b,0x4(%esp)
  1053af:	00 
  1053b0:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1053b7:	e8 3d b0 ff ff       	call   1003f9 <__panic>
    assert(PageProperty(p1) && p1->property == 3);
  1053bc:	8b 45 e0             	mov    -0x20(%ebp),%eax
  1053bf:	83 c0 04             	add    $0x4,%eax
  1053c2:	c7 45 94 01 00 00 00 	movl   $0x1,-0x6c(%ebp)
  1053c9:	89 45 90             	mov    %eax,-0x70(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
  1053cc:	8b 45 90             	mov    -0x70(%ebp),%eax
  1053cf:	8b 55 94             	mov    -0x6c(%ebp),%edx
  1053d2:	0f a3 10             	bt     %edx,(%eax)
  1053d5:	19 c0                	sbb    %eax,%eax
  1053d7:	89 45 8c             	mov    %eax,-0x74(%ebp)
    return oldbit != 0;
  1053da:	83 7d 8c 00          	cmpl   $0x0,-0x74(%ebp)
  1053de:	0f 95 c0             	setne  %al
  1053e1:	0f b6 c0             	movzbl %al,%eax
  1053e4:	85 c0                	test   %eax,%eax
  1053e6:	74 0b                	je     1053f3 <default_check+0x41e>
  1053e8:	8b 45 e0             	mov    -0x20(%ebp),%eax
  1053eb:	8b 40 08             	mov    0x8(%eax),%eax
  1053ee:	83 f8 03             	cmp    $0x3,%eax
  1053f1:	74 24                	je     105417 <default_check+0x442>
  1053f3:	c7 44 24 0c fc 71 10 	movl   $0x1071fc,0xc(%esp)
  1053fa:	00 
  1053fb:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105402:	00 
  105403:	c7 44 24 04 3c 01 00 	movl   $0x13c,0x4(%esp)
  10540a:	00 
  10540b:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105412:	e8 e2 af ff ff       	call   1003f9 <__panic>

    assert((p0 = alloc_page()) == p2 - 1);
  105417:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  10541e:	e8 48 d9 ff ff       	call   102d6b <alloc_pages>
  105423:	89 45 e8             	mov    %eax,-0x18(%ebp)
  105426:	8b 45 dc             	mov    -0x24(%ebp),%eax
  105429:	83 e8 14             	sub    $0x14,%eax
  10542c:	39 45 e8             	cmp    %eax,-0x18(%ebp)
  10542f:	74 24                	je     105455 <default_check+0x480>
  105431:	c7 44 24 0c 22 72 10 	movl   $0x107222,0xc(%esp)
  105438:	00 
  105439:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105440:	00 
  105441:	c7 44 24 04 3e 01 00 	movl   $0x13e,0x4(%esp)
  105448:	00 
  105449:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105450:	e8 a4 af ff ff       	call   1003f9 <__panic>
    free_page(p0);
  105455:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  10545c:	00 
  10545d:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105460:	89 04 24             	mov    %eax,(%esp)
  105463:	e8 3b d9 ff ff       	call   102da3 <free_pages>
    assert((p0 = alloc_pages(2)) == p2 + 1);
  105468:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
  10546f:	e8 f7 d8 ff ff       	call   102d6b <alloc_pages>
  105474:	89 45 e8             	mov    %eax,-0x18(%ebp)
  105477:	8b 45 dc             	mov    -0x24(%ebp),%eax
  10547a:	83 c0 14             	add    $0x14,%eax
  10547d:	39 45 e8             	cmp    %eax,-0x18(%ebp)
  105480:	74 24                	je     1054a6 <default_check+0x4d1>
  105482:	c7 44 24 0c 40 72 10 	movl   $0x107240,0xc(%esp)
  105489:	00 
  10548a:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105491:	00 
  105492:	c7 44 24 04 40 01 00 	movl   $0x140,0x4(%esp)
  105499:	00 
  10549a:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1054a1:	e8 53 af ff ff       	call   1003f9 <__panic>

    free_pages(p0, 2);
  1054a6:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
  1054ad:	00 
  1054ae:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1054b1:	89 04 24             	mov    %eax,(%esp)
  1054b4:	e8 ea d8 ff ff       	call   102da3 <free_pages>
    free_page(p2);
  1054b9:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
  1054c0:	00 
  1054c1:	8b 45 dc             	mov    -0x24(%ebp),%eax
  1054c4:	89 04 24             	mov    %eax,(%esp)
  1054c7:	e8 d7 d8 ff ff       	call   102da3 <free_pages>

    assert((p0 = alloc_pages(5)) != NULL);
  1054cc:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
  1054d3:	e8 93 d8 ff ff       	call   102d6b <alloc_pages>
  1054d8:	89 45 e8             	mov    %eax,-0x18(%ebp)
  1054db:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  1054df:	75 24                	jne    105505 <default_check+0x530>
  1054e1:	c7 44 24 0c 60 72 10 	movl   $0x107260,0xc(%esp)
  1054e8:	00 
  1054e9:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1054f0:	00 
  1054f1:	c7 44 24 04 45 01 00 	movl   $0x145,0x4(%esp)
  1054f8:	00 
  1054f9:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105500:	e8 f4 ae ff ff       	call   1003f9 <__panic>
    assert(alloc_page() == NULL);
  105505:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
  10550c:	e8 5a d8 ff ff       	call   102d6b <alloc_pages>
  105511:	85 c0                	test   %eax,%eax
  105513:	74 24                	je     105539 <default_check+0x564>
  105515:	c7 44 24 0c be 70 10 	movl   $0x1070be,0xc(%esp)
  10551c:	00 
  10551d:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105524:	00 
  105525:	c7 44 24 04 46 01 00 	movl   $0x146,0x4(%esp)
  10552c:	00 
  10552d:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105534:	e8 c0 ae ff ff       	call   1003f9 <__panic>

    assert(nr_free == 0);
  105539:	a1 84 bf 11 00       	mov    0x11bf84,%eax
  10553e:	85 c0                	test   %eax,%eax
  105540:	74 24                	je     105566 <default_check+0x591>
  105542:	c7 44 24 0c 11 71 10 	movl   $0x107111,0xc(%esp)
  105549:	00 
  10554a:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105551:	00 
  105552:	c7 44 24 04 48 01 00 	movl   $0x148,0x4(%esp)
  105559:	00 
  10555a:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105561:	e8 93 ae ff ff       	call   1003f9 <__panic>
    nr_free = nr_free_store;
  105566:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  105569:	a3 84 bf 11 00       	mov    %eax,0x11bf84

    free_list = free_list_store;
  10556e:	8b 45 80             	mov    -0x80(%ebp),%eax
  105571:	8b 55 84             	mov    -0x7c(%ebp),%edx
  105574:	a3 7c bf 11 00       	mov    %eax,0x11bf7c
  105579:	89 15 80 bf 11 00    	mov    %edx,0x11bf80
    free_pages(p0, 5);
  10557f:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
  105586:	00 
  105587:	8b 45 e8             	mov    -0x18(%ebp),%eax
  10558a:	89 04 24             	mov    %eax,(%esp)
  10558d:	e8 11 d8 ff ff       	call   102da3 <free_pages>

    le = &free_list;
  105592:	c7 45 ec 7c bf 11 00 	movl   $0x11bf7c,-0x14(%ebp)
    while ((le = list_next(le)) != &free_list) {
  105599:	eb 5a                	jmp    1055f5 <default_check+0x620>
        assert(le->next->prev == le && le->prev->next == le);
  10559b:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10559e:	8b 40 04             	mov    0x4(%eax),%eax
  1055a1:	8b 00                	mov    (%eax),%eax
  1055a3:	39 45 ec             	cmp    %eax,-0x14(%ebp)
  1055a6:	75 0d                	jne    1055b5 <default_check+0x5e0>
  1055a8:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1055ab:	8b 00                	mov    (%eax),%eax
  1055ad:	8b 40 04             	mov    0x4(%eax),%eax
  1055b0:	39 45 ec             	cmp    %eax,-0x14(%ebp)
  1055b3:	74 24                	je     1055d9 <default_check+0x604>
  1055b5:	c7 44 24 0c 80 72 10 	movl   $0x107280,0xc(%esp)
  1055bc:	00 
  1055bd:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  1055c4:	00 
  1055c5:	c7 44 24 04 50 01 00 	movl   $0x150,0x4(%esp)
  1055cc:	00 
  1055cd:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  1055d4:	e8 20 ae ff ff       	call   1003f9 <__panic>
        struct Page *p = le2page(le, page_link);
  1055d9:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1055dc:	83 e8 0c             	sub    $0xc,%eax
  1055df:	89 45 d8             	mov    %eax,-0x28(%ebp)
        count --, total -= p->property;
  1055e2:	ff 4d f4             	decl   -0xc(%ebp)
  1055e5:	8b 55 f0             	mov    -0x10(%ebp),%edx
  1055e8:	8b 45 d8             	mov    -0x28(%ebp),%eax
  1055eb:	8b 40 08             	mov    0x8(%eax),%eax
  1055ee:	29 c2                	sub    %eax,%edx
  1055f0:	89 d0                	mov    %edx,%eax
  1055f2:	89 45 f0             	mov    %eax,-0x10(%ebp)
  1055f5:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1055f8:	89 45 88             	mov    %eax,-0x78(%ebp)
    return listelm->next;
  1055fb:	8b 45 88             	mov    -0x78(%ebp),%eax
  1055fe:	8b 40 04             	mov    0x4(%eax),%eax
    while ((le = list_next(le)) != &free_list) {
  105601:	89 45 ec             	mov    %eax,-0x14(%ebp)
  105604:	81 7d ec 7c bf 11 00 	cmpl   $0x11bf7c,-0x14(%ebp)
  10560b:	75 8e                	jne    10559b <default_check+0x5c6>
    }
    assert(count == 0);
  10560d:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
  105611:	74 24                	je     105637 <default_check+0x662>
  105613:	c7 44 24 0c ad 72 10 	movl   $0x1072ad,0xc(%esp)
  10561a:	00 
  10561b:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  105622:	00 
  105623:	c7 44 24 04 54 01 00 	movl   $0x154,0x4(%esp)
  10562a:	00 
  10562b:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  105632:	e8 c2 ad ff ff       	call   1003f9 <__panic>
    assert(total == 0);
  105637:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  10563b:	74 24                	je     105661 <default_check+0x68c>
  10563d:	c7 44 24 0c b8 72 10 	movl   $0x1072b8,0xc(%esp)
  105644:	00 
  105645:	c7 44 24 08 1e 6f 10 	movl   $0x106f1e,0x8(%esp)
  10564c:	00 
  10564d:	c7 44 24 04 55 01 00 	movl   $0x155,0x4(%esp)
  105654:	00 
  105655:	c7 04 24 33 6f 10 00 	movl   $0x106f33,(%esp)
  10565c:	e8 98 ad ff ff       	call   1003f9 <__panic>
}
  105661:	90                   	nop
  105662:	c9                   	leave  
  105663:	c3                   	ret    

00105664 <strlen>:
 * @s:      the input string
 *
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
  105664:	55                   	push   %ebp
  105665:	89 e5                	mov    %esp,%ebp
  105667:	83 ec 10             	sub    $0x10,%esp
    size_t cnt = 0;
  10566a:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
    while (*s ++ != '\0') {
  105671:	eb 03                	jmp    105676 <strlen+0x12>
        cnt ++;
  105673:	ff 45 fc             	incl   -0x4(%ebp)
    while (*s ++ != '\0') {
  105676:	8b 45 08             	mov    0x8(%ebp),%eax
  105679:	8d 50 01             	lea    0x1(%eax),%edx
  10567c:	89 55 08             	mov    %edx,0x8(%ebp)
  10567f:	0f b6 00             	movzbl (%eax),%eax
  105682:	84 c0                	test   %al,%al
  105684:	75 ed                	jne    105673 <strlen+0xf>
    }
    return cnt;
  105686:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
  105689:	c9                   	leave  
  10568a:	c3                   	ret    

0010568b <strnlen>:
 * The return value is strlen(s), if that is less than @len, or
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
  10568b:	55                   	push   %ebp
  10568c:	89 e5                	mov    %esp,%ebp
  10568e:	83 ec 10             	sub    $0x10,%esp
    size_t cnt = 0;
  105691:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
    while (cnt < len && *s ++ != '\0') {
  105698:	eb 03                	jmp    10569d <strnlen+0x12>
        cnt ++;
  10569a:	ff 45 fc             	incl   -0x4(%ebp)
    while (cnt < len && *s ++ != '\0') {
  10569d:	8b 45 fc             	mov    -0x4(%ebp),%eax
  1056a0:	3b 45 0c             	cmp    0xc(%ebp),%eax
  1056a3:	73 10                	jae    1056b5 <strnlen+0x2a>
  1056a5:	8b 45 08             	mov    0x8(%ebp),%eax
  1056a8:	8d 50 01             	lea    0x1(%eax),%edx
  1056ab:	89 55 08             	mov    %edx,0x8(%ebp)
  1056ae:	0f b6 00             	movzbl (%eax),%eax
  1056b1:	84 c0                	test   %al,%al
  1056b3:	75 e5                	jne    10569a <strnlen+0xf>
    }
    return cnt;
  1056b5:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
  1056b8:	c9                   	leave  
  1056b9:	c3                   	ret    

001056ba <strcpy>:
 * To avoid overflows, the size of array pointed by @dst should be long enough to
 * contain the same string as @src (including the terminating null character), and
 * should not overlap in memory with @src.
 * */
char *
strcpy(char *dst, const char *src) {
  1056ba:	55                   	push   %ebp
  1056bb:	89 e5                	mov    %esp,%ebp
  1056bd:	57                   	push   %edi
  1056be:	56                   	push   %esi
  1056bf:	83 ec 20             	sub    $0x20,%esp
  1056c2:	8b 45 08             	mov    0x8(%ebp),%eax
  1056c5:	89 45 f4             	mov    %eax,-0xc(%ebp)
  1056c8:	8b 45 0c             	mov    0xc(%ebp),%eax
  1056cb:	89 45 f0             	mov    %eax,-0x10(%ebp)
#ifndef __HAVE_ARCH_STRCPY
#define __HAVE_ARCH_STRCPY
static inline char *
__strcpy(char *dst, const char *src) {
    int d0, d1, d2;
    asm volatile (
  1056ce:	8b 55 f0             	mov    -0x10(%ebp),%edx
  1056d1:	8b 45 f4             	mov    -0xc(%ebp),%eax
  1056d4:	89 d1                	mov    %edx,%ecx
  1056d6:	89 c2                	mov    %eax,%edx
  1056d8:	89 ce                	mov    %ecx,%esi
  1056da:	89 d7                	mov    %edx,%edi
  1056dc:	ac                   	lods   %ds:(%esi),%al
  1056dd:	aa                   	stos   %al,%es:(%edi)
  1056de:	84 c0                	test   %al,%al
  1056e0:	75 fa                	jne    1056dc <strcpy+0x22>
  1056e2:	89 fa                	mov    %edi,%edx
  1056e4:	89 f1                	mov    %esi,%ecx
  1056e6:	89 4d ec             	mov    %ecx,-0x14(%ebp)
  1056e9:	89 55 e8             	mov    %edx,-0x18(%ebp)
  1056ec:	89 45 e4             	mov    %eax,-0x1c(%ebp)
        "stosb;"
        "testb %%al, %%al;"
        "jne 1b;"
        : "=&S" (d0), "=&D" (d1), "=&a" (d2)
        : "0" (src), "1" (dst) : "memory");
    return dst;
  1056ef:	8b 45 f4             	mov    -0xc(%ebp),%eax
#ifdef __HAVE_ARCH_STRCPY
    return __strcpy(dst, src);
  1056f2:	90                   	nop
    char *p = dst;
    while ((*p ++ = *src ++) != '\0')
        /* nothing */;
    return dst;
#endif /* __HAVE_ARCH_STRCPY */
}
  1056f3:	83 c4 20             	add    $0x20,%esp
  1056f6:	5e                   	pop    %esi
  1056f7:	5f                   	pop    %edi
  1056f8:	5d                   	pop    %ebp
  1056f9:	c3                   	ret    

001056fa <strncpy>:
 * @len:    maximum number of characters to be copied from @src
 *
 * The return value is @dst
 * */
char *
strncpy(char *dst, const char *src, size_t len) {
  1056fa:	55                   	push   %ebp
  1056fb:	89 e5                	mov    %esp,%ebp
  1056fd:	83 ec 10             	sub    $0x10,%esp
    char *p = dst;
  105700:	8b 45 08             	mov    0x8(%ebp),%eax
  105703:	89 45 fc             	mov    %eax,-0x4(%ebp)
    while (len > 0) {
  105706:	eb 1e                	jmp    105726 <strncpy+0x2c>
        if ((*p = *src) != '\0') {
  105708:	8b 45 0c             	mov    0xc(%ebp),%eax
  10570b:	0f b6 10             	movzbl (%eax),%edx
  10570e:	8b 45 fc             	mov    -0x4(%ebp),%eax
  105711:	88 10                	mov    %dl,(%eax)
  105713:	8b 45 fc             	mov    -0x4(%ebp),%eax
  105716:	0f b6 00             	movzbl (%eax),%eax
  105719:	84 c0                	test   %al,%al
  10571b:	74 03                	je     105720 <strncpy+0x26>
            src ++;
  10571d:	ff 45 0c             	incl   0xc(%ebp)
        }
        p ++, len --;
  105720:	ff 45 fc             	incl   -0x4(%ebp)
  105723:	ff 4d 10             	decl   0x10(%ebp)
    while (len > 0) {
  105726:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  10572a:	75 dc                	jne    105708 <strncpy+0xe>
    }
    return dst;
  10572c:	8b 45 08             	mov    0x8(%ebp),%eax
}
  10572f:	c9                   	leave  
  105730:	c3                   	ret    

00105731 <strcmp>:
 * - A value greater than zero indicates that the first character that does
 *   not match has a greater value in @s1 than in @s2;
 * - And a value less than zero indicates the opposite.
 * */
int
strcmp(const char *s1, const char *s2) {
  105731:	55                   	push   %ebp
  105732:	89 e5                	mov    %esp,%ebp
  105734:	57                   	push   %edi
  105735:	56                   	push   %esi
  105736:	83 ec 20             	sub    $0x20,%esp
  105739:	8b 45 08             	mov    0x8(%ebp),%eax
  10573c:	89 45 f4             	mov    %eax,-0xc(%ebp)
  10573f:	8b 45 0c             	mov    0xc(%ebp),%eax
  105742:	89 45 f0             	mov    %eax,-0x10(%ebp)
    asm volatile (
  105745:	8b 55 f4             	mov    -0xc(%ebp),%edx
  105748:	8b 45 f0             	mov    -0x10(%ebp),%eax
  10574b:	89 d1                	mov    %edx,%ecx
  10574d:	89 c2                	mov    %eax,%edx
  10574f:	89 ce                	mov    %ecx,%esi
  105751:	89 d7                	mov    %edx,%edi
  105753:	ac                   	lods   %ds:(%esi),%al
  105754:	ae                   	scas   %es:(%edi),%al
  105755:	75 08                	jne    10575f <strcmp+0x2e>
  105757:	84 c0                	test   %al,%al
  105759:	75 f8                	jne    105753 <strcmp+0x22>
  10575b:	31 c0                	xor    %eax,%eax
  10575d:	eb 04                	jmp    105763 <strcmp+0x32>
  10575f:	19 c0                	sbb    %eax,%eax
  105761:	0c 01                	or     $0x1,%al
  105763:	89 fa                	mov    %edi,%edx
  105765:	89 f1                	mov    %esi,%ecx
  105767:	89 45 ec             	mov    %eax,-0x14(%ebp)
  10576a:	89 4d e8             	mov    %ecx,-0x18(%ebp)
  10576d:	89 55 e4             	mov    %edx,-0x1c(%ebp)
    return ret;
  105770:	8b 45 ec             	mov    -0x14(%ebp),%eax
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
  105773:	90                   	nop
    while (*s1 != '\0' && *s1 == *s2) {
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
#endif /* __HAVE_ARCH_STRCMP */
}
  105774:	83 c4 20             	add    $0x20,%esp
  105777:	5e                   	pop    %esi
  105778:	5f                   	pop    %edi
  105779:	5d                   	pop    %ebp
  10577a:	c3                   	ret    

0010577b <strncmp>:
 * they are equal to each other, it continues with the following pairs until
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
  10577b:	55                   	push   %ebp
  10577c:	89 e5                	mov    %esp,%ebp
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
  10577e:	eb 09                	jmp    105789 <strncmp+0xe>
        n --, s1 ++, s2 ++;
  105780:	ff 4d 10             	decl   0x10(%ebp)
  105783:	ff 45 08             	incl   0x8(%ebp)
  105786:	ff 45 0c             	incl   0xc(%ebp)
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
  105789:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  10578d:	74 1a                	je     1057a9 <strncmp+0x2e>
  10578f:	8b 45 08             	mov    0x8(%ebp),%eax
  105792:	0f b6 00             	movzbl (%eax),%eax
  105795:	84 c0                	test   %al,%al
  105797:	74 10                	je     1057a9 <strncmp+0x2e>
  105799:	8b 45 08             	mov    0x8(%ebp),%eax
  10579c:	0f b6 10             	movzbl (%eax),%edx
  10579f:	8b 45 0c             	mov    0xc(%ebp),%eax
  1057a2:	0f b6 00             	movzbl (%eax),%eax
  1057a5:	38 c2                	cmp    %al,%dl
  1057a7:	74 d7                	je     105780 <strncmp+0x5>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
  1057a9:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  1057ad:	74 18                	je     1057c7 <strncmp+0x4c>
  1057af:	8b 45 08             	mov    0x8(%ebp),%eax
  1057b2:	0f b6 00             	movzbl (%eax),%eax
  1057b5:	0f b6 d0             	movzbl %al,%edx
  1057b8:	8b 45 0c             	mov    0xc(%ebp),%eax
  1057bb:	0f b6 00             	movzbl (%eax),%eax
  1057be:	0f b6 c0             	movzbl %al,%eax
  1057c1:	29 c2                	sub    %eax,%edx
  1057c3:	89 d0                	mov    %edx,%eax
  1057c5:	eb 05                	jmp    1057cc <strncmp+0x51>
  1057c7:	b8 00 00 00 00       	mov    $0x0,%eax
}
  1057cc:	5d                   	pop    %ebp
  1057cd:	c3                   	ret    

001057ce <strchr>:
 *
 * The strchr() function returns a pointer to the first occurrence of
 * character in @s. If the value is not found, the function returns 'NULL'.
 * */
char *
strchr(const char *s, char c) {
  1057ce:	55                   	push   %ebp
  1057cf:	89 e5                	mov    %esp,%ebp
  1057d1:	83 ec 04             	sub    $0x4,%esp
  1057d4:	8b 45 0c             	mov    0xc(%ebp),%eax
  1057d7:	88 45 fc             	mov    %al,-0x4(%ebp)
    while (*s != '\0') {
  1057da:	eb 13                	jmp    1057ef <strchr+0x21>
        if (*s == c) {
  1057dc:	8b 45 08             	mov    0x8(%ebp),%eax
  1057df:	0f b6 00             	movzbl (%eax),%eax
  1057e2:	38 45 fc             	cmp    %al,-0x4(%ebp)
  1057e5:	75 05                	jne    1057ec <strchr+0x1e>
            return (char *)s;
  1057e7:	8b 45 08             	mov    0x8(%ebp),%eax
  1057ea:	eb 12                	jmp    1057fe <strchr+0x30>
        }
        s ++;
  1057ec:	ff 45 08             	incl   0x8(%ebp)
    while (*s != '\0') {
  1057ef:	8b 45 08             	mov    0x8(%ebp),%eax
  1057f2:	0f b6 00             	movzbl (%eax),%eax
  1057f5:	84 c0                	test   %al,%al
  1057f7:	75 e3                	jne    1057dc <strchr+0xe>
    }
    return NULL;
  1057f9:	b8 00 00 00 00       	mov    $0x0,%eax
}
  1057fe:	c9                   	leave  
  1057ff:	c3                   	ret    

00105800 <strfind>:
 * The strfind() function is like strchr() except that if @c is
 * not found in @s, then it returns a pointer to the null byte at the
 * end of @s, rather than 'NULL'.
 * */
char *
strfind(const char *s, char c) {
  105800:	55                   	push   %ebp
  105801:	89 e5                	mov    %esp,%ebp
  105803:	83 ec 04             	sub    $0x4,%esp
  105806:	8b 45 0c             	mov    0xc(%ebp),%eax
  105809:	88 45 fc             	mov    %al,-0x4(%ebp)
    while (*s != '\0') {
  10580c:	eb 0e                	jmp    10581c <strfind+0x1c>
        if (*s == c) {
  10580e:	8b 45 08             	mov    0x8(%ebp),%eax
  105811:	0f b6 00             	movzbl (%eax),%eax
  105814:	38 45 fc             	cmp    %al,-0x4(%ebp)
  105817:	74 0f                	je     105828 <strfind+0x28>
            break;
        }
        s ++;
  105819:	ff 45 08             	incl   0x8(%ebp)
    while (*s != '\0') {
  10581c:	8b 45 08             	mov    0x8(%ebp),%eax
  10581f:	0f b6 00             	movzbl (%eax),%eax
  105822:	84 c0                	test   %al,%al
  105824:	75 e8                	jne    10580e <strfind+0xe>
  105826:	eb 01                	jmp    105829 <strfind+0x29>
            break;
  105828:	90                   	nop
    }
    return (char *)s;
  105829:	8b 45 08             	mov    0x8(%ebp),%eax
}
  10582c:	c9                   	leave  
  10582d:	c3                   	ret    

0010582e <strtol>:
 * an optional "0x" or "0X" prefix.
 *
 * The strtol() function returns the converted integral number as a long int value.
 * */
long
strtol(const char *s, char **endptr, int base) {
  10582e:	55                   	push   %ebp
  10582f:	89 e5                	mov    %esp,%ebp
  105831:	83 ec 10             	sub    $0x10,%esp
    int neg = 0;
  105834:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
    long val = 0;
  10583b:	c7 45 f8 00 00 00 00 	movl   $0x0,-0x8(%ebp)

    // gobble initial whitespace
    while (*s == ' ' || *s == '\t') {
  105842:	eb 03                	jmp    105847 <strtol+0x19>
        s ++;
  105844:	ff 45 08             	incl   0x8(%ebp)
    while (*s == ' ' || *s == '\t') {
  105847:	8b 45 08             	mov    0x8(%ebp),%eax
  10584a:	0f b6 00             	movzbl (%eax),%eax
  10584d:	3c 20                	cmp    $0x20,%al
  10584f:	74 f3                	je     105844 <strtol+0x16>
  105851:	8b 45 08             	mov    0x8(%ebp),%eax
  105854:	0f b6 00             	movzbl (%eax),%eax
  105857:	3c 09                	cmp    $0x9,%al
  105859:	74 e9                	je     105844 <strtol+0x16>
    }

    // plus/minus sign
    if (*s == '+') {
  10585b:	8b 45 08             	mov    0x8(%ebp),%eax
  10585e:	0f b6 00             	movzbl (%eax),%eax
  105861:	3c 2b                	cmp    $0x2b,%al
  105863:	75 05                	jne    10586a <strtol+0x3c>
        s ++;
  105865:	ff 45 08             	incl   0x8(%ebp)
  105868:	eb 14                	jmp    10587e <strtol+0x50>
    }
    else if (*s == '-') {
  10586a:	8b 45 08             	mov    0x8(%ebp),%eax
  10586d:	0f b6 00             	movzbl (%eax),%eax
  105870:	3c 2d                	cmp    $0x2d,%al
  105872:	75 0a                	jne    10587e <strtol+0x50>
        s ++, neg = 1;
  105874:	ff 45 08             	incl   0x8(%ebp)
  105877:	c7 45 fc 01 00 00 00 	movl   $0x1,-0x4(%ebp)
    }

    // hex or octal base prefix
    if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x')) {
  10587e:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  105882:	74 06                	je     10588a <strtol+0x5c>
  105884:	83 7d 10 10          	cmpl   $0x10,0x10(%ebp)
  105888:	75 22                	jne    1058ac <strtol+0x7e>
  10588a:	8b 45 08             	mov    0x8(%ebp),%eax
  10588d:	0f b6 00             	movzbl (%eax),%eax
  105890:	3c 30                	cmp    $0x30,%al
  105892:	75 18                	jne    1058ac <strtol+0x7e>
  105894:	8b 45 08             	mov    0x8(%ebp),%eax
  105897:	40                   	inc    %eax
  105898:	0f b6 00             	movzbl (%eax),%eax
  10589b:	3c 78                	cmp    $0x78,%al
  10589d:	75 0d                	jne    1058ac <strtol+0x7e>
        s += 2, base = 16;
  10589f:	83 45 08 02          	addl   $0x2,0x8(%ebp)
  1058a3:	c7 45 10 10 00 00 00 	movl   $0x10,0x10(%ebp)
  1058aa:	eb 29                	jmp    1058d5 <strtol+0xa7>
    }
    else if (base == 0 && s[0] == '0') {
  1058ac:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  1058b0:	75 16                	jne    1058c8 <strtol+0x9a>
  1058b2:	8b 45 08             	mov    0x8(%ebp),%eax
  1058b5:	0f b6 00             	movzbl (%eax),%eax
  1058b8:	3c 30                	cmp    $0x30,%al
  1058ba:	75 0c                	jne    1058c8 <strtol+0x9a>
        s ++, base = 8;
  1058bc:	ff 45 08             	incl   0x8(%ebp)
  1058bf:	c7 45 10 08 00 00 00 	movl   $0x8,0x10(%ebp)
  1058c6:	eb 0d                	jmp    1058d5 <strtol+0xa7>
    }
    else if (base == 0) {
  1058c8:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
  1058cc:	75 07                	jne    1058d5 <strtol+0xa7>
        base = 10;
  1058ce:	c7 45 10 0a 00 00 00 	movl   $0xa,0x10(%ebp)

    // digits
    while (1) {
        int dig;

        if (*s >= '0' && *s <= '9') {
  1058d5:	8b 45 08             	mov    0x8(%ebp),%eax
  1058d8:	0f b6 00             	movzbl (%eax),%eax
  1058db:	3c 2f                	cmp    $0x2f,%al
  1058dd:	7e 1b                	jle    1058fa <strtol+0xcc>
  1058df:	8b 45 08             	mov    0x8(%ebp),%eax
  1058e2:	0f b6 00             	movzbl (%eax),%eax
  1058e5:	3c 39                	cmp    $0x39,%al
  1058e7:	7f 11                	jg     1058fa <strtol+0xcc>
            dig = *s - '0';
  1058e9:	8b 45 08             	mov    0x8(%ebp),%eax
  1058ec:	0f b6 00             	movzbl (%eax),%eax
  1058ef:	0f be c0             	movsbl %al,%eax
  1058f2:	83 e8 30             	sub    $0x30,%eax
  1058f5:	89 45 f4             	mov    %eax,-0xc(%ebp)
  1058f8:	eb 48                	jmp    105942 <strtol+0x114>
        }
        else if (*s >= 'a' && *s <= 'z') {
  1058fa:	8b 45 08             	mov    0x8(%ebp),%eax
  1058fd:	0f b6 00             	movzbl (%eax),%eax
  105900:	3c 60                	cmp    $0x60,%al
  105902:	7e 1b                	jle    10591f <strtol+0xf1>
  105904:	8b 45 08             	mov    0x8(%ebp),%eax
  105907:	0f b6 00             	movzbl (%eax),%eax
  10590a:	3c 7a                	cmp    $0x7a,%al
  10590c:	7f 11                	jg     10591f <strtol+0xf1>
            dig = *s - 'a' + 10;
  10590e:	8b 45 08             	mov    0x8(%ebp),%eax
  105911:	0f b6 00             	movzbl (%eax),%eax
  105914:	0f be c0             	movsbl %al,%eax
  105917:	83 e8 57             	sub    $0x57,%eax
  10591a:	89 45 f4             	mov    %eax,-0xc(%ebp)
  10591d:	eb 23                	jmp    105942 <strtol+0x114>
        }
        else if (*s >= 'A' && *s <= 'Z') {
  10591f:	8b 45 08             	mov    0x8(%ebp),%eax
  105922:	0f b6 00             	movzbl (%eax),%eax
  105925:	3c 40                	cmp    $0x40,%al
  105927:	7e 3b                	jle    105964 <strtol+0x136>
  105929:	8b 45 08             	mov    0x8(%ebp),%eax
  10592c:	0f b6 00             	movzbl (%eax),%eax
  10592f:	3c 5a                	cmp    $0x5a,%al
  105931:	7f 31                	jg     105964 <strtol+0x136>
            dig = *s - 'A' + 10;
  105933:	8b 45 08             	mov    0x8(%ebp),%eax
  105936:	0f b6 00             	movzbl (%eax),%eax
  105939:	0f be c0             	movsbl %al,%eax
  10593c:	83 e8 37             	sub    $0x37,%eax
  10593f:	89 45 f4             	mov    %eax,-0xc(%ebp)
        }
        else {
            break;
        }
        if (dig >= base) {
  105942:	8b 45 f4             	mov    -0xc(%ebp),%eax
  105945:	3b 45 10             	cmp    0x10(%ebp),%eax
  105948:	7d 19                	jge    105963 <strtol+0x135>
            break;
        }
        s ++, val = (val * base) + dig;
  10594a:	ff 45 08             	incl   0x8(%ebp)
  10594d:	8b 45 f8             	mov    -0x8(%ebp),%eax
  105950:	0f af 45 10          	imul   0x10(%ebp),%eax
  105954:	89 c2                	mov    %eax,%edx
  105956:	8b 45 f4             	mov    -0xc(%ebp),%eax
  105959:	01 d0                	add    %edx,%eax
  10595b:	89 45 f8             	mov    %eax,-0x8(%ebp)
    while (1) {
  10595e:	e9 72 ff ff ff       	jmp    1058d5 <strtol+0xa7>
            break;
  105963:	90                   	nop
        // we don't properly detect overflow!
    }

    if (endptr) {
  105964:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
  105968:	74 08                	je     105972 <strtol+0x144>
        *endptr = (char *) s;
  10596a:	8b 45 0c             	mov    0xc(%ebp),%eax
  10596d:	8b 55 08             	mov    0x8(%ebp),%edx
  105970:	89 10                	mov    %edx,(%eax)
    }
    return (neg ? -val : val);
  105972:	83 7d fc 00          	cmpl   $0x0,-0x4(%ebp)
  105976:	74 07                	je     10597f <strtol+0x151>
  105978:	8b 45 f8             	mov    -0x8(%ebp),%eax
  10597b:	f7 d8                	neg    %eax
  10597d:	eb 03                	jmp    105982 <strtol+0x154>
  10597f:	8b 45 f8             	mov    -0x8(%ebp),%eax
}
  105982:	c9                   	leave  
  105983:	c3                   	ret    

00105984 <memset>:
 * @n:      number of bytes to be set to the value
 *
 * The memset() function returns @s.
 * */
void *
memset(void *s, char c, size_t n) {
  105984:	55                   	push   %ebp
  105985:	89 e5                	mov    %esp,%ebp
  105987:	57                   	push   %edi
  105988:	83 ec 24             	sub    $0x24,%esp
  10598b:	8b 45 0c             	mov    0xc(%ebp),%eax
  10598e:	88 45 d8             	mov    %al,-0x28(%ebp)
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
  105991:	0f be 45 d8          	movsbl -0x28(%ebp),%eax
  105995:	8b 55 08             	mov    0x8(%ebp),%edx
  105998:	89 55 f8             	mov    %edx,-0x8(%ebp)
  10599b:	88 45 f7             	mov    %al,-0x9(%ebp)
  10599e:	8b 45 10             	mov    0x10(%ebp),%eax
  1059a1:	89 45 f0             	mov    %eax,-0x10(%ebp)
#ifndef __HAVE_ARCH_MEMSET
#define __HAVE_ARCH_MEMSET
static inline void *
__memset(void *s, char c, size_t n) {
    int d0, d1;
    asm volatile (
  1059a4:	8b 4d f0             	mov    -0x10(%ebp),%ecx
  1059a7:	0f b6 45 f7          	movzbl -0x9(%ebp),%eax
  1059ab:	8b 55 f8             	mov    -0x8(%ebp),%edx
  1059ae:	89 d7                	mov    %edx,%edi
  1059b0:	f3 aa                	rep stos %al,%es:(%edi)
  1059b2:	89 fa                	mov    %edi,%edx
  1059b4:	89 4d ec             	mov    %ecx,-0x14(%ebp)
  1059b7:	89 55 e8             	mov    %edx,-0x18(%ebp)
        "rep; stosb;"
        : "=&c" (d0), "=&D" (d1)
        : "0" (n), "a" (c), "1" (s)
        : "memory");
    return s;
  1059ba:	8b 45 f8             	mov    -0x8(%ebp),%eax
  1059bd:	90                   	nop
    while (n -- > 0) {
        *p ++ = c;
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
  1059be:	83 c4 24             	add    $0x24,%esp
  1059c1:	5f                   	pop    %edi
  1059c2:	5d                   	pop    %ebp
  1059c3:	c3                   	ret    

001059c4 <memmove>:
 * @n:      number of bytes to copy
 *
 * The memmove() function returns @dst.
 * */
void *
memmove(void *dst, const void *src, size_t n) {
  1059c4:	55                   	push   %ebp
  1059c5:	89 e5                	mov    %esp,%ebp
  1059c7:	57                   	push   %edi
  1059c8:	56                   	push   %esi
  1059c9:	53                   	push   %ebx
  1059ca:	83 ec 30             	sub    $0x30,%esp
  1059cd:	8b 45 08             	mov    0x8(%ebp),%eax
  1059d0:	89 45 f0             	mov    %eax,-0x10(%ebp)
  1059d3:	8b 45 0c             	mov    0xc(%ebp),%eax
  1059d6:	89 45 ec             	mov    %eax,-0x14(%ebp)
  1059d9:	8b 45 10             	mov    0x10(%ebp),%eax
  1059dc:	89 45 e8             	mov    %eax,-0x18(%ebp)

#ifndef __HAVE_ARCH_MEMMOVE
#define __HAVE_ARCH_MEMMOVE
static inline void *
__memmove(void *dst, const void *src, size_t n) {
    if (dst < src) {
  1059df:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1059e2:	3b 45 ec             	cmp    -0x14(%ebp),%eax
  1059e5:	73 42                	jae    105a29 <memmove+0x65>
  1059e7:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1059ea:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  1059ed:	8b 45 ec             	mov    -0x14(%ebp),%eax
  1059f0:	89 45 e0             	mov    %eax,-0x20(%ebp)
  1059f3:	8b 45 e8             	mov    -0x18(%ebp),%eax
  1059f6:	89 45 dc             	mov    %eax,-0x24(%ebp)
        "andl $3, %%ecx;"
        "jz 1f;"
        "rep; movsb;"
        "1:"
        : "=&c" (d0), "=&D" (d1), "=&S" (d2)
        : "0" (n / 4), "g" (n), "1" (dst), "2" (src)
  1059f9:	8b 45 dc             	mov    -0x24(%ebp),%eax
  1059fc:	c1 e8 02             	shr    $0x2,%eax
  1059ff:	89 c1                	mov    %eax,%ecx
    asm volatile (
  105a01:	8b 55 e4             	mov    -0x1c(%ebp),%edx
  105a04:	8b 45 e0             	mov    -0x20(%ebp),%eax
  105a07:	89 d7                	mov    %edx,%edi
  105a09:	89 c6                	mov    %eax,%esi
  105a0b:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
  105a0d:	8b 4d dc             	mov    -0x24(%ebp),%ecx
  105a10:	83 e1 03             	and    $0x3,%ecx
  105a13:	74 02                	je     105a17 <memmove+0x53>
  105a15:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
  105a17:	89 f0                	mov    %esi,%eax
  105a19:	89 fa                	mov    %edi,%edx
  105a1b:	89 4d d8             	mov    %ecx,-0x28(%ebp)
  105a1e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
  105a21:	89 45 d0             	mov    %eax,-0x30(%ebp)
        : "memory");
    return dst;
  105a24:	8b 45 e4             	mov    -0x1c(%ebp),%eax
#ifdef __HAVE_ARCH_MEMMOVE
    return __memmove(dst, src, n);
  105a27:	eb 36                	jmp    105a5f <memmove+0x9b>
        : "0" (n), "1" (n - 1 + src), "2" (n - 1 + dst)
  105a29:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105a2c:	8d 50 ff             	lea    -0x1(%eax),%edx
  105a2f:	8b 45 ec             	mov    -0x14(%ebp),%eax
  105a32:	01 c2                	add    %eax,%edx
  105a34:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105a37:	8d 48 ff             	lea    -0x1(%eax),%ecx
  105a3a:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105a3d:	8d 1c 01             	lea    (%ecx,%eax,1),%ebx
    asm volatile (
  105a40:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105a43:	89 c1                	mov    %eax,%ecx
  105a45:	89 d8                	mov    %ebx,%eax
  105a47:	89 d6                	mov    %edx,%esi
  105a49:	89 c7                	mov    %eax,%edi
  105a4b:	fd                   	std    
  105a4c:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
  105a4e:	fc                   	cld    
  105a4f:	89 f8                	mov    %edi,%eax
  105a51:	89 f2                	mov    %esi,%edx
  105a53:	89 4d cc             	mov    %ecx,-0x34(%ebp)
  105a56:	89 55 c8             	mov    %edx,-0x38(%ebp)
  105a59:	89 45 c4             	mov    %eax,-0x3c(%ebp)
    return dst;
  105a5c:	8b 45 f0             	mov    -0x10(%ebp),%eax
            *d ++ = *s ++;
        }
    }
    return dst;
#endif /* __HAVE_ARCH_MEMMOVE */
}
  105a5f:	83 c4 30             	add    $0x30,%esp
  105a62:	5b                   	pop    %ebx
  105a63:	5e                   	pop    %esi
  105a64:	5f                   	pop    %edi
  105a65:	5d                   	pop    %ebp
  105a66:	c3                   	ret    

00105a67 <memcpy>:
 * it always copies exactly @n bytes. To avoid overflows, the size of arrays pointed
 * by both @src and @dst, should be at least @n bytes, and should not overlap
 * (for overlapping memory area, memmove is a safer approach).
 * */
void *
memcpy(void *dst, const void *src, size_t n) {
  105a67:	55                   	push   %ebp
  105a68:	89 e5                	mov    %esp,%ebp
  105a6a:	57                   	push   %edi
  105a6b:	56                   	push   %esi
  105a6c:	83 ec 20             	sub    $0x20,%esp
  105a6f:	8b 45 08             	mov    0x8(%ebp),%eax
  105a72:	89 45 f4             	mov    %eax,-0xc(%ebp)
  105a75:	8b 45 0c             	mov    0xc(%ebp),%eax
  105a78:	89 45 f0             	mov    %eax,-0x10(%ebp)
  105a7b:	8b 45 10             	mov    0x10(%ebp),%eax
  105a7e:	89 45 ec             	mov    %eax,-0x14(%ebp)
        : "0" (n / 4), "g" (n), "1" (dst), "2" (src)
  105a81:	8b 45 ec             	mov    -0x14(%ebp),%eax
  105a84:	c1 e8 02             	shr    $0x2,%eax
  105a87:	89 c1                	mov    %eax,%ecx
    asm volatile (
  105a89:	8b 55 f4             	mov    -0xc(%ebp),%edx
  105a8c:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105a8f:	89 d7                	mov    %edx,%edi
  105a91:	89 c6                	mov    %eax,%esi
  105a93:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
  105a95:	8b 4d ec             	mov    -0x14(%ebp),%ecx
  105a98:	83 e1 03             	and    $0x3,%ecx
  105a9b:	74 02                	je     105a9f <memcpy+0x38>
  105a9d:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
  105a9f:	89 f0                	mov    %esi,%eax
  105aa1:	89 fa                	mov    %edi,%edx
  105aa3:	89 4d e8             	mov    %ecx,-0x18(%ebp)
  105aa6:	89 55 e4             	mov    %edx,-0x1c(%ebp)
  105aa9:	89 45 e0             	mov    %eax,-0x20(%ebp)
    return dst;
  105aac:	8b 45 f4             	mov    -0xc(%ebp),%eax
#ifdef __HAVE_ARCH_MEMCPY
    return __memcpy(dst, src, n);
  105aaf:	90                   	nop
    while (n -- > 0) {
        *d ++ = *s ++;
    }
    return dst;
#endif /* __HAVE_ARCH_MEMCPY */
}
  105ab0:	83 c4 20             	add    $0x20,%esp
  105ab3:	5e                   	pop    %esi
  105ab4:	5f                   	pop    %edi
  105ab5:	5d                   	pop    %ebp
  105ab6:	c3                   	ret    

00105ab7 <memcmp>:
 *   match in both memory blocks has a greater value in @v1 than in @v2
 *   as if evaluated as unsigned char values;
 * - And a value less than zero indicates the opposite.
 * */
int
memcmp(const void *v1, const void *v2, size_t n) {
  105ab7:	55                   	push   %ebp
  105ab8:	89 e5                	mov    %esp,%ebp
  105aba:	83 ec 10             	sub    $0x10,%esp
    const char *s1 = (const char *)v1;
  105abd:	8b 45 08             	mov    0x8(%ebp),%eax
  105ac0:	89 45 fc             	mov    %eax,-0x4(%ebp)
    const char *s2 = (const char *)v2;
  105ac3:	8b 45 0c             	mov    0xc(%ebp),%eax
  105ac6:	89 45 f8             	mov    %eax,-0x8(%ebp)
    while (n -- > 0) {
  105ac9:	eb 2e                	jmp    105af9 <memcmp+0x42>
        if (*s1 != *s2) {
  105acb:	8b 45 fc             	mov    -0x4(%ebp),%eax
  105ace:	0f b6 10             	movzbl (%eax),%edx
  105ad1:	8b 45 f8             	mov    -0x8(%ebp),%eax
  105ad4:	0f b6 00             	movzbl (%eax),%eax
  105ad7:	38 c2                	cmp    %al,%dl
  105ad9:	74 18                	je     105af3 <memcmp+0x3c>
            return (int)((unsigned char)*s1 - (unsigned char)*s2);
  105adb:	8b 45 fc             	mov    -0x4(%ebp),%eax
  105ade:	0f b6 00             	movzbl (%eax),%eax
  105ae1:	0f b6 d0             	movzbl %al,%edx
  105ae4:	8b 45 f8             	mov    -0x8(%ebp),%eax
  105ae7:	0f b6 00             	movzbl (%eax),%eax
  105aea:	0f b6 c0             	movzbl %al,%eax
  105aed:	29 c2                	sub    %eax,%edx
  105aef:	89 d0                	mov    %edx,%eax
  105af1:	eb 18                	jmp    105b0b <memcmp+0x54>
        }
        s1 ++, s2 ++;
  105af3:	ff 45 fc             	incl   -0x4(%ebp)
  105af6:	ff 45 f8             	incl   -0x8(%ebp)
    while (n -- > 0) {
  105af9:	8b 45 10             	mov    0x10(%ebp),%eax
  105afc:	8d 50 ff             	lea    -0x1(%eax),%edx
  105aff:	89 55 10             	mov    %edx,0x10(%ebp)
  105b02:	85 c0                	test   %eax,%eax
  105b04:	75 c5                	jne    105acb <memcmp+0x14>
    }
    return 0;
  105b06:	b8 00 00 00 00       	mov    $0x0,%eax
}
  105b0b:	c9                   	leave  
  105b0c:	c3                   	ret    

00105b0d <printnum>:
 * @width:      maximum number of digits, if the actual width is less than @width, use @padc instead
 * @padc:       character that padded on the left if the actual width is less than @width
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
  105b0d:	55                   	push   %ebp
  105b0e:	89 e5                	mov    %esp,%ebp
  105b10:	83 ec 58             	sub    $0x58,%esp
  105b13:	8b 45 10             	mov    0x10(%ebp),%eax
  105b16:	89 45 d0             	mov    %eax,-0x30(%ebp)
  105b19:	8b 45 14             	mov    0x14(%ebp),%eax
  105b1c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
    unsigned long long result = num;
  105b1f:	8b 45 d0             	mov    -0x30(%ebp),%eax
  105b22:	8b 55 d4             	mov    -0x2c(%ebp),%edx
  105b25:	89 45 e8             	mov    %eax,-0x18(%ebp)
  105b28:	89 55 ec             	mov    %edx,-0x14(%ebp)
    unsigned mod = do_div(result, base);
  105b2b:	8b 45 18             	mov    0x18(%ebp),%eax
  105b2e:	89 45 e4             	mov    %eax,-0x1c(%ebp)
  105b31:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105b34:	8b 55 ec             	mov    -0x14(%ebp),%edx
  105b37:	89 45 e0             	mov    %eax,-0x20(%ebp)
  105b3a:	89 55 f0             	mov    %edx,-0x10(%ebp)
  105b3d:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105b40:	89 45 f4             	mov    %eax,-0xc(%ebp)
  105b43:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
  105b47:	74 1c                	je     105b65 <printnum+0x58>
  105b49:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105b4c:	ba 00 00 00 00       	mov    $0x0,%edx
  105b51:	f7 75 e4             	divl   -0x1c(%ebp)
  105b54:	89 55 f4             	mov    %edx,-0xc(%ebp)
  105b57:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105b5a:	ba 00 00 00 00       	mov    $0x0,%edx
  105b5f:	f7 75 e4             	divl   -0x1c(%ebp)
  105b62:	89 45 f0             	mov    %eax,-0x10(%ebp)
  105b65:	8b 45 e0             	mov    -0x20(%ebp),%eax
  105b68:	8b 55 f4             	mov    -0xc(%ebp),%edx
  105b6b:	f7 75 e4             	divl   -0x1c(%ebp)
  105b6e:	89 45 e0             	mov    %eax,-0x20(%ebp)
  105b71:	89 55 dc             	mov    %edx,-0x24(%ebp)
  105b74:	8b 45 e0             	mov    -0x20(%ebp),%eax
  105b77:	8b 55 f0             	mov    -0x10(%ebp),%edx
  105b7a:	89 45 e8             	mov    %eax,-0x18(%ebp)
  105b7d:	89 55 ec             	mov    %edx,-0x14(%ebp)
  105b80:	8b 45 dc             	mov    -0x24(%ebp),%eax
  105b83:	89 45 d8             	mov    %eax,-0x28(%ebp)

    // first recursively print all preceding (more significant) digits
    if (num >= base) {
  105b86:	8b 45 18             	mov    0x18(%ebp),%eax
  105b89:	ba 00 00 00 00       	mov    $0x0,%edx
  105b8e:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
  105b91:	72 56                	jb     105be9 <printnum+0xdc>
  105b93:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
  105b96:	77 05                	ja     105b9d <printnum+0x90>
  105b98:	39 45 d0             	cmp    %eax,-0x30(%ebp)
  105b9b:	72 4c                	jb     105be9 <printnum+0xdc>
        printnum(putch, putdat, result, base, width - 1, padc);
  105b9d:	8b 45 1c             	mov    0x1c(%ebp),%eax
  105ba0:	8d 50 ff             	lea    -0x1(%eax),%edx
  105ba3:	8b 45 20             	mov    0x20(%ebp),%eax
  105ba6:	89 44 24 18          	mov    %eax,0x18(%esp)
  105baa:	89 54 24 14          	mov    %edx,0x14(%esp)
  105bae:	8b 45 18             	mov    0x18(%ebp),%eax
  105bb1:	89 44 24 10          	mov    %eax,0x10(%esp)
  105bb5:	8b 45 e8             	mov    -0x18(%ebp),%eax
  105bb8:	8b 55 ec             	mov    -0x14(%ebp),%edx
  105bbb:	89 44 24 08          	mov    %eax,0x8(%esp)
  105bbf:	89 54 24 0c          	mov    %edx,0xc(%esp)
  105bc3:	8b 45 0c             	mov    0xc(%ebp),%eax
  105bc6:	89 44 24 04          	mov    %eax,0x4(%esp)
  105bca:	8b 45 08             	mov    0x8(%ebp),%eax
  105bcd:	89 04 24             	mov    %eax,(%esp)
  105bd0:	e8 38 ff ff ff       	call   105b0d <printnum>
  105bd5:	eb 1b                	jmp    105bf2 <printnum+0xe5>
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
            putch(padc, putdat);
  105bd7:	8b 45 0c             	mov    0xc(%ebp),%eax
  105bda:	89 44 24 04          	mov    %eax,0x4(%esp)
  105bde:	8b 45 20             	mov    0x20(%ebp),%eax
  105be1:	89 04 24             	mov    %eax,(%esp)
  105be4:	8b 45 08             	mov    0x8(%ebp),%eax
  105be7:	ff d0                	call   *%eax
        while (-- width > 0)
  105be9:	ff 4d 1c             	decl   0x1c(%ebp)
  105bec:	83 7d 1c 00          	cmpl   $0x0,0x1c(%ebp)
  105bf0:	7f e5                	jg     105bd7 <printnum+0xca>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
  105bf2:	8b 45 d8             	mov    -0x28(%ebp),%eax
  105bf5:	05 74 73 10 00       	add    $0x107374,%eax
  105bfa:	0f b6 00             	movzbl (%eax),%eax
  105bfd:	0f be c0             	movsbl %al,%eax
  105c00:	8b 55 0c             	mov    0xc(%ebp),%edx
  105c03:	89 54 24 04          	mov    %edx,0x4(%esp)
  105c07:	89 04 24             	mov    %eax,(%esp)
  105c0a:	8b 45 08             	mov    0x8(%ebp),%eax
  105c0d:	ff d0                	call   *%eax
}
  105c0f:	90                   	nop
  105c10:	c9                   	leave  
  105c11:	c3                   	ret    

00105c12 <getuint>:
 * getuint - get an unsigned int of various possible sizes from a varargs list
 * @ap:         a varargs list pointer
 * @lflag:      determines the size of the vararg that @ap points to
 * */
static unsigned long long
getuint(va_list *ap, int lflag) {
  105c12:	55                   	push   %ebp
  105c13:	89 e5                	mov    %esp,%ebp
    if (lflag >= 2) {
  105c15:	83 7d 0c 01          	cmpl   $0x1,0xc(%ebp)
  105c19:	7e 14                	jle    105c2f <getuint+0x1d>
        return va_arg(*ap, unsigned long long);
  105c1b:	8b 45 08             	mov    0x8(%ebp),%eax
  105c1e:	8b 00                	mov    (%eax),%eax
  105c20:	8d 48 08             	lea    0x8(%eax),%ecx
  105c23:	8b 55 08             	mov    0x8(%ebp),%edx
  105c26:	89 0a                	mov    %ecx,(%edx)
  105c28:	8b 50 04             	mov    0x4(%eax),%edx
  105c2b:	8b 00                	mov    (%eax),%eax
  105c2d:	eb 30                	jmp    105c5f <getuint+0x4d>
    }
    else if (lflag) {
  105c2f:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
  105c33:	74 16                	je     105c4b <getuint+0x39>
        return va_arg(*ap, unsigned long);
  105c35:	8b 45 08             	mov    0x8(%ebp),%eax
  105c38:	8b 00                	mov    (%eax),%eax
  105c3a:	8d 48 04             	lea    0x4(%eax),%ecx
  105c3d:	8b 55 08             	mov    0x8(%ebp),%edx
  105c40:	89 0a                	mov    %ecx,(%edx)
  105c42:	8b 00                	mov    (%eax),%eax
  105c44:	ba 00 00 00 00       	mov    $0x0,%edx
  105c49:	eb 14                	jmp    105c5f <getuint+0x4d>
    }
    else {
        return va_arg(*ap, unsigned int);
  105c4b:	8b 45 08             	mov    0x8(%ebp),%eax
  105c4e:	8b 00                	mov    (%eax),%eax
  105c50:	8d 48 04             	lea    0x4(%eax),%ecx
  105c53:	8b 55 08             	mov    0x8(%ebp),%edx
  105c56:	89 0a                	mov    %ecx,(%edx)
  105c58:	8b 00                	mov    (%eax),%eax
  105c5a:	ba 00 00 00 00       	mov    $0x0,%edx
    }
}
  105c5f:	5d                   	pop    %ebp
  105c60:	c3                   	ret    

00105c61 <getint>:
 * getint - same as getuint but signed, we can't use getuint because of sign extension
 * @ap:         a varargs list pointer
 * @lflag:      determines the size of the vararg that @ap points to
 * */
static long long
getint(va_list *ap, int lflag) {
  105c61:	55                   	push   %ebp
  105c62:	89 e5                	mov    %esp,%ebp
    if (lflag >= 2) {
  105c64:	83 7d 0c 01          	cmpl   $0x1,0xc(%ebp)
  105c68:	7e 14                	jle    105c7e <getint+0x1d>
        return va_arg(*ap, long long);
  105c6a:	8b 45 08             	mov    0x8(%ebp),%eax
  105c6d:	8b 00                	mov    (%eax),%eax
  105c6f:	8d 48 08             	lea    0x8(%eax),%ecx
  105c72:	8b 55 08             	mov    0x8(%ebp),%edx
  105c75:	89 0a                	mov    %ecx,(%edx)
  105c77:	8b 50 04             	mov    0x4(%eax),%edx
  105c7a:	8b 00                	mov    (%eax),%eax
  105c7c:	eb 28                	jmp    105ca6 <getint+0x45>
    }
    else if (lflag) {
  105c7e:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
  105c82:	74 12                	je     105c96 <getint+0x35>
        return va_arg(*ap, long);
  105c84:	8b 45 08             	mov    0x8(%ebp),%eax
  105c87:	8b 00                	mov    (%eax),%eax
  105c89:	8d 48 04             	lea    0x4(%eax),%ecx
  105c8c:	8b 55 08             	mov    0x8(%ebp),%edx
  105c8f:	89 0a                	mov    %ecx,(%edx)
  105c91:	8b 00                	mov    (%eax),%eax
  105c93:	99                   	cltd   
  105c94:	eb 10                	jmp    105ca6 <getint+0x45>
    }
    else {
        return va_arg(*ap, int);
  105c96:	8b 45 08             	mov    0x8(%ebp),%eax
  105c99:	8b 00                	mov    (%eax),%eax
  105c9b:	8d 48 04             	lea    0x4(%eax),%ecx
  105c9e:	8b 55 08             	mov    0x8(%ebp),%edx
  105ca1:	89 0a                	mov    %ecx,(%edx)
  105ca3:	8b 00                	mov    (%eax),%eax
  105ca5:	99                   	cltd   
    }
}
  105ca6:	5d                   	pop    %ebp
  105ca7:	c3                   	ret    

00105ca8 <printfmt>:
 * @putch:      specified putch function, print a single character
 * @putdat:     used by @putch function
 * @fmt:        the format string to use
 * */
void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
  105ca8:	55                   	push   %ebp
  105ca9:	89 e5                	mov    %esp,%ebp
  105cab:	83 ec 28             	sub    $0x28,%esp
    va_list ap;

    va_start(ap, fmt);
  105cae:	8d 45 14             	lea    0x14(%ebp),%eax
  105cb1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    vprintfmt(putch, putdat, fmt, ap);
  105cb4:	8b 45 f4             	mov    -0xc(%ebp),%eax
  105cb7:	89 44 24 0c          	mov    %eax,0xc(%esp)
  105cbb:	8b 45 10             	mov    0x10(%ebp),%eax
  105cbe:	89 44 24 08          	mov    %eax,0x8(%esp)
  105cc2:	8b 45 0c             	mov    0xc(%ebp),%eax
  105cc5:	89 44 24 04          	mov    %eax,0x4(%esp)
  105cc9:	8b 45 08             	mov    0x8(%ebp),%eax
  105ccc:	89 04 24             	mov    %eax,(%esp)
  105ccf:	e8 03 00 00 00       	call   105cd7 <vprintfmt>
    va_end(ap);
}
  105cd4:	90                   	nop
  105cd5:	c9                   	leave  
  105cd6:	c3                   	ret    

00105cd7 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
  105cd7:	55                   	push   %ebp
  105cd8:	89 e5                	mov    %esp,%ebp
  105cda:	56                   	push   %esi
  105cdb:	53                   	push   %ebx
  105cdc:	83 ec 40             	sub    $0x40,%esp
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
  105cdf:	eb 17                	jmp    105cf8 <vprintfmt+0x21>
            if (ch == '\0') {
  105ce1:	85 db                	test   %ebx,%ebx
  105ce3:	0f 84 bf 03 00 00    	je     1060a8 <vprintfmt+0x3d1>
                return;
            }
            putch(ch, putdat);
  105ce9:	8b 45 0c             	mov    0xc(%ebp),%eax
  105cec:	89 44 24 04          	mov    %eax,0x4(%esp)
  105cf0:	89 1c 24             	mov    %ebx,(%esp)
  105cf3:	8b 45 08             	mov    0x8(%ebp),%eax
  105cf6:	ff d0                	call   *%eax
        while ((ch = *(unsigned char *)fmt ++) != '%') {
  105cf8:	8b 45 10             	mov    0x10(%ebp),%eax
  105cfb:	8d 50 01             	lea    0x1(%eax),%edx
  105cfe:	89 55 10             	mov    %edx,0x10(%ebp)
  105d01:	0f b6 00             	movzbl (%eax),%eax
  105d04:	0f b6 d8             	movzbl %al,%ebx
  105d07:	83 fb 25             	cmp    $0x25,%ebx
  105d0a:	75 d5                	jne    105ce1 <vprintfmt+0xa>
        }

        // Process a %-escape sequence
        char padc = ' ';
  105d0c:	c6 45 db 20          	movb   $0x20,-0x25(%ebp)
        width = precision = -1;
  105d10:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
  105d17:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  105d1a:	89 45 e8             	mov    %eax,-0x18(%ebp)
        lflag = altflag = 0;
  105d1d:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
  105d24:	8b 45 dc             	mov    -0x24(%ebp),%eax
  105d27:	89 45 e0             	mov    %eax,-0x20(%ebp)

    reswitch:
        switch (ch = *(unsigned char *)fmt ++) {
  105d2a:	8b 45 10             	mov    0x10(%ebp),%eax
  105d2d:	8d 50 01             	lea    0x1(%eax),%edx
  105d30:	89 55 10             	mov    %edx,0x10(%ebp)
  105d33:	0f b6 00             	movzbl (%eax),%eax
  105d36:	0f b6 d8             	movzbl %al,%ebx
  105d39:	8d 43 dd             	lea    -0x23(%ebx),%eax
  105d3c:	83 f8 55             	cmp    $0x55,%eax
  105d3f:	0f 87 37 03 00 00    	ja     10607c <vprintfmt+0x3a5>
  105d45:	8b 04 85 98 73 10 00 	mov    0x107398(,%eax,4),%eax
  105d4c:	ff e0                	jmp    *%eax

        // flag to pad on the right
        case '-':
            padc = '-';
  105d4e:	c6 45 db 2d          	movb   $0x2d,-0x25(%ebp)
            goto reswitch;
  105d52:	eb d6                	jmp    105d2a <vprintfmt+0x53>

        // flag to pad with 0's instead of spaces
        case '0':
            padc = '0';
  105d54:	c6 45 db 30          	movb   $0x30,-0x25(%ebp)
            goto reswitch;
  105d58:	eb d0                	jmp    105d2a <vprintfmt+0x53>

        // width field
        case '1' ... '9':
            for (precision = 0; ; ++ fmt) {
  105d5a:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
                precision = precision * 10 + ch - '0';
  105d61:	8b 55 e4             	mov    -0x1c(%ebp),%edx
  105d64:	89 d0                	mov    %edx,%eax
  105d66:	c1 e0 02             	shl    $0x2,%eax
  105d69:	01 d0                	add    %edx,%eax
  105d6b:	01 c0                	add    %eax,%eax
  105d6d:	01 d8                	add    %ebx,%eax
  105d6f:	83 e8 30             	sub    $0x30,%eax
  105d72:	89 45 e4             	mov    %eax,-0x1c(%ebp)
                ch = *fmt;
  105d75:	8b 45 10             	mov    0x10(%ebp),%eax
  105d78:	0f b6 00             	movzbl (%eax),%eax
  105d7b:	0f be d8             	movsbl %al,%ebx
                if (ch < '0' || ch > '9') {
  105d7e:	83 fb 2f             	cmp    $0x2f,%ebx
  105d81:	7e 38                	jle    105dbb <vprintfmt+0xe4>
  105d83:	83 fb 39             	cmp    $0x39,%ebx
  105d86:	7f 33                	jg     105dbb <vprintfmt+0xe4>
            for (precision = 0; ; ++ fmt) {
  105d88:	ff 45 10             	incl   0x10(%ebp)
                precision = precision * 10 + ch - '0';
  105d8b:	eb d4                	jmp    105d61 <vprintfmt+0x8a>
                }
            }
            goto process_precision;

        case '*':
            precision = va_arg(ap, int);
  105d8d:	8b 45 14             	mov    0x14(%ebp),%eax
  105d90:	8d 50 04             	lea    0x4(%eax),%edx
  105d93:	89 55 14             	mov    %edx,0x14(%ebp)
  105d96:	8b 00                	mov    (%eax),%eax
  105d98:	89 45 e4             	mov    %eax,-0x1c(%ebp)
            goto process_precision;
  105d9b:	eb 1f                	jmp    105dbc <vprintfmt+0xe5>

        case '.':
            if (width < 0)
  105d9d:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  105da1:	79 87                	jns    105d2a <vprintfmt+0x53>
                width = 0;
  105da3:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
            goto reswitch;
  105daa:	e9 7b ff ff ff       	jmp    105d2a <vprintfmt+0x53>

        case '#':
            altflag = 1;
  105daf:	c7 45 dc 01 00 00 00 	movl   $0x1,-0x24(%ebp)
            goto reswitch;
  105db6:	e9 6f ff ff ff       	jmp    105d2a <vprintfmt+0x53>
            goto process_precision;
  105dbb:	90                   	nop

        process_precision:
            if (width < 0)
  105dbc:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  105dc0:	0f 89 64 ff ff ff    	jns    105d2a <vprintfmt+0x53>
                width = precision, precision = -1;
  105dc6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  105dc9:	89 45 e8             	mov    %eax,-0x18(%ebp)
  105dcc:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
            goto reswitch;
  105dd3:	e9 52 ff ff ff       	jmp    105d2a <vprintfmt+0x53>

        // long flag (doubled for long long)
        case 'l':
            lflag ++;
  105dd8:	ff 45 e0             	incl   -0x20(%ebp)
            goto reswitch;
  105ddb:	e9 4a ff ff ff       	jmp    105d2a <vprintfmt+0x53>

        // character
        case 'c':
            putch(va_arg(ap, int), putdat);
  105de0:	8b 45 14             	mov    0x14(%ebp),%eax
  105de3:	8d 50 04             	lea    0x4(%eax),%edx
  105de6:	89 55 14             	mov    %edx,0x14(%ebp)
  105de9:	8b 00                	mov    (%eax),%eax
  105deb:	8b 55 0c             	mov    0xc(%ebp),%edx
  105dee:	89 54 24 04          	mov    %edx,0x4(%esp)
  105df2:	89 04 24             	mov    %eax,(%esp)
  105df5:	8b 45 08             	mov    0x8(%ebp),%eax
  105df8:	ff d0                	call   *%eax
            break;
  105dfa:	e9 a4 02 00 00       	jmp    1060a3 <vprintfmt+0x3cc>

        // error message
        case 'e':
            err = va_arg(ap, int);
  105dff:	8b 45 14             	mov    0x14(%ebp),%eax
  105e02:	8d 50 04             	lea    0x4(%eax),%edx
  105e05:	89 55 14             	mov    %edx,0x14(%ebp)
  105e08:	8b 18                	mov    (%eax),%ebx
            if (err < 0) {
  105e0a:	85 db                	test   %ebx,%ebx
  105e0c:	79 02                	jns    105e10 <vprintfmt+0x139>
                err = -err;
  105e0e:	f7 db                	neg    %ebx
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
  105e10:	83 fb 06             	cmp    $0x6,%ebx
  105e13:	7f 0b                	jg     105e20 <vprintfmt+0x149>
  105e15:	8b 34 9d 58 73 10 00 	mov    0x107358(,%ebx,4),%esi
  105e1c:	85 f6                	test   %esi,%esi
  105e1e:	75 23                	jne    105e43 <vprintfmt+0x16c>
                printfmt(putch, putdat, "error %d", err);
  105e20:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
  105e24:	c7 44 24 08 85 73 10 	movl   $0x107385,0x8(%esp)
  105e2b:	00 
  105e2c:	8b 45 0c             	mov    0xc(%ebp),%eax
  105e2f:	89 44 24 04          	mov    %eax,0x4(%esp)
  105e33:	8b 45 08             	mov    0x8(%ebp),%eax
  105e36:	89 04 24             	mov    %eax,(%esp)
  105e39:	e8 6a fe ff ff       	call   105ca8 <printfmt>
            }
            else {
                printfmt(putch, putdat, "%s", p);
            }
            break;
  105e3e:	e9 60 02 00 00       	jmp    1060a3 <vprintfmt+0x3cc>
                printfmt(putch, putdat, "%s", p);
  105e43:	89 74 24 0c          	mov    %esi,0xc(%esp)
  105e47:	c7 44 24 08 8e 73 10 	movl   $0x10738e,0x8(%esp)
  105e4e:	00 
  105e4f:	8b 45 0c             	mov    0xc(%ebp),%eax
  105e52:	89 44 24 04          	mov    %eax,0x4(%esp)
  105e56:	8b 45 08             	mov    0x8(%ebp),%eax
  105e59:	89 04 24             	mov    %eax,(%esp)
  105e5c:	e8 47 fe ff ff       	call   105ca8 <printfmt>
            break;
  105e61:	e9 3d 02 00 00       	jmp    1060a3 <vprintfmt+0x3cc>

        // string
        case 's':
            if ((p = va_arg(ap, char *)) == NULL) {
  105e66:	8b 45 14             	mov    0x14(%ebp),%eax
  105e69:	8d 50 04             	lea    0x4(%eax),%edx
  105e6c:	89 55 14             	mov    %edx,0x14(%ebp)
  105e6f:	8b 30                	mov    (%eax),%esi
  105e71:	85 f6                	test   %esi,%esi
  105e73:	75 05                	jne    105e7a <vprintfmt+0x1a3>
                p = "(null)";
  105e75:	be 91 73 10 00       	mov    $0x107391,%esi
            }
            if (width > 0 && padc != '-') {
  105e7a:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  105e7e:	7e 76                	jle    105ef6 <vprintfmt+0x21f>
  105e80:	80 7d db 2d          	cmpb   $0x2d,-0x25(%ebp)
  105e84:	74 70                	je     105ef6 <vprintfmt+0x21f>
                for (width -= strnlen(p, precision); width > 0; width --) {
  105e86:	8b 45 e4             	mov    -0x1c(%ebp),%eax
  105e89:	89 44 24 04          	mov    %eax,0x4(%esp)
  105e8d:	89 34 24             	mov    %esi,(%esp)
  105e90:	e8 f6 f7 ff ff       	call   10568b <strnlen>
  105e95:	8b 55 e8             	mov    -0x18(%ebp),%edx
  105e98:	29 c2                	sub    %eax,%edx
  105e9a:	89 d0                	mov    %edx,%eax
  105e9c:	89 45 e8             	mov    %eax,-0x18(%ebp)
  105e9f:	eb 16                	jmp    105eb7 <vprintfmt+0x1e0>
                    putch(padc, putdat);
  105ea1:	0f be 45 db          	movsbl -0x25(%ebp),%eax
  105ea5:	8b 55 0c             	mov    0xc(%ebp),%edx
  105ea8:	89 54 24 04          	mov    %edx,0x4(%esp)
  105eac:	89 04 24             	mov    %eax,(%esp)
  105eaf:	8b 45 08             	mov    0x8(%ebp),%eax
  105eb2:	ff d0                	call   *%eax
                for (width -= strnlen(p, precision); width > 0; width --) {
  105eb4:	ff 4d e8             	decl   -0x18(%ebp)
  105eb7:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  105ebb:	7f e4                	jg     105ea1 <vprintfmt+0x1ca>
                }
            }
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
  105ebd:	eb 37                	jmp    105ef6 <vprintfmt+0x21f>
                if (altflag && (ch < ' ' || ch > '~')) {
  105ebf:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
  105ec3:	74 1f                	je     105ee4 <vprintfmt+0x20d>
  105ec5:	83 fb 1f             	cmp    $0x1f,%ebx
  105ec8:	7e 05                	jle    105ecf <vprintfmt+0x1f8>
  105eca:	83 fb 7e             	cmp    $0x7e,%ebx
  105ecd:	7e 15                	jle    105ee4 <vprintfmt+0x20d>
                    putch('?', putdat);
  105ecf:	8b 45 0c             	mov    0xc(%ebp),%eax
  105ed2:	89 44 24 04          	mov    %eax,0x4(%esp)
  105ed6:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
  105edd:	8b 45 08             	mov    0x8(%ebp),%eax
  105ee0:	ff d0                	call   *%eax
  105ee2:	eb 0f                	jmp    105ef3 <vprintfmt+0x21c>
                }
                else {
                    putch(ch, putdat);
  105ee4:	8b 45 0c             	mov    0xc(%ebp),%eax
  105ee7:	89 44 24 04          	mov    %eax,0x4(%esp)
  105eeb:	89 1c 24             	mov    %ebx,(%esp)
  105eee:	8b 45 08             	mov    0x8(%ebp),%eax
  105ef1:	ff d0                	call   *%eax
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
  105ef3:	ff 4d e8             	decl   -0x18(%ebp)
  105ef6:	89 f0                	mov    %esi,%eax
  105ef8:	8d 70 01             	lea    0x1(%eax),%esi
  105efb:	0f b6 00             	movzbl (%eax),%eax
  105efe:	0f be d8             	movsbl %al,%ebx
  105f01:	85 db                	test   %ebx,%ebx
  105f03:	74 27                	je     105f2c <vprintfmt+0x255>
  105f05:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
  105f09:	78 b4                	js     105ebf <vprintfmt+0x1e8>
  105f0b:	ff 4d e4             	decl   -0x1c(%ebp)
  105f0e:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
  105f12:	79 ab                	jns    105ebf <vprintfmt+0x1e8>
                }
            }
            for (; width > 0; width --) {
  105f14:	eb 16                	jmp    105f2c <vprintfmt+0x255>
                putch(' ', putdat);
  105f16:	8b 45 0c             	mov    0xc(%ebp),%eax
  105f19:	89 44 24 04          	mov    %eax,0x4(%esp)
  105f1d:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
  105f24:	8b 45 08             	mov    0x8(%ebp),%eax
  105f27:	ff d0                	call   *%eax
            for (; width > 0; width --) {
  105f29:	ff 4d e8             	decl   -0x18(%ebp)
  105f2c:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
  105f30:	7f e4                	jg     105f16 <vprintfmt+0x23f>
            }
            break;
  105f32:	e9 6c 01 00 00       	jmp    1060a3 <vprintfmt+0x3cc>

        // (signed) decimal
        case 'd':
            num = getint(&ap, lflag);
  105f37:	8b 45 e0             	mov    -0x20(%ebp),%eax
  105f3a:	89 44 24 04          	mov    %eax,0x4(%esp)
  105f3e:	8d 45 14             	lea    0x14(%ebp),%eax
  105f41:	89 04 24             	mov    %eax,(%esp)
  105f44:	e8 18 fd ff ff       	call   105c61 <getint>
  105f49:	89 45 f0             	mov    %eax,-0x10(%ebp)
  105f4c:	89 55 f4             	mov    %edx,-0xc(%ebp)
            if ((long long)num < 0) {
  105f4f:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105f52:	8b 55 f4             	mov    -0xc(%ebp),%edx
  105f55:	85 d2                	test   %edx,%edx
  105f57:	79 26                	jns    105f7f <vprintfmt+0x2a8>
                putch('-', putdat);
  105f59:	8b 45 0c             	mov    0xc(%ebp),%eax
  105f5c:	89 44 24 04          	mov    %eax,0x4(%esp)
  105f60:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
  105f67:	8b 45 08             	mov    0x8(%ebp),%eax
  105f6a:	ff d0                	call   *%eax
                num = -(long long)num;
  105f6c:	8b 45 f0             	mov    -0x10(%ebp),%eax
  105f6f:	8b 55 f4             	mov    -0xc(%ebp),%edx
  105f72:	f7 d8                	neg    %eax
  105f74:	83 d2 00             	adc    $0x0,%edx
  105f77:	f7 da                	neg    %edx
  105f79:	89 45 f0             	mov    %eax,-0x10(%ebp)
  105f7c:	89 55 f4             	mov    %edx,-0xc(%ebp)
            }
            base = 10;
  105f7f:	c7 45 ec 0a 00 00 00 	movl   $0xa,-0x14(%ebp)
            goto number;
  105f86:	e9 a8 00 00 00       	jmp    106033 <vprintfmt+0x35c>

        // unsigned decimal
        case 'u':
            num = getuint(&ap, lflag);
  105f8b:	8b 45 e0             	mov    -0x20(%ebp),%eax
  105f8e:	89 44 24 04          	mov    %eax,0x4(%esp)
  105f92:	8d 45 14             	lea    0x14(%ebp),%eax
  105f95:	89 04 24             	mov    %eax,(%esp)
  105f98:	e8 75 fc ff ff       	call   105c12 <getuint>
  105f9d:	89 45 f0             	mov    %eax,-0x10(%ebp)
  105fa0:	89 55 f4             	mov    %edx,-0xc(%ebp)
            base = 10;
  105fa3:	c7 45 ec 0a 00 00 00 	movl   $0xa,-0x14(%ebp)
            goto number;
  105faa:	e9 84 00 00 00       	jmp    106033 <vprintfmt+0x35c>

        // (unsigned) octal
        case 'o':
            num = getuint(&ap, lflag);
  105faf:	8b 45 e0             	mov    -0x20(%ebp),%eax
  105fb2:	89 44 24 04          	mov    %eax,0x4(%esp)
  105fb6:	8d 45 14             	lea    0x14(%ebp),%eax
  105fb9:	89 04 24             	mov    %eax,(%esp)
  105fbc:	e8 51 fc ff ff       	call   105c12 <getuint>
  105fc1:	89 45 f0             	mov    %eax,-0x10(%ebp)
  105fc4:	89 55 f4             	mov    %edx,-0xc(%ebp)
            base = 8;
  105fc7:	c7 45 ec 08 00 00 00 	movl   $0x8,-0x14(%ebp)
            goto number;
  105fce:	eb 63                	jmp    106033 <vprintfmt+0x35c>

        // pointer
        case 'p':
            putch('0', putdat);
  105fd0:	8b 45 0c             	mov    0xc(%ebp),%eax
  105fd3:	89 44 24 04          	mov    %eax,0x4(%esp)
  105fd7:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
  105fde:	8b 45 08             	mov    0x8(%ebp),%eax
  105fe1:	ff d0                	call   *%eax
            putch('x', putdat);
  105fe3:	8b 45 0c             	mov    0xc(%ebp),%eax
  105fe6:	89 44 24 04          	mov    %eax,0x4(%esp)
  105fea:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
  105ff1:	8b 45 08             	mov    0x8(%ebp),%eax
  105ff4:	ff d0                	call   *%eax
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
  105ff6:	8b 45 14             	mov    0x14(%ebp),%eax
  105ff9:	8d 50 04             	lea    0x4(%eax),%edx
  105ffc:	89 55 14             	mov    %edx,0x14(%ebp)
  105fff:	8b 00                	mov    (%eax),%eax
  106001:	89 45 f0             	mov    %eax,-0x10(%ebp)
  106004:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
            base = 16;
  10600b:	c7 45 ec 10 00 00 00 	movl   $0x10,-0x14(%ebp)
            goto number;
  106012:	eb 1f                	jmp    106033 <vprintfmt+0x35c>

        // (unsigned) hexadecimal
        case 'x':
            num = getuint(&ap, lflag);
  106014:	8b 45 e0             	mov    -0x20(%ebp),%eax
  106017:	89 44 24 04          	mov    %eax,0x4(%esp)
  10601b:	8d 45 14             	lea    0x14(%ebp),%eax
  10601e:	89 04 24             	mov    %eax,(%esp)
  106021:	e8 ec fb ff ff       	call   105c12 <getuint>
  106026:	89 45 f0             	mov    %eax,-0x10(%ebp)
  106029:	89 55 f4             	mov    %edx,-0xc(%ebp)
            base = 16;
  10602c:	c7 45 ec 10 00 00 00 	movl   $0x10,-0x14(%ebp)
        number:
            printnum(putch, putdat, num, base, width, padc);
  106033:	0f be 55 db          	movsbl -0x25(%ebp),%edx
  106037:	8b 45 ec             	mov    -0x14(%ebp),%eax
  10603a:	89 54 24 18          	mov    %edx,0x18(%esp)
  10603e:	8b 55 e8             	mov    -0x18(%ebp),%edx
  106041:	89 54 24 14          	mov    %edx,0x14(%esp)
  106045:	89 44 24 10          	mov    %eax,0x10(%esp)
  106049:	8b 45 f0             	mov    -0x10(%ebp),%eax
  10604c:	8b 55 f4             	mov    -0xc(%ebp),%edx
  10604f:	89 44 24 08          	mov    %eax,0x8(%esp)
  106053:	89 54 24 0c          	mov    %edx,0xc(%esp)
  106057:	8b 45 0c             	mov    0xc(%ebp),%eax
  10605a:	89 44 24 04          	mov    %eax,0x4(%esp)
  10605e:	8b 45 08             	mov    0x8(%ebp),%eax
  106061:	89 04 24             	mov    %eax,(%esp)
  106064:	e8 a4 fa ff ff       	call   105b0d <printnum>
            break;
  106069:	eb 38                	jmp    1060a3 <vprintfmt+0x3cc>

        // escaped '%' character
        case '%':
            putch(ch, putdat);
  10606b:	8b 45 0c             	mov    0xc(%ebp),%eax
  10606e:	89 44 24 04          	mov    %eax,0x4(%esp)
  106072:	89 1c 24             	mov    %ebx,(%esp)
  106075:	8b 45 08             	mov    0x8(%ebp),%eax
  106078:	ff d0                	call   *%eax
            break;
  10607a:	eb 27                	jmp    1060a3 <vprintfmt+0x3cc>

        // unrecognized escape sequence - just print it literally
        default:
            putch('%', putdat);
  10607c:	8b 45 0c             	mov    0xc(%ebp),%eax
  10607f:	89 44 24 04          	mov    %eax,0x4(%esp)
  106083:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
  10608a:	8b 45 08             	mov    0x8(%ebp),%eax
  10608d:	ff d0                	call   *%eax
            for (fmt --; fmt[-1] != '%'; fmt --)
  10608f:	ff 4d 10             	decl   0x10(%ebp)
  106092:	eb 03                	jmp    106097 <vprintfmt+0x3c0>
  106094:	ff 4d 10             	decl   0x10(%ebp)
  106097:	8b 45 10             	mov    0x10(%ebp),%eax
  10609a:	48                   	dec    %eax
  10609b:	0f b6 00             	movzbl (%eax),%eax
  10609e:	3c 25                	cmp    $0x25,%al
  1060a0:	75 f2                	jne    106094 <vprintfmt+0x3bd>
                /* do nothing */;
            break;
  1060a2:	90                   	nop
    while (1) {
  1060a3:	e9 37 fc ff ff       	jmp    105cdf <vprintfmt+0x8>
                return;
  1060a8:	90                   	nop
        }
    }
}
  1060a9:	83 c4 40             	add    $0x40,%esp
  1060ac:	5b                   	pop    %ebx
  1060ad:	5e                   	pop    %esi
  1060ae:	5d                   	pop    %ebp
  1060af:	c3                   	ret    

001060b0 <sprintputch>:
 * sprintputch - 'print' a single character in a buffer
 * @ch:         the character will be printed
 * @b:          the buffer to place the character @ch
 * */
static void
sprintputch(int ch, struct sprintbuf *b) {
  1060b0:	55                   	push   %ebp
  1060b1:	89 e5                	mov    %esp,%ebp
    b->cnt ++;
  1060b3:	8b 45 0c             	mov    0xc(%ebp),%eax
  1060b6:	8b 40 08             	mov    0x8(%eax),%eax
  1060b9:	8d 50 01             	lea    0x1(%eax),%edx
  1060bc:	8b 45 0c             	mov    0xc(%ebp),%eax
  1060bf:	89 50 08             	mov    %edx,0x8(%eax)
    if (b->buf < b->ebuf) {
  1060c2:	8b 45 0c             	mov    0xc(%ebp),%eax
  1060c5:	8b 10                	mov    (%eax),%edx
  1060c7:	8b 45 0c             	mov    0xc(%ebp),%eax
  1060ca:	8b 40 04             	mov    0x4(%eax),%eax
  1060cd:	39 c2                	cmp    %eax,%edx
  1060cf:	73 12                	jae    1060e3 <sprintputch+0x33>
        *b->buf ++ = ch;
  1060d1:	8b 45 0c             	mov    0xc(%ebp),%eax
  1060d4:	8b 00                	mov    (%eax),%eax
  1060d6:	8d 48 01             	lea    0x1(%eax),%ecx
  1060d9:	8b 55 0c             	mov    0xc(%ebp),%edx
  1060dc:	89 0a                	mov    %ecx,(%edx)
  1060de:	8b 55 08             	mov    0x8(%ebp),%edx
  1060e1:	88 10                	mov    %dl,(%eax)
    }
}
  1060e3:	90                   	nop
  1060e4:	5d                   	pop    %ebp
  1060e5:	c3                   	ret    

001060e6 <snprintf>:
 * @str:        the buffer to place the result into
 * @size:       the size of buffer, including the trailing null space
 * @fmt:        the format string to use
 * */
int
snprintf(char *str, size_t size, const char *fmt, ...) {
  1060e6:	55                   	push   %ebp
  1060e7:	89 e5                	mov    %esp,%ebp
  1060e9:	83 ec 28             	sub    $0x28,%esp
    va_list ap;
    int cnt;
    va_start(ap, fmt);
  1060ec:	8d 45 14             	lea    0x14(%ebp),%eax
  1060ef:	89 45 f0             	mov    %eax,-0x10(%ebp)
    cnt = vsnprintf(str, size, fmt, ap);
  1060f2:	8b 45 f0             	mov    -0x10(%ebp),%eax
  1060f5:	89 44 24 0c          	mov    %eax,0xc(%esp)
  1060f9:	8b 45 10             	mov    0x10(%ebp),%eax
  1060fc:	89 44 24 08          	mov    %eax,0x8(%esp)
  106100:	8b 45 0c             	mov    0xc(%ebp),%eax
  106103:	89 44 24 04          	mov    %eax,0x4(%esp)
  106107:	8b 45 08             	mov    0x8(%ebp),%eax
  10610a:	89 04 24             	mov    %eax,(%esp)
  10610d:	e8 08 00 00 00       	call   10611a <vsnprintf>
  106112:	89 45 f4             	mov    %eax,-0xc(%ebp)
    va_end(ap);
    return cnt;
  106115:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  106118:	c9                   	leave  
  106119:	c3                   	ret    

0010611a <vsnprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want snprintf() instead.
 * */
int
vsnprintf(char *str, size_t size, const char *fmt, va_list ap) {
  10611a:	55                   	push   %ebp
  10611b:	89 e5                	mov    %esp,%ebp
  10611d:	83 ec 28             	sub    $0x28,%esp
    struct sprintbuf b = {str, str + size - 1, 0};
  106120:	8b 45 08             	mov    0x8(%ebp),%eax
  106123:	89 45 ec             	mov    %eax,-0x14(%ebp)
  106126:	8b 45 0c             	mov    0xc(%ebp),%eax
  106129:	8d 50 ff             	lea    -0x1(%eax),%edx
  10612c:	8b 45 08             	mov    0x8(%ebp),%eax
  10612f:	01 d0                	add    %edx,%eax
  106131:	89 45 f0             	mov    %eax,-0x10(%ebp)
  106134:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    if (str == NULL || b.buf > b.ebuf) {
  10613b:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
  10613f:	74 0a                	je     10614b <vsnprintf+0x31>
  106141:	8b 55 ec             	mov    -0x14(%ebp),%edx
  106144:	8b 45 f0             	mov    -0x10(%ebp),%eax
  106147:	39 c2                	cmp    %eax,%edx
  106149:	76 07                	jbe    106152 <vsnprintf+0x38>
        return -E_INVAL;
  10614b:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
  106150:	eb 2a                	jmp    10617c <vsnprintf+0x62>
    }
    // print the string to the buffer
    vprintfmt((void*)sprintputch, &b, fmt, ap);
  106152:	8b 45 14             	mov    0x14(%ebp),%eax
  106155:	89 44 24 0c          	mov    %eax,0xc(%esp)
  106159:	8b 45 10             	mov    0x10(%ebp),%eax
  10615c:	89 44 24 08          	mov    %eax,0x8(%esp)
  106160:	8d 45 ec             	lea    -0x14(%ebp),%eax
  106163:	89 44 24 04          	mov    %eax,0x4(%esp)
  106167:	c7 04 24 b0 60 10 00 	movl   $0x1060b0,(%esp)
  10616e:	e8 64 fb ff ff       	call   105cd7 <vprintfmt>
    // null terminate the buffer
    *b.buf = '\0';
  106173:	8b 45 ec             	mov    -0x14(%ebp),%eax
  106176:	c6 00 00             	movb   $0x0,(%eax)
    return b.cnt;
  106179:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
  10617c:	c9                   	leave  
  10617d:	c3                   	ret    
