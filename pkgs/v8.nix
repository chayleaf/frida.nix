{ stdenv, lib, fetchgit, fetchFromGitHub
, gn, ninja, python3, glib, pkg-config, icu
, xcbuild, darwin
, fetchpatch
, llvmPackages
, symlinkJoin
}:

# Use update.sh to update all checksums.

let
  version = "10.9.42";
  v8Src = fetchgit {
    url = "https://chromium.googlesource.com/v8/v8";
    rev = version;
    sha256 = "1j4z1gzcgzhs6dzg1ww8iv0wm9msykf70jyl8f636nka3a0cj77b";
  };

  git_url = "https://chromium.googlesource.com";

  # This data is from the DEPS file in the root of a V8 checkout.
  deps = {
    "base/trace_event/common" = fetchgit {
      url    = "${git_url}/chromium/src/base/trace_event/common.git";
      rev    = "521ac34ebd795939c7e16b37d9d3ddb40e8ed556";
      sha256 = "1zqm9sc98rkr86mzd8mxzcqsqvsyw2ncjha8gv32rxhfzzfz29k4";
    };
    "build" = fetchgit {
      url    = "${git_url}/chromium/src/build.git";
      rev    = "8d71aabf07c0ac19c62e856c74eb03700a88a665";
      sha256 = "1rc2aqnhq7rbkmawclicrfa512fapjavdbjwb6wh81m64g8bd62l";
    };
    "third_party/googletest/src" = fetchgit {
      url    = "${git_url}/external/github.com/google/googletest.git";
      rev    = "af29db7ec28d6df1c7f0f745186884091e602e07";
      sha256 = "0f7g4v435xh830npqnczl851fac19hhmzqmvda2qs3fxrmq6712m";
    };
    "third_party/icu" = fetchgit {
      url    = "${git_url}/chromium/deps/icu.git";
      rev    = "da07448619763d1cde255b361324242646f5b268";
      sha256 = "0wqlxhiwcgswywr3mw6qhimg2jxzdlybn25bk4qmkzpmqp7xl94j";
    };
    "third_party/zlib" = fetchgit {
      url    = "${git_url}/chromium/src/third_party/zlib.git";
      rev    = "3cec05733f5d3d7049d2a4600053902a25d08cd2";
      sha256 = "0nva4cz15s38607amanply06isha1pdknfl98any1l9bj04ikid4";
    };
    "third_party/jinja2" = fetchgit {
      url    = "${git_url}/chromium/src/third_party/jinja2.git";
      rev    = "ee69aa00ee8536f61db6a451f3858745cf587de6";
      sha256 = "1fsnd5h0gisfp8bdsfd81kk5v4mkqf8z368c7qlm1qcwc4ri4x7a";
    };
    "third_party/markupsafe" = fetchgit {
      url    = "${git_url}/chromium/src/third_party/markupsafe.git";
      rev    = "1b882ef6372b58bfd55a3285f37ed801be9137cd";
      sha256 = "1jnjidbh03lhfaawimkjxbprmsgz4snr0jl06630dyd41zkdw5kr";
    };
  };

  # See `gn_version` in DEPS.
  gnSrc = fetchgit {
    url = "https://gn.googlesource.com/gn";
    rev = "57c352b2b03461c24b19c678c61d7aeacc6981f4";
    sha256 = "1y87r9nvfpbg8gi0lzxdn126r9887p300m1fs1jn4c3y9p4xyk22";
  };

  myGn = gn.overrideAttrs (oldAttrs: {
    version = "for-v8";
    src = gnSrc;
  });

in

stdenv.mkDerivation rec {
  pname = "v8";
  inherit version;

  doCheck = true;

  patches = [
    ./darwin.patch
  ];

  src = v8Src;

  postUnpack = ''
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (n: v: ''
        mkdir -p $sourceRoot/${n}
        cp -r ${v}/* $sourceRoot/${n}
      '') deps)}
    chmod u+w -R .
  '';

  postPatch = ''
    ${lib.optionalString stdenv.isAarch64 ''
      substituteInPlace build/toolchain/linux/BUILD.gn \
        --replace 'toolprefix = "aarch64-linux-gnu-"' 'toolprefix = ""'
    ''}
    ${lib.optionalString stdenv.isDarwin ''
      substituteInPlace build/config/compiler/compiler.gni \
        --replace 'strip_absolute_paths_from_debug_symbols = true' \
                  'strip_absolute_paths_from_debug_symbols = false'
      substituteInPlace build/config/compiler/BUILD.gn \
        --replace 'current_toolchain == host_toolchain || !use_xcode_clang' \
                  'false'
    ''}
    ${lib.optionalString (stdenv.isDarwin && stdenv.isx86_64) ''
      substituteInPlace build/config/compiler/BUILD.gn \
        --replace "-Wl,-fatal_warnings" ""
    ''}
    touch build/config/gclient_args.gni
    sed '1i#include <utility>' -i src/heap/cppgc/prefinalizer-handler.h # gcc12
  '';

  llvmCcAndBintools = symlinkJoin { name = "llvmCcAndBintools"; paths = [ stdenv.cc llvmPackages.llvm ]; };

  gnFlags = [
    "use_custom_libcxx=false"
    "is_clang=${lib.boolToString stdenv.cc.isClang}"
    "use_sysroot=false"
    # "use_system_icu=true"
    "clang_use_chrome_plugins=false"
    "is_component_build=false"
    "v8_use_external_startup_data=false"
    "v8_monolithic=true"
    "is_debug=true"
    "is_official_build=false"
    "treat_warnings_as_errors=false"
    "v8_enable_i18n_support=true"
    "use_gold=false"
    # ''custom_toolchain="//build/toolchain/linux/unbundle:default"''
    ''host_toolchain="//build/toolchain/linux/unbundle:default"''
    ''v8_snapshot_toolchain="//build/toolchain/linux/unbundle:default"''
  ] ++ lib.optional stdenv.cc.isClang ''clang_base_path="${llvmCcAndBintools}"''
  ++ lib.optional stdenv.isDarwin ''use_lld=false'';

  env.NIX_CFLAGS_COMPILE = "-O2 -std=c++17";
  FORCE_MAC_SDK_MIN = stdenv.targetPlatform.sdkVer or "10.12";

  nativeBuildInputs = [
    myGn
    ninja
    pkg-config
    python3
  ] ++ lib.optionals stdenv.isDarwin [
    xcbuild
    llvmPackages.llvm
    python3.pkgs.setuptools
  ];
  buildInputs = [ glib icu ];

  ninjaFlags = [ ":d8" "v8_monolith" ];

  enableParallelBuilding = true;

  /*installPhase = ''
    install -D d8 $out/bin/d8
    install -D -m644 obj/libv8_monolith.a $out/lib/libv8.a
    install -D -m644 icudtl.dat $out/share/v8/icudtl.dat
    ln -s libv8.a $out/lib/libv8_monolith.a
    cp -r ../../include $out

    mkdir -p $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/v8.pc << EOF
    Name: v8
    Description: V8 JavaScript Engine
    Version: ${version}
    Libs: -L$out/lib -lv8 -pthread
    Cflags: -I$out/include
    EOF
  '';*/

  meta = with lib; {
    homepage = "https://v8.dev/";
    description = "Google's open source JavaScript engine";
    maintainers = with maintainers; [ cstrahan proglodyte matthewbauer ];
    platforms = platforms.unix;
    license = licenses.bsd3;
  };
}
