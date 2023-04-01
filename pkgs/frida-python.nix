{ lib
, fetchFromGitHub
, python3
, python3Packages
, srcs
, versions
, frida-core
, glib
, json-glib
, meson
, ninja
, pkg-config
, ... }:

python3Packages.buildPythonPackage {
  pname = "frida-python";
  src = srcs.frida-python;
  version = versions.frida-python;
  format = "other";
  nativeBuildInputs = [ meson ninja pkg-config ];
  mesonFlags = [ "--default-library=static" ];
  propagatedBuildInputs = [ python3Packages.typing-extensions ];
  buildInputs = [ frida-core frida-core.glib frida-core.json-glib ];
  postInstall = ''
    # This is typically set by pipInstallHook/eggInstallHook,
    # so we have to do so manually when using meson
    export PYTHONPATH=$out/${python3.sitePackages}:$PYTHONPATH
  '';
  pythonImportsCheck = [ "frida" ];
}
