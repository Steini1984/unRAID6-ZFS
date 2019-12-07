#!/bin/bash

# This is a script to build the latest openzfs on unRAID
# A lot of the code was based on work from gfjardim:
# https://gist.githubusercontent.com/gfjardim/c18d782c3e9aa30837ff/raw/224264b305a56f85f08112a4ca16e3d59d45d6be/build.sh

#VARIABLES
zfs_version="$(curl -s https://zfsonlinux.org/  | grep -i releases/download | head -1 | cut -d ">" -f 2 | cut -d "<" -f 1 | cut -d "-" -f 2)"
D="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")"
[[ $(uname -r) =~ ([0-9.]*) ]] &&  KERNEL=${BASH_REMATCH[1]} || return 1

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

#variables for counter
count=0
total=33
pstr="[=======================================================================]"

#make a url - parameters: 1=folder 2=name 3=arch
build_url(){
  #build URL
  URLS+=$(echo $mirror/$1/$(curl -s $mirror/$1/ | grep $2-.*-$3-.*.txz |awk '{print $6}' | head -1 | cut -d "\"" -f 2))$'\n'
  count=$(( $count + 1 ))
  pd=$(( $count * 73 / $total ))
  printf "\r%3d.%1d%% %.${pd}s" $(( $count * 100 / $total )) $(( ($count * 1000 / $total) % 10 )) $pstr
}

get_urls(){
  mirror="https://mirrors.slackware.com/slackware/slackware64-current/slackware64"
  URLS=""
  build_url a gettext x86_64
  build_url l libmpc x86_64
  build_url d \"make x86_64
  build_url l dbus x86_64
  build_url d gcc x86_64
  build_url d gcc-g++ x86_64
  build_url d cmake x86_64
  build_url d pkg x86_64
  build_url d autoconf noarch
  build_url d automake noarch
  build_url d kernel x86
  build_url a cpio x86_64
  build_url d guile x86_64
  build_url l gc x86_64
  build_url d bison x86_64
  build_url d binutils x86_64
  build_url d perl x86_64
  build_url d libtool x86_64
  build_url d m4 x86_64
  build_url a aaa_elflibs x86_64
  build_url a patch x86_64
  build_url a attr x86_64
  build_url a util x86_64
  build_url ap sqlite x86_64
  build_url ap bc x86_64
  build_url l mpfr x86_64
  build_url l ncurses x86_64
  build_url l libunistring x86_64
  build_url l elfutils x86_64
  build_url n libtirpc x86_64
  build_url l glibc x86_64
  build_url d python3 x86_64
  build_url n openssl x86_64
}

## MODULES ##
do_install_modules(){
  echo ""
  echo "Fetching package urls......"
  echo ""
  printf "\r%3d.%1d%% %.${pd}s" $(( $count * 100 / $total )) $(( ($count * 1000 / $total) % 10 )) $pstr
  get_urls

  [ ! -d "$D/packages" ] && mkdir $D/packages
  OLD_IFS="$IFS";IFS=$'\n';
  for url in $URLS; do
    PKGPATH=${D}/packages/$(basename $url)
    [ ! -e "${PKGPATH}" ] && wget --no-check-certificate $url -O "${PKGPATH}"

     [[ "${PKGPATH}" == *.txz ]] && installpkg "${PKGPATH}"
  done
  IFS="$OLD_IFS";
}

## KERNEL
do_extract_kernel(){
  [[ $(uname -r) =~ ([0-9.]*) ]] &&  KERNEL=${BASH_REMATCH[1]} || return 1
  LINK="https://www.kernel.org/pub/linux/kernel/v$(uname -r | head -c 1).x/linux-${KERNEL}.tar.xz"

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
  rm -rf $D/bzroot $D/kernel $D/packages $D/linux-*.tar.xz $D/sources $D/zfs-*
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

if [ "$1" = "-a" ] || [ "$1" = "--auto" ]; then

  echo ""
  echo "Starting automatic build of ZFS version "$zfs_version" for unRAID-"$(cat /etc/unraid-version | cut -d '"' -f2)" running Kernel:" $(uname -r)
  do_cleanup
  do_install_modules
  do_extract_kernel
  do_install_kernel_modules
  do_compile

elif [ "$1" = "-h" ] ||  [ "$1" = "--help" ]; then
echo "Usage: ./build.sh [OPTION]"
echo "Script that gets all dependancies and build ZFS on unRAID 6+"
echo ""
echo "Optinal arguments"
echo "-a, --all                  automatic build of ZFS"
echo "-h, --help                 this page"




else
  if ask "1) Do you want to clean directories?" N ; then do_cleanup; fi
  if ask "2) Do you want to install build dependencies?" $([[ -f /usr/bin/make ]] && echo N||echo Y;) ; then do_install_modules; fi
  if ask "3) Do you want to download and extract the Linux kernel?" $([[ -f $D/kernel/.config ]] && echo N||echo Y;) ;then do_extract_kernel;fi
  if ask "3.1) Do you want to install Linux kernel modules?" N ;then do_install_kernel_modules; fi
  if ask "4) Do you want to compile ZFS ?" N ; then do_compile; fi
fi

if [ $zfs_version != $(curl -s https://raw.githubusercontent.com/Steini1984/unRAID6-ZFS/master/unRAID6-ZFS.plg | grep zfs_pkg  | head -1 | cut -d "-" -f 2)  ]; then
  echo ""
  echo "******************************"
  echo "  New ZFS version: " $zfs_version
  echo "******************************"
  echo ""
fi

##Return to original directory
cd $D
