# possum

> A operating system built for Raspberry Pi Pico

## Requirement

- [Docker](https://www.docker.com/)
- [Make](https://www.gnu.org/software/make/manual/make.html) (or [just](https://just.systems/))
- ARM GNU Toolchain [link](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain)

## Building the project

```sh
# Clone the repository:
git clone https://github.com/PES-Innovation-Lab/possum
cd possum

# Update the submodules:
# Pulls the pico-sdk and the picosh tool for loading
# programs
git submodule update --init --recursive

```
Prepare a sample env file

```sh
export ARM_NONE_EABI_PATH="path-to-arm-gnu-toolchain/arm-none-eabi/include/"
export PICO_SDK_PATH="path-to-possum-project/pico-sdk/"

export PATH="path-to-arm-gnu-toolchain/bin/":$PATH
```

### Using docker
- build the image

```sh
make run

# optionally use just
just run
```

- Run the container with the `run-clean` recipe if you are cleaning the '.zig-cache' and 'cmake' builds

### Build on bare metal

```sh
zig build
```
