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

#VARIABLES
zfs_version=0.8.1
D="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")"
[[ $(uname -r) =~ ([0-9.]*) ]] &&  KERNEL=${BASH_REMATCH[1]} || return 1

URLS="
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/libmpc-1.1.0-x86_64-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/make-4.2.1-x86_64-4.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/dbus-glib-0.110-x86_64-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/gcc-9.1.0-x86_64-6.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/gcc-g++-9.1.0-x86_64-6.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/cmake-3.14.5-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/pkg-config-0.29.2-x86_64-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/autoconf-2.69-noarch-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/automake-1.16.1-noarch-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/kernel-headers-4.19.55-x86-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/a/cpio-2.12-x86_64-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/guile-2.2.5-x86_64-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/gc-8.0.4-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/bison-3.4.1-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/binutils-2.32-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/perl-5.30.0-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/libtool-2.4.6-x86_64-11.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/m4-1.4.18-x86_64-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/a/aaa_elflibs-15.0-x86_64-8.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/a/patch-2.7.6-x86_64-3.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/a/attr-2.4.48-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/a/util-linux-2.34-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/ap/bc-1.07.1-x86_64-3.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/ap/sqlite-3.28.0-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/mpfr-4.0.2-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/ncurses-6.1_20190518-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/libunistring-0.9.10-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/elfutils-0.176-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/n/libtirpc-1.1.4-x86_64-1.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/l/glibc-2.29-x86_64-3.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/d/python3-3.7.3-x86_64-2.txz
https://mirrors.slackware.com/slackware/slackware64-current/slackware64/n/openssl-1.1.1c-x86_64-1.txz
"

SOURCES="
https://sourceforge.net/projects/libuuid/files/libuuid-1.0.3.tar.gz
http://www.zlib.net/zlib-1.2.11.tar.gz
https://github.com/zfsonlinux/zfs/releases/download/zfs-$zfs_version/zfs-$zfs_version.tar.gz
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

do_compile_kernel(){
  cd $D/kernel
  make -j $(cat /proc/cpuinfo | grep -m 1 -Po "cpu cores.*?\K\d")
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


  cd $D/sources/zfs*/
  ./configure --prefix=/usr
  make
  make install DESTDIR=$(pwd)/PACKAGE
  cd $(pwd)/PACKAGE
  makepkg -l y -c n $D/zfs-$zfs_version-unRAID-$unRAID_version.x86_64.tgz
  installpkg $D/zfs-$zfs_version-unRAID-$unRAID_version.x86_64.tgz
  #load module
  depmod
  modprobe zfs
  #Copy to destination
  md5sum $D/zfs-$zfs_version-unRAID-$unRAID_version.x86_64.tgz > $D/zfs-$zfs_version-unRAID-$unRAID_version.x86_64.tgz.md5

}

do_cleanup(){
  rm -rf $D/bzroot $D/kernel $D/packages $D/linux-*.tar.xz $D/sources
}

#Change to current directory
cd $D

##Unmount bzmodules and make rw
if mount | grep /lib/modules > /dev/null; 
then
      echo "Remounting modules"
      cp -r /lib/modules /tmp
      umount -l /lib/modules/
      rm -rf  /lib/modules
      mv -f  /tmp/modules /lib
fi


if ask "1) Do you want to clean directories?" N ; then do_cleanup; fi

if ask "2) Do you want to install build dependencies?" $([[ -f /usr/bin/make ]] && echo N||echo Y;) ; then do_install_modules; fi

if ask "3) Do you want to download and extract the Linux kernel?" $([[ -f $D/kernel/.config ]] && echo N||echo Y;) ;then do_extract_kernel;fi

if ask "3.1) Do you want to compile the Linux kernel?" N ;then do_compile_kernel; fi

if ask "3.2) Do you want to install Linux kernel modules?" N ;then do_install_kernel_modules; fi

if ask "4) Do you want to compile ZFS?" N ; then do_compile; fi

##Return to original directory
cd $D
