#directory i should grab the source from
SRCDIR?=.
#the directory i should dump .o to
OBJDIR?=.
#top level directory, where .config is
TOPDIR?=.
#antares directory where all the scripts are
ANTARES_DIR?=$(TOPDIR)
#temporary dir for autogenerated stuff and other such shit
TMPDIR?=tmp
ARCH?=avr

#enforce bash, since other shells may break things
SHELL:=$(shell which bash)

define check_alt
which $(1) 2>/dev/null|| which $(2) 2>/dev/null || echo "fail"
endef

#Nasty OS X compat
STAT:=$(shell $(call check_alt,gstat,stat))
export STAT
ECHO:=$(shell $(call check_alt,gecho,echo))
export ECHO


ANTARES_DIR:=$(abspath $(ANTARES_DIR))
TMPDIR:=$(abspath $(TMPDIR))
TOPDIR:=$(abspath $(TOPDIR))

Kconfig:=$(SRCDIR)/kcnf
KVersion:=$(ANTARES_DIR)/version.kcnf


PHONY+=deftarget deploy build collectinfo clean
MAKEFLAGS:=-r

IMAGENAME=$(call unquote,$(CONFIG_IMAGE_DIR))/$(call unquote,$(CONFIG_IMAGE_FILENAME))

export SRCDIR ARCH TMPDIR IMAGENAME ARCH TOPDIR ANTARES_DIR TOOL_PREFIX

-include $(ANTARES_DIR)/.version
-include $(TOPDIR)/.config
-include $(TOPDIR)/include/config/auto.conf.cmd

.DEFAULT_GOAL := $(subst ",, $(CONFIG_MAKE_DEFTARGET))

include $(ANTARES_DIR)/make/host.mk
-include $(TMPDIR)/arch.mk
include $(ANTARES_DIR)/make/Makefile.lib

ifeq ($(PROJECT_SHIPS_ARCH),y)
-include $(TOPDIR)/src/arch/$(ARCH)/arch.mk
else
-include $(ANTARES_DIR)/src/arch/$(ARCH)/arch.mk
endif

ifeq ($(ANTARES_DIR),$(TOPDIR))
$(info $(tb_red))
$(info Please, do not run make in the antares directory)
$(info Use an out-of-tree project directory instead.)
$(info Have a look at the documentation on how to do that)
$(info $(col_rst))
$(error Cowardly refusing to go further)
endif



ifeq ($(CONFIG_TOOLCHAIN_GCC),y)
include $(ANTARES_DIR)/toolchains/gcc.mk
endif

ifeq ($(CONFIG_TOOLCHAIN_SDCC),y)
include $(ANTARES_DIR)/toolchains/sdcc.mk
endif


include $(ANTARES_DIR)/make/Makefile.collect

include $(ANTARES_DIR)/kconfig/kconfig.mk

# For compiler portability
export O

.SUFFIXES:

clean-y:="$(TMPDIR)" "$(TOPDIR)/build" "$(TOPDIR)/include/generated" "$(CONFIG_IMAGE_DIR)"

clean:  
	-$(SILENT_CLEAN) rm -Rf $(clean-y)

mrproper: clean
	-$(SILENT_MRPROPER) rm -Rf $(TOPDIR)/kconfig 
	$(Q)rm -f $(TOPDIR)/antares
	$(Q)rm -Rf $(TOPDIR)/include/config
	$(Q)rm -f $(TOPDIR)/include/arch

distclean: mrproper

build:  $(TOPDIR)/include/config/auto.conf $(BUILDGOALS)
	@echo > /dev/null

deploy: build
	$(Q)$(MAKE) -f $(ANTARES_DIR)/make/Makefile.deploy $(call unquote,$(CONFIG_DEPLOY_DEFTARGET))
	@echo "Your Antares firmware is now deployed"

real-deploy-%: build
	$(Q)$(MAKE) -f $(ANTARES_DIR)/make/Makefile.deploy $*
	@echo "Your Antares firmware is now deployed"
	$(Q)$(MAKE) -f $(ANTARES_DIR)/make/Makefile.deploy post

tags:
	$(SILENT_TAGS)etags `find $(TOPDIR) $(ANTARES_DIR)/ -name "*.c" -o -name "*.cpp" -o -name "*.h"|grep -v kconfig`


#Help needs a dedicated rule, so that it won't invoke build as it normally does
deploy-help:
	$(Q)$(MAKE) -f $(ANTARES_DIR)/make/Makefile.deploy help

#For deployment autocompletion
define deploy_dummy
deploy-$(1): real-deploy-$(1)
	@echo > /dev/null
PHONY+=deploy-$(1)
endef

-include $(TMPDIR)/deploy.mk
$(foreach d,$(DEPLOY), $(eval $(call deploy_dummy,$(d))))

.PHONY: $(PHONY)
