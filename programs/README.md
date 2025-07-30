# PIC Programs for PicOS

Steps for building a program for PicOS

1. Have the ARM GNU Toolchain available in your path: [link](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain)
2. Build a C file with the below example command for PIC

```sh
arm-none-eabi-gcc \
    -fPIC -pie -nostdlib \
    -ffreestanding \
    -mcpu=cortex-m0plus \
    -mthumb \
    ./main.c -o main.elf
```
