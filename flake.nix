{
  description = "Frida compiled for NixOS from source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux =
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
      lib = pkgs.lib;
      # see https://github.com/frida/releng/blob/main/deps.toml for latest commit hashes

      # to unvendor, add "override = pkgs.<package>"
      version = "16.4.8";
      deps = {
        frida-tools = {
          version = "12.5.0";
          src = {
            rev = "3fbc2fb80133dd65afcd076226f90542debefe80";
            hash = "";
          };
        };
        frida-python = {
          inherit version;
          src = {
            rev = "aab9c4e76f0ffec253ec67d0372adb19cf275d86";
            hash = "";
          };
        };
        frida-gum = {
          inherit version;
          src = {
            rev = "25efdc99b005fdb59a136c1d6b96b3cddfea33de";
            hash = "sha256-oWjM/VT5gWyYjWxRqVJhHesUBeubxedzOFh9f677/WQ=";
            fetchSubmodules = true;
          };
        };
        frida-core = {
          inherit version;
          src = {
            rev = "2ebec1addff5e0bc908a7f0a5979dd86452b05b8";
            hash = "sha256-c03rnbMPVpUIW0zayK2rByDO1yg4Zc4IToGx4edpbXg=";
            fetchSubmodules = true;
          };
        };
        glib = {
          src = {
            rev = "148f677c620b57893e3fcdb872d241b61870ef0d";
            hash = "sha256-ltrfLY/+7kTXtNBAxty8cObn8cH5Tuufqx5nARg+J1Q=";
            fetchSubmodules = true;
          };
          version = "2.75.0";
          # reason for vendoring: too many frida-specific features
          # override = pkgs.glib;
        };
        capstone = {
          src = {
            rev = "e98746112da0a40b2ccd0340db0d20cca5f97950";
            hash = "sha256-dUlfkRqPTGsqff62pCNbj8uhYYU4orrOofS00RIJMJ0=";
          };
          version = "5.0.1";
          # reason for vendoring: capstone 5 not in nixpkgs; it probably has frida-specific features too
          # override = pkgs.capstone;
        };
        libffi = {
          src = {
            rev = "10bcbcc6295e559b7c952b054e7669a912d3ce06";
            hash = "sha256-/J2ndCb4zpbihHd5XbrwtwqLKqO6fLBLCHWPkBbo5j0=";
          };
          version = "3.4.4";
          # reason for vendoring: it has frida-specific features
          # override = pkgs.libffi;
        };
        nghttp2 = {
          src = {
            rev = "ae13d24ea59c30e36ca53d1b22c4e664588d0445";
            hash = "sha256-HnSCBCfRHhEOsxfNP9IpMgm7iMu6o5YjT27nh+VAy6U=";
          };
          version = "1.51.0";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.nghttp2;
        };
        ngtcp2 = {
          src = {
            rev = "cc5cf523615b7fa7a9340234c7eec3c3645ae969";
            hash = "sha256-3n4f3dxC4lXNT/7UaIIYdncVcOmFMDUneRgp+p23PX4=";
          };
          version = "1.0.90";
          # override = pkgs.ngtcp2;
        };
        libusb = {
          src = {
            rev = "be4d8ec1012f35ff6ce9474ed8d7c3ec4182ac55";
            hash = "sha256-aFddYzLUZloi1x2R5/tY7wy7EGZ60pwM7lRc4PDvcKU=";
          };
          version = "1.0.27";
          # override = pkgs.libusb;
        };
        lwip = {
          src = {
            rev = "9f64c40cac2e77eddf6b3913961fdd056d307716";
            hash = "sha256-1dvZkF5r8YQexhT+pZdjxa6062HskyU0XVGANQXxxtk=";
          };
          version = "2.2.1";
          # override = pkgs.lwip;
        };
        brotli = {
          src = {
            rev = "01d9e2922ca878965ebcd71ee8965d2a7aadb47a";
            hash = "sha256-S0tz+MxacBAseHwDbjq3vorHHM0lmU/JW1enOBWq8eo=";
          };
          version = "1.0.9";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.brotli;
        };
        libsoup = {
          src = {
            rev = "80dc080951c9037aef51a40ffbe4508d3ce98d1b";
            hash = "sha256-7bVK9oSjhQn90DeibUVg50zu3wn+b1elcYxsv4PnlmY=";
          };
          version = "3.3.0";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.libsoup_3;
        };
        libdwarf = {
          src = {
            rev = "fce48507e895f7e808a1b50c31a44571ae30389b";
            hash = "sha256-P4i5DN8+54pZIzg12z49DKqzxfaPsUEpUTQlI42a2x8=";
          };
          version = "20201201";
          # reason for vendoring: this version is very old but has some security patches
          # override = pkgs.libdwarf;
        };
        quickjs = {
          src = {
            rev = "b3582307ed491e5efb5e54fe14d6bd5675857b51";
            hash = "sha256-Noi6k1xeF0sycM0Jc+5v1jko3/X7Yl5lC5C5CZJjM5Q=";
          };
          version = "2024-01-13-frida";
          # reason for vendoring: too many frida-specific features
          # override = pkgs.quickjs;
        };
        # dont forget to update v8's deps too
        v8 = {
          src = {
            rev = "9492bfc5ca8615be651b85336caafa8f3c730cd7";
            hash = "sha256-nfBfDOT9XVE7mnLW7Q8sOae4f8LNrem2fJIJMNF2pqM=";
          };
          version = "10.9.42";
          # reason for vendoring: not in nixpkgs
          # override = pkgs.v8;
        };
        tinycc = {
          src = {
            rev = "722c253d8dece3bc9a46b6f510c6682329d838b7";
            hash = "sha256-GrddxEW5aDfFbdQ3ca4huomIoK9HLyykTGyMDtcvtJY=";
          };
          version = "0.9.27-frida";
          # reason for vendoring: frida-specific features
          # override = pkgs.tinycc;
        };
        vala = {
          src = {
            rev = "2c7a02d29332dedfdf803ce21b0540bc8461a035";
            hash = "sha256-WX+3P6B0hfXAPK9z8trnUKqp2bQVplmEo+tl2Q+dPOo=";
          };
          version = "0.58.0-frida";
          # reason for vendoring: frida-specific features
          # override = pkgs.vala;
        };
        usrsctp = {
          src = {
            rev = "f459ae9d3700c06e59d709901e92c08e31c6e623";
            hash = "sha256-S5nHb54Kck/35KXLbqVmC/BBVvhfJ9gHalcMMmZFU74=";
          };
          version = "0.9.5.0";
          # reason for vendoring: frida-specific features
          # override = pkgs.usrsctp;
        };
        libgee = {
          src = {
            rev = "ad17ed847039469fcc2dc711ecfee2bbf7d2bf87";
            hash = "sha256-WjOzmXHTH3lj1mRygI5StO0JI0ZIHG65qofMNB1tQPA=";
          };
          version = "0.20.6";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.libgee;
        };
        libnice = {
          src = {
            rev = "e12567b0a16a0c2eb5dfe5e0782baba8496772ff";
            hash = "sha256-m9VHFwIu4pgh1gW0KBqEXNSnUpYHykkLGT01UEBlbEY=";
          };
          version = "0.1.19.1";
          # reason for vendoring: frida-specific features
          # override = pkgs.libnice;
        };
        openssl = {
          src = {
            rev = "ca4781aaf7910b623d3ae21c6a017e7e9ca6936c";
            hash = "sha256-FqgLzjxFLS044FmjG3M+LPQrQB6hYZjyZxFbQkpDkwY=";
          };
          version = "3.0.12";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.openssl;
        };
        glib-networking = {
          src = {
            rev = "fe4cad1b45e40f5aede081c6ed1e74c0ba2b89b4";
            hash = "sha256-EnzCL9TqAIsJ3gaQwEaB7ycJLcNty6ahZPiljeGFD2A=";
          };
          version = "2.74.0";
          # reason for vendoring: *has* to be linked statically, has frida-specific features, uses custom build config
          # override = pkgs.glib-networking;
        };
      };
      srcs = builtins.mapAttrs (k: v: pkgs.fetchFromGitHub ({ owner = "frida"; repo = k; } // v.src)) deps;
      versions = builtins.mapAttrs (k: v: v.version) deps;
      overrides = lib.filterAttrs (k: v: v != null) (builtins.mapAttrs (k: v: if v?override then v.override else null) deps);
    in rec {
      frida-python = pkgs.callPackage ./pkgs/frida-python.nix {
        inherit versions srcs;
        frida-core = frida-core-static;
      };
      python3Packages = lib.recurseIntoAttrs {
        frida = frida-python;
      };
      pythonWithFrida = pkgs.python3.withPackages (p: [ (frida-python.override {
        python3 = pkgs.python3;
        python3Packages = p;
      }) ]);
      frida-tools = pkgs.callPackage ./pkgs/frida-tools.nix {
        inherit versions srcs;
        python3Packages = pkgs.python3Packages // python3Packages;
      };
      frida-core-static = pkgs.callPackage ./pkgs/frida-core.nix {
        inherit srcs versions overrides;
        # has to be frida-gumjs-static
        # otherwise it segfaults with free(): invalid pointer
        # (presumably due to conflicting allocator impls)
        frida-gumjs = frida-gumjs-static.override {
          dontCombineDeps = true;
        };
        enableStatic = true;
      };
      # doesn't work (because .so files aren't being built for whatever reason)
      frida-core = frida-core-static.override {
        frida-gumjs = frida-gumjs;
        enableStatic = false;
      };
      frida-gum-static = pkgs.callPackage ./pkgs/frida-gum.nix {
        inherit srcs versions overrides;
        enableStatic = true;
      };
      frida-gum = frida-gum-static.override { enableStatic = false; };
      frida-gumjs-static = frida-gum-static.override { enableJsBindings = true; };
      frida-gumpp-static = frida-gum-static.override { enableCppBindings = true; };
      frida-gumjs = frida-gum.override { enableJsBindings = true; };
      frida-gumpp = frida-gum.override { enableCppBindings = true; };
      default = frida-tools;
    };
  };
}
