# premake-ninja

[Premake](https://github.com/premake/premake-core) module to support [Ninja](https://github.com/martine/ninja), because it's awesome.

## Usage (little reminder)
1. Put these files in a "premake-ninja" subdirectory of [Premake search paths](https://premake.github.io/docs/Locating-Scripts/).<br>

2. Adapt your premake5.lua script, or better: create/adapt your [premake-system.lua](https://premake.github.io/docs/System-Scripts/)

```lua
require "premake-ninja/ninja"
```

3. Generate ninja files

```sh
premake5 ninja
```
On msys2 (mingw)
```sh
premake5 ninja --cc=gcc --shell=posix
```

4. Run ninja

For each project - configuration pair, we create separate .ninja file. For solution we create build.ninja file which imports other .ninja files with subninja command.

Build.ninja file sets phony targets for configuration names so you can build them from command line. And default target is the first configuration name in your project (usually default).

General from:
```sh
ninja $(YourProjectName)_$(ConfigName)
```
as example:
```sh
ninja myapp_Release
```

### Tested on ![ubuntu-badge](https://github.com/jimon/premake-ninja/actions/workflows/ubuntu.yml/badge.svg) ![windows-badge](https://github.com/jimon/premake-ninja/actions/workflows/windows.yml/badge.svg) ![macos-badge](https://github.com/jimon/premake-ninja/actions/workflows/macos.yml/badge.svg)

### Extra Tests

Part of integration tests of several generators in https://github.com/Jarod42/premake-sample-projects ![Premake5 ubuntu ninja badge](https://github.com/Jarod42/premake-sample-projects/actions/workflows/premake5-ubuntu-ninja.yml/badge.svg)![Premake5 window ninja badge](https://github.com/Jarod42/premake-sample-projects/actions/workflows/premake5-windows-ninja.yml/badge.svg)
