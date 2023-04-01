{ lib
, fetchFromGitHub
, python3Packages
, srcs
, versions
, meson
, ninja
, pkg-config
, python3
, which
, substituteAll
, callPackage
, ... }:

python3Packages.buildPythonApplication {
  pname = "frida-tools";
  src = srcs.frida-tools;
  version = versions.frida-tools;
  format = "other";
  preConfigure = ''
    patchShebangs --host agents
    sed -i "s%/usr/bin/env python3%$(which python3)%g" agents/*.py
  '';
  patches = [
    (let
      fs = (callPackage ./fs-agent { }).package;
      tracer = (callPackage ./tracer-agent { }).package;
    in substituteAll {
      src = ./tools_deps.patch;
      node_modules_fs = "${fs}/lib/node_modules/fs-agent/node_modules";
      node_modules_tracer = "${tracer}/lib/node_modules/tracer-agent/node_modules";
    })
  ];
  propagatedBuildInputs = [ python3Packages.frida python3Packages.colorama python3Packages.prompt-toolkit python3Packages.pygments ];
  nativeBuildInputs = [ meson ninja pkg-config which python3 ];
  postInstall = ''
    # This is typically set by pipInstallHook/eggInstallHook,
    # so we have to do so manually when using meson
    export PYTHONPATH=$out/${python3.sitePackages}:$PYTHONPATH
  '';
}
