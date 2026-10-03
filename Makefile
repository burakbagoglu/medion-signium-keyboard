obj-m += medion_kbd.o

KVERSION ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVERSION)/build

all:
	$(MAKE) -C "$(KDIR)" M="$(CURDIR)" LLVM=1 modules

clean:
	$(MAKE) -C "$(KDIR)" M="$(CURDIR)" clean
