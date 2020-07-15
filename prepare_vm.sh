#!/bin/bash

install_mininet() {
    # Simply install mininet from the APT repos
    sudo apt-get update
    sudo apt-get install -y mininet
}

install_clang() {
    # Install clang 10
    sudo echo "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-10 main" >> /etc/apt/sources.list
    sudo echo "deb-src http://apt.llvm.org/bionic/ llvm-toolchain-bionic-10 main" >> /etc/apt/sources.list
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -
    sudo apt-get update
    sudo apt-get install -y clang-10 lldb-10 lld-10
}

install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y flex bison automake make autoconf pkg-config cmake libarchive-dev libgoogle-perftools-dev openssl libssl-dev git
    install_clang
}

install_iproute() {
    # Install an MPTCP-aware version of ip route
    git clone https://github.com/multipath-tcp/iproute-mptcp.git
    pushd iproute-mptcp
    # Note: you might need to change this if you install another version of MPTCP
    git checkout mptcp_v0.94
    make
    sudo make install
    popd
}

install_minitopo() {
    # First, install mininet
    install_mininet
    # Then fetch the repository
    git clone https://github.com/qdeconinck/minitopo.git
    pushd minitopo
    # Install the right version of minitopo
    git checkout minitopo2
    # Get the current dir, and insert an mprun helper command
    sudo echo "mprun() {" >> /etc/bash.bashrc
    sudo printf 'sudo python %s/runner.py "$@"\n' $(pwd) >> /etc/bash.bashrc
    sudo echo "}" >> /etc/bash.bashrc
}

install_pquic() {
    # We first need to have picotls
    git clone https://github.com/p-quic/picotls.git
    pushd picotls
    git submodule update --init
    cmake .
    make
    popd

    # Now we can prepare pquic
    git clone https://github.com/p-quic/pquic.git
    pushd pquic
    # Go on a special branch for an additional multipath plugin
    git checkout sigcomm20_mptp
    git submodule update --init
    cd ubpf/vm/
    make
    cd ../../picoquic/michelfralloc
    make
    cd ../..
    cmake .
    make
    # And also prepare plugins
    cd plugins
    CLANG=clang-10 LLC=llc-10 make
    cd ..
    popd
}

install_mptcp() {
    # Let us rely on APT repo. For more details to build this, go to
    # http://multipath-tcp.org/pmwiki.php/Users/DoItYourself
    sudo apt-key adv --keyserver hkps://keyserver.ubuntu.com:443 --recv-keys 379CE192D401AB61
    sudo sh -c "echo 'deb https://dl.bintray.com/multipath-tcp/mptcp_deb stable main' > /etc/apt/sources.list.d/mptcp.list"
    sudo apt-get update
    sudo apt-get install -y linux-mptcp-4.14
    # The following remove the previous running kernel, to make MPTCP the default one
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get remove linux-headers-4.15.0-109-generic linux-image-4.15.0-109-generic linux-modules-4.15.0-109-generic
}

install_dependencies
install_minitopo
install_iproute
install_pquic
install_mptcp