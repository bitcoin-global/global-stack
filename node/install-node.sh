#!/bin/sh

###############################################################################
#
#                             install-node.sh
#
# This is the install script for Bitcoin full node based on Bitcoin Global.
#
# This script attempts to make your node automatically reachable by other nodes
# in the network. This is done by using uPnP to open port 8222 on your router
# to accept incoming connections to port 8222 and route the connections to your
# node running inside your local network.
#
# For security reason, wallet functionality is not enabled by default.
#
# Supported OS: Linux, Mac OS X, BSD, Windows (Windows Subsystem for Linux)
# Supported platforms: x86, x86_64, ARM
#
# Bitcoin Global will be installed using binaries provided by bitcoin-global.io.
#
# If the binaries for your system are not available, the installer will attempt
# to build and install Bitcoin Global from source.
#
# All files will be installed into $HOME/bitcoin-global directory. Layout of this
# directory after the installation is shown below:
#
# Binaries:
#   $HOME/bin/
#
# Configuration file:
#   $HOME/.bitglobal/bitglob.conf
#
# Blockchain data files:
#   $HOME/bitcoin-global/
#
###############################################################################

REPO="bitcoin-global/bitcoin-global"
REPO_URL="https://github.com/$REPO.git"

# See https://github.com/bitcoin-global/bitcoin-global/tags for latest version.
VERSION=0.19.1
RELEASE=$VERSION

TARGET_DIR=$HOME/bin
DATA_DIR=$HOME/bitcoin-global
PORT=8222

BUILD=0
UNINSTALL=0

BLUE='\033[94m'
GREEN='\033[32;1m'
YELLOW='\033[33;1m'
RED='\033[91;1m'
RESET='\033[0m'

ARCH=$(uname -m)
SYSTEM=$(uname -s)
MAKE="make"
if [ "$SYSTEM" = "FreeBSD" ]; then
    MAKE="gmake"
fi
SUDO=""

usage() {
    cat <<EOF

This is the install script for Bitcoin full node based on Bitcoin Global.

Usage: $0 [-h] [-v <version>] [-t <target_directory>] [-p <port>] [-b] [-u]

-h
    Print usage.

-v <version>
    Version of Bitcoin Global to install.
    Default: $VERSION

-r <release>
    Release of Bitcoin Global to install.
    Default: $VERSION

-t <target_directory>
    Target directory for source files and binaries.
    Default: $HOME/bin

-d <data_dir>
    Data directory for blockchain.
    Default: $HOME/bitcoin-global

-p <port>
    Bitcoin Global listening port.
    Default: $PORT

-b
    Build and install Bitcoin Global from source.
    Default: $BUILD

-u
    Uninstall Bitcoin Global.

EOF
}

print_info() {
    printf "$BLUE$1$RESET\n"
}

print_success() {
    printf "$GREEN$1$RESET\n"
    sleep 1
}

print_warning() {
    printf "$YELLOW$1$RESET\n"
}

print_error() {
    printf "$RED$1$RESET\n"
    sleep 1
}

print_start() {
    print_info "Start date: $(date)"
}

print_end() {
    print_info "\nEnd date: $(date)"
}

print_readme() {
    cat <<EOF

# README

To stop Bitcoin Global:

    cd $TARGET_DIR/bin && ./stop.sh

To start Bitcoin Global again:

    cd $TARGET_DIR/bin && ./start.sh

To use bitglob-cli program:

    cd $TARGET_DIR/bin && ./bitglob-cli -conf=$TARGET_DIR/.bitglobal/bitglob.conf getnetworkinfo

To view Bitcoin Global log file:

    tail -f $TARGET_DIR/.bitglobal/debug.log

To uninstall Bitcoin Global:

    ./install-full-node.sh -u

EOF
}

program_exists() {
    type "$1" > /dev/null 2>&1
    return $?
}

create_target_dir() {
    if [ ! -d "$TARGET_DIR" ]; then
        print_info "\nCreating target directory: $TARGET_DIR"
        mkdir -p $TARGET_DIR
    fi
}

create_data_dir() {
    if [ ! -d "$DATA_DIR" ]; then
        print_info "\nCreating target directory: $DATA_DIR"
        mkdir -p $DATA_DIR
    fi
}


init_system_install() {
    if [ $(id -u) -ne 0 ]; then
        if program_exists "sudo"; then
            SUDO="sudo"
            print_info "\nInstalling required system packages.."
        else
            print_error "\nsudo program is required to install system packages. Please install sudo as root and rerun this script as normal user."
            exit 1
        fi
    fi
}

install_miniupnpc() {
    print_info "Installing miniupnpc from source.."
    rm -rf miniupnpc-2.0 miniupnpc-2.0.tar.gz &&
        wget -q http://miniupnp.free.fr/files/download.php?file=miniupnpc-2.0.tar.gz -O miniupnpc-2.0.tar.gz && \
        tar xzf miniupnpc-2.0.tar.gz && \
        cd miniupnpc-2.0 && \
        $SUDO $MAKE install > build.out 2>&1 && \
        cd .. && \
        rm -rf miniupnpc-2.0 miniupnpc-2.0.tar.gz
}

install_debian_build_dependencies() {
    $SUDO apt-get update
    $SUDO apt-get install -y \
        automake \
        autotools-dev \
        build-essential \
        curl \
        git \
        libboost-all-dev \
        libevent-dev \
        libminiupnpc-dev \
        libssl-dev \
        libtool \
        pkg-config
}

install_fedora_build_dependencies() {
    $SUDO dnf install -y \
        automake \
        boost-devel \
        curl \
        gcc-c++ \
        git \
        libevent-devel \
        libtool \
        miniupnpc-devel \
        openssl-devel
}

install_centos_build_dependencies() {
    $SUDO yum install -y \
        automake \
        boost-devel \
        curl \
        gcc-c++ \
        git \
        libevent-devel \
        libtool \
        openssl-devel
    install_miniupnpc
    echo '/usr/lib' | $SUDO tee /etc/ld.so.conf.d/miniupnpc-x86.conf > /dev/null && $SUDO ldconfig
}

install_archlinux_build_dependencies() {
    $SUDO pacman -S --noconfirm \
        automake \
        boost \
        curl \
        git \
        libevent \
        libtool \
        miniupnpc \
        openssl
}

install_alpine_build_dependencies() {
    $SUDO apk update
    $SUDO apk add \
        autoconf \
        automake \
        boost-dev \
        build-base \
        curl \
        git \
        libevent-dev \
        libtool \
        openssl-dev
    install_miniupnpc
}

install_mac_build_dependencies() {
    if ! program_exists "gcc"; then
        print_info "When the popup appears, click 'Install' to install the XCode Command Line Tools."
        xcode-select --install
    fi

    if ! program_exists "brew"; then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi

    brew install \
        --c++11 \
        automake \
        boost \
        libevent \
        libtool \
        miniupnpc \
        openssl \
        pkg-config
}

install_freebsd_build_dependencies() {
    $SUDO pkg install -y \
        autoconf \
        automake \
        boost-libs \
        curl \
        git \
        gmake \
        libevent2 \
        libtool \
        openssl \
        pkgconf \
        wget
    install_miniupnpc
}

install_build_dependencies() {
    init_system_install
    case "$SYSTEM" in
        Linux)
            if program_exists "apt-get"; then
                install_debian_build_dependencies
            elif program_exists "dnf"; then
                install_fedora_build_dependencies
            elif program_exists "yum"; then
                install_centos_build_dependencies
            elif program_exists "pacman"; then
                install_archlinux_build_dependencies
            elif program_exists "apk"; then
                install_alpine_build_dependencies
            else
                print_error "\nSorry, your system is not supported by this installer."
                exit 1
            fi
            ;;
        Darwin)
            install_mac_build_dependencies
            ;;
        FreeBSD)
            install_freebsd_build_dependencies
            ;;
        *)
            print_error "\nSorry, your system is not supported by this installer."
            exit 1
            ;;
    esac
}

build_bitcoin_global() {
    cd $TARGET_DIR

    if [ ! -d "$TARGET_DIR/bitcoin-global" ]; then
        print_info "\nDownloading Bitcoin Global source files.."
        git clone $REPO_URL
    fi

    # Tune gcc to use less memory on single board computers.
    cxxflags=""
    if [ "$SYSTEM" = "Linux" ]; then
        ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        if [ $ram_kb -lt 1500000 ]; then
            cxxflags="--param ggc-min-expand=1 --param ggc-min-heapsize=32768"
        fi
    fi

    print_info "\nBuilding Bitcoin Global $VERSION"
    print_info "Build output: $TARGET_DIR/bitcoin-global/build.out"
    print_info "This can take up to an hour or more..."
    rm -f build.out
    cd bitcoin-global &&
        git fetch > build.out 2>&1 &&
        git checkout "$VERSION" 1>> build.out 2>&1 &&
        git clean -f -d -x 1>> build.out 2>&1 &&
        ./autogen.sh 1>> build.out 2>&1 &&
        ./configure \
            CXXFLAGS="$cxxflags" \
            --without-gui \
            --with-miniupnpc \
            --disable-wallet \
            --disable-tests \
            --enable-upnp-default \
            1>> build.out 2>&1 &&
        $MAKE 1>> build.out 2>&1 &&
        $SUDO $MAKE install 1>> build.out 2>&1

    if [ ! -f "$TARGET_DIR/bitcoin-global/src/bitglobd" ]; then
        print_error "Build failed. See $TARGET_DIR/bitcoin-global/build.out"
        cat $TARGET_DIR/bitcoin-global/build.out
        exit 1
    fi

    sleep 1
}

private_gh_curl() {
    curl -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3.raw" \
         $@
}

gh_curl() {
    curl $@
}

get_bin_url() {
    case "$SYSTEM" in
        Linux)
            if program_exists "apk"; then
                echo ""
            elif [ "$ARCH" = "armv7l" ]; then
                file="bitcoin-global-$VERSION-arm-linux-gnueabihf.tar.gz"
            else
                file="bitcoin-global-$VERSION-$ARCH-linux-gnu.tar.gz"
            fi
            ;;
        Darwin)
            file="bitcoin-global-$VERSION-osx64.tar.gz"
            ;;
        FreeBSD)
            ;;
        *)
            ;;
    esac
    parser=".assets[] | select(.name==\"$file\") | .id"
    asset_id=$(gh_curl -s https://api.github.com/repos/$REPO/releases/tags/$RELEASE | jq "$parser")
    
    if [ -z "$asset_id" ]; then
        echo ""
    else
        echo "https://api.github.com/repos/$REPO/releases/assets/$asset_id"
    fi
}

download_bin() {
    print_info "\nDownloading Bitcoin Global binaries.."
    
    cd $TARGET_DIR
    wget -q --auth-no-challenge --header='Accept:application/octet-stream' $1 \
        -O bitcoin-global-$VERSION.tar.gz
    
    mkdir -p bitcoin-global-$VERSION
    tar xzf bitcoin-global-$VERSION.tar.gz -C bitcoin-global-$VERSION --strip-components=1
    rm -f bitcoin-global-$VERSION.tar.gz
}

install_bitcoin_global() {
    cd $TARGET_DIR

    print_info "\nInstalling Bitcoin Global $VERSION"

    if [ ! -d "$TARGET_DIR/bin" ]; then
        mkdir -p $TARGET_DIR/bin
    fi

    if [ ! -d "$TARGET_DIR/.bitglobal" ]; then
        mkdir -p $TARGET_DIR/.bitglobal
    fi

    if [ "$SYSTEM" = "Darwin" ]; then
        if [ ! -e "$HOME/Library/Application Support/Bitcoin" ]; then
            ln -s $TARGET_DIR/.bitglobal "$HOME/Library/Application Support/Bitcoin"
        fi
    else
        if [ ! -e "$HOME/.bitglobal" ]; then
            ln -s $TARGET_DIR/.bitglobal $HOME/.bitglobal
        fi
    fi

    if [ -f "$TARGET_DIR/bitcoin-global/src/bitglobd" ]; then
        # Install compiled binaries.
        cp "$TARGET_DIR/bitcoin-global/src/bitglobd" "$TARGET_DIR/bin/" &&
        cp "$TARGET_DIR/bitcoin-global/src/bitglob-cli" "$TARGET_DIR/bin/" &&
        print_success "Bitcoin Global $VERSION (compiled) installed successfully!"
    elif [ -f "$TARGET_DIR/bitcoin-global-$VERSION/bin/bitglobd" ]; then
        # Install downloaded binaries.
        cp "$TARGET_DIR/bitcoin-global-$VERSION/bin/bitglobd" "$TARGET_DIR/bin/" &&
        cp "$TARGET_DIR/bitcoin-global-$VERSION/bin/bitglob-cli" "$TARGET_DIR/bin/" &&
        rm -rf "$TARGET_DIR/bitcoin-global-$VERSION"
        print_success "Bitcoin Global $VERSION (binaries) installed successfully!"
    else
        print_error "Cannot find files to install."
        exit 1
    fi

    cat > $TARGET_DIR/.bitglobal/bitglob.conf <<EOF
listen=1
maxconnections=64
upnp=1
txindex=1

dbcache=64
par=2
checkblocks=24
checklevel=0

disablewallet=1
datadir=$DATA_DIR

rpcallowip=127.0.0.1
rpcuser=admin
rpcpassword=$(openssl rand -base64 32)

[main]
port=$PORT
bind=0.0.0.0
rpcbind=127.0.0.1
rpcport=18444

[test]
port=$PORT
bind=0.0.0.0
rpcbind=127.0.0.1
rpcport=18444

[regtest]
port=$PORT
bind=0.0.0.0
rpcbind=127.0.0.1
rpcport=18444

EOF
    chmod go-rw $TARGET_DIR/.bitglobal/bitglob.conf

    cat > $TARGET_DIR/bin/start.sh <<EOF
#!/bin/sh
if [ -f $TARGET_DIR/bin/bitglobd ]; then
    $TARGET_DIR/bin/bitglobd -conf=$TARGET_DIR/.bitglobal/bitglob.conf -datadir=$TARGET_DIR/.bitglobal -daemon
fi
EOF
    chmod ugo+x $TARGET_DIR/bin/start.sh

    cat > $TARGET_DIR/bin/stop.sh <<EOF
#!/bin/sh
if [ -f $TARGET_DIR/.bitglobal/bitglobd.pid ]; then
    kill \$(cat $TARGET_DIR/.bitglobal/bitglobd.pid)
fi
EOF
    chmod ugo+x $TARGET_DIR/bin/stop.sh
}

start_bitcoin_global() {
    if [ ! -f $TARGET_DIR/.bitglobal/bitglobd.pid ]; then
        print_info "\nStarting Bitcoin Global.."
        cd $TARGET_DIR/bin && ./start.sh

        timer=0
        until [ -f $TARGET_DIR/.bitglobal/bitglobd.pid ] || [ $timer -eq 5 ]; do
            timer=$((timer + 1))
            sleep $timer
        done

        if [ -f $TARGET_DIR/.bitglobal/bitglobd.pid ]; then
            print_success "Bitcoin Global is running!"
        else
            print_error "Failed to start Bitcoin Global."
            exit 1
        fi
    fi
}

stop_bitcoin_global() {
    if [ -f $TARGET_DIR/.bitglobal/bitglobd.pid ]; then
        print_info "\nStopping Bitcoin Global.."
        cd $TARGET_DIR/bin && ./stop.sh

        timer=0
        until [ ! -f $TARGET_DIR/.bitglobal/bitglobd.pid ] || [ $timer -eq 120 ]; do
            timer=$((timer + 1))
            sleep $timer
        done

        if [ ! -f $TARGET_DIR/.bitglobal/bitglobd.pid ]; then
            print_success "Bitcoin Global stopped."
        else
            print_error "Failed to stop Bitcoin Global."
            exit 1
        fi
    fi
}

check_bitcoin_global() {
    if [ -f $TARGET_DIR/.bitglobal/bitglobd.pid ]; then
        if [ -f $TARGET_DIR/bin/bitglob-cli ]; then
            print_info "\nChecking Bitcoin Global.."
            sleep 5
            $TARGET_DIR/bin/bitglob-cli -conf=$TARGET_DIR/.bitglobal/bitglob.conf -datadir=$TARGET_DIR/.bitglobal getnetworkinfo
        fi
    fi
}

uninstall_bitcoin_global() {
    stop_bitcoin_global

    if [ -d "$TARGET_DIR" ]; then
        print_info "\nUninstalling Bitcoin Global.."
        rm -rf $TARGET_DIR

        # Remove stale symlink.
        if [ "$SYSTEM" = "Darwin" ]; then
            if [ -L "$HOME/Library/Application Support/Bitcoin" ] && [ ! -d "$HOME/Library/Application Support/Bitcoin" ]; then
                rm "$HOME/Library/Application Support/Bitcoin"
            fi
        else
            if [ -L $HOME/.bitglobal ] && [ ! -d $HOME/.bitglobal ]; then
                rm $HOME/.bitglobal
            fi
        fi

        if [ ! -d "$TARGET_DIR" ]; then
            print_success "Bitcoin Global uninstalled successfully!"
        else
            print_error "Uninstallation failed. Is Bitcoin Global still running?"
            exit 1
        fi
    else
        print_error "Bitcoin Global not installed."
    fi
}

while getopts ":v:r:t:d:p:b:u" opt
do
    case "$opt" in
        v)
            VERSION=${OPTARG}
            ;;
        r)
            RELEASE=${OPTARG}
            ;;
        t)
            TARGET_DIR=${OPTARG}
            ;;
        d)
            DATA_DIR=${OPTARG}
            ;;
        p)
            PORT=${OPTARG}
            ;;
        b)
            BUILD=0
            ;;
        u)
            UNINSTALL=1
            ;;
        h)
            usage
            exit 0
            ;;
        ?)
            usage >& 2
            exit 1
            ;;
    esac
done

WELCOME_TEXT=$(cat <<EOF

Welcome!

You are about to install a Bitcoin full node based on Bitcoin Global $VERSION.

All files will be installed under $TARGET_DIR directory.

Your node will be configured to accept incoming connections from other nodes in
the Bitcoin network by using uPnP feature on your router.

For security reason, wallet functionality is not enabled by default.

After the installation, it may take several hours for your node to download a
full copy of the blockchain.

If you wish to uninstall Bitcoin Global later, you can download this script and
run "sh install-full-node.sh -u".

EOF
)

print_start

if [ $UNINSTALL -eq 1 ]; then
    echo
    read -p "WARNING: This will stop Bitcoin Global and uninstall it from your system. Uninstall? (y/n) " answer
    if [ "$answer" = "y" ]; then
        uninstall_bitcoin_global
    fi
else
    echo "$WELCOME_TEXT"
    
    # Should build or download?
    if [ "$BUILD" -eq 0 ]; then
        bin_url=$(get_bin_url)
    else
        bin_url=""
    fi

    # Required presteps.
    stop_bitcoin_global
    uninstall_bitcoin_global
    create_target_dir
    create_data_dir

    # Build or download
    if [ "$bin_url" != "" ]; then
        download_bin "$bin_url"
    else
        install_build_dependencies && build_bitcoin_global
    fi

    # Download and install client.
    install_bitcoin_global

    print_readme > $TARGET_DIR/README.md
    cat $TARGET_DIR/README.md
    print_success "If this your first install, Bitcoin Global may take several hours to download a full copy of the blockchain."
    print_success "Installation completed! You may now launch Bitcoin Global from $TARGET_DIR/bin/"
    print_success "\nYou can also add to path running: export PATH=\"\${PATH}:$TARGET_DIR/bin/\""
fi

print_end
