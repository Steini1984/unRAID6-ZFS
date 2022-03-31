# Download ZFS package and extract it
cd ${DATA_DIR}
if [ ! -d ${DATA_DIR}/zfs-v${ZFS_V} ]; then
  mkdir ${DATA_DIR}/zfs-v${ZFS_V}
fi
if [ ! -f ${DATA_DIR}/zfs-v${ZFS_V}.tar.gz ]; then
  wget -q -nc --show-progress --progress=bar:force:noscroll -O ${DATA_DIR}/zfs-v${ZFS_V}.tar.gz https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_V}/zfs-${ZFS_V}.tar.gz
  if [ ! -s ${DATA_DIR}/zfs-v${ZFS_V}.tar.gz ]; then
    rm -rf ${DATA_DIR}/zfs-v${ZFS_V}.tar.gz
    wget -q -nc --show-progress --progress=bar:force:noscroll -O ${DATA_DIR}/zfs-v${ZFS_V}.tar.gz https://github.com/openzfs/zfs/archive/refs/tags/zfs-${ZFS_V}.tar.gz
  fi
else
  echo "---ZFS v${ZFS_V} found locally---"
fi
tar -C ${DATA_DIR}/zfs-v${ZFS_V} --strip-components=1 -xf ${DATA_DIR}/zfs-v${ZFS_V}.tar.gz

# Compile and install ZFS to temporary directory
cd ${DATA_DIR}/zfs-v${ZFS_V}
${DATA_DIR}/zfs-v${ZFS_V}/configure --prefix=/usr
make -j${CPU_COUNT}
DESTDIR=/zfs make install -j${CPU_COUNT}

# Create Slackware package
PLUGIN_NAME="zfs"
BASE_DIR="/zfs"
TMP_DIR="/tmp/${PLUGIN_NAME}_"$(echo $RANDOM)""
VERSION="$(date +'%Y.%m.%d')"

mkdir -p $TMP_DIR/$VERSION
cd $TMP_DIR/$VERSION
cp -R $BASE_DIR/* $TMP_DIR/$VERSION/
mkdir $TMP_DIR/$VERSION/install
tee $TMP_DIR/$VERSION/install/slack-desc <<EOF
       |-----handy-ruler------------------------------------------------------|
$PLUGIN_NAME: $PLUGIN_NAME-${ZFS_V//-}
$PLUGIN_NAME:
$PLUGIN_NAME:
$PLUGIN_NAME: Custom $PLUGIN_NAME-${ZFS_V//-} package for Unraid Kernel v${UNAME%%-*} by Steini1984
$PLUGIN_NAME:
EOF
${DATA_DIR}/bzroot-extracted-$UNAME/sbin/makepkg -l n -c n $TMP_DIR/$PLUGIN_NAME-${ZFS_V//-}-$UNAME-1.tgz
md5sum $TMP_DIR/$PLUGIN_NAME-${ZFS_V//-}-$UNAME-1.tgz | awk '{print $1}' > $TMP_DIR/$PLUGIN_NAME-${ZFS_V//-}-$UNAME-1.tgz.md5
