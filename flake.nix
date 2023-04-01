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
      # see https://github.com/frida/frida/blob/main/releng/deps.mk for latest commit hashes

      # to unvendor, add "override = pkgs.<package>"
      version = "16.0.11";
      deps = {
        frida-tools = rec {
          version = "12.1.1";
          src = {
            rev = version;
            sha256 = "sha256-oOLkWC+dQKGzK4LjT5CKKp6voyvg5ZOpZatr+RZsHJU=";
          };
        };
        frida-python = {
          inherit version;
          src = {
            rev = "1d35663c97730de6e1d8fa5ad97a166f3145b368";
            sha256 = "sha256-ElRU/UiuU61ZOB/ShIUF0/fOSP7wXcLYed6UELJFKSg=";
          };
        };
        frida-gum = {
          inherit version;
          src = {
            rev = "675929662780c9c35188a0a1cd0f6d0fb2b3c3b0";
            sha256 = "sha256-+dV5y3TAczwsyvMmI7muC6GIbFPObcjspGSRp3tGbdY=";
          };
        };
        frida-core = {
          inherit version;
          src = {
            rev = "897d79b35919af7b0cac5763631b042cf1eb4f78";
            sha256 = "sha256-SEgyyaoJ7fy934lmHTjQ9phF5Z22M4SzcqMOpNofMD4=";
          };
        };
        glib = {
          src = {
            rev = "805e42d63aa17f58b90a57c71f4b1896f154a535";
            sha256 = "sha256-XSOukzSm8c6XbkafKSWhcxbwJSE71P3tYat6Il+NsDU=";
            fetchSubmodules = true;
          };
          version = "2.75.0";
          # reason for vendoring: too many frida-specific features
          # override = pkgs.glib;
        };
        capstone = {
          src = {
            rev = "22d317042ee4d251280d2960f5cf294433977db4";
            sha256 = "sha256-KhzGRQzx5g9g/RddYtB/xwjTM4mn1sNJCCaJgT7cu/A=";
          };
          version = "5.0.0";
          # reason for vendoring: capstone 5 not in nixpkgs; it probably has frida-specific features too
          # override = pkgs.capstone;
        };
        libffi = {
          src = {
            rev = "763cf41612c4a9ed98d764a5237acdb9f5337f2d";
            sha256 = "sha256-BrJidiomPlJ/o/aGPMtnjIvOR0s6uD+C919+Y81Qvgk=";
          };
          version = "3.4.4";
          # reason for vendoring: it has frida-specific features
          # override = pkgs.libffi;
        };
        nghttp2 = {
          src = {
            rev = "91a1324cc5bcedbf7cd9a51a61427b362ee08109";
            sha256 = "sha256-BNTp0cRvSRQxQ52b64eE+dtJn9gv06dk7LUFA1Kcfds=";
          };
          version = "1.51.0";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.nghttp2;
        };
        brotli = {
          src = {
            rev = "9f51b6b95599466f46678381492834cdbde018f7";
            sha256 = "sha256-Qg1KZ7rA+N3OcaJXG/S+DACprFxNnTBWRD2lCAP3NFU=";
          };
          version = "1.0.9";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.brotli;
        };
        libsoup = {
          src = {
            rev = "071bebc4a85357d11c8d4b9265dc8f723216a684";
            sha256 = "sha256-Bet0zdXHplgbgyGeCQ6wx+eOQs70QE3kBoT66acZrgY=";
          };
          version = "3.3.0";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.libsoup_3;
        };
        libdwarf = {
          src = {
            rev = "0a5640598201d9a025c33055dde82d6597fcd650";
            sha256 = "sha256-Hl4QCUuHxqEt23yeA8nsITzYfIRNA/RxaNp32Bi/Tlg=";
          };
          version = "20191022";
          # reason for vendoring: this version is very old but has some security patches
          # override = pkgs.libdwarf;
        };
        quickjs = {
          src = {
            rev = "a3303a2bec40fb55df6de5e94e53a7a67e7dbfb0";
            sha256 = "sha256-sHAqeZgcDDPeJxefDFpea8/9KinNp8j0uvZJMp2Y954=";
          };
          version = "2021-03-27-frida";
          # reason for vendoring: too many frida-specific features
          # override = pkgs.quickjs;
        };
        # dont forget to update v8's deps too
        v8 = {
          src = {
            rev = "bda4a1a3ccc6231a389caebe309fc20fd7cf1650";
            sha256 = "sha256-Ust8RNhuqOUtHzb8bGrlvcjp2M0rfEP2MwS8NwsZJKE=";
          };
          version = "10.9.42";
          # reason for vendoring: not in nixpkgs
          # override = pkgs.v8;
        };
        tinycc = {
          src = {
            rev = "a438164dd4c453ae62c1224b4b7997507a388b3d";
            sha256 = "sha256-BoTzGr/4z8h7/EqUP9N1Xtg7CCtqT/uKVX8P/lzmDHg=";
          };
          version = "0.9.27-frida";
          # reason for vendoring: frida-specific features
          # override = pkgs.tinycc;
        };
        vala = {
          src = {
            rev = "62ee2b101a5e5f37ce2a073fdb36e7f6ffb553d1";
            sha256 = "sha256-czzWYcOo6qkvUNldDBWC2/1ugcaRwD2AnGGdq1ksLAE=";
          };
          version = "0.58.0-frida";
          # reason for vendoring: frida-specific features
          # override = pkgs.vala;
        };
        usrsctp = {
          src = {
            rev = "42627714785294aef2bb31851bdeef5db15f5802";
            sha256 = "sha256-qaAzO6sM/UxcvCUVrz+wbSR/bjATbqkJjc8U3zjSTdQ=";
          };
          version = "0.9.5.0";
          # reason for vendoring: frida-specific features
          # override = pkgs.usrsctp;
        };
        libgee = {
          src = {
            rev = "b1db8f4e0ff72583e5f10205a6512befffa7b541";
            sha256 = "sha256-c5TzCtgi8wE3B7IhQAwbJ3IXsD2D9SELcoo4tgzPhbk=";
          };
          version = "0.20.6";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.libgee;
        };
        libnice = {
          src = {
            rev = "3c9e960fdb79229b672cbd9e600b4a4f1346409e";
            sha256 = "sha256-TDgJ63ZuRnxYFioxw07/ryyRpbqgt4+X4IqukHTX2cM=";
          };
          version = "0.1.19.1";
          # reason for vendoring: frida-specific features
          # override = pkgs.libnice;
        };
        openssl = {
          src = {
            rev = "bcb2d5a58ff3c3c6098eedd8bc77895ad27fed0e";
            sha256 = "sha256-uTOlK3wYHzg7MkwXzEI7K/piXJjbTwrAL5QGrq/ohjY=";
          };
          version = "3.0.7";
          # reason for vendoring: symbol not found at runtime if linked to .so
          # override = pkgs.openssl;
        };
        glib-networking = {
          src = {
            rev = "54a06f8399cac1fbdddd130790475a45a8124304";
            sha256 = "sha256-NN9bvX2syB6gwLQuEitR+T8h582j/YbbwB+Q7tJE2U4=";
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
      python3Packages = lib.recurseIntoAttrs {
        frida = pkgs.callPackage ./pkgs/frida-python.nix {
          inherit versions srcs;
          frida-core = frida-core-static;
        };
      };
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
      /*frida-core = frida-core-static.override {
        frida-gumjs = frida-gumjs-static;
        enableStatic = false;
      };*/
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
