#!/usr/bin/env bash
##############################################################################
# 1)Installing dependencies & asking user preferences
##############################################################################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi
IFS=$'\n\t'
USER_HOME=$(eval echo "~$SUDO_USER")
DIR="src/"
SCRIPT_PATH=$(realpath "$0")
echo $USER_HOME
echo "Script only installs the program, program will remain even without the script."
echo "Would you like to conserve script after installation? n (no) | otherkey (yes)"
read remove
remove=${remove,,}
set -euo pipefail
sudo apt install build-essential pkg-config python3-pyqt5 autoconf libtool libpcap-dev dbus-x11
##############################################################################
# 2) Start fresh
##############################################################################
sudo rm -rf /usr/local/include/ndpi
sudo rm -f  /usr/local/lib/libndpi.so*
sudo rm -f  /usr/local/lib/pkgconfig/libndpi*.pc
sudo ldconfig
cd "$USER_HOME"
if [ -d "$DIR" ]; then
    sudo rm -r "$DIR"
    echo "Directory removed: $DIR"
else
    echo "Directory does not exist: $DIR"
fi
##############################################################################
# 3) Build and install nDPI 4.6
##############################################################################
mkdir src
cd src/
rm -rf nDPI
git clone  --branch 4.6 https://github.com/ntop/nDPI.git
cd nDPI
./autogen.sh
./configure --prefix=/usr/local
make -j"$(nproc)"
sudo make install
sudo ldconfig
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
pkg-config --modversion libndpi         # 4.6
pkg-config --cflags libndpi             # -I/usr/local/include/ndpi
ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
sudo ln -sf /usr/local/lib/pkgconfig/libndpi.pc /usr/lib/$ARCH/pkgconfig/libndpi.pc
sudo ln -sf /usr/local/lib/pkgconfig/libndpi.pc /usr/lib/$ARCH/pkgconfig/ndpi.pc
##############################################################################
# 4) Build and Install PMACCT 1.7.9
##############################################################################
cd ..
git clone --depth 1 --branch 1.7.9 \
          https://github.com/pmacct/pmacct.git
cd pmacct
git submodule update --init --recursive       # pulls libcdada and other deps
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
make distclean || true
./autogen.sh
./configure --enable-ndpi NDPI_CFLAGS="-I/usr/local/include/ndpi" NDPI_LIBS="-L/usr/local/lib -lndpi"
make -j"$(nproc)"
sudo make install
##############################################################################
# 5)Download GUI
##############################################################################
cd ..
wget https://raw.githubusercontent.com/mr-goodgame/PMACCT_GUI/refs/heads/main/QT5_gui.py
##############################################################################
# 5) Verify / notes
##############################################################################
pmacctd -V
if [[ "$remove" == "n" ]]; then
echo "Removing: $SCRIPT_PATH"
sudo rm -- "$SCRIPT_PATH"
fi
chmod +x QT5_gui.py
echo "Remember to run the program as \"sudo ./QT5_gui.py\"" > README.txt
echo "You must have access to sudo in order to read files." >> README.txt
echo "You can download the script & gui at: https://github.com/mr-goodgame/PMACCT_GUI" >> README.txt
sudo ./QT5_gui.py
