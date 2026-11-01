#!/bin/bash

build_bios() {
    rm -f bin/ipxe.iso

    make -e -j 8 bin/ipxe.iso BIOS_MODE=BIOS NO_WERROR=1 || exit 1

    if ! [ -e bin/ipxe.iso ]; then
        echo "Failed"
        exit 1
    fi

    rm -f ../../../INSTALL/ventoy/ipxe.krn
    xorriso -osirrox on -indev bin/ipxe.iso -extract /ipxe.krn ../../../INSTALL/ventoy/ipxe.krn >/dev/null || exit 1

    echo -e "\n===============SUCCESS===============\n"
}


build_bios

