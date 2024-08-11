{ lib
, stdenv
, srcs
, overrides
, versions
, meson
, pkg-config
, frida-gumjs
, python3
, gettext
, ninja
, bash
, makeWrapper
, substituteAll
, callPackage
, nodejs-18_x
, vala
, glib
, flex
, bison
, systemdLibs
, autoPatchelfHook
, enableStatic ? true

# vendored but works without vendoring
, json-glib
, ... }:

let 
  commonFlags = lib.optional enableStatic ["--default-library=static"];
  propagate = enableStatic;
  build = attrs@{ pname, mesonFlags ? [], nativeBuildInputs ? [], buildInputs ? [], propagatedBuildInputs ? [], forceMesonFlags ? false, ... }:
    overrides.${pname} or (stdenv.mkDerivation ({
      version = versions.${pname};
      src = srcs.${pname};
    } // (builtins.removeAttrs attrs ["forceMesonFlags"]) // {
      mesonFlags = if forceMesonFlags then mesonFlags else commonFlags ++ mesonFlags;
      nativeBuildInputs = [ meson ninja ] ++ nativeBuildInputs;
      hardeningDisable = [
        "bindnow"
        "format"
        "fortify"
        "fortify3"
        "pic"
        "relro"
        "stackprotector"
        "strictoverflow"
        "zerocallusedregs"
     ];
    } // (if propagate then { propagatedBuildInputs = buildInputs ++ propagatedBuildInputs; buildInputs = []; } else {})));
  frida-vala = vala.overrideAttrs (old: {
    outputs = [ "out" ];
    version = versions.vala;
    src = srcs.vala;
    nativeBuildInputs = [ meson ninja vala pkg-config flex bison autoPatchelfHook ];
    buildInputs = [ glib ]; # frida's glib doesn't work (for whatever reason)
    postPatch = old.postPatch + ''
      touch ChangeLog
      mkdir -p m4
    '';
    mesonFlags = commonFlags;
  });
  frida-usrsctp = build {
    pname = "usrsctp";
    mesonFlags = [
      "-Dsctp_inet=false"
      "-Dsctp_inet6=false"
      "-Dsctp_build_programs=false"
    ];
  };
  frida-libgee = build {
    pname = "libgee";
    nativeBuildInputs = [ pkg-config frida-vala ];
    mesonFlags = [
      "-Ddisable-internal-asserts=true"
      "-Ddisable-introspection=true"
    ];
    buildInputs = [ frida-gumjs.glib ];
  };
  frida-libnice = build {
    pname = "libnice";
    nativeBuildInputs = [ pkg-config glib ];
    mesonFlags = [
      "-Dgupnp=disabled"
      "-Dgstreamer=disabled"
      "-Dcrypto-library=openssl"
      "-Dexamples=disabled"
      "-Dtests=disabled"
      "-Dintrospection=disabled"
    ];
    buildInputs = [ frida-gumjs.glib frida-openssl ];
  };
  frida-openssl = build {
    pname = "openssl";
    mesonFlags = [
      "-Dcli=disabled"
      # "-Dasm=disabled"
    ];
  };
  gioopenssl = build {
    pname = "glib-networking";
    strictDeps = true;
    forceMesonFlags = true;
    mesonFlags = [
      # this must always be static
      "--default-library=static"
      "-Dgnutls=disabled"
      "-Dopenssl=enabled"
      "-Dlibproxy=disabled"
      "-Dgnome_proxy=disabled"
      "-Dtests=false"
    ];
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [
      frida-gumjs.glib
      frida-openssl
    ];
  };
  # fails to build dynamically
  frida-ngtcp2 = build {
    pname = "ngtcp2";
    nativeBuildInputs = [ python3 frida-openssl ];
  };
  frida-libusb = build {
    pname = "libusb";
    buildInputs = [ systemdLibs ];
    nativeBuildInputs = [ pkg-config ];
  };
  frida-lwip = build {
    pname = "lwip";
    mesonFlags = [
      "-Dipv4=disabled"
      "-Dipv6=enabled"
      "-Ddns=disabled"
      "-Darp=disabled"
      "-Dethernet=enabled"
      "-Dtcp_mss=1360"
      "-Dtcp_snd_buf=65535"
      "-Dtcp_wnd=65535"
    ];
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ frida-gumjs.glib ];
  };
  self = build {
    pname = "frida-core";
    preConfigure = ''
      patchShebangs --host src
      patchShebangs --host src/compiler
      patchShebangs --host src/api
      patchShebangs --host tools
      patchShebangs --host server
      patchShebangs --host portal
      patchShebangs --host inject
      sed -i "s%/usr/bin/env python3%$(command -v python3)%g" src/compiler/*.py tools/*.py src/api/*.py releng/frida_version.py
    '';
    patches = [
      (let agent = (callPackage ./frida-compiler-agent { }).package; in substituteAll {
        src = ./core_deps.patch;
        node_modules = "${agent}/lib/node_modules/frida-compiler-agent/node_modules";
      })
    ];
    mesonFlags = [
      # normally it's only enabled if the host can run target arch's binaries
      # but this is set for more determinism
      "-Dcompiler_snapshot=enabled"
      "-Dconnectivity=enabled"
      "-Dmapper=${if stdenv.targetPlatform.isDarwin then "enabled" else "disabled"}"
      "-Dcompiler_snapshot=enabled"
      "-Dtests=disabled"
    ];
    nativeBuildInputs = [ frida-vala pkg-config python3 nodejs-18_x bash ];
    postInstall = let
      getAllPropagatedBuildInputs = inputs:
        lib.flatten
          (map
            (x: if x?propagatedBuildInputs then getAllPropagatedBuildInputs x.propagatedBuildInputs ++ [x] else [x])
            inputs);
      allPropagatedBuildInputs = lib.unique (map builtins.toString (getAllPropagatedBuildInputs self.propagatedBuildInputs));
    in if !enableStatic then "" else ''
      pushd "$(mktemp -d)"
      ar_inputs=()
      ${builtins.concatStringsSep "\n" (map (dep:
      ''
      for file in $(find ${dep}/lib -type f -name "*.a"); do
        ar_inputs+=( "$file" )
      done
      '') allPropagatedBuildInputs)}
      for file in $(find $out/lib -type f -name "*.a"); do
        mv "$file" "$file.bak"
        echo "CREATE $file" > tmp.ar
        echo "ADDLIB $file.bak" >> tmp.ar
        for ar_input in "''${ar_inputs[@]}"; do
          echo "ADDLIB $ar_input" >> tmp.ar
        done
        echo SAVE >> tmp.ar
        echo END >> tmp.ar
        ar -M < tmp.ar
        rm "$file.bak"
      done
      popd
    '';
    dontStrip = true;
    passthru = {
      inherit (frida-gumjs) glib;
    };
    buildInputs = [ frida-gumjs.glib frida-libgee json-glib frida-gumjs.libsoup frida-gumjs frida-gumjs.capstone frida-gumjs.brotli gioopenssl frida-openssl frida-libnice frida-usrsctp frida-gumjs.nghttp2 frida-ngtcp2 frida-libusb frida-lwip ];
  };
in self
