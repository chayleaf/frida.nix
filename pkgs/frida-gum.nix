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
, ... }:

let
  commonFlags = lib.optionals enableStatic ["--default-library=static"];
  propagate = enableStatic;
  dontCombineDeps' = dontCombineDeps || (!enableStatic);
  buildInputs = x: if propagate then { propagatedBuildInputs = x; buildInputs = x; } else { buildInputs = x; };
  build = attrs@{ pname, ... }: if overrides?${pname} then overrides.${pname} else stdenv.mkDerivation ({ version = versions.${pname}; src = srcs.${pname}; } // attrs);
  frida-elfutils = build ({
    pname = "elfutils";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags;
  } // (buildInputs [ frida-zlib ]));
  frida-xz = build {
    pname = "xz";
    preConfigure = ''
      sed -i "s/st_mtimensec/st_mtim.tv_nsec/g" src/xz/file_io.c
      sed -i "s/st_atimensec/st_atim.tv_nsec/g" src/xz/file_io.c
    '';
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [
      "-Dunaligned_access=${if stdenv.targetPlatform.isx86_64 || stdenv.targetPlatform.isx86 || (stdenv.targetPlatform.isPower && !stdenv.targetPlatform.isLittleEndian) then "enabled" else "disabled"}"
    
      "-Dcli=disabled" # seemingly this flag is unused, but doing this for good measure anyway
    ];
  };
  frida-sqlite = build {
    pname = "sqlite";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags;
  };
  frida-pcre2 = build {
    pname = "pcre2";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [ "-Dgrep=false" "-Dtest=false" ];
  };
  # selinux
  # -Dregex=disabled
  frida-libpsl = build {
    pname = "libpsl";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [ "-Druntime=no" "-Dbuiltin=false" "-Dtests=false" ];
  };
  frida-zlib = build {
    pname = "zlib";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags;
  };
  frida-glib = build ({
    pname = "glib";
    preConfigure = ''
      patchShebangs --host tools
      sed -i "s%/usr/bin/env python3%$(which python3)%g" tools/*.py
      sed -i "s%.*Werror=unused-result.*%%g" meson.build
    '';
    nativeBuildInputs = [ meson ninja pkg-config which python3 ];
    mesonFlags = commonFlags ++ [
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
  } // (buildInputs [ frida-pcre2 frida-libffi frida-zlib ]));
  frida-capstone = build {
    pname = "capstone";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [
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
  frida-json-glib = build ({
    pname = "json-glib";
    nativeBuildInputs = [ meson ninja pkg-config /*gettext*/ glib ];
    mesonFlags = commonFlags ++ [ "-Dintrospection=disabled" "-Dgtk_doc=disabled" "-Dtests=false" "-Dnls=disabled" ];
  } // (buildInputs [ frida-glib ]));
  frida-libffi = build {
    pname = "libffi";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [ "-Dtests=false" "-Dexe_static_tramp=false" ];
  };
  frida-libunwind = build ({
    pname = "libunwind";
    nativeBuildInputs = [ meson ninja pkg-config ];
    mesonFlags = commonFlags ++ [
      "-Dgeneric_library=disabled" "-Dcoredump_library=disabled" "-Dptrace_library=disabled" "-Dsetjmp_library=disabled" "-Dmsabi_support=false" "-Dminidebuginfo=enabled" "-Dzlibdebuginfo=enabled"
      # implicit options
      "-Dunwind_debug=disabled"
      "-Dcxx_exceptions=disabled"
      "-Ddebug_frame=${if stdenv.targetPlatform.isAarch32 || stdenv.targetPlatform.isAarch64 then "enabled" else "disabled"}"
    ];
  } // (buildInputs [ frida-xz frida-zlib ]));
  frida-nghttp2 = build {
    pname = "nghttp2";
    nativeBuildInputs = [ meson ninja python3 ];
    mesonFlags = commonFlags;
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
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags;
  };
  frida-libsoup = build ({
    pname = "libsoup";
    nativeBuildInputs = [ meson ninja pkg-config which python3 glib ];
    preConfigure = ''
      patchShebangs --host libsoup
      sed -i "s%/usr/bin/env python3%$(which python3)%g" libsoup/*.py
    '';
    mesonFlags = commonFlags ++ [
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
  } // (buildInputs [ frida-glib frida-nghttp2 frida-sqlite frida-libpsl frida-brotli ]));
  frida-libdwarf = build ({
    pname = "libdwarf";
    nativeBuildInputs = [ meson ninja python3 which pkg-config ];
    preConfigure = ''
      patchShebangs --host scripts
      sed -i "s%/usr/bin/env python3%$(which python3)%g" scripts/*.py
    '';
    mesonFlags = commonFlags;
  } // (buildInputs [ frida-elfutils ]));
  frida-quickjs = build {
    pname = "quickjs";
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags ++ [ "-Dlibc=false" "-Dbignum=true" "-Datomics=disabled" "-Dstack_check=disabled" ];
  };
  frida-v8 = (callPackage ./v8.nix { }).overrideAttrs (old: {
    nativeBuildInputs = [ meson ninja pkg-config ];
    ninjaFlags = [ ];
    env.NIX_CFLAGS_COMPILE = "-O2";
    src = srcs.v8;
    mesonFlags = commonFlags ++ [
      "-Ddebug=false" "-Dembedder_string=-frida" "-Dpointer_compression=disabled" "-Dsnapshot_compression=disabled" "-Dshared_ro_heap=disabled" "-Dcppgc_caged_heap=disabled"
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
    nativeBuildInputs = [ meson ninja ];
    mesonFlags = commonFlags;
  };
  deps = [ frida-glib frida-capstone frida-libffi frida-xz frida-libunwind frida-elfutils frida-libdwarf ]
    ++ (lib.optionals enableJsBindings [ frida-quickjs frida-v8 frida-json-glib frida-tinycc frida-sqlite frida-libsoup ]);
in build (
  (if dontCombineDeps || propagate then {
    propagatedBuildInputs = deps;
  } else {
    buildInputs = deps;
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
  nativeBuildInputs = [ meson pkg-config ninja glib ]
    ++ (lib.optionals enableJsBindings [ python3 which ]);
  passthru = {
    glib = frida-glib;
    json-glib = frida-json-glib;
    capstone = frida-capstone;
    libsoup = frida-libsoup;
    brotli = frida-brotli;
  };
  mesonFlags = commonFlags ++ [
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
  in if dontCombineDeps' then "" else ''
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
