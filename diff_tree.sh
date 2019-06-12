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
            dest=$(readlink -f "$(dirname "$1")")
            TVHEADLESS=1 ida -Llog -B -A "-OBinExportAutoAction:BinExportBinary" "-OBinExportModule:$dest/" "-S$HOME/.idapro/mybinexport.idc" "$1"
        fi
    fi
}

if [ $# -lt 3 ]; then
    echo "Usage: $0 storage_path old new"
    exit 1
fi

store=$1
old=$2
new=$3

if [ ! -f "$store/difflist" ] ; then
    (rsync --links -rcn --out-format="%n" "$old" "$new" && rsync --links -rcn --out-format="%n" "$new" "$old") | sort | uniq > "$store/difflist"
    cat "$store/difflist" | sed "s;^;$old;" | xargs file | grep ELF | cut -d':' -f 1 | sed "s;^$old;;" > "$store/diff_elf"
    cat "$store/difflist" | sed "s;^;$old;" | xargs file | grep -v ELF | cut -d':' -f 1 | sed "s;^$old;;" > "$store/diff_not_elf"
fi
cat "$store/diff_elf" | while read -r elf ; do
    tmp=$(mktemp)
    ${BINUTILS_PREFIX}objcopy -j .text -O binary "$old/$elf" "$tmp"
    md5_1=$(md5sum "$tmp" |cut -d' ' -f1)
    ${BINUTILS_PREFIX}objcopy -j .text -O binary "$new/$elf" "$tmp"
    md5_2=$(md5sum "$tmp" |cut -d' ' -f1)
    if [ "$md5_1" == "$md5_2" ]; then
        #echo -e "$elf : ${GREEN}SAME${NC} .text"
        true
    else
        echo -e "$elf : ${RED}DIFF${NC} .text"
        make_idb "$old/$elf"
        make_idb "$new/$elf"
        filename=$(basename "$old/$elf")
        bindiff --primary="$old/${elf%.*}.BinExport" --secondary="$new/${elf%.*}.BinExport" | tee "$store/${filename}_bindiff.txt"
    fi
    # diff -u <(hd "$old/$elf") <(hd "$new/$elf") |diffstat
done

cat "$store/diff_not_elf" | while read -r file ; do
    filename=$(basename "$old/$file")
    diff -u "$old/$file" "$new/$file" | tee "$store/${filename}.diff"
done
