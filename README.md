# pony-pi
Raspberry Pi I/O support library - Only Raspberry Pi3 is tested. Earlier Pi versions don't have ARMv8-a, so needs to be different. RPi4 probably works, but not tested.

Pony Language doesn't support Raspberry Pi from the community directly,
but it is possible to compile Pony Language compiler to cross-compile to
ARM and with files and information here, you can cross-compile your
Pony applications for Raspberry Pi.
## Packages needed
You need to have a bunch of packages installed on your host (Linux) system. I 
am not totally sure exactly which packages, but the following are likely;

```bash
sudo apt install g++-10-arm-linux-gnueabihf
sudo apt install gcc-10-arm-linux-gnueabi
sudo apt install gcc-arm-linux-gnueabihf
```

## Compile Pony Language compiler
First check out the source code from GitHub, into a new directory for this.
```bash
# Clone the Pony compiler
git clone https://github.com/ponylang/ponyc ponyc-arm
cd ponyc-arm

# Build the (partial) LLVM toolchain
make libs build_flags=-j8 llvm_archs="X86;ARM"

# Configure Ponyc compilation
make configure

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

## How to compile your program
Then to compile, you need to set up the `$CC` environment variable, and 
provide the right target information to the compiler.

```bash
export CC="/usr/bin/arm-linux-gnueabihf-gcc -mfloat-abi=hard -mfpu=fp-armv8 -lwiringPi"
cd <<YOURPROJECT>>
corral run -- ponyc -Dopenssl_1.1.x --cpu=cortex-a53 --triple="arm-unknown-linux-gnueabihf" --link-arch=armv8-a
```

## Different Compiler
At the moment, the compiler will not work for `x86` compilation, so need to keep the regular compiler separate.

