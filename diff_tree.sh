#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

BINUTILS_PREFIX="powerpc-linux-gnu-"

make_idb () {
    echo "Creating IDB for $1"    
    if [ ! -f "$1.idb" ]; then
        size=$(stat -c%s "$1")
        if [ $((size)) -gt $((10*1024*1024)) ]; then
            echo "file too big"
        else
            TVHEADLESS=1 ida -B -A "$1"
            export_bindiff.sh "$1.idb"
            dest=$(readlink -f "$(dirname "$1")")
            ida -Llog -A "-OBinExportAutoAction:BinExportBinary" "-OBinExportModule:$dest/" "-S$HOME/.idapro/mybinexport.idc" "$1"
        fi
    fi
}

(rsync --links -rcn --out-format="%n" "$1" "$2" && rsync --links -rcn --out-format="%n" "$2" "$1") | sort | uniq > difflist
cat difflist | sed "s;^;$1;" | xargs file | grep ELF | cut -d':' -f 1 | sed "s;^$1;;" > diff_elf
cat diff_elf | while read -r elf ; do 
    tmp=$(mktemp)
    ${BINUTILS_PREFIX}objcopy -j .text -O binary "$1/$elf" "$tmp"
    md5_1=$(md5sum "$tmp" |cut -d' ' -f1)
    ${BINUTILS_PREFIX}objcopy -j .text -O binary "$2/$elf" "$tmp"
    md5_2=$(md5sum "$tmp" |cut -d' ' -f1)
    if [ "$md5_1" == "$md5_2" ]; then
        #echo -e "$elf : ${GREEN}SAME${NC} .text"
        true
    else
        echo -e "$elf : ${RED}DIFF${NC} .text"
        make_idb "$1/$elf"
        make_idb "$2/$elf"
        bindiff --primary="$1/${elf%.*}.BinExport" --secondary="$2/${elf%.*}.BinExport"
    fi
    # diff -u <(hd "$1/$elf") <(hd "$2/$elf") |diffstat
done

