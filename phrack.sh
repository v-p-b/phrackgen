#!/usr/bin/env bash

set -e

FIRST=1
LAST=71

pushd .
cd localcontent

# Download all issue archives
for i in $(seq $FIRST $LAST); do 
    curl -O https://archives.phrack.org/tgz/phrack"$i".tar.gz; 
done

# Download all TOC's
for i in $(seq $FIRST $LAST); do 
    curl  https://phrack.org/issues/$i/1 > toc-"$i"; 
done

#Extract all issues
for i in $(seq $FIRST $LAST);do 
    mkdir -p "$i"; 
    tar -xzvf phrack"$i".tar.gz -C "$i"
done

popd

# Run the script
perl phrack.pl
