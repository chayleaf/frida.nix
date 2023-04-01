# frida.nix

a nixos flake to compile frida 16.0.11 from source (i don't plan on
updating it, but you're free to send prs).

## warning

vendoring is used by the authors, so this will take up a lot of disk
space! (relatively speaking)

## license

0bsd, except v8.nix (taken from nixpkgs) and all package.json files
(taken from frida), except package.json from gumjs-runtime is 0bsd too

## faq

- q: is this done the proper way?
- a: no, this is done in an utterly stupid way. basically, i combine all
  vendored static dependencies into one `.a` file so it can be used with
  python
- q: why???
- a: i couldn't find another way to make it link all the symbols
  properly. you're welcome to help (overriding linker flags could be the
  answer).
- q: so i can't use it in my own c programs because of potential symbol
  conflicts?
- a: you can because the symbols aren't exported from the .so (well at
  least i hope so). worst case you can `dlopen` it.
- q: why do you use so much of frida's vendored deps? isn't it possible
  to build frida using only a part of those vendored deps?
- a: i faced plenty of issues during making this and wanted to make sure
  they weren't caused by me not using vendored deps.

