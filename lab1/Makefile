PROJ	:= challenge
EMPTY	:=
SPACE	:= $(EMPTY) $(EMPTY)
SLASH	:= /
##make “V=”可输出make执行的命令
V       := @
#need llvm/cang-3.5+
#USELLVM := 1
##选择交叉编译器检查GCCPREFIX
# try to infer the correct GCCPREFX
ifndef GCCPREFIX
GCCPREFIX := $(shell if i386-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
	then echo 'i386-elf-'; \
	elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
	then echo ''; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an i386-elf version of GCC/binutils." 1>&2; \
	echo "*** Is the directory with i386-elf-gcc in your PATH?" 1>&2; \
	echo "*** If your i386-elf toolchain is installed with a command" 1>&2; \
	echo "*** prefix other than 'i386-elf-', set your GCCPREFIX" 1>&2; \
	echo "*** environment variable to that prefix and run 'make' again." 1>&2; \
	echo "*** To turn off this error, run 'gmake GCCPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif
##设置QEMU
# try to infer the correct QEMU
ifndef QEMU
QEMU := $(shell if which qemu-system-i386 > /dev/null; \
	then echo 'qemu-system-i386'; exit; \
	elif which i386-elf-qemu > /dev/null; \
	then echo 'i386-elf-qemu'; exit; \
	elif which qemu > /dev/null; \
	then echo 'qemu'; exit; \
	else \
	echo "***" 1>&2; \
	echo "*** Error: Couldn't find a working QEMU executable." 1>&2; \
	echo "*** Is the directory containing the qemu binary in your PATH" 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# eliminate default suffix rules
.SUFFIXES: .c .S .h

##如果遇到error或者被中断了就删除所有目标文件
# delete target files if there is an error (or make is interrupted)
.DELETE_ON_ERROR:

##设置编译器选项
# define compiler and flags
ifndef  USELLVM
##gcc编译，-g为了gdb调试，-Wall生成警告信息，-02优化处理级别
HOSTCC		:= gcc
HOSTCFLAGS	:= -g -Wall -O2
CC		:= $(GCCPREFIX)gcc
##-fno-builtin不使用C语言的内建函数，-ggdb为GDB生成更丰富的调试信息，-m32用32位编译，
##-gstabs生成stabs格式调试信息但不包括GDB调试信息，-nostdinc不在系统默认头文件目录中寻找文件，$(DEFS)未定义可用来扩展信息
CFLAGS	:= -march=i686 -fno-builtin -fno-PIC -Wall -ggdb -m32 -gstabs -nostdinc $(DEFS)
##$(shell)可以输出shell指令，-fno-stack-protector禁用堆栈保护，-E仅预处理不进行编译汇编链接可以提高速度，-x c指明C语言
##/dev/null指定目标文件，>/dev/null 2>&1标准错误重定向到标准输出，&&先运行前一句，若成功再运行后一句
##意为只预处理，所有出错全部作为垃圾(/dev/null类似垃圾文件)测试能否开启-fno-stack-protector，若能则CFLAGS += -fno-stack-protector
CFLAGS	+= $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
else
##若使用clang，类似处理
HOSTCC		:= clang
HOSTCFLAGS	:= -g -Wall -O2
CC		:= clang
CFLAGS	:= -march=i686 -fno-builtin -fno-PIC -Wall -g -m32 -nostdinc $(DEFS)
CFLAGS	+= $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
endif

##源文件类型为.c和.s
CTYPE	:= c S

LD      := $(GCCPREFIX)ld
##shell中命令ld -V可以输出支持的版本，|管道将前者的输出作为后者的输入，grep在输入中搜索elf_i386字串，找到就输出elf_i386
##意味如果支持elf_i386则LDFLAGS := -m elf_i386
LDFLAGS	:= -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)
##-nostdlib不连接系统标准库文件
LDFLAGS	+= -nostdlib

OBJCOPY := $(GCCPREFIX)objcopy
OBJDUMP := $(GCCPREFIX)objdump

##定义一些shell命令
COPY	:= cp
MKDIR   := mkdir -p
MV		:= mv
RM		:= rm -f
AWK		:= awk
SED		:= sed
SH		:= sh
TR		:= tr
TOUCH	:= touch -c

OBJDIR	:= obj
BINDIR	:= bin

ALLOBJS	:=
ALLDEPS	:=
TARGETS	:=

##在function.mk中定义了大量辅助函数
include tools/function.mk

##call:call func,变量1,变量2,... 
##listf:列出某地址下某类型的文件 
##listf_cc:列出变量1下的.c与.S文件
listf_cc = $(call listf,$(1),$(CTYPE))

# for cc
##将文件打包
add_files_cc = $(call add_files,$(1),$(CC),$(CFLAGS) $(3),$(2),$(4))
##创建目标文件包
create_target_cc = $(call create_target,$(1),$(2),$(3),$(CC),$(CFLAGS))

# for hostcc
add_files_host = $(call add_files,$(1),$(HOSTCC),$(HOSTCFLAGS),$(2),$(3))
create_target_host = $(call create_target,$(1),$(2),$(3),$(HOSTCC),$(HOSTCFLAGS))

##patsubst替换通配符 
cgtype = $(patsubst %.$(2),%.$(3),$(1))
##列出所有目标文件，并按规则改后缀名
objfile = $(call toobj,$(1))
asmfile = $(call cgtype,$(call toobj,$(1)),o,asm)
outfile = $(call cgtype,$(call toobj,$(1)),o,out)
symfile = $(call cgtype,$(call toobj,$(1)),o,sym)

# for match pattern
match = $(shell echo $(2) | $(AWK) '{for(i=1;i<=NF;i++){if(match("$(1)","^"$$(i)"$$")){exit 1;}}}'; echo $$?)

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# include kernel/user

INCLUDE	+= libs/

CFLAGS	+= $(addprefix -I,$(INCLUDE))

LIBDIR	+= libs

$(call add_files_cc,$(call listf_cc,$(LIBDIR)),libs,)

# kernel

KINCLUDE	+= kern/debug/ \
			   kern/driver/ \
			   kern/trap/ \
			   kern/mm/

KSRCDIR		+= kern/init \
			   kern/libs \
			   kern/debug \
			   kern/driver \
			   kern/trap \
			   kern/mm

KCFLAGS		+= $(addprefix -I,$(KINCLUDE))

$(call add_files_cc,$(call listf_cc,$(KSRCDIR)),kernel,$(KCFLAGS))

KOBJS	= $(call read_packet,kernel libs)

# create kernel target
##将所有文件链接生成kernel
kernel = $(call totarget,kernel)

$(kernel): tools/kernel.ld

$(kernel): $(KOBJS)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS)
	@$(OBJDUMP) -S $@ > $(call asmfile,kernel)
	@$(OBJDUMP) -t $@ | $(SED) '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(call symfile,kernel)

$(call create_target,kernel)

# -------------------------------------------------------------------

# create bootblock
##将所有文件链接生成bootblock
bootfiles = $(call listf_cc,boot)
$(foreach f,$(bootfiles),$(call cc_compile,$(f),$(CC),$(CFLAGS) -Os -nostdinc))

bootblock = $(call totarget,bootblock)

$(bootblock): $(call toobj,$(bootfiles)) | $(call totarget,sign)
	@echo + ld $@
	$(V)$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 $^ -o $(call toobj,bootblock)
	@$(OBJDUMP) -S $(call objfile,bootblock) > $(call asmfile,bootblock)
	@$(OBJCOPY) -S -O binary $(call objfile,bootblock) $(call outfile,bootblock)
	@$(call totarget,sign) $(call outfile,bootblock) $(bootblock)
##为了生成bootblock，首先需要生成bootasm.o、bootmain.o、sign

$(call create_target,bootblock)

# -------------------------------------------------------------------

# create 'sign' tools
##生成sign辅助工具
$(call add_files_host,tools/sign.c,sign,sign)
$(call create_target_host,sign,sign)

# -------------------------------------------------------------------

# create ucore.img
##生成ucore.img
# 1 编译所有生成bin/kernel所需的文件
# 2 链接生成bin/kernel
# 3 编译bootasm.S  bootmain.c  sign.c 
# 4 根据sign规范生成obj/bootblock.o
# 5 生成ucore.img
UCOREIMG	:= $(call totarget,ucore.img)
##首先要生成一个有10000个块的文件，每个块默认512字节，用0填充
##接着把bootblock中的内容写到第一个块
##从第二个块开始写kernel中的内容
$(UCOREIMG): $(kernel) $(bootblock)
	$(V)dd if=/dev/zero of=$@ count=10000
	$(V)dd if=$(bootblock) of=$@ conv=notrunc
##conv = notrunc 不截短输出文件
	$(V)dd if=$(kernel) of=$@ seek=1 conv=notrunc
##seek=blocks 从输出文件开头跳过blocks个块后再开始复制
##为了生成ucore.img，首先需要生成bootblock、kernel

$(call create_target,ucore.img)

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

$(call finish_all)

IGNORE_ALLDEPS	= clean \
				  dist-clean \
				  grade \
				  touch \
				  print-.+ \
				  handin

ifeq ($(call match,$(MAKECMDGOALS),$(IGNORE_ALLDEPS)),0)
-include $(ALLDEPS)
endif

# files for grade script

TARGETS: $(TARGETS)

.DEFAULT_GOAL := TARGETS

.PHONY: qemu qemu-nox debug debug-nox
qemu-mon: $(UCOREIMG)
	$(V)$(QEMU)  -no-reboot -monitor stdio -hda $< -serial null
qemu: $(UCOREIMG)
	$(V)$(QEMU) -no-reboot -parallel stdio -hda $< -serial null
log: $(UCOREIMG)
	$(V)$(QEMU) -no-reboot -d int,cpu_reset  -D q.log -parallel stdio -hda $< -serial null
qemu-nox: $(UCOREIMG)
	$(V)$(QEMU)   -no-reboot -serial mon:stdio -hda $< -nographic
TERMINAL        :=gnome-terminal
debug: $(UCOREIMG)
	$(V)$(TERMINAL) -e "$(QEMU) -S -s -d in_asm -D $(BINDIR)/q.log -parallel stdio -hda $< -serial null"
	$(V)sleep 2
	$(V)$(TERMINAL) -e "gdb -q -tui -x tools/gdbinit"
	
debug-nox: $(UCOREIMG)
	$(V)$(QEMU) -S -s -serial mon:stdio -hda $< -nographic &
	$(V)sleep 2
	$(V)$(TERMINAL) -e "gdb -q -x tools/gdbinit"

.PHONY: grade touch

GRADE_GDB_IN	:= .gdb.in
GRADE_QEMU_OUT	:= .qemu.out
HANDIN			:= proj$(PROJ)-handin.tar.gz

TOUCH_FILES		:= kern/trap/trap.c

MAKEOPTS		:= --quiet --no-print-directory

grade:
	$(V)$(MAKE) $(MAKEOPTS) clean
	$(V)$(SH) tools/grade.sh

touch:
	$(V)$(foreach f,$(TOUCH_FILES),$(TOUCH) $(f))

print-%:
	@echo $($(shell echo $(patsubst print-%,%,$@) | $(TR) [a-z] [A-Z]))

.PHONY: clean dist-clean handin packall tags
clean:
	$(V)$(RM) $(GRADE_GDB_IN) $(GRADE_QEMU_OUT) cscope* tags
	-$(RM) -r $(OBJDIR) $(BINDIR)

dist-clean: clean
	-$(RM) $(HANDIN)

handin: packall
	@echo Please visit http://learn.tsinghua.edu.cn and upload $(HANDIN). Thanks!

packall: clean
	@$(RM) -f $(HANDIN)
	@tar -czf $(HANDIN) `find . -type f -o -type d | grep -v '^\.*$$' | grep -vF '$(HANDIN)'`

tags:
	@echo TAGS ALL
	$(V)rm -f cscope.files cscope.in.out cscope.out cscope.po.out tags
	$(V)find . -type f -name "*.[chS]" >cscope.files
	$(V)cscope -bq 
	$(V)ctags -L cscope.files
