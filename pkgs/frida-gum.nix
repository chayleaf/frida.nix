{ lib
, stdenv
, srcs
, overrides
, versions
, meson
, pkg-config
, ninja
, enableJsBindings ? false
, enableCppBindings ? false
, enableObjcBridge ? false
, enableSwiftBridge ? false
, enableJavaBridge ? false
, python3
, which
, callPackage

, gettext
, glib # only for binaries

, enableStatic ? true
, dontCombineDeps ? false

# vendored but works without vendoring
, libelf
, lzma
, sqlite
, pcre2
, libpsl
, zlib
, json-glib
, libunwind
, ... }:

let
  commonFlags = lib.optionals enableStatic ["--default-library=static"];
  propagate = enableStatic;
  build = attrs@{ pname, mesonFlags ? [], nativeBuildInputs ? [], buildInputs ? [], propagatedBuildInputs ? [], forceBuildInputs ? false, ... }:
    if overrides?${pname} then overrides.${pname} else stdenv.mkDerivation ({
      version = versions.${pname};
      src = srcs.${pname};
    } // attrs // {
      mesonFlags = commonFlags ++ mesonFlags;
      nativeBuildInputs = [ meson ninja ] ++ nativeBuildInputs;
    } // (if propagate && !forceBuildInputs then { propagatedBuildInputs = buildInputs ++ propagatedBuildInputs; buildInputs = []; } else {}));
  frida-glib = build {
    pname = "glib";
    preConfigure = ''
      patchShebangs --host tools
      sed -i "s%/usr/bin/env python3%$(which python3)%g" tools/*.py
      sed -i "s%.*Werror=unused-result.*%%g" meson.build
    '';
    nativeBuildInputs = [ pkg-config which python3 ];
    mesonFlags = [
      "-Dprintf=internal"
      "-Dcocoa=disabled"
      "-Dselinux=disabled"
      "-Dxattr=false"
      "-Dlibmount=disabled"
      "-Dtests=false"
      "-Dnls=disabled"
      "-Dglib_debug=disabled"
      "-Dglib_assert=false"
      "-Dglib_checks=false"
      # implicit options
      "-Diconv=libc" # might have to be external on darwin, don't have a mac to test
      "-Dlibelf=disabled"
    ];
    buildInputs = [ pcre2 frida-libffi zlib ];
  };
  frida-capstone = build {
    pname = "capstone";
    mesonFlags = [
      "-Dprofile=full"
      "-Dcli=disabled"
      "-Darchs=${
        # code adapted from: https://github.com/frida/frida/blob/9cfa93e552870237b8a3b57a2315321af4c10a4a/releng/deps.mk#L484
        # all arches: https://github.com/frida/capstone/blob/22d317042ee4d251280d2960f5cf294433977db4/meson_options.txt#L15
        if stdenv.targetPlatform.isS390x then "sysz"
        else if stdenv.targetPlatform.isx86_64 then "x86"
        else if stdenv.targetPlatform.isx86 then "x86"
        else stdenv.targetPlatform.linuxArch
      }"
      "-Dx86_att_disable=true"
    ];
  };
  frida-libffi = build {
    pname = "libffi";
    mesonFlags = [ "-Dtests=false" "-Dexe_static_tramp=false" ];
  };
  frida-nghttp2 = build {
    pname = "nghttp2";
    nativeBuildInputs = [ python3 ];
  };
  frida-brotli = build {
    pname = "brotli";
    postUnpack = ''
      cp ${builtins.fetchurl {
        url = "https://raw.githubusercontent.com/frida/brotli/9f51b6b95599466f46678381492834cdbde018f7/meson.build";
        sha256 = "023d7w6dwrzdgksmhchb0qb3xhfzbhqh792siz2i3yab4im32c5r";
      }} source/meson.build
      ls -la source
    '';
  };
  frida-libsoup = build {
    pname = "libsoup";
    nativeBuildInputs = [ pkg-config which python3 glib ];
    preConfigure = ''
      patchShebangs --host libsoup
      sed -i "s%/usr/bin/env python3%$(which python3)%g" libsoup/*.py
    '';
    mesonFlags = [
      "-Dgssapi=disabled"
      "-Dntlm=disabled"
      "-Dbrotli=disabled"
      "-Dtls_check=false"
      "-Dintrospection=disabled"
      "-Dvapi=disabled"
      "-Ddocs=disabled"
      "-Dexamples=disabled"
      "-Dtests=false"
      "-Dsysprof=disabled"
      # implicit
      "-Dpkcs11_tests=disabled"
      "-Dfuzzing=disabled"
      "-Dautobahn=disabled"
    ];
    buildInputs = [ frida-glib frida-nghttp2 sqlite libpsl frida-brotli ];
  };
  frida-libdwarf = build {
    pname = "libdwarf";
    nativeBuildInputs = [ python3 which pkg-config ];
    preConfigure = ''
      patchShebangs --host scripts
      sed -i "s%/usr/bin/env python3%$(which python3)%g" scripts/*.py
    '';
    buildInputs = [ libelf ];
  };
  frida-quickjs = build {
    pname = "quickjs";
    mesonFlags = [ "-Dlibc=false" "-Dbignum=true" "-Datomics=disabled" "-Dstack_check=disabled" ];
  };
  frida-v8 = (callPackage ./v8.nix { }).overrideAttrs (old: {
    nativeBuildInputs = [ meson ninja pkg-config ];
    ninjaFlags = [ ];
    env.NIX_CFLAGS_COMPILE = "-O2";
    src = srcs.v8;
    mesonFlags = commonFlags ++ [
      "-Ddebug=false"
      "-Dembedder_string=-frida"
      "-Dpointer_compression=disabled"
      "-Dsnapshot_compression=disabled"
      "-Dshared_ro_heap=disabled"
      "-Dcppgc_caged_heap=disabled"
      # implicit flags
      "-Dadvanced_bigint_algorithms=disabled"
      "-Dcppgc_young_generation=disabled"
      "-Dcppgc_pointer_compression=disabled"
      "-Dpointer_compression_shared_cage=disabled"
      "-Dwasm=disabled"
    ] ++ (lib.optionals (stdenv.targetPlatform.isAarch64 || stdenv.targetPlatform.isAarch32) [
      # not sure this is the correct path to the option
      # also this is actually wrong as 'none-or-vfpv2', 'vfpv3-d16', 'vfpv3', 'neon' are the options
      "-Darm_fpu=${if stdenv.targetPlatform.gcc.fpu then "enabled" else "disabled"}"
    ]);
  });
  frida-tinycc = build {
    pname = "tinycc";
  };
  deps = [ frida-glib frida-capstone frida-libffi lzma libunwind libelf frida-libdwarf ]
    ++ (lib.optionals enableJsBindings [ frida-quickjs frida-v8 json-glib frida-tinycc sqlite frida-libsoup ]);
in build (
  (if dontCombineDeps && enableStatic then {
    propagatedBuildInputs = deps;
  } else {
    buildInputs = deps;
    forceBuildInputs = true;
  })
// {
  pname = "frida-gum";
  inherit enableJsBindings;
  preConfigure = ''
    patchShebangs --host bindings
    ${if enableJsBindings then ''
    sed -i "s%/usr/bin/env python3%$(which python3)%g" bindings/gumjs/*.py
    '' else ""}
  '';
  preBuild = let runtime = (callPackage ./gumjs-runtime {}).package; in ''
    mkdir -p bindings/gumjs
    cp ${runtime}/lib/node_modules/gumjs-runtime/*.json bindings/gumjs
    cp -r ${runtime}/lib/node_modules/gumjs-runtime/node_modules bindings/gumjs/node_modules
  '';
  # some binary from glib is required for whatever reason
  nativeBuildInputs = [ pkg-config glib ]
    ++ (lib.optionals enableJsBindings [ python3 which ]);
  passthru = {
    glib = frida-glib;
    capstone = frida-capstone;
    libsoup = frida-libsoup;
    brotli = frida-brotli;
  };
  mesonFlags = [
    "-Dgumjs=${if enableJsBindings then "enabled" else "disabled"}"
    "-Dallocator=internal"
    "-Djailbreak=disabled" # usually only enabled on macos,ios. dont have a mac so cant test
    "-Dgumpp=${if enableCppBindings then "enabled" else "disabled"}"
    "-Dquickjs=enabled"
    "-Dtests=disabled"
    "-Dfrida_objc_bridge=${if enableObjcBridge then "enabled" else "disabled"}"
    "-Dfrida_swift_bridge=${if enableSwiftBridge then "enabled" else "disabled"}"
    "-Dfrida_java_bridge=${if enableJavaBridge then "enabled" else "disabled"}"
  ];
  postInstall = let
    getAllPropagatedBuildInputs = inputs:
      lib.flatten
        (map
          (x: if x?propagatedBuildInputs then getAllPropagatedBuildInputs x.propagatedBuildInputs ++ [x] else [x])
          inputs);
    allPropagatedBuildInputs = lib.unique (map builtins.toString (getAllPropagatedBuildInputs deps));
  in if dontCombineDeps || !enableStatic then "" else ''
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
})
