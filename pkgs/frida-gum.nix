{ lib
, stdenv
, fetchurl
, substituteAll
, srcs
, overrides
, versions
, meson
, pkg-config
, ninja
, gettext
, enableJsBindings ? false
, enableCppBindings ? false
, enableObjcBridge ? false
, enableSwiftBridge ? false
, enableJavaBridge ? false
, python3
, nodejs_18
, callPackage

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
    overrides.${pname} or (stdenv.mkDerivation ({
      version = versions.${pname};
      src = srcs.${pname};
    } // attrs // {
      mesonFlags = commonFlags ++ mesonFlags;
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
    } // (if propagate && !forceBuildInputs then { propagatedBuildInputs = buildInputs ++ propagatedBuildInputs; buildInputs = []; } else {})));
  frida-glib = build {
    pname = "glib";
    preConfigure = ''
      patchShebangs --host tools
      sed -i "s%/usr/bin/env python3%$(command -v python3)%g" tools/*.py
      sed -i "s%.*Werror=unused-result.*%%g" meson.build
    '';
    nativeBuildInputs = [ pkg-config python3 gettext python3.pkgs.distutils ];
    mesonFlags = [
      # "-Dprintf=internal"
      "-Dcocoa=disabled"
      "-Dselinux=disabled"
      "-Dxattr=false"
      "-Dlibmount=disabled"
      "-Dtests=false"
      "--force-fallback-for=pcre"
      # "-Dnls=disabled"
      # "-Dglib_debug=disabled"
      # "-Dglib_assert=false"
      # "-Dglib_checks=false"
      # implicit options
      "-Diconv=libc" # might have to be external on darwin, don't have a mac to test
      "-Dlibelf=disabled"
    ];
    buildInputs = [ pcre2 frida-libffi zlib ];
  };
  frida-capstone = build {
    pname = "capstone";
    mesonFlags = [
      # "-Dprofile=full"
      "-Darchs=all"
      "-Duse_arch_registration=true"
      "-Dx86_att_disable=true"
      "-Dcli=disabled"
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
    # WHY?
    postUnpack = ''
      cp ${fetchurl {
        url = "https://raw.githubusercontent.com/frida/brotli/01d9e2922ca878965ebcd71ee8965d2a7aadb47a/meson.build";
        hash = "sha256-+Kaiyxqx5W/6PFoDVzhAJ3qPNOkThV4Q2zu3iLoG0+Q=";
      }} source/meson.build
    '';
  };
  frida-libsoup = build {
    pname = "libsoup";
    nativeBuildInputs = [ pkg-config python3 glib ];
    preConfigure = ''
      patchShebangs --host libsoup
      sed -i "s%/usr/bin/env python3%$(command -v python3)%g" libsoup/*.py
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
    nativeBuildInputs = [ python3 pkg-config ];
    preConfigure = ''
      patchShebangs --host scripts
      sed -i "s%/usr/bin/env python3%$(command -v python3)%g" scripts/*.py
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
      "-Dsnapshot_compression=disabled"
      "-Dpointer_compression=disabled"
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
  (if !dontCombineDeps || enableStatic then {
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
    sed -i "s%/usr/bin/env python3%$(command -v python3)%g" bindings/gumjs/*.py
    '' else ""}
  '';
  patches = lib.optionals enableJsBindings [
    (let runtime = (callPackage ./gumjs-runtime { }).package; in substituteAll {
      src = ./gum_deps.patch;
      gumjs_runtime = "${runtime}/lib/node_modules/gumjs-runtime";
    })
  ];
  # some binary from glib is required for whatever reason
  nativeBuildInputs = [ pkg-config glib ]
    ++ (lib.optionals enableJsBindings [ nodejs_18 python3 ]);
  passthru = {
    glib = frida-glib;
    capstone = frida-capstone;
    libsoup = frida-libsoup;
    brotli = frida-brotli;
    nghttp2 = frida-nghttp2;
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
