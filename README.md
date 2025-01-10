Debian image builder for [Kakip](https://www.kakip.ai/)

# Limitations

- Functions related to image processing such as OpenCV are not provided.

# How to build

## Required debian packages

- debos
- build-essential
- arm-trusted-firmware-tools 
- gcc-aarch64-linux-gnu 
- wget
- bmap-tools

## Build

1. Extract firmware from Kakip OS Image

```
$ scripts/extract_bibary.sh 
```

2. Build image

```
$ make
or
$ make build-fip ; make build-linux ; make build-image
```

If you want to build image with cache, run the following command:
```
# Creates a cache of common parts when creating an image.
$ make build-image CACHE_MODE=pack
$ ls
# Creaste an image with cache.
$ make build-image CACHE_MODE=unpack
```

## Writing image to micro SD

```
$ sudo sh -c "zcat kakip/debian-arm64-bookworm-base.img.gz > /dev/sdX"
```

or

```
$ sudo bmaptool copy --bmap kakip/debian-arm64-bookworm-base.bmap \
        kakip/debian-arm64-bookworm-base.img.gz /dev/sdX
```

## Boot

Run the following command in u-boot.

```
=> ext2load mmc 0 0xa0000000 /boot/boot.scr;source 0xa0000000
```

If you want to automatically boot, execute the following command and overwrite
the `bootcmd` variable.

```
=> setenv bootcmd "ext2load mmc 0 0xa0000000 /boot/boot.scr;source 0xa0000000"
=> saveenv
```

# License

```
Apache License, Version 2.0
Copyright 2024, 2025 Nobuhiro Iwamatsu <iwamatsu@nigauri.org>
```

Please see LICENSE.

# Licenses for files under the patches directory

```
GNU GPL v2.0
Copyright 2024, 2025 Nobuhiro Iwamatsu <iwamatsu@nigauri.org>
```

Please see COPYING.
