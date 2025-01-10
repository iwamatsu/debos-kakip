#!/usr/bin/make -f 

USE_MEM := 4
USE_JOBS := 10
BOARD := kakip
DEB_ARCH ?= arm64
KERNEL_ARCH ?= arm64
SUITE ?= bookworm
IMG_TYPE ?= base
IMG_FORMAT ?= raw
CACHE_MODE ?= nocache

BASE_URL = "https://github.com/Kakip-ai/"

# U-Boot
UBOOT_VERSION ?= main
UBOOT_DOWNLOAD_URL ?= $(BASE_URL)/kakip_u-boot/archive/refs/heads/$(UBOOT_VERSION).zip
UBOOT_DEFCONFIG ?= kakip.config
UBOOT_DTB_NAME ?= kakip-es1
UBOOT_PATCHES ?= 0001-arm-dts-kakip-Fix-PHY-address-for-ethernet0.patch 
UBOOT_BIN = out/firmware/u-boot-$(UBOOT_VERSION)/u-boot.bin \
	  out/firmware/u-boot-$(UBOOT_VERSION)/bl31-kakip-es1.bin

# Linux kernel
LINUX_BASE_URL ?= "https://github.com/iwamatsu/linux/"
LINUX_BASE_VERSION ?= 5.10.145-cip17
LINUX_VERSION ?= ${LINUX_BASE_VERSION}-20241002
LINUX_TAG ?= kakip/5.10.145-cip17-20241002
LINUX_PATCHES ?= lock_drp.c.patch SPDX_License_Identifier.patch
LINUX_DEB_PKGVERSION ?= $(LINUX_VERSION)-1
LINUX_DEB_PKGNAME ?= linux-image-$(LINUX_BASE_VERSION)_$(LINUX_DEB_PKGVERSION)_$(DEB_ARCH).deb

LINUX_DOWNLOAD_URL ?= $(LINUX_BASE_URL)/archive/refs/tags/$(LINUX_TAG).tar.gz
LINUX_BIN := overlay/linux/opt/$(LINUX_DEB_PKGNAME)

all: build-fip build-linux build-image

build-image:
	@test -d $(BOARD) || mkdir $(BOARD) 
	@test -f overlay/bootloader/opt/header0.bin || \
		(echo 'no header0.bin file, please run scripts/extract_bibary.sh.'; exit 1)
	@test -f overlay/bootloader/opt/header1.bin || \
		(echo 'no header1.bin file, please run scripts/extract_bibary.sh.'; exit 1)
	@test -f overlay/bootloader/opt/bl2.bin || \
		(echo 'no bl2.bin file, please run scripts/extract_bibary.sh.' ;exit 1)
	@test -f overlay/bootloader/opt/fip.bin || \
		(echo 'no fit.bin file, please run make build-fip.'; exit 1)

	debos -c $(USE_JOBS) --memory $(USE_MEM)Gb \
		--artifactdir $(BOARD) \
		-t architecture:$(DEB_ARCH) \
		-t suite:$(SUITE) \
		-t image_type:$(IMG_TYPE) \
		-t image_format:$(IMG_FORMAT) \
		-t cache_mode:$(CACHE_MODE) \
		-t linux_base_version:$(LINUX_BASE_VERSION) \
		-t linux_packagename:$(LINUX_DEB_PKGNAME) \
		base.yaml

# Linux kernel
downloads/$(LINUX_VERSION).tar.gz:
	@test -f $@ || wget $(LINUX_DOWNLOAD_URL) -O $@
download-linux: downloads/$(LINUX_VERSION).tar.gz

build/linux-$(LINUX_VERSION):
	@test -d build/linux-$(LINUX_VERSION) || \
		mkdir build/linux-$(LINUX_VERSION) && \
		tar -zxf downloads/$(LINUX_VERSION).tar.gz --strip-components 1 -C build/linux-$(LINUX_VERSION)

expand-linux: download-linux build/linux-$(LINUX_VERSION)

build/linux-$(LINUX_VERSION)/patched-stamp:
ifneq (,$(LINUX_PATCHES))
	for p in $(LINUX_PATCHES) ; do \
		echo "Patch: $$p" ;\
		patch -d build/linux-$(LINUX_VERSION)/ -p1 < patches/linux/$$p ;\
	done
	touch build/linux-$(LINUX_VERSION)/patched-stamp
endif
patch-linux: expand-linux build/linux-$(LINUX_VERSION)/patched-stamp

build-linux: patch-linux
	rm -rf build/*.deb
	cp build/linux-$(LINUX_VERSION)/arch/arm64/configs/kakip.config \
		build/linux-$(LINUX_VERSION)/.config

	sed -i -e '/^CONFIG_LOCALVERSION/d' build/linux-$(LINUX_VERSION)/.config

	yes '' | make -C build/linux-$(LINUX_VERSION) ARCH=$(KERNEL_ARCH) olddefconfig
	yes '' | make -C build/linux-$(LINUX_VERSION) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=aarch64-linux-gnu- \
		KBUILD_IMAGE=arch/arm64/boot/Image \
		KDEB_PKGVERSION=$(LINUX_DEB_PKGVERSION) \
		bindeb-pkg -j${USE_JOBS}

	mkdir -p overlay/linux/opt
	cp build/*.deb overlay/linux/opt/.

$(LINUX_BIN): build-linux

# U-Boot
downloads/$(UBOOT_VERSION).zip:
	@test -f $@ || wget $(UBOOT_DOWNLOAD_URL) -O $@
download-uboot: downloads/$(UBOOT_VERSION).zip

build/u-boot-$(UBOOT_VERSION):
	@test -d build/u-boot-$(UBOOT_VERSION) || \
		unzip downloads/$(UBOOT_VERSION).zip -d build && \
		mv build/kakip_u-boot-main build/u-boot-$(UBOOT_VERSION)
	
expand-uboot: download-uboot build/u-boot-$(UBOOT_VERSION)

build/u-boot-$(UBOOT_VERSION)/patched-stamp:
ifneq (,$(UBOOT_PATCHES))
	for p in $(UBOOT_PATCHES) ; do \
		echo "Patch: $$p" ;\
		patch -d build/u-boot-$(UBOOT_VERSION)/ -p1 < patches/u-boot/$$p ;\
	done
	touch build/u-boot-$(UBOOT_VERSION)/patched-stamp
endif
patch-uboot: expand-uboot build/u-boot-$(UBOOT_VERSION)/patched-stamp

build-uboot: patch-uboot
	cp build/u-boot-$(UBOOT_VERSION)/kakip.config build/u-boot-$(UBOOT_VERSION)/.config

	make CROSS_COMPILE=aarch64-linux-gnu- olddefconfig \
       		-C build/u-boot-$(UBOOT_VERSION) \
		-j$(USE_JOBS)
	make CROSS_COMPILE=aarch64-linux-gnu- \
		DEVICE_TREE=$(UBOOT_DTB_NAME) \
		all \
       		-C build/u-boot-$(UBOOT_VERSION) \
		-j$(USE_JOBS)

	mkdir -p out/firmware/u-boot-$(UBOOT_VERSION)

	cp build/u-boot-$(UBOOT_VERSION)/u-boot.bin \
		out/firmware/u-boot-$(UBOOT_VERSION)/.
	cp build/u-boot-$(UBOOT_VERSION)/bl31-kakip-es1.bin \
		out/firmware/u-boot-$(UBOOT_VERSION)/.

$(UBOOT_BIN): build-uboot

# FIP
FIP_BIN = overlay/bootloader/opt/fip.bin
build-fip: $(UBOOT_BIN)
	@mkdir -p overlay/bootloader/opt
	@test -f $(FIP_BIN) || fiptool create --align 16 \
		--soc-fw out/firmware/u-boot-$(UBOOT_VERSION)/bl31-kakip-es1.bin \
		--nt-fw out/firmware/u-boot-$(UBOOT_VERSION)/u-boot.bin \
		$(FIP_BIN)

$(FIP_BIN): build-fip

clean:
	rm -rf build/*

cleanall: clean
	rm -rf downloads/*
	rm -rf out/firmware
	rm -rf overlay/bootloader
	rm -rf $(BOARD)

.PHONY: build-image clean cleanall
