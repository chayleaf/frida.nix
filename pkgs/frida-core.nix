{ lib
, stdenv
, srcs
, overrides
, versions
, meson
, pkg-config
, frida-gumjs
, which
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
, enableStatic ? true
, ... }:

let 
  commonFlags = lib.optional enableStatic ["--default-library=static"];
  propagate = enableStatic;
  buildInputs = x: if propagate then { propagatedBuildInputs = x; buildInputs = x; } else { buildInputs = x; };
  build = attrs@{ pname, ... }: if overrides?${pname} then overrides.${pname} else stdenv.mkDerivation ({ version = versions.${pname}; src = srcs.${pname}; } // attrs);
  frida-vala = vala.overrideAttrs (old: {
    outputs = [ "out" ];
    version = versions.vala;
    src = srcs.vala;
    nativeBuildInputs = [ meson ninja vala pkg-config flex bison ];
    buildInputs = [ glib ]; # frida's glib doesn't work (for whatever reason)
    postPatch = old.postPatch + ''
      touch ChangeLog
      mkdir -p m4
    '';
    mesonFlags = commonFlags;
  });
  frida-usrsctp = build {
    pname = "usrsctp";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [ "-Dsctp_inet=false" "-Dsctp_inet6=false" "-Dsctp_build_programs=false" ];
  };
  frida-libgee = build ({
    pname = "libgee";
    env = {
      LD_LIBRARY_PATH = "${frida-vala}/lib/vala-0.58";
    };
    nativeBuildInputs = [ meson ninja pkg-config frida-vala which /*vala*/ ]; # why?
    mesonFlags = commonFlags ++ [ "-Ddisable-internal-asserts=true" "-Ddisable-introspection=true" ];
  } // (buildInputs [ frida-gumjs.glib ]));
  frida-libnice = build ({
    pname = "libnice";
    nativeBuildInputs = [ meson ninja pkg-config glib ];
    mesonFlags = commonFlags ++ [ "-Dgupnp=disabled" "-Dgstreamer=disabled" "-Dcrypto-library=openssl" "-Dexamples=disabled" "-Dtests=disabled" "-Dintrospection=disabled" ];
  } // (buildInputs [ frida-gumjs.glib frida-openssl ]));
  frida-openssl = build {
    pname = "openssl";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [ "-Dcli=disabled" "-Dasm=disabled" ];
  };
  gioopenssl = build ({
    pname = "glib-networking";
    strictDeps = true;
    mesonFlags = [
      # this must always be static
      "--default-library=static"
      "-Dopenssl=enabled" "-Dgnutls=disabled" "-Dlibproxy=disabled" "-Dgnome_proxy=disabled" "-Dtests=false"
    ];
    nativeBuildInputs = [ meson ninja pkg-config ];
  } // (buildInputs [
    frida-gumjs.glib
    frida-openssl
  ]));
  self = build ({
    env = {
      LD_LIBRARY_PATH = "${frida-vala}/lib/vala-0.58";
    };
    pname = "frida-core";
    preConfigure = ''
      patchShebangs --host src
      patchShebangs --host src/compiler
      patchShebangs --host src/api
      patchShebangs --host tools
      patchShebangs --host server
      patchShebangs --host portal
      patchShebangs --host inject
      sed -i "s%/usr/bin/env python3%$(which python3)%g" src/compiler/*.py tools/*.py src/api/*.py
    '';
    patches = [
      (let agent = (callPackage ./frida-compiler-agent { }).package; in substituteAll {
        src = ./core_deps.patch;
        node_modules = "${agent}/lib/node_modules/frida-compiler-agent/node_modules";
        index_d_ts = builtins.fetchurl {
          url = "https://raw.githubusercontent.com/DefinitelyTyped/DefinitelyTyped/86804f3dc1469f041fcec0f945e66eefbd94baeb/types/frida-gum/index.d.ts";
          sha256 = "1janmrpy2zbrlqwv605viajs621pdwifyizqc78z4mzgv19kqhm0";
        };
      })
    ];
    mesonFlags = commonFlags ++ [
      # normally it's only enabled if the host can run target arch's binaries
      # but this is set for more determinism
      "-Dcompiler_snapshot=enabled"
      "-Dconnectivity=enabled"
      "-Dmapper=${if stdenv.targetPlatform.isDarwin then "enabled" else "disabled"}"
      "-Dcompiler_snapshot=enabled"
      "-Dtests=false"
    ];
    nativeBuildInputs = [ meson frida-vala pkg-config ninja which python3 nodejs-18_x bash ];
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
      inherit (frida-gumjs) glib json-glib;
    };
  } // (buildInputs [ frida-gumjs.glib frida-libgee frida-gumjs.json-glib frida-gumjs.libsoup frida-gumjs frida-gumjs.capstone frida-gumjs.brotli gioopenssl frida-openssl frida-libnice frida-usrsctp ]));
in self