# pony-pi
Raspberry Pi I/O support library - Only Raspberry Pi3 is tested. Earlier Pi versions don't have ARMv8-a, so needs to be different. RPi4 probably works, but not tested.

Pony Language doesn't support Raspberry Pi from the community directly,
but it is possible to compile Pony Language compiler to cross-compile to
ARM and with files and information here, you can cross-compile your
Pony applications for Raspberry Pi.
## Packages needed
You need to have a bunch of packages installed on your host (Linux) system. I 
am not totally sure exactly which packages are needed at the root, but these are
the one's that I have on my system that has "armhf" in the name. There might be others
needed, and I am sure that some of these are dependencies and not required to be installed
by `apt-get`

The cross compile stuff;
```bash
sudo apt-get libasan8-armhf-cross \
    libatomic1-armhf-cross \
    libc6-armhf-cross \
    libc6-dev-armhf-cross \
    libgcc-14-dev-armhf-cross \
    libgcc-s1-armhf-cross \
    libgomp1-armhf-cross \
    libstdc++-14-dev-armhf-cross \
    libstdc++6-armhf-cross \
    libubsan1-armhf-cross \
    linux-libc-dev-armhf-cross
```

And the Raspberry Pi runtime parts needs a different "system" installed in apt;

```bash
sudo dpkg --add-architecture armhf
```

and here are the packages that I have on my system for `armhf` arch. 

```bash
sudo apt-get gcc-14-base:armhf \
    libc6:armhf \
    libcrypt-dev:armhf \
    libcrypt1:armhf \
    libgcc-s1:armhf \
    libidn2-0:armhf \
    libssl-dev:armhf \
    libssl3t64:armhf \
    libunistring5:armhf \
    libzstd1:armhf \
    wiringpi:armhf \
    zlib1g:armhf
```


## Compile Pony Language compiler
First check out the source code from GitHub, into a new directory for this.
```bash
# Clone the Pony compiler
git clone https://github.com/ponylang/ponyc --recurse-submodules ponyc-arm
cd ponyc-arm
export PONYC_ROOT=`pwd`
```

We need to add a "toolchain cmake file".

```bash
mkdir toolchains
echo '
# This file is for cross-compiling to ARM hard-float ABI on Linux

# Set the target system name and processor
SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_PROCESSOR armv8-a)

# Specify the cross-compilers
# Ensure these paths are correct for your system
SET(CMAKE_C_COMPILER "/usr/bin/arm-linux-gnueabihf-gcc-14")
SET(CMAKE_CXX_COMPILER "/usr/bin/arm-linux-gnueabihf-g++-14")

# Set the root path for CMake to find libraries and headers for the target
SET(CMAKE_FIND_ROOT_PATH "/usr/arm-linux-gnueabihf")

# Tell CMake how to search for programs, libraries, and includes
# NEVER for programs means host tools are used (like make, ar, ranlib)
# ONLY for libraries/includes means only look within CMAKE_FIND_ROOT_PATH
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Explicitly set CMAKE_CROSSCOMPILING to true
SET(CMAKE_CROSSCOMPILING TRUE)

# **CRITICAL FIX:** Append --sysroot to the compiler flags.
# This forces the compiler to use the correct sysroot for its own searches,
# overriding its default of "/".
SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --sysroot=${CMAKE_FIND_ROOT_PATH}")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --sysroot=${CMAKE_FIND_ROOT_PATH}")
' >toolchains/armhf-toolchain.cmake
```

Then run the following 

```bash 
# Build the (partial) LLVM toolchain (might as well do RISC-V while we are at it
make libs build_flags=-j8 llvm_archs="X86;ARM;RISCV"

# Configure Ponyc compilation
make configure CMAKE_ARGS="-DCMAKE_TOOLCHAIN_FILE=toolchains/armhf-toolchain.cmake"

# Build the ponyc binary
make build build_flags=-j8

# Build the pony runtime library
make cross-libponyrt CC=arm-linux-gnueabihf-gcc-10 CXX=arm-linux-gnueabihf-g++-10 arch=armv8-a tune=cortex-a53 llc_arch=arm
```

## Put Pony compiler on PATH
I have my personal stuff in `/home/niclas/bin` so I needed to do

```bash
ln -s /home/niclas/dev/pony/ponyc-arm/build/release/ponyc /home/niclas/bin
```
but you can set it up the way you want it.


## How to compile your program
It is recommended to use `corral` for dependency management, so this is how your
compile will look like;

```bash
corral run -- \
    ponyc-arm \
    -Dwiringpi \
    -Dopenssl_3.0.x \
    --cpu=cortex-a53 \
    --triple="arm-unknown-linux-gnueabihf" \
    --link-arch=armv8-a \
    --linker=arm-linux-gnueabihf-gcc-14 \
    --path "$PONYC_ROOT/build/armv8-a/release/"
```
Note that `PONY_ROOT` needs to be set up in terminal, or simply replace it with a hardcode path.
