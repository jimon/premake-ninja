# premake-ninja

[Premake](https://github.com/premake/premake-core) module to support [Ninja](https://github.com/martine/ninja), because it's awesome.

### Implementation

For each project - configuration pair we create separate .ninja file. For solution we create build.ninja file which imports other .ninja files with subninja command.

Build.ninja file sets phony targets for configuration names so you can build them from command line. And default target is the first configuration name in your project (usually default).

### Tested on ![ubuntu-badge](https://github.com/jimon/premake-ninja/workflows/ubuntu/badge.svg) ![windows-badge](https://github.com/jimon/premake-ninja/workflows/windows/badge.svg) ![macos-badge](https://github.com/jimon/premake-ninja/workflows/macos/badge.svg)

### Extra Tests

Part of integration tests of several generators in https://github.com/Jarod42/premake-sample-projects ![Premake5 ubuntu ninja badge](https://github.com/Jarod42/premake-sample-projects/workflows/premake5-ubuntu-ninja/badge.svg)![Premake5 window ninja badge](https://github.com/Jarod42/premake-sample-projects/workflows/premake5-windows-ninja/badge.svg)

### TODO

- Resources are not supported
- Makefile not supported
- Bundles of any sort are not supported
- Clear methods are not supported
- C# not supported
- D not supported
- ...
