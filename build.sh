#!/bin/bash

# This is a script to build openzfs on unRAID
# A lof of the code is stolen from gfjardim
# https://gist.githubusercontent.com/gfjardim/c18d782c3e9aa30837ff/raw/224264b305a56f85f08112a4ca16e3d59d45d6be/build.sh
# 
# 
# There are alot of hard coded links in this file that can break anytime!
#
# For up to date builds you need to update the links to the sources
#


D="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")"

URLS="
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/gcc-4.8.2-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/gcc-g++-4.8.2-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/patches/packages/glibc-2.17-x86_64-11_slack14.1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/binutils-2.23.52.0.1-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/make-3.82-x86_64-4.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/a/cxxlibs-6.0.18-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/perl-5.18.1-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/a/patch-2.7-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/l/mpfr-3.1.2-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/ap/bc-1.06.95-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/patches/packages/linux-3.10.104/kernel-headers-3.10.104-x86-1_slack14.1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/l/libmpc-0.8.2-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/l/ncurses-5.9-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/a/cpio-2.11-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/pkg-config-0.25-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/autoconf-2.69-noarch-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/automake-1.11.5-noarch-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/l/libmpc-0.8.2-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/ap/sqlite-3.7.17-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/pkg-config-0.25-x86_64-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/automake-1.11.5-noarch-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/autoconf-2.69-noarch-1.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/libtool-2.4.2-x86_64-2.txz
http://mirrors.slackware.com/slackware/slackware64-14.1/slackware64/d/m4-1.4.17-x86_64-1.txz
"

SOURCES="
https://sourceforge.net/projects/libuuid/files/libuuid-1.0.3.tar.gz
http://www.zlib.net/zlib-1.2.11.tar.gz
https://github.com/zfsonlinux/zfs/releases/download/zfs-0.6.5.9/spl-0.6.5.9.tar.gz
https://github.com/zfsonlinux/zfs/releases/download/zfs-0.6.5.9/zfs-0.6.5.9.tar.gz
"

ask() {
    # http://djm.me/ask
    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question
        echo ''
        read -p "$1 [$prompt] " REPLY

        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

## MODULES ##
do_install_modules(){
  [ ! -d "$D/packages" ] && mkdir $D/packages
  OLD_IFS="$IFS";IFS=$'\n';
  for url in $URLS; do
    PKGPATH=${D}/packages/$(basename $url)
    [ ! -e "${PKGPATH}" ] && wget --no-check-certificate $url -O "${PKGPATH}"

    #check if the package is empty
    if [ ! -s $PKGPATH ]; then
         echo "***********************************"
         echo "The package: " $PKGPATH " is broken"
         echo "You need to update the link for it "
         echo "in this script"
         echo "***********************************"
         exit 1
    fi

     [[ "${PKGPATH}" == *.txz ]] && installpkg "${PKGPATH}"
  done
  IFS="$OLD_IFS";
}

## KERNEL
do_extract_kernel(){
  [[ $(uname -r) =~ ([0-9.]*) ]] &&  KERNEL=${BASH_REMATCH[1]} || return 1
  LINK="https://www.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL}.tar.xz"

  rm -rf $D/kernel; mkdir $D/kernel

  [[ ! -f $D/linux-${KERNEL}.tar.xz ]] && wget $LINK -O $D/linux-${KERNEL}.tar.xz
  
  tar -C $D/kernel --strip-components=1 -Jxf $D/linux-${KERNEL}.tar.xz

  rsync -av /usr/src/linux-$(uname -r)/ $D/kernel/

  cd $D/kernel
  for p in $(find . -type f -iname "*.patch"); do
    patch -p 1 < $p
  done

  make oldconfig
}

do_install_kernel_modules () {
  cd $D/kernel
  make all modules_install install
}

do_copy_modules(){
  cd $D/kernel/
  make modules_install
  mkdir -p $D/bzroot
  find /lib/modules/$(uname -r) -type f -exec cp -r --parents '{}' $D/bzroot/ \;
}

do_install_packages() {
for package in $(find /boot/extra/ -iname "*.t*z"); do
  ROOT=$D/bzroot installpkg $package; 
done
}

do_compile() {

  unRAID_version=$(cat /etc/unraid-version | cut -d '"' -f2)

  #Get the sources
  [ ! -d "$D/sources" ] && mkdir $D/sources
  for source in $SOURCES; do
    PKGPATH=${D}/sources/$(basename $source)
    [ ! -e "${PKGPATH}" ] && wget --no-check-certificate $source -O "${PKGPATH}"
    [ ! -d ${PKGPATH%.*.*} ] && tar -xf $PKGPATH -C $D/sources/
  done

  #compile the sources
  cd $D/sources/libuu*/
  ./configure
  make
  make install

  cd $D/sources/zlib*/
  ./configure 
  make
  make install

  cd $D/sources/spl*/
  ./configure --prefix=/usr
  make
  make install DESTDIR=$(pwd)/PACKAGE
  cd $(pwd)/PACKAGE
  makepkg -l y -c n $D/spl-$unRAID_version.tgz
  installpkg $D/spl-$unRAID_version.tgz
  #load module
  depmod
  modprobe spl

  cd $D/sources/zfs*/
  ./configure --prefix=/usr
  make
  make install DESTDIR=$(pwd)/PACKAGE
  cd $(pwd)/PACKAGE
  makepkg -l y -c n $D/zfs-$unRAID_version.tgz
  installpkg $D/zfs-$unRAID_version.tgz
  #load module
  depmod
  modprobe zfs
}


do_cleanup(){
  rm -rf $D/bzroot $D/kernel $D/packages $D/linux-*.tar.xz $D/sources
}

if ask "1) Do you want to clean directories?" N ; then do_cleanup; fi

if ask "2) Do you want to install build dependencies?" $([[ -f /usr/bin/make ]] && echo N||echo Y;) ; then do_install_modules; fi

if ask "3) Do you want to download and extract the Linux kernel?" $([[ -f $D/kernel/.config ]] && echo N||echo Y;) ;then do_extract_kernel;fi

if ask "3.1) Do you want to install Linux kernel modules?" N ;then do_install_kernel_modules; fi

if ask "4) Do you want to compile ZFS?" N ; then do_compile; fi
