
bin/kernel：     文件格式 elf32-i386


Disassembly of section .text:

c0100000 <kern_entry>:
#而且临时建立了一个段映射关系，为之后建立分页机制的过程做一个准备
.text
.globl kern_entry
kern_entry:
    # load pa of boot pgdir
    movl $REALLOC(__boot_pgdir), %eax
c0100000:	b8 00 90 11 00       	mov    $0x119000,%eax
    movl %eax, %cr3   #指令把页目录表的起始地址存入CR3寄存器中；
c0100005:	0f 22 d8             	mov    %eax,%cr3

    # enable paging
    movl %cr0, %eax
c0100008:	0f 20 c0             	mov    %cr0,%eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
c010000b:	0d 2f 00 05 80       	or     $0x8005002f,%eax
    andl $~(CR0_TS | CR0_EM), %eax
c0100010:	83 e0 f3             	and    $0xfffffff3,%eax
    movl %eax, %cr0   #指令把cr0中的CR0_PG标志位设置上。
c0100013:	0f 22 c0             	mov    %eax,%cr0

    # update eip  需要使用一个绝对跳转来使内核跳转到高虚拟地址
    # now, eip = 0x1.....
    leal next, %eax
c0100016:	8d 05 1e 00 10 c0    	lea    0xc010001e,%eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
c010001c:	ff e0                	jmp    *%eax

c010001e <next>:
next:

    #跳转完毕后，通过把boot_pgdir[0]对应的第一个页目录表项（0~4MB）清零来取消了临时的页映射关系：
    # unmap va 0 ~ 4M, it's temporary mapping 
    xorl %eax, %eax
c010001e:	31 c0                	xor    %eax,%eax
    movl %eax, __boot_pgdir
c0100020:	a3 00 90 11 c0       	mov    %eax,0xc0119000

    # set ebp, esp
    movl $0x0, %ebp
c0100025:	bd 00 00 00 00       	mov    $0x0,%ebp
    # the kernel stack region is from bootstack -- bootstacktop,
    # the kernel stack size is KSTACKSIZE (8KB)defined in memlayout.h
    movl $bootstacktop, %esp
c010002a:	bc 00 80 11 c0       	mov    $0xc0118000,%esp
    # now kernel stack is ready , call the first C function
    call kern_init
c010002f:	e8 02 00 00 00       	call   c0100036 <kern_init>

c0100034 <spin>:

# should never get here
spin:
    jmp spin
c0100034:	eb fe                	jmp    c0100034 <spin>

c0100036 <kern_init>:
//不像lab1那样，直接调用kern_init函数，而是先调用位于kern_entry函数。
//kern_entry函数的主要任务是为执行kern_init建立一个良好的C语言运行环境（设置堆栈），
//而且临时建立了一个段映射关系，为之后建立分页机制的过程做一个准备
//完成这些工作后，才调用kern_init函数
int
kern_init(void) {
c0100036:	55                   	push   %ebp
c0100037:	89 e5                	mov    %esp,%ebp
c0100039:	83 ec 28             	sub    $0x28,%esp
    extern char edata[], end[];
    memset(edata, 0, end - edata);
c010003c:	ba 88 bf 11 c0       	mov    $0xc011bf88,%edx
c0100041:	b8 00 b0 11 c0       	mov    $0xc011b000,%eax
c0100046:	29 c2                	sub    %eax,%edx
c0100048:	89 d0                	mov    %edx,%eax
c010004a:	89 44 24 08          	mov    %eax,0x8(%esp)
c010004e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0100055:	00 
c0100056:	c7 04 24 00 b0 11 c0 	movl   $0xc011b000,(%esp)
c010005d:	e8 22 59 00 00       	call   c0105984 <memset>

    cons_init();                // init the console
c0100062:	e8 90 15 00 00       	call   c01015f7 <cons_init>

    const char *message = "(THU.CST) os is loading ...";
c0100067:	c7 45 f4 80 61 10 c0 	movl   $0xc0106180,-0xc(%ebp)
    cprintf("%s\n\n", message);
c010006e:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100071:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100075:	c7 04 24 9c 61 10 c0 	movl   $0xc010619c,(%esp)
c010007c:	e8 21 02 00 00       	call   c01002a2 <cprintf>

    print_kerninfo();
c0100081:	e8 c2 08 00 00       	call   c0100948 <print_kerninfo>

    grade_backtrace();
c0100086:	e8 8e 00 00 00       	call   c0100119 <grade_backtrace>

    //调用pmm_init函数完成物理内存的管理
    pmm_init();                 // init physical memory management
c010008b:	e8 ad 32 00 00       	call   c010333d <pmm_init>

    //调用pic_init函数和idt_init函数执行中断和异常相关的初始化工作，这些工作与lab1的中断异常初始化工作的内容是相同的。
    pic_init();                 // init interrupt controller
c0100090:	e8 c7 16 00 00       	call   c010175c <pic_init>
    idt_init();                 // init interrupt descriptor table
c0100095:	e8 4c 18 00 00       	call   c01018e6 <idt_init>

    clock_init();               // init clock interrupt
c010009a:	e8 fb 0c 00 00       	call   c0100d9a <clock_init>
    intr_enable();              // enable irq interrupt
c010009f:	e8 f2 17 00 00       	call   c0101896 <intr_enable>

    //LAB1: CAHLLENGE 1 If you try to do it, uncomment lab1_switch_test()
    // user/kernel mode switch test
    lab1_switch_test(); 
c01000a4:	e8 6b 01 00 00       	call   c0100214 <lab1_switch_test>

    /* do nothing */
    while (1);
c01000a9:	eb fe                	jmp    c01000a9 <kern_init+0x73>

c01000ab <grade_backtrace2>:
}

void __attribute__((noinline))
grade_backtrace2(int arg0, int arg1, int arg2, int arg3) {
c01000ab:	55                   	push   %ebp
c01000ac:	89 e5                	mov    %esp,%ebp
c01000ae:	83 ec 18             	sub    $0x18,%esp
    mon_backtrace(0, NULL, NULL);
c01000b1:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c01000b8:	00 
c01000b9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c01000c0:	00 
c01000c1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c01000c8:	e8 bb 0c 00 00       	call   c0100d88 <mon_backtrace>
}
c01000cd:	90                   	nop
c01000ce:	c9                   	leave  
c01000cf:	c3                   	ret    

c01000d0 <grade_backtrace1>:

void __attribute__((noinline))
grade_backtrace1(int arg0, int arg1) {
c01000d0:	55                   	push   %ebp
c01000d1:	89 e5                	mov    %esp,%ebp
c01000d3:	53                   	push   %ebx
c01000d4:	83 ec 14             	sub    $0x14,%esp
    grade_backtrace2(arg0, (int)&arg0, arg1, (int)&arg1);
c01000d7:	8d 4d 0c             	lea    0xc(%ebp),%ecx
c01000da:	8b 55 0c             	mov    0xc(%ebp),%edx
c01000dd:	8d 5d 08             	lea    0x8(%ebp),%ebx
c01000e0:	8b 45 08             	mov    0x8(%ebp),%eax
c01000e3:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c01000e7:	89 54 24 08          	mov    %edx,0x8(%esp)
c01000eb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c01000ef:	89 04 24             	mov    %eax,(%esp)
c01000f2:	e8 b4 ff ff ff       	call   c01000ab <grade_backtrace2>
}
c01000f7:	90                   	nop
c01000f8:	83 c4 14             	add    $0x14,%esp
c01000fb:	5b                   	pop    %ebx
c01000fc:	5d                   	pop    %ebp
c01000fd:	c3                   	ret    

c01000fe <grade_backtrace0>:

void __attribute__((noinline))
grade_backtrace0(int arg0, int arg1, int arg2) {
c01000fe:	55                   	push   %ebp
c01000ff:	89 e5                	mov    %esp,%ebp
c0100101:	83 ec 18             	sub    $0x18,%esp
    grade_backtrace1(arg0, arg2);
c0100104:	8b 45 10             	mov    0x10(%ebp),%eax
c0100107:	89 44 24 04          	mov    %eax,0x4(%esp)
c010010b:	8b 45 08             	mov    0x8(%ebp),%eax
c010010e:	89 04 24             	mov    %eax,(%esp)
c0100111:	e8 ba ff ff ff       	call   c01000d0 <grade_backtrace1>
}
c0100116:	90                   	nop
c0100117:	c9                   	leave  
c0100118:	c3                   	ret    

c0100119 <grade_backtrace>:

void
grade_backtrace(void) {
c0100119:	55                   	push   %ebp
c010011a:	89 e5                	mov    %esp,%ebp
c010011c:	83 ec 18             	sub    $0x18,%esp
    grade_backtrace0(0, (int)kern_init, 0xffff0000);
c010011f:	b8 36 00 10 c0       	mov    $0xc0100036,%eax
c0100124:	c7 44 24 08 00 00 ff 	movl   $0xffff0000,0x8(%esp)
c010012b:	ff 
c010012c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100130:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0100137:	e8 c2 ff ff ff       	call   c01000fe <grade_backtrace0>
}
c010013c:	90                   	nop
c010013d:	c9                   	leave  
c010013e:	c3                   	ret    

c010013f <lab1_print_cur_status>:

static void
lab1_print_cur_status(void) {
c010013f:	55                   	push   %ebp
c0100140:	89 e5                	mov    %esp,%ebp
c0100142:	83 ec 28             	sub    $0x28,%esp
    static int round = 0;
    uint16_t reg1, reg2, reg3, reg4;
    asm volatile (
c0100145:	8c 4d f6             	mov    %cs,-0xa(%ebp)
c0100148:	8c 5d f4             	mov    %ds,-0xc(%ebp)
c010014b:	8c 45 f2             	mov    %es,-0xe(%ebp)
c010014e:	8c 55 f0             	mov    %ss,-0x10(%ebp)
            "mov %%cs, %0;"
            "mov %%ds, %1;"
            "mov %%es, %2;"
            "mov %%ss, %3;"
            : "=m"(reg1), "=m"(reg2), "=m"(reg3), "=m"(reg4));
    cprintf("%d: @ring %d\n", round, reg1 & 3);
c0100151:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
c0100155:	83 e0 03             	and    $0x3,%eax
c0100158:	89 c2                	mov    %eax,%edx
c010015a:	a1 00 b0 11 c0       	mov    0xc011b000,%eax
c010015f:	89 54 24 08          	mov    %edx,0x8(%esp)
c0100163:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100167:	c7 04 24 a1 61 10 c0 	movl   $0xc01061a1,(%esp)
c010016e:	e8 2f 01 00 00       	call   c01002a2 <cprintf>
    cprintf("%d:  cs = %x\n", round, reg1);
c0100173:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
c0100177:	89 c2                	mov    %eax,%edx
c0100179:	a1 00 b0 11 c0       	mov    0xc011b000,%eax
c010017e:	89 54 24 08          	mov    %edx,0x8(%esp)
c0100182:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100186:	c7 04 24 af 61 10 c0 	movl   $0xc01061af,(%esp)
c010018d:	e8 10 01 00 00       	call   c01002a2 <cprintf>
    cprintf("%d:  ds = %x\n", round, reg2);
c0100192:	0f b7 45 f4          	movzwl -0xc(%ebp),%eax
c0100196:	89 c2                	mov    %eax,%edx
c0100198:	a1 00 b0 11 c0       	mov    0xc011b000,%eax
c010019d:	89 54 24 08          	mov    %edx,0x8(%esp)
c01001a1:	89 44 24 04          	mov    %eax,0x4(%esp)
c01001a5:	c7 04 24 bd 61 10 c0 	movl   $0xc01061bd,(%esp)
c01001ac:	e8 f1 00 00 00       	call   c01002a2 <cprintf>
    cprintf("%d:  es = %x\n", round, reg3);
c01001b1:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
c01001b5:	89 c2                	mov    %eax,%edx
c01001b7:	a1 00 b0 11 c0       	mov    0xc011b000,%eax
c01001bc:	89 54 24 08          	mov    %edx,0x8(%esp)
c01001c0:	89 44 24 04          	mov    %eax,0x4(%esp)
c01001c4:	c7 04 24 cb 61 10 c0 	movl   $0xc01061cb,(%esp)
c01001cb:	e8 d2 00 00 00       	call   c01002a2 <cprintf>
    cprintf("%d:  ss = %x\n", round, reg4);
c01001d0:	0f b7 45 f0          	movzwl -0x10(%ebp),%eax
c01001d4:	89 c2                	mov    %eax,%edx
c01001d6:	a1 00 b0 11 c0       	mov    0xc011b000,%eax
c01001db:	89 54 24 08          	mov    %edx,0x8(%esp)
c01001df:	89 44 24 04          	mov    %eax,0x4(%esp)
c01001e3:	c7 04 24 d9 61 10 c0 	movl   $0xc01061d9,(%esp)
c01001ea:	e8 b3 00 00 00       	call   c01002a2 <cprintf>
    round ++;
c01001ef:	a1 00 b0 11 c0       	mov    0xc011b000,%eax
c01001f4:	40                   	inc    %eax
c01001f5:	a3 00 b0 11 c0       	mov    %eax,0xc011b000
}
c01001fa:	90                   	nop
c01001fb:	c9                   	leave  
c01001fc:	c3                   	ret    

c01001fd <lab1_switch_to_user>:

static void
lab1_switch_to_user(void) {
c01001fd:	55                   	push   %ebp
c01001fe:	89 e5                	mov    %esp,%ebp
    //LAB1 CHALLENGE 1 : TODO
    asm volatile (
c0100200:	83 ec 08             	sub    $0x8,%esp
c0100203:	cd 78                	int    $0x78
c0100205:	89 ec                	mov    %ebp,%esp
	    "int %0 \n"
	    "movl %%ebp, %%esp"
	    : 
	    : "i"(T_SWITCH_TOU)
	);
}
c0100207:	90                   	nop
c0100208:	5d                   	pop    %ebp
c0100209:	c3                   	ret    

c010020a <lab1_switch_to_kernel>:

static void
lab1_switch_to_kernel(void) {
c010020a:	55                   	push   %ebp
c010020b:	89 e5                	mov    %esp,%ebp
    //LAB1 CHALLENGE 1 :  TODO
    asm volatile (
c010020d:	cd 79                	int    $0x79
c010020f:	89 ec                	mov    %ebp,%esp
	    "int %0 \n"
	    "movl %%ebp, %%esp \n"
	    : 
	    : "i"(T_SWITCH_TOK)
	);
}
c0100211:	90                   	nop
c0100212:	5d                   	pop    %ebp
c0100213:	c3                   	ret    

c0100214 <lab1_switch_test>:

static void
lab1_switch_test(void) {
c0100214:	55                   	push   %ebp
c0100215:	89 e5                	mov    %esp,%ebp
c0100217:	83 ec 18             	sub    $0x18,%esp
    lab1_print_cur_status();
c010021a:	e8 20 ff ff ff       	call   c010013f <lab1_print_cur_status>
    cprintf("+++ switch to  user  mode +++\n");
c010021f:	c7 04 24 e8 61 10 c0 	movl   $0xc01061e8,(%esp)
c0100226:	e8 77 00 00 00       	call   c01002a2 <cprintf>
    lab1_switch_to_user();
c010022b:	e8 cd ff ff ff       	call   c01001fd <lab1_switch_to_user>
    lab1_print_cur_status();
c0100230:	e8 0a ff ff ff       	call   c010013f <lab1_print_cur_status>
    cprintf("+++ switch to kernel mode +++\n");
c0100235:	c7 04 24 08 62 10 c0 	movl   $0xc0106208,(%esp)
c010023c:	e8 61 00 00 00       	call   c01002a2 <cprintf>
    lab1_switch_to_kernel();
c0100241:	e8 c4 ff ff ff       	call   c010020a <lab1_switch_to_kernel>
    lab1_print_cur_status();
c0100246:	e8 f4 fe ff ff       	call   c010013f <lab1_print_cur_status>
}
c010024b:	90                   	nop
c010024c:	c9                   	leave  
c010024d:	c3                   	ret    

c010024e <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
c010024e:	55                   	push   %ebp
c010024f:	89 e5                	mov    %esp,%ebp
c0100251:	83 ec 18             	sub    $0x18,%esp
    cons_putc(c);
c0100254:	8b 45 08             	mov    0x8(%ebp),%eax
c0100257:	89 04 24             	mov    %eax,(%esp)
c010025a:	e8 c5 13 00 00       	call   c0101624 <cons_putc>
    (*cnt) ++;
c010025f:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100262:	8b 00                	mov    (%eax),%eax
c0100264:	8d 50 01             	lea    0x1(%eax),%edx
c0100267:	8b 45 0c             	mov    0xc(%ebp),%eax
c010026a:	89 10                	mov    %edx,(%eax)
}
c010026c:	90                   	nop
c010026d:	c9                   	leave  
c010026e:	c3                   	ret    

c010026f <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
c010026f:	55                   	push   %ebp
c0100270:	89 e5                	mov    %esp,%ebp
c0100272:	83 ec 28             	sub    $0x28,%esp
    int cnt = 0;
c0100275:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
c010027c:	8b 45 0c             	mov    0xc(%ebp),%eax
c010027f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0100283:	8b 45 08             	mov    0x8(%ebp),%eax
c0100286:	89 44 24 08          	mov    %eax,0x8(%esp)
c010028a:	8d 45 f4             	lea    -0xc(%ebp),%eax
c010028d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100291:	c7 04 24 4e 02 10 c0 	movl   $0xc010024e,(%esp)
c0100298:	e8 3a 5a 00 00       	call   c0105cd7 <vprintfmt>
    return cnt;
c010029d:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c01002a0:	c9                   	leave  
c01002a1:	c3                   	ret    

c01002a2 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
c01002a2:	55                   	push   %ebp
c01002a3:	89 e5                	mov    %esp,%ebp
c01002a5:	83 ec 28             	sub    $0x28,%esp
    va_list ap;
    int cnt;
    va_start(ap, fmt);
c01002a8:	8d 45 0c             	lea    0xc(%ebp),%eax
c01002ab:	89 45 f0             	mov    %eax,-0x10(%ebp)
    cnt = vcprintf(fmt, ap);
c01002ae:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01002b1:	89 44 24 04          	mov    %eax,0x4(%esp)
c01002b5:	8b 45 08             	mov    0x8(%ebp),%eax
c01002b8:	89 04 24             	mov    %eax,(%esp)
c01002bb:	e8 af ff ff ff       	call   c010026f <vcprintf>
c01002c0:	89 45 f4             	mov    %eax,-0xc(%ebp)
    va_end(ap);
    return cnt;
c01002c3:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c01002c6:	c9                   	leave  
c01002c7:	c3                   	ret    

c01002c8 <cputchar>:

/* cputchar - writes a single character to stdout */
void
cputchar(int c) {
c01002c8:	55                   	push   %ebp
c01002c9:	89 e5                	mov    %esp,%ebp
c01002cb:	83 ec 18             	sub    $0x18,%esp
    cons_putc(c);
c01002ce:	8b 45 08             	mov    0x8(%ebp),%eax
c01002d1:	89 04 24             	mov    %eax,(%esp)
c01002d4:	e8 4b 13 00 00       	call   c0101624 <cons_putc>
}
c01002d9:	90                   	nop
c01002da:	c9                   	leave  
c01002db:	c3                   	ret    

c01002dc <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
c01002dc:	55                   	push   %ebp
c01002dd:	89 e5                	mov    %esp,%ebp
c01002df:	83 ec 28             	sub    $0x28,%esp
    int cnt = 0;
c01002e2:	c7 45 f0 00 00 00 00 	movl   $0x0,-0x10(%ebp)
    char c;
    while ((c = *str ++) != '\0') {
c01002e9:	eb 13                	jmp    c01002fe <cputs+0x22>
        cputch(c, &cnt);
c01002eb:	0f be 45 f7          	movsbl -0x9(%ebp),%eax
c01002ef:	8d 55 f0             	lea    -0x10(%ebp),%edx
c01002f2:	89 54 24 04          	mov    %edx,0x4(%esp)
c01002f6:	89 04 24             	mov    %eax,(%esp)
c01002f9:	e8 50 ff ff ff       	call   c010024e <cputch>
    while ((c = *str ++) != '\0') {
c01002fe:	8b 45 08             	mov    0x8(%ebp),%eax
c0100301:	8d 50 01             	lea    0x1(%eax),%edx
c0100304:	89 55 08             	mov    %edx,0x8(%ebp)
c0100307:	0f b6 00             	movzbl (%eax),%eax
c010030a:	88 45 f7             	mov    %al,-0x9(%ebp)
c010030d:	80 7d f7 00          	cmpb   $0x0,-0x9(%ebp)
c0100311:	75 d8                	jne    c01002eb <cputs+0xf>
    }
    cputch('\n', &cnt);
c0100313:	8d 45 f0             	lea    -0x10(%ebp),%eax
c0100316:	89 44 24 04          	mov    %eax,0x4(%esp)
c010031a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
c0100321:	e8 28 ff ff ff       	call   c010024e <cputch>
    return cnt;
c0100326:	8b 45 f0             	mov    -0x10(%ebp),%eax
}
c0100329:	c9                   	leave  
c010032a:	c3                   	ret    

c010032b <getchar>:

/* getchar - reads a single non-zero character from stdin */
int
getchar(void) {
c010032b:	55                   	push   %ebp
c010032c:	89 e5                	mov    %esp,%ebp
c010032e:	83 ec 18             	sub    $0x18,%esp
    int c;
    while ((c = cons_getc()) == 0)
c0100331:	e8 2b 13 00 00       	call   c0101661 <cons_getc>
c0100336:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0100339:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c010033d:	74 f2                	je     c0100331 <getchar+0x6>
        /* do nothing */;
    return c;
c010033f:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c0100342:	c9                   	leave  
c0100343:	c3                   	ret    

c0100344 <readline>:
 * The readline() function returns the text of the line read. If some errors
 * are happened, NULL is returned. The return value is a global variable,
 * thus it should be copied before it is used.
 * */
char *
readline(const char *prompt) {
c0100344:	55                   	push   %ebp
c0100345:	89 e5                	mov    %esp,%ebp
c0100347:	83 ec 28             	sub    $0x28,%esp
    if (prompt != NULL) {
c010034a:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
c010034e:	74 13                	je     c0100363 <readline+0x1f>
        cprintf("%s", prompt);
c0100350:	8b 45 08             	mov    0x8(%ebp),%eax
c0100353:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100357:	c7 04 24 27 62 10 c0 	movl   $0xc0106227,(%esp)
c010035e:	e8 3f ff ff ff       	call   c01002a2 <cprintf>
    }
    int i = 0, c;
c0100363:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    while (1) {
        c = getchar();
c010036a:	e8 bc ff ff ff       	call   c010032b <getchar>
c010036f:	89 45 f0             	mov    %eax,-0x10(%ebp)
        if (c < 0) {
c0100372:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0100376:	79 07                	jns    c010037f <readline+0x3b>
            return NULL;
c0100378:	b8 00 00 00 00       	mov    $0x0,%eax
c010037d:	eb 78                	jmp    c01003f7 <readline+0xb3>
        }
        else if (c >= ' ' && i < BUFSIZE - 1) {
c010037f:	83 7d f0 1f          	cmpl   $0x1f,-0x10(%ebp)
c0100383:	7e 28                	jle    c01003ad <readline+0x69>
c0100385:	81 7d f4 fe 03 00 00 	cmpl   $0x3fe,-0xc(%ebp)
c010038c:	7f 1f                	jg     c01003ad <readline+0x69>
            cputchar(c);
c010038e:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0100391:	89 04 24             	mov    %eax,(%esp)
c0100394:	e8 2f ff ff ff       	call   c01002c8 <cputchar>
            buf[i ++] = c;
c0100399:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010039c:	8d 50 01             	lea    0x1(%eax),%edx
c010039f:	89 55 f4             	mov    %edx,-0xc(%ebp)
c01003a2:	8b 55 f0             	mov    -0x10(%ebp),%edx
c01003a5:	88 90 20 b0 11 c0    	mov    %dl,-0x3fee4fe0(%eax)
c01003ab:	eb 45                	jmp    c01003f2 <readline+0xae>
        }
        else if (c == '\b' && i > 0) {
c01003ad:	83 7d f0 08          	cmpl   $0x8,-0x10(%ebp)
c01003b1:	75 16                	jne    c01003c9 <readline+0x85>
c01003b3:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c01003b7:	7e 10                	jle    c01003c9 <readline+0x85>
            cputchar(c);
c01003b9:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01003bc:	89 04 24             	mov    %eax,(%esp)
c01003bf:	e8 04 ff ff ff       	call   c01002c8 <cputchar>
            i --;
c01003c4:	ff 4d f4             	decl   -0xc(%ebp)
c01003c7:	eb 29                	jmp    c01003f2 <readline+0xae>
        }
        else if (c == '\n' || c == '\r') {
c01003c9:	83 7d f0 0a          	cmpl   $0xa,-0x10(%ebp)
c01003cd:	74 06                	je     c01003d5 <readline+0x91>
c01003cf:	83 7d f0 0d          	cmpl   $0xd,-0x10(%ebp)
c01003d3:	75 95                	jne    c010036a <readline+0x26>
            cputchar(c);
c01003d5:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01003d8:	89 04 24             	mov    %eax,(%esp)
c01003db:	e8 e8 fe ff ff       	call   c01002c8 <cputchar>
            buf[i] = '\0';
c01003e0:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01003e3:	05 20 b0 11 c0       	add    $0xc011b020,%eax
c01003e8:	c6 00 00             	movb   $0x0,(%eax)
            return buf;
c01003eb:	b8 20 b0 11 c0       	mov    $0xc011b020,%eax
c01003f0:	eb 05                	jmp    c01003f7 <readline+0xb3>
        c = getchar();
c01003f2:	e9 73 ff ff ff       	jmp    c010036a <readline+0x26>
        }
    }
}
c01003f7:	c9                   	leave  
c01003f8:	c3                   	ret    

c01003f9 <__panic>:
/* *
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
c01003f9:	55                   	push   %ebp
c01003fa:	89 e5                	mov    %esp,%ebp
c01003fc:	83 ec 28             	sub    $0x28,%esp
    if (is_panic) {
c01003ff:	a1 20 b4 11 c0       	mov    0xc011b420,%eax
c0100404:	85 c0                	test   %eax,%eax
c0100406:	75 5b                	jne    c0100463 <__panic+0x6a>
        goto panic_dead;
    }
    is_panic = 1;
c0100408:	c7 05 20 b4 11 c0 01 	movl   $0x1,0xc011b420
c010040f:	00 00 00 

    // print the 'message'
    va_list ap;
    va_start(ap, fmt);
c0100412:	8d 45 14             	lea    0x14(%ebp),%eax
c0100415:	89 45 f4             	mov    %eax,-0xc(%ebp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
c0100418:	8b 45 0c             	mov    0xc(%ebp),%eax
c010041b:	89 44 24 08          	mov    %eax,0x8(%esp)
c010041f:	8b 45 08             	mov    0x8(%ebp),%eax
c0100422:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100426:	c7 04 24 2a 62 10 c0 	movl   $0xc010622a,(%esp)
c010042d:	e8 70 fe ff ff       	call   c01002a2 <cprintf>
    vcprintf(fmt, ap);
c0100432:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100435:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100439:	8b 45 10             	mov    0x10(%ebp),%eax
c010043c:	89 04 24             	mov    %eax,(%esp)
c010043f:	e8 2b fe ff ff       	call   c010026f <vcprintf>
    cprintf("\n");
c0100444:	c7 04 24 46 62 10 c0 	movl   $0xc0106246,(%esp)
c010044b:	e8 52 fe ff ff       	call   c01002a2 <cprintf>
    
    cprintf("stack trackback:\n");
c0100450:	c7 04 24 48 62 10 c0 	movl   $0xc0106248,(%esp)
c0100457:	e8 46 fe ff ff       	call   c01002a2 <cprintf>
    print_stackframe();
c010045c:	e8 32 06 00 00       	call   c0100a93 <print_stackframe>
c0100461:	eb 01                	jmp    c0100464 <__panic+0x6b>
        goto panic_dead;
c0100463:	90                   	nop
    
    va_end(ap);

panic_dead:
    intr_disable();
c0100464:	e8 34 14 00 00       	call   c010189d <intr_disable>
    while (1) {
        kmonitor(NULL);
c0100469:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0100470:	e8 46 08 00 00       	call   c0100cbb <kmonitor>
c0100475:	eb f2                	jmp    c0100469 <__panic+0x70>

c0100477 <__warn>:
    }
}

/* __warn - like panic, but don't */
void
__warn(const char *file, int line, const char *fmt, ...) {
c0100477:	55                   	push   %ebp
c0100478:	89 e5                	mov    %esp,%ebp
c010047a:	83 ec 28             	sub    $0x28,%esp
    va_list ap;
    va_start(ap, fmt);
c010047d:	8d 45 14             	lea    0x14(%ebp),%eax
c0100480:	89 45 f4             	mov    %eax,-0xc(%ebp)
    cprintf("kernel warning at %s:%d:\n    ", file, line);
c0100483:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100486:	89 44 24 08          	mov    %eax,0x8(%esp)
c010048a:	8b 45 08             	mov    0x8(%ebp),%eax
c010048d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100491:	c7 04 24 5a 62 10 c0 	movl   $0xc010625a,(%esp)
c0100498:	e8 05 fe ff ff       	call   c01002a2 <cprintf>
    vcprintf(fmt, ap);
c010049d:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01004a0:	89 44 24 04          	mov    %eax,0x4(%esp)
c01004a4:	8b 45 10             	mov    0x10(%ebp),%eax
c01004a7:	89 04 24             	mov    %eax,(%esp)
c01004aa:	e8 c0 fd ff ff       	call   c010026f <vcprintf>
    cprintf("\n");
c01004af:	c7 04 24 46 62 10 c0 	movl   $0xc0106246,(%esp)
c01004b6:	e8 e7 fd ff ff       	call   c01002a2 <cprintf>
    va_end(ap);
}
c01004bb:	90                   	nop
c01004bc:	c9                   	leave  
c01004bd:	c3                   	ret    

c01004be <is_kernel_panic>:

bool
is_kernel_panic(void) {
c01004be:	55                   	push   %ebp
c01004bf:	89 e5                	mov    %esp,%ebp
    return is_panic;
c01004c1:	a1 20 b4 11 c0       	mov    0xc011b420,%eax
}
c01004c6:	5d                   	pop    %ebp
c01004c7:	c3                   	ret    

c01004c8 <stab_binsearch>:
 *      stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
 * will exit setting left = 118, right = 554.
 * */
static void
stab_binsearch(const struct stab *stabs, int *region_left, int *region_right,
           int type, uintptr_t addr) {
c01004c8:	55                   	push   %ebp
c01004c9:	89 e5                	mov    %esp,%ebp
c01004cb:	83 ec 20             	sub    $0x20,%esp
    int l = *region_left, r = *region_right, any_matches = 0;
c01004ce:	8b 45 0c             	mov    0xc(%ebp),%eax
c01004d1:	8b 00                	mov    (%eax),%eax
c01004d3:	89 45 fc             	mov    %eax,-0x4(%ebp)
c01004d6:	8b 45 10             	mov    0x10(%ebp),%eax
c01004d9:	8b 00                	mov    (%eax),%eax
c01004db:	89 45 f8             	mov    %eax,-0x8(%ebp)
c01004de:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

    while (l <= r) {
c01004e5:	e9 ca 00 00 00       	jmp    c01005b4 <stab_binsearch+0xec>
        int true_m = (l + r) / 2, m = true_m;
c01004ea:	8b 55 fc             	mov    -0x4(%ebp),%edx
c01004ed:	8b 45 f8             	mov    -0x8(%ebp),%eax
c01004f0:	01 d0                	add    %edx,%eax
c01004f2:	89 c2                	mov    %eax,%edx
c01004f4:	c1 ea 1f             	shr    $0x1f,%edx
c01004f7:	01 d0                	add    %edx,%eax
c01004f9:	d1 f8                	sar    %eax
c01004fb:	89 45 ec             	mov    %eax,-0x14(%ebp)
c01004fe:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0100501:	89 45 f0             	mov    %eax,-0x10(%ebp)

        // search for earliest stab with right type
        while (m >= l && stabs[m].n_type != type) {
c0100504:	eb 03                	jmp    c0100509 <stab_binsearch+0x41>
            m --;
c0100506:	ff 4d f0             	decl   -0x10(%ebp)
        while (m >= l && stabs[m].n_type != type) {
c0100509:	8b 45 f0             	mov    -0x10(%ebp),%eax
c010050c:	3b 45 fc             	cmp    -0x4(%ebp),%eax
c010050f:	7c 1f                	jl     c0100530 <stab_binsearch+0x68>
c0100511:	8b 55 f0             	mov    -0x10(%ebp),%edx
c0100514:	89 d0                	mov    %edx,%eax
c0100516:	01 c0                	add    %eax,%eax
c0100518:	01 d0                	add    %edx,%eax
c010051a:	c1 e0 02             	shl    $0x2,%eax
c010051d:	89 c2                	mov    %eax,%edx
c010051f:	8b 45 08             	mov    0x8(%ebp),%eax
c0100522:	01 d0                	add    %edx,%eax
c0100524:	0f b6 40 04          	movzbl 0x4(%eax),%eax
c0100528:	0f b6 c0             	movzbl %al,%eax
c010052b:	39 45 14             	cmp    %eax,0x14(%ebp)
c010052e:	75 d6                	jne    c0100506 <stab_binsearch+0x3e>
        }
        if (m < l) {    // no match in [l, m]
c0100530:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0100533:	3b 45 fc             	cmp    -0x4(%ebp),%eax
c0100536:	7d 09                	jge    c0100541 <stab_binsearch+0x79>
            l = true_m + 1;
c0100538:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010053b:	40                   	inc    %eax
c010053c:	89 45 fc             	mov    %eax,-0x4(%ebp)
            continue;
c010053f:	eb 73                	jmp    c01005b4 <stab_binsearch+0xec>
        }

        // actual binary search
        any_matches = 1;
c0100541:	c7 45 f4 01 00 00 00 	movl   $0x1,-0xc(%ebp)
        if (stabs[m].n_value < addr) {
c0100548:	8b 55 f0             	mov    -0x10(%ebp),%edx
c010054b:	89 d0                	mov    %edx,%eax
c010054d:	01 c0                	add    %eax,%eax
c010054f:	01 d0                	add    %edx,%eax
c0100551:	c1 e0 02             	shl    $0x2,%eax
c0100554:	89 c2                	mov    %eax,%edx
c0100556:	8b 45 08             	mov    0x8(%ebp),%eax
c0100559:	01 d0                	add    %edx,%eax
c010055b:	8b 40 08             	mov    0x8(%eax),%eax
c010055e:	39 45 18             	cmp    %eax,0x18(%ebp)
c0100561:	76 11                	jbe    c0100574 <stab_binsearch+0xac>
            *region_left = m;
c0100563:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100566:	8b 55 f0             	mov    -0x10(%ebp),%edx
c0100569:	89 10                	mov    %edx,(%eax)
            l = true_m + 1;
c010056b:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010056e:	40                   	inc    %eax
c010056f:	89 45 fc             	mov    %eax,-0x4(%ebp)
c0100572:	eb 40                	jmp    c01005b4 <stab_binsearch+0xec>
        } else if (stabs[m].n_value > addr) {
c0100574:	8b 55 f0             	mov    -0x10(%ebp),%edx
c0100577:	89 d0                	mov    %edx,%eax
c0100579:	01 c0                	add    %eax,%eax
c010057b:	01 d0                	add    %edx,%eax
c010057d:	c1 e0 02             	shl    $0x2,%eax
c0100580:	89 c2                	mov    %eax,%edx
c0100582:	8b 45 08             	mov    0x8(%ebp),%eax
c0100585:	01 d0                	add    %edx,%eax
c0100587:	8b 40 08             	mov    0x8(%eax),%eax
c010058a:	39 45 18             	cmp    %eax,0x18(%ebp)
c010058d:	73 14                	jae    c01005a3 <stab_binsearch+0xdb>
            *region_right = m - 1;
c010058f:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0100592:	8d 50 ff             	lea    -0x1(%eax),%edx
c0100595:	8b 45 10             	mov    0x10(%ebp),%eax
c0100598:	89 10                	mov    %edx,(%eax)
            r = m - 1;
c010059a:	8b 45 f0             	mov    -0x10(%ebp),%eax
c010059d:	48                   	dec    %eax
c010059e:	89 45 f8             	mov    %eax,-0x8(%ebp)
c01005a1:	eb 11                	jmp    c01005b4 <stab_binsearch+0xec>
        } else {
            // exact match for 'addr', but continue loop to find
            // *region_right
            *region_left = m;
c01005a3:	8b 45 0c             	mov    0xc(%ebp),%eax
c01005a6:	8b 55 f0             	mov    -0x10(%ebp),%edx
c01005a9:	89 10                	mov    %edx,(%eax)
            l = m;
c01005ab:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01005ae:	89 45 fc             	mov    %eax,-0x4(%ebp)
            addr ++;
c01005b1:	ff 45 18             	incl   0x18(%ebp)
    while (l <= r) {
c01005b4:	8b 45 fc             	mov    -0x4(%ebp),%eax
c01005b7:	3b 45 f8             	cmp    -0x8(%ebp),%eax
c01005ba:	0f 8e 2a ff ff ff    	jle    c01004ea <stab_binsearch+0x22>
        }
    }

    if (!any_matches) {
c01005c0:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c01005c4:	75 0f                	jne    c01005d5 <stab_binsearch+0x10d>
        *region_right = *region_left - 1;
c01005c6:	8b 45 0c             	mov    0xc(%ebp),%eax
c01005c9:	8b 00                	mov    (%eax),%eax
c01005cb:	8d 50 ff             	lea    -0x1(%eax),%edx
c01005ce:	8b 45 10             	mov    0x10(%ebp),%eax
c01005d1:	89 10                	mov    %edx,(%eax)
        l = *region_right;
        for (; l > *region_left && stabs[l].n_type != type; l --)
            /* do nothing */;
        *region_left = l;
    }
}
c01005d3:	eb 3e                	jmp    c0100613 <stab_binsearch+0x14b>
        l = *region_right;
c01005d5:	8b 45 10             	mov    0x10(%ebp),%eax
c01005d8:	8b 00                	mov    (%eax),%eax
c01005da:	89 45 fc             	mov    %eax,-0x4(%ebp)
        for (; l > *region_left && stabs[l].n_type != type; l --)
c01005dd:	eb 03                	jmp    c01005e2 <stab_binsearch+0x11a>
c01005df:	ff 4d fc             	decl   -0x4(%ebp)
c01005e2:	8b 45 0c             	mov    0xc(%ebp),%eax
c01005e5:	8b 00                	mov    (%eax),%eax
c01005e7:	39 45 fc             	cmp    %eax,-0x4(%ebp)
c01005ea:	7e 1f                	jle    c010060b <stab_binsearch+0x143>
c01005ec:	8b 55 fc             	mov    -0x4(%ebp),%edx
c01005ef:	89 d0                	mov    %edx,%eax
c01005f1:	01 c0                	add    %eax,%eax
c01005f3:	01 d0                	add    %edx,%eax
c01005f5:	c1 e0 02             	shl    $0x2,%eax
c01005f8:	89 c2                	mov    %eax,%edx
c01005fa:	8b 45 08             	mov    0x8(%ebp),%eax
c01005fd:	01 d0                	add    %edx,%eax
c01005ff:	0f b6 40 04          	movzbl 0x4(%eax),%eax
c0100603:	0f b6 c0             	movzbl %al,%eax
c0100606:	39 45 14             	cmp    %eax,0x14(%ebp)
c0100609:	75 d4                	jne    c01005df <stab_binsearch+0x117>
        *region_left = l;
c010060b:	8b 45 0c             	mov    0xc(%ebp),%eax
c010060e:	8b 55 fc             	mov    -0x4(%ebp),%edx
c0100611:	89 10                	mov    %edx,(%eax)
}
c0100613:	90                   	nop
c0100614:	c9                   	leave  
c0100615:	c3                   	ret    

c0100616 <debuginfo_eip>:
 * the specified instruction address, @addr.  Returns 0 if information
 * was found, and negative if not.  But even if it returns negative it
 * has stored some information into '*info'.
 * */
int
debuginfo_eip(uintptr_t addr, struct eipdebuginfo *info) {
c0100616:	55                   	push   %ebp
c0100617:	89 e5                	mov    %esp,%ebp
c0100619:	83 ec 58             	sub    $0x58,%esp
    const struct stab *stabs, *stab_end;
    const char *stabstr, *stabstr_end;

    info->eip_file = "<unknown>";
c010061c:	8b 45 0c             	mov    0xc(%ebp),%eax
c010061f:	c7 00 78 62 10 c0    	movl   $0xc0106278,(%eax)
    info->eip_line = 0;
c0100625:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100628:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
    info->eip_fn_name = "<unknown>";
c010062f:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100632:	c7 40 08 78 62 10 c0 	movl   $0xc0106278,0x8(%eax)
    info->eip_fn_namelen = 9;
c0100639:	8b 45 0c             	mov    0xc(%ebp),%eax
c010063c:	c7 40 0c 09 00 00 00 	movl   $0x9,0xc(%eax)
    info->eip_fn_addr = addr;
c0100643:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100646:	8b 55 08             	mov    0x8(%ebp),%edx
c0100649:	89 50 10             	mov    %edx,0x10(%eax)
    info->eip_fn_narg = 0;
c010064c:	8b 45 0c             	mov    0xc(%ebp),%eax
c010064f:	c7 40 14 00 00 00 00 	movl   $0x0,0x14(%eax)

    stabs = __STAB_BEGIN__;
c0100656:	c7 45 f4 f0 74 10 c0 	movl   $0xc01074f0,-0xc(%ebp)
    stab_end = __STAB_END__;
c010065d:	c7 45 f0 0c 28 11 c0 	movl   $0xc011280c,-0x10(%ebp)
    stabstr = __STABSTR_BEGIN__;
c0100664:	c7 45 ec 0d 28 11 c0 	movl   $0xc011280d,-0x14(%ebp)
    stabstr_end = __STABSTR_END__;
c010066b:	c7 45 e8 2e 53 11 c0 	movl   $0xc011532e,-0x18(%ebp)

    // String table validity checks
    if (stabstr_end <= stabstr || stabstr_end[-1] != 0) {
c0100672:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0100675:	3b 45 ec             	cmp    -0x14(%ebp),%eax
c0100678:	76 0b                	jbe    c0100685 <debuginfo_eip+0x6f>
c010067a:	8b 45 e8             	mov    -0x18(%ebp),%eax
c010067d:	48                   	dec    %eax
c010067e:	0f b6 00             	movzbl (%eax),%eax
c0100681:	84 c0                	test   %al,%al
c0100683:	74 0a                	je     c010068f <debuginfo_eip+0x79>
        return -1;
c0100685:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c010068a:	e9 b7 02 00 00       	jmp    c0100946 <debuginfo_eip+0x330>
    // 'eip'.  First, we find the basic source file containing 'eip'.
    // Then, we look in that source file for the function.  Then we look
    // for the line number.

    // Search the entire set of stabs for the source file (type N_SO).
    int lfile = 0, rfile = (stab_end - stabs) - 1;
c010068f:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
c0100696:	8b 55 f0             	mov    -0x10(%ebp),%edx
c0100699:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010069c:	29 c2                	sub    %eax,%edx
c010069e:	89 d0                	mov    %edx,%eax
c01006a0:	c1 f8 02             	sar    $0x2,%eax
c01006a3:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
c01006a9:	48                   	dec    %eax
c01006aa:	89 45 e0             	mov    %eax,-0x20(%ebp)
    stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
c01006ad:	8b 45 08             	mov    0x8(%ebp),%eax
c01006b0:	89 44 24 10          	mov    %eax,0x10(%esp)
c01006b4:	c7 44 24 0c 64 00 00 	movl   $0x64,0xc(%esp)
c01006bb:	00 
c01006bc:	8d 45 e0             	lea    -0x20(%ebp),%eax
c01006bf:	89 44 24 08          	mov    %eax,0x8(%esp)
c01006c3:	8d 45 e4             	lea    -0x1c(%ebp),%eax
c01006c6:	89 44 24 04          	mov    %eax,0x4(%esp)
c01006ca:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01006cd:	89 04 24             	mov    %eax,(%esp)
c01006d0:	e8 f3 fd ff ff       	call   c01004c8 <stab_binsearch>
    if (lfile == 0)
c01006d5:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c01006d8:	85 c0                	test   %eax,%eax
c01006da:	75 0a                	jne    c01006e6 <debuginfo_eip+0xd0>
        return -1;
c01006dc:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c01006e1:	e9 60 02 00 00       	jmp    c0100946 <debuginfo_eip+0x330>

    // Search within that file's stabs for the function definition
    // (N_FUN).
    int lfun = lfile, rfun = rfile;
c01006e6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c01006e9:	89 45 dc             	mov    %eax,-0x24(%ebp)
c01006ec:	8b 45 e0             	mov    -0x20(%ebp),%eax
c01006ef:	89 45 d8             	mov    %eax,-0x28(%ebp)
    int lline, rline;
    stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
c01006f2:	8b 45 08             	mov    0x8(%ebp),%eax
c01006f5:	89 44 24 10          	mov    %eax,0x10(%esp)
c01006f9:	c7 44 24 0c 24 00 00 	movl   $0x24,0xc(%esp)
c0100700:	00 
c0100701:	8d 45 d8             	lea    -0x28(%ebp),%eax
c0100704:	89 44 24 08          	mov    %eax,0x8(%esp)
c0100708:	8d 45 dc             	lea    -0x24(%ebp),%eax
c010070b:	89 44 24 04          	mov    %eax,0x4(%esp)
c010070f:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100712:	89 04 24             	mov    %eax,(%esp)
c0100715:	e8 ae fd ff ff       	call   c01004c8 <stab_binsearch>

    if (lfun <= rfun) {
c010071a:	8b 55 dc             	mov    -0x24(%ebp),%edx
c010071d:	8b 45 d8             	mov    -0x28(%ebp),%eax
c0100720:	39 c2                	cmp    %eax,%edx
c0100722:	7f 7c                	jg     c01007a0 <debuginfo_eip+0x18a>
        // stabs[lfun] points to the function name
        // in the string table, but check bounds just in case.
        if (stabs[lfun].n_strx < stabstr_end - stabstr) {
c0100724:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0100727:	89 c2                	mov    %eax,%edx
c0100729:	89 d0                	mov    %edx,%eax
c010072b:	01 c0                	add    %eax,%eax
c010072d:	01 d0                	add    %edx,%eax
c010072f:	c1 e0 02             	shl    $0x2,%eax
c0100732:	89 c2                	mov    %eax,%edx
c0100734:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100737:	01 d0                	add    %edx,%eax
c0100739:	8b 00                	mov    (%eax),%eax
c010073b:	8b 4d e8             	mov    -0x18(%ebp),%ecx
c010073e:	8b 55 ec             	mov    -0x14(%ebp),%edx
c0100741:	29 d1                	sub    %edx,%ecx
c0100743:	89 ca                	mov    %ecx,%edx
c0100745:	39 d0                	cmp    %edx,%eax
c0100747:	73 22                	jae    c010076b <debuginfo_eip+0x155>
            info->eip_fn_name = stabstr + stabs[lfun].n_strx;
c0100749:	8b 45 dc             	mov    -0x24(%ebp),%eax
c010074c:	89 c2                	mov    %eax,%edx
c010074e:	89 d0                	mov    %edx,%eax
c0100750:	01 c0                	add    %eax,%eax
c0100752:	01 d0                	add    %edx,%eax
c0100754:	c1 e0 02             	shl    $0x2,%eax
c0100757:	89 c2                	mov    %eax,%edx
c0100759:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010075c:	01 d0                	add    %edx,%eax
c010075e:	8b 10                	mov    (%eax),%edx
c0100760:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0100763:	01 c2                	add    %eax,%edx
c0100765:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100768:	89 50 08             	mov    %edx,0x8(%eax)
        }
        info->eip_fn_addr = stabs[lfun].n_value;
c010076b:	8b 45 dc             	mov    -0x24(%ebp),%eax
c010076e:	89 c2                	mov    %eax,%edx
c0100770:	89 d0                	mov    %edx,%eax
c0100772:	01 c0                	add    %eax,%eax
c0100774:	01 d0                	add    %edx,%eax
c0100776:	c1 e0 02             	shl    $0x2,%eax
c0100779:	89 c2                	mov    %eax,%edx
c010077b:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010077e:	01 d0                	add    %edx,%eax
c0100780:	8b 50 08             	mov    0x8(%eax),%edx
c0100783:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100786:	89 50 10             	mov    %edx,0x10(%eax)
        addr -= info->eip_fn_addr;
c0100789:	8b 45 0c             	mov    0xc(%ebp),%eax
c010078c:	8b 40 10             	mov    0x10(%eax),%eax
c010078f:	29 45 08             	sub    %eax,0x8(%ebp)
        // Search within the function definition for the line number.
        lline = lfun;
c0100792:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0100795:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        rline = rfun;
c0100798:	8b 45 d8             	mov    -0x28(%ebp),%eax
c010079b:	89 45 d0             	mov    %eax,-0x30(%ebp)
c010079e:	eb 15                	jmp    c01007b5 <debuginfo_eip+0x19f>
    } else {
        // Couldn't find function stab!  Maybe we're in an assembly
        // file.  Search the whole file for the line number.
        info->eip_fn_addr = addr;
c01007a0:	8b 45 0c             	mov    0xc(%ebp),%eax
c01007a3:	8b 55 08             	mov    0x8(%ebp),%edx
c01007a6:	89 50 10             	mov    %edx,0x10(%eax)
        lline = lfile;
c01007a9:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c01007ac:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        rline = rfile;
c01007af:	8b 45 e0             	mov    -0x20(%ebp),%eax
c01007b2:	89 45 d0             	mov    %eax,-0x30(%ebp)
    }
    info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
c01007b5:	8b 45 0c             	mov    0xc(%ebp),%eax
c01007b8:	8b 40 08             	mov    0x8(%eax),%eax
c01007bb:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
c01007c2:	00 
c01007c3:	89 04 24             	mov    %eax,(%esp)
c01007c6:	e8 35 50 00 00       	call   c0105800 <strfind>
c01007cb:	89 c2                	mov    %eax,%edx
c01007cd:	8b 45 0c             	mov    0xc(%ebp),%eax
c01007d0:	8b 40 08             	mov    0x8(%eax),%eax
c01007d3:	29 c2                	sub    %eax,%edx
c01007d5:	8b 45 0c             	mov    0xc(%ebp),%eax
c01007d8:	89 50 0c             	mov    %edx,0xc(%eax)

    // Search within [lline, rline] for the line number stab.
    // If found, set info->eip_line to the right line number.
    // If not found, return -1.
    stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
c01007db:	8b 45 08             	mov    0x8(%ebp),%eax
c01007de:	89 44 24 10          	mov    %eax,0x10(%esp)
c01007e2:	c7 44 24 0c 44 00 00 	movl   $0x44,0xc(%esp)
c01007e9:	00 
c01007ea:	8d 45 d0             	lea    -0x30(%ebp),%eax
c01007ed:	89 44 24 08          	mov    %eax,0x8(%esp)
c01007f1:	8d 45 d4             	lea    -0x2c(%ebp),%eax
c01007f4:	89 44 24 04          	mov    %eax,0x4(%esp)
c01007f8:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01007fb:	89 04 24             	mov    %eax,(%esp)
c01007fe:	e8 c5 fc ff ff       	call   c01004c8 <stab_binsearch>
    if (lline <= rline) {
c0100803:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0100806:	8b 45 d0             	mov    -0x30(%ebp),%eax
c0100809:	39 c2                	cmp    %eax,%edx
c010080b:	7f 23                	jg     c0100830 <debuginfo_eip+0x21a>
        info->eip_line = stabs[rline].n_desc;
c010080d:	8b 45 d0             	mov    -0x30(%ebp),%eax
c0100810:	89 c2                	mov    %eax,%edx
c0100812:	89 d0                	mov    %edx,%eax
c0100814:	01 c0                	add    %eax,%eax
c0100816:	01 d0                	add    %edx,%eax
c0100818:	c1 e0 02             	shl    $0x2,%eax
c010081b:	89 c2                	mov    %eax,%edx
c010081d:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100820:	01 d0                	add    %edx,%eax
c0100822:	0f b7 40 06          	movzwl 0x6(%eax),%eax
c0100826:	89 c2                	mov    %eax,%edx
c0100828:	8b 45 0c             	mov    0xc(%ebp),%eax
c010082b:	89 50 04             	mov    %edx,0x4(%eax)

    // Search backwards from the line number for the relevant filename stab.
    // We can't just use the "lfile" stab because inlined functions
    // can interpolate code from a different file!
    // Such included source files use the N_SOL stab type.
    while (lline >= lfile
c010082e:	eb 11                	jmp    c0100841 <debuginfo_eip+0x22b>
        return -1;
c0100830:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c0100835:	e9 0c 01 00 00       	jmp    c0100946 <debuginfo_eip+0x330>
           && stabs[lline].n_type != N_SOL
           && (stabs[lline].n_type != N_SO || !stabs[lline].n_value)) {
        lline --;
c010083a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c010083d:	48                   	dec    %eax
c010083e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
    while (lline >= lfile
c0100841:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0100844:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0100847:	39 c2                	cmp    %eax,%edx
c0100849:	7c 56                	jl     c01008a1 <debuginfo_eip+0x28b>
           && stabs[lline].n_type != N_SOL
c010084b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c010084e:	89 c2                	mov    %eax,%edx
c0100850:	89 d0                	mov    %edx,%eax
c0100852:	01 c0                	add    %eax,%eax
c0100854:	01 d0                	add    %edx,%eax
c0100856:	c1 e0 02             	shl    $0x2,%eax
c0100859:	89 c2                	mov    %eax,%edx
c010085b:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010085e:	01 d0                	add    %edx,%eax
c0100860:	0f b6 40 04          	movzbl 0x4(%eax),%eax
c0100864:	3c 84                	cmp    $0x84,%al
c0100866:	74 39                	je     c01008a1 <debuginfo_eip+0x28b>
           && (stabs[lline].n_type != N_SO || !stabs[lline].n_value)) {
c0100868:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c010086b:	89 c2                	mov    %eax,%edx
c010086d:	89 d0                	mov    %edx,%eax
c010086f:	01 c0                	add    %eax,%eax
c0100871:	01 d0                	add    %edx,%eax
c0100873:	c1 e0 02             	shl    $0x2,%eax
c0100876:	89 c2                	mov    %eax,%edx
c0100878:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010087b:	01 d0                	add    %edx,%eax
c010087d:	0f b6 40 04          	movzbl 0x4(%eax),%eax
c0100881:	3c 64                	cmp    $0x64,%al
c0100883:	75 b5                	jne    c010083a <debuginfo_eip+0x224>
c0100885:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c0100888:	89 c2                	mov    %eax,%edx
c010088a:	89 d0                	mov    %edx,%eax
c010088c:	01 c0                	add    %eax,%eax
c010088e:	01 d0                	add    %edx,%eax
c0100890:	c1 e0 02             	shl    $0x2,%eax
c0100893:	89 c2                	mov    %eax,%edx
c0100895:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100898:	01 d0                	add    %edx,%eax
c010089a:	8b 40 08             	mov    0x8(%eax),%eax
c010089d:	85 c0                	test   %eax,%eax
c010089f:	74 99                	je     c010083a <debuginfo_eip+0x224>
    }
    if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr) {
c01008a1:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c01008a4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c01008a7:	39 c2                	cmp    %eax,%edx
c01008a9:	7c 46                	jl     c01008f1 <debuginfo_eip+0x2db>
c01008ab:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c01008ae:	89 c2                	mov    %eax,%edx
c01008b0:	89 d0                	mov    %edx,%eax
c01008b2:	01 c0                	add    %eax,%eax
c01008b4:	01 d0                	add    %edx,%eax
c01008b6:	c1 e0 02             	shl    $0x2,%eax
c01008b9:	89 c2                	mov    %eax,%edx
c01008bb:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01008be:	01 d0                	add    %edx,%eax
c01008c0:	8b 00                	mov    (%eax),%eax
c01008c2:	8b 4d e8             	mov    -0x18(%ebp),%ecx
c01008c5:	8b 55 ec             	mov    -0x14(%ebp),%edx
c01008c8:	29 d1                	sub    %edx,%ecx
c01008ca:	89 ca                	mov    %ecx,%edx
c01008cc:	39 d0                	cmp    %edx,%eax
c01008ce:	73 21                	jae    c01008f1 <debuginfo_eip+0x2db>
        info->eip_file = stabstr + stabs[lline].n_strx;
c01008d0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c01008d3:	89 c2                	mov    %eax,%edx
c01008d5:	89 d0                	mov    %edx,%eax
c01008d7:	01 c0                	add    %eax,%eax
c01008d9:	01 d0                	add    %edx,%eax
c01008db:	c1 e0 02             	shl    $0x2,%eax
c01008de:	89 c2                	mov    %eax,%edx
c01008e0:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01008e3:	01 d0                	add    %edx,%eax
c01008e5:	8b 10                	mov    (%eax),%edx
c01008e7:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01008ea:	01 c2                	add    %eax,%edx
c01008ec:	8b 45 0c             	mov    0xc(%ebp),%eax
c01008ef:	89 10                	mov    %edx,(%eax)
    }

    // Set eip_fn_narg to the number of arguments taken by the function,
    // or 0 if there was no containing function.
    if (lfun < rfun) {
c01008f1:	8b 55 dc             	mov    -0x24(%ebp),%edx
c01008f4:	8b 45 d8             	mov    -0x28(%ebp),%eax
c01008f7:	39 c2                	cmp    %eax,%edx
c01008f9:	7d 46                	jge    c0100941 <debuginfo_eip+0x32b>
        for (lline = lfun + 1;
c01008fb:	8b 45 dc             	mov    -0x24(%ebp),%eax
c01008fe:	40                   	inc    %eax
c01008ff:	89 45 d4             	mov    %eax,-0x2c(%ebp)
c0100902:	eb 16                	jmp    c010091a <debuginfo_eip+0x304>
             lline < rfun && stabs[lline].n_type == N_PSYM;
             lline ++) {
            info->eip_fn_narg ++;
c0100904:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100907:	8b 40 14             	mov    0x14(%eax),%eax
c010090a:	8d 50 01             	lea    0x1(%eax),%edx
c010090d:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100910:	89 50 14             	mov    %edx,0x14(%eax)
             lline ++) {
c0100913:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c0100916:	40                   	inc    %eax
c0100917:	89 45 d4             	mov    %eax,-0x2c(%ebp)
             lline < rfun && stabs[lline].n_type == N_PSYM;
c010091a:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c010091d:	8b 45 d8             	mov    -0x28(%ebp),%eax
        for (lline = lfun + 1;
c0100920:	39 c2                	cmp    %eax,%edx
c0100922:	7d 1d                	jge    c0100941 <debuginfo_eip+0x32b>
             lline < rfun && stabs[lline].n_type == N_PSYM;
c0100924:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c0100927:	89 c2                	mov    %eax,%edx
c0100929:	89 d0                	mov    %edx,%eax
c010092b:	01 c0                	add    %eax,%eax
c010092d:	01 d0                	add    %edx,%eax
c010092f:	c1 e0 02             	shl    $0x2,%eax
c0100932:	89 c2                	mov    %eax,%edx
c0100934:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100937:	01 d0                	add    %edx,%eax
c0100939:	0f b6 40 04          	movzbl 0x4(%eax),%eax
c010093d:	3c a0                	cmp    $0xa0,%al
c010093f:	74 c3                	je     c0100904 <debuginfo_eip+0x2ee>
        }
    }
    return 0;
c0100941:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0100946:	c9                   	leave  
c0100947:	c3                   	ret    

c0100948 <print_kerninfo>:
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void
print_kerninfo(void) {
c0100948:	55                   	push   %ebp
c0100949:	89 e5                	mov    %esp,%ebp
c010094b:	83 ec 18             	sub    $0x18,%esp
    extern char etext[], edata[], end[], kern_init[];
    cprintf("Special kernel symbols:\n");
c010094e:	c7 04 24 82 62 10 c0 	movl   $0xc0106282,(%esp)
c0100955:	e8 48 f9 ff ff       	call   c01002a2 <cprintf>
    cprintf("  entry  0x%08x (phys)\n", kern_init);
c010095a:	c7 44 24 04 36 00 10 	movl   $0xc0100036,0x4(%esp)
c0100961:	c0 
c0100962:	c7 04 24 9b 62 10 c0 	movl   $0xc010629b,(%esp)
c0100969:	e8 34 f9 ff ff       	call   c01002a2 <cprintf>
    cprintf("  etext  0x%08x (phys)\n", etext);
c010096e:	c7 44 24 04 7e 61 10 	movl   $0xc010617e,0x4(%esp)
c0100975:	c0 
c0100976:	c7 04 24 b3 62 10 c0 	movl   $0xc01062b3,(%esp)
c010097d:	e8 20 f9 ff ff       	call   c01002a2 <cprintf>
    cprintf("  edata  0x%08x (phys)\n", edata);
c0100982:	c7 44 24 04 00 b0 11 	movl   $0xc011b000,0x4(%esp)
c0100989:	c0 
c010098a:	c7 04 24 cb 62 10 c0 	movl   $0xc01062cb,(%esp)
c0100991:	e8 0c f9 ff ff       	call   c01002a2 <cprintf>
    cprintf("  end    0x%08x (phys)\n", end);
c0100996:	c7 44 24 04 88 bf 11 	movl   $0xc011bf88,0x4(%esp)
c010099d:	c0 
c010099e:	c7 04 24 e3 62 10 c0 	movl   $0xc01062e3,(%esp)
c01009a5:	e8 f8 f8 ff ff       	call   c01002a2 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n", (end - kern_init + 1023)/1024);
c01009aa:	b8 88 bf 11 c0       	mov    $0xc011bf88,%eax
c01009af:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
c01009b5:	b8 36 00 10 c0       	mov    $0xc0100036,%eax
c01009ba:	29 c2                	sub    %eax,%edx
c01009bc:	89 d0                	mov    %edx,%eax
c01009be:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
c01009c4:	85 c0                	test   %eax,%eax
c01009c6:	0f 48 c2             	cmovs  %edx,%eax
c01009c9:	c1 f8 0a             	sar    $0xa,%eax
c01009cc:	89 44 24 04          	mov    %eax,0x4(%esp)
c01009d0:	c7 04 24 fc 62 10 c0 	movl   $0xc01062fc,(%esp)
c01009d7:	e8 c6 f8 ff ff       	call   c01002a2 <cprintf>
}
c01009dc:	90                   	nop
c01009dd:	c9                   	leave  
c01009de:	c3                   	ret    

c01009df <print_debuginfo>:
/* *
 * print_debuginfo - read and print the stat information for the address @eip,
 * and info.eip_fn_addr should be the first address of the related function.
 * */
void
print_debuginfo(uintptr_t eip) {
c01009df:	55                   	push   %ebp
c01009e0:	89 e5                	mov    %esp,%ebp
c01009e2:	81 ec 48 01 00 00    	sub    $0x148,%esp
    struct eipdebuginfo info;
    if (debuginfo_eip(eip, &info) != 0) {
c01009e8:	8d 45 dc             	lea    -0x24(%ebp),%eax
c01009eb:	89 44 24 04          	mov    %eax,0x4(%esp)
c01009ef:	8b 45 08             	mov    0x8(%ebp),%eax
c01009f2:	89 04 24             	mov    %eax,(%esp)
c01009f5:	e8 1c fc ff ff       	call   c0100616 <debuginfo_eip>
c01009fa:	85 c0                	test   %eax,%eax
c01009fc:	74 15                	je     c0100a13 <print_debuginfo+0x34>
        cprintf("    <unknow>: -- 0x%08x --\n", eip);
c01009fe:	8b 45 08             	mov    0x8(%ebp),%eax
c0100a01:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100a05:	c7 04 24 26 63 10 c0 	movl   $0xc0106326,(%esp)
c0100a0c:	e8 91 f8 ff ff       	call   c01002a2 <cprintf>
        }
        fnname[j] = '\0';
        cprintf("    %s:%d: %s+%d\n", info.eip_file, info.eip_line,
                fnname, eip - info.eip_fn_addr);
    }
}
c0100a11:	eb 6c                	jmp    c0100a7f <print_debuginfo+0xa0>
        for (j = 0; j < info.eip_fn_namelen; j ++) {
c0100a13:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
c0100a1a:	eb 1b                	jmp    c0100a37 <print_debuginfo+0x58>
            fnname[j] = info.eip_fn_name[j];
c0100a1c:	8b 55 e4             	mov    -0x1c(%ebp),%edx
c0100a1f:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100a22:	01 d0                	add    %edx,%eax
c0100a24:	0f b6 00             	movzbl (%eax),%eax
c0100a27:	8d 8d dc fe ff ff    	lea    -0x124(%ebp),%ecx
c0100a2d:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0100a30:	01 ca                	add    %ecx,%edx
c0100a32:	88 02                	mov    %al,(%edx)
        for (j = 0; j < info.eip_fn_namelen; j ++) {
c0100a34:	ff 45 f4             	incl   -0xc(%ebp)
c0100a37:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0100a3a:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c0100a3d:	7c dd                	jl     c0100a1c <print_debuginfo+0x3d>
        fnname[j] = '\0';
c0100a3f:	8d 95 dc fe ff ff    	lea    -0x124(%ebp),%edx
c0100a45:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100a48:	01 d0                	add    %edx,%eax
c0100a4a:	c6 00 00             	movb   $0x0,(%eax)
                fnname, eip - info.eip_fn_addr);
c0100a4d:	8b 45 ec             	mov    -0x14(%ebp),%eax
        cprintf("    %s:%d: %s+%d\n", info.eip_file, info.eip_line,
c0100a50:	8b 55 08             	mov    0x8(%ebp),%edx
c0100a53:	89 d1                	mov    %edx,%ecx
c0100a55:	29 c1                	sub    %eax,%ecx
c0100a57:	8b 55 e0             	mov    -0x20(%ebp),%edx
c0100a5a:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0100a5d:	89 4c 24 10          	mov    %ecx,0x10(%esp)
c0100a61:	8d 8d dc fe ff ff    	lea    -0x124(%ebp),%ecx
c0100a67:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c0100a6b:	89 54 24 08          	mov    %edx,0x8(%esp)
c0100a6f:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100a73:	c7 04 24 42 63 10 c0 	movl   $0xc0106342,(%esp)
c0100a7a:	e8 23 f8 ff ff       	call   c01002a2 <cprintf>
}
c0100a7f:	90                   	nop
c0100a80:	c9                   	leave  
c0100a81:	c3                   	ret    

c0100a82 <read_eip>:

static __noinline uint32_t
read_eip(void) {
c0100a82:	55                   	push   %ebp
c0100a83:	89 e5                	mov    %esp,%ebp
c0100a85:	83 ec 10             	sub    $0x10,%esp
    uint32_t eip;
    asm volatile("movl 4(%%ebp), %0" : "=r" (eip));
c0100a88:	8b 45 04             	mov    0x4(%ebp),%eax
c0100a8b:	89 45 fc             	mov    %eax,-0x4(%ebp)
    return eip;
c0100a8e:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
c0100a91:	c9                   	leave  
c0100a92:	c3                   	ret    

c0100a93 <print_stackframe>:
 *
 * Note that, the length of ebp-chain is limited. In boot/bootasm.S, before jumping
 * to the kernel entry, the value of ebp has been set to zero, that's the boundary.
 * */
void
print_stackframe(void) {
c0100a93:	55                   	push   %ebp
c0100a94:	89 e5                	mov    %esp,%ebp
c0100a96:	83 ec 38             	sub    $0x38,%esp
}

static inline uint32_t
read_ebp(void) {
    uint32_t ebp;
    asm volatile ("movl %%ebp, %0" : "=r" (ebp));
c0100a99:	89 e8                	mov    %ebp,%eax
c0100a9b:	89 45 e0             	mov    %eax,-0x20(%ebp)
    return ebp;
c0100a9e:	8b 45 e0             	mov    -0x20(%ebp),%eax
      *    (3.4) call print_debuginfo(eip-1) to print the C calling function name and line number, etc.
      *    (3.5) popup a calling stackframe
      *           NOTICE: the calling funciton's return addr eip  = ss:[ebp+4]
      *                   the calling funciton's ebp = ss:[ebp]
      */
     uint32_t ebp = read_ebp(); //获取ebp的值
c0100aa1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    uint32_t eip = read_eip(); //获取eip的值
c0100aa4:	e8 d9 ff ff ff       	call   c0100a82 <read_eip>
c0100aa9:	89 45 f0             	mov    %eax,-0x10(%ebp)
    int i , j ;
    for (i = 0; ebp != 0 && i < STACKFRAME_DEPTH; i ++) {
c0100aac:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
c0100ab3:	e9 84 00 00 00       	jmp    c0100b3c <print_stackframe+0xa9>
        cprintf("ebp:0x%08x eip:0x%08x args:", ebp, eip); 
c0100ab8:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0100abb:	89 44 24 08          	mov    %eax,0x8(%esp)
c0100abf:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100ac2:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100ac6:	c7 04 24 54 63 10 c0 	movl   $0xc0106354,(%esp)
c0100acd:	e8 d0 f7 ff ff       	call   c01002a2 <cprintf>
        uint32_t *args = (uint32_t *)ebp + 2; //参数的首地址
c0100ad2:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100ad5:	83 c0 08             	add    $0x8,%eax
c0100ad8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
        for (j = 0; j < 4; j ++) {
c0100adb:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
c0100ae2:	eb 24                	jmp    c0100b08 <print_stackframe+0x75>
            cprintf("0x%08x ", args[j]); //打印4个参数
c0100ae4:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0100ae7:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
c0100aee:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0100af1:	01 d0                	add    %edx,%eax
c0100af3:	8b 00                	mov    (%eax),%eax
c0100af5:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100af9:	c7 04 24 70 63 10 c0 	movl   $0xc0106370,(%esp)
c0100b00:	e8 9d f7 ff ff       	call   c01002a2 <cprintf>
        for (j = 0; j < 4; j ++) {
c0100b05:	ff 45 e8             	incl   -0x18(%ebp)
c0100b08:	83 7d e8 03          	cmpl   $0x3,-0x18(%ebp)
c0100b0c:	7e d6                	jle    c0100ae4 <print_stackframe+0x51>
        }
        cprintf("\n");
c0100b0e:	c7 04 24 78 63 10 c0 	movl   $0xc0106378,(%esp)
c0100b15:	e8 88 f7 ff ff       	call   c01002a2 <cprintf>
        print_debuginfo(eip - 1);  //打印函数信息
c0100b1a:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0100b1d:	48                   	dec    %eax
c0100b1e:	89 04 24             	mov    %eax,(%esp)
c0100b21:	e8 b9 fe ff ff       	call   c01009df <print_debuginfo>
        eip = ((uint32_t *)ebp)[1]; //更新eip
c0100b26:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100b29:	83 c0 04             	add    $0x4,%eax
c0100b2c:	8b 00                	mov    (%eax),%eax
c0100b2e:	89 45 f0             	mov    %eax,-0x10(%ebp)
        ebp = ((uint32_t *)ebp)[0]; //更新ebp
c0100b31:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100b34:	8b 00                	mov    (%eax),%eax
c0100b36:	89 45 f4             	mov    %eax,-0xc(%ebp)
    for (i = 0; ebp != 0 && i < STACKFRAME_DEPTH; i ++) {
c0100b39:	ff 45 ec             	incl   -0x14(%ebp)
c0100b3c:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0100b40:	74 0a                	je     c0100b4c <print_stackframe+0xb9>
c0100b42:	83 7d ec 13          	cmpl   $0x13,-0x14(%ebp)
c0100b46:	0f 8e 6c ff ff ff    	jle    c0100ab8 <print_stackframe+0x25>
    }
}
c0100b4c:	90                   	nop
c0100b4d:	c9                   	leave  
c0100b4e:	c3                   	ret    

c0100b4f <parse>:
#define MAXARGS         16
#define WHITESPACE      " \t\n\r"

/* parse - parse the command buffer into whitespace-separated arguments */
static int
parse(char *buf, char **argv) {
c0100b4f:	55                   	push   %ebp
c0100b50:	89 e5                	mov    %esp,%ebp
c0100b52:	83 ec 28             	sub    $0x28,%esp
    int argc = 0;
c0100b55:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    while (1) {
        // find global whitespace
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
c0100b5c:	eb 0c                	jmp    c0100b6a <parse+0x1b>
            *buf ++ = '\0';
c0100b5e:	8b 45 08             	mov    0x8(%ebp),%eax
c0100b61:	8d 50 01             	lea    0x1(%eax),%edx
c0100b64:	89 55 08             	mov    %edx,0x8(%ebp)
c0100b67:	c6 00 00             	movb   $0x0,(%eax)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
c0100b6a:	8b 45 08             	mov    0x8(%ebp),%eax
c0100b6d:	0f b6 00             	movzbl (%eax),%eax
c0100b70:	84 c0                	test   %al,%al
c0100b72:	74 1d                	je     c0100b91 <parse+0x42>
c0100b74:	8b 45 08             	mov    0x8(%ebp),%eax
c0100b77:	0f b6 00             	movzbl (%eax),%eax
c0100b7a:	0f be c0             	movsbl %al,%eax
c0100b7d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100b81:	c7 04 24 fc 63 10 c0 	movl   $0xc01063fc,(%esp)
c0100b88:	e8 41 4c 00 00       	call   c01057ce <strchr>
c0100b8d:	85 c0                	test   %eax,%eax
c0100b8f:	75 cd                	jne    c0100b5e <parse+0xf>
        }
        if (*buf == '\0') {
c0100b91:	8b 45 08             	mov    0x8(%ebp),%eax
c0100b94:	0f b6 00             	movzbl (%eax),%eax
c0100b97:	84 c0                	test   %al,%al
c0100b99:	74 65                	je     c0100c00 <parse+0xb1>
            break;
        }

        // save and scan past next arg
        if (argc == MAXARGS - 1) {
c0100b9b:	83 7d f4 0f          	cmpl   $0xf,-0xc(%ebp)
c0100b9f:	75 14                	jne    c0100bb5 <parse+0x66>
            cprintf("Too many arguments (max %d).\n", MAXARGS);
c0100ba1:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
c0100ba8:	00 
c0100ba9:	c7 04 24 01 64 10 c0 	movl   $0xc0106401,(%esp)
c0100bb0:	e8 ed f6 ff ff       	call   c01002a2 <cprintf>
        }
        argv[argc ++] = buf;
c0100bb5:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100bb8:	8d 50 01             	lea    0x1(%eax),%edx
c0100bbb:	89 55 f4             	mov    %edx,-0xc(%ebp)
c0100bbe:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
c0100bc5:	8b 45 0c             	mov    0xc(%ebp),%eax
c0100bc8:	01 c2                	add    %eax,%edx
c0100bca:	8b 45 08             	mov    0x8(%ebp),%eax
c0100bcd:	89 02                	mov    %eax,(%edx)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
c0100bcf:	eb 03                	jmp    c0100bd4 <parse+0x85>
            buf ++;
c0100bd1:	ff 45 08             	incl   0x8(%ebp)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
c0100bd4:	8b 45 08             	mov    0x8(%ebp),%eax
c0100bd7:	0f b6 00             	movzbl (%eax),%eax
c0100bda:	84 c0                	test   %al,%al
c0100bdc:	74 8c                	je     c0100b6a <parse+0x1b>
c0100bde:	8b 45 08             	mov    0x8(%ebp),%eax
c0100be1:	0f b6 00             	movzbl (%eax),%eax
c0100be4:	0f be c0             	movsbl %al,%eax
c0100be7:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100beb:	c7 04 24 fc 63 10 c0 	movl   $0xc01063fc,(%esp)
c0100bf2:	e8 d7 4b 00 00       	call   c01057ce <strchr>
c0100bf7:	85 c0                	test   %eax,%eax
c0100bf9:	74 d6                	je     c0100bd1 <parse+0x82>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
c0100bfb:	e9 6a ff ff ff       	jmp    c0100b6a <parse+0x1b>
            break;
c0100c00:	90                   	nop
        }
    }
    return argc;
c0100c01:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c0100c04:	c9                   	leave  
c0100c05:	c3                   	ret    

c0100c06 <runcmd>:
/* *
 * runcmd - parse the input string, split it into separated arguments
 * and then lookup and invoke some related commands/
 * */
static int
runcmd(char *buf, struct trapframe *tf) {
c0100c06:	55                   	push   %ebp
c0100c07:	89 e5                	mov    %esp,%ebp
c0100c09:	53                   	push   %ebx
c0100c0a:	83 ec 64             	sub    $0x64,%esp
    char *argv[MAXARGS];
    int argc = parse(buf, argv);
c0100c0d:	8d 45 b0             	lea    -0x50(%ebp),%eax
c0100c10:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100c14:	8b 45 08             	mov    0x8(%ebp),%eax
c0100c17:	89 04 24             	mov    %eax,(%esp)
c0100c1a:	e8 30 ff ff ff       	call   c0100b4f <parse>
c0100c1f:	89 45 f0             	mov    %eax,-0x10(%ebp)
    if (argc == 0) {
c0100c22:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0100c26:	75 0a                	jne    c0100c32 <runcmd+0x2c>
        return 0;
c0100c28:	b8 00 00 00 00       	mov    $0x0,%eax
c0100c2d:	e9 83 00 00 00       	jmp    c0100cb5 <runcmd+0xaf>
    }
    int i;
    for (i = 0; i < NCOMMANDS; i ++) {
c0100c32:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
c0100c39:	eb 5a                	jmp    c0100c95 <runcmd+0x8f>
        if (strcmp(commands[i].name, argv[0]) == 0) {
c0100c3b:	8b 4d b0             	mov    -0x50(%ebp),%ecx
c0100c3e:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0100c41:	89 d0                	mov    %edx,%eax
c0100c43:	01 c0                	add    %eax,%eax
c0100c45:	01 d0                	add    %edx,%eax
c0100c47:	c1 e0 02             	shl    $0x2,%eax
c0100c4a:	05 00 80 11 c0       	add    $0xc0118000,%eax
c0100c4f:	8b 00                	mov    (%eax),%eax
c0100c51:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0100c55:	89 04 24             	mov    %eax,(%esp)
c0100c58:	e8 d4 4a 00 00       	call   c0105731 <strcmp>
c0100c5d:	85 c0                	test   %eax,%eax
c0100c5f:	75 31                	jne    c0100c92 <runcmd+0x8c>
            return commands[i].func(argc - 1, argv + 1, tf);
c0100c61:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0100c64:	89 d0                	mov    %edx,%eax
c0100c66:	01 c0                	add    %eax,%eax
c0100c68:	01 d0                	add    %edx,%eax
c0100c6a:	c1 e0 02             	shl    $0x2,%eax
c0100c6d:	05 08 80 11 c0       	add    $0xc0118008,%eax
c0100c72:	8b 10                	mov    (%eax),%edx
c0100c74:	8d 45 b0             	lea    -0x50(%ebp),%eax
c0100c77:	83 c0 04             	add    $0x4,%eax
c0100c7a:	8b 4d f0             	mov    -0x10(%ebp),%ecx
c0100c7d:	8d 59 ff             	lea    -0x1(%ecx),%ebx
c0100c80:	8b 4d 0c             	mov    0xc(%ebp),%ecx
c0100c83:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0100c87:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100c8b:	89 1c 24             	mov    %ebx,(%esp)
c0100c8e:	ff d2                	call   *%edx
c0100c90:	eb 23                	jmp    c0100cb5 <runcmd+0xaf>
    for (i = 0; i < NCOMMANDS; i ++) {
c0100c92:	ff 45 f4             	incl   -0xc(%ebp)
c0100c95:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100c98:	83 f8 02             	cmp    $0x2,%eax
c0100c9b:	76 9e                	jbe    c0100c3b <runcmd+0x35>
        }
    }
    cprintf("Unknown command '%s'\n", argv[0]);
c0100c9d:	8b 45 b0             	mov    -0x50(%ebp),%eax
c0100ca0:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100ca4:	c7 04 24 1f 64 10 c0 	movl   $0xc010641f,(%esp)
c0100cab:	e8 f2 f5 ff ff       	call   c01002a2 <cprintf>
    return 0;
c0100cb0:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0100cb5:	83 c4 64             	add    $0x64,%esp
c0100cb8:	5b                   	pop    %ebx
c0100cb9:	5d                   	pop    %ebp
c0100cba:	c3                   	ret    

c0100cbb <kmonitor>:

/***** Implementations of basic kernel monitor commands *****/

void
kmonitor(struct trapframe *tf) {
c0100cbb:	55                   	push   %ebp
c0100cbc:	89 e5                	mov    %esp,%ebp
c0100cbe:	83 ec 28             	sub    $0x28,%esp
    cprintf("Welcome to the kernel debug monitor!!\n");
c0100cc1:	c7 04 24 38 64 10 c0 	movl   $0xc0106438,(%esp)
c0100cc8:	e8 d5 f5 ff ff       	call   c01002a2 <cprintf>
    cprintf("Type 'help' for a list of commands.\n");
c0100ccd:	c7 04 24 60 64 10 c0 	movl   $0xc0106460,(%esp)
c0100cd4:	e8 c9 f5 ff ff       	call   c01002a2 <cprintf>

    if (tf != NULL) {
c0100cd9:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
c0100cdd:	74 0b                	je     c0100cea <kmonitor+0x2f>
        print_trapframe(tf);
c0100cdf:	8b 45 08             	mov    0x8(%ebp),%eax
c0100ce2:	89 04 24             	mov    %eax,(%esp)
c0100ce5:	e8 b4 0d 00 00       	call   c0101a9e <print_trapframe>
    }

    char *buf;
    while (1) {
        if ((buf = readline("K> ")) != NULL) {
c0100cea:	c7 04 24 85 64 10 c0 	movl   $0xc0106485,(%esp)
c0100cf1:	e8 4e f6 ff ff       	call   c0100344 <readline>
c0100cf6:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0100cf9:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0100cfd:	74 eb                	je     c0100cea <kmonitor+0x2f>
            if (runcmd(buf, tf) < 0) {
c0100cff:	8b 45 08             	mov    0x8(%ebp),%eax
c0100d02:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100d06:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100d09:	89 04 24             	mov    %eax,(%esp)
c0100d0c:	e8 f5 fe ff ff       	call   c0100c06 <runcmd>
c0100d11:	85 c0                	test   %eax,%eax
c0100d13:	78 02                	js     c0100d17 <kmonitor+0x5c>
        if ((buf = readline("K> ")) != NULL) {
c0100d15:	eb d3                	jmp    c0100cea <kmonitor+0x2f>
                break;
c0100d17:	90                   	nop
            }
        }
    }
}
c0100d18:	90                   	nop
c0100d19:	c9                   	leave  
c0100d1a:	c3                   	ret    

c0100d1b <mon_help>:

/* mon_help - print the information about mon_* functions */
int
mon_help(int argc, char **argv, struct trapframe *tf) {
c0100d1b:	55                   	push   %ebp
c0100d1c:	89 e5                	mov    %esp,%ebp
c0100d1e:	83 ec 28             	sub    $0x28,%esp
    int i;
    for (i = 0; i < NCOMMANDS; i ++) {
c0100d21:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
c0100d28:	eb 3d                	jmp    c0100d67 <mon_help+0x4c>
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
c0100d2a:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0100d2d:	89 d0                	mov    %edx,%eax
c0100d2f:	01 c0                	add    %eax,%eax
c0100d31:	01 d0                	add    %edx,%eax
c0100d33:	c1 e0 02             	shl    $0x2,%eax
c0100d36:	05 04 80 11 c0       	add    $0xc0118004,%eax
c0100d3b:	8b 08                	mov    (%eax),%ecx
c0100d3d:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0100d40:	89 d0                	mov    %edx,%eax
c0100d42:	01 c0                	add    %eax,%eax
c0100d44:	01 d0                	add    %edx,%eax
c0100d46:	c1 e0 02             	shl    $0x2,%eax
c0100d49:	05 00 80 11 c0       	add    $0xc0118000,%eax
c0100d4e:	8b 00                	mov    (%eax),%eax
c0100d50:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c0100d54:	89 44 24 04          	mov    %eax,0x4(%esp)
c0100d58:	c7 04 24 89 64 10 c0 	movl   $0xc0106489,(%esp)
c0100d5f:	e8 3e f5 ff ff       	call   c01002a2 <cprintf>
    for (i = 0; i < NCOMMANDS; i ++) {
c0100d64:	ff 45 f4             	incl   -0xc(%ebp)
c0100d67:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100d6a:	83 f8 02             	cmp    $0x2,%eax
c0100d6d:	76 bb                	jbe    c0100d2a <mon_help+0xf>
    }
    return 0;
c0100d6f:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0100d74:	c9                   	leave  
c0100d75:	c3                   	ret    

c0100d76 <mon_kerninfo>:
/* *
 * mon_kerninfo - call print_kerninfo in kern/debug/kdebug.c to
 * print the memory occupancy in kernel.
 * */
int
mon_kerninfo(int argc, char **argv, struct trapframe *tf) {
c0100d76:	55                   	push   %ebp
c0100d77:	89 e5                	mov    %esp,%ebp
c0100d79:	83 ec 08             	sub    $0x8,%esp
    print_kerninfo();
c0100d7c:	e8 c7 fb ff ff       	call   c0100948 <print_kerninfo>
    return 0;
c0100d81:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0100d86:	c9                   	leave  
c0100d87:	c3                   	ret    

c0100d88 <mon_backtrace>:
/* *
 * mon_backtrace - call print_stackframe in kern/debug/kdebug.c to
 * print a backtrace of the stack.
 * */
int
mon_backtrace(int argc, char **argv, struct trapframe *tf) {
c0100d88:	55                   	push   %ebp
c0100d89:	89 e5                	mov    %esp,%ebp
c0100d8b:	83 ec 08             	sub    $0x8,%esp
    print_stackframe();
c0100d8e:	e8 00 fd ff ff       	call   c0100a93 <print_stackframe>
    return 0;
c0100d93:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0100d98:	c9                   	leave  
c0100d99:	c3                   	ret    

c0100d9a <clock_init>:
/* *
 * clock_init - initialize 8253 clock to interrupt 100 times per second,
 * and then enable IRQ_TIMER.
 * */
void
clock_init(void) {
c0100d9a:	55                   	push   %ebp
c0100d9b:	89 e5                	mov    %esp,%ebp
c0100d9d:	83 ec 28             	sub    $0x28,%esp
c0100da0:	66 c7 45 ee 43 00    	movw   $0x43,-0x12(%ebp)
c0100da6:	c6 45 ed 34          	movb   $0x34,-0x13(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
c0100daa:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
c0100dae:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
c0100db2:	ee                   	out    %al,(%dx)
c0100db3:	66 c7 45 f2 40 00    	movw   $0x40,-0xe(%ebp)
c0100db9:	c6 45 f1 9c          	movb   $0x9c,-0xf(%ebp)
c0100dbd:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
c0100dc1:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
c0100dc5:	ee                   	out    %al,(%dx)
c0100dc6:	66 c7 45 f6 40 00    	movw   $0x40,-0xa(%ebp)
c0100dcc:	c6 45 f5 2e          	movb   $0x2e,-0xb(%ebp)
c0100dd0:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
c0100dd4:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
c0100dd8:	ee                   	out    %al,(%dx)
    outb(TIMER_MODE, TIMER_SEL0 | TIMER_RATEGEN | TIMER_16BIT);
    outb(IO_TIMER1, TIMER_DIV(100) % 256);
    outb(IO_TIMER1, TIMER_DIV(100) / 256);

    // initialize time counter 'ticks' to zero
    ticks = 0;
c0100dd9:	c7 05 0c bf 11 c0 00 	movl   $0x0,0xc011bf0c
c0100de0:	00 00 00 

    cprintf("++ setup timer interrupts\n");
c0100de3:	c7 04 24 92 64 10 c0 	movl   $0xc0106492,(%esp)
c0100dea:	e8 b3 f4 ff ff       	call   c01002a2 <cprintf>
    pic_enable(IRQ_TIMER);
c0100def:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c0100df6:	e8 2e 09 00 00       	call   c0101729 <pic_enable>
}
c0100dfb:	90                   	nop
c0100dfc:	c9                   	leave  
c0100dfd:	c3                   	ret    

c0100dfe <__intr_save>:
#include <x86.h>
#include <intr.h>
#include <mmu.h>

static inline bool
__intr_save(void) {
c0100dfe:	55                   	push   %ebp
c0100dff:	89 e5                	mov    %esp,%ebp
c0100e01:	83 ec 18             	sub    $0x18,%esp
}

static inline uint32_t
read_eflags(void) {
    uint32_t eflags;
    asm volatile ("pushfl; popl %0" : "=r" (eflags));
c0100e04:	9c                   	pushf  
c0100e05:	58                   	pop    %eax
c0100e06:	89 45 f4             	mov    %eax,-0xc(%ebp)
    return eflags;
c0100e09:	8b 45 f4             	mov    -0xc(%ebp),%eax
    if (read_eflags() & FL_IF) {
c0100e0c:	25 00 02 00 00       	and    $0x200,%eax
c0100e11:	85 c0                	test   %eax,%eax
c0100e13:	74 0c                	je     c0100e21 <__intr_save+0x23>
        intr_disable();
c0100e15:	e8 83 0a 00 00       	call   c010189d <intr_disable>
        return 1;
c0100e1a:	b8 01 00 00 00       	mov    $0x1,%eax
c0100e1f:	eb 05                	jmp    c0100e26 <__intr_save+0x28>
    }
    return 0;
c0100e21:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0100e26:	c9                   	leave  
c0100e27:	c3                   	ret    

c0100e28 <__intr_restore>:

static inline void
__intr_restore(bool flag) {
c0100e28:	55                   	push   %ebp
c0100e29:	89 e5                	mov    %esp,%ebp
c0100e2b:	83 ec 08             	sub    $0x8,%esp
    if (flag) {
c0100e2e:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
c0100e32:	74 05                	je     c0100e39 <__intr_restore+0x11>
        intr_enable();
c0100e34:	e8 5d 0a 00 00       	call   c0101896 <intr_enable>
    }
}
c0100e39:	90                   	nop
c0100e3a:	c9                   	leave  
c0100e3b:	c3                   	ret    

c0100e3c <delay>:
#include <memlayout.h>
#include <sync.h>

/* stupid I/O delay routine necessitated by historical PC design flaws */
static void
delay(void) {
c0100e3c:	55                   	push   %ebp
c0100e3d:	89 e5                	mov    %esp,%ebp
c0100e3f:	83 ec 10             	sub    $0x10,%esp
c0100e42:	66 c7 45 f2 84 00    	movw   $0x84,-0xe(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0100e48:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
c0100e4c:	89 c2                	mov    %eax,%edx
c0100e4e:	ec                   	in     (%dx),%al
c0100e4f:	88 45 f1             	mov    %al,-0xf(%ebp)
c0100e52:	66 c7 45 f6 84 00    	movw   $0x84,-0xa(%ebp)
c0100e58:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
c0100e5c:	89 c2                	mov    %eax,%edx
c0100e5e:	ec                   	in     (%dx),%al
c0100e5f:	88 45 f5             	mov    %al,-0xb(%ebp)
c0100e62:	66 c7 45 fa 84 00    	movw   $0x84,-0x6(%ebp)
c0100e68:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
c0100e6c:	89 c2                	mov    %eax,%edx
c0100e6e:	ec                   	in     (%dx),%al
c0100e6f:	88 45 f9             	mov    %al,-0x7(%ebp)
c0100e72:	66 c7 45 fe 84 00    	movw   $0x84,-0x2(%ebp)
c0100e78:	0f b7 45 fe          	movzwl -0x2(%ebp),%eax
c0100e7c:	89 c2                	mov    %eax,%edx
c0100e7e:	ec                   	in     (%dx),%al
c0100e7f:	88 45 fd             	mov    %al,-0x3(%ebp)
    inb(0x84);
    inb(0x84);
    inb(0x84);
    inb(0x84);
}
c0100e82:	90                   	nop
c0100e83:	c9                   	leave  
c0100e84:	c3                   	ret    

c0100e85 <cga_init>:
static uint16_t addr_6845;

/* TEXT-mode CGA/VGA display output */

static void
cga_init(void) {
c0100e85:	55                   	push   %ebp
c0100e86:	89 e5                	mov    %esp,%ebp
c0100e88:	83 ec 20             	sub    $0x20,%esp
    volatile uint16_t *cp = (uint16_t *)(CGA_BUF + KERNBASE);
c0100e8b:	c7 45 fc 00 80 0b c0 	movl   $0xc00b8000,-0x4(%ebp)
    uint16_t was = *cp;
c0100e92:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0100e95:	0f b7 00             	movzwl (%eax),%eax
c0100e98:	66 89 45 fa          	mov    %ax,-0x6(%ebp)
    *cp = (uint16_t) 0xA55A;
c0100e9c:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0100e9f:	66 c7 00 5a a5       	movw   $0xa55a,(%eax)
    if (*cp != 0xA55A) {
c0100ea4:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0100ea7:	0f b7 00             	movzwl (%eax),%eax
c0100eaa:	0f b7 c0             	movzwl %ax,%eax
c0100ead:	3d 5a a5 00 00       	cmp    $0xa55a,%eax
c0100eb2:	74 12                	je     c0100ec6 <cga_init+0x41>
        cp = (uint16_t*)(MONO_BUF + KERNBASE);
c0100eb4:	c7 45 fc 00 00 0b c0 	movl   $0xc00b0000,-0x4(%ebp)
        addr_6845 = MONO_BASE;
c0100ebb:	66 c7 05 46 b4 11 c0 	movw   $0x3b4,0xc011b446
c0100ec2:	b4 03 
c0100ec4:	eb 13                	jmp    c0100ed9 <cga_init+0x54>
    } else {
        *cp = was;
c0100ec6:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0100ec9:	0f b7 55 fa          	movzwl -0x6(%ebp),%edx
c0100ecd:	66 89 10             	mov    %dx,(%eax)
        addr_6845 = CGA_BASE;
c0100ed0:	66 c7 05 46 b4 11 c0 	movw   $0x3d4,0xc011b446
c0100ed7:	d4 03 
    }

    // Extract cursor location
    uint32_t pos;
    outb(addr_6845, 14);
c0100ed9:	0f b7 05 46 b4 11 c0 	movzwl 0xc011b446,%eax
c0100ee0:	66 89 45 e6          	mov    %ax,-0x1a(%ebp)
c0100ee4:	c6 45 e5 0e          	movb   $0xe,-0x1b(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
c0100ee8:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
c0100eec:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
c0100ef0:	ee                   	out    %al,(%dx)
    pos = inb(addr_6845 + 1) << 8;
c0100ef1:	0f b7 05 46 b4 11 c0 	movzwl 0xc011b446,%eax
c0100ef8:	40                   	inc    %eax
c0100ef9:	0f b7 c0             	movzwl %ax,%eax
c0100efc:	66 89 45 ea          	mov    %ax,-0x16(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0100f00:	0f b7 45 ea          	movzwl -0x16(%ebp),%eax
c0100f04:	89 c2                	mov    %eax,%edx
c0100f06:	ec                   	in     (%dx),%al
c0100f07:	88 45 e9             	mov    %al,-0x17(%ebp)
    return data;
c0100f0a:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
c0100f0e:	0f b6 c0             	movzbl %al,%eax
c0100f11:	c1 e0 08             	shl    $0x8,%eax
c0100f14:	89 45 f4             	mov    %eax,-0xc(%ebp)
    outb(addr_6845, 15);
c0100f17:	0f b7 05 46 b4 11 c0 	movzwl 0xc011b446,%eax
c0100f1e:	66 89 45 ee          	mov    %ax,-0x12(%ebp)
c0100f22:	c6 45 ed 0f          	movb   $0xf,-0x13(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
c0100f26:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
c0100f2a:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
c0100f2e:	ee                   	out    %al,(%dx)
    pos |= inb(addr_6845 + 1);
c0100f2f:	0f b7 05 46 b4 11 c0 	movzwl 0xc011b446,%eax
c0100f36:	40                   	inc    %eax
c0100f37:	0f b7 c0             	movzwl %ax,%eax
c0100f3a:	66 89 45 f2          	mov    %ax,-0xe(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0100f3e:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
c0100f42:	89 c2                	mov    %eax,%edx
c0100f44:	ec                   	in     (%dx),%al
c0100f45:	88 45 f1             	mov    %al,-0xf(%ebp)
    return data;
c0100f48:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
c0100f4c:	0f b6 c0             	movzbl %al,%eax
c0100f4f:	09 45 f4             	or     %eax,-0xc(%ebp)

    crt_buf = (uint16_t*) cp;
c0100f52:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0100f55:	a3 40 b4 11 c0       	mov    %eax,0xc011b440
    crt_pos = pos;
c0100f5a:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0100f5d:	0f b7 c0             	movzwl %ax,%eax
c0100f60:	66 a3 44 b4 11 c0    	mov    %ax,0xc011b444
}
c0100f66:	90                   	nop
c0100f67:	c9                   	leave  
c0100f68:	c3                   	ret    

c0100f69 <serial_init>:

static bool serial_exists = 0;

static void
serial_init(void) {
c0100f69:	55                   	push   %ebp
c0100f6a:	89 e5                	mov    %esp,%ebp
c0100f6c:	83 ec 48             	sub    $0x48,%esp
c0100f6f:	66 c7 45 d2 fa 03    	movw   $0x3fa,-0x2e(%ebp)
c0100f75:	c6 45 d1 00          	movb   $0x0,-0x2f(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
c0100f79:	0f b6 45 d1          	movzbl -0x2f(%ebp),%eax
c0100f7d:	0f b7 55 d2          	movzwl -0x2e(%ebp),%edx
c0100f81:	ee                   	out    %al,(%dx)
c0100f82:	66 c7 45 d6 fb 03    	movw   $0x3fb,-0x2a(%ebp)
c0100f88:	c6 45 d5 80          	movb   $0x80,-0x2b(%ebp)
c0100f8c:	0f b6 45 d5          	movzbl -0x2b(%ebp),%eax
c0100f90:	0f b7 55 d6          	movzwl -0x2a(%ebp),%edx
c0100f94:	ee                   	out    %al,(%dx)
c0100f95:	66 c7 45 da f8 03    	movw   $0x3f8,-0x26(%ebp)
c0100f9b:	c6 45 d9 0c          	movb   $0xc,-0x27(%ebp)
c0100f9f:	0f b6 45 d9          	movzbl -0x27(%ebp),%eax
c0100fa3:	0f b7 55 da          	movzwl -0x26(%ebp),%edx
c0100fa7:	ee                   	out    %al,(%dx)
c0100fa8:	66 c7 45 de f9 03    	movw   $0x3f9,-0x22(%ebp)
c0100fae:	c6 45 dd 00          	movb   $0x0,-0x23(%ebp)
c0100fb2:	0f b6 45 dd          	movzbl -0x23(%ebp),%eax
c0100fb6:	0f b7 55 de          	movzwl -0x22(%ebp),%edx
c0100fba:	ee                   	out    %al,(%dx)
c0100fbb:	66 c7 45 e2 fb 03    	movw   $0x3fb,-0x1e(%ebp)
c0100fc1:	c6 45 e1 03          	movb   $0x3,-0x1f(%ebp)
c0100fc5:	0f b6 45 e1          	movzbl -0x1f(%ebp),%eax
c0100fc9:	0f b7 55 e2          	movzwl -0x1e(%ebp),%edx
c0100fcd:	ee                   	out    %al,(%dx)
c0100fce:	66 c7 45 e6 fc 03    	movw   $0x3fc,-0x1a(%ebp)
c0100fd4:	c6 45 e5 00          	movb   $0x0,-0x1b(%ebp)
c0100fd8:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
c0100fdc:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
c0100fe0:	ee                   	out    %al,(%dx)
c0100fe1:	66 c7 45 ea f9 03    	movw   $0x3f9,-0x16(%ebp)
c0100fe7:	c6 45 e9 01          	movb   $0x1,-0x17(%ebp)
c0100feb:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
c0100fef:	0f b7 55 ea          	movzwl -0x16(%ebp),%edx
c0100ff3:	ee                   	out    %al,(%dx)
c0100ff4:	66 c7 45 ee fd 03    	movw   $0x3fd,-0x12(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0100ffa:	0f b7 45 ee          	movzwl -0x12(%ebp),%eax
c0100ffe:	89 c2                	mov    %eax,%edx
c0101000:	ec                   	in     (%dx),%al
c0101001:	88 45 ed             	mov    %al,-0x13(%ebp)
    return data;
c0101004:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
    // Enable rcv interrupts
    outb(COM1 + COM_IER, COM_IER_RDI);

    // Clear any preexisting overrun indications and interrupts
    // Serial port doesn't exist if COM_LSR returns 0xFF
    serial_exists = (inb(COM1 + COM_LSR) != 0xFF);
c0101008:	3c ff                	cmp    $0xff,%al
c010100a:	0f 95 c0             	setne  %al
c010100d:	0f b6 c0             	movzbl %al,%eax
c0101010:	a3 48 b4 11 c0       	mov    %eax,0xc011b448
c0101015:	66 c7 45 f2 fa 03    	movw   $0x3fa,-0xe(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c010101b:	0f b7 45 f2          	movzwl -0xe(%ebp),%eax
c010101f:	89 c2                	mov    %eax,%edx
c0101021:	ec                   	in     (%dx),%al
c0101022:	88 45 f1             	mov    %al,-0xf(%ebp)
c0101025:	66 c7 45 f6 f8 03    	movw   $0x3f8,-0xa(%ebp)
c010102b:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
c010102f:	89 c2                	mov    %eax,%edx
c0101031:	ec                   	in     (%dx),%al
c0101032:	88 45 f5             	mov    %al,-0xb(%ebp)
    (void) inb(COM1+COM_IIR);
    (void) inb(COM1+COM_RX);

    if (serial_exists) {
c0101035:	a1 48 b4 11 c0       	mov    0xc011b448,%eax
c010103a:	85 c0                	test   %eax,%eax
c010103c:	74 0c                	je     c010104a <serial_init+0xe1>
        pic_enable(IRQ_COM1);
c010103e:	c7 04 24 04 00 00 00 	movl   $0x4,(%esp)
c0101045:	e8 df 06 00 00       	call   c0101729 <pic_enable>
    }
}
c010104a:	90                   	nop
c010104b:	c9                   	leave  
c010104c:	c3                   	ret    

c010104d <lpt_putc_sub>:

static void
lpt_putc_sub(int c) {
c010104d:	55                   	push   %ebp
c010104e:	89 e5                	mov    %esp,%ebp
c0101050:	83 ec 20             	sub    $0x20,%esp
    int i;
    for (i = 0; !(inb(LPTPORT + 1) & 0x80) && i < 12800; i ++) {
c0101053:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
c010105a:	eb 08                	jmp    c0101064 <lpt_putc_sub+0x17>
        delay();
c010105c:	e8 db fd ff ff       	call   c0100e3c <delay>
    for (i = 0; !(inb(LPTPORT + 1) & 0x80) && i < 12800; i ++) {
c0101061:	ff 45 fc             	incl   -0x4(%ebp)
c0101064:	66 c7 45 fa 79 03    	movw   $0x379,-0x6(%ebp)
c010106a:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
c010106e:	89 c2                	mov    %eax,%edx
c0101070:	ec                   	in     (%dx),%al
c0101071:	88 45 f9             	mov    %al,-0x7(%ebp)
    return data;
c0101074:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
c0101078:	84 c0                	test   %al,%al
c010107a:	78 09                	js     c0101085 <lpt_putc_sub+0x38>
c010107c:	81 7d fc ff 31 00 00 	cmpl   $0x31ff,-0x4(%ebp)
c0101083:	7e d7                	jle    c010105c <lpt_putc_sub+0xf>
    }
    outb(LPTPORT + 0, c);
c0101085:	8b 45 08             	mov    0x8(%ebp),%eax
c0101088:	0f b6 c0             	movzbl %al,%eax
c010108b:	66 c7 45 ee 78 03    	movw   $0x378,-0x12(%ebp)
c0101091:	88 45 ed             	mov    %al,-0x13(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
c0101094:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
c0101098:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
c010109c:	ee                   	out    %al,(%dx)
c010109d:	66 c7 45 f2 7a 03    	movw   $0x37a,-0xe(%ebp)
c01010a3:	c6 45 f1 0d          	movb   $0xd,-0xf(%ebp)
c01010a7:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
c01010ab:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
c01010af:	ee                   	out    %al,(%dx)
c01010b0:	66 c7 45 f6 7a 03    	movw   $0x37a,-0xa(%ebp)
c01010b6:	c6 45 f5 08          	movb   $0x8,-0xb(%ebp)
c01010ba:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
c01010be:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
c01010c2:	ee                   	out    %al,(%dx)
    outb(LPTPORT + 2, 0x08 | 0x04 | 0x01);
    outb(LPTPORT + 2, 0x08);
}
c01010c3:	90                   	nop
c01010c4:	c9                   	leave  
c01010c5:	c3                   	ret    

c01010c6 <lpt_putc>:

/* lpt_putc - copy console output to parallel port */
static void
lpt_putc(int c) {
c01010c6:	55                   	push   %ebp
c01010c7:	89 e5                	mov    %esp,%ebp
c01010c9:	83 ec 04             	sub    $0x4,%esp
    if (c != '\b') {
c01010cc:	83 7d 08 08          	cmpl   $0x8,0x8(%ebp)
c01010d0:	74 0d                	je     c01010df <lpt_putc+0x19>
        lpt_putc_sub(c);
c01010d2:	8b 45 08             	mov    0x8(%ebp),%eax
c01010d5:	89 04 24             	mov    %eax,(%esp)
c01010d8:	e8 70 ff ff ff       	call   c010104d <lpt_putc_sub>
    else {
        lpt_putc_sub('\b');
        lpt_putc_sub(' ');
        lpt_putc_sub('\b');
    }
}
c01010dd:	eb 24                	jmp    c0101103 <lpt_putc+0x3d>
        lpt_putc_sub('\b');
c01010df:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c01010e6:	e8 62 ff ff ff       	call   c010104d <lpt_putc_sub>
        lpt_putc_sub(' ');
c01010eb:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c01010f2:	e8 56 ff ff ff       	call   c010104d <lpt_putc_sub>
        lpt_putc_sub('\b');
c01010f7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c01010fe:	e8 4a ff ff ff       	call   c010104d <lpt_putc_sub>
}
c0101103:	90                   	nop
c0101104:	c9                   	leave  
c0101105:	c3                   	ret    

c0101106 <cga_putc>:

/* cga_putc - print character to console */
static void
cga_putc(int c) {
c0101106:	55                   	push   %ebp
c0101107:	89 e5                	mov    %esp,%ebp
c0101109:	53                   	push   %ebx
c010110a:	83 ec 34             	sub    $0x34,%esp
    // set black on white
    if (!(c & ~0xFF)) {
c010110d:	8b 45 08             	mov    0x8(%ebp),%eax
c0101110:	25 00 ff ff ff       	and    $0xffffff00,%eax
c0101115:	85 c0                	test   %eax,%eax
c0101117:	75 07                	jne    c0101120 <cga_putc+0x1a>
        c |= 0x0700;
c0101119:	81 4d 08 00 07 00 00 	orl    $0x700,0x8(%ebp)
    }

    switch (c & 0xff) {
c0101120:	8b 45 08             	mov    0x8(%ebp),%eax
c0101123:	0f b6 c0             	movzbl %al,%eax
c0101126:	83 f8 0a             	cmp    $0xa,%eax
c0101129:	74 55                	je     c0101180 <cga_putc+0x7a>
c010112b:	83 f8 0d             	cmp    $0xd,%eax
c010112e:	74 63                	je     c0101193 <cga_putc+0x8d>
c0101130:	83 f8 08             	cmp    $0x8,%eax
c0101133:	0f 85 94 00 00 00    	jne    c01011cd <cga_putc+0xc7>
    case '\b':
        if (crt_pos > 0) {
c0101139:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c0101140:	85 c0                	test   %eax,%eax
c0101142:	0f 84 af 00 00 00    	je     c01011f7 <cga_putc+0xf1>
            crt_pos --;
c0101148:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c010114f:	48                   	dec    %eax
c0101150:	0f b7 c0             	movzwl %ax,%eax
c0101153:	66 a3 44 b4 11 c0    	mov    %ax,0xc011b444
            crt_buf[crt_pos] = (c & ~0xff) | ' ';
c0101159:	8b 45 08             	mov    0x8(%ebp),%eax
c010115c:	98                   	cwtl   
c010115d:	25 00 ff ff ff       	and    $0xffffff00,%eax
c0101162:	98                   	cwtl   
c0101163:	83 c8 20             	or     $0x20,%eax
c0101166:	98                   	cwtl   
c0101167:	8b 15 40 b4 11 c0    	mov    0xc011b440,%edx
c010116d:	0f b7 0d 44 b4 11 c0 	movzwl 0xc011b444,%ecx
c0101174:	01 c9                	add    %ecx,%ecx
c0101176:	01 ca                	add    %ecx,%edx
c0101178:	0f b7 c0             	movzwl %ax,%eax
c010117b:	66 89 02             	mov    %ax,(%edx)
        }
        break;
c010117e:	eb 77                	jmp    c01011f7 <cga_putc+0xf1>
    case '\n':
        crt_pos += CRT_COLS;
c0101180:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c0101187:	83 c0 50             	add    $0x50,%eax
c010118a:	0f b7 c0             	movzwl %ax,%eax
c010118d:	66 a3 44 b4 11 c0    	mov    %ax,0xc011b444
    case '\r':
        crt_pos -= (crt_pos % CRT_COLS);
c0101193:	0f b7 1d 44 b4 11 c0 	movzwl 0xc011b444,%ebx
c010119a:	0f b7 0d 44 b4 11 c0 	movzwl 0xc011b444,%ecx
c01011a1:	ba cd cc cc cc       	mov    $0xcccccccd,%edx
c01011a6:	89 c8                	mov    %ecx,%eax
c01011a8:	f7 e2                	mul    %edx
c01011aa:	c1 ea 06             	shr    $0x6,%edx
c01011ad:	89 d0                	mov    %edx,%eax
c01011af:	c1 e0 02             	shl    $0x2,%eax
c01011b2:	01 d0                	add    %edx,%eax
c01011b4:	c1 e0 04             	shl    $0x4,%eax
c01011b7:	29 c1                	sub    %eax,%ecx
c01011b9:	89 c8                	mov    %ecx,%eax
c01011bb:	0f b7 c0             	movzwl %ax,%eax
c01011be:	29 c3                	sub    %eax,%ebx
c01011c0:	89 d8                	mov    %ebx,%eax
c01011c2:	0f b7 c0             	movzwl %ax,%eax
c01011c5:	66 a3 44 b4 11 c0    	mov    %ax,0xc011b444
        break;
c01011cb:	eb 2b                	jmp    c01011f8 <cga_putc+0xf2>
    default:
        crt_buf[crt_pos ++] = c;     // write the character
c01011cd:	8b 0d 40 b4 11 c0    	mov    0xc011b440,%ecx
c01011d3:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c01011da:	8d 50 01             	lea    0x1(%eax),%edx
c01011dd:	0f b7 d2             	movzwl %dx,%edx
c01011e0:	66 89 15 44 b4 11 c0 	mov    %dx,0xc011b444
c01011e7:	01 c0                	add    %eax,%eax
c01011e9:	8d 14 01             	lea    (%ecx,%eax,1),%edx
c01011ec:	8b 45 08             	mov    0x8(%ebp),%eax
c01011ef:	0f b7 c0             	movzwl %ax,%eax
c01011f2:	66 89 02             	mov    %ax,(%edx)
        break;
c01011f5:	eb 01                	jmp    c01011f8 <cga_putc+0xf2>
        break;
c01011f7:	90                   	nop
    }

    // What is the purpose of this?
    if (crt_pos >= CRT_SIZE) {
c01011f8:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c01011ff:	3d cf 07 00 00       	cmp    $0x7cf,%eax
c0101204:	76 5d                	jbe    c0101263 <cga_putc+0x15d>
        int i;
        memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
c0101206:	a1 40 b4 11 c0       	mov    0xc011b440,%eax
c010120b:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
c0101211:	a1 40 b4 11 c0       	mov    0xc011b440,%eax
c0101216:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
c010121d:	00 
c010121e:	89 54 24 04          	mov    %edx,0x4(%esp)
c0101222:	89 04 24             	mov    %eax,(%esp)
c0101225:	e8 9a 47 00 00       	call   c01059c4 <memmove>
        for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i ++) {
c010122a:	c7 45 f4 80 07 00 00 	movl   $0x780,-0xc(%ebp)
c0101231:	eb 14                	jmp    c0101247 <cga_putc+0x141>
            crt_buf[i] = 0x0700 | ' ';
c0101233:	a1 40 b4 11 c0       	mov    0xc011b440,%eax
c0101238:	8b 55 f4             	mov    -0xc(%ebp),%edx
c010123b:	01 d2                	add    %edx,%edx
c010123d:	01 d0                	add    %edx,%eax
c010123f:	66 c7 00 20 07       	movw   $0x720,(%eax)
        for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i ++) {
c0101244:	ff 45 f4             	incl   -0xc(%ebp)
c0101247:	81 7d f4 cf 07 00 00 	cmpl   $0x7cf,-0xc(%ebp)
c010124e:	7e e3                	jle    c0101233 <cga_putc+0x12d>
        }
        crt_pos -= CRT_COLS;
c0101250:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c0101257:	83 e8 50             	sub    $0x50,%eax
c010125a:	0f b7 c0             	movzwl %ax,%eax
c010125d:	66 a3 44 b4 11 c0    	mov    %ax,0xc011b444
    }

    // move that little blinky thing
    outb(addr_6845, 14);
c0101263:	0f b7 05 46 b4 11 c0 	movzwl 0xc011b446,%eax
c010126a:	66 89 45 e6          	mov    %ax,-0x1a(%ebp)
c010126e:	c6 45 e5 0e          	movb   $0xe,-0x1b(%ebp)
c0101272:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
c0101276:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
c010127a:	ee                   	out    %al,(%dx)
    outb(addr_6845 + 1, crt_pos >> 8);
c010127b:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c0101282:	c1 e8 08             	shr    $0x8,%eax
c0101285:	0f b7 c0             	movzwl %ax,%eax
c0101288:	0f b6 c0             	movzbl %al,%eax
c010128b:	0f b7 15 46 b4 11 c0 	movzwl 0xc011b446,%edx
c0101292:	42                   	inc    %edx
c0101293:	0f b7 d2             	movzwl %dx,%edx
c0101296:	66 89 55 ea          	mov    %dx,-0x16(%ebp)
c010129a:	88 45 e9             	mov    %al,-0x17(%ebp)
c010129d:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
c01012a1:	0f b7 55 ea          	movzwl -0x16(%ebp),%edx
c01012a5:	ee                   	out    %al,(%dx)
    outb(addr_6845, 15);
c01012a6:	0f b7 05 46 b4 11 c0 	movzwl 0xc011b446,%eax
c01012ad:	66 89 45 ee          	mov    %ax,-0x12(%ebp)
c01012b1:	c6 45 ed 0f          	movb   $0xf,-0x13(%ebp)
c01012b5:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
c01012b9:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
c01012bd:	ee                   	out    %al,(%dx)
    outb(addr_6845 + 1, crt_pos);
c01012be:	0f b7 05 44 b4 11 c0 	movzwl 0xc011b444,%eax
c01012c5:	0f b6 c0             	movzbl %al,%eax
c01012c8:	0f b7 15 46 b4 11 c0 	movzwl 0xc011b446,%edx
c01012cf:	42                   	inc    %edx
c01012d0:	0f b7 d2             	movzwl %dx,%edx
c01012d3:	66 89 55 f2          	mov    %dx,-0xe(%ebp)
c01012d7:	88 45 f1             	mov    %al,-0xf(%ebp)
c01012da:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
c01012de:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
c01012e2:	ee                   	out    %al,(%dx)
}
c01012e3:	90                   	nop
c01012e4:	83 c4 34             	add    $0x34,%esp
c01012e7:	5b                   	pop    %ebx
c01012e8:	5d                   	pop    %ebp
c01012e9:	c3                   	ret    

c01012ea <serial_putc_sub>:

static void
serial_putc_sub(int c) {
c01012ea:	55                   	push   %ebp
c01012eb:	89 e5                	mov    %esp,%ebp
c01012ed:	83 ec 10             	sub    $0x10,%esp
    int i;
    for (i = 0; !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800; i ++) {
c01012f0:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
c01012f7:	eb 08                	jmp    c0101301 <serial_putc_sub+0x17>
        delay();
c01012f9:	e8 3e fb ff ff       	call   c0100e3c <delay>
    for (i = 0; !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800; i ++) {
c01012fe:	ff 45 fc             	incl   -0x4(%ebp)
c0101301:	66 c7 45 fa fd 03    	movw   $0x3fd,-0x6(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0101307:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
c010130b:	89 c2                	mov    %eax,%edx
c010130d:	ec                   	in     (%dx),%al
c010130e:	88 45 f9             	mov    %al,-0x7(%ebp)
    return data;
c0101311:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
c0101315:	0f b6 c0             	movzbl %al,%eax
c0101318:	83 e0 20             	and    $0x20,%eax
c010131b:	85 c0                	test   %eax,%eax
c010131d:	75 09                	jne    c0101328 <serial_putc_sub+0x3e>
c010131f:	81 7d fc ff 31 00 00 	cmpl   $0x31ff,-0x4(%ebp)
c0101326:	7e d1                	jle    c01012f9 <serial_putc_sub+0xf>
    }
    outb(COM1 + COM_TX, c);
c0101328:	8b 45 08             	mov    0x8(%ebp),%eax
c010132b:	0f b6 c0             	movzbl %al,%eax
c010132e:	66 c7 45 f6 f8 03    	movw   $0x3f8,-0xa(%ebp)
c0101334:	88 45 f5             	mov    %al,-0xb(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
c0101337:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
c010133b:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
c010133f:	ee                   	out    %al,(%dx)
}
c0101340:	90                   	nop
c0101341:	c9                   	leave  
c0101342:	c3                   	ret    

c0101343 <serial_putc>:

/* serial_putc - print character to serial port */
static void
serial_putc(int c) {
c0101343:	55                   	push   %ebp
c0101344:	89 e5                	mov    %esp,%ebp
c0101346:	83 ec 04             	sub    $0x4,%esp
    if (c != '\b') {
c0101349:	83 7d 08 08          	cmpl   $0x8,0x8(%ebp)
c010134d:	74 0d                	je     c010135c <serial_putc+0x19>
        serial_putc_sub(c);
c010134f:	8b 45 08             	mov    0x8(%ebp),%eax
c0101352:	89 04 24             	mov    %eax,(%esp)
c0101355:	e8 90 ff ff ff       	call   c01012ea <serial_putc_sub>
    else {
        serial_putc_sub('\b');
        serial_putc_sub(' ');
        serial_putc_sub('\b');
    }
}
c010135a:	eb 24                	jmp    c0101380 <serial_putc+0x3d>
        serial_putc_sub('\b');
c010135c:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c0101363:	e8 82 ff ff ff       	call   c01012ea <serial_putc_sub>
        serial_putc_sub(' ');
c0101368:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c010136f:	e8 76 ff ff ff       	call   c01012ea <serial_putc_sub>
        serial_putc_sub('\b');
c0101374:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
c010137b:	e8 6a ff ff ff       	call   c01012ea <serial_putc_sub>
}
c0101380:	90                   	nop
c0101381:	c9                   	leave  
c0101382:	c3                   	ret    

c0101383 <cons_intr>:
/* *
 * cons_intr - called by device interrupt routines to feed input
 * characters into the circular console input buffer.
 * */
static void
cons_intr(int (*proc)(void)) {
c0101383:	55                   	push   %ebp
c0101384:	89 e5                	mov    %esp,%ebp
c0101386:	83 ec 18             	sub    $0x18,%esp
    int c;
    while ((c = (*proc)()) != -1) {
c0101389:	eb 33                	jmp    c01013be <cons_intr+0x3b>
        if (c != 0) {
c010138b:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c010138f:	74 2d                	je     c01013be <cons_intr+0x3b>
            cons.buf[cons.wpos ++] = c;
c0101391:	a1 64 b6 11 c0       	mov    0xc011b664,%eax
c0101396:	8d 50 01             	lea    0x1(%eax),%edx
c0101399:	89 15 64 b6 11 c0    	mov    %edx,0xc011b664
c010139f:	8b 55 f4             	mov    -0xc(%ebp),%edx
c01013a2:	88 90 60 b4 11 c0    	mov    %dl,-0x3fee4ba0(%eax)
            if (cons.wpos == CONSBUFSIZE) {
c01013a8:	a1 64 b6 11 c0       	mov    0xc011b664,%eax
c01013ad:	3d 00 02 00 00       	cmp    $0x200,%eax
c01013b2:	75 0a                	jne    c01013be <cons_intr+0x3b>
                cons.wpos = 0;
c01013b4:	c7 05 64 b6 11 c0 00 	movl   $0x0,0xc011b664
c01013bb:	00 00 00 
    while ((c = (*proc)()) != -1) {
c01013be:	8b 45 08             	mov    0x8(%ebp),%eax
c01013c1:	ff d0                	call   *%eax
c01013c3:	89 45 f4             	mov    %eax,-0xc(%ebp)
c01013c6:	83 7d f4 ff          	cmpl   $0xffffffff,-0xc(%ebp)
c01013ca:	75 bf                	jne    c010138b <cons_intr+0x8>
            }
        }
    }
}
c01013cc:	90                   	nop
c01013cd:	c9                   	leave  
c01013ce:	c3                   	ret    

c01013cf <serial_proc_data>:

/* serial_proc_data - get data from serial port */
static int
serial_proc_data(void) {
c01013cf:	55                   	push   %ebp
c01013d0:	89 e5                	mov    %esp,%ebp
c01013d2:	83 ec 10             	sub    $0x10,%esp
c01013d5:	66 c7 45 fa fd 03    	movw   $0x3fd,-0x6(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c01013db:	0f b7 45 fa          	movzwl -0x6(%ebp),%eax
c01013df:	89 c2                	mov    %eax,%edx
c01013e1:	ec                   	in     (%dx),%al
c01013e2:	88 45 f9             	mov    %al,-0x7(%ebp)
    return data;
c01013e5:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
    if (!(inb(COM1 + COM_LSR) & COM_LSR_DATA)) {
c01013e9:	0f b6 c0             	movzbl %al,%eax
c01013ec:	83 e0 01             	and    $0x1,%eax
c01013ef:	85 c0                	test   %eax,%eax
c01013f1:	75 07                	jne    c01013fa <serial_proc_data+0x2b>
        return -1;
c01013f3:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c01013f8:	eb 2a                	jmp    c0101424 <serial_proc_data+0x55>
c01013fa:	66 c7 45 f6 f8 03    	movw   $0x3f8,-0xa(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0101400:	0f b7 45 f6          	movzwl -0xa(%ebp),%eax
c0101404:	89 c2                	mov    %eax,%edx
c0101406:	ec                   	in     (%dx),%al
c0101407:	88 45 f5             	mov    %al,-0xb(%ebp)
    return data;
c010140a:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
    }
    int c = inb(COM1 + COM_RX);
c010140e:	0f b6 c0             	movzbl %al,%eax
c0101411:	89 45 fc             	mov    %eax,-0x4(%ebp)
    if (c == 127) {
c0101414:	83 7d fc 7f          	cmpl   $0x7f,-0x4(%ebp)
c0101418:	75 07                	jne    c0101421 <serial_proc_data+0x52>
        c = '\b';
c010141a:	c7 45 fc 08 00 00 00 	movl   $0x8,-0x4(%ebp)
    }
    return c;
c0101421:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
c0101424:	c9                   	leave  
c0101425:	c3                   	ret    

c0101426 <serial_intr>:

/* serial_intr - try to feed input characters from serial port */
void
serial_intr(void) {
c0101426:	55                   	push   %ebp
c0101427:	89 e5                	mov    %esp,%ebp
c0101429:	83 ec 18             	sub    $0x18,%esp
    if (serial_exists) {
c010142c:	a1 48 b4 11 c0       	mov    0xc011b448,%eax
c0101431:	85 c0                	test   %eax,%eax
c0101433:	74 0c                	je     c0101441 <serial_intr+0x1b>
        cons_intr(serial_proc_data);
c0101435:	c7 04 24 cf 13 10 c0 	movl   $0xc01013cf,(%esp)
c010143c:	e8 42 ff ff ff       	call   c0101383 <cons_intr>
    }
}
c0101441:	90                   	nop
c0101442:	c9                   	leave  
c0101443:	c3                   	ret    

c0101444 <kbd_proc_data>:
 *
 * The kbd_proc_data() function gets data from the keyboard.
 * If we finish a character, return it, else 0. And return -1 if no data.
 * */
static int
kbd_proc_data(void) {
c0101444:	55                   	push   %ebp
c0101445:	89 e5                	mov    %esp,%ebp
c0101447:	83 ec 38             	sub    $0x38,%esp
c010144a:	66 c7 45 f0 64 00    	movw   $0x64,-0x10(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0101450:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0101453:	89 c2                	mov    %eax,%edx
c0101455:	ec                   	in     (%dx),%al
c0101456:	88 45 ef             	mov    %al,-0x11(%ebp)
    return data;
c0101459:	0f b6 45 ef          	movzbl -0x11(%ebp),%eax
    int c;
    uint8_t data;
    static uint32_t shift;

    if ((inb(KBSTATP) & KBS_DIB) == 0) {
c010145d:	0f b6 c0             	movzbl %al,%eax
c0101460:	83 e0 01             	and    $0x1,%eax
c0101463:	85 c0                	test   %eax,%eax
c0101465:	75 0a                	jne    c0101471 <kbd_proc_data+0x2d>
        return -1;
c0101467:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
c010146c:	e9 55 01 00 00       	jmp    c01015c6 <kbd_proc_data+0x182>
c0101471:	66 c7 45 ec 60 00    	movw   $0x60,-0x14(%ebp)
    asm volatile ("inb %1, %0" : "=a" (data) : "d" (port) : "memory");
c0101477:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010147a:	89 c2                	mov    %eax,%edx
c010147c:	ec                   	in     (%dx),%al
c010147d:	88 45 eb             	mov    %al,-0x15(%ebp)
    return data;
c0101480:	0f b6 45 eb          	movzbl -0x15(%ebp),%eax
    }

    data = inb(KBDATAP);
c0101484:	88 45 f3             	mov    %al,-0xd(%ebp)

    if (data == 0xE0) {
c0101487:	80 7d f3 e0          	cmpb   $0xe0,-0xd(%ebp)
c010148b:	75 17                	jne    c01014a4 <kbd_proc_data+0x60>
        // E0 escape character
        shift |= E0ESC;
c010148d:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c0101492:	83 c8 40             	or     $0x40,%eax
c0101495:	a3 68 b6 11 c0       	mov    %eax,0xc011b668
        return 0;
c010149a:	b8 00 00 00 00       	mov    $0x0,%eax
c010149f:	e9 22 01 00 00       	jmp    c01015c6 <kbd_proc_data+0x182>
    } else if (data & 0x80) {
c01014a4:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
c01014a8:	84 c0                	test   %al,%al
c01014aa:	79 45                	jns    c01014f1 <kbd_proc_data+0xad>
        // Key released
        data = (shift & E0ESC ? data : data & 0x7F);
c01014ac:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c01014b1:	83 e0 40             	and    $0x40,%eax
c01014b4:	85 c0                	test   %eax,%eax
c01014b6:	75 08                	jne    c01014c0 <kbd_proc_data+0x7c>
c01014b8:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
c01014bc:	24 7f                	and    $0x7f,%al
c01014be:	eb 04                	jmp    c01014c4 <kbd_proc_data+0x80>
c01014c0:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
c01014c4:	88 45 f3             	mov    %al,-0xd(%ebp)
        shift &= ~(shiftcode[data] | E0ESC);
c01014c7:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
c01014cb:	0f b6 80 40 80 11 c0 	movzbl -0x3fee7fc0(%eax),%eax
c01014d2:	0c 40                	or     $0x40,%al
c01014d4:	0f b6 c0             	movzbl %al,%eax
c01014d7:	f7 d0                	not    %eax
c01014d9:	89 c2                	mov    %eax,%edx
c01014db:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c01014e0:	21 d0                	and    %edx,%eax
c01014e2:	a3 68 b6 11 c0       	mov    %eax,0xc011b668
        return 0;
c01014e7:	b8 00 00 00 00       	mov    $0x0,%eax
c01014ec:	e9 d5 00 00 00       	jmp    c01015c6 <kbd_proc_data+0x182>
    } else if (shift & E0ESC) {
c01014f1:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c01014f6:	83 e0 40             	and    $0x40,%eax
c01014f9:	85 c0                	test   %eax,%eax
c01014fb:	74 11                	je     c010150e <kbd_proc_data+0xca>
        // Last character was an E0 escape; or with 0x80
        data |= 0x80;
c01014fd:	80 4d f3 80          	orb    $0x80,-0xd(%ebp)
        shift &= ~E0ESC;
c0101501:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c0101506:	83 e0 bf             	and    $0xffffffbf,%eax
c0101509:	a3 68 b6 11 c0       	mov    %eax,0xc011b668
    }

    shift |= shiftcode[data];
c010150e:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
c0101512:	0f b6 80 40 80 11 c0 	movzbl -0x3fee7fc0(%eax),%eax
c0101519:	0f b6 d0             	movzbl %al,%edx
c010151c:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c0101521:	09 d0                	or     %edx,%eax
c0101523:	a3 68 b6 11 c0       	mov    %eax,0xc011b668
    shift ^= togglecode[data];
c0101528:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
c010152c:	0f b6 80 40 81 11 c0 	movzbl -0x3fee7ec0(%eax),%eax
c0101533:	0f b6 d0             	movzbl %al,%edx
c0101536:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c010153b:	31 d0                	xor    %edx,%eax
c010153d:	a3 68 b6 11 c0       	mov    %eax,0xc011b668

    c = charcode[shift & (CTL | SHIFT)][data];
c0101542:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c0101547:	83 e0 03             	and    $0x3,%eax
c010154a:	8b 14 85 40 85 11 c0 	mov    -0x3fee7ac0(,%eax,4),%edx
c0101551:	0f b6 45 f3          	movzbl -0xd(%ebp),%eax
c0101555:	01 d0                	add    %edx,%eax
c0101557:	0f b6 00             	movzbl (%eax),%eax
c010155a:	0f b6 c0             	movzbl %al,%eax
c010155d:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (shift & CAPSLOCK) {
c0101560:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c0101565:	83 e0 08             	and    $0x8,%eax
c0101568:	85 c0                	test   %eax,%eax
c010156a:	74 22                	je     c010158e <kbd_proc_data+0x14a>
        if ('a' <= c && c <= 'z')
c010156c:	83 7d f4 60          	cmpl   $0x60,-0xc(%ebp)
c0101570:	7e 0c                	jle    c010157e <kbd_proc_data+0x13a>
c0101572:	83 7d f4 7a          	cmpl   $0x7a,-0xc(%ebp)
c0101576:	7f 06                	jg     c010157e <kbd_proc_data+0x13a>
            c += 'A' - 'a';
c0101578:	83 6d f4 20          	subl   $0x20,-0xc(%ebp)
c010157c:	eb 10                	jmp    c010158e <kbd_proc_data+0x14a>
        else if ('A' <= c && c <= 'Z')
c010157e:	83 7d f4 40          	cmpl   $0x40,-0xc(%ebp)
c0101582:	7e 0a                	jle    c010158e <kbd_proc_data+0x14a>
c0101584:	83 7d f4 5a          	cmpl   $0x5a,-0xc(%ebp)
c0101588:	7f 04                	jg     c010158e <kbd_proc_data+0x14a>
            c += 'a' - 'A';
c010158a:	83 45 f4 20          	addl   $0x20,-0xc(%ebp)
    }

    // Process special keys
    // Ctrl-Alt-Del: reboot
    if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
c010158e:	a1 68 b6 11 c0       	mov    0xc011b668,%eax
c0101593:	f7 d0                	not    %eax
c0101595:	83 e0 06             	and    $0x6,%eax
c0101598:	85 c0                	test   %eax,%eax
c010159a:	75 27                	jne    c01015c3 <kbd_proc_data+0x17f>
c010159c:	81 7d f4 e9 00 00 00 	cmpl   $0xe9,-0xc(%ebp)
c01015a3:	75 1e                	jne    c01015c3 <kbd_proc_data+0x17f>
        cprintf("Rebooting!\n");
c01015a5:	c7 04 24 ad 64 10 c0 	movl   $0xc01064ad,(%esp)
c01015ac:	e8 f1 ec ff ff       	call   c01002a2 <cprintf>
c01015b1:	66 c7 45 e8 92 00    	movw   $0x92,-0x18(%ebp)
c01015b7:	c6 45 e7 03          	movb   $0x3,-0x19(%ebp)
    asm volatile ("outb %0, %1" :: "a" (data), "d" (port) : "memory");
c01015bb:	0f b6 45 e7          	movzbl -0x19(%ebp),%eax
c01015bf:	8b 55 e8             	mov    -0x18(%ebp),%edx
c01015c2:	ee                   	out    %al,(%dx)
        outb(0x92, 0x3); // courtesy of Chris Frost
    }
    return c;
c01015c3:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c01015c6:	c9                   	leave  
c01015c7:	c3                   	ret    

c01015c8 <kbd_intr>:

/* kbd_intr - try to feed input characters from keyboard */
static void
kbd_intr(void) {
c01015c8:	55                   	push   %ebp
c01015c9:	89 e5                	mov    %esp,%ebp
c01015cb:	83 ec 18             	sub    $0x18,%esp
    cons_intr(kbd_proc_data);
c01015ce:	c7 04 24 44 14 10 c0 	movl   $0xc0101444,(%esp)
c01015d5:	e8 a9 fd ff ff       	call   c0101383 <cons_intr>
}
c01015da:	90                   	nop
c01015db:	c9                   	leave  
c01015dc:	c3                   	ret    

c01015dd <kbd_init>:

static void
kbd_init(void) {
c01015dd:	55                   	push   %ebp
c01015de:	89 e5                	mov    %esp,%ebp
c01015e0:	83 ec 18             	sub    $0x18,%esp
    // drain the kbd buffer
    kbd_intr();
c01015e3:	e8 e0 ff ff ff       	call   c01015c8 <kbd_intr>
    pic_enable(IRQ_KBD);
c01015e8:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c01015ef:	e8 35 01 00 00       	call   c0101729 <pic_enable>
}
c01015f4:	90                   	nop
c01015f5:	c9                   	leave  
c01015f6:	c3                   	ret    

c01015f7 <cons_init>:

/* cons_init - initializes the console devices */
void
cons_init(void) {
c01015f7:	55                   	push   %ebp
c01015f8:	89 e5                	mov    %esp,%ebp
c01015fa:	83 ec 18             	sub    $0x18,%esp
    cga_init();
c01015fd:	e8 83 f8 ff ff       	call   c0100e85 <cga_init>
    serial_init();
c0101602:	e8 62 f9 ff ff       	call   c0100f69 <serial_init>
    kbd_init();
c0101607:	e8 d1 ff ff ff       	call   c01015dd <kbd_init>
    if (!serial_exists) {
c010160c:	a1 48 b4 11 c0       	mov    0xc011b448,%eax
c0101611:	85 c0                	test   %eax,%eax
c0101613:	75 0c                	jne    c0101621 <cons_init+0x2a>
        cprintf("serial port does not exist!!\n");
c0101615:	c7 04 24 b9 64 10 c0 	movl   $0xc01064b9,(%esp)
c010161c:	e8 81 ec ff ff       	call   c01002a2 <cprintf>
    }
}
c0101621:	90                   	nop
c0101622:	c9                   	leave  
c0101623:	c3                   	ret    

c0101624 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void
cons_putc(int c) {
c0101624:	55                   	push   %ebp
c0101625:	89 e5                	mov    %esp,%ebp
c0101627:	83 ec 28             	sub    $0x28,%esp
    bool intr_flag;
    local_intr_save(intr_flag);
c010162a:	e8 cf f7 ff ff       	call   c0100dfe <__intr_save>
c010162f:	89 45 f4             	mov    %eax,-0xc(%ebp)
    {
        lpt_putc(c);
c0101632:	8b 45 08             	mov    0x8(%ebp),%eax
c0101635:	89 04 24             	mov    %eax,(%esp)
c0101638:	e8 89 fa ff ff       	call   c01010c6 <lpt_putc>
        cga_putc(c);
c010163d:	8b 45 08             	mov    0x8(%ebp),%eax
c0101640:	89 04 24             	mov    %eax,(%esp)
c0101643:	e8 be fa ff ff       	call   c0101106 <cga_putc>
        serial_putc(c);
c0101648:	8b 45 08             	mov    0x8(%ebp),%eax
c010164b:	89 04 24             	mov    %eax,(%esp)
c010164e:	e8 f0 fc ff ff       	call   c0101343 <serial_putc>
    }
    local_intr_restore(intr_flag);
c0101653:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0101656:	89 04 24             	mov    %eax,(%esp)
c0101659:	e8 ca f7 ff ff       	call   c0100e28 <__intr_restore>
}
c010165e:	90                   	nop
c010165f:	c9                   	leave  
c0101660:	c3                   	ret    

c0101661 <cons_getc>:
/* *
 * cons_getc - return the next input character from console,
 * or 0 if none waiting.
 * */
int
cons_getc(void) {
c0101661:	55                   	push   %ebp
c0101662:	89 e5                	mov    %esp,%ebp
c0101664:	83 ec 28             	sub    $0x28,%esp
    int c = 0;
c0101667:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    bool intr_flag;
    local_intr_save(intr_flag);
c010166e:	e8 8b f7 ff ff       	call   c0100dfe <__intr_save>
c0101673:	89 45 f0             	mov    %eax,-0x10(%ebp)
    {
        // poll for any pending input characters,
        // so that this function works even when interrupts are disabled
        // (e.g., when called from the kernel monitor).
        serial_intr();
c0101676:	e8 ab fd ff ff       	call   c0101426 <serial_intr>
        kbd_intr();
c010167b:	e8 48 ff ff ff       	call   c01015c8 <kbd_intr>

        // grab the next character from the input buffer.
        if (cons.rpos != cons.wpos) {
c0101680:	8b 15 60 b6 11 c0    	mov    0xc011b660,%edx
c0101686:	a1 64 b6 11 c0       	mov    0xc011b664,%eax
c010168b:	39 c2                	cmp    %eax,%edx
c010168d:	74 31                	je     c01016c0 <cons_getc+0x5f>
            c = cons.buf[cons.rpos ++];
c010168f:	a1 60 b6 11 c0       	mov    0xc011b660,%eax
c0101694:	8d 50 01             	lea    0x1(%eax),%edx
c0101697:	89 15 60 b6 11 c0    	mov    %edx,0xc011b660
c010169d:	0f b6 80 60 b4 11 c0 	movzbl -0x3fee4ba0(%eax),%eax
c01016a4:	0f b6 c0             	movzbl %al,%eax
c01016a7:	89 45 f4             	mov    %eax,-0xc(%ebp)
            if (cons.rpos == CONSBUFSIZE) {
c01016aa:	a1 60 b6 11 c0       	mov    0xc011b660,%eax
c01016af:	3d 00 02 00 00       	cmp    $0x200,%eax
c01016b4:	75 0a                	jne    c01016c0 <cons_getc+0x5f>
                cons.rpos = 0;
c01016b6:	c7 05 60 b6 11 c0 00 	movl   $0x0,0xc011b660
c01016bd:	00 00 00 
            }
        }
    }
    local_intr_restore(intr_flag);
c01016c0:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01016c3:	89 04 24             	mov    %eax,(%esp)
c01016c6:	e8 5d f7 ff ff       	call   c0100e28 <__intr_restore>
    return c;
c01016cb:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c01016ce:	c9                   	leave  
c01016cf:	c3                   	ret    

c01016d0 <pic_setmask>:
// Initial IRQ mask has interrupt 2 enabled (for slave 8259A).
static uint16_t irq_mask = 0xFFFF & ~(1 << IRQ_SLAVE);
static bool did_init = 0;

static void
pic_setmask(uint16_t mask) {
c01016d0:	55                   	push   %ebp
c01016d1:	89 e5                	mov    %esp,%ebp
c01016d3:	83 ec 14             	sub    $0x14,%esp
c01016d6:	8b 45 08             	mov    0x8(%ebp),%eax
c01016d9:	66 89 45 ec          	mov    %ax,-0x14(%ebp)
    irq_mask = mask;
c01016dd:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01016e0:	66 a3 50 85 11 c0    	mov    %ax,0xc0118550
    if (did_init) {
c01016e6:	a1 6c b6 11 c0       	mov    0xc011b66c,%eax
c01016eb:	85 c0                	test   %eax,%eax
c01016ed:	74 37                	je     c0101726 <pic_setmask+0x56>
        outb(IO_PIC1 + 1, mask);
c01016ef:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01016f2:	0f b6 c0             	movzbl %al,%eax
c01016f5:	66 c7 45 fa 21 00    	movw   $0x21,-0x6(%ebp)
c01016fb:	88 45 f9             	mov    %al,-0x7(%ebp)
c01016fe:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
c0101702:	0f b7 55 fa          	movzwl -0x6(%ebp),%edx
c0101706:	ee                   	out    %al,(%dx)
        outb(IO_PIC2 + 1, mask >> 8);
c0101707:	0f b7 45 ec          	movzwl -0x14(%ebp),%eax
c010170b:	c1 e8 08             	shr    $0x8,%eax
c010170e:	0f b7 c0             	movzwl %ax,%eax
c0101711:	0f b6 c0             	movzbl %al,%eax
c0101714:	66 c7 45 fe a1 00    	movw   $0xa1,-0x2(%ebp)
c010171a:	88 45 fd             	mov    %al,-0x3(%ebp)
c010171d:	0f b6 45 fd          	movzbl -0x3(%ebp),%eax
c0101721:	0f b7 55 fe          	movzwl -0x2(%ebp),%edx
c0101725:	ee                   	out    %al,(%dx)
    }
}
c0101726:	90                   	nop
c0101727:	c9                   	leave  
c0101728:	c3                   	ret    

c0101729 <pic_enable>:

void
pic_enable(unsigned int irq) {
c0101729:	55                   	push   %ebp
c010172a:	89 e5                	mov    %esp,%ebp
c010172c:	83 ec 04             	sub    $0x4,%esp
    pic_setmask(irq_mask & ~(1 << irq));
c010172f:	8b 45 08             	mov    0x8(%ebp),%eax
c0101732:	ba 01 00 00 00       	mov    $0x1,%edx
c0101737:	88 c1                	mov    %al,%cl
c0101739:	d3 e2                	shl    %cl,%edx
c010173b:	89 d0                	mov    %edx,%eax
c010173d:	98                   	cwtl   
c010173e:	f7 d0                	not    %eax
c0101740:	0f bf d0             	movswl %ax,%edx
c0101743:	0f b7 05 50 85 11 c0 	movzwl 0xc0118550,%eax
c010174a:	98                   	cwtl   
c010174b:	21 d0                	and    %edx,%eax
c010174d:	98                   	cwtl   
c010174e:	0f b7 c0             	movzwl %ax,%eax
c0101751:	89 04 24             	mov    %eax,(%esp)
c0101754:	e8 77 ff ff ff       	call   c01016d0 <pic_setmask>
}
c0101759:	90                   	nop
c010175a:	c9                   	leave  
c010175b:	c3                   	ret    

c010175c <pic_init>:

/* pic_init - initialize the 8259A interrupt controllers */
void
pic_init(void) {
c010175c:	55                   	push   %ebp
c010175d:	89 e5                	mov    %esp,%ebp
c010175f:	83 ec 44             	sub    $0x44,%esp
    did_init = 1;
c0101762:	c7 05 6c b6 11 c0 01 	movl   $0x1,0xc011b66c
c0101769:	00 00 00 
c010176c:	66 c7 45 ca 21 00    	movw   $0x21,-0x36(%ebp)
c0101772:	c6 45 c9 ff          	movb   $0xff,-0x37(%ebp)
c0101776:	0f b6 45 c9          	movzbl -0x37(%ebp),%eax
c010177a:	0f b7 55 ca          	movzwl -0x36(%ebp),%edx
c010177e:	ee                   	out    %al,(%dx)
c010177f:	66 c7 45 ce a1 00    	movw   $0xa1,-0x32(%ebp)
c0101785:	c6 45 cd ff          	movb   $0xff,-0x33(%ebp)
c0101789:	0f b6 45 cd          	movzbl -0x33(%ebp),%eax
c010178d:	0f b7 55 ce          	movzwl -0x32(%ebp),%edx
c0101791:	ee                   	out    %al,(%dx)
c0101792:	66 c7 45 d2 20 00    	movw   $0x20,-0x2e(%ebp)
c0101798:	c6 45 d1 11          	movb   $0x11,-0x2f(%ebp)
c010179c:	0f b6 45 d1          	movzbl -0x2f(%ebp),%eax
c01017a0:	0f b7 55 d2          	movzwl -0x2e(%ebp),%edx
c01017a4:	ee                   	out    %al,(%dx)
c01017a5:	66 c7 45 d6 21 00    	movw   $0x21,-0x2a(%ebp)
c01017ab:	c6 45 d5 20          	movb   $0x20,-0x2b(%ebp)
c01017af:	0f b6 45 d5          	movzbl -0x2b(%ebp),%eax
c01017b3:	0f b7 55 d6          	movzwl -0x2a(%ebp),%edx
c01017b7:	ee                   	out    %al,(%dx)
c01017b8:	66 c7 45 da 21 00    	movw   $0x21,-0x26(%ebp)
c01017be:	c6 45 d9 04          	movb   $0x4,-0x27(%ebp)
c01017c2:	0f b6 45 d9          	movzbl -0x27(%ebp),%eax
c01017c6:	0f b7 55 da          	movzwl -0x26(%ebp),%edx
c01017ca:	ee                   	out    %al,(%dx)
c01017cb:	66 c7 45 de 21 00    	movw   $0x21,-0x22(%ebp)
c01017d1:	c6 45 dd 03          	movb   $0x3,-0x23(%ebp)
c01017d5:	0f b6 45 dd          	movzbl -0x23(%ebp),%eax
c01017d9:	0f b7 55 de          	movzwl -0x22(%ebp),%edx
c01017dd:	ee                   	out    %al,(%dx)
c01017de:	66 c7 45 e2 a0 00    	movw   $0xa0,-0x1e(%ebp)
c01017e4:	c6 45 e1 11          	movb   $0x11,-0x1f(%ebp)
c01017e8:	0f b6 45 e1          	movzbl -0x1f(%ebp),%eax
c01017ec:	0f b7 55 e2          	movzwl -0x1e(%ebp),%edx
c01017f0:	ee                   	out    %al,(%dx)
c01017f1:	66 c7 45 e6 a1 00    	movw   $0xa1,-0x1a(%ebp)
c01017f7:	c6 45 e5 28          	movb   $0x28,-0x1b(%ebp)
c01017fb:	0f b6 45 e5          	movzbl -0x1b(%ebp),%eax
c01017ff:	0f b7 55 e6          	movzwl -0x1a(%ebp),%edx
c0101803:	ee                   	out    %al,(%dx)
c0101804:	66 c7 45 ea a1 00    	movw   $0xa1,-0x16(%ebp)
c010180a:	c6 45 e9 02          	movb   $0x2,-0x17(%ebp)
c010180e:	0f b6 45 e9          	movzbl -0x17(%ebp),%eax
c0101812:	0f b7 55 ea          	movzwl -0x16(%ebp),%edx
c0101816:	ee                   	out    %al,(%dx)
c0101817:	66 c7 45 ee a1 00    	movw   $0xa1,-0x12(%ebp)
c010181d:	c6 45 ed 03          	movb   $0x3,-0x13(%ebp)
c0101821:	0f b6 45 ed          	movzbl -0x13(%ebp),%eax
c0101825:	0f b7 55 ee          	movzwl -0x12(%ebp),%edx
c0101829:	ee                   	out    %al,(%dx)
c010182a:	66 c7 45 f2 20 00    	movw   $0x20,-0xe(%ebp)
c0101830:	c6 45 f1 68          	movb   $0x68,-0xf(%ebp)
c0101834:	0f b6 45 f1          	movzbl -0xf(%ebp),%eax
c0101838:	0f b7 55 f2          	movzwl -0xe(%ebp),%edx
c010183c:	ee                   	out    %al,(%dx)
c010183d:	66 c7 45 f6 20 00    	movw   $0x20,-0xa(%ebp)
c0101843:	c6 45 f5 0a          	movb   $0xa,-0xb(%ebp)
c0101847:	0f b6 45 f5          	movzbl -0xb(%ebp),%eax
c010184b:	0f b7 55 f6          	movzwl -0xa(%ebp),%edx
c010184f:	ee                   	out    %al,(%dx)
c0101850:	66 c7 45 fa a0 00    	movw   $0xa0,-0x6(%ebp)
c0101856:	c6 45 f9 68          	movb   $0x68,-0x7(%ebp)
c010185a:	0f b6 45 f9          	movzbl -0x7(%ebp),%eax
c010185e:	0f b7 55 fa          	movzwl -0x6(%ebp),%edx
c0101862:	ee                   	out    %al,(%dx)
c0101863:	66 c7 45 fe a0 00    	movw   $0xa0,-0x2(%ebp)
c0101869:	c6 45 fd 0a          	movb   $0xa,-0x3(%ebp)
c010186d:	0f b6 45 fd          	movzbl -0x3(%ebp),%eax
c0101871:	0f b7 55 fe          	movzwl -0x2(%ebp),%edx
c0101875:	ee                   	out    %al,(%dx)
    outb(IO_PIC1, 0x0a);    // read IRR by default

    outb(IO_PIC2, 0x68);    // OCW3
    outb(IO_PIC2, 0x0a);    // OCW3

    if (irq_mask != 0xFFFF) {
c0101876:	0f b7 05 50 85 11 c0 	movzwl 0xc0118550,%eax
c010187d:	3d ff ff 00 00       	cmp    $0xffff,%eax
c0101882:	74 0f                	je     c0101893 <pic_init+0x137>
        pic_setmask(irq_mask);
c0101884:	0f b7 05 50 85 11 c0 	movzwl 0xc0118550,%eax
c010188b:	89 04 24             	mov    %eax,(%esp)
c010188e:	e8 3d fe ff ff       	call   c01016d0 <pic_setmask>
    }
}
c0101893:	90                   	nop
c0101894:	c9                   	leave  
c0101895:	c3                   	ret    

c0101896 <intr_enable>:
#include <x86.h>
#include <intr.h>

/* intr_enable - enable irq interrupt */
void
intr_enable(void) {
c0101896:	55                   	push   %ebp
c0101897:	89 e5                	mov    %esp,%ebp
    asm volatile ("sti");
c0101899:	fb                   	sti    
    sti();
}
c010189a:	90                   	nop
c010189b:	5d                   	pop    %ebp
c010189c:	c3                   	ret    

c010189d <intr_disable>:

/* intr_disable - disable irq interrupt */
void
intr_disable(void) {
c010189d:	55                   	push   %ebp
c010189e:	89 e5                	mov    %esp,%ebp
    asm volatile ("cli" ::: "memory");
c01018a0:	fa                   	cli    
    cli();
}
c01018a1:	90                   	nop
c01018a2:	5d                   	pop    %ebp
c01018a3:	c3                   	ret    

c01018a4 <print_ticks>:
#include <console.h>
#include <kdebug.h>

#define TICK_NUM 100

static void print_ticks() {
c01018a4:	55                   	push   %ebp
c01018a5:	89 e5                	mov    %esp,%ebp
c01018a7:	83 ec 18             	sub    $0x18,%esp
    cprintf("%d ticks\n",TICK_NUM);
c01018aa:	c7 44 24 04 64 00 00 	movl   $0x64,0x4(%esp)
c01018b1:	00 
c01018b2:	c7 04 24 e0 64 10 c0 	movl   $0xc01064e0,(%esp)
c01018b9:	e8 e4 e9 ff ff       	call   c01002a2 <cprintf>
#ifdef DEBUG_GRADE
    cprintf("End of Test.\n");
c01018be:	c7 04 24 ea 64 10 c0 	movl   $0xc01064ea,(%esp)
c01018c5:	e8 d8 e9 ff ff       	call   c01002a2 <cprintf>
    panic("EOT: kernel seems ok.");
c01018ca:	c7 44 24 08 f8 64 10 	movl   $0xc01064f8,0x8(%esp)
c01018d1:	c0 
c01018d2:	c7 44 24 04 12 00 00 	movl   $0x12,0x4(%esp)
c01018d9:	00 
c01018da:	c7 04 24 0e 65 10 c0 	movl   $0xc010650e,(%esp)
c01018e1:	e8 13 eb ff ff       	call   c01003f9 <__panic>

c01018e6 <idt_init>:
    sizeof(idt) - 1, (uintptr_t)idt
};

/* idt_init - initialize IDT to each of the entry points in kern/trap/vectors.S */
void
idt_init(void) {
c01018e6:	55                   	push   %ebp
c01018e7:	89 e5                	mov    %esp,%ebp
c01018e9:	83 ec 10             	sub    $0x10,%esp
      *     You don't know the meaning of this instruction? just google it! and check the libs/x86.h to know more.
      *     Notice: the argument of lidt is idt_pd. try to find it!
      */
      extern uintptr_t __vectors[];
    int i;
    for (i = 0; i < sizeof(idt) / sizeof(struct gatedesc); i ++) {
c01018ec:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
c01018f3:	e9 c4 00 00 00       	jmp    c01019bc <idt_init+0xd6>
        SETGATE(idt[i], 0, GD_KTEXT, __vectors[i], DPL_KERNEL);
c01018f8:	8b 45 fc             	mov    -0x4(%ebp),%eax
c01018fb:	8b 04 85 e0 85 11 c0 	mov    -0x3fee7a20(,%eax,4),%eax
c0101902:	0f b7 d0             	movzwl %ax,%edx
c0101905:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0101908:	66 89 14 c5 80 b6 11 	mov    %dx,-0x3fee4980(,%eax,8)
c010190f:	c0 
c0101910:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0101913:	66 c7 04 c5 82 b6 11 	movw   $0x8,-0x3fee497e(,%eax,8)
c010191a:	c0 08 00 
c010191d:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0101920:	0f b6 14 c5 84 b6 11 	movzbl -0x3fee497c(,%eax,8),%edx
c0101927:	c0 
c0101928:	80 e2 e0             	and    $0xe0,%dl
c010192b:	88 14 c5 84 b6 11 c0 	mov    %dl,-0x3fee497c(,%eax,8)
c0101932:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0101935:	0f b6 14 c5 84 b6 11 	movzbl -0x3fee497c(,%eax,8),%edx
c010193c:	c0 
c010193d:	80 e2 1f             	and    $0x1f,%dl
c0101940:	88 14 c5 84 b6 11 c0 	mov    %dl,-0x3fee497c(,%eax,8)
c0101947:	8b 45 fc             	mov    -0x4(%ebp),%eax
c010194a:	0f b6 14 c5 85 b6 11 	movzbl -0x3fee497b(,%eax,8),%edx
c0101951:	c0 
c0101952:	80 e2 f0             	and    $0xf0,%dl
c0101955:	80 ca 0e             	or     $0xe,%dl
c0101958:	88 14 c5 85 b6 11 c0 	mov    %dl,-0x3fee497b(,%eax,8)
c010195f:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0101962:	0f b6 14 c5 85 b6 11 	movzbl -0x3fee497b(,%eax,8),%edx
c0101969:	c0 
c010196a:	80 e2 ef             	and    $0xef,%dl
c010196d:	88 14 c5 85 b6 11 c0 	mov    %dl,-0x3fee497b(,%eax,8)
c0101974:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0101977:	0f b6 14 c5 85 b6 11 	movzbl -0x3fee497b(,%eax,8),%edx
c010197e:	c0 
c010197f:	80 e2 9f             	and    $0x9f,%dl
c0101982:	88 14 c5 85 b6 11 c0 	mov    %dl,-0x3fee497b(,%eax,8)
c0101989:	8b 45 fc             	mov    -0x4(%ebp),%eax
c010198c:	0f b6 14 c5 85 b6 11 	movzbl -0x3fee497b(,%eax,8),%edx
c0101993:	c0 
c0101994:	80 ca 80             	or     $0x80,%dl
c0101997:	88 14 c5 85 b6 11 c0 	mov    %dl,-0x3fee497b(,%eax,8)
c010199e:	8b 45 fc             	mov    -0x4(%ebp),%eax
c01019a1:	8b 04 85 e0 85 11 c0 	mov    -0x3fee7a20(,%eax,4),%eax
c01019a8:	c1 e8 10             	shr    $0x10,%eax
c01019ab:	0f b7 d0             	movzwl %ax,%edx
c01019ae:	8b 45 fc             	mov    -0x4(%ebp),%eax
c01019b1:	66 89 14 c5 86 b6 11 	mov    %dx,-0x3fee497a(,%eax,8)
c01019b8:	c0 
    for (i = 0; i < sizeof(idt) / sizeof(struct gatedesc); i ++) {
c01019b9:	ff 45 fc             	incl   -0x4(%ebp)
c01019bc:	8b 45 fc             	mov    -0x4(%ebp),%eax
c01019bf:	3d ff 00 00 00       	cmp    $0xff,%eax
c01019c4:	0f 86 2e ff ff ff    	jbe    c01018f8 <idt_init+0x12>
    }
	// set for switch from user to kernel
    SETGATE(idt[T_SWITCH_TOK], 0, GD_KTEXT, __vectors[T_SWITCH_TOK], DPL_USER);
c01019ca:	a1 c4 87 11 c0       	mov    0xc01187c4,%eax
c01019cf:	0f b7 c0             	movzwl %ax,%eax
c01019d2:	66 a3 48 ba 11 c0    	mov    %ax,0xc011ba48
c01019d8:	66 c7 05 4a ba 11 c0 	movw   $0x8,0xc011ba4a
c01019df:	08 00 
c01019e1:	0f b6 05 4c ba 11 c0 	movzbl 0xc011ba4c,%eax
c01019e8:	24 e0                	and    $0xe0,%al
c01019ea:	a2 4c ba 11 c0       	mov    %al,0xc011ba4c
c01019ef:	0f b6 05 4c ba 11 c0 	movzbl 0xc011ba4c,%eax
c01019f6:	24 1f                	and    $0x1f,%al
c01019f8:	a2 4c ba 11 c0       	mov    %al,0xc011ba4c
c01019fd:	0f b6 05 4d ba 11 c0 	movzbl 0xc011ba4d,%eax
c0101a04:	24 f0                	and    $0xf0,%al
c0101a06:	0c 0e                	or     $0xe,%al
c0101a08:	a2 4d ba 11 c0       	mov    %al,0xc011ba4d
c0101a0d:	0f b6 05 4d ba 11 c0 	movzbl 0xc011ba4d,%eax
c0101a14:	24 ef                	and    $0xef,%al
c0101a16:	a2 4d ba 11 c0       	mov    %al,0xc011ba4d
c0101a1b:	0f b6 05 4d ba 11 c0 	movzbl 0xc011ba4d,%eax
c0101a22:	0c 60                	or     $0x60,%al
c0101a24:	a2 4d ba 11 c0       	mov    %al,0xc011ba4d
c0101a29:	0f b6 05 4d ba 11 c0 	movzbl 0xc011ba4d,%eax
c0101a30:	0c 80                	or     $0x80,%al
c0101a32:	a2 4d ba 11 c0       	mov    %al,0xc011ba4d
c0101a37:	a1 c4 87 11 c0       	mov    0xc01187c4,%eax
c0101a3c:	c1 e8 10             	shr    $0x10,%eax
c0101a3f:	0f b7 c0             	movzwl %ax,%eax
c0101a42:	66 a3 4e ba 11 c0    	mov    %ax,0xc011ba4e
c0101a48:	c7 45 f8 60 85 11 c0 	movl   $0xc0118560,-0x8(%ebp)
    asm volatile ("lidt (%0)" :: "r" (pd) : "memory");
c0101a4f:	8b 45 f8             	mov    -0x8(%ebp),%eax
c0101a52:	0f 01 18             	lidtl  (%eax)
	// load the IDT
    lidt(&idt_pd);
}
c0101a55:	90                   	nop
c0101a56:	c9                   	leave  
c0101a57:	c3                   	ret    

c0101a58 <trapname>:

static const char *
trapname(int trapno) {
c0101a58:	55                   	push   %ebp
c0101a59:	89 e5                	mov    %esp,%ebp
        "Alignment Check",
        "Machine-Check",
        "SIMD Floating-Point Exception"
    };

    if (trapno < sizeof(excnames)/sizeof(const char * const)) {
c0101a5b:	8b 45 08             	mov    0x8(%ebp),%eax
c0101a5e:	83 f8 13             	cmp    $0x13,%eax
c0101a61:	77 0c                	ja     c0101a6f <trapname+0x17>
        return excnames[trapno];
c0101a63:	8b 45 08             	mov    0x8(%ebp),%eax
c0101a66:	8b 04 85 60 68 10 c0 	mov    -0x3fef97a0(,%eax,4),%eax
c0101a6d:	eb 18                	jmp    c0101a87 <trapname+0x2f>
    }
    if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16) {
c0101a6f:	83 7d 08 1f          	cmpl   $0x1f,0x8(%ebp)
c0101a73:	7e 0d                	jle    c0101a82 <trapname+0x2a>
c0101a75:	83 7d 08 2f          	cmpl   $0x2f,0x8(%ebp)
c0101a79:	7f 07                	jg     c0101a82 <trapname+0x2a>
        return "Hardware Interrupt";
c0101a7b:	b8 1f 65 10 c0       	mov    $0xc010651f,%eax
c0101a80:	eb 05                	jmp    c0101a87 <trapname+0x2f>
    }
    return "(unknown trap)";
c0101a82:	b8 32 65 10 c0       	mov    $0xc0106532,%eax
}
c0101a87:	5d                   	pop    %ebp
c0101a88:	c3                   	ret    

c0101a89 <trap_in_kernel>:

/* trap_in_kernel - test if trap happened in kernel */
bool
trap_in_kernel(struct trapframe *tf) {
c0101a89:	55                   	push   %ebp
c0101a8a:	89 e5                	mov    %esp,%ebp
    return (tf->tf_cs == (uint16_t)KERNEL_CS);
c0101a8c:	8b 45 08             	mov    0x8(%ebp),%eax
c0101a8f:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
c0101a93:	83 f8 08             	cmp    $0x8,%eax
c0101a96:	0f 94 c0             	sete   %al
c0101a99:	0f b6 c0             	movzbl %al,%eax
}
c0101a9c:	5d                   	pop    %ebp
c0101a9d:	c3                   	ret    

c0101a9e <print_trapframe>:
    "TF", "IF", "DF", "OF", NULL, NULL, "NT", NULL,
    "RF", "VM", "AC", "VIF", "VIP", "ID", NULL, NULL,
};

void
print_trapframe(struct trapframe *tf) {
c0101a9e:	55                   	push   %ebp
c0101a9f:	89 e5                	mov    %esp,%ebp
c0101aa1:	83 ec 28             	sub    $0x28,%esp
    cprintf("trapframe at %p\n", tf);
c0101aa4:	8b 45 08             	mov    0x8(%ebp),%eax
c0101aa7:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101aab:	c7 04 24 73 65 10 c0 	movl   $0xc0106573,(%esp)
c0101ab2:	e8 eb e7 ff ff       	call   c01002a2 <cprintf>
    print_regs(&tf->tf_regs);
c0101ab7:	8b 45 08             	mov    0x8(%ebp),%eax
c0101aba:	89 04 24             	mov    %eax,(%esp)
c0101abd:	e8 8f 01 00 00       	call   c0101c51 <print_regs>
    cprintf("  ds   0x----%04x\n", tf->tf_ds);
c0101ac2:	8b 45 08             	mov    0x8(%ebp),%eax
c0101ac5:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
c0101ac9:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101acd:	c7 04 24 84 65 10 c0 	movl   $0xc0106584,(%esp)
c0101ad4:	e8 c9 e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  es   0x----%04x\n", tf->tf_es);
c0101ad9:	8b 45 08             	mov    0x8(%ebp),%eax
c0101adc:	0f b7 40 28          	movzwl 0x28(%eax),%eax
c0101ae0:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101ae4:	c7 04 24 97 65 10 c0 	movl   $0xc0106597,(%esp)
c0101aeb:	e8 b2 e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  fs   0x----%04x\n", tf->tf_fs);
c0101af0:	8b 45 08             	mov    0x8(%ebp),%eax
c0101af3:	0f b7 40 24          	movzwl 0x24(%eax),%eax
c0101af7:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101afb:	c7 04 24 aa 65 10 c0 	movl   $0xc01065aa,(%esp)
c0101b02:	e8 9b e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  gs   0x----%04x\n", tf->tf_gs);
c0101b07:	8b 45 08             	mov    0x8(%ebp),%eax
c0101b0a:	0f b7 40 20          	movzwl 0x20(%eax),%eax
c0101b0e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101b12:	c7 04 24 bd 65 10 c0 	movl   $0xc01065bd,(%esp)
c0101b19:	e8 84 e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
c0101b1e:	8b 45 08             	mov    0x8(%ebp),%eax
c0101b21:	8b 40 30             	mov    0x30(%eax),%eax
c0101b24:	89 04 24             	mov    %eax,(%esp)
c0101b27:	e8 2c ff ff ff       	call   c0101a58 <trapname>
c0101b2c:	89 c2                	mov    %eax,%edx
c0101b2e:	8b 45 08             	mov    0x8(%ebp),%eax
c0101b31:	8b 40 30             	mov    0x30(%eax),%eax
c0101b34:	89 54 24 08          	mov    %edx,0x8(%esp)
c0101b38:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101b3c:	c7 04 24 d0 65 10 c0 	movl   $0xc01065d0,(%esp)
c0101b43:	e8 5a e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  err  0x%08x\n", tf->tf_err);
c0101b48:	8b 45 08             	mov    0x8(%ebp),%eax
c0101b4b:	8b 40 34             	mov    0x34(%eax),%eax
c0101b4e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101b52:	c7 04 24 e2 65 10 c0 	movl   $0xc01065e2,(%esp)
c0101b59:	e8 44 e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  eip  0x%08x\n", tf->tf_eip);
c0101b5e:	8b 45 08             	mov    0x8(%ebp),%eax
c0101b61:	8b 40 38             	mov    0x38(%eax),%eax
c0101b64:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101b68:	c7 04 24 f1 65 10 c0 	movl   $0xc01065f1,(%esp)
c0101b6f:	e8 2e e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  cs   0x----%04x\n", tf->tf_cs);
c0101b74:	8b 45 08             	mov    0x8(%ebp),%eax
c0101b77:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
c0101b7b:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101b7f:	c7 04 24 00 66 10 c0 	movl   $0xc0106600,(%esp)
c0101b86:	e8 17 e7 ff ff       	call   c01002a2 <cprintf>
    cprintf("  flag 0x%08x ", tf->tf_eflags);
c0101b8b:	8b 45 08             	mov    0x8(%ebp),%eax
c0101b8e:	8b 40 40             	mov    0x40(%eax),%eax
c0101b91:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101b95:	c7 04 24 13 66 10 c0 	movl   $0xc0106613,(%esp)
c0101b9c:	e8 01 e7 ff ff       	call   c01002a2 <cprintf>

    int i, j;
    for (i = 0, j = 1; i < sizeof(IA32flags) / sizeof(IA32flags[0]); i ++, j <<= 1) {
c0101ba1:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
c0101ba8:	c7 45 f0 01 00 00 00 	movl   $0x1,-0x10(%ebp)
c0101baf:	eb 3d                	jmp    c0101bee <print_trapframe+0x150>
        if ((tf->tf_eflags & j) && IA32flags[i] != NULL) {
c0101bb1:	8b 45 08             	mov    0x8(%ebp),%eax
c0101bb4:	8b 50 40             	mov    0x40(%eax),%edx
c0101bb7:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0101bba:	21 d0                	and    %edx,%eax
c0101bbc:	85 c0                	test   %eax,%eax
c0101bbe:	74 28                	je     c0101be8 <print_trapframe+0x14a>
c0101bc0:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0101bc3:	8b 04 85 80 85 11 c0 	mov    -0x3fee7a80(,%eax,4),%eax
c0101bca:	85 c0                	test   %eax,%eax
c0101bcc:	74 1a                	je     c0101be8 <print_trapframe+0x14a>
            cprintf("%s,", IA32flags[i]);
c0101bce:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0101bd1:	8b 04 85 80 85 11 c0 	mov    -0x3fee7a80(,%eax,4),%eax
c0101bd8:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101bdc:	c7 04 24 22 66 10 c0 	movl   $0xc0106622,(%esp)
c0101be3:	e8 ba e6 ff ff       	call   c01002a2 <cprintf>
    for (i = 0, j = 1; i < sizeof(IA32flags) / sizeof(IA32flags[0]); i ++, j <<= 1) {
c0101be8:	ff 45 f4             	incl   -0xc(%ebp)
c0101beb:	d1 65 f0             	shll   -0x10(%ebp)
c0101bee:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0101bf1:	83 f8 17             	cmp    $0x17,%eax
c0101bf4:	76 bb                	jbe    c0101bb1 <print_trapframe+0x113>
        }
    }
    cprintf("IOPL=%d\n", (tf->tf_eflags & FL_IOPL_MASK) >> 12);
c0101bf6:	8b 45 08             	mov    0x8(%ebp),%eax
c0101bf9:	8b 40 40             	mov    0x40(%eax),%eax
c0101bfc:	c1 e8 0c             	shr    $0xc,%eax
c0101bff:	83 e0 03             	and    $0x3,%eax
c0101c02:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101c06:	c7 04 24 26 66 10 c0 	movl   $0xc0106626,(%esp)
c0101c0d:	e8 90 e6 ff ff       	call   c01002a2 <cprintf>

    if (!trap_in_kernel(tf)) {
c0101c12:	8b 45 08             	mov    0x8(%ebp),%eax
c0101c15:	89 04 24             	mov    %eax,(%esp)
c0101c18:	e8 6c fe ff ff       	call   c0101a89 <trap_in_kernel>
c0101c1d:	85 c0                	test   %eax,%eax
c0101c1f:	75 2d                	jne    c0101c4e <print_trapframe+0x1b0>
        cprintf("  esp  0x%08x\n", tf->tf_esp);
c0101c21:	8b 45 08             	mov    0x8(%ebp),%eax
c0101c24:	8b 40 44             	mov    0x44(%eax),%eax
c0101c27:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101c2b:	c7 04 24 2f 66 10 c0 	movl   $0xc010662f,(%esp)
c0101c32:	e8 6b e6 ff ff       	call   c01002a2 <cprintf>
        cprintf("  ss   0x----%04x\n", tf->tf_ss);
c0101c37:	8b 45 08             	mov    0x8(%ebp),%eax
c0101c3a:	0f b7 40 48          	movzwl 0x48(%eax),%eax
c0101c3e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101c42:	c7 04 24 3e 66 10 c0 	movl   $0xc010663e,(%esp)
c0101c49:	e8 54 e6 ff ff       	call   c01002a2 <cprintf>
    }
}
c0101c4e:	90                   	nop
c0101c4f:	c9                   	leave  
c0101c50:	c3                   	ret    

c0101c51 <print_regs>:

void
print_regs(struct pushregs *regs) {
c0101c51:	55                   	push   %ebp
c0101c52:	89 e5                	mov    %esp,%ebp
c0101c54:	83 ec 18             	sub    $0x18,%esp
    cprintf("  edi  0x%08x\n", regs->reg_edi);
c0101c57:	8b 45 08             	mov    0x8(%ebp),%eax
c0101c5a:	8b 00                	mov    (%eax),%eax
c0101c5c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101c60:	c7 04 24 51 66 10 c0 	movl   $0xc0106651,(%esp)
c0101c67:	e8 36 e6 ff ff       	call   c01002a2 <cprintf>
    cprintf("  esi  0x%08x\n", regs->reg_esi);
c0101c6c:	8b 45 08             	mov    0x8(%ebp),%eax
c0101c6f:	8b 40 04             	mov    0x4(%eax),%eax
c0101c72:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101c76:	c7 04 24 60 66 10 c0 	movl   $0xc0106660,(%esp)
c0101c7d:	e8 20 e6 ff ff       	call   c01002a2 <cprintf>
    cprintf("  ebp  0x%08x\n", regs->reg_ebp);
c0101c82:	8b 45 08             	mov    0x8(%ebp),%eax
c0101c85:	8b 40 08             	mov    0x8(%eax),%eax
c0101c88:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101c8c:	c7 04 24 6f 66 10 c0 	movl   $0xc010666f,(%esp)
c0101c93:	e8 0a e6 ff ff       	call   c01002a2 <cprintf>
    cprintf("  oesp 0x%08x\n", regs->reg_oesp);
c0101c98:	8b 45 08             	mov    0x8(%ebp),%eax
c0101c9b:	8b 40 0c             	mov    0xc(%eax),%eax
c0101c9e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101ca2:	c7 04 24 7e 66 10 c0 	movl   $0xc010667e,(%esp)
c0101ca9:	e8 f4 e5 ff ff       	call   c01002a2 <cprintf>
    cprintf("  ebx  0x%08x\n", regs->reg_ebx);
c0101cae:	8b 45 08             	mov    0x8(%ebp),%eax
c0101cb1:	8b 40 10             	mov    0x10(%eax),%eax
c0101cb4:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101cb8:	c7 04 24 8d 66 10 c0 	movl   $0xc010668d,(%esp)
c0101cbf:	e8 de e5 ff ff       	call   c01002a2 <cprintf>
    cprintf("  edx  0x%08x\n", regs->reg_edx);
c0101cc4:	8b 45 08             	mov    0x8(%ebp),%eax
c0101cc7:	8b 40 14             	mov    0x14(%eax),%eax
c0101cca:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101cce:	c7 04 24 9c 66 10 c0 	movl   $0xc010669c,(%esp)
c0101cd5:	e8 c8 e5 ff ff       	call   c01002a2 <cprintf>
    cprintf("  ecx  0x%08x\n", regs->reg_ecx);
c0101cda:	8b 45 08             	mov    0x8(%ebp),%eax
c0101cdd:	8b 40 18             	mov    0x18(%eax),%eax
c0101ce0:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101ce4:	c7 04 24 ab 66 10 c0 	movl   $0xc01066ab,(%esp)
c0101ceb:	e8 b2 e5 ff ff       	call   c01002a2 <cprintf>
    cprintf("  eax  0x%08x\n", regs->reg_eax);
c0101cf0:	8b 45 08             	mov    0x8(%ebp),%eax
c0101cf3:	8b 40 1c             	mov    0x1c(%eax),%eax
c0101cf6:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101cfa:	c7 04 24 ba 66 10 c0 	movl   $0xc01066ba,(%esp)
c0101d01:	e8 9c e5 ff ff       	call   c01002a2 <cprintf>
}
c0101d06:	90                   	nop
c0101d07:	c9                   	leave  
c0101d08:	c3                   	ret    

c0101d09 <trap_dispatch>:
/* temporary trapframe or pointer to trapframe */
struct trapframe switchk2u, *switchu2k;

/* trap_dispatch - dispatch based on what type of trap occurred */
static void
trap_dispatch(struct trapframe *tf) {
c0101d09:	55                   	push   %ebp
c0101d0a:	89 e5                	mov    %esp,%ebp
c0101d0c:	57                   	push   %edi
c0101d0d:	56                   	push   %esi
c0101d0e:	53                   	push   %ebx
c0101d0f:	83 ec 2c             	sub    $0x2c,%esp
    char c;

    switch (tf->tf_trapno) {
c0101d12:	8b 45 08             	mov    0x8(%ebp),%eax
c0101d15:	8b 40 30             	mov    0x30(%eax),%eax
c0101d18:	83 f8 2f             	cmp    $0x2f,%eax
c0101d1b:	77 21                	ja     c0101d3e <trap_dispatch+0x35>
c0101d1d:	83 f8 2e             	cmp    $0x2e,%eax
c0101d20:	0f 83 5d 02 00 00    	jae    c0101f83 <trap_dispatch+0x27a>
c0101d26:	83 f8 21             	cmp    $0x21,%eax
c0101d29:	0f 84 95 00 00 00    	je     c0101dc4 <trap_dispatch+0xbb>
c0101d2f:	83 f8 24             	cmp    $0x24,%eax
c0101d32:	74 67                	je     c0101d9b <trap_dispatch+0x92>
c0101d34:	83 f8 20             	cmp    $0x20,%eax
c0101d37:	74 1c                	je     c0101d55 <trap_dispatch+0x4c>
c0101d39:	e9 10 02 00 00       	jmp    c0101f4e <trap_dispatch+0x245>
c0101d3e:	83 f8 78             	cmp    $0x78,%eax
c0101d41:	0f 84 a6 00 00 00    	je     c0101ded <trap_dispatch+0xe4>
c0101d47:	83 f8 79             	cmp    $0x79,%eax
c0101d4a:	0f 84 81 01 00 00    	je     c0101ed1 <trap_dispatch+0x1c8>
c0101d50:	e9 f9 01 00 00       	jmp    c0101f4e <trap_dispatch+0x245>
        /* handle the timer interrupt */
        /* (1) After a timer interrupt, you should record this event using a global variable (increase it), such as ticks in kern/driver/clock.c
         * (2) Every TICK_NUM cycle, you can print some info using a funciton, such as print_ticks().
         * (3) Too Simple? Yes, I think so!
         */
        ticks ++;
c0101d55:	a1 0c bf 11 c0       	mov    0xc011bf0c,%eax
c0101d5a:	40                   	inc    %eax
c0101d5b:	a3 0c bf 11 c0       	mov    %eax,0xc011bf0c
        if (ticks % TICK_NUM == 0) {
c0101d60:	8b 0d 0c bf 11 c0    	mov    0xc011bf0c,%ecx
c0101d66:	ba 1f 85 eb 51       	mov    $0x51eb851f,%edx
c0101d6b:	89 c8                	mov    %ecx,%eax
c0101d6d:	f7 e2                	mul    %edx
c0101d6f:	c1 ea 05             	shr    $0x5,%edx
c0101d72:	89 d0                	mov    %edx,%eax
c0101d74:	c1 e0 02             	shl    $0x2,%eax
c0101d77:	01 d0                	add    %edx,%eax
c0101d79:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
c0101d80:	01 d0                	add    %edx,%eax
c0101d82:	c1 e0 02             	shl    $0x2,%eax
c0101d85:	29 c1                	sub    %eax,%ecx
c0101d87:	89 ca                	mov    %ecx,%edx
c0101d89:	85 d2                	test   %edx,%edx
c0101d8b:	0f 85 f5 01 00 00    	jne    c0101f86 <trap_dispatch+0x27d>
            print_ticks();
c0101d91:	e8 0e fb ff ff       	call   c01018a4 <print_ticks>
        }
        break;
c0101d96:	e9 eb 01 00 00       	jmp    c0101f86 <trap_dispatch+0x27d>
    case IRQ_OFFSET + IRQ_COM1:
        c = cons_getc();
c0101d9b:	e8 c1 f8 ff ff       	call   c0101661 <cons_getc>
c0101da0:	88 45 e7             	mov    %al,-0x19(%ebp)
        cprintf("serial [%03d] %c\n", c, c);
c0101da3:	0f be 55 e7          	movsbl -0x19(%ebp),%edx
c0101da7:	0f be 45 e7          	movsbl -0x19(%ebp),%eax
c0101dab:	89 54 24 08          	mov    %edx,0x8(%esp)
c0101daf:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101db3:	c7 04 24 c9 66 10 c0 	movl   $0xc01066c9,(%esp)
c0101dba:	e8 e3 e4 ff ff       	call   c01002a2 <cprintf>
        break;
c0101dbf:	e9 c9 01 00 00       	jmp    c0101f8d <trap_dispatch+0x284>
    case IRQ_OFFSET + IRQ_KBD:
        c = cons_getc();
c0101dc4:	e8 98 f8 ff ff       	call   c0101661 <cons_getc>
c0101dc9:	88 45 e7             	mov    %al,-0x19(%ebp)
        cprintf("kbd [%03d] %c\n", c, c);
c0101dcc:	0f be 55 e7          	movsbl -0x19(%ebp),%edx
c0101dd0:	0f be 45 e7          	movsbl -0x19(%ebp),%eax
c0101dd4:	89 54 24 08          	mov    %edx,0x8(%esp)
c0101dd8:	89 44 24 04          	mov    %eax,0x4(%esp)
c0101ddc:	c7 04 24 db 66 10 c0 	movl   $0xc01066db,(%esp)
c0101de3:	e8 ba e4 ff ff       	call   c01002a2 <cprintf>
        break;
c0101de8:	e9 a0 01 00 00       	jmp    c0101f8d <trap_dispatch+0x284>
    //LAB1 CHALLENGE 1 : YOUR CODE you should modify below codes.
    case T_SWITCH_TOU:
        if (tf->tf_cs != USER_CS) {
c0101ded:	8b 45 08             	mov    0x8(%ebp),%eax
c0101df0:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
c0101df4:	83 f8 1b             	cmp    $0x1b,%eax
c0101df7:	0f 84 8c 01 00 00    	je     c0101f89 <trap_dispatch+0x280>
            switchk2u = *tf;
c0101dfd:	8b 55 08             	mov    0x8(%ebp),%edx
c0101e00:	b8 20 bf 11 c0       	mov    $0xc011bf20,%eax
c0101e05:	bb 4c 00 00 00       	mov    $0x4c,%ebx
c0101e0a:	89 c1                	mov    %eax,%ecx
c0101e0c:	83 e1 01             	and    $0x1,%ecx
c0101e0f:	85 c9                	test   %ecx,%ecx
c0101e11:	74 0c                	je     c0101e1f <trap_dispatch+0x116>
c0101e13:	0f b6 0a             	movzbl (%edx),%ecx
c0101e16:	88 08                	mov    %cl,(%eax)
c0101e18:	8d 40 01             	lea    0x1(%eax),%eax
c0101e1b:	8d 52 01             	lea    0x1(%edx),%edx
c0101e1e:	4b                   	dec    %ebx
c0101e1f:	89 c1                	mov    %eax,%ecx
c0101e21:	83 e1 02             	and    $0x2,%ecx
c0101e24:	85 c9                	test   %ecx,%ecx
c0101e26:	74 0f                	je     c0101e37 <trap_dispatch+0x12e>
c0101e28:	0f b7 0a             	movzwl (%edx),%ecx
c0101e2b:	66 89 08             	mov    %cx,(%eax)
c0101e2e:	8d 40 02             	lea    0x2(%eax),%eax
c0101e31:	8d 52 02             	lea    0x2(%edx),%edx
c0101e34:	83 eb 02             	sub    $0x2,%ebx
c0101e37:	89 df                	mov    %ebx,%edi
c0101e39:	83 e7 fc             	and    $0xfffffffc,%edi
c0101e3c:	b9 00 00 00 00       	mov    $0x0,%ecx
c0101e41:	8b 34 0a             	mov    (%edx,%ecx,1),%esi
c0101e44:	89 34 08             	mov    %esi,(%eax,%ecx,1)
c0101e47:	83 c1 04             	add    $0x4,%ecx
c0101e4a:	39 f9                	cmp    %edi,%ecx
c0101e4c:	72 f3                	jb     c0101e41 <trap_dispatch+0x138>
c0101e4e:	01 c8                	add    %ecx,%eax
c0101e50:	01 ca                	add    %ecx,%edx
c0101e52:	b9 00 00 00 00       	mov    $0x0,%ecx
c0101e57:	89 de                	mov    %ebx,%esi
c0101e59:	83 e6 02             	and    $0x2,%esi
c0101e5c:	85 f6                	test   %esi,%esi
c0101e5e:	74 0b                	je     c0101e6b <trap_dispatch+0x162>
c0101e60:	0f b7 34 0a          	movzwl (%edx,%ecx,1),%esi
c0101e64:	66 89 34 08          	mov    %si,(%eax,%ecx,1)
c0101e68:	83 c1 02             	add    $0x2,%ecx
c0101e6b:	83 e3 01             	and    $0x1,%ebx
c0101e6e:	85 db                	test   %ebx,%ebx
c0101e70:	74 07                	je     c0101e79 <trap_dispatch+0x170>
c0101e72:	0f b6 14 0a          	movzbl (%edx,%ecx,1),%edx
c0101e76:	88 14 08             	mov    %dl,(%eax,%ecx,1)
            switchk2u.tf_cs = USER_CS;
c0101e79:	66 c7 05 5c bf 11 c0 	movw   $0x1b,0xc011bf5c
c0101e80:	1b 00 
            switchk2u.tf_ds = switchk2u.tf_es = switchk2u.tf_ss = USER_DS;
c0101e82:	66 c7 05 68 bf 11 c0 	movw   $0x23,0xc011bf68
c0101e89:	23 00 
c0101e8b:	0f b7 05 68 bf 11 c0 	movzwl 0xc011bf68,%eax
c0101e92:	66 a3 48 bf 11 c0    	mov    %ax,0xc011bf48
c0101e98:	0f b7 05 48 bf 11 c0 	movzwl 0xc011bf48,%eax
c0101e9f:	66 a3 4c bf 11 c0    	mov    %ax,0xc011bf4c
            switchk2u.tf_esp = (uint32_t)tf + sizeof(struct trapframe) - 8;
c0101ea5:	8b 45 08             	mov    0x8(%ebp),%eax
c0101ea8:	83 c0 44             	add    $0x44,%eax
c0101eab:	a3 64 bf 11 c0       	mov    %eax,0xc011bf64
		
            // set eflags, make sure ucore can use io under user mode.
            // if CPL > IOPL, then cpu will generate a general protection.
            switchk2u.tf_eflags |= FL_IOPL_MASK;
c0101eb0:	a1 60 bf 11 c0       	mov    0xc011bf60,%eax
c0101eb5:	0d 00 30 00 00       	or     $0x3000,%eax
c0101eba:	a3 60 bf 11 c0       	mov    %eax,0xc011bf60
		
            // set temporary stack
            // then iret will jump to the right stack
            *((uint32_t *)tf - 1) = (uint32_t)&switchk2u;
c0101ebf:	8b 45 08             	mov    0x8(%ebp),%eax
c0101ec2:	83 e8 04             	sub    $0x4,%eax
c0101ec5:	ba 20 bf 11 c0       	mov    $0xc011bf20,%edx
c0101eca:	89 10                	mov    %edx,(%eax)
        }
        break;
c0101ecc:	e9 b8 00 00 00       	jmp    c0101f89 <trap_dispatch+0x280>
    case T_SWITCH_TOK:
         if (tf->tf_cs != KERNEL_CS) {
c0101ed1:	8b 45 08             	mov    0x8(%ebp),%eax
c0101ed4:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
c0101ed8:	83 f8 08             	cmp    $0x8,%eax
c0101edb:	0f 84 ab 00 00 00    	je     c0101f8c <trap_dispatch+0x283>
            tf->tf_cs = KERNEL_CS;
c0101ee1:	8b 45 08             	mov    0x8(%ebp),%eax
c0101ee4:	66 c7 40 3c 08 00    	movw   $0x8,0x3c(%eax)
            tf->tf_ds = tf->tf_es = KERNEL_DS;
c0101eea:	8b 45 08             	mov    0x8(%ebp),%eax
c0101eed:	66 c7 40 28 10 00    	movw   $0x10,0x28(%eax)
c0101ef3:	8b 45 08             	mov    0x8(%ebp),%eax
c0101ef6:	0f b7 50 28          	movzwl 0x28(%eax),%edx
c0101efa:	8b 45 08             	mov    0x8(%ebp),%eax
c0101efd:	66 89 50 2c          	mov    %dx,0x2c(%eax)
            tf->tf_eflags &= ~FL_IOPL_MASK;
c0101f01:	8b 45 08             	mov    0x8(%ebp),%eax
c0101f04:	8b 40 40             	mov    0x40(%eax),%eax
c0101f07:	25 ff cf ff ff       	and    $0xffffcfff,%eax
c0101f0c:	89 c2                	mov    %eax,%edx
c0101f0e:	8b 45 08             	mov    0x8(%ebp),%eax
c0101f11:	89 50 40             	mov    %edx,0x40(%eax)
            switchu2k = (struct trapframe *)(tf->tf_esp - (sizeof(struct trapframe) - 8));
c0101f14:	8b 45 08             	mov    0x8(%ebp),%eax
c0101f17:	8b 40 44             	mov    0x44(%eax),%eax
c0101f1a:	83 e8 44             	sub    $0x44,%eax
c0101f1d:	a3 6c bf 11 c0       	mov    %eax,0xc011bf6c
            memmove(switchu2k, tf, sizeof(struct trapframe) - 8);
c0101f22:	a1 6c bf 11 c0       	mov    0xc011bf6c,%eax
c0101f27:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
c0101f2e:	00 
c0101f2f:	8b 55 08             	mov    0x8(%ebp),%edx
c0101f32:	89 54 24 04          	mov    %edx,0x4(%esp)
c0101f36:	89 04 24             	mov    %eax,(%esp)
c0101f39:	e8 86 3a 00 00       	call   c01059c4 <memmove>
            *((uint32_t *)tf - 1) = (uint32_t)switchu2k;
c0101f3e:	8b 15 6c bf 11 c0    	mov    0xc011bf6c,%edx
c0101f44:	8b 45 08             	mov    0x8(%ebp),%eax
c0101f47:	83 e8 04             	sub    $0x4,%eax
c0101f4a:	89 10                	mov    %edx,(%eax)
        }
        break;
c0101f4c:	eb 3e                	jmp    c0101f8c <trap_dispatch+0x283>
    case IRQ_OFFSET + IRQ_IDE2:
        /* do nothing */
        break;
    default:
        // in kernel, it must be a mistake
        if ((tf->tf_cs & 3) == 0) {
c0101f4e:	8b 45 08             	mov    0x8(%ebp),%eax
c0101f51:	0f b7 40 3c          	movzwl 0x3c(%eax),%eax
c0101f55:	83 e0 03             	and    $0x3,%eax
c0101f58:	85 c0                	test   %eax,%eax
c0101f5a:	75 31                	jne    c0101f8d <trap_dispatch+0x284>
            print_trapframe(tf);
c0101f5c:	8b 45 08             	mov    0x8(%ebp),%eax
c0101f5f:	89 04 24             	mov    %eax,(%esp)
c0101f62:	e8 37 fb ff ff       	call   c0101a9e <print_trapframe>
            panic("unexpected trap in kernel.\n");
c0101f67:	c7 44 24 08 ea 66 10 	movl   $0xc01066ea,0x8(%esp)
c0101f6e:	c0 
c0101f6f:	c7 44 24 04 d4 00 00 	movl   $0xd4,0x4(%esp)
c0101f76:	00 
c0101f77:	c7 04 24 0e 65 10 c0 	movl   $0xc010650e,(%esp)
c0101f7e:	e8 76 e4 ff ff       	call   c01003f9 <__panic>
        break;
c0101f83:	90                   	nop
c0101f84:	eb 07                	jmp    c0101f8d <trap_dispatch+0x284>
        break;
c0101f86:	90                   	nop
c0101f87:	eb 04                	jmp    c0101f8d <trap_dispatch+0x284>
        break;
c0101f89:	90                   	nop
c0101f8a:	eb 01                	jmp    c0101f8d <trap_dispatch+0x284>
        break;
c0101f8c:	90                   	nop
        }
    }
}
c0101f8d:	90                   	nop
c0101f8e:	83 c4 2c             	add    $0x2c,%esp
c0101f91:	5b                   	pop    %ebx
c0101f92:	5e                   	pop    %esi
c0101f93:	5f                   	pop    %edi
c0101f94:	5d                   	pop    %ebp
c0101f95:	c3                   	ret    

c0101f96 <trap>:
 * trap - handles or dispatches an exception/interrupt. if and when trap() returns,
 * the code in kern/trap/trapentry.S restores the old CPU state saved in the
 * trapframe and then uses the iret instruction to return from the exception.
 * */
void
trap(struct trapframe *tf) {
c0101f96:	55                   	push   %ebp
c0101f97:	89 e5                	mov    %esp,%ebp
c0101f99:	83 ec 18             	sub    $0x18,%esp
    // dispatch based on what type of trap occurred
    trap_dispatch(tf);
c0101f9c:	8b 45 08             	mov    0x8(%ebp),%eax
c0101f9f:	89 04 24             	mov    %eax,(%esp)
c0101fa2:	e8 62 fd ff ff       	call   c0101d09 <trap_dispatch>
}
c0101fa7:	90                   	nop
c0101fa8:	c9                   	leave  
c0101fa9:	c3                   	ret    

c0101faa <vector0>:
# handler
.text
.globl __alltraps
.globl vector0
vector0:
  pushl $0
c0101faa:	6a 00                	push   $0x0
  pushl $0
c0101fac:	6a 00                	push   $0x0
  jmp __alltraps
c0101fae:	e9 69 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101fb3 <vector1>:
.globl vector1
vector1:
  pushl $0
c0101fb3:	6a 00                	push   $0x0
  pushl $1
c0101fb5:	6a 01                	push   $0x1
  jmp __alltraps
c0101fb7:	e9 60 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101fbc <vector2>:
.globl vector2
vector2:
  pushl $0
c0101fbc:	6a 00                	push   $0x0
  pushl $2
c0101fbe:	6a 02                	push   $0x2
  jmp __alltraps
c0101fc0:	e9 57 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101fc5 <vector3>:
.globl vector3
vector3:
  pushl $0
c0101fc5:	6a 00                	push   $0x0
  pushl $3
c0101fc7:	6a 03                	push   $0x3
  jmp __alltraps
c0101fc9:	e9 4e 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101fce <vector4>:
.globl vector4
vector4:
  pushl $0
c0101fce:	6a 00                	push   $0x0
  pushl $4
c0101fd0:	6a 04                	push   $0x4
  jmp __alltraps
c0101fd2:	e9 45 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101fd7 <vector5>:
.globl vector5
vector5:
  pushl $0
c0101fd7:	6a 00                	push   $0x0
  pushl $5
c0101fd9:	6a 05                	push   $0x5
  jmp __alltraps
c0101fdb:	e9 3c 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101fe0 <vector6>:
.globl vector6
vector6:
  pushl $0
c0101fe0:	6a 00                	push   $0x0
  pushl $6
c0101fe2:	6a 06                	push   $0x6
  jmp __alltraps
c0101fe4:	e9 33 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101fe9 <vector7>:
.globl vector7
vector7:
  pushl $0
c0101fe9:	6a 00                	push   $0x0
  pushl $7
c0101feb:	6a 07                	push   $0x7
  jmp __alltraps
c0101fed:	e9 2a 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101ff2 <vector8>:
.globl vector8
vector8:
  pushl $8
c0101ff2:	6a 08                	push   $0x8
  jmp __alltraps
c0101ff4:	e9 23 0a 00 00       	jmp    c0102a1c <__alltraps>

c0101ff9 <vector9>:
.globl vector9
vector9:
  pushl $0
c0101ff9:	6a 00                	push   $0x0
  pushl $9
c0101ffb:	6a 09                	push   $0x9
  jmp __alltraps
c0101ffd:	e9 1a 0a 00 00       	jmp    c0102a1c <__alltraps>

c0102002 <vector10>:
.globl vector10
vector10:
  pushl $10
c0102002:	6a 0a                	push   $0xa
  jmp __alltraps
c0102004:	e9 13 0a 00 00       	jmp    c0102a1c <__alltraps>

c0102009 <vector11>:
.globl vector11
vector11:
  pushl $11
c0102009:	6a 0b                	push   $0xb
  jmp __alltraps
c010200b:	e9 0c 0a 00 00       	jmp    c0102a1c <__alltraps>

c0102010 <vector12>:
.globl vector12
vector12:
  pushl $12
c0102010:	6a 0c                	push   $0xc
  jmp __alltraps
c0102012:	e9 05 0a 00 00       	jmp    c0102a1c <__alltraps>

c0102017 <vector13>:
.globl vector13
vector13:
  pushl $13
c0102017:	6a 0d                	push   $0xd
  jmp __alltraps
c0102019:	e9 fe 09 00 00       	jmp    c0102a1c <__alltraps>

c010201e <vector14>:
.globl vector14
vector14:
  pushl $14
c010201e:	6a 0e                	push   $0xe
  jmp __alltraps
c0102020:	e9 f7 09 00 00       	jmp    c0102a1c <__alltraps>

c0102025 <vector15>:
.globl vector15
vector15:
  pushl $0
c0102025:	6a 00                	push   $0x0
  pushl $15
c0102027:	6a 0f                	push   $0xf
  jmp __alltraps
c0102029:	e9 ee 09 00 00       	jmp    c0102a1c <__alltraps>

c010202e <vector16>:
.globl vector16
vector16:
  pushl $0
c010202e:	6a 00                	push   $0x0
  pushl $16
c0102030:	6a 10                	push   $0x10
  jmp __alltraps
c0102032:	e9 e5 09 00 00       	jmp    c0102a1c <__alltraps>

c0102037 <vector17>:
.globl vector17
vector17:
  pushl $17
c0102037:	6a 11                	push   $0x11
  jmp __alltraps
c0102039:	e9 de 09 00 00       	jmp    c0102a1c <__alltraps>

c010203e <vector18>:
.globl vector18
vector18:
  pushl $0
c010203e:	6a 00                	push   $0x0
  pushl $18
c0102040:	6a 12                	push   $0x12
  jmp __alltraps
c0102042:	e9 d5 09 00 00       	jmp    c0102a1c <__alltraps>

c0102047 <vector19>:
.globl vector19
vector19:
  pushl $0
c0102047:	6a 00                	push   $0x0
  pushl $19
c0102049:	6a 13                	push   $0x13
  jmp __alltraps
c010204b:	e9 cc 09 00 00       	jmp    c0102a1c <__alltraps>

c0102050 <vector20>:
.globl vector20
vector20:
  pushl $0
c0102050:	6a 00                	push   $0x0
  pushl $20
c0102052:	6a 14                	push   $0x14
  jmp __alltraps
c0102054:	e9 c3 09 00 00       	jmp    c0102a1c <__alltraps>

c0102059 <vector21>:
.globl vector21
vector21:
  pushl $0
c0102059:	6a 00                	push   $0x0
  pushl $21
c010205b:	6a 15                	push   $0x15
  jmp __alltraps
c010205d:	e9 ba 09 00 00       	jmp    c0102a1c <__alltraps>

c0102062 <vector22>:
.globl vector22
vector22:
  pushl $0
c0102062:	6a 00                	push   $0x0
  pushl $22
c0102064:	6a 16                	push   $0x16
  jmp __alltraps
c0102066:	e9 b1 09 00 00       	jmp    c0102a1c <__alltraps>

c010206b <vector23>:
.globl vector23
vector23:
  pushl $0
c010206b:	6a 00                	push   $0x0
  pushl $23
c010206d:	6a 17                	push   $0x17
  jmp __alltraps
c010206f:	e9 a8 09 00 00       	jmp    c0102a1c <__alltraps>

c0102074 <vector24>:
.globl vector24
vector24:
  pushl $0
c0102074:	6a 00                	push   $0x0
  pushl $24
c0102076:	6a 18                	push   $0x18
  jmp __alltraps
c0102078:	e9 9f 09 00 00       	jmp    c0102a1c <__alltraps>

c010207d <vector25>:
.globl vector25
vector25:
  pushl $0
c010207d:	6a 00                	push   $0x0
  pushl $25
c010207f:	6a 19                	push   $0x19
  jmp __alltraps
c0102081:	e9 96 09 00 00       	jmp    c0102a1c <__alltraps>

c0102086 <vector26>:
.globl vector26
vector26:
  pushl $0
c0102086:	6a 00                	push   $0x0
  pushl $26
c0102088:	6a 1a                	push   $0x1a
  jmp __alltraps
c010208a:	e9 8d 09 00 00       	jmp    c0102a1c <__alltraps>

c010208f <vector27>:
.globl vector27
vector27:
  pushl $0
c010208f:	6a 00                	push   $0x0
  pushl $27
c0102091:	6a 1b                	push   $0x1b
  jmp __alltraps
c0102093:	e9 84 09 00 00       	jmp    c0102a1c <__alltraps>

c0102098 <vector28>:
.globl vector28
vector28:
  pushl $0
c0102098:	6a 00                	push   $0x0
  pushl $28
c010209a:	6a 1c                	push   $0x1c
  jmp __alltraps
c010209c:	e9 7b 09 00 00       	jmp    c0102a1c <__alltraps>

c01020a1 <vector29>:
.globl vector29
vector29:
  pushl $0
c01020a1:	6a 00                	push   $0x0
  pushl $29
c01020a3:	6a 1d                	push   $0x1d
  jmp __alltraps
c01020a5:	e9 72 09 00 00       	jmp    c0102a1c <__alltraps>

c01020aa <vector30>:
.globl vector30
vector30:
  pushl $0
c01020aa:	6a 00                	push   $0x0
  pushl $30
c01020ac:	6a 1e                	push   $0x1e
  jmp __alltraps
c01020ae:	e9 69 09 00 00       	jmp    c0102a1c <__alltraps>

c01020b3 <vector31>:
.globl vector31
vector31:
  pushl $0
c01020b3:	6a 00                	push   $0x0
  pushl $31
c01020b5:	6a 1f                	push   $0x1f
  jmp __alltraps
c01020b7:	e9 60 09 00 00       	jmp    c0102a1c <__alltraps>

c01020bc <vector32>:
.globl vector32
vector32:
  pushl $0
c01020bc:	6a 00                	push   $0x0
  pushl $32
c01020be:	6a 20                	push   $0x20
  jmp __alltraps
c01020c0:	e9 57 09 00 00       	jmp    c0102a1c <__alltraps>

c01020c5 <vector33>:
.globl vector33
vector33:
  pushl $0
c01020c5:	6a 00                	push   $0x0
  pushl $33
c01020c7:	6a 21                	push   $0x21
  jmp __alltraps
c01020c9:	e9 4e 09 00 00       	jmp    c0102a1c <__alltraps>

c01020ce <vector34>:
.globl vector34
vector34:
  pushl $0
c01020ce:	6a 00                	push   $0x0
  pushl $34
c01020d0:	6a 22                	push   $0x22
  jmp __alltraps
c01020d2:	e9 45 09 00 00       	jmp    c0102a1c <__alltraps>

c01020d7 <vector35>:
.globl vector35
vector35:
  pushl $0
c01020d7:	6a 00                	push   $0x0
  pushl $35
c01020d9:	6a 23                	push   $0x23
  jmp __alltraps
c01020db:	e9 3c 09 00 00       	jmp    c0102a1c <__alltraps>

c01020e0 <vector36>:
.globl vector36
vector36:
  pushl $0
c01020e0:	6a 00                	push   $0x0
  pushl $36
c01020e2:	6a 24                	push   $0x24
  jmp __alltraps
c01020e4:	e9 33 09 00 00       	jmp    c0102a1c <__alltraps>

c01020e9 <vector37>:
.globl vector37
vector37:
  pushl $0
c01020e9:	6a 00                	push   $0x0
  pushl $37
c01020eb:	6a 25                	push   $0x25
  jmp __alltraps
c01020ed:	e9 2a 09 00 00       	jmp    c0102a1c <__alltraps>

c01020f2 <vector38>:
.globl vector38
vector38:
  pushl $0
c01020f2:	6a 00                	push   $0x0
  pushl $38
c01020f4:	6a 26                	push   $0x26
  jmp __alltraps
c01020f6:	e9 21 09 00 00       	jmp    c0102a1c <__alltraps>

c01020fb <vector39>:
.globl vector39
vector39:
  pushl $0
c01020fb:	6a 00                	push   $0x0
  pushl $39
c01020fd:	6a 27                	push   $0x27
  jmp __alltraps
c01020ff:	e9 18 09 00 00       	jmp    c0102a1c <__alltraps>

c0102104 <vector40>:
.globl vector40
vector40:
  pushl $0
c0102104:	6a 00                	push   $0x0
  pushl $40
c0102106:	6a 28                	push   $0x28
  jmp __alltraps
c0102108:	e9 0f 09 00 00       	jmp    c0102a1c <__alltraps>

c010210d <vector41>:
.globl vector41
vector41:
  pushl $0
c010210d:	6a 00                	push   $0x0
  pushl $41
c010210f:	6a 29                	push   $0x29
  jmp __alltraps
c0102111:	e9 06 09 00 00       	jmp    c0102a1c <__alltraps>

c0102116 <vector42>:
.globl vector42
vector42:
  pushl $0
c0102116:	6a 00                	push   $0x0
  pushl $42
c0102118:	6a 2a                	push   $0x2a
  jmp __alltraps
c010211a:	e9 fd 08 00 00       	jmp    c0102a1c <__alltraps>

c010211f <vector43>:
.globl vector43
vector43:
  pushl $0
c010211f:	6a 00                	push   $0x0
  pushl $43
c0102121:	6a 2b                	push   $0x2b
  jmp __alltraps
c0102123:	e9 f4 08 00 00       	jmp    c0102a1c <__alltraps>

c0102128 <vector44>:
.globl vector44
vector44:
  pushl $0
c0102128:	6a 00                	push   $0x0
  pushl $44
c010212a:	6a 2c                	push   $0x2c
  jmp __alltraps
c010212c:	e9 eb 08 00 00       	jmp    c0102a1c <__alltraps>

c0102131 <vector45>:
.globl vector45
vector45:
  pushl $0
c0102131:	6a 00                	push   $0x0
  pushl $45
c0102133:	6a 2d                	push   $0x2d
  jmp __alltraps
c0102135:	e9 e2 08 00 00       	jmp    c0102a1c <__alltraps>

c010213a <vector46>:
.globl vector46
vector46:
  pushl $0
c010213a:	6a 00                	push   $0x0
  pushl $46
c010213c:	6a 2e                	push   $0x2e
  jmp __alltraps
c010213e:	e9 d9 08 00 00       	jmp    c0102a1c <__alltraps>

c0102143 <vector47>:
.globl vector47
vector47:
  pushl $0
c0102143:	6a 00                	push   $0x0
  pushl $47
c0102145:	6a 2f                	push   $0x2f
  jmp __alltraps
c0102147:	e9 d0 08 00 00       	jmp    c0102a1c <__alltraps>

c010214c <vector48>:
.globl vector48
vector48:
  pushl $0
c010214c:	6a 00                	push   $0x0
  pushl $48
c010214e:	6a 30                	push   $0x30
  jmp __alltraps
c0102150:	e9 c7 08 00 00       	jmp    c0102a1c <__alltraps>

c0102155 <vector49>:
.globl vector49
vector49:
  pushl $0
c0102155:	6a 00                	push   $0x0
  pushl $49
c0102157:	6a 31                	push   $0x31
  jmp __alltraps
c0102159:	e9 be 08 00 00       	jmp    c0102a1c <__alltraps>

c010215e <vector50>:
.globl vector50
vector50:
  pushl $0
c010215e:	6a 00                	push   $0x0
  pushl $50
c0102160:	6a 32                	push   $0x32
  jmp __alltraps
c0102162:	e9 b5 08 00 00       	jmp    c0102a1c <__alltraps>

c0102167 <vector51>:
.globl vector51
vector51:
  pushl $0
c0102167:	6a 00                	push   $0x0
  pushl $51
c0102169:	6a 33                	push   $0x33
  jmp __alltraps
c010216b:	e9 ac 08 00 00       	jmp    c0102a1c <__alltraps>

c0102170 <vector52>:
.globl vector52
vector52:
  pushl $0
c0102170:	6a 00                	push   $0x0
  pushl $52
c0102172:	6a 34                	push   $0x34
  jmp __alltraps
c0102174:	e9 a3 08 00 00       	jmp    c0102a1c <__alltraps>

c0102179 <vector53>:
.globl vector53
vector53:
  pushl $0
c0102179:	6a 00                	push   $0x0
  pushl $53
c010217b:	6a 35                	push   $0x35
  jmp __alltraps
c010217d:	e9 9a 08 00 00       	jmp    c0102a1c <__alltraps>

c0102182 <vector54>:
.globl vector54
vector54:
  pushl $0
c0102182:	6a 00                	push   $0x0
  pushl $54
c0102184:	6a 36                	push   $0x36
  jmp __alltraps
c0102186:	e9 91 08 00 00       	jmp    c0102a1c <__alltraps>

c010218b <vector55>:
.globl vector55
vector55:
  pushl $0
c010218b:	6a 00                	push   $0x0
  pushl $55
c010218d:	6a 37                	push   $0x37
  jmp __alltraps
c010218f:	e9 88 08 00 00       	jmp    c0102a1c <__alltraps>

c0102194 <vector56>:
.globl vector56
vector56:
  pushl $0
c0102194:	6a 00                	push   $0x0
  pushl $56
c0102196:	6a 38                	push   $0x38
  jmp __alltraps
c0102198:	e9 7f 08 00 00       	jmp    c0102a1c <__alltraps>

c010219d <vector57>:
.globl vector57
vector57:
  pushl $0
c010219d:	6a 00                	push   $0x0
  pushl $57
c010219f:	6a 39                	push   $0x39
  jmp __alltraps
c01021a1:	e9 76 08 00 00       	jmp    c0102a1c <__alltraps>

c01021a6 <vector58>:
.globl vector58
vector58:
  pushl $0
c01021a6:	6a 00                	push   $0x0
  pushl $58
c01021a8:	6a 3a                	push   $0x3a
  jmp __alltraps
c01021aa:	e9 6d 08 00 00       	jmp    c0102a1c <__alltraps>

c01021af <vector59>:
.globl vector59
vector59:
  pushl $0
c01021af:	6a 00                	push   $0x0
  pushl $59
c01021b1:	6a 3b                	push   $0x3b
  jmp __alltraps
c01021b3:	e9 64 08 00 00       	jmp    c0102a1c <__alltraps>

c01021b8 <vector60>:
.globl vector60
vector60:
  pushl $0
c01021b8:	6a 00                	push   $0x0
  pushl $60
c01021ba:	6a 3c                	push   $0x3c
  jmp __alltraps
c01021bc:	e9 5b 08 00 00       	jmp    c0102a1c <__alltraps>

c01021c1 <vector61>:
.globl vector61
vector61:
  pushl $0
c01021c1:	6a 00                	push   $0x0
  pushl $61
c01021c3:	6a 3d                	push   $0x3d
  jmp __alltraps
c01021c5:	e9 52 08 00 00       	jmp    c0102a1c <__alltraps>

c01021ca <vector62>:
.globl vector62
vector62:
  pushl $0
c01021ca:	6a 00                	push   $0x0
  pushl $62
c01021cc:	6a 3e                	push   $0x3e
  jmp __alltraps
c01021ce:	e9 49 08 00 00       	jmp    c0102a1c <__alltraps>

c01021d3 <vector63>:
.globl vector63
vector63:
  pushl $0
c01021d3:	6a 00                	push   $0x0
  pushl $63
c01021d5:	6a 3f                	push   $0x3f
  jmp __alltraps
c01021d7:	e9 40 08 00 00       	jmp    c0102a1c <__alltraps>

c01021dc <vector64>:
.globl vector64
vector64:
  pushl $0
c01021dc:	6a 00                	push   $0x0
  pushl $64
c01021de:	6a 40                	push   $0x40
  jmp __alltraps
c01021e0:	e9 37 08 00 00       	jmp    c0102a1c <__alltraps>

c01021e5 <vector65>:
.globl vector65
vector65:
  pushl $0
c01021e5:	6a 00                	push   $0x0
  pushl $65
c01021e7:	6a 41                	push   $0x41
  jmp __alltraps
c01021e9:	e9 2e 08 00 00       	jmp    c0102a1c <__alltraps>

c01021ee <vector66>:
.globl vector66
vector66:
  pushl $0
c01021ee:	6a 00                	push   $0x0
  pushl $66
c01021f0:	6a 42                	push   $0x42
  jmp __alltraps
c01021f2:	e9 25 08 00 00       	jmp    c0102a1c <__alltraps>

c01021f7 <vector67>:
.globl vector67
vector67:
  pushl $0
c01021f7:	6a 00                	push   $0x0
  pushl $67
c01021f9:	6a 43                	push   $0x43
  jmp __alltraps
c01021fb:	e9 1c 08 00 00       	jmp    c0102a1c <__alltraps>

c0102200 <vector68>:
.globl vector68
vector68:
  pushl $0
c0102200:	6a 00                	push   $0x0
  pushl $68
c0102202:	6a 44                	push   $0x44
  jmp __alltraps
c0102204:	e9 13 08 00 00       	jmp    c0102a1c <__alltraps>

c0102209 <vector69>:
.globl vector69
vector69:
  pushl $0
c0102209:	6a 00                	push   $0x0
  pushl $69
c010220b:	6a 45                	push   $0x45
  jmp __alltraps
c010220d:	e9 0a 08 00 00       	jmp    c0102a1c <__alltraps>

c0102212 <vector70>:
.globl vector70
vector70:
  pushl $0
c0102212:	6a 00                	push   $0x0
  pushl $70
c0102214:	6a 46                	push   $0x46
  jmp __alltraps
c0102216:	e9 01 08 00 00       	jmp    c0102a1c <__alltraps>

c010221b <vector71>:
.globl vector71
vector71:
  pushl $0
c010221b:	6a 00                	push   $0x0
  pushl $71
c010221d:	6a 47                	push   $0x47
  jmp __alltraps
c010221f:	e9 f8 07 00 00       	jmp    c0102a1c <__alltraps>

c0102224 <vector72>:
.globl vector72
vector72:
  pushl $0
c0102224:	6a 00                	push   $0x0
  pushl $72
c0102226:	6a 48                	push   $0x48
  jmp __alltraps
c0102228:	e9 ef 07 00 00       	jmp    c0102a1c <__alltraps>

c010222d <vector73>:
.globl vector73
vector73:
  pushl $0
c010222d:	6a 00                	push   $0x0
  pushl $73
c010222f:	6a 49                	push   $0x49
  jmp __alltraps
c0102231:	e9 e6 07 00 00       	jmp    c0102a1c <__alltraps>

c0102236 <vector74>:
.globl vector74
vector74:
  pushl $0
c0102236:	6a 00                	push   $0x0
  pushl $74
c0102238:	6a 4a                	push   $0x4a
  jmp __alltraps
c010223a:	e9 dd 07 00 00       	jmp    c0102a1c <__alltraps>

c010223f <vector75>:
.globl vector75
vector75:
  pushl $0
c010223f:	6a 00                	push   $0x0
  pushl $75
c0102241:	6a 4b                	push   $0x4b
  jmp __alltraps
c0102243:	e9 d4 07 00 00       	jmp    c0102a1c <__alltraps>

c0102248 <vector76>:
.globl vector76
vector76:
  pushl $0
c0102248:	6a 00                	push   $0x0
  pushl $76
c010224a:	6a 4c                	push   $0x4c
  jmp __alltraps
c010224c:	e9 cb 07 00 00       	jmp    c0102a1c <__alltraps>

c0102251 <vector77>:
.globl vector77
vector77:
  pushl $0
c0102251:	6a 00                	push   $0x0
  pushl $77
c0102253:	6a 4d                	push   $0x4d
  jmp __alltraps
c0102255:	e9 c2 07 00 00       	jmp    c0102a1c <__alltraps>

c010225a <vector78>:
.globl vector78
vector78:
  pushl $0
c010225a:	6a 00                	push   $0x0
  pushl $78
c010225c:	6a 4e                	push   $0x4e
  jmp __alltraps
c010225e:	e9 b9 07 00 00       	jmp    c0102a1c <__alltraps>

c0102263 <vector79>:
.globl vector79
vector79:
  pushl $0
c0102263:	6a 00                	push   $0x0
  pushl $79
c0102265:	6a 4f                	push   $0x4f
  jmp __alltraps
c0102267:	e9 b0 07 00 00       	jmp    c0102a1c <__alltraps>

c010226c <vector80>:
.globl vector80
vector80:
  pushl $0
c010226c:	6a 00                	push   $0x0
  pushl $80
c010226e:	6a 50                	push   $0x50
  jmp __alltraps
c0102270:	e9 a7 07 00 00       	jmp    c0102a1c <__alltraps>

c0102275 <vector81>:
.globl vector81
vector81:
  pushl $0
c0102275:	6a 00                	push   $0x0
  pushl $81
c0102277:	6a 51                	push   $0x51
  jmp __alltraps
c0102279:	e9 9e 07 00 00       	jmp    c0102a1c <__alltraps>

c010227e <vector82>:
.globl vector82
vector82:
  pushl $0
c010227e:	6a 00                	push   $0x0
  pushl $82
c0102280:	6a 52                	push   $0x52
  jmp __alltraps
c0102282:	e9 95 07 00 00       	jmp    c0102a1c <__alltraps>

c0102287 <vector83>:
.globl vector83
vector83:
  pushl $0
c0102287:	6a 00                	push   $0x0
  pushl $83
c0102289:	6a 53                	push   $0x53
  jmp __alltraps
c010228b:	e9 8c 07 00 00       	jmp    c0102a1c <__alltraps>

c0102290 <vector84>:
.globl vector84
vector84:
  pushl $0
c0102290:	6a 00                	push   $0x0
  pushl $84
c0102292:	6a 54                	push   $0x54
  jmp __alltraps
c0102294:	e9 83 07 00 00       	jmp    c0102a1c <__alltraps>

c0102299 <vector85>:
.globl vector85
vector85:
  pushl $0
c0102299:	6a 00                	push   $0x0
  pushl $85
c010229b:	6a 55                	push   $0x55
  jmp __alltraps
c010229d:	e9 7a 07 00 00       	jmp    c0102a1c <__alltraps>

c01022a2 <vector86>:
.globl vector86
vector86:
  pushl $0
c01022a2:	6a 00                	push   $0x0
  pushl $86
c01022a4:	6a 56                	push   $0x56
  jmp __alltraps
c01022a6:	e9 71 07 00 00       	jmp    c0102a1c <__alltraps>

c01022ab <vector87>:
.globl vector87
vector87:
  pushl $0
c01022ab:	6a 00                	push   $0x0
  pushl $87
c01022ad:	6a 57                	push   $0x57
  jmp __alltraps
c01022af:	e9 68 07 00 00       	jmp    c0102a1c <__alltraps>

c01022b4 <vector88>:
.globl vector88
vector88:
  pushl $0
c01022b4:	6a 00                	push   $0x0
  pushl $88
c01022b6:	6a 58                	push   $0x58
  jmp __alltraps
c01022b8:	e9 5f 07 00 00       	jmp    c0102a1c <__alltraps>

c01022bd <vector89>:
.globl vector89
vector89:
  pushl $0
c01022bd:	6a 00                	push   $0x0
  pushl $89
c01022bf:	6a 59                	push   $0x59
  jmp __alltraps
c01022c1:	e9 56 07 00 00       	jmp    c0102a1c <__alltraps>

c01022c6 <vector90>:
.globl vector90
vector90:
  pushl $0
c01022c6:	6a 00                	push   $0x0
  pushl $90
c01022c8:	6a 5a                	push   $0x5a
  jmp __alltraps
c01022ca:	e9 4d 07 00 00       	jmp    c0102a1c <__alltraps>

c01022cf <vector91>:
.globl vector91
vector91:
  pushl $0
c01022cf:	6a 00                	push   $0x0
  pushl $91
c01022d1:	6a 5b                	push   $0x5b
  jmp __alltraps
c01022d3:	e9 44 07 00 00       	jmp    c0102a1c <__alltraps>

c01022d8 <vector92>:
.globl vector92
vector92:
  pushl $0
c01022d8:	6a 00                	push   $0x0
  pushl $92
c01022da:	6a 5c                	push   $0x5c
  jmp __alltraps
c01022dc:	e9 3b 07 00 00       	jmp    c0102a1c <__alltraps>

c01022e1 <vector93>:
.globl vector93
vector93:
  pushl $0
c01022e1:	6a 00                	push   $0x0
  pushl $93
c01022e3:	6a 5d                	push   $0x5d
  jmp __alltraps
c01022e5:	e9 32 07 00 00       	jmp    c0102a1c <__alltraps>

c01022ea <vector94>:
.globl vector94
vector94:
  pushl $0
c01022ea:	6a 00                	push   $0x0
  pushl $94
c01022ec:	6a 5e                	push   $0x5e
  jmp __alltraps
c01022ee:	e9 29 07 00 00       	jmp    c0102a1c <__alltraps>

c01022f3 <vector95>:
.globl vector95
vector95:
  pushl $0
c01022f3:	6a 00                	push   $0x0
  pushl $95
c01022f5:	6a 5f                	push   $0x5f
  jmp __alltraps
c01022f7:	e9 20 07 00 00       	jmp    c0102a1c <__alltraps>

c01022fc <vector96>:
.globl vector96
vector96:
  pushl $0
c01022fc:	6a 00                	push   $0x0
  pushl $96
c01022fe:	6a 60                	push   $0x60
  jmp __alltraps
c0102300:	e9 17 07 00 00       	jmp    c0102a1c <__alltraps>

c0102305 <vector97>:
.globl vector97
vector97:
  pushl $0
c0102305:	6a 00                	push   $0x0
  pushl $97
c0102307:	6a 61                	push   $0x61
  jmp __alltraps
c0102309:	e9 0e 07 00 00       	jmp    c0102a1c <__alltraps>

c010230e <vector98>:
.globl vector98
vector98:
  pushl $0
c010230e:	6a 00                	push   $0x0
  pushl $98
c0102310:	6a 62                	push   $0x62
  jmp __alltraps
c0102312:	e9 05 07 00 00       	jmp    c0102a1c <__alltraps>

c0102317 <vector99>:
.globl vector99
vector99:
  pushl $0
c0102317:	6a 00                	push   $0x0
  pushl $99
c0102319:	6a 63                	push   $0x63
  jmp __alltraps
c010231b:	e9 fc 06 00 00       	jmp    c0102a1c <__alltraps>

c0102320 <vector100>:
.globl vector100
vector100:
  pushl $0
c0102320:	6a 00                	push   $0x0
  pushl $100
c0102322:	6a 64                	push   $0x64
  jmp __alltraps
c0102324:	e9 f3 06 00 00       	jmp    c0102a1c <__alltraps>

c0102329 <vector101>:
.globl vector101
vector101:
  pushl $0
c0102329:	6a 00                	push   $0x0
  pushl $101
c010232b:	6a 65                	push   $0x65
  jmp __alltraps
c010232d:	e9 ea 06 00 00       	jmp    c0102a1c <__alltraps>

c0102332 <vector102>:
.globl vector102
vector102:
  pushl $0
c0102332:	6a 00                	push   $0x0
  pushl $102
c0102334:	6a 66                	push   $0x66
  jmp __alltraps
c0102336:	e9 e1 06 00 00       	jmp    c0102a1c <__alltraps>

c010233b <vector103>:
.globl vector103
vector103:
  pushl $0
c010233b:	6a 00                	push   $0x0
  pushl $103
c010233d:	6a 67                	push   $0x67
  jmp __alltraps
c010233f:	e9 d8 06 00 00       	jmp    c0102a1c <__alltraps>

c0102344 <vector104>:
.globl vector104
vector104:
  pushl $0
c0102344:	6a 00                	push   $0x0
  pushl $104
c0102346:	6a 68                	push   $0x68
  jmp __alltraps
c0102348:	e9 cf 06 00 00       	jmp    c0102a1c <__alltraps>

c010234d <vector105>:
.globl vector105
vector105:
  pushl $0
c010234d:	6a 00                	push   $0x0
  pushl $105
c010234f:	6a 69                	push   $0x69
  jmp __alltraps
c0102351:	e9 c6 06 00 00       	jmp    c0102a1c <__alltraps>

c0102356 <vector106>:
.globl vector106
vector106:
  pushl $0
c0102356:	6a 00                	push   $0x0
  pushl $106
c0102358:	6a 6a                	push   $0x6a
  jmp __alltraps
c010235a:	e9 bd 06 00 00       	jmp    c0102a1c <__alltraps>

c010235f <vector107>:
.globl vector107
vector107:
  pushl $0
c010235f:	6a 00                	push   $0x0
  pushl $107
c0102361:	6a 6b                	push   $0x6b
  jmp __alltraps
c0102363:	e9 b4 06 00 00       	jmp    c0102a1c <__alltraps>

c0102368 <vector108>:
.globl vector108
vector108:
  pushl $0
c0102368:	6a 00                	push   $0x0
  pushl $108
c010236a:	6a 6c                	push   $0x6c
  jmp __alltraps
c010236c:	e9 ab 06 00 00       	jmp    c0102a1c <__alltraps>

c0102371 <vector109>:
.globl vector109
vector109:
  pushl $0
c0102371:	6a 00                	push   $0x0
  pushl $109
c0102373:	6a 6d                	push   $0x6d
  jmp __alltraps
c0102375:	e9 a2 06 00 00       	jmp    c0102a1c <__alltraps>

c010237a <vector110>:
.globl vector110
vector110:
  pushl $0
c010237a:	6a 00                	push   $0x0
  pushl $110
c010237c:	6a 6e                	push   $0x6e
  jmp __alltraps
c010237e:	e9 99 06 00 00       	jmp    c0102a1c <__alltraps>

c0102383 <vector111>:
.globl vector111
vector111:
  pushl $0
c0102383:	6a 00                	push   $0x0
  pushl $111
c0102385:	6a 6f                	push   $0x6f
  jmp __alltraps
c0102387:	e9 90 06 00 00       	jmp    c0102a1c <__alltraps>

c010238c <vector112>:
.globl vector112
vector112:
  pushl $0
c010238c:	6a 00                	push   $0x0
  pushl $112
c010238e:	6a 70                	push   $0x70
  jmp __alltraps
c0102390:	e9 87 06 00 00       	jmp    c0102a1c <__alltraps>

c0102395 <vector113>:
.globl vector113
vector113:
  pushl $0
c0102395:	6a 00                	push   $0x0
  pushl $113
c0102397:	6a 71                	push   $0x71
  jmp __alltraps
c0102399:	e9 7e 06 00 00       	jmp    c0102a1c <__alltraps>

c010239e <vector114>:
.globl vector114
vector114:
  pushl $0
c010239e:	6a 00                	push   $0x0
  pushl $114
c01023a0:	6a 72                	push   $0x72
  jmp __alltraps
c01023a2:	e9 75 06 00 00       	jmp    c0102a1c <__alltraps>

c01023a7 <vector115>:
.globl vector115
vector115:
  pushl $0
c01023a7:	6a 00                	push   $0x0
  pushl $115
c01023a9:	6a 73                	push   $0x73
  jmp __alltraps
c01023ab:	e9 6c 06 00 00       	jmp    c0102a1c <__alltraps>

c01023b0 <vector116>:
.globl vector116
vector116:
  pushl $0
c01023b0:	6a 00                	push   $0x0
  pushl $116
c01023b2:	6a 74                	push   $0x74
  jmp __alltraps
c01023b4:	e9 63 06 00 00       	jmp    c0102a1c <__alltraps>

c01023b9 <vector117>:
.globl vector117
vector117:
  pushl $0
c01023b9:	6a 00                	push   $0x0
  pushl $117
c01023bb:	6a 75                	push   $0x75
  jmp __alltraps
c01023bd:	e9 5a 06 00 00       	jmp    c0102a1c <__alltraps>

c01023c2 <vector118>:
.globl vector118
vector118:
  pushl $0
c01023c2:	6a 00                	push   $0x0
  pushl $118
c01023c4:	6a 76                	push   $0x76
  jmp __alltraps
c01023c6:	e9 51 06 00 00       	jmp    c0102a1c <__alltraps>

c01023cb <vector119>:
.globl vector119
vector119:
  pushl $0
c01023cb:	6a 00                	push   $0x0
  pushl $119
c01023cd:	6a 77                	push   $0x77
  jmp __alltraps
c01023cf:	e9 48 06 00 00       	jmp    c0102a1c <__alltraps>

c01023d4 <vector120>:
.globl vector120
vector120:
  pushl $0
c01023d4:	6a 00                	push   $0x0
  pushl $120
c01023d6:	6a 78                	push   $0x78
  jmp __alltraps
c01023d8:	e9 3f 06 00 00       	jmp    c0102a1c <__alltraps>

c01023dd <vector121>:
.globl vector121
vector121:
  pushl $0
c01023dd:	6a 00                	push   $0x0
  pushl $121
c01023df:	6a 79                	push   $0x79
  jmp __alltraps
c01023e1:	e9 36 06 00 00       	jmp    c0102a1c <__alltraps>

c01023e6 <vector122>:
.globl vector122
vector122:
  pushl $0
c01023e6:	6a 00                	push   $0x0
  pushl $122
c01023e8:	6a 7a                	push   $0x7a
  jmp __alltraps
c01023ea:	e9 2d 06 00 00       	jmp    c0102a1c <__alltraps>

c01023ef <vector123>:
.globl vector123
vector123:
  pushl $0
c01023ef:	6a 00                	push   $0x0
  pushl $123
c01023f1:	6a 7b                	push   $0x7b
  jmp __alltraps
c01023f3:	e9 24 06 00 00       	jmp    c0102a1c <__alltraps>

c01023f8 <vector124>:
.globl vector124
vector124:
  pushl $0
c01023f8:	6a 00                	push   $0x0
  pushl $124
c01023fa:	6a 7c                	push   $0x7c
  jmp __alltraps
c01023fc:	e9 1b 06 00 00       	jmp    c0102a1c <__alltraps>

c0102401 <vector125>:
.globl vector125
vector125:
  pushl $0
c0102401:	6a 00                	push   $0x0
  pushl $125
c0102403:	6a 7d                	push   $0x7d
  jmp __alltraps
c0102405:	e9 12 06 00 00       	jmp    c0102a1c <__alltraps>

c010240a <vector126>:
.globl vector126
vector126:
  pushl $0
c010240a:	6a 00                	push   $0x0
  pushl $126
c010240c:	6a 7e                	push   $0x7e
  jmp __alltraps
c010240e:	e9 09 06 00 00       	jmp    c0102a1c <__alltraps>

c0102413 <vector127>:
.globl vector127
vector127:
  pushl $0
c0102413:	6a 00                	push   $0x0
  pushl $127
c0102415:	6a 7f                	push   $0x7f
  jmp __alltraps
c0102417:	e9 00 06 00 00       	jmp    c0102a1c <__alltraps>

c010241c <vector128>:
.globl vector128
vector128:
  pushl $0
c010241c:	6a 00                	push   $0x0
  pushl $128
c010241e:	68 80 00 00 00       	push   $0x80
  jmp __alltraps
c0102423:	e9 f4 05 00 00       	jmp    c0102a1c <__alltraps>

c0102428 <vector129>:
.globl vector129
vector129:
  pushl $0
c0102428:	6a 00                	push   $0x0
  pushl $129
c010242a:	68 81 00 00 00       	push   $0x81
  jmp __alltraps
c010242f:	e9 e8 05 00 00       	jmp    c0102a1c <__alltraps>

c0102434 <vector130>:
.globl vector130
vector130:
  pushl $0
c0102434:	6a 00                	push   $0x0
  pushl $130
c0102436:	68 82 00 00 00       	push   $0x82
  jmp __alltraps
c010243b:	e9 dc 05 00 00       	jmp    c0102a1c <__alltraps>

c0102440 <vector131>:
.globl vector131
vector131:
  pushl $0
c0102440:	6a 00                	push   $0x0
  pushl $131
c0102442:	68 83 00 00 00       	push   $0x83
  jmp __alltraps
c0102447:	e9 d0 05 00 00       	jmp    c0102a1c <__alltraps>

c010244c <vector132>:
.globl vector132
vector132:
  pushl $0
c010244c:	6a 00                	push   $0x0
  pushl $132
c010244e:	68 84 00 00 00       	push   $0x84
  jmp __alltraps
c0102453:	e9 c4 05 00 00       	jmp    c0102a1c <__alltraps>

c0102458 <vector133>:
.globl vector133
vector133:
  pushl $0
c0102458:	6a 00                	push   $0x0
  pushl $133
c010245a:	68 85 00 00 00       	push   $0x85
  jmp __alltraps
c010245f:	e9 b8 05 00 00       	jmp    c0102a1c <__alltraps>

c0102464 <vector134>:
.globl vector134
vector134:
  pushl $0
c0102464:	6a 00                	push   $0x0
  pushl $134
c0102466:	68 86 00 00 00       	push   $0x86
  jmp __alltraps
c010246b:	e9 ac 05 00 00       	jmp    c0102a1c <__alltraps>

c0102470 <vector135>:
.globl vector135
vector135:
  pushl $0
c0102470:	6a 00                	push   $0x0
  pushl $135
c0102472:	68 87 00 00 00       	push   $0x87
  jmp __alltraps
c0102477:	e9 a0 05 00 00       	jmp    c0102a1c <__alltraps>

c010247c <vector136>:
.globl vector136
vector136:
  pushl $0
c010247c:	6a 00                	push   $0x0
  pushl $136
c010247e:	68 88 00 00 00       	push   $0x88
  jmp __alltraps
c0102483:	e9 94 05 00 00       	jmp    c0102a1c <__alltraps>

c0102488 <vector137>:
.globl vector137
vector137:
  pushl $0
c0102488:	6a 00                	push   $0x0
  pushl $137
c010248a:	68 89 00 00 00       	push   $0x89
  jmp __alltraps
c010248f:	e9 88 05 00 00       	jmp    c0102a1c <__alltraps>

c0102494 <vector138>:
.globl vector138
vector138:
  pushl $0
c0102494:	6a 00                	push   $0x0
  pushl $138
c0102496:	68 8a 00 00 00       	push   $0x8a
  jmp __alltraps
c010249b:	e9 7c 05 00 00       	jmp    c0102a1c <__alltraps>

c01024a0 <vector139>:
.globl vector139
vector139:
  pushl $0
c01024a0:	6a 00                	push   $0x0
  pushl $139
c01024a2:	68 8b 00 00 00       	push   $0x8b
  jmp __alltraps
c01024a7:	e9 70 05 00 00       	jmp    c0102a1c <__alltraps>

c01024ac <vector140>:
.globl vector140
vector140:
  pushl $0
c01024ac:	6a 00                	push   $0x0
  pushl $140
c01024ae:	68 8c 00 00 00       	push   $0x8c
  jmp __alltraps
c01024b3:	e9 64 05 00 00       	jmp    c0102a1c <__alltraps>

c01024b8 <vector141>:
.globl vector141
vector141:
  pushl $0
c01024b8:	6a 00                	push   $0x0
  pushl $141
c01024ba:	68 8d 00 00 00       	push   $0x8d
  jmp __alltraps
c01024bf:	e9 58 05 00 00       	jmp    c0102a1c <__alltraps>

c01024c4 <vector142>:
.globl vector142
vector142:
  pushl $0
c01024c4:	6a 00                	push   $0x0
  pushl $142
c01024c6:	68 8e 00 00 00       	push   $0x8e
  jmp __alltraps
c01024cb:	e9 4c 05 00 00       	jmp    c0102a1c <__alltraps>

c01024d0 <vector143>:
.globl vector143
vector143:
  pushl $0
c01024d0:	6a 00                	push   $0x0
  pushl $143
c01024d2:	68 8f 00 00 00       	push   $0x8f
  jmp __alltraps
c01024d7:	e9 40 05 00 00       	jmp    c0102a1c <__alltraps>

c01024dc <vector144>:
.globl vector144
vector144:
  pushl $0
c01024dc:	6a 00                	push   $0x0
  pushl $144
c01024de:	68 90 00 00 00       	push   $0x90
  jmp __alltraps
c01024e3:	e9 34 05 00 00       	jmp    c0102a1c <__alltraps>

c01024e8 <vector145>:
.globl vector145
vector145:
  pushl $0
c01024e8:	6a 00                	push   $0x0
  pushl $145
c01024ea:	68 91 00 00 00       	push   $0x91
  jmp __alltraps
c01024ef:	e9 28 05 00 00       	jmp    c0102a1c <__alltraps>

c01024f4 <vector146>:
.globl vector146
vector146:
  pushl $0
c01024f4:	6a 00                	push   $0x0
  pushl $146
c01024f6:	68 92 00 00 00       	push   $0x92
  jmp __alltraps
c01024fb:	e9 1c 05 00 00       	jmp    c0102a1c <__alltraps>

c0102500 <vector147>:
.globl vector147
vector147:
  pushl $0
c0102500:	6a 00                	push   $0x0
  pushl $147
c0102502:	68 93 00 00 00       	push   $0x93
  jmp __alltraps
c0102507:	e9 10 05 00 00       	jmp    c0102a1c <__alltraps>

c010250c <vector148>:
.globl vector148
vector148:
  pushl $0
c010250c:	6a 00                	push   $0x0
  pushl $148
c010250e:	68 94 00 00 00       	push   $0x94
  jmp __alltraps
c0102513:	e9 04 05 00 00       	jmp    c0102a1c <__alltraps>

c0102518 <vector149>:
.globl vector149
vector149:
  pushl $0
c0102518:	6a 00                	push   $0x0
  pushl $149
c010251a:	68 95 00 00 00       	push   $0x95
  jmp __alltraps
c010251f:	e9 f8 04 00 00       	jmp    c0102a1c <__alltraps>

c0102524 <vector150>:
.globl vector150
vector150:
  pushl $0
c0102524:	6a 00                	push   $0x0
  pushl $150
c0102526:	68 96 00 00 00       	push   $0x96
  jmp __alltraps
c010252b:	e9 ec 04 00 00       	jmp    c0102a1c <__alltraps>

c0102530 <vector151>:
.globl vector151
vector151:
  pushl $0
c0102530:	6a 00                	push   $0x0
  pushl $151
c0102532:	68 97 00 00 00       	push   $0x97
  jmp __alltraps
c0102537:	e9 e0 04 00 00       	jmp    c0102a1c <__alltraps>

c010253c <vector152>:
.globl vector152
vector152:
  pushl $0
c010253c:	6a 00                	push   $0x0
  pushl $152
c010253e:	68 98 00 00 00       	push   $0x98
  jmp __alltraps
c0102543:	e9 d4 04 00 00       	jmp    c0102a1c <__alltraps>

c0102548 <vector153>:
.globl vector153
vector153:
  pushl $0
c0102548:	6a 00                	push   $0x0
  pushl $153
c010254a:	68 99 00 00 00       	push   $0x99
  jmp __alltraps
c010254f:	e9 c8 04 00 00       	jmp    c0102a1c <__alltraps>

c0102554 <vector154>:
.globl vector154
vector154:
  pushl $0
c0102554:	6a 00                	push   $0x0
  pushl $154
c0102556:	68 9a 00 00 00       	push   $0x9a
  jmp __alltraps
c010255b:	e9 bc 04 00 00       	jmp    c0102a1c <__alltraps>

c0102560 <vector155>:
.globl vector155
vector155:
  pushl $0
c0102560:	6a 00                	push   $0x0
  pushl $155
c0102562:	68 9b 00 00 00       	push   $0x9b
  jmp __alltraps
c0102567:	e9 b0 04 00 00       	jmp    c0102a1c <__alltraps>

c010256c <vector156>:
.globl vector156
vector156:
  pushl $0
c010256c:	6a 00                	push   $0x0
  pushl $156
c010256e:	68 9c 00 00 00       	push   $0x9c
  jmp __alltraps
c0102573:	e9 a4 04 00 00       	jmp    c0102a1c <__alltraps>

c0102578 <vector157>:
.globl vector157
vector157:
  pushl $0
c0102578:	6a 00                	push   $0x0
  pushl $157
c010257a:	68 9d 00 00 00       	push   $0x9d
  jmp __alltraps
c010257f:	e9 98 04 00 00       	jmp    c0102a1c <__alltraps>

c0102584 <vector158>:
.globl vector158
vector158:
  pushl $0
c0102584:	6a 00                	push   $0x0
  pushl $158
c0102586:	68 9e 00 00 00       	push   $0x9e
  jmp __alltraps
c010258b:	e9 8c 04 00 00       	jmp    c0102a1c <__alltraps>

c0102590 <vector159>:
.globl vector159
vector159:
  pushl $0
c0102590:	6a 00                	push   $0x0
  pushl $159
c0102592:	68 9f 00 00 00       	push   $0x9f
  jmp __alltraps
c0102597:	e9 80 04 00 00       	jmp    c0102a1c <__alltraps>

c010259c <vector160>:
.globl vector160
vector160:
  pushl $0
c010259c:	6a 00                	push   $0x0
  pushl $160
c010259e:	68 a0 00 00 00       	push   $0xa0
  jmp __alltraps
c01025a3:	e9 74 04 00 00       	jmp    c0102a1c <__alltraps>

c01025a8 <vector161>:
.globl vector161
vector161:
  pushl $0
c01025a8:	6a 00                	push   $0x0
  pushl $161
c01025aa:	68 a1 00 00 00       	push   $0xa1
  jmp __alltraps
c01025af:	e9 68 04 00 00       	jmp    c0102a1c <__alltraps>

c01025b4 <vector162>:
.globl vector162
vector162:
  pushl $0
c01025b4:	6a 00                	push   $0x0
  pushl $162
c01025b6:	68 a2 00 00 00       	push   $0xa2
  jmp __alltraps
c01025bb:	e9 5c 04 00 00       	jmp    c0102a1c <__alltraps>

c01025c0 <vector163>:
.globl vector163
vector163:
  pushl $0
c01025c0:	6a 00                	push   $0x0
  pushl $163
c01025c2:	68 a3 00 00 00       	push   $0xa3
  jmp __alltraps
c01025c7:	e9 50 04 00 00       	jmp    c0102a1c <__alltraps>

c01025cc <vector164>:
.globl vector164
vector164:
  pushl $0
c01025cc:	6a 00                	push   $0x0
  pushl $164
c01025ce:	68 a4 00 00 00       	push   $0xa4
  jmp __alltraps
c01025d3:	e9 44 04 00 00       	jmp    c0102a1c <__alltraps>

c01025d8 <vector165>:
.globl vector165
vector165:
  pushl $0
c01025d8:	6a 00                	push   $0x0
  pushl $165
c01025da:	68 a5 00 00 00       	push   $0xa5
  jmp __alltraps
c01025df:	e9 38 04 00 00       	jmp    c0102a1c <__alltraps>

c01025e4 <vector166>:
.globl vector166
vector166:
  pushl $0
c01025e4:	6a 00                	push   $0x0
  pushl $166
c01025e6:	68 a6 00 00 00       	push   $0xa6
  jmp __alltraps
c01025eb:	e9 2c 04 00 00       	jmp    c0102a1c <__alltraps>

c01025f0 <vector167>:
.globl vector167
vector167:
  pushl $0
c01025f0:	6a 00                	push   $0x0
  pushl $167
c01025f2:	68 a7 00 00 00       	push   $0xa7
  jmp __alltraps
c01025f7:	e9 20 04 00 00       	jmp    c0102a1c <__alltraps>

c01025fc <vector168>:
.globl vector168
vector168:
  pushl $0
c01025fc:	6a 00                	push   $0x0
  pushl $168
c01025fe:	68 a8 00 00 00       	push   $0xa8
  jmp __alltraps
c0102603:	e9 14 04 00 00       	jmp    c0102a1c <__alltraps>

c0102608 <vector169>:
.globl vector169
vector169:
  pushl $0
c0102608:	6a 00                	push   $0x0
  pushl $169
c010260a:	68 a9 00 00 00       	push   $0xa9
  jmp __alltraps
c010260f:	e9 08 04 00 00       	jmp    c0102a1c <__alltraps>

c0102614 <vector170>:
.globl vector170
vector170:
  pushl $0
c0102614:	6a 00                	push   $0x0
  pushl $170
c0102616:	68 aa 00 00 00       	push   $0xaa
  jmp __alltraps
c010261b:	e9 fc 03 00 00       	jmp    c0102a1c <__alltraps>

c0102620 <vector171>:
.globl vector171
vector171:
  pushl $0
c0102620:	6a 00                	push   $0x0
  pushl $171
c0102622:	68 ab 00 00 00       	push   $0xab
  jmp __alltraps
c0102627:	e9 f0 03 00 00       	jmp    c0102a1c <__alltraps>

c010262c <vector172>:
.globl vector172
vector172:
  pushl $0
c010262c:	6a 00                	push   $0x0
  pushl $172
c010262e:	68 ac 00 00 00       	push   $0xac
  jmp __alltraps
c0102633:	e9 e4 03 00 00       	jmp    c0102a1c <__alltraps>

c0102638 <vector173>:
.globl vector173
vector173:
  pushl $0
c0102638:	6a 00                	push   $0x0
  pushl $173
c010263a:	68 ad 00 00 00       	push   $0xad
  jmp __alltraps
c010263f:	e9 d8 03 00 00       	jmp    c0102a1c <__alltraps>

c0102644 <vector174>:
.globl vector174
vector174:
  pushl $0
c0102644:	6a 00                	push   $0x0
  pushl $174
c0102646:	68 ae 00 00 00       	push   $0xae
  jmp __alltraps
c010264b:	e9 cc 03 00 00       	jmp    c0102a1c <__alltraps>

c0102650 <vector175>:
.globl vector175
vector175:
  pushl $0
c0102650:	6a 00                	push   $0x0
  pushl $175
c0102652:	68 af 00 00 00       	push   $0xaf
  jmp __alltraps
c0102657:	e9 c0 03 00 00       	jmp    c0102a1c <__alltraps>

c010265c <vector176>:
.globl vector176
vector176:
  pushl $0
c010265c:	6a 00                	push   $0x0
  pushl $176
c010265e:	68 b0 00 00 00       	push   $0xb0
  jmp __alltraps
c0102663:	e9 b4 03 00 00       	jmp    c0102a1c <__alltraps>

c0102668 <vector177>:
.globl vector177
vector177:
  pushl $0
c0102668:	6a 00                	push   $0x0
  pushl $177
c010266a:	68 b1 00 00 00       	push   $0xb1
  jmp __alltraps
c010266f:	e9 a8 03 00 00       	jmp    c0102a1c <__alltraps>

c0102674 <vector178>:
.globl vector178
vector178:
  pushl $0
c0102674:	6a 00                	push   $0x0
  pushl $178
c0102676:	68 b2 00 00 00       	push   $0xb2
  jmp __alltraps
c010267b:	e9 9c 03 00 00       	jmp    c0102a1c <__alltraps>

c0102680 <vector179>:
.globl vector179
vector179:
  pushl $0
c0102680:	6a 00                	push   $0x0
  pushl $179
c0102682:	68 b3 00 00 00       	push   $0xb3
  jmp __alltraps
c0102687:	e9 90 03 00 00       	jmp    c0102a1c <__alltraps>

c010268c <vector180>:
.globl vector180
vector180:
  pushl $0
c010268c:	6a 00                	push   $0x0
  pushl $180
c010268e:	68 b4 00 00 00       	push   $0xb4
  jmp __alltraps
c0102693:	e9 84 03 00 00       	jmp    c0102a1c <__alltraps>

c0102698 <vector181>:
.globl vector181
vector181:
  pushl $0
c0102698:	6a 00                	push   $0x0
  pushl $181
c010269a:	68 b5 00 00 00       	push   $0xb5
  jmp __alltraps
c010269f:	e9 78 03 00 00       	jmp    c0102a1c <__alltraps>

c01026a4 <vector182>:
.globl vector182
vector182:
  pushl $0
c01026a4:	6a 00                	push   $0x0
  pushl $182
c01026a6:	68 b6 00 00 00       	push   $0xb6
  jmp __alltraps
c01026ab:	e9 6c 03 00 00       	jmp    c0102a1c <__alltraps>

c01026b0 <vector183>:
.globl vector183
vector183:
  pushl $0
c01026b0:	6a 00                	push   $0x0
  pushl $183
c01026b2:	68 b7 00 00 00       	push   $0xb7
  jmp __alltraps
c01026b7:	e9 60 03 00 00       	jmp    c0102a1c <__alltraps>

c01026bc <vector184>:
.globl vector184
vector184:
  pushl $0
c01026bc:	6a 00                	push   $0x0
  pushl $184
c01026be:	68 b8 00 00 00       	push   $0xb8
  jmp __alltraps
c01026c3:	e9 54 03 00 00       	jmp    c0102a1c <__alltraps>

c01026c8 <vector185>:
.globl vector185
vector185:
  pushl $0
c01026c8:	6a 00                	push   $0x0
  pushl $185
c01026ca:	68 b9 00 00 00       	push   $0xb9
  jmp __alltraps
c01026cf:	e9 48 03 00 00       	jmp    c0102a1c <__alltraps>

c01026d4 <vector186>:
.globl vector186
vector186:
  pushl $0
c01026d4:	6a 00                	push   $0x0
  pushl $186
c01026d6:	68 ba 00 00 00       	push   $0xba
  jmp __alltraps
c01026db:	e9 3c 03 00 00       	jmp    c0102a1c <__alltraps>

c01026e0 <vector187>:
.globl vector187
vector187:
  pushl $0
c01026e0:	6a 00                	push   $0x0
  pushl $187
c01026e2:	68 bb 00 00 00       	push   $0xbb
  jmp __alltraps
c01026e7:	e9 30 03 00 00       	jmp    c0102a1c <__alltraps>

c01026ec <vector188>:
.globl vector188
vector188:
  pushl $0
c01026ec:	6a 00                	push   $0x0
  pushl $188
c01026ee:	68 bc 00 00 00       	push   $0xbc
  jmp __alltraps
c01026f3:	e9 24 03 00 00       	jmp    c0102a1c <__alltraps>

c01026f8 <vector189>:
.globl vector189
vector189:
  pushl $0
c01026f8:	6a 00                	push   $0x0
  pushl $189
c01026fa:	68 bd 00 00 00       	push   $0xbd
  jmp __alltraps
c01026ff:	e9 18 03 00 00       	jmp    c0102a1c <__alltraps>

c0102704 <vector190>:
.globl vector190
vector190:
  pushl $0
c0102704:	6a 00                	push   $0x0
  pushl $190
c0102706:	68 be 00 00 00       	push   $0xbe
  jmp __alltraps
c010270b:	e9 0c 03 00 00       	jmp    c0102a1c <__alltraps>

c0102710 <vector191>:
.globl vector191
vector191:
  pushl $0
c0102710:	6a 00                	push   $0x0
  pushl $191
c0102712:	68 bf 00 00 00       	push   $0xbf
  jmp __alltraps
c0102717:	e9 00 03 00 00       	jmp    c0102a1c <__alltraps>

c010271c <vector192>:
.globl vector192
vector192:
  pushl $0
c010271c:	6a 00                	push   $0x0
  pushl $192
c010271e:	68 c0 00 00 00       	push   $0xc0
  jmp __alltraps
c0102723:	e9 f4 02 00 00       	jmp    c0102a1c <__alltraps>

c0102728 <vector193>:
.globl vector193
vector193:
  pushl $0
c0102728:	6a 00                	push   $0x0
  pushl $193
c010272a:	68 c1 00 00 00       	push   $0xc1
  jmp __alltraps
c010272f:	e9 e8 02 00 00       	jmp    c0102a1c <__alltraps>

c0102734 <vector194>:
.globl vector194
vector194:
  pushl $0
c0102734:	6a 00                	push   $0x0
  pushl $194
c0102736:	68 c2 00 00 00       	push   $0xc2
  jmp __alltraps
c010273b:	e9 dc 02 00 00       	jmp    c0102a1c <__alltraps>

c0102740 <vector195>:
.globl vector195
vector195:
  pushl $0
c0102740:	6a 00                	push   $0x0
  pushl $195
c0102742:	68 c3 00 00 00       	push   $0xc3
  jmp __alltraps
c0102747:	e9 d0 02 00 00       	jmp    c0102a1c <__alltraps>

c010274c <vector196>:
.globl vector196
vector196:
  pushl $0
c010274c:	6a 00                	push   $0x0
  pushl $196
c010274e:	68 c4 00 00 00       	push   $0xc4
  jmp __alltraps
c0102753:	e9 c4 02 00 00       	jmp    c0102a1c <__alltraps>

c0102758 <vector197>:
.globl vector197
vector197:
  pushl $0
c0102758:	6a 00                	push   $0x0
  pushl $197
c010275a:	68 c5 00 00 00       	push   $0xc5
  jmp __alltraps
c010275f:	e9 b8 02 00 00       	jmp    c0102a1c <__alltraps>

c0102764 <vector198>:
.globl vector198
vector198:
  pushl $0
c0102764:	6a 00                	push   $0x0
  pushl $198
c0102766:	68 c6 00 00 00       	push   $0xc6
  jmp __alltraps
c010276b:	e9 ac 02 00 00       	jmp    c0102a1c <__alltraps>

c0102770 <vector199>:
.globl vector199
vector199:
  pushl $0
c0102770:	6a 00                	push   $0x0
  pushl $199
c0102772:	68 c7 00 00 00       	push   $0xc7
  jmp __alltraps
c0102777:	e9 a0 02 00 00       	jmp    c0102a1c <__alltraps>

c010277c <vector200>:
.globl vector200
vector200:
  pushl $0
c010277c:	6a 00                	push   $0x0
  pushl $200
c010277e:	68 c8 00 00 00       	push   $0xc8
  jmp __alltraps
c0102783:	e9 94 02 00 00       	jmp    c0102a1c <__alltraps>

c0102788 <vector201>:
.globl vector201
vector201:
  pushl $0
c0102788:	6a 00                	push   $0x0
  pushl $201
c010278a:	68 c9 00 00 00       	push   $0xc9
  jmp __alltraps
c010278f:	e9 88 02 00 00       	jmp    c0102a1c <__alltraps>

c0102794 <vector202>:
.globl vector202
vector202:
  pushl $0
c0102794:	6a 00                	push   $0x0
  pushl $202
c0102796:	68 ca 00 00 00       	push   $0xca
  jmp __alltraps
c010279b:	e9 7c 02 00 00       	jmp    c0102a1c <__alltraps>

c01027a0 <vector203>:
.globl vector203
vector203:
  pushl $0
c01027a0:	6a 00                	push   $0x0
  pushl $203
c01027a2:	68 cb 00 00 00       	push   $0xcb
  jmp __alltraps
c01027a7:	e9 70 02 00 00       	jmp    c0102a1c <__alltraps>

c01027ac <vector204>:
.globl vector204
vector204:
  pushl $0
c01027ac:	6a 00                	push   $0x0
  pushl $204
c01027ae:	68 cc 00 00 00       	push   $0xcc
  jmp __alltraps
c01027b3:	e9 64 02 00 00       	jmp    c0102a1c <__alltraps>

c01027b8 <vector205>:
.globl vector205
vector205:
  pushl $0
c01027b8:	6a 00                	push   $0x0
  pushl $205
c01027ba:	68 cd 00 00 00       	push   $0xcd
  jmp __alltraps
c01027bf:	e9 58 02 00 00       	jmp    c0102a1c <__alltraps>

c01027c4 <vector206>:
.globl vector206
vector206:
  pushl $0
c01027c4:	6a 00                	push   $0x0
  pushl $206
c01027c6:	68 ce 00 00 00       	push   $0xce
  jmp __alltraps
c01027cb:	e9 4c 02 00 00       	jmp    c0102a1c <__alltraps>

c01027d0 <vector207>:
.globl vector207
vector207:
  pushl $0
c01027d0:	6a 00                	push   $0x0
  pushl $207
c01027d2:	68 cf 00 00 00       	push   $0xcf
  jmp __alltraps
c01027d7:	e9 40 02 00 00       	jmp    c0102a1c <__alltraps>

c01027dc <vector208>:
.globl vector208
vector208:
  pushl $0
c01027dc:	6a 00                	push   $0x0
  pushl $208
c01027de:	68 d0 00 00 00       	push   $0xd0
  jmp __alltraps
c01027e3:	e9 34 02 00 00       	jmp    c0102a1c <__alltraps>

c01027e8 <vector209>:
.globl vector209
vector209:
  pushl $0
c01027e8:	6a 00                	push   $0x0
  pushl $209
c01027ea:	68 d1 00 00 00       	push   $0xd1
  jmp __alltraps
c01027ef:	e9 28 02 00 00       	jmp    c0102a1c <__alltraps>

c01027f4 <vector210>:
.globl vector210
vector210:
  pushl $0
c01027f4:	6a 00                	push   $0x0
  pushl $210
c01027f6:	68 d2 00 00 00       	push   $0xd2
  jmp __alltraps
c01027fb:	e9 1c 02 00 00       	jmp    c0102a1c <__alltraps>

c0102800 <vector211>:
.globl vector211
vector211:
  pushl $0
c0102800:	6a 00                	push   $0x0
  pushl $211
c0102802:	68 d3 00 00 00       	push   $0xd3
  jmp __alltraps
c0102807:	e9 10 02 00 00       	jmp    c0102a1c <__alltraps>

c010280c <vector212>:
.globl vector212
vector212:
  pushl $0
c010280c:	6a 00                	push   $0x0
  pushl $212
c010280e:	68 d4 00 00 00       	push   $0xd4
  jmp __alltraps
c0102813:	e9 04 02 00 00       	jmp    c0102a1c <__alltraps>

c0102818 <vector213>:
.globl vector213
vector213:
  pushl $0
c0102818:	6a 00                	push   $0x0
  pushl $213
c010281a:	68 d5 00 00 00       	push   $0xd5
  jmp __alltraps
c010281f:	e9 f8 01 00 00       	jmp    c0102a1c <__alltraps>

c0102824 <vector214>:
.globl vector214
vector214:
  pushl $0
c0102824:	6a 00                	push   $0x0
  pushl $214
c0102826:	68 d6 00 00 00       	push   $0xd6
  jmp __alltraps
c010282b:	e9 ec 01 00 00       	jmp    c0102a1c <__alltraps>

c0102830 <vector215>:
.globl vector215
vector215:
  pushl $0
c0102830:	6a 00                	push   $0x0
  pushl $215
c0102832:	68 d7 00 00 00       	push   $0xd7
  jmp __alltraps
c0102837:	e9 e0 01 00 00       	jmp    c0102a1c <__alltraps>

c010283c <vector216>:
.globl vector216
vector216:
  pushl $0
c010283c:	6a 00                	push   $0x0
  pushl $216
c010283e:	68 d8 00 00 00       	push   $0xd8
  jmp __alltraps
c0102843:	e9 d4 01 00 00       	jmp    c0102a1c <__alltraps>

c0102848 <vector217>:
.globl vector217
vector217:
  pushl $0
c0102848:	6a 00                	push   $0x0
  pushl $217
c010284a:	68 d9 00 00 00       	push   $0xd9
  jmp __alltraps
c010284f:	e9 c8 01 00 00       	jmp    c0102a1c <__alltraps>

c0102854 <vector218>:
.globl vector218
vector218:
  pushl $0
c0102854:	6a 00                	push   $0x0
  pushl $218
c0102856:	68 da 00 00 00       	push   $0xda
  jmp __alltraps
c010285b:	e9 bc 01 00 00       	jmp    c0102a1c <__alltraps>

c0102860 <vector219>:
.globl vector219
vector219:
  pushl $0
c0102860:	6a 00                	push   $0x0
  pushl $219
c0102862:	68 db 00 00 00       	push   $0xdb
  jmp __alltraps
c0102867:	e9 b0 01 00 00       	jmp    c0102a1c <__alltraps>

c010286c <vector220>:
.globl vector220
vector220:
  pushl $0
c010286c:	6a 00                	push   $0x0
  pushl $220
c010286e:	68 dc 00 00 00       	push   $0xdc
  jmp __alltraps
c0102873:	e9 a4 01 00 00       	jmp    c0102a1c <__alltraps>

c0102878 <vector221>:
.globl vector221
vector221:
  pushl $0
c0102878:	6a 00                	push   $0x0
  pushl $221
c010287a:	68 dd 00 00 00       	push   $0xdd
  jmp __alltraps
c010287f:	e9 98 01 00 00       	jmp    c0102a1c <__alltraps>

c0102884 <vector222>:
.globl vector222
vector222:
  pushl $0
c0102884:	6a 00                	push   $0x0
  pushl $222
c0102886:	68 de 00 00 00       	push   $0xde
  jmp __alltraps
c010288b:	e9 8c 01 00 00       	jmp    c0102a1c <__alltraps>

c0102890 <vector223>:
.globl vector223
vector223:
  pushl $0
c0102890:	6a 00                	push   $0x0
  pushl $223
c0102892:	68 df 00 00 00       	push   $0xdf
  jmp __alltraps
c0102897:	e9 80 01 00 00       	jmp    c0102a1c <__alltraps>

c010289c <vector224>:
.globl vector224
vector224:
  pushl $0
c010289c:	6a 00                	push   $0x0
  pushl $224
c010289e:	68 e0 00 00 00       	push   $0xe0
  jmp __alltraps
c01028a3:	e9 74 01 00 00       	jmp    c0102a1c <__alltraps>

c01028a8 <vector225>:
.globl vector225
vector225:
  pushl $0
c01028a8:	6a 00                	push   $0x0
  pushl $225
c01028aa:	68 e1 00 00 00       	push   $0xe1
  jmp __alltraps
c01028af:	e9 68 01 00 00       	jmp    c0102a1c <__alltraps>

c01028b4 <vector226>:
.globl vector226
vector226:
  pushl $0
c01028b4:	6a 00                	push   $0x0
  pushl $226
c01028b6:	68 e2 00 00 00       	push   $0xe2
  jmp __alltraps
c01028bb:	e9 5c 01 00 00       	jmp    c0102a1c <__alltraps>

c01028c0 <vector227>:
.globl vector227
vector227:
  pushl $0
c01028c0:	6a 00                	push   $0x0
  pushl $227
c01028c2:	68 e3 00 00 00       	push   $0xe3
  jmp __alltraps
c01028c7:	e9 50 01 00 00       	jmp    c0102a1c <__alltraps>

c01028cc <vector228>:
.globl vector228
vector228:
  pushl $0
c01028cc:	6a 00                	push   $0x0
  pushl $228
c01028ce:	68 e4 00 00 00       	push   $0xe4
  jmp __alltraps
c01028d3:	e9 44 01 00 00       	jmp    c0102a1c <__alltraps>

c01028d8 <vector229>:
.globl vector229
vector229:
  pushl $0
c01028d8:	6a 00                	push   $0x0
  pushl $229
c01028da:	68 e5 00 00 00       	push   $0xe5
  jmp __alltraps
c01028df:	e9 38 01 00 00       	jmp    c0102a1c <__alltraps>

c01028e4 <vector230>:
.globl vector230
vector230:
  pushl $0
c01028e4:	6a 00                	push   $0x0
  pushl $230
c01028e6:	68 e6 00 00 00       	push   $0xe6
  jmp __alltraps
c01028eb:	e9 2c 01 00 00       	jmp    c0102a1c <__alltraps>

c01028f0 <vector231>:
.globl vector231
vector231:
  pushl $0
c01028f0:	6a 00                	push   $0x0
  pushl $231
c01028f2:	68 e7 00 00 00       	push   $0xe7
  jmp __alltraps
c01028f7:	e9 20 01 00 00       	jmp    c0102a1c <__alltraps>

c01028fc <vector232>:
.globl vector232
vector232:
  pushl $0
c01028fc:	6a 00                	push   $0x0
  pushl $232
c01028fe:	68 e8 00 00 00       	push   $0xe8
  jmp __alltraps
c0102903:	e9 14 01 00 00       	jmp    c0102a1c <__alltraps>

c0102908 <vector233>:
.globl vector233
vector233:
  pushl $0
c0102908:	6a 00                	push   $0x0
  pushl $233
c010290a:	68 e9 00 00 00       	push   $0xe9
  jmp __alltraps
c010290f:	e9 08 01 00 00       	jmp    c0102a1c <__alltraps>

c0102914 <vector234>:
.globl vector234
vector234:
  pushl $0
c0102914:	6a 00                	push   $0x0
  pushl $234
c0102916:	68 ea 00 00 00       	push   $0xea
  jmp __alltraps
c010291b:	e9 fc 00 00 00       	jmp    c0102a1c <__alltraps>

c0102920 <vector235>:
.globl vector235
vector235:
  pushl $0
c0102920:	6a 00                	push   $0x0
  pushl $235
c0102922:	68 eb 00 00 00       	push   $0xeb
  jmp __alltraps
c0102927:	e9 f0 00 00 00       	jmp    c0102a1c <__alltraps>

c010292c <vector236>:
.globl vector236
vector236:
  pushl $0
c010292c:	6a 00                	push   $0x0
  pushl $236
c010292e:	68 ec 00 00 00       	push   $0xec
  jmp __alltraps
c0102933:	e9 e4 00 00 00       	jmp    c0102a1c <__alltraps>

c0102938 <vector237>:
.globl vector237
vector237:
  pushl $0
c0102938:	6a 00                	push   $0x0
  pushl $237
c010293a:	68 ed 00 00 00       	push   $0xed
  jmp __alltraps
c010293f:	e9 d8 00 00 00       	jmp    c0102a1c <__alltraps>

c0102944 <vector238>:
.globl vector238
vector238:
  pushl $0
c0102944:	6a 00                	push   $0x0
  pushl $238
c0102946:	68 ee 00 00 00       	push   $0xee
  jmp __alltraps
c010294b:	e9 cc 00 00 00       	jmp    c0102a1c <__alltraps>

c0102950 <vector239>:
.globl vector239
vector239:
  pushl $0
c0102950:	6a 00                	push   $0x0
  pushl $239
c0102952:	68 ef 00 00 00       	push   $0xef
  jmp __alltraps
c0102957:	e9 c0 00 00 00       	jmp    c0102a1c <__alltraps>

c010295c <vector240>:
.globl vector240
vector240:
  pushl $0
c010295c:	6a 00                	push   $0x0
  pushl $240
c010295e:	68 f0 00 00 00       	push   $0xf0
  jmp __alltraps
c0102963:	e9 b4 00 00 00       	jmp    c0102a1c <__alltraps>

c0102968 <vector241>:
.globl vector241
vector241:
  pushl $0
c0102968:	6a 00                	push   $0x0
  pushl $241
c010296a:	68 f1 00 00 00       	push   $0xf1
  jmp __alltraps
c010296f:	e9 a8 00 00 00       	jmp    c0102a1c <__alltraps>

c0102974 <vector242>:
.globl vector242
vector242:
  pushl $0
c0102974:	6a 00                	push   $0x0
  pushl $242
c0102976:	68 f2 00 00 00       	push   $0xf2
  jmp __alltraps
c010297b:	e9 9c 00 00 00       	jmp    c0102a1c <__alltraps>

c0102980 <vector243>:
.globl vector243
vector243:
  pushl $0
c0102980:	6a 00                	push   $0x0
  pushl $243
c0102982:	68 f3 00 00 00       	push   $0xf3
  jmp __alltraps
c0102987:	e9 90 00 00 00       	jmp    c0102a1c <__alltraps>

c010298c <vector244>:
.globl vector244
vector244:
  pushl $0
c010298c:	6a 00                	push   $0x0
  pushl $244
c010298e:	68 f4 00 00 00       	push   $0xf4
  jmp __alltraps
c0102993:	e9 84 00 00 00       	jmp    c0102a1c <__alltraps>

c0102998 <vector245>:
.globl vector245
vector245:
  pushl $0
c0102998:	6a 00                	push   $0x0
  pushl $245
c010299a:	68 f5 00 00 00       	push   $0xf5
  jmp __alltraps
c010299f:	e9 78 00 00 00       	jmp    c0102a1c <__alltraps>

c01029a4 <vector246>:
.globl vector246
vector246:
  pushl $0
c01029a4:	6a 00                	push   $0x0
  pushl $246
c01029a6:	68 f6 00 00 00       	push   $0xf6
  jmp __alltraps
c01029ab:	e9 6c 00 00 00       	jmp    c0102a1c <__alltraps>

c01029b0 <vector247>:
.globl vector247
vector247:
  pushl $0
c01029b0:	6a 00                	push   $0x0
  pushl $247
c01029b2:	68 f7 00 00 00       	push   $0xf7
  jmp __alltraps
c01029b7:	e9 60 00 00 00       	jmp    c0102a1c <__alltraps>

c01029bc <vector248>:
.globl vector248
vector248:
  pushl $0
c01029bc:	6a 00                	push   $0x0
  pushl $248
c01029be:	68 f8 00 00 00       	push   $0xf8
  jmp __alltraps
c01029c3:	e9 54 00 00 00       	jmp    c0102a1c <__alltraps>

c01029c8 <vector249>:
.globl vector249
vector249:
  pushl $0
c01029c8:	6a 00                	push   $0x0
  pushl $249
c01029ca:	68 f9 00 00 00       	push   $0xf9
  jmp __alltraps
c01029cf:	e9 48 00 00 00       	jmp    c0102a1c <__alltraps>

c01029d4 <vector250>:
.globl vector250
vector250:
  pushl $0
c01029d4:	6a 00                	push   $0x0
  pushl $250
c01029d6:	68 fa 00 00 00       	push   $0xfa
  jmp __alltraps
c01029db:	e9 3c 00 00 00       	jmp    c0102a1c <__alltraps>

c01029e0 <vector251>:
.globl vector251
vector251:
  pushl $0
c01029e0:	6a 00                	push   $0x0
  pushl $251
c01029e2:	68 fb 00 00 00       	push   $0xfb
  jmp __alltraps
c01029e7:	e9 30 00 00 00       	jmp    c0102a1c <__alltraps>

c01029ec <vector252>:
.globl vector252
vector252:
  pushl $0
c01029ec:	6a 00                	push   $0x0
  pushl $252
c01029ee:	68 fc 00 00 00       	push   $0xfc
  jmp __alltraps
c01029f3:	e9 24 00 00 00       	jmp    c0102a1c <__alltraps>

c01029f8 <vector253>:
.globl vector253
vector253:
  pushl $0
c01029f8:	6a 00                	push   $0x0
  pushl $253
c01029fa:	68 fd 00 00 00       	push   $0xfd
  jmp __alltraps
c01029ff:	e9 18 00 00 00       	jmp    c0102a1c <__alltraps>

c0102a04 <vector254>:
.globl vector254
vector254:
  pushl $0
c0102a04:	6a 00                	push   $0x0
  pushl $254
c0102a06:	68 fe 00 00 00       	push   $0xfe
  jmp __alltraps
c0102a0b:	e9 0c 00 00 00       	jmp    c0102a1c <__alltraps>

c0102a10 <vector255>:
.globl vector255
vector255:
  pushl $0
c0102a10:	6a 00                	push   $0x0
  pushl $255
c0102a12:	68 ff 00 00 00       	push   $0xff
  jmp __alltraps
c0102a17:	e9 00 00 00 00       	jmp    c0102a1c <__alltraps>

c0102a1c <__alltraps>:
.text
.globl __alltraps
__alltraps:
    # push registers to build a trap frame
    # therefore make the stack look like a struct trapframe
    pushl %ds
c0102a1c:	1e                   	push   %ds
    pushl %es
c0102a1d:	06                   	push   %es
    pushl %fs
c0102a1e:	0f a0                	push   %fs
    pushl %gs
c0102a20:	0f a8                	push   %gs
    pushal
c0102a22:	60                   	pusha  

    # load GD_KDATA into %ds and %es to set up data segments for kernel
    movl $GD_KDATA, %eax
c0102a23:	b8 10 00 00 00       	mov    $0x10,%eax
    movw %ax, %ds
c0102a28:	8e d8                	mov    %eax,%ds
    movw %ax, %es
c0102a2a:	8e c0                	mov    %eax,%es

    # push %esp to pass a pointer to the trapframe as an argument to trap()
    pushl %esp
c0102a2c:	54                   	push   %esp

    # call trap(tf), where tf=%esp
    call trap
c0102a2d:	e8 64 f5 ff ff       	call   c0101f96 <trap>

    # pop the pushed stack pointer
    popl %esp
c0102a32:	5c                   	pop    %esp

c0102a33 <__trapret>:

    # return falls through to trapret...
.globl __trapret
__trapret:
    # restore registers from stack
    popal
c0102a33:	61                   	popa   

    # restore %ds, %es, %fs and %gs
    popl %gs
c0102a34:	0f a9                	pop    %gs
    popl %fs
c0102a36:	0f a1                	pop    %fs
    popl %es
c0102a38:	07                   	pop    %es
    popl %ds
c0102a39:	1f                   	pop    %ds

    # get rid of the trap number and error code
    addl $0x8, %esp
c0102a3a:	83 c4 08             	add    $0x8,%esp
    iret
c0102a3d:	cf                   	iret   

c0102a3e <page2ppn>:

extern struct Page *pages;
extern size_t npage;

static inline ppn_t
page2ppn(struct Page *page) {
c0102a3e:	55                   	push   %ebp
c0102a3f:	89 e5                	mov    %esp,%ebp
    return page - pages;
c0102a41:	8b 45 08             	mov    0x8(%ebp),%eax
c0102a44:	8b 15 78 bf 11 c0    	mov    0xc011bf78,%edx
c0102a4a:	29 d0                	sub    %edx,%eax
c0102a4c:	c1 f8 02             	sar    $0x2,%eax
c0102a4f:	69 c0 cd cc cc cc    	imul   $0xcccccccd,%eax,%eax
}
c0102a55:	5d                   	pop    %ebp
c0102a56:	c3                   	ret    

c0102a57 <page2pa>:

static inline uintptr_t
page2pa(struct Page *page) {
c0102a57:	55                   	push   %ebp
c0102a58:	89 e5                	mov    %esp,%ebp
c0102a5a:	83 ec 04             	sub    $0x4,%esp
    return page2ppn(page) << PGSHIFT;
c0102a5d:	8b 45 08             	mov    0x8(%ebp),%eax
c0102a60:	89 04 24             	mov    %eax,(%esp)
c0102a63:	e8 d6 ff ff ff       	call   c0102a3e <page2ppn>
c0102a68:	c1 e0 0c             	shl    $0xc,%eax
}
c0102a6b:	c9                   	leave  
c0102a6c:	c3                   	ret    

c0102a6d <pa2page>:

static inline struct Page *
pa2page(uintptr_t pa) {
c0102a6d:	55                   	push   %ebp
c0102a6e:	89 e5                	mov    %esp,%ebp
c0102a70:	83 ec 18             	sub    $0x18,%esp
    if (PPN(pa) >= npage) {
c0102a73:	8b 45 08             	mov    0x8(%ebp),%eax
c0102a76:	c1 e8 0c             	shr    $0xc,%eax
c0102a79:	89 c2                	mov    %eax,%edx
c0102a7b:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c0102a80:	39 c2                	cmp    %eax,%edx
c0102a82:	72 1c                	jb     c0102aa0 <pa2page+0x33>
        panic("pa2page called with invalid pa");
c0102a84:	c7 44 24 08 b0 68 10 	movl   $0xc01068b0,0x8(%esp)
c0102a8b:	c0 
c0102a8c:	c7 44 24 04 5b 00 00 	movl   $0x5b,0x4(%esp)
c0102a93:	00 
c0102a94:	c7 04 24 cf 68 10 c0 	movl   $0xc01068cf,(%esp)
c0102a9b:	e8 59 d9 ff ff       	call   c01003f9 <__panic>
    }
    return &pages[PPN(pa)];
c0102aa0:	8b 0d 78 bf 11 c0    	mov    0xc011bf78,%ecx
c0102aa6:	8b 45 08             	mov    0x8(%ebp),%eax
c0102aa9:	c1 e8 0c             	shr    $0xc,%eax
c0102aac:	89 c2                	mov    %eax,%edx
c0102aae:	89 d0                	mov    %edx,%eax
c0102ab0:	c1 e0 02             	shl    $0x2,%eax
c0102ab3:	01 d0                	add    %edx,%eax
c0102ab5:	c1 e0 02             	shl    $0x2,%eax
c0102ab8:	01 c8                	add    %ecx,%eax
}
c0102aba:	c9                   	leave  
c0102abb:	c3                   	ret    

c0102abc <page2kva>:

static inline void *
page2kva(struct Page *page) {
c0102abc:	55                   	push   %ebp
c0102abd:	89 e5                	mov    %esp,%ebp
c0102abf:	83 ec 28             	sub    $0x28,%esp
    return KADDR(page2pa(page));
c0102ac2:	8b 45 08             	mov    0x8(%ebp),%eax
c0102ac5:	89 04 24             	mov    %eax,(%esp)
c0102ac8:	e8 8a ff ff ff       	call   c0102a57 <page2pa>
c0102acd:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0102ad0:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0102ad3:	c1 e8 0c             	shr    $0xc,%eax
c0102ad6:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0102ad9:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c0102ade:	39 45 f0             	cmp    %eax,-0x10(%ebp)
c0102ae1:	72 23                	jb     c0102b06 <page2kva+0x4a>
c0102ae3:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0102ae6:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0102aea:	c7 44 24 08 e0 68 10 	movl   $0xc01068e0,0x8(%esp)
c0102af1:	c0 
c0102af2:	c7 44 24 04 62 00 00 	movl   $0x62,0x4(%esp)
c0102af9:	00 
c0102afa:	c7 04 24 cf 68 10 c0 	movl   $0xc01068cf,(%esp)
c0102b01:	e8 f3 d8 ff ff       	call   c01003f9 <__panic>
c0102b06:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0102b09:	2d 00 00 00 40       	sub    $0x40000000,%eax
}
c0102b0e:	c9                   	leave  
c0102b0f:	c3                   	ret    

c0102b10 <pte2page>:
kva2page(void *kva) {
    return pa2page(PADDR(kva));
}

static inline struct Page *
pte2page(pte_t pte) {
c0102b10:	55                   	push   %ebp
c0102b11:	89 e5                	mov    %esp,%ebp
c0102b13:	83 ec 18             	sub    $0x18,%esp
    if (!(pte & PTE_P)) {
c0102b16:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b19:	83 e0 01             	and    $0x1,%eax
c0102b1c:	85 c0                	test   %eax,%eax
c0102b1e:	75 1c                	jne    c0102b3c <pte2page+0x2c>
        panic("pte2page called with invalid pte");
c0102b20:	c7 44 24 08 04 69 10 	movl   $0xc0106904,0x8(%esp)
c0102b27:	c0 
c0102b28:	c7 44 24 04 6d 00 00 	movl   $0x6d,0x4(%esp)
c0102b2f:	00 
c0102b30:	c7 04 24 cf 68 10 c0 	movl   $0xc01068cf,(%esp)
c0102b37:	e8 bd d8 ff ff       	call   c01003f9 <__panic>
    }
    return pa2page(PTE_ADDR(pte));
c0102b3c:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b3f:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0102b44:	89 04 24             	mov    %eax,(%esp)
c0102b47:	e8 21 ff ff ff       	call   c0102a6d <pa2page>
}
c0102b4c:	c9                   	leave  
c0102b4d:	c3                   	ret    

c0102b4e <pde2page>:

static inline struct Page *
pde2page(pde_t pde) {
c0102b4e:	55                   	push   %ebp
c0102b4f:	89 e5                	mov    %esp,%ebp
c0102b51:	83 ec 18             	sub    $0x18,%esp
    return pa2page(PDE_ADDR(pde));
c0102b54:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b57:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0102b5c:	89 04 24             	mov    %eax,(%esp)
c0102b5f:	e8 09 ff ff ff       	call   c0102a6d <pa2page>
}
c0102b64:	c9                   	leave  
c0102b65:	c3                   	ret    

c0102b66 <page_ref>:

static inline int
page_ref(struct Page *page) {
c0102b66:	55                   	push   %ebp
c0102b67:	89 e5                	mov    %esp,%ebp
    return page->ref;
c0102b69:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b6c:	8b 00                	mov    (%eax),%eax
}
c0102b6e:	5d                   	pop    %ebp
c0102b6f:	c3                   	ret    

c0102b70 <set_page_ref>:

static inline void
set_page_ref(struct Page *page, int val) {
c0102b70:	55                   	push   %ebp
c0102b71:	89 e5                	mov    %esp,%ebp
    page->ref = val;
c0102b73:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b76:	8b 55 0c             	mov    0xc(%ebp),%edx
c0102b79:	89 10                	mov    %edx,(%eax)
}
c0102b7b:	90                   	nop
c0102b7c:	5d                   	pop    %ebp
c0102b7d:	c3                   	ret    

c0102b7e <page_ref_inc>:

static inline int
page_ref_inc(struct Page *page) {
c0102b7e:	55                   	push   %ebp
c0102b7f:	89 e5                	mov    %esp,%ebp
    page->ref += 1;
c0102b81:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b84:	8b 00                	mov    (%eax),%eax
c0102b86:	8d 50 01             	lea    0x1(%eax),%edx
c0102b89:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b8c:	89 10                	mov    %edx,(%eax)
    return page->ref;
c0102b8e:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b91:	8b 00                	mov    (%eax),%eax
}
c0102b93:	5d                   	pop    %ebp
c0102b94:	c3                   	ret    

c0102b95 <page_ref_dec>:

static inline int
page_ref_dec(struct Page *page) {
c0102b95:	55                   	push   %ebp
c0102b96:	89 e5                	mov    %esp,%ebp
    page->ref -= 1;
c0102b98:	8b 45 08             	mov    0x8(%ebp),%eax
c0102b9b:	8b 00                	mov    (%eax),%eax
c0102b9d:	8d 50 ff             	lea    -0x1(%eax),%edx
c0102ba0:	8b 45 08             	mov    0x8(%ebp),%eax
c0102ba3:	89 10                	mov    %edx,(%eax)
    return page->ref;
c0102ba5:	8b 45 08             	mov    0x8(%ebp),%eax
c0102ba8:	8b 00                	mov    (%eax),%eax
}
c0102baa:	5d                   	pop    %ebp
c0102bab:	c3                   	ret    

c0102bac <__intr_save>:
__intr_save(void) {
c0102bac:	55                   	push   %ebp
c0102bad:	89 e5                	mov    %esp,%ebp
c0102baf:	83 ec 18             	sub    $0x18,%esp
    asm volatile ("pushfl; popl %0" : "=r" (eflags));
c0102bb2:	9c                   	pushf  
c0102bb3:	58                   	pop    %eax
c0102bb4:	89 45 f4             	mov    %eax,-0xc(%ebp)
    return eflags;
c0102bb7:	8b 45 f4             	mov    -0xc(%ebp),%eax
    if (read_eflags() & FL_IF) {
c0102bba:	25 00 02 00 00       	and    $0x200,%eax
c0102bbf:	85 c0                	test   %eax,%eax
c0102bc1:	74 0c                	je     c0102bcf <__intr_save+0x23>
        intr_disable();
c0102bc3:	e8 d5 ec ff ff       	call   c010189d <intr_disable>
        return 1;
c0102bc8:	b8 01 00 00 00       	mov    $0x1,%eax
c0102bcd:	eb 05                	jmp    c0102bd4 <__intr_save+0x28>
    return 0;
c0102bcf:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0102bd4:	c9                   	leave  
c0102bd5:	c3                   	ret    

c0102bd6 <__intr_restore>:
__intr_restore(bool flag) {
c0102bd6:	55                   	push   %ebp
c0102bd7:	89 e5                	mov    %esp,%ebp
c0102bd9:	83 ec 08             	sub    $0x8,%esp
    if (flag) {
c0102bdc:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
c0102be0:	74 05                	je     c0102be7 <__intr_restore+0x11>
        intr_enable();
c0102be2:	e8 af ec ff ff       	call   c0101896 <intr_enable>
}
c0102be7:	90                   	nop
c0102be8:	c9                   	leave  
c0102be9:	c3                   	ret    

c0102bea <lgdt>:
/* *
 * lgdt - load the global descriptor table register and reset the
 * data/code segement registers for kernel.
 * */
static inline void
lgdt(struct pseudodesc *pd) {
c0102bea:	55                   	push   %ebp
c0102beb:	89 e5                	mov    %esp,%ebp
    asm volatile ("lgdt (%0)" :: "r" (pd));
c0102bed:	8b 45 08             	mov    0x8(%ebp),%eax
c0102bf0:	0f 01 10             	lgdtl  (%eax)
    asm volatile ("movw %%ax, %%gs" :: "a" (USER_DS));
c0102bf3:	b8 23 00 00 00       	mov    $0x23,%eax
c0102bf8:	8e e8                	mov    %eax,%gs
    asm volatile ("movw %%ax, %%fs" :: "a" (USER_DS));
c0102bfa:	b8 23 00 00 00       	mov    $0x23,%eax
c0102bff:	8e e0                	mov    %eax,%fs
    asm volatile ("movw %%ax, %%es" :: "a" (KERNEL_DS));
c0102c01:	b8 10 00 00 00       	mov    $0x10,%eax
c0102c06:	8e c0                	mov    %eax,%es
    asm volatile ("movw %%ax, %%ds" :: "a" (KERNEL_DS));
c0102c08:	b8 10 00 00 00       	mov    $0x10,%eax
c0102c0d:	8e d8                	mov    %eax,%ds
    asm volatile ("movw %%ax, %%ss" :: "a" (KERNEL_DS));
c0102c0f:	b8 10 00 00 00       	mov    $0x10,%eax
c0102c14:	8e d0                	mov    %eax,%ss
    // reload cs
    asm volatile ("ljmp %0, $1f\n 1:\n" :: "i" (KERNEL_CS));
c0102c16:	ea 1d 2c 10 c0 08 00 	ljmp   $0x8,$0xc0102c1d
}
c0102c1d:	90                   	nop
c0102c1e:	5d                   	pop    %ebp
c0102c1f:	c3                   	ret    

c0102c20 <load_esp0>:
 * load_esp0 - change the ESP0 in default task state segment,
 * so that we can use different kernel stack when we trap frame
 * user to kernel.
 * */
void
load_esp0(uintptr_t esp0) {
c0102c20:	55                   	push   %ebp
c0102c21:	89 e5                	mov    %esp,%ebp
    ts.ts_esp0 = esp0;
c0102c23:	8b 45 08             	mov    0x8(%ebp),%eax
c0102c26:	a3 a4 be 11 c0       	mov    %eax,0xc011bea4
}
c0102c2b:	90                   	nop
c0102c2c:	5d                   	pop    %ebp
c0102c2d:	c3                   	ret    

c0102c2e <gdt_init>:

/* gdt_init - initialize the default GDT and TSS */
static void
gdt_init(void) {
c0102c2e:	55                   	push   %ebp
c0102c2f:	89 e5                	mov    %esp,%ebp
c0102c31:	83 ec 14             	sub    $0x14,%esp
    // set boot kernel stack and default SS0
    load_esp0((uintptr_t)bootstacktop);
c0102c34:	b8 00 80 11 c0       	mov    $0xc0118000,%eax
c0102c39:	89 04 24             	mov    %eax,(%esp)
c0102c3c:	e8 df ff ff ff       	call   c0102c20 <load_esp0>
    ts.ts_ss0 = KERNEL_DS;
c0102c41:	66 c7 05 a8 be 11 c0 	movw   $0x10,0xc011bea8
c0102c48:	10 00 

    // initialize the TSS filed of the gdt
    gdt[SEG_TSS] = SEGTSS(STS_T32A, (uintptr_t)&ts, sizeof(ts), DPL_KERNEL);
c0102c4a:	66 c7 05 28 8a 11 c0 	movw   $0x68,0xc0118a28
c0102c51:	68 00 
c0102c53:	b8 a0 be 11 c0       	mov    $0xc011bea0,%eax
c0102c58:	0f b7 c0             	movzwl %ax,%eax
c0102c5b:	66 a3 2a 8a 11 c0    	mov    %ax,0xc0118a2a
c0102c61:	b8 a0 be 11 c0       	mov    $0xc011bea0,%eax
c0102c66:	c1 e8 10             	shr    $0x10,%eax
c0102c69:	a2 2c 8a 11 c0       	mov    %al,0xc0118a2c
c0102c6e:	0f b6 05 2d 8a 11 c0 	movzbl 0xc0118a2d,%eax
c0102c75:	24 f0                	and    $0xf0,%al
c0102c77:	0c 09                	or     $0x9,%al
c0102c79:	a2 2d 8a 11 c0       	mov    %al,0xc0118a2d
c0102c7e:	0f b6 05 2d 8a 11 c0 	movzbl 0xc0118a2d,%eax
c0102c85:	24 ef                	and    $0xef,%al
c0102c87:	a2 2d 8a 11 c0       	mov    %al,0xc0118a2d
c0102c8c:	0f b6 05 2d 8a 11 c0 	movzbl 0xc0118a2d,%eax
c0102c93:	24 9f                	and    $0x9f,%al
c0102c95:	a2 2d 8a 11 c0       	mov    %al,0xc0118a2d
c0102c9a:	0f b6 05 2d 8a 11 c0 	movzbl 0xc0118a2d,%eax
c0102ca1:	0c 80                	or     $0x80,%al
c0102ca3:	a2 2d 8a 11 c0       	mov    %al,0xc0118a2d
c0102ca8:	0f b6 05 2e 8a 11 c0 	movzbl 0xc0118a2e,%eax
c0102caf:	24 f0                	and    $0xf0,%al
c0102cb1:	a2 2e 8a 11 c0       	mov    %al,0xc0118a2e
c0102cb6:	0f b6 05 2e 8a 11 c0 	movzbl 0xc0118a2e,%eax
c0102cbd:	24 ef                	and    $0xef,%al
c0102cbf:	a2 2e 8a 11 c0       	mov    %al,0xc0118a2e
c0102cc4:	0f b6 05 2e 8a 11 c0 	movzbl 0xc0118a2e,%eax
c0102ccb:	24 df                	and    $0xdf,%al
c0102ccd:	a2 2e 8a 11 c0       	mov    %al,0xc0118a2e
c0102cd2:	0f b6 05 2e 8a 11 c0 	movzbl 0xc0118a2e,%eax
c0102cd9:	0c 40                	or     $0x40,%al
c0102cdb:	a2 2e 8a 11 c0       	mov    %al,0xc0118a2e
c0102ce0:	0f b6 05 2e 8a 11 c0 	movzbl 0xc0118a2e,%eax
c0102ce7:	24 7f                	and    $0x7f,%al
c0102ce9:	a2 2e 8a 11 c0       	mov    %al,0xc0118a2e
c0102cee:	b8 a0 be 11 c0       	mov    $0xc011bea0,%eax
c0102cf3:	c1 e8 18             	shr    $0x18,%eax
c0102cf6:	a2 2f 8a 11 c0       	mov    %al,0xc0118a2f

    // reload all segment registers
    lgdt(&gdt_pd);
c0102cfb:	c7 04 24 30 8a 11 c0 	movl   $0xc0118a30,(%esp)
c0102d02:	e8 e3 fe ff ff       	call   c0102bea <lgdt>
c0102d07:	66 c7 45 fe 28 00    	movw   $0x28,-0x2(%ebp)
    asm volatile ("ltr %0" :: "r" (sel) : "memory");
c0102d0d:	0f b7 45 fe          	movzwl -0x2(%ebp),%eax
c0102d11:	0f 00 d8             	ltr    %ax

    // load the TSS
    ltr(GD_TSS);
}
c0102d14:	90                   	nop
c0102d15:	c9                   	leave  
c0102d16:	c3                   	ret    

c0102d17 <init_pmm_manager>:

//init_pmm_manager - initialize a pmm_manager instance
static void
init_pmm_manager(void) {
c0102d17:	55                   	push   %ebp
c0102d18:	89 e5                	mov    %esp,%ebp
c0102d1a:	83 ec 18             	sub    $0x18,%esp
    pmm_manager = &default_pmm_manager;
c0102d1d:	c7 05 70 bf 11 c0 d8 	movl   $0xc01072d8,0xc011bf70
c0102d24:	72 10 c0 
    cprintf("memory management: %s\n", pmm_manager->name);
c0102d27:	a1 70 bf 11 c0       	mov    0xc011bf70,%eax
c0102d2c:	8b 00                	mov    (%eax),%eax
c0102d2e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0102d32:	c7 04 24 30 69 10 c0 	movl   $0xc0106930,(%esp)
c0102d39:	e8 64 d5 ff ff       	call   c01002a2 <cprintf>
    pmm_manager->init();
c0102d3e:	a1 70 bf 11 c0       	mov    0xc011bf70,%eax
c0102d43:	8b 40 04             	mov    0x4(%eax),%eax
c0102d46:	ff d0                	call   *%eax
}
c0102d48:	90                   	nop
c0102d49:	c9                   	leave  
c0102d4a:	c3                   	ret    

c0102d4b <init_memmap>:

//init_memmap - call pmm->init_memmap to build Page struct for free memory  
static void
init_memmap(struct Page *base, size_t n) {
c0102d4b:	55                   	push   %ebp
c0102d4c:	89 e5                	mov    %esp,%ebp
c0102d4e:	83 ec 18             	sub    $0x18,%esp
    pmm_manager->init_memmap(base, n);
c0102d51:	a1 70 bf 11 c0       	mov    0xc011bf70,%eax
c0102d56:	8b 40 08             	mov    0x8(%eax),%eax
c0102d59:	8b 55 0c             	mov    0xc(%ebp),%edx
c0102d5c:	89 54 24 04          	mov    %edx,0x4(%esp)
c0102d60:	8b 55 08             	mov    0x8(%ebp),%edx
c0102d63:	89 14 24             	mov    %edx,(%esp)
c0102d66:	ff d0                	call   *%eax
}
c0102d68:	90                   	nop
c0102d69:	c9                   	leave  
c0102d6a:	c3                   	ret    

c0102d6b <alloc_pages>:

//alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE memory 
struct Page *
alloc_pages(size_t n) {
c0102d6b:	55                   	push   %ebp
c0102d6c:	89 e5                	mov    %esp,%ebp
c0102d6e:	83 ec 28             	sub    $0x28,%esp
    struct Page *page=NULL;
c0102d71:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    bool intr_flag;
    local_intr_save(intr_flag);
c0102d78:	e8 2f fe ff ff       	call   c0102bac <__intr_save>
c0102d7d:	89 45 f0             	mov    %eax,-0x10(%ebp)
    {
        page = pmm_manager->alloc_pages(n);
c0102d80:	a1 70 bf 11 c0       	mov    0xc011bf70,%eax
c0102d85:	8b 40 0c             	mov    0xc(%eax),%eax
c0102d88:	8b 55 08             	mov    0x8(%ebp),%edx
c0102d8b:	89 14 24             	mov    %edx,(%esp)
c0102d8e:	ff d0                	call   *%eax
c0102d90:	89 45 f4             	mov    %eax,-0xc(%ebp)
    }
    local_intr_restore(intr_flag);
c0102d93:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0102d96:	89 04 24             	mov    %eax,(%esp)
c0102d99:	e8 38 fe ff ff       	call   c0102bd6 <__intr_restore>
    return page;
c0102d9e:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c0102da1:	c9                   	leave  
c0102da2:	c3                   	ret    

c0102da3 <free_pages>:

//free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory 
void
free_pages(struct Page *base, size_t n) {
c0102da3:	55                   	push   %ebp
c0102da4:	89 e5                	mov    %esp,%ebp
c0102da6:	83 ec 28             	sub    $0x28,%esp
    bool intr_flag;
    local_intr_save(intr_flag);
c0102da9:	e8 fe fd ff ff       	call   c0102bac <__intr_save>
c0102dae:	89 45 f4             	mov    %eax,-0xc(%ebp)
    {
        pmm_manager->free_pages(base, n);
c0102db1:	a1 70 bf 11 c0       	mov    0xc011bf70,%eax
c0102db6:	8b 40 10             	mov    0x10(%eax),%eax
c0102db9:	8b 55 0c             	mov    0xc(%ebp),%edx
c0102dbc:	89 54 24 04          	mov    %edx,0x4(%esp)
c0102dc0:	8b 55 08             	mov    0x8(%ebp),%edx
c0102dc3:	89 14 24             	mov    %edx,(%esp)
c0102dc6:	ff d0                	call   *%eax
    }
    local_intr_restore(intr_flag);
c0102dc8:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0102dcb:	89 04 24             	mov    %eax,(%esp)
c0102dce:	e8 03 fe ff ff       	call   c0102bd6 <__intr_restore>
}
c0102dd3:	90                   	nop
c0102dd4:	c9                   	leave  
c0102dd5:	c3                   	ret    

c0102dd6 <nr_free_pages>:

//nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE) 
//of current free memory
size_t
nr_free_pages(void) {
c0102dd6:	55                   	push   %ebp
c0102dd7:	89 e5                	mov    %esp,%ebp
c0102dd9:	83 ec 28             	sub    $0x28,%esp
    size_t ret;
    bool intr_flag;
    local_intr_save(intr_flag);
c0102ddc:	e8 cb fd ff ff       	call   c0102bac <__intr_save>
c0102de1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    {
        ret = pmm_manager->nr_free_pages();
c0102de4:	a1 70 bf 11 c0       	mov    0xc011bf70,%eax
c0102de9:	8b 40 14             	mov    0x14(%eax),%eax
c0102dec:	ff d0                	call   *%eax
c0102dee:	89 45 f0             	mov    %eax,-0x10(%ebp)
    }
    local_intr_restore(intr_flag);
c0102df1:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0102df4:	89 04 24             	mov    %eax,(%esp)
c0102df7:	e8 da fd ff ff       	call   c0102bd6 <__intr_restore>
    return ret;
c0102dfc:	8b 45 f0             	mov    -0x10(%ebp),%eax
}
c0102dff:	c9                   	leave  
c0102e00:	c3                   	ret    

c0102e01 <page_init>:

/* pmm_init - initialize the physical memory management */
//主要是完成了一个整体物理地址的初始化过程，包括设置标记位，探测物理内存布局等操作
//页初始化，交给了init_memmap函数处理。
static void
page_init(void) {
c0102e01:	55                   	push   %ebp
c0102e02:	89 e5                	mov    %esp,%ebp
c0102e04:	57                   	push   %edi
c0102e05:	56                   	push   %esi
c0102e06:	53                   	push   %ebx
c0102e07:	81 ec 9c 00 00 00    	sub    $0x9c,%esp
    struct e820map *memmap = (struct e820map *)(0x8000 + KERNBASE);
c0102e0d:	c7 45 c4 00 80 00 c0 	movl   $0xc0008000,-0x3c(%ebp)
    uint64_t maxpa = 0;
c0102e14:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
c0102e1b:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)

    cprintf("e820map:\n");
c0102e22:	c7 04 24 47 69 10 c0 	movl   $0xc0106947,(%esp)
c0102e29:	e8 74 d4 ff ff       	call   c01002a2 <cprintf>
    int i;
    for (i = 0; i < memmap->nr_map; i ++) {
c0102e2e:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
c0102e35:	e9 22 01 00 00       	jmp    c0102f5c <page_init+0x15b>
        uint64_t begin = memmap->map[i].addr, end = begin + memmap->map[i].size;
c0102e3a:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c0102e3d:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0102e40:	89 d0                	mov    %edx,%eax
c0102e42:	c1 e0 02             	shl    $0x2,%eax
c0102e45:	01 d0                	add    %edx,%eax
c0102e47:	c1 e0 02             	shl    $0x2,%eax
c0102e4a:	01 c8                	add    %ecx,%eax
c0102e4c:	8b 50 08             	mov    0x8(%eax),%edx
c0102e4f:	8b 40 04             	mov    0x4(%eax),%eax
c0102e52:	89 45 a0             	mov    %eax,-0x60(%ebp)
c0102e55:	89 55 a4             	mov    %edx,-0x5c(%ebp)
c0102e58:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c0102e5b:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0102e5e:	89 d0                	mov    %edx,%eax
c0102e60:	c1 e0 02             	shl    $0x2,%eax
c0102e63:	01 d0                	add    %edx,%eax
c0102e65:	c1 e0 02             	shl    $0x2,%eax
c0102e68:	01 c8                	add    %ecx,%eax
c0102e6a:	8b 48 0c             	mov    0xc(%eax),%ecx
c0102e6d:	8b 58 10             	mov    0x10(%eax),%ebx
c0102e70:	8b 45 a0             	mov    -0x60(%ebp),%eax
c0102e73:	8b 55 a4             	mov    -0x5c(%ebp),%edx
c0102e76:	01 c8                	add    %ecx,%eax
c0102e78:	11 da                	adc    %ebx,%edx
c0102e7a:	89 45 98             	mov    %eax,-0x68(%ebp)
c0102e7d:	89 55 9c             	mov    %edx,-0x64(%ebp)
        cprintf("  memory: %08llx, [%08llx, %08llx], type = %d.\n",
c0102e80:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c0102e83:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0102e86:	89 d0                	mov    %edx,%eax
c0102e88:	c1 e0 02             	shl    $0x2,%eax
c0102e8b:	01 d0                	add    %edx,%eax
c0102e8d:	c1 e0 02             	shl    $0x2,%eax
c0102e90:	01 c8                	add    %ecx,%eax
c0102e92:	83 c0 14             	add    $0x14,%eax
c0102e95:	8b 00                	mov    (%eax),%eax
c0102e97:	89 45 84             	mov    %eax,-0x7c(%ebp)
c0102e9a:	8b 45 98             	mov    -0x68(%ebp),%eax
c0102e9d:	8b 55 9c             	mov    -0x64(%ebp),%edx
c0102ea0:	83 c0 ff             	add    $0xffffffff,%eax
c0102ea3:	83 d2 ff             	adc    $0xffffffff,%edx
c0102ea6:	89 85 78 ff ff ff    	mov    %eax,-0x88(%ebp)
c0102eac:	89 95 7c ff ff ff    	mov    %edx,-0x84(%ebp)
c0102eb2:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c0102eb5:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0102eb8:	89 d0                	mov    %edx,%eax
c0102eba:	c1 e0 02             	shl    $0x2,%eax
c0102ebd:	01 d0                	add    %edx,%eax
c0102ebf:	c1 e0 02             	shl    $0x2,%eax
c0102ec2:	01 c8                	add    %ecx,%eax
c0102ec4:	8b 48 0c             	mov    0xc(%eax),%ecx
c0102ec7:	8b 58 10             	mov    0x10(%eax),%ebx
c0102eca:	8b 55 84             	mov    -0x7c(%ebp),%edx
c0102ecd:	89 54 24 1c          	mov    %edx,0x1c(%esp)
c0102ed1:	8b 85 78 ff ff ff    	mov    -0x88(%ebp),%eax
c0102ed7:	8b 95 7c ff ff ff    	mov    -0x84(%ebp),%edx
c0102edd:	89 44 24 14          	mov    %eax,0x14(%esp)
c0102ee1:	89 54 24 18          	mov    %edx,0x18(%esp)
c0102ee5:	8b 45 a0             	mov    -0x60(%ebp),%eax
c0102ee8:	8b 55 a4             	mov    -0x5c(%ebp),%edx
c0102eeb:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0102eef:	89 54 24 10          	mov    %edx,0x10(%esp)
c0102ef3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
c0102ef7:	89 5c 24 08          	mov    %ebx,0x8(%esp)
c0102efb:	c7 04 24 54 69 10 c0 	movl   $0xc0106954,(%esp)
c0102f02:	e8 9b d3 ff ff       	call   c01002a2 <cprintf>
                memmap->map[i].size, begin, end - 1, memmap->map[i].type);
        if (memmap->map[i].type == E820_ARM) {
c0102f07:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c0102f0a:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0102f0d:	89 d0                	mov    %edx,%eax
c0102f0f:	c1 e0 02             	shl    $0x2,%eax
c0102f12:	01 d0                	add    %edx,%eax
c0102f14:	c1 e0 02             	shl    $0x2,%eax
c0102f17:	01 c8                	add    %ecx,%eax
c0102f19:	83 c0 14             	add    $0x14,%eax
c0102f1c:	8b 00                	mov    (%eax),%eax
c0102f1e:	83 f8 01             	cmp    $0x1,%eax
c0102f21:	75 36                	jne    c0102f59 <page_init+0x158>
            if (maxpa < end && begin < KMEMSIZE) {
c0102f23:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0102f26:	8b 55 e4             	mov    -0x1c(%ebp),%edx
c0102f29:	3b 55 9c             	cmp    -0x64(%ebp),%edx
c0102f2c:	77 2b                	ja     c0102f59 <page_init+0x158>
c0102f2e:	3b 55 9c             	cmp    -0x64(%ebp),%edx
c0102f31:	72 05                	jb     c0102f38 <page_init+0x137>
c0102f33:	3b 45 98             	cmp    -0x68(%ebp),%eax
c0102f36:	73 21                	jae    c0102f59 <page_init+0x158>
c0102f38:	83 7d a4 00          	cmpl   $0x0,-0x5c(%ebp)
c0102f3c:	77 1b                	ja     c0102f59 <page_init+0x158>
c0102f3e:	83 7d a4 00          	cmpl   $0x0,-0x5c(%ebp)
c0102f42:	72 09                	jb     c0102f4d <page_init+0x14c>
c0102f44:	81 7d a0 ff ff ff 37 	cmpl   $0x37ffffff,-0x60(%ebp)
c0102f4b:	77 0c                	ja     c0102f59 <page_init+0x158>
                maxpa = end;
c0102f4d:	8b 45 98             	mov    -0x68(%ebp),%eax
c0102f50:	8b 55 9c             	mov    -0x64(%ebp),%edx
c0102f53:	89 45 e0             	mov    %eax,-0x20(%ebp)
c0102f56:	89 55 e4             	mov    %edx,-0x1c(%ebp)
    for (i = 0; i < memmap->nr_map; i ++) {
c0102f59:	ff 45 dc             	incl   -0x24(%ebp)
c0102f5c:	8b 45 c4             	mov    -0x3c(%ebp),%eax
c0102f5f:	8b 00                	mov    (%eax),%eax
c0102f61:	39 45 dc             	cmp    %eax,-0x24(%ebp)
c0102f64:	0f 8c d0 fe ff ff    	jl     c0102e3a <page_init+0x39>
            }
        }
    }
    if (maxpa > KMEMSIZE) {
c0102f6a:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
c0102f6e:	72 1d                	jb     c0102f8d <page_init+0x18c>
c0102f70:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
c0102f74:	77 09                	ja     c0102f7f <page_init+0x17e>
c0102f76:	81 7d e0 00 00 00 38 	cmpl   $0x38000000,-0x20(%ebp)
c0102f7d:	76 0e                	jbe    c0102f8d <page_init+0x18c>
        maxpa = KMEMSIZE;
c0102f7f:	c7 45 e0 00 00 00 38 	movl   $0x38000000,-0x20(%ebp)
c0102f86:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
    }

    extern char end[];

    npage = maxpa / PGSIZE; //需要管理的物理页个数为
c0102f8d:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0102f90:	8b 55 e4             	mov    -0x1c(%ebp),%edx
c0102f93:	0f ac d0 0c          	shrd   $0xc,%edx,%eax
c0102f97:	c1 ea 0c             	shr    $0xc,%edx
c0102f9a:	89 c1                	mov    %eax,%ecx
c0102f9c:	89 d3                	mov    %edx,%ebx
c0102f9e:	89 c8                	mov    %ecx,%eax
c0102fa0:	a3 80 be 11 c0       	mov    %eax,0xc011be80
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);  //由于bootloader加载ucore的结束地址（用全局指针变量end记录）
c0102fa5:	c7 45 c0 00 10 00 00 	movl   $0x1000,-0x40(%ebp)
c0102fac:	b8 88 bf 11 c0       	mov    $0xc011bf88,%eax
c0102fb1:	8d 50 ff             	lea    -0x1(%eax),%edx
c0102fb4:	8b 45 c0             	mov    -0x40(%ebp),%eax
c0102fb7:	01 d0                	add    %edx,%eax
c0102fb9:	89 45 bc             	mov    %eax,-0x44(%ebp)
c0102fbc:	8b 45 bc             	mov    -0x44(%ebp),%eax
c0102fbf:	ba 00 00 00 00       	mov    $0x0,%edx
c0102fc4:	f7 75 c0             	divl   -0x40(%ebp)
c0102fc7:	8b 45 bc             	mov    -0x44(%ebp),%eax
c0102fca:	29 d0                	sub    %edx,%eax
c0102fcc:	a3 78 bf 11 c0       	mov    %eax,0xc011bf78
                    //以上的空间没有被使用，所以我们可以把end按页大小为边界取整后，作为管理页级物理内存空间所需的Page结构的内存空间


    //首先，对于所有物理空间，通过如下语句即可实现占用标记
    for (i = 0; i < npage; i ++) {
c0102fd1:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
c0102fd8:	eb 2e                	jmp    c0103008 <page_init+0x207>
        SetPageReserved(pages + i);
c0102fda:	8b 0d 78 bf 11 c0    	mov    0xc011bf78,%ecx
c0102fe0:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0102fe3:	89 d0                	mov    %edx,%eax
c0102fe5:	c1 e0 02             	shl    $0x2,%eax
c0102fe8:	01 d0                	add    %edx,%eax
c0102fea:	c1 e0 02             	shl    $0x2,%eax
c0102fed:	01 c8                	add    %ecx,%eax
c0102fef:	83 c0 04             	add    $0x4,%eax
c0102ff2:	c7 45 94 00 00 00 00 	movl   $0x0,-0x6c(%ebp)
c0102ff9:	89 45 90             	mov    %eax,-0x70(%ebp)
 * Note that @nr may be almost arbitrarily large; this function is not
 * restricted to acting on a single-word quantity.
 * */
static inline void
set_bit(int nr, volatile void *addr) {
    asm volatile ("btsl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
c0102ffc:	8b 45 90             	mov    -0x70(%ebp),%eax
c0102fff:	8b 55 94             	mov    -0x6c(%ebp),%edx
c0103002:	0f ab 10             	bts    %edx,(%eax)
    for (i = 0; i < npage; i ++) {
c0103005:	ff 45 dc             	incl   -0x24(%ebp)
c0103008:	8b 55 dc             	mov    -0x24(%ebp),%edx
c010300b:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c0103010:	39 c2                	cmp    %eax,%edx
c0103012:	72 c6                	jb     c0102fda <page_init+0x1d9>
    }
    //SetPageReserved只需把物理地址对应的Page结构中的flags标志设置为PG_reserved ，表示这些页已经被使用了，将来不能被用于分配。

    //为了简化起见，从地址0到地址pages+ sizeof(struct Page) * npage)结束的物理内存空间设定为已占用物理内存空间
    //（起始0~640KB的空间是空闲的），地址pages+ sizeof(struct Page) * npage)以上的空间为空闲物理内存空间，这时的空闲空间起始地址为
    uintptr_t freemem = PADDR((uintptr_t)pages + sizeof(struct Page) * npage);
c0103014:	8b 15 80 be 11 c0    	mov    0xc011be80,%edx
c010301a:	89 d0                	mov    %edx,%eax
c010301c:	c1 e0 02             	shl    $0x2,%eax
c010301f:	01 d0                	add    %edx,%eax
c0103021:	c1 e0 02             	shl    $0x2,%eax
c0103024:	89 c2                	mov    %eax,%edx
c0103026:	a1 78 bf 11 c0       	mov    0xc011bf78,%eax
c010302b:	01 d0                	add    %edx,%eax
c010302d:	89 45 b8             	mov    %eax,-0x48(%ebp)
c0103030:	81 7d b8 ff ff ff bf 	cmpl   $0xbfffffff,-0x48(%ebp)
c0103037:	77 23                	ja     c010305c <page_init+0x25b>
c0103039:	8b 45 b8             	mov    -0x48(%ebp),%eax
c010303c:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0103040:	c7 44 24 08 84 69 10 	movl   $0xc0106984,0x8(%esp)
c0103047:	c0 
c0103048:	c7 44 24 04 e6 00 00 	movl   $0xe6,0x4(%esp)
c010304f:	00 
c0103050:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103057:	e8 9d d3 ff ff       	call   c01003f9 <__panic>
c010305c:	8b 45 b8             	mov    -0x48(%ebp),%eax
c010305f:	05 00 00 00 40       	add    $0x40000000,%eax
c0103064:	89 45 b4             	mov    %eax,-0x4c(%ebp)

    for (i = 0; i < memmap->nr_map; i ++) {
c0103067:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
c010306e:	e9 69 01 00 00       	jmp    c01031dc <page_init+0x3db>
        uint64_t begin = memmap->map[i].addr, end = begin + memmap->map[i].size;
c0103073:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c0103076:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0103079:	89 d0                	mov    %edx,%eax
c010307b:	c1 e0 02             	shl    $0x2,%eax
c010307e:	01 d0                	add    %edx,%eax
c0103080:	c1 e0 02             	shl    $0x2,%eax
c0103083:	01 c8                	add    %ecx,%eax
c0103085:	8b 50 08             	mov    0x8(%eax),%edx
c0103088:	8b 40 04             	mov    0x4(%eax),%eax
c010308b:	89 45 d0             	mov    %eax,-0x30(%ebp)
c010308e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
c0103091:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c0103094:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0103097:	89 d0                	mov    %edx,%eax
c0103099:	c1 e0 02             	shl    $0x2,%eax
c010309c:	01 d0                	add    %edx,%eax
c010309e:	c1 e0 02             	shl    $0x2,%eax
c01030a1:	01 c8                	add    %ecx,%eax
c01030a3:	8b 48 0c             	mov    0xc(%eax),%ecx
c01030a6:	8b 58 10             	mov    0x10(%eax),%ebx
c01030a9:	8b 45 d0             	mov    -0x30(%ebp),%eax
c01030ac:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c01030af:	01 c8                	add    %ecx,%eax
c01030b1:	11 da                	adc    %ebx,%edx
c01030b3:	89 45 c8             	mov    %eax,-0x38(%ebp)
c01030b6:	89 55 cc             	mov    %edx,-0x34(%ebp)
        if (memmap->map[i].type == E820_ARM) {//获得空闲空间的起始地址begin和结束地址end
c01030b9:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
c01030bc:	8b 55 dc             	mov    -0x24(%ebp),%edx
c01030bf:	89 d0                	mov    %edx,%eax
c01030c1:	c1 e0 02             	shl    $0x2,%eax
c01030c4:	01 d0                	add    %edx,%eax
c01030c6:	c1 e0 02             	shl    $0x2,%eax
c01030c9:	01 c8                	add    %ecx,%eax
c01030cb:	83 c0 14             	add    $0x14,%eax
c01030ce:	8b 00                	mov    (%eax),%eax
c01030d0:	83 f8 01             	cmp    $0x1,%eax
c01030d3:	0f 85 00 01 00 00    	jne    c01031d9 <page_init+0x3d8>
            if (begin < freemem) {
c01030d9:	8b 45 b4             	mov    -0x4c(%ebp),%eax
c01030dc:	ba 00 00 00 00       	mov    $0x0,%edx
c01030e1:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
c01030e4:	77 17                	ja     c01030fd <page_init+0x2fc>
c01030e6:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
c01030e9:	72 05                	jb     c01030f0 <page_init+0x2ef>
c01030eb:	39 45 d0             	cmp    %eax,-0x30(%ebp)
c01030ee:	73 0d                	jae    c01030fd <page_init+0x2fc>
                begin = freemem;
c01030f0:	8b 45 b4             	mov    -0x4c(%ebp),%eax
c01030f3:	89 45 d0             	mov    %eax,-0x30(%ebp)
c01030f6:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%ebp)
            }
            if (end > KMEMSIZE) {
c01030fd:	83 7d cc 00          	cmpl   $0x0,-0x34(%ebp)
c0103101:	72 1d                	jb     c0103120 <page_init+0x31f>
c0103103:	83 7d cc 00          	cmpl   $0x0,-0x34(%ebp)
c0103107:	77 09                	ja     c0103112 <page_init+0x311>
c0103109:	81 7d c8 00 00 00 38 	cmpl   $0x38000000,-0x38(%ebp)
c0103110:	76 0e                	jbe    c0103120 <page_init+0x31f>
                end = KMEMSIZE;
c0103112:	c7 45 c8 00 00 00 38 	movl   $0x38000000,-0x38(%ebp)
c0103119:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
            }
            if (begin < end) {
c0103120:	8b 45 d0             	mov    -0x30(%ebp),%eax
c0103123:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0103126:	3b 55 cc             	cmp    -0x34(%ebp),%edx
c0103129:	0f 87 aa 00 00 00    	ja     c01031d9 <page_init+0x3d8>
c010312f:	3b 55 cc             	cmp    -0x34(%ebp),%edx
c0103132:	72 09                	jb     c010313d <page_init+0x33c>
c0103134:	3b 45 c8             	cmp    -0x38(%ebp),%eax
c0103137:	0f 83 9c 00 00 00    	jae    c01031d9 <page_init+0x3d8>
                begin = ROUNDUP(begin, PGSIZE);
c010313d:	c7 45 b0 00 10 00 00 	movl   $0x1000,-0x50(%ebp)
c0103144:	8b 55 d0             	mov    -0x30(%ebp),%edx
c0103147:	8b 45 b0             	mov    -0x50(%ebp),%eax
c010314a:	01 d0                	add    %edx,%eax
c010314c:	48                   	dec    %eax
c010314d:	89 45 ac             	mov    %eax,-0x54(%ebp)
c0103150:	8b 45 ac             	mov    -0x54(%ebp),%eax
c0103153:	ba 00 00 00 00       	mov    $0x0,%edx
c0103158:	f7 75 b0             	divl   -0x50(%ebp)
c010315b:	8b 45 ac             	mov    -0x54(%ebp),%eax
c010315e:	29 d0                	sub    %edx,%eax
c0103160:	ba 00 00 00 00       	mov    $0x0,%edx
c0103165:	89 45 d0             	mov    %eax,-0x30(%ebp)
c0103168:	89 55 d4             	mov    %edx,-0x2c(%ebp)
                end = ROUNDDOWN(end, PGSIZE);
c010316b:	8b 45 c8             	mov    -0x38(%ebp),%eax
c010316e:	89 45 a8             	mov    %eax,-0x58(%ebp)
c0103171:	8b 45 a8             	mov    -0x58(%ebp),%eax
c0103174:	ba 00 00 00 00       	mov    $0x0,%edx
c0103179:	89 c3                	mov    %eax,%ebx
c010317b:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
c0103181:	89 de                	mov    %ebx,%esi
c0103183:	89 d0                	mov    %edx,%eax
c0103185:	83 e0 00             	and    $0x0,%eax
c0103188:	89 c7                	mov    %eax,%edi
c010318a:	89 75 c8             	mov    %esi,-0x38(%ebp)
c010318d:	89 7d cc             	mov    %edi,-0x34(%ebp)
                if (begin < end) {
c0103190:	8b 45 d0             	mov    -0x30(%ebp),%eax
c0103193:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0103196:	3b 55 cc             	cmp    -0x34(%ebp),%edx
c0103199:	77 3e                	ja     c01031d9 <page_init+0x3d8>
c010319b:	3b 55 cc             	cmp    -0x34(%ebp),%edx
c010319e:	72 05                	jb     c01031a5 <page_init+0x3a4>
c01031a0:	3b 45 c8             	cmp    -0x38(%ebp),%eax
c01031a3:	73 34                	jae    c01031d9 <page_init+0x3d8>
                    //然后，根据探测到的空闲物理空间，通过如下语句即可实现空闲标记：
                    init_memmap(pa2page(begin), (end - begin) / PGSIZE);
c01031a5:	8b 45 c8             	mov    -0x38(%ebp),%eax
c01031a8:	8b 55 cc             	mov    -0x34(%ebp),%edx
c01031ab:	2b 45 d0             	sub    -0x30(%ebp),%eax
c01031ae:	1b 55 d4             	sbb    -0x2c(%ebp),%edx
c01031b1:	89 c1                	mov    %eax,%ecx
c01031b3:	89 d3                	mov    %edx,%ebx
c01031b5:	89 c8                	mov    %ecx,%eax
c01031b7:	89 da                	mov    %ebx,%edx
c01031b9:	0f ac d0 0c          	shrd   $0xc,%edx,%eax
c01031bd:	c1 ea 0c             	shr    $0xc,%edx
c01031c0:	89 c3                	mov    %eax,%ebx
c01031c2:	8b 45 d0             	mov    -0x30(%ebp),%eax
c01031c5:	89 04 24             	mov    %eax,(%esp)
c01031c8:	e8 a0 f8 ff ff       	call   c0102a6d <pa2page>
c01031cd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c01031d1:	89 04 24             	mov    %eax,(%esp)
c01031d4:	e8 72 fb ff ff       	call   c0102d4b <init_memmap>
    for (i = 0; i < memmap->nr_map; i ++) {
c01031d9:	ff 45 dc             	incl   -0x24(%ebp)
c01031dc:	8b 45 c4             	mov    -0x3c(%ebp),%eax
c01031df:	8b 00                	mov    (%eax),%eax
c01031e1:	39 45 dc             	cmp    %eax,-0x24(%ebp)
c01031e4:	0f 8c 89 fe ff ff    	jl     c0103073 <page_init+0x272>
                    //init_memmap函数则是把空闲物理页对应的Page结构中的flags和引用计数ref清零，并加到free_area.free_list指向的双向列表中，为将来的空闲页管理做好初始化准备工作。
                }
            }
        }
    }
}
c01031ea:	90                   	nop
c01031eb:	81 c4 9c 00 00 00    	add    $0x9c,%esp
c01031f1:	5b                   	pop    %ebx
c01031f2:	5e                   	pop    %esi
c01031f3:	5f                   	pop    %edi
c01031f4:	5d                   	pop    %ebp
c01031f5:	c3                   	ret    

c01031f6 <boot_map_segment>:
//  size: memory size
//  pa:   physical address of this memory
//  perm: permission of this memory  
//完成页表和页表项建立
static void
boot_map_segment(pde_t *pgdir, uintptr_t la, size_t size, uintptr_t pa, uint32_t perm) {
c01031f6:	55                   	push   %ebp
c01031f7:	89 e5                	mov    %esp,%ebp
c01031f9:	83 ec 38             	sub    $0x38,%esp
    assert(PGOFF(la) == PGOFF(pa));
c01031fc:	8b 45 0c             	mov    0xc(%ebp),%eax
c01031ff:	33 45 14             	xor    0x14(%ebp),%eax
c0103202:	25 ff 0f 00 00       	and    $0xfff,%eax
c0103207:	85 c0                	test   %eax,%eax
c0103209:	74 24                	je     c010322f <boot_map_segment+0x39>
c010320b:	c7 44 24 0c b6 69 10 	movl   $0xc01069b6,0xc(%esp)
c0103212:	c0 
c0103213:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c010321a:	c0 
c010321b:	c7 44 24 04 07 01 00 	movl   $0x107,0x4(%esp)
c0103222:	00 
c0103223:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c010322a:	e8 ca d1 ff ff       	call   c01003f9 <__panic>
    size_t n = ROUNDUP(size + PGOFF(la), PGSIZE) / PGSIZE;
c010322f:	c7 45 f0 00 10 00 00 	movl   $0x1000,-0x10(%ebp)
c0103236:	8b 45 0c             	mov    0xc(%ebp),%eax
c0103239:	25 ff 0f 00 00       	and    $0xfff,%eax
c010323e:	89 c2                	mov    %eax,%edx
c0103240:	8b 45 10             	mov    0x10(%ebp),%eax
c0103243:	01 c2                	add    %eax,%edx
c0103245:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103248:	01 d0                	add    %edx,%eax
c010324a:	48                   	dec    %eax
c010324b:	89 45 ec             	mov    %eax,-0x14(%ebp)
c010324e:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0103251:	ba 00 00 00 00       	mov    $0x0,%edx
c0103256:	f7 75 f0             	divl   -0x10(%ebp)
c0103259:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010325c:	29 d0                	sub    %edx,%eax
c010325e:	c1 e8 0c             	shr    $0xc,%eax
c0103261:	89 45 f4             	mov    %eax,-0xc(%ebp)
    la = ROUNDDOWN(la, PGSIZE);
c0103264:	8b 45 0c             	mov    0xc(%ebp),%eax
c0103267:	89 45 e8             	mov    %eax,-0x18(%ebp)
c010326a:	8b 45 e8             	mov    -0x18(%ebp),%eax
c010326d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0103272:	89 45 0c             	mov    %eax,0xc(%ebp)
    pa = ROUNDDOWN(pa, PGSIZE);
c0103275:	8b 45 14             	mov    0x14(%ebp),%eax
c0103278:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c010327b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c010327e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0103283:	89 45 14             	mov    %eax,0x14(%ebp)
    for (; n > 0; n --, la += PGSIZE, pa += PGSIZE) {
c0103286:	eb 68                	jmp    c01032f0 <boot_map_segment+0xfa>
        pte_t *ptep = get_pte(pgdir, la, 1);
c0103288:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
c010328f:	00 
c0103290:	8b 45 0c             	mov    0xc(%ebp),%eax
c0103293:	89 44 24 04          	mov    %eax,0x4(%esp)
c0103297:	8b 45 08             	mov    0x8(%ebp),%eax
c010329a:	89 04 24             	mov    %eax,(%esp)
c010329d:	e8 81 01 00 00       	call   c0103423 <get_pte>
c01032a2:	89 45 e0             	mov    %eax,-0x20(%ebp)
        assert(ptep != NULL);
c01032a5:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
c01032a9:	75 24                	jne    c01032cf <boot_map_segment+0xd9>
c01032ab:	c7 44 24 0c e2 69 10 	movl   $0xc01069e2,0xc(%esp)
c01032b2:	c0 
c01032b3:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c01032ba:	c0 
c01032bb:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
c01032c2:	00 
c01032c3:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01032ca:	e8 2a d1 ff ff       	call   c01003f9 <__panic>
        *ptep = pa | PTE_P | perm;
c01032cf:	8b 45 14             	mov    0x14(%ebp),%eax
c01032d2:	0b 45 18             	or     0x18(%ebp),%eax
c01032d5:	83 c8 01             	or     $0x1,%eax
c01032d8:	89 c2                	mov    %eax,%edx
c01032da:	8b 45 e0             	mov    -0x20(%ebp),%eax
c01032dd:	89 10                	mov    %edx,(%eax)
    for (; n > 0; n --, la += PGSIZE, pa += PGSIZE) {
c01032df:	ff 4d f4             	decl   -0xc(%ebp)
c01032e2:	81 45 0c 00 10 00 00 	addl   $0x1000,0xc(%ebp)
c01032e9:	81 45 14 00 10 00 00 	addl   $0x1000,0x14(%ebp)
c01032f0:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c01032f4:	75 92                	jne    c0103288 <boot_map_segment+0x92>
    }
}
c01032f6:	90                   	nop
c01032f7:	c9                   	leave  
c01032f8:	c3                   	ret    

c01032f9 <boot_alloc_page>:

//boot_alloc_page - allocate one page using pmm->alloc_pages(1) 
// return value: the kernel virtual address of this allocated page
//note: this function is used to get the memory for PDT(Page Directory Table)&PT(Page Table)
static void *
boot_alloc_page(void) {
c01032f9:	55                   	push   %ebp
c01032fa:	89 e5                	mov    %esp,%ebp
c01032fc:	83 ec 28             	sub    $0x28,%esp
    struct Page *p = alloc_page();
c01032ff:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0103306:	e8 60 fa ff ff       	call   c0102d6b <alloc_pages>
c010330b:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (p == NULL) {
c010330e:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0103312:	75 1c                	jne    c0103330 <boot_alloc_page+0x37>
        panic("boot_alloc_page failed.\n");
c0103314:	c7 44 24 08 ef 69 10 	movl   $0xc01069ef,0x8(%esp)
c010331b:	c0 
c010331c:	c7 44 24 04 19 01 00 	movl   $0x119,0x4(%esp)
c0103323:	00 
c0103324:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c010332b:	e8 c9 d0 ff ff       	call   c01003f9 <__panic>
    }
    return page2kva(p);
c0103330:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103333:	89 04 24             	mov    %eax,(%esp)
c0103336:	e8 81 f7 ff ff       	call   c0102abc <page2kva>
}
c010333b:	c9                   	leave  
c010333c:	c3                   	ret    

c010333d <pmm_init>:
//7、从新设置全局段描述符表；
//8、取消临时二级页表；
//9、检查页表建立是否正确；
//10、通过自映射机制完成页表的打印输出（这部分是扩展知识）
void
pmm_init(void) {
c010333d:	55                   	push   %ebp
c010333e:	89 e5                	mov    %esp,%ebp
c0103340:	83 ec 38             	sub    $0x38,%esp
    // We've already enabled paging
    boot_cr3 = PADDR(boot_pgdir);
c0103343:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103348:	89 45 f4             	mov    %eax,-0xc(%ebp)
c010334b:	81 7d f4 ff ff ff bf 	cmpl   $0xbfffffff,-0xc(%ebp)
c0103352:	77 23                	ja     c0103377 <pmm_init+0x3a>
c0103354:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103357:	89 44 24 0c          	mov    %eax,0xc(%esp)
c010335b:	c7 44 24 08 84 69 10 	movl   $0xc0106984,0x8(%esp)
c0103362:	c0 
c0103363:	c7 44 24 04 2e 01 00 	movl   $0x12e,0x4(%esp)
c010336a:	00 
c010336b:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103372:	e8 82 d0 ff ff       	call   c01003f9 <__panic>
c0103377:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010337a:	05 00 00 00 40       	add    $0x40000000,%eax
c010337f:	a3 74 bf 11 c0       	mov    %eax,0xc011bf74
    //So a framework of physical memory manager (struct pmm_manager)is defined in pmm.h
    //First we should init a physical memory manager(pmm) based on the framework.
    //Then pmm can alloc/free the physical memory. 
    //Now the first_fit/best_fit/worst_fit/buddy_system pmm are available.
    //1、初始化物理内存页管理器框架pmm_manager；
    init_pmm_manager();
c0103384:	e8 8e f9 ff ff       	call   c0102d17 <init_pmm_manager>

    // detect physical memory space, reserve already used memory,
    // then use pmm->init_memmap to create free page list
    //2、建立空闲的page链表，这样就可以分配以页（4KB）为单位的空闲内存了；
    page_init();
c0103389:	e8 73 fa ff ff       	call   c0102e01 <page_init>

    //use pmm->check to verify the correctness of the alloc/free function in a pmm
   // 3、检查物理内存页分配算法；
    check_alloc_page();
c010338e:	e8 de 03 00 00       	call   c0103771 <check_alloc_page>

    check_pgdir();
c0103393:	e8 f8 03 00 00       	call   c0103790 <check_pgdir>

    static_assert(KERNBASE % PTSIZE == 0 && KERNTOP % PTSIZE == 0);

    // recursively insert boot_pgdir in itself
    // to form a virtual page table at virtual address VPT
    boot_pgdir[PDX(VPT)] = PADDR(boot_pgdir) | PTE_P | PTE_W;
c0103398:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c010339d:	89 45 f0             	mov    %eax,-0x10(%ebp)
c01033a0:	81 7d f0 ff ff ff bf 	cmpl   $0xbfffffff,-0x10(%ebp)
c01033a7:	77 23                	ja     c01033cc <pmm_init+0x8f>
c01033a9:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01033ac:	89 44 24 0c          	mov    %eax,0xc(%esp)
c01033b0:	c7 44 24 08 84 69 10 	movl   $0xc0106984,0x8(%esp)
c01033b7:	c0 
c01033b8:	c7 44 24 04 47 01 00 	movl   $0x147,0x4(%esp)
c01033bf:	00 
c01033c0:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01033c7:	e8 2d d0 ff ff       	call   c01003f9 <__panic>
c01033cc:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01033cf:	8d 90 00 00 00 40    	lea    0x40000000(%eax),%edx
c01033d5:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c01033da:	05 ac 0f 00 00       	add    $0xfac,%eax
c01033df:	83 ca 03             	or     $0x3,%edx
c01033e2:	89 10                	mov    %edx,(%eax)

    // map all physical memory to linear memory with base linear addr KERNBASE
    // linear_addr KERNBASE ~ KERNBASE + KMEMSIZE = phy_addr 0 ~ KMEMSIZE
    boot_map_segment(boot_pgdir, KERNBASE, KMEMSIZE, 0, PTE_W);
c01033e4:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c01033e9:	c7 44 24 10 02 00 00 	movl   $0x2,0x10(%esp)
c01033f0:	00 
c01033f1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c01033f8:	00 
c01033f9:	c7 44 24 08 00 00 00 	movl   $0x38000000,0x8(%esp)
c0103400:	38 
c0103401:	c7 44 24 04 00 00 00 	movl   $0xc0000000,0x4(%esp)
c0103408:	c0 
c0103409:	89 04 24             	mov    %eax,(%esp)
c010340c:	e8 e5 fd ff ff       	call   c01031f6 <boot_map_segment>

    // Since we are using bootloader's GDT,
    // we should reload gdt (second time, the last time) to get user segments and the TSS
    // map virtual_addr 0 ~ 4G = linear_addr 0 ~ 4G
    // then set kernel stack (ss:esp) in TSS, setup TSS in gdt, load TSS
    gdt_init();
c0103411:	e8 18 f8 ff ff       	call   c0102c2e <gdt_init>

    //now the basic virtual memory map(see memalyout.h) is established.
    //check the correctness of the basic virtual memory map.
    //检查页表建立是否正确；
    check_boot_pgdir();
c0103416:	e8 11 0a 00 00       	call   c0103e2c <check_boot_pgdir>

    //10、通过自映射机制完成页表的打印输出（这部分是扩展知识）
    print_pgdir();
c010341b:	e8 8a 0e 00 00       	call   c01042aa <print_pgdir>

}
c0103420:	90                   	nop
c0103421:	c9                   	leave  
c0103422:	c3                   	ret    

c0103423 <get_pte>:
//  la:     the linear address need to map
//  create: a logical value to decide if alloc a page for PT
// return vaule: the kernel virtual address of this pte
//完成虚实映射
pte_t *
get_pte(pde_t *pgdir, uintptr_t la, bool create) {
c0103423:	55                   	push   %ebp
c0103424:	89 e5                	mov    %esp,%ebp
c0103426:	83 ec 38             	sub    $0x38,%esp
                          // (6) clear page content using memset
                          // (7) set page directory entry's permission
    }
    return NULL;          // (8) return page table entry
#endif
 pde_t *pdep = &pgdir[PDX(la)];
c0103429:	8b 45 0c             	mov    0xc(%ebp),%eax
c010342c:	c1 e8 16             	shr    $0x16,%eax
c010342f:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
c0103436:	8b 45 08             	mov    0x8(%ebp),%eax
c0103439:	01 d0                	add    %edx,%eax
c010343b:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (!(*pdep & PTE_P)) {
c010343e:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103441:	8b 00                	mov    (%eax),%eax
c0103443:	83 e0 01             	and    $0x1,%eax
c0103446:	85 c0                	test   %eax,%eax
c0103448:	0f 85 af 00 00 00    	jne    c01034fd <get_pte+0xda>
        struct Page *page;
        if (!create || (page = alloc_page()) == NULL) {
c010344e:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c0103452:	74 15                	je     c0103469 <get_pte+0x46>
c0103454:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c010345b:	e8 0b f9 ff ff       	call   c0102d6b <alloc_pages>
c0103460:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0103463:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0103467:	75 0a                	jne    c0103473 <get_pte+0x50>
            return NULL;
c0103469:	b8 00 00 00 00       	mov    $0x0,%eax
c010346e:	e9 e7 00 00 00       	jmp    c010355a <get_pte+0x137>
        }
        set_page_ref(page, 1);
c0103473:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c010347a:	00 
c010347b:	8b 45 f0             	mov    -0x10(%ebp),%eax
c010347e:	89 04 24             	mov    %eax,(%esp)
c0103481:	e8 ea f6 ff ff       	call   c0102b70 <set_page_ref>
        uintptr_t pa = page2pa(page);
c0103486:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103489:	89 04 24             	mov    %eax,(%esp)
c010348c:	e8 c6 f5 ff ff       	call   c0102a57 <page2pa>
c0103491:	89 45 ec             	mov    %eax,-0x14(%ebp)
        memset(KADDR(pa), 0, PGSIZE);
c0103494:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0103497:	89 45 e8             	mov    %eax,-0x18(%ebp)
c010349a:	8b 45 e8             	mov    -0x18(%ebp),%eax
c010349d:	c1 e8 0c             	shr    $0xc,%eax
c01034a0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c01034a3:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c01034a8:	39 45 e4             	cmp    %eax,-0x1c(%ebp)
c01034ab:	72 23                	jb     c01034d0 <get_pte+0xad>
c01034ad:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01034b0:	89 44 24 0c          	mov    %eax,0xc(%esp)
c01034b4:	c7 44 24 08 e0 68 10 	movl   $0xc01068e0,0x8(%esp)
c01034bb:	c0 
c01034bc:	c7 44 24 04 90 01 00 	movl   $0x190,0x4(%esp)
c01034c3:	00 
c01034c4:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01034cb:	e8 29 cf ff ff       	call   c01003f9 <__panic>
c01034d0:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01034d3:	2d 00 00 00 40       	sub    $0x40000000,%eax
c01034d8:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
c01034df:	00 
c01034e0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c01034e7:	00 
c01034e8:	89 04 24             	mov    %eax,(%esp)
c01034eb:	e8 94 24 00 00       	call   c0105984 <memset>
        *pdep = pa | PTE_U | PTE_W | PTE_P;
c01034f0:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01034f3:	83 c8 07             	or     $0x7,%eax
c01034f6:	89 c2                	mov    %eax,%edx
c01034f8:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01034fb:	89 10                	mov    %edx,(%eax)
    }
    return &((pte_t *)KADDR(PDE_ADDR(*pdep)))[PTX(la)];
c01034fd:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103500:	8b 00                	mov    (%eax),%eax
c0103502:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0103507:	89 45 e0             	mov    %eax,-0x20(%ebp)
c010350a:	8b 45 e0             	mov    -0x20(%ebp),%eax
c010350d:	c1 e8 0c             	shr    $0xc,%eax
c0103510:	89 45 dc             	mov    %eax,-0x24(%ebp)
c0103513:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c0103518:	39 45 dc             	cmp    %eax,-0x24(%ebp)
c010351b:	72 23                	jb     c0103540 <get_pte+0x11d>
c010351d:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0103520:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0103524:	c7 44 24 08 e0 68 10 	movl   $0xc01068e0,0x8(%esp)
c010352b:	c0 
c010352c:	c7 44 24 04 93 01 00 	movl   $0x193,0x4(%esp)
c0103533:	00 
c0103534:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c010353b:	e8 b9 ce ff ff       	call   c01003f9 <__panic>
c0103540:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0103543:	2d 00 00 00 40       	sub    $0x40000000,%eax
c0103548:	89 c2                	mov    %eax,%edx
c010354a:	8b 45 0c             	mov    0xc(%ebp),%eax
c010354d:	c1 e8 0c             	shr    $0xc,%eax
c0103550:	25 ff 03 00 00       	and    $0x3ff,%eax
c0103555:	c1 e0 02             	shl    $0x2,%eax
c0103558:	01 d0                	add    %edx,%eax
}
c010355a:	c9                   	leave  
c010355b:	c3                   	ret    

c010355c <get_page>:

//get_page - get related Page struct for linear address la using PDT pgdir
struct Page *
get_page(pde_t *pgdir, uintptr_t la, pte_t **ptep_store) {
c010355c:	55                   	push   %ebp
c010355d:	89 e5                	mov    %esp,%ebp
c010355f:	83 ec 28             	sub    $0x28,%esp
    pte_t *ptep = get_pte(pgdir, la, 0);
c0103562:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0103569:	00 
c010356a:	8b 45 0c             	mov    0xc(%ebp),%eax
c010356d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0103571:	8b 45 08             	mov    0x8(%ebp),%eax
c0103574:	89 04 24             	mov    %eax,(%esp)
c0103577:	e8 a7 fe ff ff       	call   c0103423 <get_pte>
c010357c:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (ptep_store != NULL) {
c010357f:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c0103583:	74 08                	je     c010358d <get_page+0x31>
        *ptep_store = ptep;
c0103585:	8b 45 10             	mov    0x10(%ebp),%eax
c0103588:	8b 55 f4             	mov    -0xc(%ebp),%edx
c010358b:	89 10                	mov    %edx,(%eax)
    }
    if (ptep != NULL && *ptep & PTE_P) {
c010358d:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0103591:	74 1b                	je     c01035ae <get_page+0x52>
c0103593:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103596:	8b 00                	mov    (%eax),%eax
c0103598:	83 e0 01             	and    $0x1,%eax
c010359b:	85 c0                	test   %eax,%eax
c010359d:	74 0f                	je     c01035ae <get_page+0x52>
        return pte2page(*ptep);
c010359f:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01035a2:	8b 00                	mov    (%eax),%eax
c01035a4:	89 04 24             	mov    %eax,(%esp)
c01035a7:	e8 64 f5 ff ff       	call   c0102b10 <pte2page>
c01035ac:	eb 05                	jmp    c01035b3 <get_page+0x57>
    }
    return NULL;
c01035ae:	b8 00 00 00 00       	mov    $0x0,%eax
}
c01035b3:	c9                   	leave  
c01035b4:	c3                   	ret    

c01035b5 <page_remove_pte>:

//page_remove_pte - free an Page sturct which is related linear address la
//                - and clean(invalidate) pte which is related linear address la
//note: PT is changed, so the TLB need to be invalidate 
static inline void
page_remove_pte(pde_t *pgdir, uintptr_t la, pte_t *ptep) {
c01035b5:	55                   	push   %ebp
c01035b6:	89 e5                	mov    %esp,%ebp
c01035b8:	83 ec 28             	sub    $0x28,%esp
                                  //(4) and free this page when page reference reachs 0
                                  //(5) clear second page table entry
                                  //(6) flush tlb
    }
#endif
    if (*ptep & PTE_P) {
c01035bb:	8b 45 10             	mov    0x10(%ebp),%eax
c01035be:	8b 00                	mov    (%eax),%eax
c01035c0:	83 e0 01             	and    $0x1,%eax
c01035c3:	85 c0                	test   %eax,%eax
c01035c5:	74 4d                	je     c0103614 <page_remove_pte+0x5f>
        struct Page *page = pte2page(*ptep);
c01035c7:	8b 45 10             	mov    0x10(%ebp),%eax
c01035ca:	8b 00                	mov    (%eax),%eax
c01035cc:	89 04 24             	mov    %eax,(%esp)
c01035cf:	e8 3c f5 ff ff       	call   c0102b10 <pte2page>
c01035d4:	89 45 f4             	mov    %eax,-0xc(%ebp)
        if (page_ref_dec(page) == 0) {
c01035d7:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01035da:	89 04 24             	mov    %eax,(%esp)
c01035dd:	e8 b3 f5 ff ff       	call   c0102b95 <page_ref_dec>
c01035e2:	85 c0                	test   %eax,%eax
c01035e4:	75 13                	jne    c01035f9 <page_remove_pte+0x44>
            free_page(page);
c01035e6:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c01035ed:	00 
c01035ee:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01035f1:	89 04 24             	mov    %eax,(%esp)
c01035f4:	e8 aa f7 ff ff       	call   c0102da3 <free_pages>
        }
        *ptep = 0;
c01035f9:	8b 45 10             	mov    0x10(%ebp),%eax
c01035fc:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
        tlb_invalidate(pgdir, la);
c0103602:	8b 45 0c             	mov    0xc(%ebp),%eax
c0103605:	89 44 24 04          	mov    %eax,0x4(%esp)
c0103609:	8b 45 08             	mov    0x8(%ebp),%eax
c010360c:	89 04 24             	mov    %eax,(%esp)
c010360f:	e8 01 01 00 00       	call   c0103715 <tlb_invalidate>
    }
}
c0103614:	90                   	nop
c0103615:	c9                   	leave  
c0103616:	c3                   	ret    

c0103617 <page_remove>:

//page_remove - free an Page which is related linear address la and has an validated pte
void
page_remove(pde_t *pgdir, uintptr_t la) {
c0103617:	55                   	push   %ebp
c0103618:	89 e5                	mov    %esp,%ebp
c010361a:	83 ec 28             	sub    $0x28,%esp
    pte_t *ptep = get_pte(pgdir, la, 0);
c010361d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0103624:	00 
c0103625:	8b 45 0c             	mov    0xc(%ebp),%eax
c0103628:	89 44 24 04          	mov    %eax,0x4(%esp)
c010362c:	8b 45 08             	mov    0x8(%ebp),%eax
c010362f:	89 04 24             	mov    %eax,(%esp)
c0103632:	e8 ec fd ff ff       	call   c0103423 <get_pte>
c0103637:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (ptep != NULL) {
c010363a:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c010363e:	74 19                	je     c0103659 <page_remove+0x42>
        page_remove_pte(pgdir, la, ptep);
c0103640:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103643:	89 44 24 08          	mov    %eax,0x8(%esp)
c0103647:	8b 45 0c             	mov    0xc(%ebp),%eax
c010364a:	89 44 24 04          	mov    %eax,0x4(%esp)
c010364e:	8b 45 08             	mov    0x8(%ebp),%eax
c0103651:	89 04 24             	mov    %eax,(%esp)
c0103654:	e8 5c ff ff ff       	call   c01035b5 <page_remove_pte>
    }
}
c0103659:	90                   	nop
c010365a:	c9                   	leave  
c010365b:	c3                   	ret    

c010365c <page_insert>:
//  la:    the linear address need to map
//  perm:  the permission of this Page which is setted in related pte
// return value: always 0
//note: PT is changed, so the TLB need to be invalidate 
int
page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm) {
c010365c:	55                   	push   %ebp
c010365d:	89 e5                	mov    %esp,%ebp
c010365f:	83 ec 28             	sub    $0x28,%esp
    pte_t *ptep = get_pte(pgdir, la, 1);
c0103662:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
c0103669:	00 
c010366a:	8b 45 10             	mov    0x10(%ebp),%eax
c010366d:	89 44 24 04          	mov    %eax,0x4(%esp)
c0103671:	8b 45 08             	mov    0x8(%ebp),%eax
c0103674:	89 04 24             	mov    %eax,(%esp)
c0103677:	e8 a7 fd ff ff       	call   c0103423 <get_pte>
c010367c:	89 45 f4             	mov    %eax,-0xc(%ebp)
    if (ptep == NULL) {
c010367f:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0103683:	75 0a                	jne    c010368f <page_insert+0x33>
        return -E_NO_MEM;
c0103685:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
c010368a:	e9 84 00 00 00       	jmp    c0103713 <page_insert+0xb7>
    }
    page_ref_inc(page);
c010368f:	8b 45 0c             	mov    0xc(%ebp),%eax
c0103692:	89 04 24             	mov    %eax,(%esp)
c0103695:	e8 e4 f4 ff ff       	call   c0102b7e <page_ref_inc>
    if (*ptep & PTE_P) {
c010369a:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010369d:	8b 00                	mov    (%eax),%eax
c010369f:	83 e0 01             	and    $0x1,%eax
c01036a2:	85 c0                	test   %eax,%eax
c01036a4:	74 3e                	je     c01036e4 <page_insert+0x88>
        struct Page *p = pte2page(*ptep);
c01036a6:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01036a9:	8b 00                	mov    (%eax),%eax
c01036ab:	89 04 24             	mov    %eax,(%esp)
c01036ae:	e8 5d f4 ff ff       	call   c0102b10 <pte2page>
c01036b3:	89 45 f0             	mov    %eax,-0x10(%ebp)
        if (p == page) {
c01036b6:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01036b9:	3b 45 0c             	cmp    0xc(%ebp),%eax
c01036bc:	75 0d                	jne    c01036cb <page_insert+0x6f>
            page_ref_dec(page);
c01036be:	8b 45 0c             	mov    0xc(%ebp),%eax
c01036c1:	89 04 24             	mov    %eax,(%esp)
c01036c4:	e8 cc f4 ff ff       	call   c0102b95 <page_ref_dec>
c01036c9:	eb 19                	jmp    c01036e4 <page_insert+0x88>
        }
        else {
            page_remove_pte(pgdir, la, ptep);
c01036cb:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01036ce:	89 44 24 08          	mov    %eax,0x8(%esp)
c01036d2:	8b 45 10             	mov    0x10(%ebp),%eax
c01036d5:	89 44 24 04          	mov    %eax,0x4(%esp)
c01036d9:	8b 45 08             	mov    0x8(%ebp),%eax
c01036dc:	89 04 24             	mov    %eax,(%esp)
c01036df:	e8 d1 fe ff ff       	call   c01035b5 <page_remove_pte>
        }
    }
    *ptep = page2pa(page) | PTE_P | perm;
c01036e4:	8b 45 0c             	mov    0xc(%ebp),%eax
c01036e7:	89 04 24             	mov    %eax,(%esp)
c01036ea:	e8 68 f3 ff ff       	call   c0102a57 <page2pa>
c01036ef:	0b 45 14             	or     0x14(%ebp),%eax
c01036f2:	83 c8 01             	or     $0x1,%eax
c01036f5:	89 c2                	mov    %eax,%edx
c01036f7:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01036fa:	89 10                	mov    %edx,(%eax)
    tlb_invalidate(pgdir, la);
c01036fc:	8b 45 10             	mov    0x10(%ebp),%eax
c01036ff:	89 44 24 04          	mov    %eax,0x4(%esp)
c0103703:	8b 45 08             	mov    0x8(%ebp),%eax
c0103706:	89 04 24             	mov    %eax,(%esp)
c0103709:	e8 07 00 00 00       	call   c0103715 <tlb_invalidate>
    return 0;
c010370e:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0103713:	c9                   	leave  
c0103714:	c3                   	ret    

c0103715 <tlb_invalidate>:

// invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
void
tlb_invalidate(pde_t *pgdir, uintptr_t la) {
c0103715:	55                   	push   %ebp
c0103716:	89 e5                	mov    %esp,%ebp
c0103718:	83 ec 28             	sub    $0x28,%esp
}

static inline uintptr_t
rcr3(void) {
    uintptr_t cr3;
    asm volatile ("mov %%cr3, %0" : "=r" (cr3) :: "memory");
c010371b:	0f 20 d8             	mov    %cr3,%eax
c010371e:	89 45 f0             	mov    %eax,-0x10(%ebp)
    return cr3;
c0103721:	8b 55 f0             	mov    -0x10(%ebp),%edx
    if (rcr3() == PADDR(pgdir)) {
c0103724:	8b 45 08             	mov    0x8(%ebp),%eax
c0103727:	89 45 f4             	mov    %eax,-0xc(%ebp)
c010372a:	81 7d f4 ff ff ff bf 	cmpl   $0xbfffffff,-0xc(%ebp)
c0103731:	77 23                	ja     c0103756 <tlb_invalidate+0x41>
c0103733:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103736:	89 44 24 0c          	mov    %eax,0xc(%esp)
c010373a:	c7 44 24 08 84 69 10 	movl   $0xc0106984,0x8(%esp)
c0103741:	c0 
c0103742:	c7 44 24 04 f5 01 00 	movl   $0x1f5,0x4(%esp)
c0103749:	00 
c010374a:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103751:	e8 a3 cc ff ff       	call   c01003f9 <__panic>
c0103756:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103759:	05 00 00 00 40       	add    $0x40000000,%eax
c010375e:	39 d0                	cmp    %edx,%eax
c0103760:	75 0c                	jne    c010376e <tlb_invalidate+0x59>
        invlpg((void *)la);
c0103762:	8b 45 0c             	mov    0xc(%ebp),%eax
c0103765:	89 45 ec             	mov    %eax,-0x14(%ebp)
}

static inline void
invlpg(void *addr) {
    asm volatile ("invlpg (%0)" :: "r" (addr) : "memory");
c0103768:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010376b:	0f 01 38             	invlpg (%eax)
    }
}
c010376e:	90                   	nop
c010376f:	c9                   	leave  
c0103770:	c3                   	ret    

c0103771 <check_alloc_page>:

static void
check_alloc_page(void) {
c0103771:	55                   	push   %ebp
c0103772:	89 e5                	mov    %esp,%ebp
c0103774:	83 ec 18             	sub    $0x18,%esp
    pmm_manager->check();
c0103777:	a1 70 bf 11 c0       	mov    0xc011bf70,%eax
c010377c:	8b 40 18             	mov    0x18(%eax),%eax
c010377f:	ff d0                	call   *%eax
    cprintf("check_alloc_page() succeeded!\n");
c0103781:	c7 04 24 08 6a 10 c0 	movl   $0xc0106a08,(%esp)
c0103788:	e8 15 cb ff ff       	call   c01002a2 <cprintf>
}
c010378d:	90                   	nop
c010378e:	c9                   	leave  
c010378f:	c3                   	ret    

c0103790 <check_pgdir>:

static void
check_pgdir(void) {
c0103790:	55                   	push   %ebp
c0103791:	89 e5                	mov    %esp,%ebp
c0103793:	83 ec 38             	sub    $0x38,%esp
    assert(npage <= KMEMSIZE / PGSIZE);
c0103796:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c010379b:	3d 00 80 03 00       	cmp    $0x38000,%eax
c01037a0:	76 24                	jbe    c01037c6 <check_pgdir+0x36>
c01037a2:	c7 44 24 0c 27 6a 10 	movl   $0xc0106a27,0xc(%esp)
c01037a9:	c0 
c01037aa:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c01037b1:	c0 
c01037b2:	c7 44 24 04 02 02 00 	movl   $0x202,0x4(%esp)
c01037b9:	00 
c01037ba:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01037c1:	e8 33 cc ff ff       	call   c01003f9 <__panic>
    assert(boot_pgdir != NULL && (uint32_t)PGOFF(boot_pgdir) == 0);
c01037c6:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c01037cb:	85 c0                	test   %eax,%eax
c01037cd:	74 0e                	je     c01037dd <check_pgdir+0x4d>
c01037cf:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c01037d4:	25 ff 0f 00 00       	and    $0xfff,%eax
c01037d9:	85 c0                	test   %eax,%eax
c01037db:	74 24                	je     c0103801 <check_pgdir+0x71>
c01037dd:	c7 44 24 0c 44 6a 10 	movl   $0xc0106a44,0xc(%esp)
c01037e4:	c0 
c01037e5:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c01037ec:	c0 
c01037ed:	c7 44 24 04 03 02 00 	movl   $0x203,0x4(%esp)
c01037f4:	00 
c01037f5:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01037fc:	e8 f8 cb ff ff       	call   c01003f9 <__panic>
    assert(get_page(boot_pgdir, 0x0, NULL) == NULL);
c0103801:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103806:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c010380d:	00 
c010380e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0103815:	00 
c0103816:	89 04 24             	mov    %eax,(%esp)
c0103819:	e8 3e fd ff ff       	call   c010355c <get_page>
c010381e:	85 c0                	test   %eax,%eax
c0103820:	74 24                	je     c0103846 <check_pgdir+0xb6>
c0103822:	c7 44 24 0c 7c 6a 10 	movl   $0xc0106a7c,0xc(%esp)
c0103829:	c0 
c010382a:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103831:	c0 
c0103832:	c7 44 24 04 04 02 00 	movl   $0x204,0x4(%esp)
c0103839:	00 
c010383a:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103841:	e8 b3 cb ff ff       	call   c01003f9 <__panic>

    struct Page *p1, *p2;
    p1 = alloc_page();
c0103846:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c010384d:	e8 19 f5 ff ff       	call   c0102d6b <alloc_pages>
c0103852:	89 45 f4             	mov    %eax,-0xc(%ebp)
    assert(page_insert(boot_pgdir, p1, 0x0, 0) == 0);
c0103855:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c010385a:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0103861:	00 
c0103862:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0103869:	00 
c010386a:	8b 55 f4             	mov    -0xc(%ebp),%edx
c010386d:	89 54 24 04          	mov    %edx,0x4(%esp)
c0103871:	89 04 24             	mov    %eax,(%esp)
c0103874:	e8 e3 fd ff ff       	call   c010365c <page_insert>
c0103879:	85 c0                	test   %eax,%eax
c010387b:	74 24                	je     c01038a1 <check_pgdir+0x111>
c010387d:	c7 44 24 0c a4 6a 10 	movl   $0xc0106aa4,0xc(%esp)
c0103884:	c0 
c0103885:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c010388c:	c0 
c010388d:	c7 44 24 04 08 02 00 	movl   $0x208,0x4(%esp)
c0103894:	00 
c0103895:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c010389c:	e8 58 cb ff ff       	call   c01003f9 <__panic>

    pte_t *ptep;
    assert((ptep = get_pte(boot_pgdir, 0x0, 0)) != NULL);
c01038a1:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c01038a6:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c01038ad:	00 
c01038ae:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c01038b5:	00 
c01038b6:	89 04 24             	mov    %eax,(%esp)
c01038b9:	e8 65 fb ff ff       	call   c0103423 <get_pte>
c01038be:	89 45 f0             	mov    %eax,-0x10(%ebp)
c01038c1:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c01038c5:	75 24                	jne    c01038eb <check_pgdir+0x15b>
c01038c7:	c7 44 24 0c d0 6a 10 	movl   $0xc0106ad0,0xc(%esp)
c01038ce:	c0 
c01038cf:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c01038d6:	c0 
c01038d7:	c7 44 24 04 0b 02 00 	movl   $0x20b,0x4(%esp)
c01038de:	00 
c01038df:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01038e6:	e8 0e cb ff ff       	call   c01003f9 <__panic>
    assert(pte2page(*ptep) == p1);
c01038eb:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01038ee:	8b 00                	mov    (%eax),%eax
c01038f0:	89 04 24             	mov    %eax,(%esp)
c01038f3:	e8 18 f2 ff ff       	call   c0102b10 <pte2page>
c01038f8:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c01038fb:	74 24                	je     c0103921 <check_pgdir+0x191>
c01038fd:	c7 44 24 0c fd 6a 10 	movl   $0xc0106afd,0xc(%esp)
c0103904:	c0 
c0103905:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c010390c:	c0 
c010390d:	c7 44 24 04 0c 02 00 	movl   $0x20c,0x4(%esp)
c0103914:	00 
c0103915:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c010391c:	e8 d8 ca ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p1) == 1);
c0103921:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103924:	89 04 24             	mov    %eax,(%esp)
c0103927:	e8 3a f2 ff ff       	call   c0102b66 <page_ref>
c010392c:	83 f8 01             	cmp    $0x1,%eax
c010392f:	74 24                	je     c0103955 <check_pgdir+0x1c5>
c0103931:	c7 44 24 0c 13 6b 10 	movl   $0xc0106b13,0xc(%esp)
c0103938:	c0 
c0103939:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103940:	c0 
c0103941:	c7 44 24 04 0d 02 00 	movl   $0x20d,0x4(%esp)
c0103948:	00 
c0103949:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103950:	e8 a4 ca ff ff       	call   c01003f9 <__panic>

    ptep = &((pte_t *)KADDR(PDE_ADDR(boot_pgdir[0])))[1];
c0103955:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c010395a:	8b 00                	mov    (%eax),%eax
c010395c:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0103961:	89 45 ec             	mov    %eax,-0x14(%ebp)
c0103964:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0103967:	c1 e8 0c             	shr    $0xc,%eax
c010396a:	89 45 e8             	mov    %eax,-0x18(%ebp)
c010396d:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c0103972:	39 45 e8             	cmp    %eax,-0x18(%ebp)
c0103975:	72 23                	jb     c010399a <check_pgdir+0x20a>
c0103977:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010397a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c010397e:	c7 44 24 08 e0 68 10 	movl   $0xc01068e0,0x8(%esp)
c0103985:	c0 
c0103986:	c7 44 24 04 0f 02 00 	movl   $0x20f,0x4(%esp)
c010398d:	00 
c010398e:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103995:	e8 5f ca ff ff       	call   c01003f9 <__panic>
c010399a:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010399d:	2d 00 00 00 40       	sub    $0x40000000,%eax
c01039a2:	83 c0 04             	add    $0x4,%eax
c01039a5:	89 45 f0             	mov    %eax,-0x10(%ebp)
    assert(get_pte(boot_pgdir, PGSIZE, 0) == ptep);
c01039a8:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c01039ad:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c01039b4:	00 
c01039b5:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
c01039bc:	00 
c01039bd:	89 04 24             	mov    %eax,(%esp)
c01039c0:	e8 5e fa ff ff       	call   c0103423 <get_pte>
c01039c5:	39 45 f0             	cmp    %eax,-0x10(%ebp)
c01039c8:	74 24                	je     c01039ee <check_pgdir+0x25e>
c01039ca:	c7 44 24 0c 28 6b 10 	movl   $0xc0106b28,0xc(%esp)
c01039d1:	c0 
c01039d2:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c01039d9:	c0 
c01039da:	c7 44 24 04 10 02 00 	movl   $0x210,0x4(%esp)
c01039e1:	00 
c01039e2:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01039e9:	e8 0b ca ff ff       	call   c01003f9 <__panic>

    p2 = alloc_page();
c01039ee:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c01039f5:	e8 71 f3 ff ff       	call   c0102d6b <alloc_pages>
c01039fa:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    assert(page_insert(boot_pgdir, p2, PGSIZE, PTE_U | PTE_W) == 0);
c01039fd:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103a02:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
c0103a09:	00 
c0103a0a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
c0103a11:	00 
c0103a12:	8b 55 e4             	mov    -0x1c(%ebp),%edx
c0103a15:	89 54 24 04          	mov    %edx,0x4(%esp)
c0103a19:	89 04 24             	mov    %eax,(%esp)
c0103a1c:	e8 3b fc ff ff       	call   c010365c <page_insert>
c0103a21:	85 c0                	test   %eax,%eax
c0103a23:	74 24                	je     c0103a49 <check_pgdir+0x2b9>
c0103a25:	c7 44 24 0c 50 6b 10 	movl   $0xc0106b50,0xc(%esp)
c0103a2c:	c0 
c0103a2d:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103a34:	c0 
c0103a35:	c7 44 24 04 13 02 00 	movl   $0x213,0x4(%esp)
c0103a3c:	00 
c0103a3d:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103a44:	e8 b0 c9 ff ff       	call   c01003f9 <__panic>
    assert((ptep = get_pte(boot_pgdir, PGSIZE, 0)) != NULL);
c0103a49:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103a4e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0103a55:	00 
c0103a56:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
c0103a5d:	00 
c0103a5e:	89 04 24             	mov    %eax,(%esp)
c0103a61:	e8 bd f9 ff ff       	call   c0103423 <get_pte>
c0103a66:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0103a69:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0103a6d:	75 24                	jne    c0103a93 <check_pgdir+0x303>
c0103a6f:	c7 44 24 0c 88 6b 10 	movl   $0xc0106b88,0xc(%esp)
c0103a76:	c0 
c0103a77:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103a7e:	c0 
c0103a7f:	c7 44 24 04 14 02 00 	movl   $0x214,0x4(%esp)
c0103a86:	00 
c0103a87:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103a8e:	e8 66 c9 ff ff       	call   c01003f9 <__panic>
    assert(*ptep & PTE_U);
c0103a93:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103a96:	8b 00                	mov    (%eax),%eax
c0103a98:	83 e0 04             	and    $0x4,%eax
c0103a9b:	85 c0                	test   %eax,%eax
c0103a9d:	75 24                	jne    c0103ac3 <check_pgdir+0x333>
c0103a9f:	c7 44 24 0c b8 6b 10 	movl   $0xc0106bb8,0xc(%esp)
c0103aa6:	c0 
c0103aa7:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103aae:	c0 
c0103aaf:	c7 44 24 04 15 02 00 	movl   $0x215,0x4(%esp)
c0103ab6:	00 
c0103ab7:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103abe:	e8 36 c9 ff ff       	call   c01003f9 <__panic>
    assert(*ptep & PTE_W);
c0103ac3:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103ac6:	8b 00                	mov    (%eax),%eax
c0103ac8:	83 e0 02             	and    $0x2,%eax
c0103acb:	85 c0                	test   %eax,%eax
c0103acd:	75 24                	jne    c0103af3 <check_pgdir+0x363>
c0103acf:	c7 44 24 0c c6 6b 10 	movl   $0xc0106bc6,0xc(%esp)
c0103ad6:	c0 
c0103ad7:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103ade:	c0 
c0103adf:	c7 44 24 04 16 02 00 	movl   $0x216,0x4(%esp)
c0103ae6:	00 
c0103ae7:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103aee:	e8 06 c9 ff ff       	call   c01003f9 <__panic>
    assert(boot_pgdir[0] & PTE_U);
c0103af3:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103af8:	8b 00                	mov    (%eax),%eax
c0103afa:	83 e0 04             	and    $0x4,%eax
c0103afd:	85 c0                	test   %eax,%eax
c0103aff:	75 24                	jne    c0103b25 <check_pgdir+0x395>
c0103b01:	c7 44 24 0c d4 6b 10 	movl   $0xc0106bd4,0xc(%esp)
c0103b08:	c0 
c0103b09:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103b10:	c0 
c0103b11:	c7 44 24 04 17 02 00 	movl   $0x217,0x4(%esp)
c0103b18:	00 
c0103b19:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103b20:	e8 d4 c8 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p2) == 1);
c0103b25:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0103b28:	89 04 24             	mov    %eax,(%esp)
c0103b2b:	e8 36 f0 ff ff       	call   c0102b66 <page_ref>
c0103b30:	83 f8 01             	cmp    $0x1,%eax
c0103b33:	74 24                	je     c0103b59 <check_pgdir+0x3c9>
c0103b35:	c7 44 24 0c ea 6b 10 	movl   $0xc0106bea,0xc(%esp)
c0103b3c:	c0 
c0103b3d:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103b44:	c0 
c0103b45:	c7 44 24 04 18 02 00 	movl   $0x218,0x4(%esp)
c0103b4c:	00 
c0103b4d:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103b54:	e8 a0 c8 ff ff       	call   c01003f9 <__panic>

    assert(page_insert(boot_pgdir, p1, PGSIZE, 0) == 0);
c0103b59:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103b5e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
c0103b65:	00 
c0103b66:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
c0103b6d:	00 
c0103b6e:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0103b71:	89 54 24 04          	mov    %edx,0x4(%esp)
c0103b75:	89 04 24             	mov    %eax,(%esp)
c0103b78:	e8 df fa ff ff       	call   c010365c <page_insert>
c0103b7d:	85 c0                	test   %eax,%eax
c0103b7f:	74 24                	je     c0103ba5 <check_pgdir+0x415>
c0103b81:	c7 44 24 0c fc 6b 10 	movl   $0xc0106bfc,0xc(%esp)
c0103b88:	c0 
c0103b89:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103b90:	c0 
c0103b91:	c7 44 24 04 1a 02 00 	movl   $0x21a,0x4(%esp)
c0103b98:	00 
c0103b99:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103ba0:	e8 54 c8 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p1) == 2);
c0103ba5:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103ba8:	89 04 24             	mov    %eax,(%esp)
c0103bab:	e8 b6 ef ff ff       	call   c0102b66 <page_ref>
c0103bb0:	83 f8 02             	cmp    $0x2,%eax
c0103bb3:	74 24                	je     c0103bd9 <check_pgdir+0x449>
c0103bb5:	c7 44 24 0c 28 6c 10 	movl   $0xc0106c28,0xc(%esp)
c0103bbc:	c0 
c0103bbd:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103bc4:	c0 
c0103bc5:	c7 44 24 04 1b 02 00 	movl   $0x21b,0x4(%esp)
c0103bcc:	00 
c0103bcd:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103bd4:	e8 20 c8 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p2) == 0);
c0103bd9:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0103bdc:	89 04 24             	mov    %eax,(%esp)
c0103bdf:	e8 82 ef ff ff       	call   c0102b66 <page_ref>
c0103be4:	85 c0                	test   %eax,%eax
c0103be6:	74 24                	je     c0103c0c <check_pgdir+0x47c>
c0103be8:	c7 44 24 0c 3a 6c 10 	movl   $0xc0106c3a,0xc(%esp)
c0103bef:	c0 
c0103bf0:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103bf7:	c0 
c0103bf8:	c7 44 24 04 1c 02 00 	movl   $0x21c,0x4(%esp)
c0103bff:	00 
c0103c00:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103c07:	e8 ed c7 ff ff       	call   c01003f9 <__panic>
    assert((ptep = get_pte(boot_pgdir, PGSIZE, 0)) != NULL);
c0103c0c:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103c11:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0103c18:	00 
c0103c19:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
c0103c20:	00 
c0103c21:	89 04 24             	mov    %eax,(%esp)
c0103c24:	e8 fa f7 ff ff       	call   c0103423 <get_pte>
c0103c29:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0103c2c:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0103c30:	75 24                	jne    c0103c56 <check_pgdir+0x4c6>
c0103c32:	c7 44 24 0c 88 6b 10 	movl   $0xc0106b88,0xc(%esp)
c0103c39:	c0 
c0103c3a:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103c41:	c0 
c0103c42:	c7 44 24 04 1d 02 00 	movl   $0x21d,0x4(%esp)
c0103c49:	00 
c0103c4a:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103c51:	e8 a3 c7 ff ff       	call   c01003f9 <__panic>
    assert(pte2page(*ptep) == p1);
c0103c56:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103c59:	8b 00                	mov    (%eax),%eax
c0103c5b:	89 04 24             	mov    %eax,(%esp)
c0103c5e:	e8 ad ee ff ff       	call   c0102b10 <pte2page>
c0103c63:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c0103c66:	74 24                	je     c0103c8c <check_pgdir+0x4fc>
c0103c68:	c7 44 24 0c fd 6a 10 	movl   $0xc0106afd,0xc(%esp)
c0103c6f:	c0 
c0103c70:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103c77:	c0 
c0103c78:	c7 44 24 04 1e 02 00 	movl   $0x21e,0x4(%esp)
c0103c7f:	00 
c0103c80:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103c87:	e8 6d c7 ff ff       	call   c01003f9 <__panic>
    assert((*ptep & PTE_U) == 0);
c0103c8c:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103c8f:	8b 00                	mov    (%eax),%eax
c0103c91:	83 e0 04             	and    $0x4,%eax
c0103c94:	85 c0                	test   %eax,%eax
c0103c96:	74 24                	je     c0103cbc <check_pgdir+0x52c>
c0103c98:	c7 44 24 0c 4c 6c 10 	movl   $0xc0106c4c,0xc(%esp)
c0103c9f:	c0 
c0103ca0:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103ca7:	c0 
c0103ca8:	c7 44 24 04 1f 02 00 	movl   $0x21f,0x4(%esp)
c0103caf:	00 
c0103cb0:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103cb7:	e8 3d c7 ff ff       	call   c01003f9 <__panic>

    page_remove(boot_pgdir, 0x0);
c0103cbc:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103cc1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0103cc8:	00 
c0103cc9:	89 04 24             	mov    %eax,(%esp)
c0103ccc:	e8 46 f9 ff ff       	call   c0103617 <page_remove>
    assert(page_ref(p1) == 1);
c0103cd1:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103cd4:	89 04 24             	mov    %eax,(%esp)
c0103cd7:	e8 8a ee ff ff       	call   c0102b66 <page_ref>
c0103cdc:	83 f8 01             	cmp    $0x1,%eax
c0103cdf:	74 24                	je     c0103d05 <check_pgdir+0x575>
c0103ce1:	c7 44 24 0c 13 6b 10 	movl   $0xc0106b13,0xc(%esp)
c0103ce8:	c0 
c0103ce9:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103cf0:	c0 
c0103cf1:	c7 44 24 04 22 02 00 	movl   $0x222,0x4(%esp)
c0103cf8:	00 
c0103cf9:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103d00:	e8 f4 c6 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p2) == 0);
c0103d05:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0103d08:	89 04 24             	mov    %eax,(%esp)
c0103d0b:	e8 56 ee ff ff       	call   c0102b66 <page_ref>
c0103d10:	85 c0                	test   %eax,%eax
c0103d12:	74 24                	je     c0103d38 <check_pgdir+0x5a8>
c0103d14:	c7 44 24 0c 3a 6c 10 	movl   $0xc0106c3a,0xc(%esp)
c0103d1b:	c0 
c0103d1c:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103d23:	c0 
c0103d24:	c7 44 24 04 23 02 00 	movl   $0x223,0x4(%esp)
c0103d2b:	00 
c0103d2c:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103d33:	e8 c1 c6 ff ff       	call   c01003f9 <__panic>

    page_remove(boot_pgdir, PGSIZE);
c0103d38:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103d3d:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
c0103d44:	00 
c0103d45:	89 04 24             	mov    %eax,(%esp)
c0103d48:	e8 ca f8 ff ff       	call   c0103617 <page_remove>
    assert(page_ref(p1) == 0);
c0103d4d:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103d50:	89 04 24             	mov    %eax,(%esp)
c0103d53:	e8 0e ee ff ff       	call   c0102b66 <page_ref>
c0103d58:	85 c0                	test   %eax,%eax
c0103d5a:	74 24                	je     c0103d80 <check_pgdir+0x5f0>
c0103d5c:	c7 44 24 0c 61 6c 10 	movl   $0xc0106c61,0xc(%esp)
c0103d63:	c0 
c0103d64:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103d6b:	c0 
c0103d6c:	c7 44 24 04 26 02 00 	movl   $0x226,0x4(%esp)
c0103d73:	00 
c0103d74:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103d7b:	e8 79 c6 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p2) == 0);
c0103d80:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0103d83:	89 04 24             	mov    %eax,(%esp)
c0103d86:	e8 db ed ff ff       	call   c0102b66 <page_ref>
c0103d8b:	85 c0                	test   %eax,%eax
c0103d8d:	74 24                	je     c0103db3 <check_pgdir+0x623>
c0103d8f:	c7 44 24 0c 3a 6c 10 	movl   $0xc0106c3a,0xc(%esp)
c0103d96:	c0 
c0103d97:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103d9e:	c0 
c0103d9f:	c7 44 24 04 27 02 00 	movl   $0x227,0x4(%esp)
c0103da6:	00 
c0103da7:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103dae:	e8 46 c6 ff ff       	call   c01003f9 <__panic>

    assert(page_ref(pde2page(boot_pgdir[0])) == 1);
c0103db3:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103db8:	8b 00                	mov    (%eax),%eax
c0103dba:	89 04 24             	mov    %eax,(%esp)
c0103dbd:	e8 8c ed ff ff       	call   c0102b4e <pde2page>
c0103dc2:	89 04 24             	mov    %eax,(%esp)
c0103dc5:	e8 9c ed ff ff       	call   c0102b66 <page_ref>
c0103dca:	83 f8 01             	cmp    $0x1,%eax
c0103dcd:	74 24                	je     c0103df3 <check_pgdir+0x663>
c0103dcf:	c7 44 24 0c 74 6c 10 	movl   $0xc0106c74,0xc(%esp)
c0103dd6:	c0 
c0103dd7:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103dde:	c0 
c0103ddf:	c7 44 24 04 29 02 00 	movl   $0x229,0x4(%esp)
c0103de6:	00 
c0103de7:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103dee:	e8 06 c6 ff ff       	call   c01003f9 <__panic>
    free_page(pde2page(boot_pgdir[0]));
c0103df3:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103df8:	8b 00                	mov    (%eax),%eax
c0103dfa:	89 04 24             	mov    %eax,(%esp)
c0103dfd:	e8 4c ed ff ff       	call   c0102b4e <pde2page>
c0103e02:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0103e09:	00 
c0103e0a:	89 04 24             	mov    %eax,(%esp)
c0103e0d:	e8 91 ef ff ff       	call   c0102da3 <free_pages>
    boot_pgdir[0] = 0;
c0103e12:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103e17:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

    cprintf("check_pgdir() succeeded!\n");
c0103e1d:	c7 04 24 9b 6c 10 c0 	movl   $0xc0106c9b,(%esp)
c0103e24:	e8 79 c4 ff ff       	call   c01002a2 <cprintf>
}
c0103e29:	90                   	nop
c0103e2a:	c9                   	leave  
c0103e2b:	c3                   	ret    

c0103e2c <check_boot_pgdir>:

static void
check_boot_pgdir(void) {
c0103e2c:	55                   	push   %ebp
c0103e2d:	89 e5                	mov    %esp,%ebp
c0103e2f:	83 ec 38             	sub    $0x38,%esp
    pte_t *ptep;
    int i;
    for (i = 0; i < npage; i += PGSIZE) {
c0103e32:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
c0103e39:	e9 ca 00 00 00       	jmp    c0103f08 <check_boot_pgdir+0xdc>
        assert((ptep = get_pte(boot_pgdir, (uintptr_t)KADDR(i), 0)) != NULL);
c0103e3e:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103e41:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c0103e44:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0103e47:	c1 e8 0c             	shr    $0xc,%eax
c0103e4a:	89 45 e0             	mov    %eax,-0x20(%ebp)
c0103e4d:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c0103e52:	39 45 e0             	cmp    %eax,-0x20(%ebp)
c0103e55:	72 23                	jb     c0103e7a <check_boot_pgdir+0x4e>
c0103e57:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0103e5a:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0103e5e:	c7 44 24 08 e0 68 10 	movl   $0xc01068e0,0x8(%esp)
c0103e65:	c0 
c0103e66:	c7 44 24 04 35 02 00 	movl   $0x235,0x4(%esp)
c0103e6d:	00 
c0103e6e:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103e75:	e8 7f c5 ff ff       	call   c01003f9 <__panic>
c0103e7a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0103e7d:	2d 00 00 00 40       	sub    $0x40000000,%eax
c0103e82:	89 c2                	mov    %eax,%edx
c0103e84:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103e89:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
c0103e90:	00 
c0103e91:	89 54 24 04          	mov    %edx,0x4(%esp)
c0103e95:	89 04 24             	mov    %eax,(%esp)
c0103e98:	e8 86 f5 ff ff       	call   c0103423 <get_pte>
c0103e9d:	89 45 dc             	mov    %eax,-0x24(%ebp)
c0103ea0:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
c0103ea4:	75 24                	jne    c0103eca <check_boot_pgdir+0x9e>
c0103ea6:	c7 44 24 0c b8 6c 10 	movl   $0xc0106cb8,0xc(%esp)
c0103ead:	c0 
c0103eae:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103eb5:	c0 
c0103eb6:	c7 44 24 04 35 02 00 	movl   $0x235,0x4(%esp)
c0103ebd:	00 
c0103ebe:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103ec5:	e8 2f c5 ff ff       	call   c01003f9 <__panic>
        assert(PTE_ADDR(*ptep) == i);
c0103eca:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0103ecd:	8b 00                	mov    (%eax),%eax
c0103ecf:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0103ed4:	89 c2                	mov    %eax,%edx
c0103ed6:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0103ed9:	39 c2                	cmp    %eax,%edx
c0103edb:	74 24                	je     c0103f01 <check_boot_pgdir+0xd5>
c0103edd:	c7 44 24 0c f5 6c 10 	movl   $0xc0106cf5,0xc(%esp)
c0103ee4:	c0 
c0103ee5:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103eec:	c0 
c0103eed:	c7 44 24 04 36 02 00 	movl   $0x236,0x4(%esp)
c0103ef4:	00 
c0103ef5:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103efc:	e8 f8 c4 ff ff       	call   c01003f9 <__panic>
    for (i = 0; i < npage; i += PGSIZE) {
c0103f01:	81 45 f4 00 10 00 00 	addl   $0x1000,-0xc(%ebp)
c0103f08:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0103f0b:	a1 80 be 11 c0       	mov    0xc011be80,%eax
c0103f10:	39 c2                	cmp    %eax,%edx
c0103f12:	0f 82 26 ff ff ff    	jb     c0103e3e <check_boot_pgdir+0x12>
    }

    assert(PDE_ADDR(boot_pgdir[PDX(VPT)]) == PADDR(boot_pgdir));
c0103f18:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103f1d:	05 ac 0f 00 00       	add    $0xfac,%eax
c0103f22:	8b 00                	mov    (%eax),%eax
c0103f24:	25 00 f0 ff ff       	and    $0xfffff000,%eax
c0103f29:	89 c2                	mov    %eax,%edx
c0103f2b:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103f30:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0103f33:	81 7d f0 ff ff ff bf 	cmpl   $0xbfffffff,-0x10(%ebp)
c0103f3a:	77 23                	ja     c0103f5f <check_boot_pgdir+0x133>
c0103f3c:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103f3f:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0103f43:	c7 44 24 08 84 69 10 	movl   $0xc0106984,0x8(%esp)
c0103f4a:	c0 
c0103f4b:	c7 44 24 04 39 02 00 	movl   $0x239,0x4(%esp)
c0103f52:	00 
c0103f53:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103f5a:	e8 9a c4 ff ff       	call   c01003f9 <__panic>
c0103f5f:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0103f62:	05 00 00 00 40       	add    $0x40000000,%eax
c0103f67:	39 d0                	cmp    %edx,%eax
c0103f69:	74 24                	je     c0103f8f <check_boot_pgdir+0x163>
c0103f6b:	c7 44 24 0c 0c 6d 10 	movl   $0xc0106d0c,0xc(%esp)
c0103f72:	c0 
c0103f73:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103f7a:	c0 
c0103f7b:	c7 44 24 04 39 02 00 	movl   $0x239,0x4(%esp)
c0103f82:	00 
c0103f83:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103f8a:	e8 6a c4 ff ff       	call   c01003f9 <__panic>

    assert(boot_pgdir[0] == 0);
c0103f8f:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103f94:	8b 00                	mov    (%eax),%eax
c0103f96:	85 c0                	test   %eax,%eax
c0103f98:	74 24                	je     c0103fbe <check_boot_pgdir+0x192>
c0103f9a:	c7 44 24 0c 40 6d 10 	movl   $0xc0106d40,0xc(%esp)
c0103fa1:	c0 
c0103fa2:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0103fa9:	c0 
c0103faa:	c7 44 24 04 3b 02 00 	movl   $0x23b,0x4(%esp)
c0103fb1:	00 
c0103fb2:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0103fb9:	e8 3b c4 ff ff       	call   c01003f9 <__panic>

    struct Page *p;
    p = alloc_page();
c0103fbe:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0103fc5:	e8 a1 ed ff ff       	call   c0102d6b <alloc_pages>
c0103fca:	89 45 ec             	mov    %eax,-0x14(%ebp)
    assert(page_insert(boot_pgdir, p, 0x100, PTE_W) == 0);
c0103fcd:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0103fd2:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
c0103fd9:	00 
c0103fda:	c7 44 24 08 00 01 00 	movl   $0x100,0x8(%esp)
c0103fe1:	00 
c0103fe2:	8b 55 ec             	mov    -0x14(%ebp),%edx
c0103fe5:	89 54 24 04          	mov    %edx,0x4(%esp)
c0103fe9:	89 04 24             	mov    %eax,(%esp)
c0103fec:	e8 6b f6 ff ff       	call   c010365c <page_insert>
c0103ff1:	85 c0                	test   %eax,%eax
c0103ff3:	74 24                	je     c0104019 <check_boot_pgdir+0x1ed>
c0103ff5:	c7 44 24 0c 54 6d 10 	movl   $0xc0106d54,0xc(%esp)
c0103ffc:	c0 
c0103ffd:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0104004:	c0 
c0104005:	c7 44 24 04 3f 02 00 	movl   $0x23f,0x4(%esp)
c010400c:	00 
c010400d:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0104014:	e8 e0 c3 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p) == 1);
c0104019:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010401c:	89 04 24             	mov    %eax,(%esp)
c010401f:	e8 42 eb ff ff       	call   c0102b66 <page_ref>
c0104024:	83 f8 01             	cmp    $0x1,%eax
c0104027:	74 24                	je     c010404d <check_boot_pgdir+0x221>
c0104029:	c7 44 24 0c 82 6d 10 	movl   $0xc0106d82,0xc(%esp)
c0104030:	c0 
c0104031:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0104038:	c0 
c0104039:	c7 44 24 04 40 02 00 	movl   $0x240,0x4(%esp)
c0104040:	00 
c0104041:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0104048:	e8 ac c3 ff ff       	call   c01003f9 <__panic>
    assert(page_insert(boot_pgdir, p, 0x100 + PGSIZE, PTE_W) == 0);
c010404d:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0104052:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
c0104059:	00 
c010405a:	c7 44 24 08 00 11 00 	movl   $0x1100,0x8(%esp)
c0104061:	00 
c0104062:	8b 55 ec             	mov    -0x14(%ebp),%edx
c0104065:	89 54 24 04          	mov    %edx,0x4(%esp)
c0104069:	89 04 24             	mov    %eax,(%esp)
c010406c:	e8 eb f5 ff ff       	call   c010365c <page_insert>
c0104071:	85 c0                	test   %eax,%eax
c0104073:	74 24                	je     c0104099 <check_boot_pgdir+0x26d>
c0104075:	c7 44 24 0c 94 6d 10 	movl   $0xc0106d94,0xc(%esp)
c010407c:	c0 
c010407d:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0104084:	c0 
c0104085:	c7 44 24 04 41 02 00 	movl   $0x241,0x4(%esp)
c010408c:	00 
c010408d:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0104094:	e8 60 c3 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p) == 2);
c0104099:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010409c:	89 04 24             	mov    %eax,(%esp)
c010409f:	e8 c2 ea ff ff       	call   c0102b66 <page_ref>
c01040a4:	83 f8 02             	cmp    $0x2,%eax
c01040a7:	74 24                	je     c01040cd <check_boot_pgdir+0x2a1>
c01040a9:	c7 44 24 0c cb 6d 10 	movl   $0xc0106dcb,0xc(%esp)
c01040b0:	c0 
c01040b1:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c01040b8:	c0 
c01040b9:	c7 44 24 04 42 02 00 	movl   $0x242,0x4(%esp)
c01040c0:	00 
c01040c1:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c01040c8:	e8 2c c3 ff ff       	call   c01003f9 <__panic>

    const char *str = "ucore: Hello world!!";
c01040cd:	c7 45 e8 dc 6d 10 c0 	movl   $0xc0106ddc,-0x18(%ebp)
    strcpy((void *)0x100, str);
c01040d4:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01040d7:	89 44 24 04          	mov    %eax,0x4(%esp)
c01040db:	c7 04 24 00 01 00 00 	movl   $0x100,(%esp)
c01040e2:	e8 d3 15 00 00       	call   c01056ba <strcpy>
    assert(strcmp((void *)0x100, (void *)(0x100 + PGSIZE)) == 0);
c01040e7:	c7 44 24 04 00 11 00 	movl   $0x1100,0x4(%esp)
c01040ee:	00 
c01040ef:	c7 04 24 00 01 00 00 	movl   $0x100,(%esp)
c01040f6:	e8 36 16 00 00       	call   c0105731 <strcmp>
c01040fb:	85 c0                	test   %eax,%eax
c01040fd:	74 24                	je     c0104123 <check_boot_pgdir+0x2f7>
c01040ff:	c7 44 24 0c f4 6d 10 	movl   $0xc0106df4,0xc(%esp)
c0104106:	c0 
c0104107:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c010410e:	c0 
c010410f:	c7 44 24 04 46 02 00 	movl   $0x246,0x4(%esp)
c0104116:	00 
c0104117:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c010411e:	e8 d6 c2 ff ff       	call   c01003f9 <__panic>

    *(char *)(page2kva(p) + 0x100) = '\0';
c0104123:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104126:	89 04 24             	mov    %eax,(%esp)
c0104129:	e8 8e e9 ff ff       	call   c0102abc <page2kva>
c010412e:	05 00 01 00 00       	add    $0x100,%eax
c0104133:	c6 00 00             	movb   $0x0,(%eax)
    assert(strlen((const char *)0x100) == 0);
c0104136:	c7 04 24 00 01 00 00 	movl   $0x100,(%esp)
c010413d:	e8 22 15 00 00       	call   c0105664 <strlen>
c0104142:	85 c0                	test   %eax,%eax
c0104144:	74 24                	je     c010416a <check_boot_pgdir+0x33e>
c0104146:	c7 44 24 0c 2c 6e 10 	movl   $0xc0106e2c,0xc(%esp)
c010414d:	c0 
c010414e:	c7 44 24 08 cd 69 10 	movl   $0xc01069cd,0x8(%esp)
c0104155:	c0 
c0104156:	c7 44 24 04 49 02 00 	movl   $0x249,0x4(%esp)
c010415d:	00 
c010415e:	c7 04 24 a8 69 10 c0 	movl   $0xc01069a8,(%esp)
c0104165:	e8 8f c2 ff ff       	call   c01003f9 <__panic>

    free_page(p);
c010416a:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104171:	00 
c0104172:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104175:	89 04 24             	mov    %eax,(%esp)
c0104178:	e8 26 ec ff ff       	call   c0102da3 <free_pages>
    free_page(pde2page(boot_pgdir[0]));
c010417d:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c0104182:	8b 00                	mov    (%eax),%eax
c0104184:	89 04 24             	mov    %eax,(%esp)
c0104187:	e8 c2 e9 ff ff       	call   c0102b4e <pde2page>
c010418c:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104193:	00 
c0104194:	89 04 24             	mov    %eax,(%esp)
c0104197:	e8 07 ec ff ff       	call   c0102da3 <free_pages>
    boot_pgdir[0] = 0;
c010419c:	a1 e0 89 11 c0       	mov    0xc01189e0,%eax
c01041a1:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

    cprintf("check_boot_pgdir() succeeded!\n");
c01041a7:	c7 04 24 50 6e 10 c0 	movl   $0xc0106e50,(%esp)
c01041ae:	e8 ef c0 ff ff       	call   c01002a2 <cprintf>
}
c01041b3:	90                   	nop
c01041b4:	c9                   	leave  
c01041b5:	c3                   	ret    

c01041b6 <perm2str>:

//perm2str - use string 'u,r,w,-' to present the permission
static const char *
perm2str(int perm) {
c01041b6:	55                   	push   %ebp
c01041b7:	89 e5                	mov    %esp,%ebp
    static char str[4];
    str[0] = (perm & PTE_U) ? 'u' : '-';
c01041b9:	8b 45 08             	mov    0x8(%ebp),%eax
c01041bc:	83 e0 04             	and    $0x4,%eax
c01041bf:	85 c0                	test   %eax,%eax
c01041c1:	74 04                	je     c01041c7 <perm2str+0x11>
c01041c3:	b0 75                	mov    $0x75,%al
c01041c5:	eb 02                	jmp    c01041c9 <perm2str+0x13>
c01041c7:	b0 2d                	mov    $0x2d,%al
c01041c9:	a2 08 bf 11 c0       	mov    %al,0xc011bf08
    str[1] = 'r';
c01041ce:	c6 05 09 bf 11 c0 72 	movb   $0x72,0xc011bf09
    str[2] = (perm & PTE_W) ? 'w' : '-';
c01041d5:	8b 45 08             	mov    0x8(%ebp),%eax
c01041d8:	83 e0 02             	and    $0x2,%eax
c01041db:	85 c0                	test   %eax,%eax
c01041dd:	74 04                	je     c01041e3 <perm2str+0x2d>
c01041df:	b0 77                	mov    $0x77,%al
c01041e1:	eb 02                	jmp    c01041e5 <perm2str+0x2f>
c01041e3:	b0 2d                	mov    $0x2d,%al
c01041e5:	a2 0a bf 11 c0       	mov    %al,0xc011bf0a
    str[3] = '\0';
c01041ea:	c6 05 0b bf 11 c0 00 	movb   $0x0,0xc011bf0b
    return str;
c01041f1:	b8 08 bf 11 c0       	mov    $0xc011bf08,%eax
}
c01041f6:	5d                   	pop    %ebp
c01041f7:	c3                   	ret    

c01041f8 <get_pgtable_items>:
//  table:       the beginning addr of table
//  left_store:  the pointer of the high side of table's next range
//  right_store: the pointer of the low side of table's next range
// return value: 0 - not a invalid item range, perm - a valid item range with perm permission 
static int
get_pgtable_items(size_t left, size_t right, size_t start, uintptr_t *table, size_t *left_store, size_t *right_store) {
c01041f8:	55                   	push   %ebp
c01041f9:	89 e5                	mov    %esp,%ebp
c01041fb:	83 ec 10             	sub    $0x10,%esp
    if (start >= right) {
c01041fe:	8b 45 10             	mov    0x10(%ebp),%eax
c0104201:	3b 45 0c             	cmp    0xc(%ebp),%eax
c0104204:	72 0d                	jb     c0104213 <get_pgtable_items+0x1b>
        return 0;
c0104206:	b8 00 00 00 00       	mov    $0x0,%eax
c010420b:	e9 98 00 00 00       	jmp    c01042a8 <get_pgtable_items+0xb0>
    }
    while (start < right && !(table[start] & PTE_P)) {
        start ++;
c0104210:	ff 45 10             	incl   0x10(%ebp)
    while (start < right && !(table[start] & PTE_P)) {
c0104213:	8b 45 10             	mov    0x10(%ebp),%eax
c0104216:	3b 45 0c             	cmp    0xc(%ebp),%eax
c0104219:	73 18                	jae    c0104233 <get_pgtable_items+0x3b>
c010421b:	8b 45 10             	mov    0x10(%ebp),%eax
c010421e:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
c0104225:	8b 45 14             	mov    0x14(%ebp),%eax
c0104228:	01 d0                	add    %edx,%eax
c010422a:	8b 00                	mov    (%eax),%eax
c010422c:	83 e0 01             	and    $0x1,%eax
c010422f:	85 c0                	test   %eax,%eax
c0104231:	74 dd                	je     c0104210 <get_pgtable_items+0x18>
    }
    if (start < right) {
c0104233:	8b 45 10             	mov    0x10(%ebp),%eax
c0104236:	3b 45 0c             	cmp    0xc(%ebp),%eax
c0104239:	73 68                	jae    c01042a3 <get_pgtable_items+0xab>
        if (left_store != NULL) {
c010423b:	83 7d 18 00          	cmpl   $0x0,0x18(%ebp)
c010423f:	74 08                	je     c0104249 <get_pgtable_items+0x51>
            *left_store = start;
c0104241:	8b 45 18             	mov    0x18(%ebp),%eax
c0104244:	8b 55 10             	mov    0x10(%ebp),%edx
c0104247:	89 10                	mov    %edx,(%eax)
        }
        int perm = (table[start ++] & PTE_USER);
c0104249:	8b 45 10             	mov    0x10(%ebp),%eax
c010424c:	8d 50 01             	lea    0x1(%eax),%edx
c010424f:	89 55 10             	mov    %edx,0x10(%ebp)
c0104252:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
c0104259:	8b 45 14             	mov    0x14(%ebp),%eax
c010425c:	01 d0                	add    %edx,%eax
c010425e:	8b 00                	mov    (%eax),%eax
c0104260:	83 e0 07             	and    $0x7,%eax
c0104263:	89 45 fc             	mov    %eax,-0x4(%ebp)
        while (start < right && (table[start] & PTE_USER) == perm) {
c0104266:	eb 03                	jmp    c010426b <get_pgtable_items+0x73>
            start ++;
c0104268:	ff 45 10             	incl   0x10(%ebp)
        while (start < right && (table[start] & PTE_USER) == perm) {
c010426b:	8b 45 10             	mov    0x10(%ebp),%eax
c010426e:	3b 45 0c             	cmp    0xc(%ebp),%eax
c0104271:	73 1d                	jae    c0104290 <get_pgtable_items+0x98>
c0104273:	8b 45 10             	mov    0x10(%ebp),%eax
c0104276:	8d 14 85 00 00 00 00 	lea    0x0(,%eax,4),%edx
c010427d:	8b 45 14             	mov    0x14(%ebp),%eax
c0104280:	01 d0                	add    %edx,%eax
c0104282:	8b 00                	mov    (%eax),%eax
c0104284:	83 e0 07             	and    $0x7,%eax
c0104287:	89 c2                	mov    %eax,%edx
c0104289:	8b 45 fc             	mov    -0x4(%ebp),%eax
c010428c:	39 c2                	cmp    %eax,%edx
c010428e:	74 d8                	je     c0104268 <get_pgtable_items+0x70>
        }
        if (right_store != NULL) {
c0104290:	83 7d 1c 00          	cmpl   $0x0,0x1c(%ebp)
c0104294:	74 08                	je     c010429e <get_pgtable_items+0xa6>
            *right_store = start;
c0104296:	8b 45 1c             	mov    0x1c(%ebp),%eax
c0104299:	8b 55 10             	mov    0x10(%ebp),%edx
c010429c:	89 10                	mov    %edx,(%eax)
        }
        return perm;
c010429e:	8b 45 fc             	mov    -0x4(%ebp),%eax
c01042a1:	eb 05                	jmp    c01042a8 <get_pgtable_items+0xb0>
    }
    return 0;
c01042a3:	b8 00 00 00 00       	mov    $0x0,%eax
}
c01042a8:	c9                   	leave  
c01042a9:	c3                   	ret    

c01042aa <print_pgdir>:

//print_pgdir - print the PDT&PT
void
print_pgdir(void) {
c01042aa:	55                   	push   %ebp
c01042ab:	89 e5                	mov    %esp,%ebp
c01042ad:	57                   	push   %edi
c01042ae:	56                   	push   %esi
c01042af:	53                   	push   %ebx
c01042b0:	83 ec 4c             	sub    $0x4c,%esp
    cprintf("-------------------- BEGIN --------------------\n");
c01042b3:	c7 04 24 70 6e 10 c0 	movl   $0xc0106e70,(%esp)
c01042ba:	e8 e3 bf ff ff       	call   c01002a2 <cprintf>
    size_t left, right = 0, perm;
c01042bf:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
    while ((perm = get_pgtable_items(0, NPDEENTRY, right, vpd, &left, &right)) != 0) {
c01042c6:	e9 fa 00 00 00       	jmp    c01043c5 <print_pgdir+0x11b>
        cprintf("PDE(%03x) %08x-%08x %08x %s\n", right - left,
c01042cb:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c01042ce:	89 04 24             	mov    %eax,(%esp)
c01042d1:	e8 e0 fe ff ff       	call   c01041b6 <perm2str>
                left * PTSIZE, right * PTSIZE, (right - left) * PTSIZE, perm2str(perm));
c01042d6:	8b 4d dc             	mov    -0x24(%ebp),%ecx
c01042d9:	8b 55 e0             	mov    -0x20(%ebp),%edx
c01042dc:	29 d1                	sub    %edx,%ecx
c01042de:	89 ca                	mov    %ecx,%edx
        cprintf("PDE(%03x) %08x-%08x %08x %s\n", right - left,
c01042e0:	89 d6                	mov    %edx,%esi
c01042e2:	c1 e6 16             	shl    $0x16,%esi
c01042e5:	8b 55 dc             	mov    -0x24(%ebp),%edx
c01042e8:	89 d3                	mov    %edx,%ebx
c01042ea:	c1 e3 16             	shl    $0x16,%ebx
c01042ed:	8b 55 e0             	mov    -0x20(%ebp),%edx
c01042f0:	89 d1                	mov    %edx,%ecx
c01042f2:	c1 e1 16             	shl    $0x16,%ecx
c01042f5:	8b 7d dc             	mov    -0x24(%ebp),%edi
c01042f8:	8b 55 e0             	mov    -0x20(%ebp),%edx
c01042fb:	29 d7                	sub    %edx,%edi
c01042fd:	89 fa                	mov    %edi,%edx
c01042ff:	89 44 24 14          	mov    %eax,0x14(%esp)
c0104303:	89 74 24 10          	mov    %esi,0x10(%esp)
c0104307:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c010430b:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c010430f:	89 54 24 04          	mov    %edx,0x4(%esp)
c0104313:	c7 04 24 a1 6e 10 c0 	movl   $0xc0106ea1,(%esp)
c010431a:	e8 83 bf ff ff       	call   c01002a2 <cprintf>
        size_t l, r = left * NPTEENTRY;
c010431f:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0104322:	c1 e0 0a             	shl    $0xa,%eax
c0104325:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        while ((perm = get_pgtable_items(left * NPTEENTRY, right * NPTEENTRY, r, vpt, &l, &r)) != 0) {
c0104328:	eb 54                	jmp    c010437e <print_pgdir+0xd4>
            cprintf("  |-- PTE(%05x) %08x-%08x %08x %s\n", r - l,
c010432a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c010432d:	89 04 24             	mov    %eax,(%esp)
c0104330:	e8 81 fe ff ff       	call   c01041b6 <perm2str>
                    l * PGSIZE, r * PGSIZE, (r - l) * PGSIZE, perm2str(perm));
c0104335:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
c0104338:	8b 55 d8             	mov    -0x28(%ebp),%edx
c010433b:	29 d1                	sub    %edx,%ecx
c010433d:	89 ca                	mov    %ecx,%edx
            cprintf("  |-- PTE(%05x) %08x-%08x %08x %s\n", r - l,
c010433f:	89 d6                	mov    %edx,%esi
c0104341:	c1 e6 0c             	shl    $0xc,%esi
c0104344:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0104347:	89 d3                	mov    %edx,%ebx
c0104349:	c1 e3 0c             	shl    $0xc,%ebx
c010434c:	8b 55 d8             	mov    -0x28(%ebp),%edx
c010434f:	89 d1                	mov    %edx,%ecx
c0104351:	c1 e1 0c             	shl    $0xc,%ecx
c0104354:	8b 7d d4             	mov    -0x2c(%ebp),%edi
c0104357:	8b 55 d8             	mov    -0x28(%ebp),%edx
c010435a:	29 d7                	sub    %edx,%edi
c010435c:	89 fa                	mov    %edi,%edx
c010435e:	89 44 24 14          	mov    %eax,0x14(%esp)
c0104362:	89 74 24 10          	mov    %esi,0x10(%esp)
c0104366:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c010436a:	89 4c 24 08          	mov    %ecx,0x8(%esp)
c010436e:	89 54 24 04          	mov    %edx,0x4(%esp)
c0104372:	c7 04 24 c0 6e 10 c0 	movl   $0xc0106ec0,(%esp)
c0104379:	e8 24 bf ff ff       	call   c01002a2 <cprintf>
        while ((perm = get_pgtable_items(left * NPTEENTRY, right * NPTEENTRY, r, vpt, &l, &r)) != 0) {
c010437e:	be 00 00 c0 fa       	mov    $0xfac00000,%esi
c0104383:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c0104386:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0104389:	89 d3                	mov    %edx,%ebx
c010438b:	c1 e3 0a             	shl    $0xa,%ebx
c010438e:	8b 55 e0             	mov    -0x20(%ebp),%edx
c0104391:	89 d1                	mov    %edx,%ecx
c0104393:	c1 e1 0a             	shl    $0xa,%ecx
c0104396:	8d 55 d4             	lea    -0x2c(%ebp),%edx
c0104399:	89 54 24 14          	mov    %edx,0x14(%esp)
c010439d:	8d 55 d8             	lea    -0x28(%ebp),%edx
c01043a0:	89 54 24 10          	mov    %edx,0x10(%esp)
c01043a4:	89 74 24 0c          	mov    %esi,0xc(%esp)
c01043a8:	89 44 24 08          	mov    %eax,0x8(%esp)
c01043ac:	89 5c 24 04          	mov    %ebx,0x4(%esp)
c01043b0:	89 0c 24             	mov    %ecx,(%esp)
c01043b3:	e8 40 fe ff ff       	call   c01041f8 <get_pgtable_items>
c01043b8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c01043bb:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
c01043bf:	0f 85 65 ff ff ff    	jne    c010432a <print_pgdir+0x80>
    while ((perm = get_pgtable_items(0, NPDEENTRY, right, vpd, &left, &right)) != 0) {
c01043c5:	b9 00 b0 fe fa       	mov    $0xfafeb000,%ecx
c01043ca:	8b 45 dc             	mov    -0x24(%ebp),%eax
c01043cd:	8d 55 dc             	lea    -0x24(%ebp),%edx
c01043d0:	89 54 24 14          	mov    %edx,0x14(%esp)
c01043d4:	8d 55 e0             	lea    -0x20(%ebp),%edx
c01043d7:	89 54 24 10          	mov    %edx,0x10(%esp)
c01043db:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
c01043df:	89 44 24 08          	mov    %eax,0x8(%esp)
c01043e3:	c7 44 24 04 00 04 00 	movl   $0x400,0x4(%esp)
c01043ea:	00 
c01043eb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
c01043f2:	e8 01 fe ff ff       	call   c01041f8 <get_pgtable_items>
c01043f7:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c01043fa:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
c01043fe:	0f 85 c7 fe ff ff    	jne    c01042cb <print_pgdir+0x21>
        }
    }
    cprintf("--------------------- END ---------------------\n");
c0104404:	c7 04 24 e4 6e 10 c0 	movl   $0xc0106ee4,(%esp)
c010440b:	e8 92 be ff ff       	call   c01002a2 <cprintf>
}
c0104410:	90                   	nop
c0104411:	83 c4 4c             	add    $0x4c,%esp
c0104414:	5b                   	pop    %ebx
c0104415:	5e                   	pop    %esi
c0104416:	5f                   	pop    %edi
c0104417:	5d                   	pop    %ebp
c0104418:	c3                   	ret    

c0104419 <page2ppn>:
page2ppn(struct Page *page) {
c0104419:	55                   	push   %ebp
c010441a:	89 e5                	mov    %esp,%ebp
    return page - pages;
c010441c:	8b 45 08             	mov    0x8(%ebp),%eax
c010441f:	8b 15 78 bf 11 c0    	mov    0xc011bf78,%edx
c0104425:	29 d0                	sub    %edx,%eax
c0104427:	c1 f8 02             	sar    $0x2,%eax
c010442a:	69 c0 cd cc cc cc    	imul   $0xcccccccd,%eax,%eax
}
c0104430:	5d                   	pop    %ebp
c0104431:	c3                   	ret    

c0104432 <page2pa>:
page2pa(struct Page *page) {
c0104432:	55                   	push   %ebp
c0104433:	89 e5                	mov    %esp,%ebp
c0104435:	83 ec 04             	sub    $0x4,%esp
    return page2ppn(page) << PGSHIFT;
c0104438:	8b 45 08             	mov    0x8(%ebp),%eax
c010443b:	89 04 24             	mov    %eax,(%esp)
c010443e:	e8 d6 ff ff ff       	call   c0104419 <page2ppn>
c0104443:	c1 e0 0c             	shl    $0xc,%eax
}
c0104446:	c9                   	leave  
c0104447:	c3                   	ret    

c0104448 <page_ref>:
page_ref(struct Page *page) {
c0104448:	55                   	push   %ebp
c0104449:	89 e5                	mov    %esp,%ebp
    return page->ref;
c010444b:	8b 45 08             	mov    0x8(%ebp),%eax
c010444e:	8b 00                	mov    (%eax),%eax
}
c0104450:	5d                   	pop    %ebp
c0104451:	c3                   	ret    

c0104452 <set_page_ref>:
set_page_ref(struct Page *page, int val) {
c0104452:	55                   	push   %ebp
c0104453:	89 e5                	mov    %esp,%ebp
    page->ref = val;
c0104455:	8b 45 08             	mov    0x8(%ebp),%eax
c0104458:	8b 55 0c             	mov    0xc(%ebp),%edx
c010445b:	89 10                	mov    %edx,(%eax)
}
c010445d:	90                   	nop
c010445e:	5d                   	pop    %ebp
c010445f:	c3                   	ret    

c0104460 <default_init>:

#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

static void
default_init(void) {
c0104460:	55                   	push   %ebp
c0104461:	89 e5                	mov    %esp,%ebp
c0104463:	83 ec 10             	sub    $0x10,%esp
c0104466:	c7 45 fc 7c bf 11 c0 	movl   $0xc011bf7c,-0x4(%ebp)
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
c010446d:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0104470:	8b 55 fc             	mov    -0x4(%ebp),%edx
c0104473:	89 50 04             	mov    %edx,0x4(%eax)
c0104476:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0104479:	8b 50 04             	mov    0x4(%eax),%edx
c010447c:	8b 45 fc             	mov    -0x4(%ebp),%eax
c010447f:	89 10                	mov    %edx,(%eax)
    list_init(&free_list);
    nr_free = 0;
c0104481:	c7 05 84 bf 11 c0 00 	movl   $0x0,0xc011bf84
c0104488:	00 00 00 
}
c010448b:	90                   	nop
c010448c:	c9                   	leave  
c010448d:	c3                   	ret    

c010448e <default_init_memmap>:
// 2、将其连续空页数量设置为0，即p->property。
//3、映射到此物理页的虚拟页数量置为0，调用set_page_ref函数
//4、插入到双向链表中，free_list因为宏定义的原因，指的是free_area_t中的list结构。
//5、基地址连续空闲页数量加n，且空闲页数量加n。
static void
default_init_memmap(struct Page *base, size_t n) {
c010448e:	55                   	push   %ebp
c010448f:	89 e5                	mov    %esp,%ebp
c0104491:	83 ec 48             	sub    $0x48,%esp
    assert(n > 0);
c0104494:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
c0104498:	75 24                	jne    c01044be <default_init_memmap+0x30>
c010449a:	c7 44 24 0c 18 6f 10 	movl   $0xc0106f18,0xc(%esp)
c01044a1:	c0 
c01044a2:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01044a9:	c0 
c01044aa:	c7 44 24 04 7b 00 00 	movl   $0x7b,0x4(%esp)
c01044b1:	00 
c01044b2:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01044b9:	e8 3b bf ff ff       	call   c01003f9 <__panic>
    struct Page *p = base;
c01044be:	8b 45 08             	mov    0x8(%ebp),%eax
c01044c1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    for (; p != base + n; p ++) {
c01044c4:	eb 7d                	jmp    c0104543 <default_init_memmap+0xb5>
        assert(PageReserved(p));
c01044c6:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01044c9:	83 c0 04             	add    $0x4,%eax
c01044cc:	c7 45 f0 00 00 00 00 	movl   $0x0,-0x10(%ebp)
c01044d3:	89 45 ec             	mov    %eax,-0x14(%ebp)
 * @addr:   the address to count from
 * */
static inline bool
test_bit(int nr, volatile void *addr) {
    int oldbit;
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c01044d6:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01044d9:	8b 55 f0             	mov    -0x10(%ebp),%edx
c01044dc:	0f a3 10             	bt     %edx,(%eax)
c01044df:	19 c0                	sbb    %eax,%eax
c01044e1:	89 45 e8             	mov    %eax,-0x18(%ebp)
    return oldbit != 0;
c01044e4:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c01044e8:	0f 95 c0             	setne  %al
c01044eb:	0f b6 c0             	movzbl %al,%eax
c01044ee:	85 c0                	test   %eax,%eax
c01044f0:	75 24                	jne    c0104516 <default_init_memmap+0x88>
c01044f2:	c7 44 24 0c 49 6f 10 	movl   $0xc0106f49,0xc(%esp)
c01044f9:	c0 
c01044fa:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104501:	c0 
c0104502:	c7 44 24 04 7e 00 00 	movl   $0x7e,0x4(%esp)
c0104509:	00 
c010450a:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104511:	e8 e3 be ff ff       	call   c01003f9 <__panic>
        p->flags = p->property = 0;
c0104516:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104519:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
c0104520:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104523:	8b 50 08             	mov    0x8(%eax),%edx
c0104526:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104529:	89 50 04             	mov    %edx,0x4(%eax)
        set_page_ref(p, 0);
c010452c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0104533:	00 
c0104534:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104537:	89 04 24             	mov    %eax,(%esp)
c010453a:	e8 13 ff ff ff       	call   c0104452 <set_page_ref>
    for (; p != base + n; p ++) {
c010453f:	83 45 f4 14          	addl   $0x14,-0xc(%ebp)
c0104543:	8b 55 0c             	mov    0xc(%ebp),%edx
c0104546:	89 d0                	mov    %edx,%eax
c0104548:	c1 e0 02             	shl    $0x2,%eax
c010454b:	01 d0                	add    %edx,%eax
c010454d:	c1 e0 02             	shl    $0x2,%eax
c0104550:	89 c2                	mov    %eax,%edx
c0104552:	8b 45 08             	mov    0x8(%ebp),%eax
c0104555:	01 d0                	add    %edx,%eax
c0104557:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c010455a:	0f 85 66 ff ff ff    	jne    c01044c6 <default_init_memmap+0x38>
    }
    base->property = n;
c0104560:	8b 45 08             	mov    0x8(%ebp),%eax
c0104563:	8b 55 0c             	mov    0xc(%ebp),%edx
c0104566:	89 50 08             	mov    %edx,0x8(%eax)
    SetPageProperty(base);
c0104569:	8b 45 08             	mov    0x8(%ebp),%eax
c010456c:	83 c0 04             	add    $0x4,%eax
c010456f:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
c0104576:	89 45 cc             	mov    %eax,-0x34(%ebp)
    asm volatile ("btsl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
c0104579:	8b 45 cc             	mov    -0x34(%ebp),%eax
c010457c:	8b 55 d0             	mov    -0x30(%ebp),%edx
c010457f:	0f ab 10             	bts    %edx,(%eax)
    nr_free += n;
c0104582:	8b 15 84 bf 11 c0    	mov    0xc011bf84,%edx
c0104588:	8b 45 0c             	mov    0xc(%ebp),%eax
c010458b:	01 d0                	add    %edx,%eax
c010458d:	a3 84 bf 11 c0       	mov    %eax,0xc011bf84
    //下面这句要从list_add改成list_add_before
    list_add_before(&free_list, &(base->page_link));
c0104592:	8b 45 08             	mov    0x8(%ebp),%eax
c0104595:	83 c0 0c             	add    $0xc,%eax
c0104598:	c7 45 e4 7c bf 11 c0 	movl   $0xc011bf7c,-0x1c(%ebp)
c010459f:	89 45 e0             	mov    %eax,-0x20(%ebp)
 * Insert the new element @elm *before* the element @listelm which
 * is already in the list.
 * */
static inline void
list_add_before(list_entry_t *listelm, list_entry_t *elm) {
    __list_add(elm, listelm->prev, listelm);
c01045a2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c01045a5:	8b 00                	mov    (%eax),%eax
c01045a7:	8b 55 e0             	mov    -0x20(%ebp),%edx
c01045aa:	89 55 dc             	mov    %edx,-0x24(%ebp)
c01045ad:	89 45 d8             	mov    %eax,-0x28(%ebp)
c01045b0:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c01045b3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
c01045b6:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c01045b9:	8b 55 dc             	mov    -0x24(%ebp),%edx
c01045bc:	89 10                	mov    %edx,(%eax)
c01045be:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c01045c1:	8b 10                	mov    (%eax),%edx
c01045c3:	8b 45 d8             	mov    -0x28(%ebp),%eax
c01045c6:	89 50 04             	mov    %edx,0x4(%eax)
    elm->next = next;
c01045c9:	8b 45 dc             	mov    -0x24(%ebp),%eax
c01045cc:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c01045cf:	89 50 04             	mov    %edx,0x4(%eax)
    elm->prev = prev;
c01045d2:	8b 45 dc             	mov    -0x24(%ebp),%eax
c01045d5:	8b 55 d8             	mov    -0x28(%ebp),%edx
c01045d8:	89 10                	mov    %edx,(%eax)
}
c01045da:	90                   	nop
c01045db:	c9                   	leave  
c01045dc:	c3                   	ret    

c01045dd <default_alloc_pages>:
//firstfit需要从空闲链表头开始查找最小的地址，通过list_next找到下一个空闲块元素，
//通过le2page宏可以由链表元素获得对应的Page指针p。通过p->property可以了解此空闲块的大小。
//如果>=n，这就找到了！如果<n，则list_next，继续查找。直到list_next== &free_list，这表示找完了一遍了。
//找到后，就要从新组织空闲块，然后把找到的page返回。
static struct Page *
default_alloc_pages(size_t n) {//参数n表示要分配n个页
c01045dd:	55                   	push   %ebp
c01045de:	89 e5                	mov    %esp,%ebp
c01045e0:	83 ec 68             	sub    $0x68,%esp
    assert(n > 0);
c01045e3:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
c01045e7:	75 24                	jne    c010460d <default_alloc_pages+0x30>
c01045e9:	c7 44 24 0c 18 6f 10 	movl   $0xc0106f18,0xc(%esp)
c01045f0:	c0 
c01045f1:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01045f8:	c0 
c01045f9:	c7 44 24 04 8f 00 00 	movl   $0x8f,0x4(%esp)
c0104600:	00 
c0104601:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104608:	e8 ec bd ff ff       	call   c01003f9 <__panic>
    if (n > nr_free) {  //首先判断空闲页的大小是否大于所需的页块大小。 如果需要分配的页面数量n，已经大于了空闲页的数量，那么直接return NULL分配失败。
c010460d:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
c0104612:	39 45 08             	cmp    %eax,0x8(%ebp)
c0104615:	76 0a                	jbe    c0104621 <default_alloc_pages+0x44>
        return NULL;
c0104617:	b8 00 00 00 00       	mov    $0x0,%eax
c010461c:	e9 3b 01 00 00       	jmp    c010475c <default_alloc_pages+0x17f>
    }
    struct Page *page = NULL;
c0104621:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    list_entry_t *le = &free_list;
c0104628:	c7 45 f0 7c bf 11 c0 	movl   $0xc011bf7c,-0x10(%ebp)
    while ((le = list_next(le)) != &free_list) { //search the free list  寻找一个可分配的连续页
c010462f:	eb 1c                	jmp    c010464d <default_alloc_pages+0x70>
        //遍历整个空闲链表。如果找到合适的空闲页，即p->property >= n（从该页开始，连续的空闲页数量大于n），
        //即可认为可分配，重新设置标志位。具体操作是调用SetPageReserved(pp)和ClearPageProperty(pp)，
        //设置当前页面预留，以及清空该页面的连续空闲页面数量值。
        struct Page *p = le2page(le, page_link);
c0104631:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104634:	83 e8 0c             	sub    $0xc,%eax
c0104637:	89 45 ec             	mov    %eax,-0x14(%ebp)
        if (p->property >= n) { // If we find this `p`, it means we've found a free block with its size>= n, whose first `n` pages can be malloced
c010463a:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010463d:	8b 40 08             	mov    0x8(%eax),%eax
c0104640:	39 45 08             	cmp    %eax,0x8(%ebp)
c0104643:	77 08                	ja     c010464d <default_alloc_pages+0x70>
            page = p;  
c0104645:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104648:	89 45 f4             	mov    %eax,-0xc(%ebp)
            break;
c010464b:	eb 18                	jmp    c0104665 <default_alloc_pages+0x88>
c010464d:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104650:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    return listelm->next;
c0104653:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0104656:	8b 40 04             	mov    0x4(%eax),%eax
    while ((le = list_next(le)) != &free_list) { //search the free list  寻找一个可分配的连续页
c0104659:	89 45 f0             	mov    %eax,-0x10(%ebp)
c010465c:	81 7d f0 7c bf 11 c0 	cmpl   $0xc011bf7c,-0x10(%ebp)
c0104663:	75 cc                	jne    c0104631 <default_alloc_pages+0x54>
        }
    }
    if (page != NULL) { //若找到了空闲的页 `PG_reserved = 1`, `PG_property = 0`.，将这个页从free_list中卸下
c0104665:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0104669:	0f 84 ea 00 00 00    	je     c0104759 <default_alloc_pages+0x17c>
    //如果当前空闲页的大小大于所需大小。则分割页块。具体操作就是，刚刚分配了n个页，如果分配完了，
    //还有连续的空间，则在最后分配的那个页的下一个页（未分配），更新它的连续空闲页值。如果正好合适，则不进行操作。
        if (page->property > n) { //重新计算剩余空闲页的数量
c010466f:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104672:	8b 40 08             	mov    0x8(%eax),%eax
c0104675:	39 45 08             	cmp    %eax,0x8(%ebp)
c0104678:	0f 83 8a 00 00 00    	jae    c0104708 <default_alloc_pages+0x12b>
            struct Page *p = page + n;
c010467e:	8b 55 08             	mov    0x8(%ebp),%edx
c0104681:	89 d0                	mov    %edx,%eax
c0104683:	c1 e0 02             	shl    $0x2,%eax
c0104686:	01 d0                	add    %edx,%eax
c0104688:	c1 e0 02             	shl    $0x2,%eax
c010468b:	89 c2                	mov    %eax,%edx
c010468d:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104690:	01 d0                	add    %edx,%eax
c0104692:	89 45 e8             	mov    %eax,-0x18(%ebp)
            p->property = page->property - n;
c0104695:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104698:	8b 40 08             	mov    0x8(%eax),%eax
c010469b:	2b 45 08             	sub    0x8(%ebp),%eax
c010469e:	89 c2                	mov    %eax,%edx
c01046a0:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01046a3:	89 50 08             	mov    %edx,0x8(%eax)
            //要加上下面这句
            SetPageProperty(p);
c01046a6:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01046a9:	83 c0 04             	add    $0x4,%eax
c01046ac:	c7 45 cc 01 00 00 00 	movl   $0x1,-0x34(%ebp)
c01046b3:	89 45 c8             	mov    %eax,-0x38(%ebp)
c01046b6:	8b 45 c8             	mov    -0x38(%ebp),%eax
c01046b9:	8b 55 cc             	mov    -0x34(%ebp),%edx
c01046bc:	0f ab 10             	bts    %edx,(%eax)
            //要把 list_add改成 list_add_after
            list_add_after(&free_list, &(p->page_link));
c01046bf:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01046c2:	83 c0 0c             	add    $0xc,%eax
c01046c5:	c7 45 e0 7c bf 11 c0 	movl   $0xc011bf7c,-0x20(%ebp)
c01046cc:	89 45 dc             	mov    %eax,-0x24(%ebp)
    __list_add(elm, listelm, listelm->next);
c01046cf:	8b 45 e0             	mov    -0x20(%ebp),%eax
c01046d2:	8b 40 04             	mov    0x4(%eax),%eax
c01046d5:	8b 55 dc             	mov    -0x24(%ebp),%edx
c01046d8:	89 55 d8             	mov    %edx,-0x28(%ebp)
c01046db:	8b 55 e0             	mov    -0x20(%ebp),%edx
c01046de:	89 55 d4             	mov    %edx,-0x2c(%ebp)
c01046e1:	89 45 d0             	mov    %eax,-0x30(%ebp)
    prev->next = next->prev = elm;
c01046e4:	8b 45 d0             	mov    -0x30(%ebp),%eax
c01046e7:	8b 55 d8             	mov    -0x28(%ebp),%edx
c01046ea:	89 10                	mov    %edx,(%eax)
c01046ec:	8b 45 d0             	mov    -0x30(%ebp),%eax
c01046ef:	8b 10                	mov    (%eax),%edx
c01046f1:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c01046f4:	89 50 04             	mov    %edx,0x4(%eax)
    elm->next = next;
c01046f7:	8b 45 d8             	mov    -0x28(%ebp),%eax
c01046fa:	8b 55 d0             	mov    -0x30(%ebp),%edx
c01046fd:	89 50 04             	mov    %edx,0x4(%eax)
    elm->prev = prev;
c0104700:	8b 45 d8             	mov    -0x28(%ebp),%eax
c0104703:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0104706:	89 10                	mov    %edx,(%eax)
        }
        list_del(&(page->page_link));
c0104708:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010470b:	83 c0 0c             	add    $0xc,%eax
c010470e:	89 45 bc             	mov    %eax,-0x44(%ebp)
    __list_del(listelm->prev, listelm->next);
c0104711:	8b 45 bc             	mov    -0x44(%ebp),%eax
c0104714:	8b 40 04             	mov    0x4(%eax),%eax
c0104717:	8b 55 bc             	mov    -0x44(%ebp),%edx
c010471a:	8b 12                	mov    (%edx),%edx
c010471c:	89 55 b8             	mov    %edx,-0x48(%ebp)
c010471f:	89 45 b4             	mov    %eax,-0x4c(%ebp)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
c0104722:	8b 45 b8             	mov    -0x48(%ebp),%eax
c0104725:	8b 55 b4             	mov    -0x4c(%ebp),%edx
c0104728:	89 50 04             	mov    %edx,0x4(%eax)
    next->prev = prev;
c010472b:	8b 45 b4             	mov    -0x4c(%ebp),%eax
c010472e:	8b 55 b8             	mov    -0x48(%ebp),%edx
c0104731:	89 10                	mov    %edx,(%eax)
        nr_free -= n;  //Re-caluclate `nr_free` (number of the the rest of all free block).
c0104733:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
c0104738:	2b 45 08             	sub    0x8(%ebp),%eax
c010473b:	a3 84 bf 11 c0       	mov    %eax,0xc011bf84
        ClearPageProperty(page);
c0104740:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104743:	83 c0 04             	add    $0x4,%eax
c0104746:	c7 45 c4 01 00 00 00 	movl   $0x1,-0x3c(%ebp)
c010474d:	89 45 c0             	mov    %eax,-0x40(%ebp)
    asm volatile ("btrl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
c0104750:	8b 45 c0             	mov    -0x40(%ebp),%eax
c0104753:	8b 55 c4             	mov    -0x3c(%ebp),%edx
c0104756:	0f b3 10             	btr    %edx,(%eax)
    }
    return page;
c0104759:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c010475c:	c9                   	leave  
c010475d:	c3                   	ret    

c010475e <default_free_pages>:

//default_free_pages函数的实现其实是default_alloc_pages的逆过程，不过需要考虑空闲块的合并问题
// re-link the pages into the free list, and may merge small free blocks into the big ones.
static void
default_free_pages(struct Page *base, size_t n) {
c010475e:	55                   	push   %ebp
c010475f:	89 e5                	mov    %esp,%ebp
c0104761:	81 ec 98 00 00 00    	sub    $0x98,%esp
    assert(n > 0);
c0104767:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
c010476b:	75 24                	jne    c0104791 <default_free_pages+0x33>
c010476d:	c7 44 24 0c 18 6f 10 	movl   $0xc0106f18,0xc(%esp)
c0104774:	c0 
c0104775:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c010477c:	c0 
c010477d:	c7 44 24 04 b5 00 00 	movl   $0xb5,0x4(%esp)
c0104784:	00 
c0104785:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c010478c:	e8 68 bc ff ff       	call   c01003f9 <__panic>
    struct Page *p = base;
c0104791:	8b 45 08             	mov    0x8(%ebp),%eax
c0104794:	89 45 f4             	mov    %eax,-0xc(%ebp)
    for (; p != base + n; p ++) { // According to the base address of the withdrawed blocks, search the free
c0104797:	e9 9d 00 00 00       	jmp    c0104839 <default_free_pages+0xdb>
                                                        // list for its correct position (with address from low to high), and insert the pages.
        assert(!PageReserved(p) && !PageProperty(p));
c010479c:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010479f:	83 c0 04             	add    $0x4,%eax
c01047a2:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
c01047a9:	89 45 e8             	mov    %eax,-0x18(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c01047ac:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01047af:	8b 55 ec             	mov    -0x14(%ebp),%edx
c01047b2:	0f a3 10             	bt     %edx,(%eax)
c01047b5:	19 c0                	sbb    %eax,%eax
c01047b7:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    return oldbit != 0;
c01047ba:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
c01047be:	0f 95 c0             	setne  %al
c01047c1:	0f b6 c0             	movzbl %al,%eax
c01047c4:	85 c0                	test   %eax,%eax
c01047c6:	75 2c                	jne    c01047f4 <default_free_pages+0x96>
c01047c8:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01047cb:	83 c0 04             	add    $0x4,%eax
c01047ce:	c7 45 e0 01 00 00 00 	movl   $0x1,-0x20(%ebp)
c01047d5:	89 45 dc             	mov    %eax,-0x24(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c01047d8:	8b 45 dc             	mov    -0x24(%ebp),%eax
c01047db:	8b 55 e0             	mov    -0x20(%ebp),%edx
c01047de:	0f a3 10             	bt     %edx,(%eax)
c01047e1:	19 c0                	sbb    %eax,%eax
c01047e3:	89 45 d8             	mov    %eax,-0x28(%ebp)
    return oldbit != 0;
c01047e6:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
c01047ea:	0f 95 c0             	setne  %al
c01047ed:	0f b6 c0             	movzbl %al,%eax
c01047f0:	85 c0                	test   %eax,%eax
c01047f2:	74 24                	je     c0104818 <default_free_pages+0xba>
c01047f4:	c7 44 24 0c 5c 6f 10 	movl   $0xc0106f5c,0xc(%esp)
c01047fb:	c0 
c01047fc:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104803:	c0 
c0104804:	c7 44 24 04 b9 00 00 	movl   $0xb9,0x4(%esp)
c010480b:	00 
c010480c:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104813:	e8 e1 bb ff ff       	call   c01003f9 <__panic>
        p->flags = 0;
c0104818:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010481b:	c7 40 04 00 00 00 00 	movl   $0x0,0x4(%eax)
        set_page_ref(p, 0);
c0104822:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
c0104829:	00 
c010482a:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010482d:	89 04 24             	mov    %eax,(%esp)
c0104830:	e8 1d fc ff ff       	call   c0104452 <set_page_ref>
    for (; p != base + n; p ++) { // According to the base address of the withdrawed blocks, search the free
c0104835:	83 45 f4 14          	addl   $0x14,-0xc(%ebp)
c0104839:	8b 55 0c             	mov    0xc(%ebp),%edx
c010483c:	89 d0                	mov    %edx,%eax
c010483e:	c1 e0 02             	shl    $0x2,%eax
c0104841:	01 d0                	add    %edx,%eax
c0104843:	c1 e0 02             	shl    $0x2,%eax
c0104846:	89 c2                	mov    %eax,%edx
c0104848:	8b 45 08             	mov    0x8(%ebp),%eax
c010484b:	01 d0                	add    %edx,%eax
c010484d:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c0104850:	0f 85 46 ff ff ff    	jne    c010479c <default_free_pages+0x3e>
    }
    base->property = n;
c0104856:	8b 45 08             	mov    0x8(%ebp),%eax
c0104859:	8b 55 0c             	mov    0xc(%ebp),%edx
c010485c:	89 50 08             	mov    %edx,0x8(%eax)
    SetPageProperty(base);
c010485f:	8b 45 08             	mov    0x8(%ebp),%eax
c0104862:	83 c0 04             	add    $0x4,%eax
c0104865:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
c010486c:	89 45 cc             	mov    %eax,-0x34(%ebp)
    asm volatile ("btsl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
c010486f:	8b 45 cc             	mov    -0x34(%ebp),%eax
c0104872:	8b 55 d0             	mov    -0x30(%ebp),%edx
c0104875:	0f ab 10             	bts    %edx,(%eax)
c0104878:	c7 45 d4 7c bf 11 c0 	movl   $0xc011bf7c,-0x2c(%ebp)
    return listelm->next;
c010487f:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c0104882:	8b 40 04             	mov    0x4(%eax),%eax
    list_entry_t *le = list_next(&free_list);
c0104885:	89 45 f0             	mov    %eax,-0x10(%ebp)
    while (le != &free_list) {
c0104888:	e9 08 01 00 00       	jmp    c0104995 <default_free_pages+0x237>
        p = le2page(le, page_link);
c010488d:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104890:	83 e8 0c             	sub    $0xc,%eax
c0104893:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0104896:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104899:	89 45 c8             	mov    %eax,-0x38(%ebp)
c010489c:	8b 45 c8             	mov    -0x38(%ebp),%eax
c010489f:	8b 40 04             	mov    0x4(%eax),%eax
        le = list_next(le);
c01048a2:	89 45 f0             	mov    %eax,-0x10(%ebp)
        if (base + base->property == p) {
c01048a5:	8b 45 08             	mov    0x8(%ebp),%eax
c01048a8:	8b 50 08             	mov    0x8(%eax),%edx
c01048ab:	89 d0                	mov    %edx,%eax
c01048ad:	c1 e0 02             	shl    $0x2,%eax
c01048b0:	01 d0                	add    %edx,%eax
c01048b2:	c1 e0 02             	shl    $0x2,%eax
c01048b5:	89 c2                	mov    %eax,%edx
c01048b7:	8b 45 08             	mov    0x8(%ebp),%eax
c01048ba:	01 d0                	add    %edx,%eax
c01048bc:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c01048bf:	75 5a                	jne    c010491b <default_free_pages+0x1bd>
            base->property += p->property;
c01048c1:	8b 45 08             	mov    0x8(%ebp),%eax
c01048c4:	8b 50 08             	mov    0x8(%eax),%edx
c01048c7:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01048ca:	8b 40 08             	mov    0x8(%eax),%eax
c01048cd:	01 c2                	add    %eax,%edx
c01048cf:	8b 45 08             	mov    0x8(%ebp),%eax
c01048d2:	89 50 08             	mov    %edx,0x8(%eax)
            ClearPageProperty(p);
c01048d5:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01048d8:	83 c0 04             	add    $0x4,%eax
c01048db:	c7 45 b8 01 00 00 00 	movl   $0x1,-0x48(%ebp)
c01048e2:	89 45 b4             	mov    %eax,-0x4c(%ebp)
    asm volatile ("btrl %1, %0" :"=m" (*(volatile long *)addr) : "Ir" (nr));
c01048e5:	8b 45 b4             	mov    -0x4c(%ebp),%eax
c01048e8:	8b 55 b8             	mov    -0x48(%ebp),%edx
c01048eb:	0f b3 10             	btr    %edx,(%eax)
            list_del(&(p->page_link));
c01048ee:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01048f1:	83 c0 0c             	add    $0xc,%eax
c01048f4:	89 45 c4             	mov    %eax,-0x3c(%ebp)
    __list_del(listelm->prev, listelm->next);
c01048f7:	8b 45 c4             	mov    -0x3c(%ebp),%eax
c01048fa:	8b 40 04             	mov    0x4(%eax),%eax
c01048fd:	8b 55 c4             	mov    -0x3c(%ebp),%edx
c0104900:	8b 12                	mov    (%edx),%edx
c0104902:	89 55 c0             	mov    %edx,-0x40(%ebp)
c0104905:	89 45 bc             	mov    %eax,-0x44(%ebp)
    prev->next = next;
c0104908:	8b 45 c0             	mov    -0x40(%ebp),%eax
c010490b:	8b 55 bc             	mov    -0x44(%ebp),%edx
c010490e:	89 50 04             	mov    %edx,0x4(%eax)
    next->prev = prev;
c0104911:	8b 45 bc             	mov    -0x44(%ebp),%eax
c0104914:	8b 55 c0             	mov    -0x40(%ebp),%edx
c0104917:	89 10                	mov    %edx,(%eax)
c0104919:	eb 7a                	jmp    c0104995 <default_free_pages+0x237>
        }
        else if (p + p->property == base) {
c010491b:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010491e:	8b 50 08             	mov    0x8(%eax),%edx
c0104921:	89 d0                	mov    %edx,%eax
c0104923:	c1 e0 02             	shl    $0x2,%eax
c0104926:	01 d0                	add    %edx,%eax
c0104928:	c1 e0 02             	shl    $0x2,%eax
c010492b:	89 c2                	mov    %eax,%edx
c010492d:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104930:	01 d0                	add    %edx,%eax
c0104932:	39 45 08             	cmp    %eax,0x8(%ebp)
c0104935:	75 5e                	jne    c0104995 <default_free_pages+0x237>
            p->property += base->property;
c0104937:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010493a:	8b 50 08             	mov    0x8(%eax),%edx
c010493d:	8b 45 08             	mov    0x8(%ebp),%eax
c0104940:	8b 40 08             	mov    0x8(%eax),%eax
c0104943:	01 c2                	add    %eax,%edx
c0104945:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104948:	89 50 08             	mov    %edx,0x8(%eax)
            ClearPageProperty(base);
c010494b:	8b 45 08             	mov    0x8(%ebp),%eax
c010494e:	83 c0 04             	add    $0x4,%eax
c0104951:	c7 45 a4 01 00 00 00 	movl   $0x1,-0x5c(%ebp)
c0104958:	89 45 a0             	mov    %eax,-0x60(%ebp)
c010495b:	8b 45 a0             	mov    -0x60(%ebp),%eax
c010495e:	8b 55 a4             	mov    -0x5c(%ebp),%edx
c0104961:	0f b3 10             	btr    %edx,(%eax)
            base = p;
c0104964:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104967:	89 45 08             	mov    %eax,0x8(%ebp)
            list_del(&(p->page_link));
c010496a:	8b 45 f4             	mov    -0xc(%ebp),%eax
c010496d:	83 c0 0c             	add    $0xc,%eax
c0104970:	89 45 b0             	mov    %eax,-0x50(%ebp)
    __list_del(listelm->prev, listelm->next);
c0104973:	8b 45 b0             	mov    -0x50(%ebp),%eax
c0104976:	8b 40 04             	mov    0x4(%eax),%eax
c0104979:	8b 55 b0             	mov    -0x50(%ebp),%edx
c010497c:	8b 12                	mov    (%edx),%edx
c010497e:	89 55 ac             	mov    %edx,-0x54(%ebp)
c0104981:	89 45 a8             	mov    %eax,-0x58(%ebp)
    prev->next = next;
c0104984:	8b 45 ac             	mov    -0x54(%ebp),%eax
c0104987:	8b 55 a8             	mov    -0x58(%ebp),%edx
c010498a:	89 50 04             	mov    %edx,0x4(%eax)
    next->prev = prev;
c010498d:	8b 45 a8             	mov    -0x58(%ebp),%eax
c0104990:	8b 55 ac             	mov    -0x54(%ebp),%edx
c0104993:	89 10                	mov    %edx,(%eax)
    while (le != &free_list) {
c0104995:	81 7d f0 7c bf 11 c0 	cmpl   $0xc011bf7c,-0x10(%ebp)
c010499c:	0f 85 eb fe ff ff    	jne    c010488d <default_free_pages+0x12f>
        }
    }
    nr_free += n;
c01049a2:	8b 15 84 bf 11 c0    	mov    0xc011bf84,%edx
c01049a8:	8b 45 0c             	mov    0xc(%ebp),%eax
c01049ab:	01 d0                	add    %edx,%eax
c01049ad:	a3 84 bf 11 c0       	mov    %eax,0xc011bf84
c01049b2:	c7 45 9c 7c bf 11 c0 	movl   $0xc011bf7c,-0x64(%ebp)
    return listelm->next;
c01049b9:	8b 45 9c             	mov    -0x64(%ebp),%eax
c01049bc:	8b 40 04             	mov    0x4(%eax),%eax
    
    //加下面这段(释放的这个page的后面是空闲的)
    le = list_next(&free_list);
c01049bf:	89 45 f0             	mov    %eax,-0x10(%ebp)
    while (le != &free_list) {
c01049c2:	eb 74                	jmp    c0104a38 <default_free_pages+0x2da>
        p = le2page(le, page_link);
c01049c4:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01049c7:	83 e8 0c             	sub    $0xc,%eax
c01049ca:	89 45 f4             	mov    %eax,-0xc(%ebp)
        if (base + base->property <= p) {
c01049cd:	8b 45 08             	mov    0x8(%ebp),%eax
c01049d0:	8b 50 08             	mov    0x8(%eax),%edx
c01049d3:	89 d0                	mov    %edx,%eax
c01049d5:	c1 e0 02             	shl    $0x2,%eax
c01049d8:	01 d0                	add    %edx,%eax
c01049da:	c1 e0 02             	shl    $0x2,%eax
c01049dd:	89 c2                	mov    %eax,%edx
c01049df:	8b 45 08             	mov    0x8(%ebp),%eax
c01049e2:	01 d0                	add    %edx,%eax
c01049e4:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c01049e7:	72 40                	jb     c0104a29 <default_free_pages+0x2cb>
            assert(base + base->property != p);
c01049e9:	8b 45 08             	mov    0x8(%ebp),%eax
c01049ec:	8b 50 08             	mov    0x8(%eax),%edx
c01049ef:	89 d0                	mov    %edx,%eax
c01049f1:	c1 e0 02             	shl    $0x2,%eax
c01049f4:	01 d0                	add    %edx,%eax
c01049f6:	c1 e0 02             	shl    $0x2,%eax
c01049f9:	89 c2                	mov    %eax,%edx
c01049fb:	8b 45 08             	mov    0x8(%ebp),%eax
c01049fe:	01 d0                	add    %edx,%eax
c0104a00:	39 45 f4             	cmp    %eax,-0xc(%ebp)
c0104a03:	75 3e                	jne    c0104a43 <default_free_pages+0x2e5>
c0104a05:	c7 44 24 0c 81 6f 10 	movl   $0xc0106f81,0xc(%esp)
c0104a0c:	c0 
c0104a0d:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104a14:	c0 
c0104a15:	c7 44 24 04 d6 00 00 	movl   $0xd6,0x4(%esp)
c0104a1c:	00 
c0104a1d:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104a24:	e8 d0 b9 ff ff       	call   c01003f9 <__panic>
c0104a29:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104a2c:	89 45 98             	mov    %eax,-0x68(%ebp)
c0104a2f:	8b 45 98             	mov    -0x68(%ebp),%eax
c0104a32:	8b 40 04             	mov    0x4(%eax),%eax
            break;
        }
        le = list_next(le);
c0104a35:	89 45 f0             	mov    %eax,-0x10(%ebp)
    while (le != &free_list) {
c0104a38:	81 7d f0 7c bf 11 c0 	cmpl   $0xc011bf7c,-0x10(%ebp)
c0104a3f:	75 83                	jne    c01049c4 <default_free_pages+0x266>
c0104a41:	eb 01                	jmp    c0104a44 <default_free_pages+0x2e6>
            break;
c0104a43:	90                   	nop
    }
    list_add_before(le, &(base->page_link));
c0104a44:	8b 45 08             	mov    0x8(%ebp),%eax
c0104a47:	8d 50 0c             	lea    0xc(%eax),%edx
c0104a4a:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104a4d:	89 45 94             	mov    %eax,-0x6c(%ebp)
c0104a50:	89 55 90             	mov    %edx,-0x70(%ebp)
    __list_add(elm, listelm->prev, listelm);
c0104a53:	8b 45 94             	mov    -0x6c(%ebp),%eax
c0104a56:	8b 00                	mov    (%eax),%eax
c0104a58:	8b 55 90             	mov    -0x70(%ebp),%edx
c0104a5b:	89 55 8c             	mov    %edx,-0x74(%ebp)
c0104a5e:	89 45 88             	mov    %eax,-0x78(%ebp)
c0104a61:	8b 45 94             	mov    -0x6c(%ebp),%eax
c0104a64:	89 45 84             	mov    %eax,-0x7c(%ebp)
    prev->next = next->prev = elm;
c0104a67:	8b 45 84             	mov    -0x7c(%ebp),%eax
c0104a6a:	8b 55 8c             	mov    -0x74(%ebp),%edx
c0104a6d:	89 10                	mov    %edx,(%eax)
c0104a6f:	8b 45 84             	mov    -0x7c(%ebp),%eax
c0104a72:	8b 10                	mov    (%eax),%edx
c0104a74:	8b 45 88             	mov    -0x78(%ebp),%eax
c0104a77:	89 50 04             	mov    %edx,0x4(%eax)
    elm->next = next;
c0104a7a:	8b 45 8c             	mov    -0x74(%ebp),%eax
c0104a7d:	8b 55 84             	mov    -0x7c(%ebp),%edx
c0104a80:	89 50 04             	mov    %edx,0x4(%eax)
    elm->prev = prev;
c0104a83:	8b 45 8c             	mov    -0x74(%ebp),%eax
c0104a86:	8b 55 88             	mov    -0x78(%ebp),%edx
c0104a89:	89 10                	mov    %edx,(%eax)
}
c0104a8b:	90                   	nop
c0104a8c:	c9                   	leave  
c0104a8d:	c3                   	ret    

c0104a8e <default_nr_free_pages>:

static size_t
default_nr_free_pages(void) {
c0104a8e:	55                   	push   %ebp
c0104a8f:	89 e5                	mov    %esp,%ebp
    return nr_free;
c0104a91:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
}
c0104a96:	5d                   	pop    %ebp
c0104a97:	c3                   	ret    

c0104a98 <basic_check>:

static void
basic_check(void) {
c0104a98:	55                   	push   %ebp
c0104a99:	89 e5                	mov    %esp,%ebp
c0104a9b:	83 ec 48             	sub    $0x48,%esp
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;
c0104a9e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
c0104aa5:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104aa8:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0104aab:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104aae:	89 45 ec             	mov    %eax,-0x14(%ebp)
    assert((p0 = alloc_page()) != NULL);
c0104ab1:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104ab8:	e8 ae e2 ff ff       	call   c0102d6b <alloc_pages>
c0104abd:	89 45 ec             	mov    %eax,-0x14(%ebp)
c0104ac0:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
c0104ac4:	75 24                	jne    c0104aea <basic_check+0x52>
c0104ac6:	c7 44 24 0c 9c 6f 10 	movl   $0xc0106f9c,0xc(%esp)
c0104acd:	c0 
c0104ace:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104ad5:	c0 
c0104ad6:	c7 44 24 04 e7 00 00 	movl   $0xe7,0x4(%esp)
c0104add:	00 
c0104ade:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104ae5:	e8 0f b9 ff ff       	call   c01003f9 <__panic>
    assert((p1 = alloc_page()) != NULL);
c0104aea:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104af1:	e8 75 e2 ff ff       	call   c0102d6b <alloc_pages>
c0104af6:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0104af9:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0104afd:	75 24                	jne    c0104b23 <basic_check+0x8b>
c0104aff:	c7 44 24 0c b8 6f 10 	movl   $0xc0106fb8,0xc(%esp)
c0104b06:	c0 
c0104b07:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104b0e:	c0 
c0104b0f:	c7 44 24 04 e8 00 00 	movl   $0xe8,0x4(%esp)
c0104b16:	00 
c0104b17:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104b1e:	e8 d6 b8 ff ff       	call   c01003f9 <__panic>
    assert((p2 = alloc_page()) != NULL);
c0104b23:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104b2a:	e8 3c e2 ff ff       	call   c0102d6b <alloc_pages>
c0104b2f:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0104b32:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0104b36:	75 24                	jne    c0104b5c <basic_check+0xc4>
c0104b38:	c7 44 24 0c d4 6f 10 	movl   $0xc0106fd4,0xc(%esp)
c0104b3f:	c0 
c0104b40:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104b47:	c0 
c0104b48:	c7 44 24 04 e9 00 00 	movl   $0xe9,0x4(%esp)
c0104b4f:	00 
c0104b50:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104b57:	e8 9d b8 ff ff       	call   c01003f9 <__panic>

    assert(p0 != p1 && p0 != p2 && p1 != p2);
c0104b5c:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104b5f:	3b 45 f0             	cmp    -0x10(%ebp),%eax
c0104b62:	74 10                	je     c0104b74 <basic_check+0xdc>
c0104b64:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104b67:	3b 45 f4             	cmp    -0xc(%ebp),%eax
c0104b6a:	74 08                	je     c0104b74 <basic_check+0xdc>
c0104b6c:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104b6f:	3b 45 f4             	cmp    -0xc(%ebp),%eax
c0104b72:	75 24                	jne    c0104b98 <basic_check+0x100>
c0104b74:	c7 44 24 0c f0 6f 10 	movl   $0xc0106ff0,0xc(%esp)
c0104b7b:	c0 
c0104b7c:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104b83:	c0 
c0104b84:	c7 44 24 04 eb 00 00 	movl   $0xeb,0x4(%esp)
c0104b8b:	00 
c0104b8c:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104b93:	e8 61 b8 ff ff       	call   c01003f9 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
c0104b98:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104b9b:	89 04 24             	mov    %eax,(%esp)
c0104b9e:	e8 a5 f8 ff ff       	call   c0104448 <page_ref>
c0104ba3:	85 c0                	test   %eax,%eax
c0104ba5:	75 1e                	jne    c0104bc5 <basic_check+0x12d>
c0104ba7:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104baa:	89 04 24             	mov    %eax,(%esp)
c0104bad:	e8 96 f8 ff ff       	call   c0104448 <page_ref>
c0104bb2:	85 c0                	test   %eax,%eax
c0104bb4:	75 0f                	jne    c0104bc5 <basic_check+0x12d>
c0104bb6:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104bb9:	89 04 24             	mov    %eax,(%esp)
c0104bbc:	e8 87 f8 ff ff       	call   c0104448 <page_ref>
c0104bc1:	85 c0                	test   %eax,%eax
c0104bc3:	74 24                	je     c0104be9 <basic_check+0x151>
c0104bc5:	c7 44 24 0c 14 70 10 	movl   $0xc0107014,0xc(%esp)
c0104bcc:	c0 
c0104bcd:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104bd4:	c0 
c0104bd5:	c7 44 24 04 ec 00 00 	movl   $0xec,0x4(%esp)
c0104bdc:	00 
c0104bdd:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104be4:	e8 10 b8 ff ff       	call   c01003f9 <__panic>

    assert(page2pa(p0) < npage * PGSIZE);
c0104be9:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104bec:	89 04 24             	mov    %eax,(%esp)
c0104bef:	e8 3e f8 ff ff       	call   c0104432 <page2pa>
c0104bf4:	8b 15 80 be 11 c0    	mov    0xc011be80,%edx
c0104bfa:	c1 e2 0c             	shl    $0xc,%edx
c0104bfd:	39 d0                	cmp    %edx,%eax
c0104bff:	72 24                	jb     c0104c25 <basic_check+0x18d>
c0104c01:	c7 44 24 0c 50 70 10 	movl   $0xc0107050,0xc(%esp)
c0104c08:	c0 
c0104c09:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104c10:	c0 
c0104c11:	c7 44 24 04 ee 00 00 	movl   $0xee,0x4(%esp)
c0104c18:	00 
c0104c19:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104c20:	e8 d4 b7 ff ff       	call   c01003f9 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
c0104c25:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104c28:	89 04 24             	mov    %eax,(%esp)
c0104c2b:	e8 02 f8 ff ff       	call   c0104432 <page2pa>
c0104c30:	8b 15 80 be 11 c0    	mov    0xc011be80,%edx
c0104c36:	c1 e2 0c             	shl    $0xc,%edx
c0104c39:	39 d0                	cmp    %edx,%eax
c0104c3b:	72 24                	jb     c0104c61 <basic_check+0x1c9>
c0104c3d:	c7 44 24 0c 6d 70 10 	movl   $0xc010706d,0xc(%esp)
c0104c44:	c0 
c0104c45:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104c4c:	c0 
c0104c4d:	c7 44 24 04 ef 00 00 	movl   $0xef,0x4(%esp)
c0104c54:	00 
c0104c55:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104c5c:	e8 98 b7 ff ff       	call   c01003f9 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
c0104c61:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104c64:	89 04 24             	mov    %eax,(%esp)
c0104c67:	e8 c6 f7 ff ff       	call   c0104432 <page2pa>
c0104c6c:	8b 15 80 be 11 c0    	mov    0xc011be80,%edx
c0104c72:	c1 e2 0c             	shl    $0xc,%edx
c0104c75:	39 d0                	cmp    %edx,%eax
c0104c77:	72 24                	jb     c0104c9d <basic_check+0x205>
c0104c79:	c7 44 24 0c 8a 70 10 	movl   $0xc010708a,0xc(%esp)
c0104c80:	c0 
c0104c81:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104c88:	c0 
c0104c89:	c7 44 24 04 f0 00 00 	movl   $0xf0,0x4(%esp)
c0104c90:	00 
c0104c91:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104c98:	e8 5c b7 ff ff       	call   c01003f9 <__panic>

    list_entry_t free_list_store = free_list;
c0104c9d:	a1 7c bf 11 c0       	mov    0xc011bf7c,%eax
c0104ca2:	8b 15 80 bf 11 c0    	mov    0xc011bf80,%edx
c0104ca8:	89 45 d0             	mov    %eax,-0x30(%ebp)
c0104cab:	89 55 d4             	mov    %edx,-0x2c(%ebp)
c0104cae:	c7 45 dc 7c bf 11 c0 	movl   $0xc011bf7c,-0x24(%ebp)
    elm->prev = elm->next = elm;
c0104cb5:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0104cb8:	8b 55 dc             	mov    -0x24(%ebp),%edx
c0104cbb:	89 50 04             	mov    %edx,0x4(%eax)
c0104cbe:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0104cc1:	8b 50 04             	mov    0x4(%eax),%edx
c0104cc4:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0104cc7:	89 10                	mov    %edx,(%eax)
c0104cc9:	c7 45 e0 7c bf 11 c0 	movl   $0xc011bf7c,-0x20(%ebp)
    return list->next == list;
c0104cd0:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0104cd3:	8b 40 04             	mov    0x4(%eax),%eax
c0104cd6:	39 45 e0             	cmp    %eax,-0x20(%ebp)
c0104cd9:	0f 94 c0             	sete   %al
c0104cdc:	0f b6 c0             	movzbl %al,%eax
    list_init(&free_list);
    assert(list_empty(&free_list));
c0104cdf:	85 c0                	test   %eax,%eax
c0104ce1:	75 24                	jne    c0104d07 <basic_check+0x26f>
c0104ce3:	c7 44 24 0c a7 70 10 	movl   $0xc01070a7,0xc(%esp)
c0104cea:	c0 
c0104ceb:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104cf2:	c0 
c0104cf3:	c7 44 24 04 f4 00 00 	movl   $0xf4,0x4(%esp)
c0104cfa:	00 
c0104cfb:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104d02:	e8 f2 b6 ff ff       	call   c01003f9 <__panic>

    unsigned int nr_free_store = nr_free;
c0104d07:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
c0104d0c:	89 45 e8             	mov    %eax,-0x18(%ebp)
    nr_free = 0;
c0104d0f:	c7 05 84 bf 11 c0 00 	movl   $0x0,0xc011bf84
c0104d16:	00 00 00 

    assert(alloc_page() == NULL);
c0104d19:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104d20:	e8 46 e0 ff ff       	call   c0102d6b <alloc_pages>
c0104d25:	85 c0                	test   %eax,%eax
c0104d27:	74 24                	je     c0104d4d <basic_check+0x2b5>
c0104d29:	c7 44 24 0c be 70 10 	movl   $0xc01070be,0xc(%esp)
c0104d30:	c0 
c0104d31:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104d38:	c0 
c0104d39:	c7 44 24 04 f9 00 00 	movl   $0xf9,0x4(%esp)
c0104d40:	00 
c0104d41:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104d48:	e8 ac b6 ff ff       	call   c01003f9 <__panic>

    free_page(p0);
c0104d4d:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104d54:	00 
c0104d55:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104d58:	89 04 24             	mov    %eax,(%esp)
c0104d5b:	e8 43 e0 ff ff       	call   c0102da3 <free_pages>
    free_page(p1);
c0104d60:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104d67:	00 
c0104d68:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104d6b:	89 04 24             	mov    %eax,(%esp)
c0104d6e:	e8 30 e0 ff ff       	call   c0102da3 <free_pages>
    free_page(p2);
c0104d73:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104d7a:	00 
c0104d7b:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104d7e:	89 04 24             	mov    %eax,(%esp)
c0104d81:	e8 1d e0 ff ff       	call   c0102da3 <free_pages>
    assert(nr_free == 3);
c0104d86:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
c0104d8b:	83 f8 03             	cmp    $0x3,%eax
c0104d8e:	74 24                	je     c0104db4 <basic_check+0x31c>
c0104d90:	c7 44 24 0c d3 70 10 	movl   $0xc01070d3,0xc(%esp)
c0104d97:	c0 
c0104d98:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104d9f:	c0 
c0104da0:	c7 44 24 04 fe 00 00 	movl   $0xfe,0x4(%esp)
c0104da7:	00 
c0104da8:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104daf:	e8 45 b6 ff ff       	call   c01003f9 <__panic>

    assert((p0 = alloc_page()) != NULL);
c0104db4:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104dbb:	e8 ab df ff ff       	call   c0102d6b <alloc_pages>
c0104dc0:	89 45 ec             	mov    %eax,-0x14(%ebp)
c0104dc3:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
c0104dc7:	75 24                	jne    c0104ded <basic_check+0x355>
c0104dc9:	c7 44 24 0c 9c 6f 10 	movl   $0xc0106f9c,0xc(%esp)
c0104dd0:	c0 
c0104dd1:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104dd8:	c0 
c0104dd9:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
c0104de0:	00 
c0104de1:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104de8:	e8 0c b6 ff ff       	call   c01003f9 <__panic>
    assert((p1 = alloc_page()) != NULL);
c0104ded:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104df4:	e8 72 df ff ff       	call   c0102d6b <alloc_pages>
c0104df9:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0104dfc:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0104e00:	75 24                	jne    c0104e26 <basic_check+0x38e>
c0104e02:	c7 44 24 0c b8 6f 10 	movl   $0xc0106fb8,0xc(%esp)
c0104e09:	c0 
c0104e0a:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104e11:	c0 
c0104e12:	c7 44 24 04 01 01 00 	movl   $0x101,0x4(%esp)
c0104e19:	00 
c0104e1a:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104e21:	e8 d3 b5 ff ff       	call   c01003f9 <__panic>
    assert((p2 = alloc_page()) != NULL);
c0104e26:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104e2d:	e8 39 df ff ff       	call   c0102d6b <alloc_pages>
c0104e32:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0104e35:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0104e39:	75 24                	jne    c0104e5f <basic_check+0x3c7>
c0104e3b:	c7 44 24 0c d4 6f 10 	movl   $0xc0106fd4,0xc(%esp)
c0104e42:	c0 
c0104e43:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104e4a:	c0 
c0104e4b:	c7 44 24 04 02 01 00 	movl   $0x102,0x4(%esp)
c0104e52:	00 
c0104e53:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104e5a:	e8 9a b5 ff ff       	call   c01003f9 <__panic>

    assert(alloc_page() == NULL);
c0104e5f:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104e66:	e8 00 df ff ff       	call   c0102d6b <alloc_pages>
c0104e6b:	85 c0                	test   %eax,%eax
c0104e6d:	74 24                	je     c0104e93 <basic_check+0x3fb>
c0104e6f:	c7 44 24 0c be 70 10 	movl   $0xc01070be,0xc(%esp)
c0104e76:	c0 
c0104e77:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104e7e:	c0 
c0104e7f:	c7 44 24 04 04 01 00 	movl   $0x104,0x4(%esp)
c0104e86:	00 
c0104e87:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104e8e:	e8 66 b5 ff ff       	call   c01003f9 <__panic>

    free_page(p0);
c0104e93:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104e9a:	00 
c0104e9b:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104e9e:	89 04 24             	mov    %eax,(%esp)
c0104ea1:	e8 fd de ff ff       	call   c0102da3 <free_pages>
c0104ea6:	c7 45 d8 7c bf 11 c0 	movl   $0xc011bf7c,-0x28(%ebp)
c0104ead:	8b 45 d8             	mov    -0x28(%ebp),%eax
c0104eb0:	8b 40 04             	mov    0x4(%eax),%eax
c0104eb3:	39 45 d8             	cmp    %eax,-0x28(%ebp)
c0104eb6:	0f 94 c0             	sete   %al
c0104eb9:	0f b6 c0             	movzbl %al,%eax
    assert(!list_empty(&free_list));
c0104ebc:	85 c0                	test   %eax,%eax
c0104ebe:	74 24                	je     c0104ee4 <basic_check+0x44c>
c0104ec0:	c7 44 24 0c e0 70 10 	movl   $0xc01070e0,0xc(%esp)
c0104ec7:	c0 
c0104ec8:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104ecf:	c0 
c0104ed0:	c7 44 24 04 07 01 00 	movl   $0x107,0x4(%esp)
c0104ed7:	00 
c0104ed8:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104edf:	e8 15 b5 ff ff       	call   c01003f9 <__panic>

    struct Page *p;
    assert((p = alloc_page()) == p0);
c0104ee4:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104eeb:	e8 7b de ff ff       	call   c0102d6b <alloc_pages>
c0104ef0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c0104ef3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0104ef6:	3b 45 ec             	cmp    -0x14(%ebp),%eax
c0104ef9:	74 24                	je     c0104f1f <basic_check+0x487>
c0104efb:	c7 44 24 0c f8 70 10 	movl   $0xc01070f8,0xc(%esp)
c0104f02:	c0 
c0104f03:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104f0a:	c0 
c0104f0b:	c7 44 24 04 0a 01 00 	movl   $0x10a,0x4(%esp)
c0104f12:	00 
c0104f13:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104f1a:	e8 da b4 ff ff       	call   c01003f9 <__panic>
    assert(alloc_page() == NULL);
c0104f1f:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c0104f26:	e8 40 de ff ff       	call   c0102d6b <alloc_pages>
c0104f2b:	85 c0                	test   %eax,%eax
c0104f2d:	74 24                	je     c0104f53 <basic_check+0x4bb>
c0104f2f:	c7 44 24 0c be 70 10 	movl   $0xc01070be,0xc(%esp)
c0104f36:	c0 
c0104f37:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104f3e:	c0 
c0104f3f:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
c0104f46:	00 
c0104f47:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104f4e:	e8 a6 b4 ff ff       	call   c01003f9 <__panic>

    assert(nr_free == 0);
c0104f53:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
c0104f58:	85 c0                	test   %eax,%eax
c0104f5a:	74 24                	je     c0104f80 <basic_check+0x4e8>
c0104f5c:	c7 44 24 0c 11 71 10 	movl   $0xc0107111,0xc(%esp)
c0104f63:	c0 
c0104f64:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0104f6b:	c0 
c0104f6c:	c7 44 24 04 0d 01 00 	movl   $0x10d,0x4(%esp)
c0104f73:	00 
c0104f74:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0104f7b:	e8 79 b4 ff ff       	call   c01003f9 <__panic>
    free_list = free_list_store;
c0104f80:	8b 45 d0             	mov    -0x30(%ebp),%eax
c0104f83:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0104f86:	a3 7c bf 11 c0       	mov    %eax,0xc011bf7c
c0104f8b:	89 15 80 bf 11 c0    	mov    %edx,0xc011bf80
    nr_free = nr_free_store;
c0104f91:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0104f94:	a3 84 bf 11 c0       	mov    %eax,0xc011bf84

    free_page(p);
c0104f99:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104fa0:	00 
c0104fa1:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0104fa4:	89 04 24             	mov    %eax,(%esp)
c0104fa7:	e8 f7 dd ff ff       	call   c0102da3 <free_pages>
    free_page(p1);
c0104fac:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104fb3:	00 
c0104fb4:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0104fb7:	89 04 24             	mov    %eax,(%esp)
c0104fba:	e8 e4 dd ff ff       	call   c0102da3 <free_pages>
    free_page(p2);
c0104fbf:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0104fc6:	00 
c0104fc7:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0104fca:	89 04 24             	mov    %eax,(%esp)
c0104fcd:	e8 d1 dd ff ff       	call   c0102da3 <free_pages>
}
c0104fd2:	90                   	nop
c0104fd3:	c9                   	leave  
c0104fd4:	c3                   	ret    

c0104fd5 <default_check>:

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
default_check(void) {
c0104fd5:	55                   	push   %ebp
c0104fd6:	89 e5                	mov    %esp,%ebp
c0104fd8:	81 ec 98 00 00 00    	sub    $0x98,%esp
    int count = 0, total = 0;
c0104fde:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
c0104fe5:	c7 45 f0 00 00 00 00 	movl   $0x0,-0x10(%ebp)
    list_entry_t *le = &free_list;
c0104fec:	c7 45 ec 7c bf 11 c0 	movl   $0xc011bf7c,-0x14(%ebp)
    while ((le = list_next(le)) != &free_list) {
c0104ff3:	eb 6a                	jmp    c010505f <default_check+0x8a>
        struct Page *p = le2page(le, page_link);
c0104ff5:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0104ff8:	83 e8 0c             	sub    $0xc,%eax
c0104ffb:	89 45 d4             	mov    %eax,-0x2c(%ebp)
        assert(PageProperty(p));
c0104ffe:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c0105001:	83 c0 04             	add    $0x4,%eax
c0105004:	c7 45 d0 01 00 00 00 	movl   $0x1,-0x30(%ebp)
c010500b:	89 45 cc             	mov    %eax,-0x34(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c010500e:	8b 45 cc             	mov    -0x34(%ebp),%eax
c0105011:	8b 55 d0             	mov    -0x30(%ebp),%edx
c0105014:	0f a3 10             	bt     %edx,(%eax)
c0105017:	19 c0                	sbb    %eax,%eax
c0105019:	89 45 c8             	mov    %eax,-0x38(%ebp)
    return oldbit != 0;
c010501c:	83 7d c8 00          	cmpl   $0x0,-0x38(%ebp)
c0105020:	0f 95 c0             	setne  %al
c0105023:	0f b6 c0             	movzbl %al,%eax
c0105026:	85 c0                	test   %eax,%eax
c0105028:	75 24                	jne    c010504e <default_check+0x79>
c010502a:	c7 44 24 0c 1e 71 10 	movl   $0xc010711e,0xc(%esp)
c0105031:	c0 
c0105032:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105039:	c0 
c010503a:	c7 44 24 04 1e 01 00 	movl   $0x11e,0x4(%esp)
c0105041:	00 
c0105042:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105049:	e8 ab b3 ff ff       	call   c01003f9 <__panic>
        count ++, total += p->property;
c010504e:	ff 45 f4             	incl   -0xc(%ebp)
c0105051:	8b 45 d4             	mov    -0x2c(%ebp),%eax
c0105054:	8b 50 08             	mov    0x8(%eax),%edx
c0105057:	8b 45 f0             	mov    -0x10(%ebp),%eax
c010505a:	01 d0                	add    %edx,%eax
c010505c:	89 45 f0             	mov    %eax,-0x10(%ebp)
c010505f:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0105062:	89 45 c4             	mov    %eax,-0x3c(%ebp)
    return listelm->next;
c0105065:	8b 45 c4             	mov    -0x3c(%ebp),%eax
c0105068:	8b 40 04             	mov    0x4(%eax),%eax
    while ((le = list_next(le)) != &free_list) {
c010506b:	89 45 ec             	mov    %eax,-0x14(%ebp)
c010506e:	81 7d ec 7c bf 11 c0 	cmpl   $0xc011bf7c,-0x14(%ebp)
c0105075:	0f 85 7a ff ff ff    	jne    c0104ff5 <default_check+0x20>
    }
    assert(total == nr_free_pages());
c010507b:	e8 56 dd ff ff       	call   c0102dd6 <nr_free_pages>
c0105080:	89 c2                	mov    %eax,%edx
c0105082:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105085:	39 c2                	cmp    %eax,%edx
c0105087:	74 24                	je     c01050ad <default_check+0xd8>
c0105089:	c7 44 24 0c 2e 71 10 	movl   $0xc010712e,0xc(%esp)
c0105090:	c0 
c0105091:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105098:	c0 
c0105099:	c7 44 24 04 21 01 00 	movl   $0x121,0x4(%esp)
c01050a0:	00 
c01050a1:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01050a8:	e8 4c b3 ff ff       	call   c01003f9 <__panic>

    basic_check();
c01050ad:	e8 e6 f9 ff ff       	call   c0104a98 <basic_check>

    struct Page *p0 = alloc_pages(5), *p1, *p2;
c01050b2:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
c01050b9:	e8 ad dc ff ff       	call   c0102d6b <alloc_pages>
c01050be:	89 45 e8             	mov    %eax,-0x18(%ebp)
    assert(p0 != NULL);
c01050c1:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c01050c5:	75 24                	jne    c01050eb <default_check+0x116>
c01050c7:	c7 44 24 0c 47 71 10 	movl   $0xc0107147,0xc(%esp)
c01050ce:	c0 
c01050cf:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01050d6:	c0 
c01050d7:	c7 44 24 04 26 01 00 	movl   $0x126,0x4(%esp)
c01050de:	00 
c01050df:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01050e6:	e8 0e b3 ff ff       	call   c01003f9 <__panic>
    assert(!PageProperty(p0));
c01050eb:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01050ee:	83 c0 04             	add    $0x4,%eax
c01050f1:	c7 45 c0 01 00 00 00 	movl   $0x1,-0x40(%ebp)
c01050f8:	89 45 bc             	mov    %eax,-0x44(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c01050fb:	8b 45 bc             	mov    -0x44(%ebp),%eax
c01050fe:	8b 55 c0             	mov    -0x40(%ebp),%edx
c0105101:	0f a3 10             	bt     %edx,(%eax)
c0105104:	19 c0                	sbb    %eax,%eax
c0105106:	89 45 b8             	mov    %eax,-0x48(%ebp)
    return oldbit != 0;
c0105109:	83 7d b8 00          	cmpl   $0x0,-0x48(%ebp)
c010510d:	0f 95 c0             	setne  %al
c0105110:	0f b6 c0             	movzbl %al,%eax
c0105113:	85 c0                	test   %eax,%eax
c0105115:	74 24                	je     c010513b <default_check+0x166>
c0105117:	c7 44 24 0c 52 71 10 	movl   $0xc0107152,0xc(%esp)
c010511e:	c0 
c010511f:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105126:	c0 
c0105127:	c7 44 24 04 27 01 00 	movl   $0x127,0x4(%esp)
c010512e:	00 
c010512f:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105136:	e8 be b2 ff ff       	call   c01003f9 <__panic>

    list_entry_t free_list_store = free_list;
c010513b:	a1 7c bf 11 c0       	mov    0xc011bf7c,%eax
c0105140:	8b 15 80 bf 11 c0    	mov    0xc011bf80,%edx
c0105146:	89 45 80             	mov    %eax,-0x80(%ebp)
c0105149:	89 55 84             	mov    %edx,-0x7c(%ebp)
c010514c:	c7 45 b0 7c bf 11 c0 	movl   $0xc011bf7c,-0x50(%ebp)
    elm->prev = elm->next = elm;
c0105153:	8b 45 b0             	mov    -0x50(%ebp),%eax
c0105156:	8b 55 b0             	mov    -0x50(%ebp),%edx
c0105159:	89 50 04             	mov    %edx,0x4(%eax)
c010515c:	8b 45 b0             	mov    -0x50(%ebp),%eax
c010515f:	8b 50 04             	mov    0x4(%eax),%edx
c0105162:	8b 45 b0             	mov    -0x50(%ebp),%eax
c0105165:	89 10                	mov    %edx,(%eax)
c0105167:	c7 45 b4 7c bf 11 c0 	movl   $0xc011bf7c,-0x4c(%ebp)
    return list->next == list;
c010516e:	8b 45 b4             	mov    -0x4c(%ebp),%eax
c0105171:	8b 40 04             	mov    0x4(%eax),%eax
c0105174:	39 45 b4             	cmp    %eax,-0x4c(%ebp)
c0105177:	0f 94 c0             	sete   %al
c010517a:	0f b6 c0             	movzbl %al,%eax
    list_init(&free_list);
    assert(list_empty(&free_list));
c010517d:	85 c0                	test   %eax,%eax
c010517f:	75 24                	jne    c01051a5 <default_check+0x1d0>
c0105181:	c7 44 24 0c a7 70 10 	movl   $0xc01070a7,0xc(%esp)
c0105188:	c0 
c0105189:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105190:	c0 
c0105191:	c7 44 24 04 2b 01 00 	movl   $0x12b,0x4(%esp)
c0105198:	00 
c0105199:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01051a0:	e8 54 b2 ff ff       	call   c01003f9 <__panic>
    assert(alloc_page() == NULL);
c01051a5:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c01051ac:	e8 ba db ff ff       	call   c0102d6b <alloc_pages>
c01051b1:	85 c0                	test   %eax,%eax
c01051b3:	74 24                	je     c01051d9 <default_check+0x204>
c01051b5:	c7 44 24 0c be 70 10 	movl   $0xc01070be,0xc(%esp)
c01051bc:	c0 
c01051bd:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01051c4:	c0 
c01051c5:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
c01051cc:	00 
c01051cd:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01051d4:	e8 20 b2 ff ff       	call   c01003f9 <__panic>

    unsigned int nr_free_store = nr_free;
c01051d9:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
c01051de:	89 45 e4             	mov    %eax,-0x1c(%ebp)
    nr_free = 0;
c01051e1:	c7 05 84 bf 11 c0 00 	movl   $0x0,0xc011bf84
c01051e8:	00 00 00 

    free_pages(p0 + 2, 3);
c01051eb:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01051ee:	83 c0 28             	add    $0x28,%eax
c01051f1:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c01051f8:	00 
c01051f9:	89 04 24             	mov    %eax,(%esp)
c01051fc:	e8 a2 db ff ff       	call   c0102da3 <free_pages>
    assert(alloc_pages(4) == NULL);
c0105201:	c7 04 24 04 00 00 00 	movl   $0x4,(%esp)
c0105208:	e8 5e db ff ff       	call   c0102d6b <alloc_pages>
c010520d:	85 c0                	test   %eax,%eax
c010520f:	74 24                	je     c0105235 <default_check+0x260>
c0105211:	c7 44 24 0c 64 71 10 	movl   $0xc0107164,0xc(%esp)
c0105218:	c0 
c0105219:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105220:	c0 
c0105221:	c7 44 24 04 32 01 00 	movl   $0x132,0x4(%esp)
c0105228:	00 
c0105229:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105230:	e8 c4 b1 ff ff       	call   c01003f9 <__panic>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
c0105235:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105238:	83 c0 28             	add    $0x28,%eax
c010523b:	83 c0 04             	add    $0x4,%eax
c010523e:	c7 45 ac 01 00 00 00 	movl   $0x1,-0x54(%ebp)
c0105245:	89 45 a8             	mov    %eax,-0x58(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c0105248:	8b 45 a8             	mov    -0x58(%ebp),%eax
c010524b:	8b 55 ac             	mov    -0x54(%ebp),%edx
c010524e:	0f a3 10             	bt     %edx,(%eax)
c0105251:	19 c0                	sbb    %eax,%eax
c0105253:	89 45 a4             	mov    %eax,-0x5c(%ebp)
    return oldbit != 0;
c0105256:	83 7d a4 00          	cmpl   $0x0,-0x5c(%ebp)
c010525a:	0f 95 c0             	setne  %al
c010525d:	0f b6 c0             	movzbl %al,%eax
c0105260:	85 c0                	test   %eax,%eax
c0105262:	74 0e                	je     c0105272 <default_check+0x29d>
c0105264:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105267:	83 c0 28             	add    $0x28,%eax
c010526a:	8b 40 08             	mov    0x8(%eax),%eax
c010526d:	83 f8 03             	cmp    $0x3,%eax
c0105270:	74 24                	je     c0105296 <default_check+0x2c1>
c0105272:	c7 44 24 0c 7c 71 10 	movl   $0xc010717c,0xc(%esp)
c0105279:	c0 
c010527a:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105281:	c0 
c0105282:	c7 44 24 04 33 01 00 	movl   $0x133,0x4(%esp)
c0105289:	00 
c010528a:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105291:	e8 63 b1 ff ff       	call   c01003f9 <__panic>
    assert((p1 = alloc_pages(3)) != NULL);
c0105296:	c7 04 24 03 00 00 00 	movl   $0x3,(%esp)
c010529d:	e8 c9 da ff ff       	call   c0102d6b <alloc_pages>
c01052a2:	89 45 e0             	mov    %eax,-0x20(%ebp)
c01052a5:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
c01052a9:	75 24                	jne    c01052cf <default_check+0x2fa>
c01052ab:	c7 44 24 0c a8 71 10 	movl   $0xc01071a8,0xc(%esp)
c01052b2:	c0 
c01052b3:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01052ba:	c0 
c01052bb:	c7 44 24 04 34 01 00 	movl   $0x134,0x4(%esp)
c01052c2:	00 
c01052c3:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01052ca:	e8 2a b1 ff ff       	call   c01003f9 <__panic>
    assert(alloc_page() == NULL);
c01052cf:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c01052d6:	e8 90 da ff ff       	call   c0102d6b <alloc_pages>
c01052db:	85 c0                	test   %eax,%eax
c01052dd:	74 24                	je     c0105303 <default_check+0x32e>
c01052df:	c7 44 24 0c be 70 10 	movl   $0xc01070be,0xc(%esp)
c01052e6:	c0 
c01052e7:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01052ee:	c0 
c01052ef:	c7 44 24 04 35 01 00 	movl   $0x135,0x4(%esp)
c01052f6:	00 
c01052f7:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01052fe:	e8 f6 b0 ff ff       	call   c01003f9 <__panic>
    assert(p0 + 2 == p1);
c0105303:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105306:	83 c0 28             	add    $0x28,%eax
c0105309:	39 45 e0             	cmp    %eax,-0x20(%ebp)
c010530c:	74 24                	je     c0105332 <default_check+0x35d>
c010530e:	c7 44 24 0c c6 71 10 	movl   $0xc01071c6,0xc(%esp)
c0105315:	c0 
c0105316:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c010531d:	c0 
c010531e:	c7 44 24 04 36 01 00 	movl   $0x136,0x4(%esp)
c0105325:	00 
c0105326:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c010532d:	e8 c7 b0 ff ff       	call   c01003f9 <__panic>

    p2 = p0 + 1;
c0105332:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105335:	83 c0 14             	add    $0x14,%eax
c0105338:	89 45 dc             	mov    %eax,-0x24(%ebp)
    free_page(p0);
c010533b:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c0105342:	00 
c0105343:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105346:	89 04 24             	mov    %eax,(%esp)
c0105349:	e8 55 da ff ff       	call   c0102da3 <free_pages>
    free_pages(p1, 3);
c010534e:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
c0105355:	00 
c0105356:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0105359:	89 04 24             	mov    %eax,(%esp)
c010535c:	e8 42 da ff ff       	call   c0102da3 <free_pages>
    assert(PageProperty(p0) && p0->property == 1);
c0105361:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105364:	83 c0 04             	add    $0x4,%eax
c0105367:	c7 45 a0 01 00 00 00 	movl   $0x1,-0x60(%ebp)
c010536e:	89 45 9c             	mov    %eax,-0x64(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c0105371:	8b 45 9c             	mov    -0x64(%ebp),%eax
c0105374:	8b 55 a0             	mov    -0x60(%ebp),%edx
c0105377:	0f a3 10             	bt     %edx,(%eax)
c010537a:	19 c0                	sbb    %eax,%eax
c010537c:	89 45 98             	mov    %eax,-0x68(%ebp)
    return oldbit != 0;
c010537f:	83 7d 98 00          	cmpl   $0x0,-0x68(%ebp)
c0105383:	0f 95 c0             	setne  %al
c0105386:	0f b6 c0             	movzbl %al,%eax
c0105389:	85 c0                	test   %eax,%eax
c010538b:	74 0b                	je     c0105398 <default_check+0x3c3>
c010538d:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105390:	8b 40 08             	mov    0x8(%eax),%eax
c0105393:	83 f8 01             	cmp    $0x1,%eax
c0105396:	74 24                	je     c01053bc <default_check+0x3e7>
c0105398:	c7 44 24 0c d4 71 10 	movl   $0xc01071d4,0xc(%esp)
c010539f:	c0 
c01053a0:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01053a7:	c0 
c01053a8:	c7 44 24 04 3b 01 00 	movl   $0x13b,0x4(%esp)
c01053af:	00 
c01053b0:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01053b7:	e8 3d b0 ff ff       	call   c01003f9 <__panic>
    assert(PageProperty(p1) && p1->property == 3);
c01053bc:	8b 45 e0             	mov    -0x20(%ebp),%eax
c01053bf:	83 c0 04             	add    $0x4,%eax
c01053c2:	c7 45 94 01 00 00 00 	movl   $0x1,-0x6c(%ebp)
c01053c9:	89 45 90             	mov    %eax,-0x70(%ebp)
    asm volatile ("btl %2, %1; sbbl %0,%0" : "=r" (oldbit) : "m" (*(volatile long *)addr), "Ir" (nr));
c01053cc:	8b 45 90             	mov    -0x70(%ebp),%eax
c01053cf:	8b 55 94             	mov    -0x6c(%ebp),%edx
c01053d2:	0f a3 10             	bt     %edx,(%eax)
c01053d5:	19 c0                	sbb    %eax,%eax
c01053d7:	89 45 8c             	mov    %eax,-0x74(%ebp)
    return oldbit != 0;
c01053da:	83 7d 8c 00          	cmpl   $0x0,-0x74(%ebp)
c01053de:	0f 95 c0             	setne  %al
c01053e1:	0f b6 c0             	movzbl %al,%eax
c01053e4:	85 c0                	test   %eax,%eax
c01053e6:	74 0b                	je     c01053f3 <default_check+0x41e>
c01053e8:	8b 45 e0             	mov    -0x20(%ebp),%eax
c01053eb:	8b 40 08             	mov    0x8(%eax),%eax
c01053ee:	83 f8 03             	cmp    $0x3,%eax
c01053f1:	74 24                	je     c0105417 <default_check+0x442>
c01053f3:	c7 44 24 0c fc 71 10 	movl   $0xc01071fc,0xc(%esp)
c01053fa:	c0 
c01053fb:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105402:	c0 
c0105403:	c7 44 24 04 3c 01 00 	movl   $0x13c,0x4(%esp)
c010540a:	00 
c010540b:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105412:	e8 e2 af ff ff       	call   c01003f9 <__panic>

    assert((p0 = alloc_page()) == p2 - 1);
c0105417:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c010541e:	e8 48 d9 ff ff       	call   c0102d6b <alloc_pages>
c0105423:	89 45 e8             	mov    %eax,-0x18(%ebp)
c0105426:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0105429:	83 e8 14             	sub    $0x14,%eax
c010542c:	39 45 e8             	cmp    %eax,-0x18(%ebp)
c010542f:	74 24                	je     c0105455 <default_check+0x480>
c0105431:	c7 44 24 0c 22 72 10 	movl   $0xc0107222,0xc(%esp)
c0105438:	c0 
c0105439:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105440:	c0 
c0105441:	c7 44 24 04 3e 01 00 	movl   $0x13e,0x4(%esp)
c0105448:	00 
c0105449:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105450:	e8 a4 af ff ff       	call   c01003f9 <__panic>
    free_page(p0);
c0105455:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c010545c:	00 
c010545d:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105460:	89 04 24             	mov    %eax,(%esp)
c0105463:	e8 3b d9 ff ff       	call   c0102da3 <free_pages>
    assert((p0 = alloc_pages(2)) == p2 + 1);
c0105468:	c7 04 24 02 00 00 00 	movl   $0x2,(%esp)
c010546f:	e8 f7 d8 ff ff       	call   c0102d6b <alloc_pages>
c0105474:	89 45 e8             	mov    %eax,-0x18(%ebp)
c0105477:	8b 45 dc             	mov    -0x24(%ebp),%eax
c010547a:	83 c0 14             	add    $0x14,%eax
c010547d:	39 45 e8             	cmp    %eax,-0x18(%ebp)
c0105480:	74 24                	je     c01054a6 <default_check+0x4d1>
c0105482:	c7 44 24 0c 40 72 10 	movl   $0xc0107240,0xc(%esp)
c0105489:	c0 
c010548a:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105491:	c0 
c0105492:	c7 44 24 04 40 01 00 	movl   $0x140,0x4(%esp)
c0105499:	00 
c010549a:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01054a1:	e8 53 af ff ff       	call   c01003f9 <__panic>

    free_pages(p0, 2);
c01054a6:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
c01054ad:	00 
c01054ae:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01054b1:	89 04 24             	mov    %eax,(%esp)
c01054b4:	e8 ea d8 ff ff       	call   c0102da3 <free_pages>
    free_page(p2);
c01054b9:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
c01054c0:	00 
c01054c1:	8b 45 dc             	mov    -0x24(%ebp),%eax
c01054c4:	89 04 24             	mov    %eax,(%esp)
c01054c7:	e8 d7 d8 ff ff       	call   c0102da3 <free_pages>

    assert((p0 = alloc_pages(5)) != NULL);
c01054cc:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
c01054d3:	e8 93 d8 ff ff       	call   c0102d6b <alloc_pages>
c01054d8:	89 45 e8             	mov    %eax,-0x18(%ebp)
c01054db:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c01054df:	75 24                	jne    c0105505 <default_check+0x530>
c01054e1:	c7 44 24 0c 60 72 10 	movl   $0xc0107260,0xc(%esp)
c01054e8:	c0 
c01054e9:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01054f0:	c0 
c01054f1:	c7 44 24 04 45 01 00 	movl   $0x145,0x4(%esp)
c01054f8:	00 
c01054f9:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105500:	e8 f4 ae ff ff       	call   c01003f9 <__panic>
    assert(alloc_page() == NULL);
c0105505:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
c010550c:	e8 5a d8 ff ff       	call   c0102d6b <alloc_pages>
c0105511:	85 c0                	test   %eax,%eax
c0105513:	74 24                	je     c0105539 <default_check+0x564>
c0105515:	c7 44 24 0c be 70 10 	movl   $0xc01070be,0xc(%esp)
c010551c:	c0 
c010551d:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105524:	c0 
c0105525:	c7 44 24 04 46 01 00 	movl   $0x146,0x4(%esp)
c010552c:	00 
c010552d:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105534:	e8 c0 ae ff ff       	call   c01003f9 <__panic>

    assert(nr_free == 0);
c0105539:	a1 84 bf 11 c0       	mov    0xc011bf84,%eax
c010553e:	85 c0                	test   %eax,%eax
c0105540:	74 24                	je     c0105566 <default_check+0x591>
c0105542:	c7 44 24 0c 11 71 10 	movl   $0xc0107111,0xc(%esp)
c0105549:	c0 
c010554a:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105551:	c0 
c0105552:	c7 44 24 04 48 01 00 	movl   $0x148,0x4(%esp)
c0105559:	00 
c010555a:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105561:	e8 93 ae ff ff       	call   c01003f9 <__panic>
    nr_free = nr_free_store;
c0105566:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0105569:	a3 84 bf 11 c0       	mov    %eax,0xc011bf84

    free_list = free_list_store;
c010556e:	8b 45 80             	mov    -0x80(%ebp),%eax
c0105571:	8b 55 84             	mov    -0x7c(%ebp),%edx
c0105574:	a3 7c bf 11 c0       	mov    %eax,0xc011bf7c
c0105579:	89 15 80 bf 11 c0    	mov    %edx,0xc011bf80
    free_pages(p0, 5);
c010557f:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
c0105586:	00 
c0105587:	8b 45 e8             	mov    -0x18(%ebp),%eax
c010558a:	89 04 24             	mov    %eax,(%esp)
c010558d:	e8 11 d8 ff ff       	call   c0102da3 <free_pages>

    le = &free_list;
c0105592:	c7 45 ec 7c bf 11 c0 	movl   $0xc011bf7c,-0x14(%ebp)
    while ((le = list_next(le)) != &free_list) {
c0105599:	eb 5a                	jmp    c01055f5 <default_check+0x620>
        assert(le->next->prev == le && le->prev->next == le);
c010559b:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010559e:	8b 40 04             	mov    0x4(%eax),%eax
c01055a1:	8b 00                	mov    (%eax),%eax
c01055a3:	39 45 ec             	cmp    %eax,-0x14(%ebp)
c01055a6:	75 0d                	jne    c01055b5 <default_check+0x5e0>
c01055a8:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01055ab:	8b 00                	mov    (%eax),%eax
c01055ad:	8b 40 04             	mov    0x4(%eax),%eax
c01055b0:	39 45 ec             	cmp    %eax,-0x14(%ebp)
c01055b3:	74 24                	je     c01055d9 <default_check+0x604>
c01055b5:	c7 44 24 0c 80 72 10 	movl   $0xc0107280,0xc(%esp)
c01055bc:	c0 
c01055bd:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c01055c4:	c0 
c01055c5:	c7 44 24 04 50 01 00 	movl   $0x150,0x4(%esp)
c01055cc:	00 
c01055cd:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c01055d4:	e8 20 ae ff ff       	call   c01003f9 <__panic>
        struct Page *p = le2page(le, page_link);
c01055d9:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01055dc:	83 e8 0c             	sub    $0xc,%eax
c01055df:	89 45 d8             	mov    %eax,-0x28(%ebp)
        count --, total -= p->property;
c01055e2:	ff 4d f4             	decl   -0xc(%ebp)
c01055e5:	8b 55 f0             	mov    -0x10(%ebp),%edx
c01055e8:	8b 45 d8             	mov    -0x28(%ebp),%eax
c01055eb:	8b 40 08             	mov    0x8(%eax),%eax
c01055ee:	29 c2                	sub    %eax,%edx
c01055f0:	89 d0                	mov    %edx,%eax
c01055f2:	89 45 f0             	mov    %eax,-0x10(%ebp)
c01055f5:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01055f8:	89 45 88             	mov    %eax,-0x78(%ebp)
    return listelm->next;
c01055fb:	8b 45 88             	mov    -0x78(%ebp),%eax
c01055fe:	8b 40 04             	mov    0x4(%eax),%eax
    while ((le = list_next(le)) != &free_list) {
c0105601:	89 45 ec             	mov    %eax,-0x14(%ebp)
c0105604:	81 7d ec 7c bf 11 c0 	cmpl   $0xc011bf7c,-0x14(%ebp)
c010560b:	75 8e                	jne    c010559b <default_check+0x5c6>
    }
    assert(count == 0);
c010560d:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
c0105611:	74 24                	je     c0105637 <default_check+0x662>
c0105613:	c7 44 24 0c ad 72 10 	movl   $0xc01072ad,0xc(%esp)
c010561a:	c0 
c010561b:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c0105622:	c0 
c0105623:	c7 44 24 04 54 01 00 	movl   $0x154,0x4(%esp)
c010562a:	00 
c010562b:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c0105632:	e8 c2 ad ff ff       	call   c01003f9 <__panic>
    assert(total == 0);
c0105637:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c010563b:	74 24                	je     c0105661 <default_check+0x68c>
c010563d:	c7 44 24 0c b8 72 10 	movl   $0xc01072b8,0xc(%esp)
c0105644:	c0 
c0105645:	c7 44 24 08 1e 6f 10 	movl   $0xc0106f1e,0x8(%esp)
c010564c:	c0 
c010564d:	c7 44 24 04 55 01 00 	movl   $0x155,0x4(%esp)
c0105654:	00 
c0105655:	c7 04 24 33 6f 10 c0 	movl   $0xc0106f33,(%esp)
c010565c:	e8 98 ad ff ff       	call   c01003f9 <__panic>
}
c0105661:	90                   	nop
c0105662:	c9                   	leave  
c0105663:	c3                   	ret    

c0105664 <strlen>:
 * @s:      the input string
 *
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
c0105664:	55                   	push   %ebp
c0105665:	89 e5                	mov    %esp,%ebp
c0105667:	83 ec 10             	sub    $0x10,%esp
    size_t cnt = 0;
c010566a:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
    while (*s ++ != '\0') {
c0105671:	eb 03                	jmp    c0105676 <strlen+0x12>
        cnt ++;
c0105673:	ff 45 fc             	incl   -0x4(%ebp)
    while (*s ++ != '\0') {
c0105676:	8b 45 08             	mov    0x8(%ebp),%eax
c0105679:	8d 50 01             	lea    0x1(%eax),%edx
c010567c:	89 55 08             	mov    %edx,0x8(%ebp)
c010567f:	0f b6 00             	movzbl (%eax),%eax
c0105682:	84 c0                	test   %al,%al
c0105684:	75 ed                	jne    c0105673 <strlen+0xf>
    }
    return cnt;
c0105686:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
c0105689:	c9                   	leave  
c010568a:	c3                   	ret    

c010568b <strnlen>:
 * The return value is strlen(s), if that is less than @len, or
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
c010568b:	55                   	push   %ebp
c010568c:	89 e5                	mov    %esp,%ebp
c010568e:	83 ec 10             	sub    $0x10,%esp
    size_t cnt = 0;
c0105691:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
    while (cnt < len && *s ++ != '\0') {
c0105698:	eb 03                	jmp    c010569d <strnlen+0x12>
        cnt ++;
c010569a:	ff 45 fc             	incl   -0x4(%ebp)
    while (cnt < len && *s ++ != '\0') {
c010569d:	8b 45 fc             	mov    -0x4(%ebp),%eax
c01056a0:	3b 45 0c             	cmp    0xc(%ebp),%eax
c01056a3:	73 10                	jae    c01056b5 <strnlen+0x2a>
c01056a5:	8b 45 08             	mov    0x8(%ebp),%eax
c01056a8:	8d 50 01             	lea    0x1(%eax),%edx
c01056ab:	89 55 08             	mov    %edx,0x8(%ebp)
c01056ae:	0f b6 00             	movzbl (%eax),%eax
c01056b1:	84 c0                	test   %al,%al
c01056b3:	75 e5                	jne    c010569a <strnlen+0xf>
    }
    return cnt;
c01056b5:	8b 45 fc             	mov    -0x4(%ebp),%eax
}
c01056b8:	c9                   	leave  
c01056b9:	c3                   	ret    

c01056ba <strcpy>:
 * To avoid overflows, the size of array pointed by @dst should be long enough to
 * contain the same string as @src (including the terminating null character), and
 * should not overlap in memory with @src.
 * */
char *
strcpy(char *dst, const char *src) {
c01056ba:	55                   	push   %ebp
c01056bb:	89 e5                	mov    %esp,%ebp
c01056bd:	57                   	push   %edi
c01056be:	56                   	push   %esi
c01056bf:	83 ec 20             	sub    $0x20,%esp
c01056c2:	8b 45 08             	mov    0x8(%ebp),%eax
c01056c5:	89 45 f4             	mov    %eax,-0xc(%ebp)
c01056c8:	8b 45 0c             	mov    0xc(%ebp),%eax
c01056cb:	89 45 f0             	mov    %eax,-0x10(%ebp)
#ifndef __HAVE_ARCH_STRCPY
#define __HAVE_ARCH_STRCPY
static inline char *
__strcpy(char *dst, const char *src) {
    int d0, d1, d2;
    asm volatile (
c01056ce:	8b 55 f0             	mov    -0x10(%ebp),%edx
c01056d1:	8b 45 f4             	mov    -0xc(%ebp),%eax
c01056d4:	89 d1                	mov    %edx,%ecx
c01056d6:	89 c2                	mov    %eax,%edx
c01056d8:	89 ce                	mov    %ecx,%esi
c01056da:	89 d7                	mov    %edx,%edi
c01056dc:	ac                   	lods   %ds:(%esi),%al
c01056dd:	aa                   	stos   %al,%es:(%edi)
c01056de:	84 c0                	test   %al,%al
c01056e0:	75 fa                	jne    c01056dc <strcpy+0x22>
c01056e2:	89 fa                	mov    %edi,%edx
c01056e4:	89 f1                	mov    %esi,%ecx
c01056e6:	89 4d ec             	mov    %ecx,-0x14(%ebp)
c01056e9:	89 55 e8             	mov    %edx,-0x18(%ebp)
c01056ec:	89 45 e4             	mov    %eax,-0x1c(%ebp)
        "stosb;"
        "testb %%al, %%al;"
        "jne 1b;"
        : "=&S" (d0), "=&D" (d1), "=&a" (d2)
        : "0" (src), "1" (dst) : "memory");
    return dst;
c01056ef:	8b 45 f4             	mov    -0xc(%ebp),%eax
#ifdef __HAVE_ARCH_STRCPY
    return __strcpy(dst, src);
c01056f2:	90                   	nop
    char *p = dst;
    while ((*p ++ = *src ++) != '\0')
        /* nothing */;
    return dst;
#endif /* __HAVE_ARCH_STRCPY */
}
c01056f3:	83 c4 20             	add    $0x20,%esp
c01056f6:	5e                   	pop    %esi
c01056f7:	5f                   	pop    %edi
c01056f8:	5d                   	pop    %ebp
c01056f9:	c3                   	ret    

c01056fa <strncpy>:
 * @len:    maximum number of characters to be copied from @src
 *
 * The return value is @dst
 * */
char *
strncpy(char *dst, const char *src, size_t len) {
c01056fa:	55                   	push   %ebp
c01056fb:	89 e5                	mov    %esp,%ebp
c01056fd:	83 ec 10             	sub    $0x10,%esp
    char *p = dst;
c0105700:	8b 45 08             	mov    0x8(%ebp),%eax
c0105703:	89 45 fc             	mov    %eax,-0x4(%ebp)
    while (len > 0) {
c0105706:	eb 1e                	jmp    c0105726 <strncpy+0x2c>
        if ((*p = *src) != '\0') {
c0105708:	8b 45 0c             	mov    0xc(%ebp),%eax
c010570b:	0f b6 10             	movzbl (%eax),%edx
c010570e:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0105711:	88 10                	mov    %dl,(%eax)
c0105713:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0105716:	0f b6 00             	movzbl (%eax),%eax
c0105719:	84 c0                	test   %al,%al
c010571b:	74 03                	je     c0105720 <strncpy+0x26>
            src ++;
c010571d:	ff 45 0c             	incl   0xc(%ebp)
        }
        p ++, len --;
c0105720:	ff 45 fc             	incl   -0x4(%ebp)
c0105723:	ff 4d 10             	decl   0x10(%ebp)
    while (len > 0) {
c0105726:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c010572a:	75 dc                	jne    c0105708 <strncpy+0xe>
    }
    return dst;
c010572c:	8b 45 08             	mov    0x8(%ebp),%eax
}
c010572f:	c9                   	leave  
c0105730:	c3                   	ret    

c0105731 <strcmp>:
 * - A value greater than zero indicates that the first character that does
 *   not match has a greater value in @s1 than in @s2;
 * - And a value less than zero indicates the opposite.
 * */
int
strcmp(const char *s1, const char *s2) {
c0105731:	55                   	push   %ebp
c0105732:	89 e5                	mov    %esp,%ebp
c0105734:	57                   	push   %edi
c0105735:	56                   	push   %esi
c0105736:	83 ec 20             	sub    $0x20,%esp
c0105739:	8b 45 08             	mov    0x8(%ebp),%eax
c010573c:	89 45 f4             	mov    %eax,-0xc(%ebp)
c010573f:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105742:	89 45 f0             	mov    %eax,-0x10(%ebp)
    asm volatile (
c0105745:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0105748:	8b 45 f0             	mov    -0x10(%ebp),%eax
c010574b:	89 d1                	mov    %edx,%ecx
c010574d:	89 c2                	mov    %eax,%edx
c010574f:	89 ce                	mov    %ecx,%esi
c0105751:	89 d7                	mov    %edx,%edi
c0105753:	ac                   	lods   %ds:(%esi),%al
c0105754:	ae                   	scas   %es:(%edi),%al
c0105755:	75 08                	jne    c010575f <strcmp+0x2e>
c0105757:	84 c0                	test   %al,%al
c0105759:	75 f8                	jne    c0105753 <strcmp+0x22>
c010575b:	31 c0                	xor    %eax,%eax
c010575d:	eb 04                	jmp    c0105763 <strcmp+0x32>
c010575f:	19 c0                	sbb    %eax,%eax
c0105761:	0c 01                	or     $0x1,%al
c0105763:	89 fa                	mov    %edi,%edx
c0105765:	89 f1                	mov    %esi,%ecx
c0105767:	89 45 ec             	mov    %eax,-0x14(%ebp)
c010576a:	89 4d e8             	mov    %ecx,-0x18(%ebp)
c010576d:	89 55 e4             	mov    %edx,-0x1c(%ebp)
    return ret;
c0105770:	8b 45 ec             	mov    -0x14(%ebp),%eax
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
c0105773:	90                   	nop
    while (*s1 != '\0' && *s1 == *s2) {
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
#endif /* __HAVE_ARCH_STRCMP */
}
c0105774:	83 c4 20             	add    $0x20,%esp
c0105777:	5e                   	pop    %esi
c0105778:	5f                   	pop    %edi
c0105779:	5d                   	pop    %ebp
c010577a:	c3                   	ret    

c010577b <strncmp>:
 * they are equal to each other, it continues with the following pairs until
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
c010577b:	55                   	push   %ebp
c010577c:	89 e5                	mov    %esp,%ebp
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
c010577e:	eb 09                	jmp    c0105789 <strncmp+0xe>
        n --, s1 ++, s2 ++;
c0105780:	ff 4d 10             	decl   0x10(%ebp)
c0105783:	ff 45 08             	incl   0x8(%ebp)
c0105786:	ff 45 0c             	incl   0xc(%ebp)
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
c0105789:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c010578d:	74 1a                	je     c01057a9 <strncmp+0x2e>
c010578f:	8b 45 08             	mov    0x8(%ebp),%eax
c0105792:	0f b6 00             	movzbl (%eax),%eax
c0105795:	84 c0                	test   %al,%al
c0105797:	74 10                	je     c01057a9 <strncmp+0x2e>
c0105799:	8b 45 08             	mov    0x8(%ebp),%eax
c010579c:	0f b6 10             	movzbl (%eax),%edx
c010579f:	8b 45 0c             	mov    0xc(%ebp),%eax
c01057a2:	0f b6 00             	movzbl (%eax),%eax
c01057a5:	38 c2                	cmp    %al,%dl
c01057a7:	74 d7                	je     c0105780 <strncmp+0x5>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
c01057a9:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c01057ad:	74 18                	je     c01057c7 <strncmp+0x4c>
c01057af:	8b 45 08             	mov    0x8(%ebp),%eax
c01057b2:	0f b6 00             	movzbl (%eax),%eax
c01057b5:	0f b6 d0             	movzbl %al,%edx
c01057b8:	8b 45 0c             	mov    0xc(%ebp),%eax
c01057bb:	0f b6 00             	movzbl (%eax),%eax
c01057be:	0f b6 c0             	movzbl %al,%eax
c01057c1:	29 c2                	sub    %eax,%edx
c01057c3:	89 d0                	mov    %edx,%eax
c01057c5:	eb 05                	jmp    c01057cc <strncmp+0x51>
c01057c7:	b8 00 00 00 00       	mov    $0x0,%eax
}
c01057cc:	5d                   	pop    %ebp
c01057cd:	c3                   	ret    

c01057ce <strchr>:
 *
 * The strchr() function returns a pointer to the first occurrence of
 * character in @s. If the value is not found, the function returns 'NULL'.
 * */
char *
strchr(const char *s, char c) {
c01057ce:	55                   	push   %ebp
c01057cf:	89 e5                	mov    %esp,%ebp
c01057d1:	83 ec 04             	sub    $0x4,%esp
c01057d4:	8b 45 0c             	mov    0xc(%ebp),%eax
c01057d7:	88 45 fc             	mov    %al,-0x4(%ebp)
    while (*s != '\0') {
c01057da:	eb 13                	jmp    c01057ef <strchr+0x21>
        if (*s == c) {
c01057dc:	8b 45 08             	mov    0x8(%ebp),%eax
c01057df:	0f b6 00             	movzbl (%eax),%eax
c01057e2:	38 45 fc             	cmp    %al,-0x4(%ebp)
c01057e5:	75 05                	jne    c01057ec <strchr+0x1e>
            return (char *)s;
c01057e7:	8b 45 08             	mov    0x8(%ebp),%eax
c01057ea:	eb 12                	jmp    c01057fe <strchr+0x30>
        }
        s ++;
c01057ec:	ff 45 08             	incl   0x8(%ebp)
    while (*s != '\0') {
c01057ef:	8b 45 08             	mov    0x8(%ebp),%eax
c01057f2:	0f b6 00             	movzbl (%eax),%eax
c01057f5:	84 c0                	test   %al,%al
c01057f7:	75 e3                	jne    c01057dc <strchr+0xe>
    }
    return NULL;
c01057f9:	b8 00 00 00 00       	mov    $0x0,%eax
}
c01057fe:	c9                   	leave  
c01057ff:	c3                   	ret    

c0105800 <strfind>:
 * The strfind() function is like strchr() except that if @c is
 * not found in @s, then it returns a pointer to the null byte at the
 * end of @s, rather than 'NULL'.
 * */
char *
strfind(const char *s, char c) {
c0105800:	55                   	push   %ebp
c0105801:	89 e5                	mov    %esp,%ebp
c0105803:	83 ec 04             	sub    $0x4,%esp
c0105806:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105809:	88 45 fc             	mov    %al,-0x4(%ebp)
    while (*s != '\0') {
c010580c:	eb 0e                	jmp    c010581c <strfind+0x1c>
        if (*s == c) {
c010580e:	8b 45 08             	mov    0x8(%ebp),%eax
c0105811:	0f b6 00             	movzbl (%eax),%eax
c0105814:	38 45 fc             	cmp    %al,-0x4(%ebp)
c0105817:	74 0f                	je     c0105828 <strfind+0x28>
            break;
        }
        s ++;
c0105819:	ff 45 08             	incl   0x8(%ebp)
    while (*s != '\0') {
c010581c:	8b 45 08             	mov    0x8(%ebp),%eax
c010581f:	0f b6 00             	movzbl (%eax),%eax
c0105822:	84 c0                	test   %al,%al
c0105824:	75 e8                	jne    c010580e <strfind+0xe>
c0105826:	eb 01                	jmp    c0105829 <strfind+0x29>
            break;
c0105828:	90                   	nop
    }
    return (char *)s;
c0105829:	8b 45 08             	mov    0x8(%ebp),%eax
}
c010582c:	c9                   	leave  
c010582d:	c3                   	ret    

c010582e <strtol>:
 * an optional "0x" or "0X" prefix.
 *
 * The strtol() function returns the converted integral number as a long int value.
 * */
long
strtol(const char *s, char **endptr, int base) {
c010582e:	55                   	push   %ebp
c010582f:	89 e5                	mov    %esp,%ebp
c0105831:	83 ec 10             	sub    $0x10,%esp
    int neg = 0;
c0105834:	c7 45 fc 00 00 00 00 	movl   $0x0,-0x4(%ebp)
    long val = 0;
c010583b:	c7 45 f8 00 00 00 00 	movl   $0x0,-0x8(%ebp)

    // gobble initial whitespace
    while (*s == ' ' || *s == '\t') {
c0105842:	eb 03                	jmp    c0105847 <strtol+0x19>
        s ++;
c0105844:	ff 45 08             	incl   0x8(%ebp)
    while (*s == ' ' || *s == '\t') {
c0105847:	8b 45 08             	mov    0x8(%ebp),%eax
c010584a:	0f b6 00             	movzbl (%eax),%eax
c010584d:	3c 20                	cmp    $0x20,%al
c010584f:	74 f3                	je     c0105844 <strtol+0x16>
c0105851:	8b 45 08             	mov    0x8(%ebp),%eax
c0105854:	0f b6 00             	movzbl (%eax),%eax
c0105857:	3c 09                	cmp    $0x9,%al
c0105859:	74 e9                	je     c0105844 <strtol+0x16>
    }

    // plus/minus sign
    if (*s == '+') {
c010585b:	8b 45 08             	mov    0x8(%ebp),%eax
c010585e:	0f b6 00             	movzbl (%eax),%eax
c0105861:	3c 2b                	cmp    $0x2b,%al
c0105863:	75 05                	jne    c010586a <strtol+0x3c>
        s ++;
c0105865:	ff 45 08             	incl   0x8(%ebp)
c0105868:	eb 14                	jmp    c010587e <strtol+0x50>
    }
    else if (*s == '-') {
c010586a:	8b 45 08             	mov    0x8(%ebp),%eax
c010586d:	0f b6 00             	movzbl (%eax),%eax
c0105870:	3c 2d                	cmp    $0x2d,%al
c0105872:	75 0a                	jne    c010587e <strtol+0x50>
        s ++, neg = 1;
c0105874:	ff 45 08             	incl   0x8(%ebp)
c0105877:	c7 45 fc 01 00 00 00 	movl   $0x1,-0x4(%ebp)
    }

    // hex or octal base prefix
    if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x')) {
c010587e:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c0105882:	74 06                	je     c010588a <strtol+0x5c>
c0105884:	83 7d 10 10          	cmpl   $0x10,0x10(%ebp)
c0105888:	75 22                	jne    c01058ac <strtol+0x7e>
c010588a:	8b 45 08             	mov    0x8(%ebp),%eax
c010588d:	0f b6 00             	movzbl (%eax),%eax
c0105890:	3c 30                	cmp    $0x30,%al
c0105892:	75 18                	jne    c01058ac <strtol+0x7e>
c0105894:	8b 45 08             	mov    0x8(%ebp),%eax
c0105897:	40                   	inc    %eax
c0105898:	0f b6 00             	movzbl (%eax),%eax
c010589b:	3c 78                	cmp    $0x78,%al
c010589d:	75 0d                	jne    c01058ac <strtol+0x7e>
        s += 2, base = 16;
c010589f:	83 45 08 02          	addl   $0x2,0x8(%ebp)
c01058a3:	c7 45 10 10 00 00 00 	movl   $0x10,0x10(%ebp)
c01058aa:	eb 29                	jmp    c01058d5 <strtol+0xa7>
    }
    else if (base == 0 && s[0] == '0') {
c01058ac:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c01058b0:	75 16                	jne    c01058c8 <strtol+0x9a>
c01058b2:	8b 45 08             	mov    0x8(%ebp),%eax
c01058b5:	0f b6 00             	movzbl (%eax),%eax
c01058b8:	3c 30                	cmp    $0x30,%al
c01058ba:	75 0c                	jne    c01058c8 <strtol+0x9a>
        s ++, base = 8;
c01058bc:	ff 45 08             	incl   0x8(%ebp)
c01058bf:	c7 45 10 08 00 00 00 	movl   $0x8,0x10(%ebp)
c01058c6:	eb 0d                	jmp    c01058d5 <strtol+0xa7>
    }
    else if (base == 0) {
c01058c8:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
c01058cc:	75 07                	jne    c01058d5 <strtol+0xa7>
        base = 10;
c01058ce:	c7 45 10 0a 00 00 00 	movl   $0xa,0x10(%ebp)

    // digits
    while (1) {
        int dig;

        if (*s >= '0' && *s <= '9') {
c01058d5:	8b 45 08             	mov    0x8(%ebp),%eax
c01058d8:	0f b6 00             	movzbl (%eax),%eax
c01058db:	3c 2f                	cmp    $0x2f,%al
c01058dd:	7e 1b                	jle    c01058fa <strtol+0xcc>
c01058df:	8b 45 08             	mov    0x8(%ebp),%eax
c01058e2:	0f b6 00             	movzbl (%eax),%eax
c01058e5:	3c 39                	cmp    $0x39,%al
c01058e7:	7f 11                	jg     c01058fa <strtol+0xcc>
            dig = *s - '0';
c01058e9:	8b 45 08             	mov    0x8(%ebp),%eax
c01058ec:	0f b6 00             	movzbl (%eax),%eax
c01058ef:	0f be c0             	movsbl %al,%eax
c01058f2:	83 e8 30             	sub    $0x30,%eax
c01058f5:	89 45 f4             	mov    %eax,-0xc(%ebp)
c01058f8:	eb 48                	jmp    c0105942 <strtol+0x114>
        }
        else if (*s >= 'a' && *s <= 'z') {
c01058fa:	8b 45 08             	mov    0x8(%ebp),%eax
c01058fd:	0f b6 00             	movzbl (%eax),%eax
c0105900:	3c 60                	cmp    $0x60,%al
c0105902:	7e 1b                	jle    c010591f <strtol+0xf1>
c0105904:	8b 45 08             	mov    0x8(%ebp),%eax
c0105907:	0f b6 00             	movzbl (%eax),%eax
c010590a:	3c 7a                	cmp    $0x7a,%al
c010590c:	7f 11                	jg     c010591f <strtol+0xf1>
            dig = *s - 'a' + 10;
c010590e:	8b 45 08             	mov    0x8(%ebp),%eax
c0105911:	0f b6 00             	movzbl (%eax),%eax
c0105914:	0f be c0             	movsbl %al,%eax
c0105917:	83 e8 57             	sub    $0x57,%eax
c010591a:	89 45 f4             	mov    %eax,-0xc(%ebp)
c010591d:	eb 23                	jmp    c0105942 <strtol+0x114>
        }
        else if (*s >= 'A' && *s <= 'Z') {
c010591f:	8b 45 08             	mov    0x8(%ebp),%eax
c0105922:	0f b6 00             	movzbl (%eax),%eax
c0105925:	3c 40                	cmp    $0x40,%al
c0105927:	7e 3b                	jle    c0105964 <strtol+0x136>
c0105929:	8b 45 08             	mov    0x8(%ebp),%eax
c010592c:	0f b6 00             	movzbl (%eax),%eax
c010592f:	3c 5a                	cmp    $0x5a,%al
c0105931:	7f 31                	jg     c0105964 <strtol+0x136>
            dig = *s - 'A' + 10;
c0105933:	8b 45 08             	mov    0x8(%ebp),%eax
c0105936:	0f b6 00             	movzbl (%eax),%eax
c0105939:	0f be c0             	movsbl %al,%eax
c010593c:	83 e8 37             	sub    $0x37,%eax
c010593f:	89 45 f4             	mov    %eax,-0xc(%ebp)
        }
        else {
            break;
        }
        if (dig >= base) {
c0105942:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0105945:	3b 45 10             	cmp    0x10(%ebp),%eax
c0105948:	7d 19                	jge    c0105963 <strtol+0x135>
            break;
        }
        s ++, val = (val * base) + dig;
c010594a:	ff 45 08             	incl   0x8(%ebp)
c010594d:	8b 45 f8             	mov    -0x8(%ebp),%eax
c0105950:	0f af 45 10          	imul   0x10(%ebp),%eax
c0105954:	89 c2                	mov    %eax,%edx
c0105956:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0105959:	01 d0                	add    %edx,%eax
c010595b:	89 45 f8             	mov    %eax,-0x8(%ebp)
    while (1) {
c010595e:	e9 72 ff ff ff       	jmp    c01058d5 <strtol+0xa7>
            break;
c0105963:	90                   	nop
        // we don't properly detect overflow!
    }

    if (endptr) {
c0105964:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
c0105968:	74 08                	je     c0105972 <strtol+0x144>
        *endptr = (char *) s;
c010596a:	8b 45 0c             	mov    0xc(%ebp),%eax
c010596d:	8b 55 08             	mov    0x8(%ebp),%edx
c0105970:	89 10                	mov    %edx,(%eax)
    }
    return (neg ? -val : val);
c0105972:	83 7d fc 00          	cmpl   $0x0,-0x4(%ebp)
c0105976:	74 07                	je     c010597f <strtol+0x151>
c0105978:	8b 45 f8             	mov    -0x8(%ebp),%eax
c010597b:	f7 d8                	neg    %eax
c010597d:	eb 03                	jmp    c0105982 <strtol+0x154>
c010597f:	8b 45 f8             	mov    -0x8(%ebp),%eax
}
c0105982:	c9                   	leave  
c0105983:	c3                   	ret    

c0105984 <memset>:
 * @n:      number of bytes to be set to the value
 *
 * The memset() function returns @s.
 * */
void *
memset(void *s, char c, size_t n) {
c0105984:	55                   	push   %ebp
c0105985:	89 e5                	mov    %esp,%ebp
c0105987:	57                   	push   %edi
c0105988:	83 ec 24             	sub    $0x24,%esp
c010598b:	8b 45 0c             	mov    0xc(%ebp),%eax
c010598e:	88 45 d8             	mov    %al,-0x28(%ebp)
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
c0105991:	0f be 45 d8          	movsbl -0x28(%ebp),%eax
c0105995:	8b 55 08             	mov    0x8(%ebp),%edx
c0105998:	89 55 f8             	mov    %edx,-0x8(%ebp)
c010599b:	88 45 f7             	mov    %al,-0x9(%ebp)
c010599e:	8b 45 10             	mov    0x10(%ebp),%eax
c01059a1:	89 45 f0             	mov    %eax,-0x10(%ebp)
#ifndef __HAVE_ARCH_MEMSET
#define __HAVE_ARCH_MEMSET
static inline void *
__memset(void *s, char c, size_t n) {
    int d0, d1;
    asm volatile (
c01059a4:	8b 4d f0             	mov    -0x10(%ebp),%ecx
c01059a7:	0f b6 45 f7          	movzbl -0x9(%ebp),%eax
c01059ab:	8b 55 f8             	mov    -0x8(%ebp),%edx
c01059ae:	89 d7                	mov    %edx,%edi
c01059b0:	f3 aa                	rep stos %al,%es:(%edi)
c01059b2:	89 fa                	mov    %edi,%edx
c01059b4:	89 4d ec             	mov    %ecx,-0x14(%ebp)
c01059b7:	89 55 e8             	mov    %edx,-0x18(%ebp)
        "rep; stosb;"
        : "=&c" (d0), "=&D" (d1)
        : "0" (n), "a" (c), "1" (s)
        : "memory");
    return s;
c01059ba:	8b 45 f8             	mov    -0x8(%ebp),%eax
c01059bd:	90                   	nop
    while (n -- > 0) {
        *p ++ = c;
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
c01059be:	83 c4 24             	add    $0x24,%esp
c01059c1:	5f                   	pop    %edi
c01059c2:	5d                   	pop    %ebp
c01059c3:	c3                   	ret    

c01059c4 <memmove>:
 * @n:      number of bytes to copy
 *
 * The memmove() function returns @dst.
 * */
void *
memmove(void *dst, const void *src, size_t n) {
c01059c4:	55                   	push   %ebp
c01059c5:	89 e5                	mov    %esp,%ebp
c01059c7:	57                   	push   %edi
c01059c8:	56                   	push   %esi
c01059c9:	53                   	push   %ebx
c01059ca:	83 ec 30             	sub    $0x30,%esp
c01059cd:	8b 45 08             	mov    0x8(%ebp),%eax
c01059d0:	89 45 f0             	mov    %eax,-0x10(%ebp)
c01059d3:	8b 45 0c             	mov    0xc(%ebp),%eax
c01059d6:	89 45 ec             	mov    %eax,-0x14(%ebp)
c01059d9:	8b 45 10             	mov    0x10(%ebp),%eax
c01059dc:	89 45 e8             	mov    %eax,-0x18(%ebp)

#ifndef __HAVE_ARCH_MEMMOVE
#define __HAVE_ARCH_MEMMOVE
static inline void *
__memmove(void *dst, const void *src, size_t n) {
    if (dst < src) {
c01059df:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01059e2:	3b 45 ec             	cmp    -0x14(%ebp),%eax
c01059e5:	73 42                	jae    c0105a29 <memmove+0x65>
c01059e7:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01059ea:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c01059ed:	8b 45 ec             	mov    -0x14(%ebp),%eax
c01059f0:	89 45 e0             	mov    %eax,-0x20(%ebp)
c01059f3:	8b 45 e8             	mov    -0x18(%ebp),%eax
c01059f6:	89 45 dc             	mov    %eax,-0x24(%ebp)
        "andl $3, %%ecx;"
        "jz 1f;"
        "rep; movsb;"
        "1:"
        : "=&c" (d0), "=&D" (d1), "=&S" (d2)
        : "0" (n / 4), "g" (n), "1" (dst), "2" (src)
c01059f9:	8b 45 dc             	mov    -0x24(%ebp),%eax
c01059fc:	c1 e8 02             	shr    $0x2,%eax
c01059ff:	89 c1                	mov    %eax,%ecx
    asm volatile (
c0105a01:	8b 55 e4             	mov    -0x1c(%ebp),%edx
c0105a04:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0105a07:	89 d7                	mov    %edx,%edi
c0105a09:	89 c6                	mov    %eax,%esi
c0105a0b:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
c0105a0d:	8b 4d dc             	mov    -0x24(%ebp),%ecx
c0105a10:	83 e1 03             	and    $0x3,%ecx
c0105a13:	74 02                	je     c0105a17 <memmove+0x53>
c0105a15:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
c0105a17:	89 f0                	mov    %esi,%eax
c0105a19:	89 fa                	mov    %edi,%edx
c0105a1b:	89 4d d8             	mov    %ecx,-0x28(%ebp)
c0105a1e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
c0105a21:	89 45 d0             	mov    %eax,-0x30(%ebp)
        : "memory");
    return dst;
c0105a24:	8b 45 e4             	mov    -0x1c(%ebp),%eax
#ifdef __HAVE_ARCH_MEMMOVE
    return __memmove(dst, src, n);
c0105a27:	eb 36                	jmp    c0105a5f <memmove+0x9b>
        : "0" (n), "1" (n - 1 + src), "2" (n - 1 + dst)
c0105a29:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105a2c:	8d 50 ff             	lea    -0x1(%eax),%edx
c0105a2f:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0105a32:	01 c2                	add    %eax,%edx
c0105a34:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105a37:	8d 48 ff             	lea    -0x1(%eax),%ecx
c0105a3a:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105a3d:	8d 1c 01             	lea    (%ecx,%eax,1),%ebx
    asm volatile (
c0105a40:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105a43:	89 c1                	mov    %eax,%ecx
c0105a45:	89 d8                	mov    %ebx,%eax
c0105a47:	89 d6                	mov    %edx,%esi
c0105a49:	89 c7                	mov    %eax,%edi
c0105a4b:	fd                   	std    
c0105a4c:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
c0105a4e:	fc                   	cld    
c0105a4f:	89 f8                	mov    %edi,%eax
c0105a51:	89 f2                	mov    %esi,%edx
c0105a53:	89 4d cc             	mov    %ecx,-0x34(%ebp)
c0105a56:	89 55 c8             	mov    %edx,-0x38(%ebp)
c0105a59:	89 45 c4             	mov    %eax,-0x3c(%ebp)
    return dst;
c0105a5c:	8b 45 f0             	mov    -0x10(%ebp),%eax
            *d ++ = *s ++;
        }
    }
    return dst;
#endif /* __HAVE_ARCH_MEMMOVE */
}
c0105a5f:	83 c4 30             	add    $0x30,%esp
c0105a62:	5b                   	pop    %ebx
c0105a63:	5e                   	pop    %esi
c0105a64:	5f                   	pop    %edi
c0105a65:	5d                   	pop    %ebp
c0105a66:	c3                   	ret    

c0105a67 <memcpy>:
 * it always copies exactly @n bytes. To avoid overflows, the size of arrays pointed
 * by both @src and @dst, should be at least @n bytes, and should not overlap
 * (for overlapping memory area, memmove is a safer approach).
 * */
void *
memcpy(void *dst, const void *src, size_t n) {
c0105a67:	55                   	push   %ebp
c0105a68:	89 e5                	mov    %esp,%ebp
c0105a6a:	57                   	push   %edi
c0105a6b:	56                   	push   %esi
c0105a6c:	83 ec 20             	sub    $0x20,%esp
c0105a6f:	8b 45 08             	mov    0x8(%ebp),%eax
c0105a72:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0105a75:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105a78:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0105a7b:	8b 45 10             	mov    0x10(%ebp),%eax
c0105a7e:	89 45 ec             	mov    %eax,-0x14(%ebp)
        : "0" (n / 4), "g" (n), "1" (dst), "2" (src)
c0105a81:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0105a84:	c1 e8 02             	shr    $0x2,%eax
c0105a87:	89 c1                	mov    %eax,%ecx
    asm volatile (
c0105a89:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0105a8c:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105a8f:	89 d7                	mov    %edx,%edi
c0105a91:	89 c6                	mov    %eax,%esi
c0105a93:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
c0105a95:	8b 4d ec             	mov    -0x14(%ebp),%ecx
c0105a98:	83 e1 03             	and    $0x3,%ecx
c0105a9b:	74 02                	je     c0105a9f <memcpy+0x38>
c0105a9d:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
c0105a9f:	89 f0                	mov    %esi,%eax
c0105aa1:	89 fa                	mov    %edi,%edx
c0105aa3:	89 4d e8             	mov    %ecx,-0x18(%ebp)
c0105aa6:	89 55 e4             	mov    %edx,-0x1c(%ebp)
c0105aa9:	89 45 e0             	mov    %eax,-0x20(%ebp)
    return dst;
c0105aac:	8b 45 f4             	mov    -0xc(%ebp),%eax
#ifdef __HAVE_ARCH_MEMCPY
    return __memcpy(dst, src, n);
c0105aaf:	90                   	nop
    while (n -- > 0) {
        *d ++ = *s ++;
    }
    return dst;
#endif /* __HAVE_ARCH_MEMCPY */
}
c0105ab0:	83 c4 20             	add    $0x20,%esp
c0105ab3:	5e                   	pop    %esi
c0105ab4:	5f                   	pop    %edi
c0105ab5:	5d                   	pop    %ebp
c0105ab6:	c3                   	ret    

c0105ab7 <memcmp>:
 *   match in both memory blocks has a greater value in @v1 than in @v2
 *   as if evaluated as unsigned char values;
 * - And a value less than zero indicates the opposite.
 * */
int
memcmp(const void *v1, const void *v2, size_t n) {
c0105ab7:	55                   	push   %ebp
c0105ab8:	89 e5                	mov    %esp,%ebp
c0105aba:	83 ec 10             	sub    $0x10,%esp
    const char *s1 = (const char *)v1;
c0105abd:	8b 45 08             	mov    0x8(%ebp),%eax
c0105ac0:	89 45 fc             	mov    %eax,-0x4(%ebp)
    const char *s2 = (const char *)v2;
c0105ac3:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105ac6:	89 45 f8             	mov    %eax,-0x8(%ebp)
    while (n -- > 0) {
c0105ac9:	eb 2e                	jmp    c0105af9 <memcmp+0x42>
        if (*s1 != *s2) {
c0105acb:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0105ace:	0f b6 10             	movzbl (%eax),%edx
c0105ad1:	8b 45 f8             	mov    -0x8(%ebp),%eax
c0105ad4:	0f b6 00             	movzbl (%eax),%eax
c0105ad7:	38 c2                	cmp    %al,%dl
c0105ad9:	74 18                	je     c0105af3 <memcmp+0x3c>
            return (int)((unsigned char)*s1 - (unsigned char)*s2);
c0105adb:	8b 45 fc             	mov    -0x4(%ebp),%eax
c0105ade:	0f b6 00             	movzbl (%eax),%eax
c0105ae1:	0f b6 d0             	movzbl %al,%edx
c0105ae4:	8b 45 f8             	mov    -0x8(%ebp),%eax
c0105ae7:	0f b6 00             	movzbl (%eax),%eax
c0105aea:	0f b6 c0             	movzbl %al,%eax
c0105aed:	29 c2                	sub    %eax,%edx
c0105aef:	89 d0                	mov    %edx,%eax
c0105af1:	eb 18                	jmp    c0105b0b <memcmp+0x54>
        }
        s1 ++, s2 ++;
c0105af3:	ff 45 fc             	incl   -0x4(%ebp)
c0105af6:	ff 45 f8             	incl   -0x8(%ebp)
    while (n -- > 0) {
c0105af9:	8b 45 10             	mov    0x10(%ebp),%eax
c0105afc:	8d 50 ff             	lea    -0x1(%eax),%edx
c0105aff:	89 55 10             	mov    %edx,0x10(%ebp)
c0105b02:	85 c0                	test   %eax,%eax
c0105b04:	75 c5                	jne    c0105acb <memcmp+0x14>
    }
    return 0;
c0105b06:	b8 00 00 00 00       	mov    $0x0,%eax
}
c0105b0b:	c9                   	leave  
c0105b0c:	c3                   	ret    

c0105b0d <printnum>:
 * @width:      maximum number of digits, if the actual width is less than @width, use @padc instead
 * @padc:       character that padded on the left if the actual width is less than @width
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
c0105b0d:	55                   	push   %ebp
c0105b0e:	89 e5                	mov    %esp,%ebp
c0105b10:	83 ec 58             	sub    $0x58,%esp
c0105b13:	8b 45 10             	mov    0x10(%ebp),%eax
c0105b16:	89 45 d0             	mov    %eax,-0x30(%ebp)
c0105b19:	8b 45 14             	mov    0x14(%ebp),%eax
c0105b1c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
    unsigned long long result = num;
c0105b1f:	8b 45 d0             	mov    -0x30(%ebp),%eax
c0105b22:	8b 55 d4             	mov    -0x2c(%ebp),%edx
c0105b25:	89 45 e8             	mov    %eax,-0x18(%ebp)
c0105b28:	89 55 ec             	mov    %edx,-0x14(%ebp)
    unsigned mod = do_div(result, base);
c0105b2b:	8b 45 18             	mov    0x18(%ebp),%eax
c0105b2e:	89 45 e4             	mov    %eax,-0x1c(%ebp)
c0105b31:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105b34:	8b 55 ec             	mov    -0x14(%ebp),%edx
c0105b37:	89 45 e0             	mov    %eax,-0x20(%ebp)
c0105b3a:	89 55 f0             	mov    %edx,-0x10(%ebp)
c0105b3d:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105b40:	89 45 f4             	mov    %eax,-0xc(%ebp)
c0105b43:	83 7d f0 00          	cmpl   $0x0,-0x10(%ebp)
c0105b47:	74 1c                	je     c0105b65 <printnum+0x58>
c0105b49:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105b4c:	ba 00 00 00 00       	mov    $0x0,%edx
c0105b51:	f7 75 e4             	divl   -0x1c(%ebp)
c0105b54:	89 55 f4             	mov    %edx,-0xc(%ebp)
c0105b57:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105b5a:	ba 00 00 00 00       	mov    $0x0,%edx
c0105b5f:	f7 75 e4             	divl   -0x1c(%ebp)
c0105b62:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0105b65:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0105b68:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0105b6b:	f7 75 e4             	divl   -0x1c(%ebp)
c0105b6e:	89 45 e0             	mov    %eax,-0x20(%ebp)
c0105b71:	89 55 dc             	mov    %edx,-0x24(%ebp)
c0105b74:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0105b77:	8b 55 f0             	mov    -0x10(%ebp),%edx
c0105b7a:	89 45 e8             	mov    %eax,-0x18(%ebp)
c0105b7d:	89 55 ec             	mov    %edx,-0x14(%ebp)
c0105b80:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0105b83:	89 45 d8             	mov    %eax,-0x28(%ebp)

    // first recursively print all preceding (more significant) digits
    if (num >= base) {
c0105b86:	8b 45 18             	mov    0x18(%ebp),%eax
c0105b89:	ba 00 00 00 00       	mov    $0x0,%edx
c0105b8e:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
c0105b91:	72 56                	jb     c0105be9 <printnum+0xdc>
c0105b93:	39 55 d4             	cmp    %edx,-0x2c(%ebp)
c0105b96:	77 05                	ja     c0105b9d <printnum+0x90>
c0105b98:	39 45 d0             	cmp    %eax,-0x30(%ebp)
c0105b9b:	72 4c                	jb     c0105be9 <printnum+0xdc>
        printnum(putch, putdat, result, base, width - 1, padc);
c0105b9d:	8b 45 1c             	mov    0x1c(%ebp),%eax
c0105ba0:	8d 50 ff             	lea    -0x1(%eax),%edx
c0105ba3:	8b 45 20             	mov    0x20(%ebp),%eax
c0105ba6:	89 44 24 18          	mov    %eax,0x18(%esp)
c0105baa:	89 54 24 14          	mov    %edx,0x14(%esp)
c0105bae:	8b 45 18             	mov    0x18(%ebp),%eax
c0105bb1:	89 44 24 10          	mov    %eax,0x10(%esp)
c0105bb5:	8b 45 e8             	mov    -0x18(%ebp),%eax
c0105bb8:	8b 55 ec             	mov    -0x14(%ebp),%edx
c0105bbb:	89 44 24 08          	mov    %eax,0x8(%esp)
c0105bbf:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0105bc3:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105bc6:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105bca:	8b 45 08             	mov    0x8(%ebp),%eax
c0105bcd:	89 04 24             	mov    %eax,(%esp)
c0105bd0:	e8 38 ff ff ff       	call   c0105b0d <printnum>
c0105bd5:	eb 1b                	jmp    c0105bf2 <printnum+0xe5>
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
            putch(padc, putdat);
c0105bd7:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105bda:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105bde:	8b 45 20             	mov    0x20(%ebp),%eax
c0105be1:	89 04 24             	mov    %eax,(%esp)
c0105be4:	8b 45 08             	mov    0x8(%ebp),%eax
c0105be7:	ff d0                	call   *%eax
        while (-- width > 0)
c0105be9:	ff 4d 1c             	decl   0x1c(%ebp)
c0105bec:	83 7d 1c 00          	cmpl   $0x0,0x1c(%ebp)
c0105bf0:	7f e5                	jg     c0105bd7 <printnum+0xca>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
c0105bf2:	8b 45 d8             	mov    -0x28(%ebp),%eax
c0105bf5:	05 74 73 10 c0       	add    $0xc0107374,%eax
c0105bfa:	0f b6 00             	movzbl (%eax),%eax
c0105bfd:	0f be c0             	movsbl %al,%eax
c0105c00:	8b 55 0c             	mov    0xc(%ebp),%edx
c0105c03:	89 54 24 04          	mov    %edx,0x4(%esp)
c0105c07:	89 04 24             	mov    %eax,(%esp)
c0105c0a:	8b 45 08             	mov    0x8(%ebp),%eax
c0105c0d:	ff d0                	call   *%eax
}
c0105c0f:	90                   	nop
c0105c10:	c9                   	leave  
c0105c11:	c3                   	ret    

c0105c12 <getuint>:
 * getuint - get an unsigned int of various possible sizes from a varargs list
 * @ap:         a varargs list pointer
 * @lflag:      determines the size of the vararg that @ap points to
 * */
static unsigned long long
getuint(va_list *ap, int lflag) {
c0105c12:	55                   	push   %ebp
c0105c13:	89 e5                	mov    %esp,%ebp
    if (lflag >= 2) {
c0105c15:	83 7d 0c 01          	cmpl   $0x1,0xc(%ebp)
c0105c19:	7e 14                	jle    c0105c2f <getuint+0x1d>
        return va_arg(*ap, unsigned long long);
c0105c1b:	8b 45 08             	mov    0x8(%ebp),%eax
c0105c1e:	8b 00                	mov    (%eax),%eax
c0105c20:	8d 48 08             	lea    0x8(%eax),%ecx
c0105c23:	8b 55 08             	mov    0x8(%ebp),%edx
c0105c26:	89 0a                	mov    %ecx,(%edx)
c0105c28:	8b 50 04             	mov    0x4(%eax),%edx
c0105c2b:	8b 00                	mov    (%eax),%eax
c0105c2d:	eb 30                	jmp    c0105c5f <getuint+0x4d>
    }
    else if (lflag) {
c0105c2f:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
c0105c33:	74 16                	je     c0105c4b <getuint+0x39>
        return va_arg(*ap, unsigned long);
c0105c35:	8b 45 08             	mov    0x8(%ebp),%eax
c0105c38:	8b 00                	mov    (%eax),%eax
c0105c3a:	8d 48 04             	lea    0x4(%eax),%ecx
c0105c3d:	8b 55 08             	mov    0x8(%ebp),%edx
c0105c40:	89 0a                	mov    %ecx,(%edx)
c0105c42:	8b 00                	mov    (%eax),%eax
c0105c44:	ba 00 00 00 00       	mov    $0x0,%edx
c0105c49:	eb 14                	jmp    c0105c5f <getuint+0x4d>
    }
    else {
        return va_arg(*ap, unsigned int);
c0105c4b:	8b 45 08             	mov    0x8(%ebp),%eax
c0105c4e:	8b 00                	mov    (%eax),%eax
c0105c50:	8d 48 04             	lea    0x4(%eax),%ecx
c0105c53:	8b 55 08             	mov    0x8(%ebp),%edx
c0105c56:	89 0a                	mov    %ecx,(%edx)
c0105c58:	8b 00                	mov    (%eax),%eax
c0105c5a:	ba 00 00 00 00       	mov    $0x0,%edx
    }
}
c0105c5f:	5d                   	pop    %ebp
c0105c60:	c3                   	ret    

c0105c61 <getint>:
 * getint - same as getuint but signed, we can't use getuint because of sign extension
 * @ap:         a varargs list pointer
 * @lflag:      determines the size of the vararg that @ap points to
 * */
static long long
getint(va_list *ap, int lflag) {
c0105c61:	55                   	push   %ebp
c0105c62:	89 e5                	mov    %esp,%ebp
    if (lflag >= 2) {
c0105c64:	83 7d 0c 01          	cmpl   $0x1,0xc(%ebp)
c0105c68:	7e 14                	jle    c0105c7e <getint+0x1d>
        return va_arg(*ap, long long);
c0105c6a:	8b 45 08             	mov    0x8(%ebp),%eax
c0105c6d:	8b 00                	mov    (%eax),%eax
c0105c6f:	8d 48 08             	lea    0x8(%eax),%ecx
c0105c72:	8b 55 08             	mov    0x8(%ebp),%edx
c0105c75:	89 0a                	mov    %ecx,(%edx)
c0105c77:	8b 50 04             	mov    0x4(%eax),%edx
c0105c7a:	8b 00                	mov    (%eax),%eax
c0105c7c:	eb 28                	jmp    c0105ca6 <getint+0x45>
    }
    else if (lflag) {
c0105c7e:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
c0105c82:	74 12                	je     c0105c96 <getint+0x35>
        return va_arg(*ap, long);
c0105c84:	8b 45 08             	mov    0x8(%ebp),%eax
c0105c87:	8b 00                	mov    (%eax),%eax
c0105c89:	8d 48 04             	lea    0x4(%eax),%ecx
c0105c8c:	8b 55 08             	mov    0x8(%ebp),%edx
c0105c8f:	89 0a                	mov    %ecx,(%edx)
c0105c91:	8b 00                	mov    (%eax),%eax
c0105c93:	99                   	cltd   
c0105c94:	eb 10                	jmp    c0105ca6 <getint+0x45>
    }
    else {
        return va_arg(*ap, int);
c0105c96:	8b 45 08             	mov    0x8(%ebp),%eax
c0105c99:	8b 00                	mov    (%eax),%eax
c0105c9b:	8d 48 04             	lea    0x4(%eax),%ecx
c0105c9e:	8b 55 08             	mov    0x8(%ebp),%edx
c0105ca1:	89 0a                	mov    %ecx,(%edx)
c0105ca3:	8b 00                	mov    (%eax),%eax
c0105ca5:	99                   	cltd   
    }
}
c0105ca6:	5d                   	pop    %ebp
c0105ca7:	c3                   	ret    

c0105ca8 <printfmt>:
 * @putch:      specified putch function, print a single character
 * @putdat:     used by @putch function
 * @fmt:        the format string to use
 * */
void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
c0105ca8:	55                   	push   %ebp
c0105ca9:	89 e5                	mov    %esp,%ebp
c0105cab:	83 ec 28             	sub    $0x28,%esp
    va_list ap;

    va_start(ap, fmt);
c0105cae:	8d 45 14             	lea    0x14(%ebp),%eax
c0105cb1:	89 45 f4             	mov    %eax,-0xc(%ebp)
    vprintfmt(putch, putdat, fmt, ap);
c0105cb4:	8b 45 f4             	mov    -0xc(%ebp),%eax
c0105cb7:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0105cbb:	8b 45 10             	mov    0x10(%ebp),%eax
c0105cbe:	89 44 24 08          	mov    %eax,0x8(%esp)
c0105cc2:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105cc5:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105cc9:	8b 45 08             	mov    0x8(%ebp),%eax
c0105ccc:	89 04 24             	mov    %eax,(%esp)
c0105ccf:	e8 03 00 00 00       	call   c0105cd7 <vprintfmt>
    va_end(ap);
}
c0105cd4:	90                   	nop
c0105cd5:	c9                   	leave  
c0105cd6:	c3                   	ret    

c0105cd7 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
c0105cd7:	55                   	push   %ebp
c0105cd8:	89 e5                	mov    %esp,%ebp
c0105cda:	56                   	push   %esi
c0105cdb:	53                   	push   %ebx
c0105cdc:	83 ec 40             	sub    $0x40,%esp
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
c0105cdf:	eb 17                	jmp    c0105cf8 <vprintfmt+0x21>
            if (ch == '\0') {
c0105ce1:	85 db                	test   %ebx,%ebx
c0105ce3:	0f 84 bf 03 00 00    	je     c01060a8 <vprintfmt+0x3d1>
                return;
            }
            putch(ch, putdat);
c0105ce9:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105cec:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105cf0:	89 1c 24             	mov    %ebx,(%esp)
c0105cf3:	8b 45 08             	mov    0x8(%ebp),%eax
c0105cf6:	ff d0                	call   *%eax
        while ((ch = *(unsigned char *)fmt ++) != '%') {
c0105cf8:	8b 45 10             	mov    0x10(%ebp),%eax
c0105cfb:	8d 50 01             	lea    0x1(%eax),%edx
c0105cfe:	89 55 10             	mov    %edx,0x10(%ebp)
c0105d01:	0f b6 00             	movzbl (%eax),%eax
c0105d04:	0f b6 d8             	movzbl %al,%ebx
c0105d07:	83 fb 25             	cmp    $0x25,%ebx
c0105d0a:	75 d5                	jne    c0105ce1 <vprintfmt+0xa>
        }

        // Process a %-escape sequence
        char padc = ' ';
c0105d0c:	c6 45 db 20          	movb   $0x20,-0x25(%ebp)
        width = precision = -1;
c0105d10:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
c0105d17:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0105d1a:	89 45 e8             	mov    %eax,-0x18(%ebp)
        lflag = altflag = 0;
c0105d1d:	c7 45 dc 00 00 00 00 	movl   $0x0,-0x24(%ebp)
c0105d24:	8b 45 dc             	mov    -0x24(%ebp),%eax
c0105d27:	89 45 e0             	mov    %eax,-0x20(%ebp)

    reswitch:
        switch (ch = *(unsigned char *)fmt ++) {
c0105d2a:	8b 45 10             	mov    0x10(%ebp),%eax
c0105d2d:	8d 50 01             	lea    0x1(%eax),%edx
c0105d30:	89 55 10             	mov    %edx,0x10(%ebp)
c0105d33:	0f b6 00             	movzbl (%eax),%eax
c0105d36:	0f b6 d8             	movzbl %al,%ebx
c0105d39:	8d 43 dd             	lea    -0x23(%ebx),%eax
c0105d3c:	83 f8 55             	cmp    $0x55,%eax
c0105d3f:	0f 87 37 03 00 00    	ja     c010607c <vprintfmt+0x3a5>
c0105d45:	8b 04 85 98 73 10 c0 	mov    -0x3fef8c68(,%eax,4),%eax
c0105d4c:	ff e0                	jmp    *%eax

        // flag to pad on the right
        case '-':
            padc = '-';
c0105d4e:	c6 45 db 2d          	movb   $0x2d,-0x25(%ebp)
            goto reswitch;
c0105d52:	eb d6                	jmp    c0105d2a <vprintfmt+0x53>

        // flag to pad with 0's instead of spaces
        case '0':
            padc = '0';
c0105d54:	c6 45 db 30          	movb   $0x30,-0x25(%ebp)
            goto reswitch;
c0105d58:	eb d0                	jmp    c0105d2a <vprintfmt+0x53>

        // width field
        case '1' ... '9':
            for (precision = 0; ; ++ fmt) {
c0105d5a:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
                precision = precision * 10 + ch - '0';
c0105d61:	8b 55 e4             	mov    -0x1c(%ebp),%edx
c0105d64:	89 d0                	mov    %edx,%eax
c0105d66:	c1 e0 02             	shl    $0x2,%eax
c0105d69:	01 d0                	add    %edx,%eax
c0105d6b:	01 c0                	add    %eax,%eax
c0105d6d:	01 d8                	add    %ebx,%eax
c0105d6f:	83 e8 30             	sub    $0x30,%eax
c0105d72:	89 45 e4             	mov    %eax,-0x1c(%ebp)
                ch = *fmt;
c0105d75:	8b 45 10             	mov    0x10(%ebp),%eax
c0105d78:	0f b6 00             	movzbl (%eax),%eax
c0105d7b:	0f be d8             	movsbl %al,%ebx
                if (ch < '0' || ch > '9') {
c0105d7e:	83 fb 2f             	cmp    $0x2f,%ebx
c0105d81:	7e 38                	jle    c0105dbb <vprintfmt+0xe4>
c0105d83:	83 fb 39             	cmp    $0x39,%ebx
c0105d86:	7f 33                	jg     c0105dbb <vprintfmt+0xe4>
            for (precision = 0; ; ++ fmt) {
c0105d88:	ff 45 10             	incl   0x10(%ebp)
                precision = precision * 10 + ch - '0';
c0105d8b:	eb d4                	jmp    c0105d61 <vprintfmt+0x8a>
                }
            }
            goto process_precision;

        case '*':
            precision = va_arg(ap, int);
c0105d8d:	8b 45 14             	mov    0x14(%ebp),%eax
c0105d90:	8d 50 04             	lea    0x4(%eax),%edx
c0105d93:	89 55 14             	mov    %edx,0x14(%ebp)
c0105d96:	8b 00                	mov    (%eax),%eax
c0105d98:	89 45 e4             	mov    %eax,-0x1c(%ebp)
            goto process_precision;
c0105d9b:	eb 1f                	jmp    c0105dbc <vprintfmt+0xe5>

        case '.':
            if (width < 0)
c0105d9d:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c0105da1:	79 87                	jns    c0105d2a <vprintfmt+0x53>
                width = 0;
c0105da3:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
            goto reswitch;
c0105daa:	e9 7b ff ff ff       	jmp    c0105d2a <vprintfmt+0x53>

        case '#':
            altflag = 1;
c0105daf:	c7 45 dc 01 00 00 00 	movl   $0x1,-0x24(%ebp)
            goto reswitch;
c0105db6:	e9 6f ff ff ff       	jmp    c0105d2a <vprintfmt+0x53>
            goto process_precision;
c0105dbb:	90                   	nop

        process_precision:
            if (width < 0)
c0105dbc:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c0105dc0:	0f 89 64 ff ff ff    	jns    c0105d2a <vprintfmt+0x53>
                width = precision, precision = -1;
c0105dc6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0105dc9:	89 45 e8             	mov    %eax,-0x18(%ebp)
c0105dcc:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
            goto reswitch;
c0105dd3:	e9 52 ff ff ff       	jmp    c0105d2a <vprintfmt+0x53>

        // long flag (doubled for long long)
        case 'l':
            lflag ++;
c0105dd8:	ff 45 e0             	incl   -0x20(%ebp)
            goto reswitch;
c0105ddb:	e9 4a ff ff ff       	jmp    c0105d2a <vprintfmt+0x53>

        // character
        case 'c':
            putch(va_arg(ap, int), putdat);
c0105de0:	8b 45 14             	mov    0x14(%ebp),%eax
c0105de3:	8d 50 04             	lea    0x4(%eax),%edx
c0105de6:	89 55 14             	mov    %edx,0x14(%ebp)
c0105de9:	8b 00                	mov    (%eax),%eax
c0105deb:	8b 55 0c             	mov    0xc(%ebp),%edx
c0105dee:	89 54 24 04          	mov    %edx,0x4(%esp)
c0105df2:	89 04 24             	mov    %eax,(%esp)
c0105df5:	8b 45 08             	mov    0x8(%ebp),%eax
c0105df8:	ff d0                	call   *%eax
            break;
c0105dfa:	e9 a4 02 00 00       	jmp    c01060a3 <vprintfmt+0x3cc>

        // error message
        case 'e':
            err = va_arg(ap, int);
c0105dff:	8b 45 14             	mov    0x14(%ebp),%eax
c0105e02:	8d 50 04             	lea    0x4(%eax),%edx
c0105e05:	89 55 14             	mov    %edx,0x14(%ebp)
c0105e08:	8b 18                	mov    (%eax),%ebx
            if (err < 0) {
c0105e0a:	85 db                	test   %ebx,%ebx
c0105e0c:	79 02                	jns    c0105e10 <vprintfmt+0x139>
                err = -err;
c0105e0e:	f7 db                	neg    %ebx
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
c0105e10:	83 fb 06             	cmp    $0x6,%ebx
c0105e13:	7f 0b                	jg     c0105e20 <vprintfmt+0x149>
c0105e15:	8b 34 9d 58 73 10 c0 	mov    -0x3fef8ca8(,%ebx,4),%esi
c0105e1c:	85 f6                	test   %esi,%esi
c0105e1e:	75 23                	jne    c0105e43 <vprintfmt+0x16c>
                printfmt(putch, putdat, "error %d", err);
c0105e20:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
c0105e24:	c7 44 24 08 85 73 10 	movl   $0xc0107385,0x8(%esp)
c0105e2b:	c0 
c0105e2c:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105e2f:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105e33:	8b 45 08             	mov    0x8(%ebp),%eax
c0105e36:	89 04 24             	mov    %eax,(%esp)
c0105e39:	e8 6a fe ff ff       	call   c0105ca8 <printfmt>
            }
            else {
                printfmt(putch, putdat, "%s", p);
            }
            break;
c0105e3e:	e9 60 02 00 00       	jmp    c01060a3 <vprintfmt+0x3cc>
                printfmt(putch, putdat, "%s", p);
c0105e43:	89 74 24 0c          	mov    %esi,0xc(%esp)
c0105e47:	c7 44 24 08 8e 73 10 	movl   $0xc010738e,0x8(%esp)
c0105e4e:	c0 
c0105e4f:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105e52:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105e56:	8b 45 08             	mov    0x8(%ebp),%eax
c0105e59:	89 04 24             	mov    %eax,(%esp)
c0105e5c:	e8 47 fe ff ff       	call   c0105ca8 <printfmt>
            break;
c0105e61:	e9 3d 02 00 00       	jmp    c01060a3 <vprintfmt+0x3cc>

        // string
        case 's':
            if ((p = va_arg(ap, char *)) == NULL) {
c0105e66:	8b 45 14             	mov    0x14(%ebp),%eax
c0105e69:	8d 50 04             	lea    0x4(%eax),%edx
c0105e6c:	89 55 14             	mov    %edx,0x14(%ebp)
c0105e6f:	8b 30                	mov    (%eax),%esi
c0105e71:	85 f6                	test   %esi,%esi
c0105e73:	75 05                	jne    c0105e7a <vprintfmt+0x1a3>
                p = "(null)";
c0105e75:	be 91 73 10 c0       	mov    $0xc0107391,%esi
            }
            if (width > 0 && padc != '-') {
c0105e7a:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c0105e7e:	7e 76                	jle    c0105ef6 <vprintfmt+0x21f>
c0105e80:	80 7d db 2d          	cmpb   $0x2d,-0x25(%ebp)
c0105e84:	74 70                	je     c0105ef6 <vprintfmt+0x21f>
                for (width -= strnlen(p, precision); width > 0; width --) {
c0105e86:	8b 45 e4             	mov    -0x1c(%ebp),%eax
c0105e89:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105e8d:	89 34 24             	mov    %esi,(%esp)
c0105e90:	e8 f6 f7 ff ff       	call   c010568b <strnlen>
c0105e95:	8b 55 e8             	mov    -0x18(%ebp),%edx
c0105e98:	29 c2                	sub    %eax,%edx
c0105e9a:	89 d0                	mov    %edx,%eax
c0105e9c:	89 45 e8             	mov    %eax,-0x18(%ebp)
c0105e9f:	eb 16                	jmp    c0105eb7 <vprintfmt+0x1e0>
                    putch(padc, putdat);
c0105ea1:	0f be 45 db          	movsbl -0x25(%ebp),%eax
c0105ea5:	8b 55 0c             	mov    0xc(%ebp),%edx
c0105ea8:	89 54 24 04          	mov    %edx,0x4(%esp)
c0105eac:	89 04 24             	mov    %eax,(%esp)
c0105eaf:	8b 45 08             	mov    0x8(%ebp),%eax
c0105eb2:	ff d0                	call   *%eax
                for (width -= strnlen(p, precision); width > 0; width --) {
c0105eb4:	ff 4d e8             	decl   -0x18(%ebp)
c0105eb7:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c0105ebb:	7f e4                	jg     c0105ea1 <vprintfmt+0x1ca>
                }
            }
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
c0105ebd:	eb 37                	jmp    c0105ef6 <vprintfmt+0x21f>
                if (altflag && (ch < ' ' || ch > '~')) {
c0105ebf:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
c0105ec3:	74 1f                	je     c0105ee4 <vprintfmt+0x20d>
c0105ec5:	83 fb 1f             	cmp    $0x1f,%ebx
c0105ec8:	7e 05                	jle    c0105ecf <vprintfmt+0x1f8>
c0105eca:	83 fb 7e             	cmp    $0x7e,%ebx
c0105ecd:	7e 15                	jle    c0105ee4 <vprintfmt+0x20d>
                    putch('?', putdat);
c0105ecf:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105ed2:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105ed6:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
c0105edd:	8b 45 08             	mov    0x8(%ebp),%eax
c0105ee0:	ff d0                	call   *%eax
c0105ee2:	eb 0f                	jmp    c0105ef3 <vprintfmt+0x21c>
                }
                else {
                    putch(ch, putdat);
c0105ee4:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105ee7:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105eeb:	89 1c 24             	mov    %ebx,(%esp)
c0105eee:	8b 45 08             	mov    0x8(%ebp),%eax
c0105ef1:	ff d0                	call   *%eax
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
c0105ef3:	ff 4d e8             	decl   -0x18(%ebp)
c0105ef6:	89 f0                	mov    %esi,%eax
c0105ef8:	8d 70 01             	lea    0x1(%eax),%esi
c0105efb:	0f b6 00             	movzbl (%eax),%eax
c0105efe:	0f be d8             	movsbl %al,%ebx
c0105f01:	85 db                	test   %ebx,%ebx
c0105f03:	74 27                	je     c0105f2c <vprintfmt+0x255>
c0105f05:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
c0105f09:	78 b4                	js     c0105ebf <vprintfmt+0x1e8>
c0105f0b:	ff 4d e4             	decl   -0x1c(%ebp)
c0105f0e:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
c0105f12:	79 ab                	jns    c0105ebf <vprintfmt+0x1e8>
                }
            }
            for (; width > 0; width --) {
c0105f14:	eb 16                	jmp    c0105f2c <vprintfmt+0x255>
                putch(' ', putdat);
c0105f16:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105f19:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105f1d:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
c0105f24:	8b 45 08             	mov    0x8(%ebp),%eax
c0105f27:	ff d0                	call   *%eax
            for (; width > 0; width --) {
c0105f29:	ff 4d e8             	decl   -0x18(%ebp)
c0105f2c:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
c0105f30:	7f e4                	jg     c0105f16 <vprintfmt+0x23f>
            }
            break;
c0105f32:	e9 6c 01 00 00       	jmp    c01060a3 <vprintfmt+0x3cc>

        // (signed) decimal
        case 'd':
            num = getint(&ap, lflag);
c0105f37:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0105f3a:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105f3e:	8d 45 14             	lea    0x14(%ebp),%eax
c0105f41:	89 04 24             	mov    %eax,(%esp)
c0105f44:	e8 18 fd ff ff       	call   c0105c61 <getint>
c0105f49:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0105f4c:	89 55 f4             	mov    %edx,-0xc(%ebp)
            if ((long long)num < 0) {
c0105f4f:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105f52:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0105f55:	85 d2                	test   %edx,%edx
c0105f57:	79 26                	jns    c0105f7f <vprintfmt+0x2a8>
                putch('-', putdat);
c0105f59:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105f5c:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105f60:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
c0105f67:	8b 45 08             	mov    0x8(%ebp),%eax
c0105f6a:	ff d0                	call   *%eax
                num = -(long long)num;
c0105f6c:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0105f6f:	8b 55 f4             	mov    -0xc(%ebp),%edx
c0105f72:	f7 d8                	neg    %eax
c0105f74:	83 d2 00             	adc    $0x0,%edx
c0105f77:	f7 da                	neg    %edx
c0105f79:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0105f7c:	89 55 f4             	mov    %edx,-0xc(%ebp)
            }
            base = 10;
c0105f7f:	c7 45 ec 0a 00 00 00 	movl   $0xa,-0x14(%ebp)
            goto number;
c0105f86:	e9 a8 00 00 00       	jmp    c0106033 <vprintfmt+0x35c>

        // unsigned decimal
        case 'u':
            num = getuint(&ap, lflag);
c0105f8b:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0105f8e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105f92:	8d 45 14             	lea    0x14(%ebp),%eax
c0105f95:	89 04 24             	mov    %eax,(%esp)
c0105f98:	e8 75 fc ff ff       	call   c0105c12 <getuint>
c0105f9d:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0105fa0:	89 55 f4             	mov    %edx,-0xc(%ebp)
            base = 10;
c0105fa3:	c7 45 ec 0a 00 00 00 	movl   $0xa,-0x14(%ebp)
            goto number;
c0105faa:	e9 84 00 00 00       	jmp    c0106033 <vprintfmt+0x35c>

        // (unsigned) octal
        case 'o':
            num = getuint(&ap, lflag);
c0105faf:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0105fb2:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105fb6:	8d 45 14             	lea    0x14(%ebp),%eax
c0105fb9:	89 04 24             	mov    %eax,(%esp)
c0105fbc:	e8 51 fc ff ff       	call   c0105c12 <getuint>
c0105fc1:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0105fc4:	89 55 f4             	mov    %edx,-0xc(%ebp)
            base = 8;
c0105fc7:	c7 45 ec 08 00 00 00 	movl   $0x8,-0x14(%ebp)
            goto number;
c0105fce:	eb 63                	jmp    c0106033 <vprintfmt+0x35c>

        // pointer
        case 'p':
            putch('0', putdat);
c0105fd0:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105fd3:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105fd7:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
c0105fde:	8b 45 08             	mov    0x8(%ebp),%eax
c0105fe1:	ff d0                	call   *%eax
            putch('x', putdat);
c0105fe3:	8b 45 0c             	mov    0xc(%ebp),%eax
c0105fe6:	89 44 24 04          	mov    %eax,0x4(%esp)
c0105fea:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
c0105ff1:	8b 45 08             	mov    0x8(%ebp),%eax
c0105ff4:	ff d0                	call   *%eax
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
c0105ff6:	8b 45 14             	mov    0x14(%ebp),%eax
c0105ff9:	8d 50 04             	lea    0x4(%eax),%edx
c0105ffc:	89 55 14             	mov    %edx,0x14(%ebp)
c0105fff:	8b 00                	mov    (%eax),%eax
c0106001:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0106004:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
            base = 16;
c010600b:	c7 45 ec 10 00 00 00 	movl   $0x10,-0x14(%ebp)
            goto number;
c0106012:	eb 1f                	jmp    c0106033 <vprintfmt+0x35c>

        // (unsigned) hexadecimal
        case 'x':
            num = getuint(&ap, lflag);
c0106014:	8b 45 e0             	mov    -0x20(%ebp),%eax
c0106017:	89 44 24 04          	mov    %eax,0x4(%esp)
c010601b:	8d 45 14             	lea    0x14(%ebp),%eax
c010601e:	89 04 24             	mov    %eax,(%esp)
c0106021:	e8 ec fb ff ff       	call   c0105c12 <getuint>
c0106026:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0106029:	89 55 f4             	mov    %edx,-0xc(%ebp)
            base = 16;
c010602c:	c7 45 ec 10 00 00 00 	movl   $0x10,-0x14(%ebp)
        number:
            printnum(putch, putdat, num, base, width, padc);
c0106033:	0f be 55 db          	movsbl -0x25(%ebp),%edx
c0106037:	8b 45 ec             	mov    -0x14(%ebp),%eax
c010603a:	89 54 24 18          	mov    %edx,0x18(%esp)
c010603e:	8b 55 e8             	mov    -0x18(%ebp),%edx
c0106041:	89 54 24 14          	mov    %edx,0x14(%esp)
c0106045:	89 44 24 10          	mov    %eax,0x10(%esp)
c0106049:	8b 45 f0             	mov    -0x10(%ebp),%eax
c010604c:	8b 55 f4             	mov    -0xc(%ebp),%edx
c010604f:	89 44 24 08          	mov    %eax,0x8(%esp)
c0106053:	89 54 24 0c          	mov    %edx,0xc(%esp)
c0106057:	8b 45 0c             	mov    0xc(%ebp),%eax
c010605a:	89 44 24 04          	mov    %eax,0x4(%esp)
c010605e:	8b 45 08             	mov    0x8(%ebp),%eax
c0106061:	89 04 24             	mov    %eax,(%esp)
c0106064:	e8 a4 fa ff ff       	call   c0105b0d <printnum>
            break;
c0106069:	eb 38                	jmp    c01060a3 <vprintfmt+0x3cc>

        // escaped '%' character
        case '%':
            putch(ch, putdat);
c010606b:	8b 45 0c             	mov    0xc(%ebp),%eax
c010606e:	89 44 24 04          	mov    %eax,0x4(%esp)
c0106072:	89 1c 24             	mov    %ebx,(%esp)
c0106075:	8b 45 08             	mov    0x8(%ebp),%eax
c0106078:	ff d0                	call   *%eax
            break;
c010607a:	eb 27                	jmp    c01060a3 <vprintfmt+0x3cc>

        // unrecognized escape sequence - just print it literally
        default:
            putch('%', putdat);
c010607c:	8b 45 0c             	mov    0xc(%ebp),%eax
c010607f:	89 44 24 04          	mov    %eax,0x4(%esp)
c0106083:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
c010608a:	8b 45 08             	mov    0x8(%ebp),%eax
c010608d:	ff d0                	call   *%eax
            for (fmt --; fmt[-1] != '%'; fmt --)
c010608f:	ff 4d 10             	decl   0x10(%ebp)
c0106092:	eb 03                	jmp    c0106097 <vprintfmt+0x3c0>
c0106094:	ff 4d 10             	decl   0x10(%ebp)
c0106097:	8b 45 10             	mov    0x10(%ebp),%eax
c010609a:	48                   	dec    %eax
c010609b:	0f b6 00             	movzbl (%eax),%eax
c010609e:	3c 25                	cmp    $0x25,%al
c01060a0:	75 f2                	jne    c0106094 <vprintfmt+0x3bd>
                /* do nothing */;
            break;
c01060a2:	90                   	nop
    while (1) {
c01060a3:	e9 37 fc ff ff       	jmp    c0105cdf <vprintfmt+0x8>
                return;
c01060a8:	90                   	nop
        }
    }
}
c01060a9:	83 c4 40             	add    $0x40,%esp
c01060ac:	5b                   	pop    %ebx
c01060ad:	5e                   	pop    %esi
c01060ae:	5d                   	pop    %ebp
c01060af:	c3                   	ret    

c01060b0 <sprintputch>:
 * sprintputch - 'print' a single character in a buffer
 * @ch:         the character will be printed
 * @b:          the buffer to place the character @ch
 * */
static void
sprintputch(int ch, struct sprintbuf *b) {
c01060b0:	55                   	push   %ebp
c01060b1:	89 e5                	mov    %esp,%ebp
    b->cnt ++;
c01060b3:	8b 45 0c             	mov    0xc(%ebp),%eax
c01060b6:	8b 40 08             	mov    0x8(%eax),%eax
c01060b9:	8d 50 01             	lea    0x1(%eax),%edx
c01060bc:	8b 45 0c             	mov    0xc(%ebp),%eax
c01060bf:	89 50 08             	mov    %edx,0x8(%eax)
    if (b->buf < b->ebuf) {
c01060c2:	8b 45 0c             	mov    0xc(%ebp),%eax
c01060c5:	8b 10                	mov    (%eax),%edx
c01060c7:	8b 45 0c             	mov    0xc(%ebp),%eax
c01060ca:	8b 40 04             	mov    0x4(%eax),%eax
c01060cd:	39 c2                	cmp    %eax,%edx
c01060cf:	73 12                	jae    c01060e3 <sprintputch+0x33>
        *b->buf ++ = ch;
c01060d1:	8b 45 0c             	mov    0xc(%ebp),%eax
c01060d4:	8b 00                	mov    (%eax),%eax
c01060d6:	8d 48 01             	lea    0x1(%eax),%ecx
c01060d9:	8b 55 0c             	mov    0xc(%ebp),%edx
c01060dc:	89 0a                	mov    %ecx,(%edx)
c01060de:	8b 55 08             	mov    0x8(%ebp),%edx
c01060e1:	88 10                	mov    %dl,(%eax)
    }
}
c01060e3:	90                   	nop
c01060e4:	5d                   	pop    %ebp
c01060e5:	c3                   	ret    

c01060e6 <snprintf>:
 * @str:        the buffer to place the result into
 * @size:       the size of buffer, including the trailing null space
 * @fmt:        the format string to use
 * */
int
snprintf(char *str, size_t size, const char *fmt, ...) {
c01060e6:	55                   	push   %ebp
c01060e7:	89 e5                	mov    %esp,%ebp
c01060e9:	83 ec 28             	sub    $0x28,%esp
    va_list ap;
    int cnt;
    va_start(ap, fmt);
c01060ec:	8d 45 14             	lea    0x14(%ebp),%eax
c01060ef:	89 45 f0             	mov    %eax,-0x10(%ebp)
    cnt = vsnprintf(str, size, fmt, ap);
c01060f2:	8b 45 f0             	mov    -0x10(%ebp),%eax
c01060f5:	89 44 24 0c          	mov    %eax,0xc(%esp)
c01060f9:	8b 45 10             	mov    0x10(%ebp),%eax
c01060fc:	89 44 24 08          	mov    %eax,0x8(%esp)
c0106100:	8b 45 0c             	mov    0xc(%ebp),%eax
c0106103:	89 44 24 04          	mov    %eax,0x4(%esp)
c0106107:	8b 45 08             	mov    0x8(%ebp),%eax
c010610a:	89 04 24             	mov    %eax,(%esp)
c010610d:	e8 08 00 00 00       	call   c010611a <vsnprintf>
c0106112:	89 45 f4             	mov    %eax,-0xc(%ebp)
    va_end(ap);
    return cnt;
c0106115:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c0106118:	c9                   	leave  
c0106119:	c3                   	ret    

c010611a <vsnprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want snprintf() instead.
 * */
int
vsnprintf(char *str, size_t size, const char *fmt, va_list ap) {
c010611a:	55                   	push   %ebp
c010611b:	89 e5                	mov    %esp,%ebp
c010611d:	83 ec 28             	sub    $0x28,%esp
    struct sprintbuf b = {str, str + size - 1, 0};
c0106120:	8b 45 08             	mov    0x8(%ebp),%eax
c0106123:	89 45 ec             	mov    %eax,-0x14(%ebp)
c0106126:	8b 45 0c             	mov    0xc(%ebp),%eax
c0106129:	8d 50 ff             	lea    -0x1(%eax),%edx
c010612c:	8b 45 08             	mov    0x8(%ebp),%eax
c010612f:	01 d0                	add    %edx,%eax
c0106131:	89 45 f0             	mov    %eax,-0x10(%ebp)
c0106134:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
    if (str == NULL || b.buf > b.ebuf) {
c010613b:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
c010613f:	74 0a                	je     c010614b <vsnprintf+0x31>
c0106141:	8b 55 ec             	mov    -0x14(%ebp),%edx
c0106144:	8b 45 f0             	mov    -0x10(%ebp),%eax
c0106147:	39 c2                	cmp    %eax,%edx
c0106149:	76 07                	jbe    c0106152 <vsnprintf+0x38>
        return -E_INVAL;
c010614b:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
c0106150:	eb 2a                	jmp    c010617c <vsnprintf+0x62>
    }
    // print the string to the buffer
    vprintfmt((void*)sprintputch, &b, fmt, ap);
c0106152:	8b 45 14             	mov    0x14(%ebp),%eax
c0106155:	89 44 24 0c          	mov    %eax,0xc(%esp)
c0106159:	8b 45 10             	mov    0x10(%ebp),%eax
c010615c:	89 44 24 08          	mov    %eax,0x8(%esp)
c0106160:	8d 45 ec             	lea    -0x14(%ebp),%eax
c0106163:	89 44 24 04          	mov    %eax,0x4(%esp)
c0106167:	c7 04 24 b0 60 10 c0 	movl   $0xc01060b0,(%esp)
c010616e:	e8 64 fb ff ff       	call   c0105cd7 <vprintfmt>
    // null terminate the buffer
    *b.buf = '\0';
c0106173:	8b 45 ec             	mov    -0x14(%ebp),%eax
c0106176:	c6 00 00             	movb   $0x0,(%eax)
    return b.cnt;
c0106179:	8b 45 f4             	mov    -0xc(%ebp),%eax
}
c010617c:	c9                   	leave  
c010617d:	c3                   	ret    
