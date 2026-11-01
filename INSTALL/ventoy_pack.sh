#!/bin/sh

if [ "$VENTOY_CERT_PASS" = "YES" ]; then
    read -s -p "Enter cert key passphrase: " KEY_PASS
    echo

    if openssl pkey -in "$VENTOY_CERT_KEY" -passin pass:"$KEY_PASS" -out /dev/null > /dev/null 2>&1; then
        echo "Password check OK"
    else
        echo "Incorrect password"
        exit 1
    fi
fi

sign_efi() {
    efi=$1

    if [ ! -f "$efi" ]; then
        printf "### %-64s  non-exist\n" "$efi"
        return
    fi

    if [ -z "$VENTOY_CERT_KEY" -o -z "$VENTOY_CERT_PEM" ]; then
        printf "### %-64s  NO-CA\n" "$efi"
        return
    fi

    if echo $efi | grep -q '\.xz$'; then
        xzcat $efi > ${efi}.unxz
        mv ${efi}.unxz ${efi}
    fi

    rm -f "${efi}.signed"
    if [ "$VENTOY_CERT_PASS" = "YES" ]; then
        expect -f ./sign_with_pass.exp "$KEY_PASS" "$VENTOY_CERT_KEY" "$VENTOY_CERT_PEM" "${efi}" "${efi}.signed" >/dev/null 2>&1
    else
        sbsign --key "$VENTOY_CERT_KEY" --cert "$VENTOY_CERT_PEM" --output "${efi}.signed" "${efi}" >/dev/null 2>&1
    fi

    if [ -f "${efi}.signed" ]; then
        if echo $efi | grep -q '\.xz$'; then
            xz --check=crc32 "${efi}.signed"
            mv "${efi}.signed.xz" "$efi"
            rm -f "${efi}.signed"
        else
            mv "${efi}.signed" "$efi"
        fi
    else
        printf "### %-64s  failed\n" "$efi"
        exit 1
    fi

    printf "### %-64s  success\n" "$efi"
}

if [ "$1" = "CI" ]; then
    OPT='-dR'
else
    OPT='-a'
fi

dos2unix -q ./tool/ventoy_lib.sh
dos2unix -q ./tool/VentoyWorker.sh
dos2unix -q ./tool/VentoyGTK.glade
dos2unix -q ./tool/distro_gui_type.json

. ./tool/ventoy_lib.sh

GRUB_DIR=../GRUB2/INSTALL
LANG_DIR=../LANGUAGES

if ! [ -d $GRUB_DIR ]; then
    echo "$GRUB_DIR not exist"
    exit 1
fi


cd ../IMG
sh mkcpio.sh
sh mkloopex.sh
cd -

cd ../Unix
sh pack_unix.sh
cd -

curver=$(get_ventoy_version_from_cfg ./grub/grub.cfg)

tmpmnt=./ventoy-${curver}-mnt

rm -rf $tmpmnt
mkdir -p $tmpmnt

mkdir -p $tmpmnt/grub

# First copy grub.cfg file, to make it locate at front of the part2
cp $OPT ./grub/grub.cfg     $tmpmnt/grub/

ls -1 ./grub/ | grep -v 'grub\.cfg' | while read line; do
    cp $OPT ./grub/$line $tmpmnt/grub/
done

#tar help txt
cd $tmpmnt/grub/
tar czf help.tar.gz ./help/
rm -rf ./help
cd ../../

#tar menu txt & update menulang.cfg
cd $tmpmnt/grub/

vtlangtitle=$(grep VTLANG_LANGUAGE_NAME menu/zh_CN.json | awk -F\" '{print $4}')
echo "menuentry \"zh_CN  -  $vtlangtitle\" --class=menu_lang_item --class=debug_menu_lang --class=F5tool {" >> menulang.cfg
echo "    vt_load_menu_lang zh_CN"  >> menulang.cfg
echo "}"  >> menulang.cfg

ls -1 menu/ | grep -v 'zh_CN' | sort | while read vtlang; do
    vtlangname=${vtlang%.*}
    vtlangtitle=$(grep VTLANG_LANGUAGE_NAME menu/$vtlang | awk -F\" '{print $4}')
    echo "menuentry \"$vtlangname  -  $vtlangtitle\" --class=menu_lang_item --class=debug_menu_lang --class=F5tool {" >> menulang.cfg
    echo "    vt_load_menu_lang $vtlangname"  >> menulang.cfg
    echo "}"  >> menulang.cfg
done
echo "menuentry \"\$VTLANG_RETURN_PREVIOUS\" --class=vtoyret VTOY_RET {" >> menulang.cfg
echo "        echo \"Return ...\"" >> menulang.cfg
echo "}" >> menulang.cfg

tar czf menu.tar.gz ./menu/
rm -rf ./menu
cd ../../



cp $OPT ./ventoy   $tmpmnt/
cp $OPT ./EFI   $tmpmnt/
cp $OPT ./tool/ENROLL_THIS_KEY_IN_MOKMANAGER.cer $tmpmnt/


mkdir -p $tmpmnt/tool
# cp $OPT ./tool/i386/mount.exfat-fuse     $tmpmnt/tool/mount.exfat-fuse_i386
# cp $OPT ./tool/x86_64/mount.exfat-fuse   $tmpmnt/tool/mount.exfat-fuse_x86_64
# cp $OPT ./tool/aarch64/mount.exfat-fuse  $tmpmnt/tool/mount.exfat-fuse_aarch64
# to save space
dd status=none bs=1024 count=16  if=./tool/i386/vtoycli    of=$tmpmnt/tool/mount.exfat-fuse_i386
dd status=none bs=1024 count=16  if=./tool/x86_64/vtoycli  of=$tmpmnt/tool/mount.exfat-fuse_x86_64
dd status=none bs=1024 count=16  if=./tool/aarch64/vtoycli of=$tmpmnt/tool/mount.exfat-fuse_aarch64
cp -a ./tool/create_ventoy_iso_part_dm.sh  $tmpmnt/tool/

sign_efi $tmpmnt/EFI/BOOT/fbia32.efi
sign_efi $tmpmnt/EFI/BOOT/fbaa64.efi
sign_efi $tmpmnt/EFI/BOOT/grubx64_real.efi
sign_efi $tmpmnt/EFI/BOOT/grubia32_real.efi
sign_efi $tmpmnt/ventoy/iso9660_x64.efi
sign_efi $tmpmnt/ventoy/iso9660_ia32.efi
sign_efi $tmpmnt/ventoy/iso9660_aa64.efi
sign_efi $tmpmnt/ventoy/udf_x64.efi
sign_efi $tmpmnt/ventoy/udf_ia32.efi
sign_efi $tmpmnt/ventoy/udf_aa64.efi
sign_efi $tmpmnt/ventoy/ventoy_x64.efi
sign_efi $tmpmnt/ventoy/ventoy_ia32.efi
sign_efi $tmpmnt/ventoy/ventoy_aa64.efi
sign_efi $tmpmnt/ventoy/vtoyutil_x64.efi
sign_efi $tmpmnt/ventoy/vtoyutil_ia32.efi
sign_efi $tmpmnt/ventoy/vtoyutil_aa64.efi
sign_efi $tmpmnt/ventoy/wimboot.i386.efi.xz
sign_efi $tmpmnt/ventoy/wimboot.x86_64.xz

grub_sha256=$(sha256sum $tmpmnt/EFI/BOOT/grubx64_real.efi | awk '{print $1}')
magic_cnt=$(hexdump -C $tmpmnt/EFI/BOOT/fbx64.efi | grep '26 26 26 26 26 26 26 26' | wc -l)
if [ $magic_cnt -ne 1 ]; then
    echo "hash magic duplicate"
    exit 1
fi
magic_off_hex=$(hexdump -C $tmpmnt/EFI/BOOT/fbx64.efi | grep '26 26 26 26 26 26 26 26' | awk '{print $1}')
magic_off=$(printf '%u' "0x${magic_off_hex}")
echo_cmd=$(echo $grub_sha256 | sed 's/\(..\)/\\x\1/g')

echo Ventoy Grub hash $grub_sha256
echo -en "$echo_cmd" | dd bs=1 count=32 of=$tmpmnt/EFI/BOOT/fbx64.efi seek=$magic_off conv=notrunc status=none

sign_efi $tmpmnt/EFI/BOOT/fbx64.efi

cd $tmpmnt/../
tar -czvf ventoy-${curver}.tar.gz $tmpmnt
rm -rf $tmpmnt



rm -f log.txt
rm -f sha256.txt
sha256sum "ventoy-${curver}.tar.gz" > sha256.txt
