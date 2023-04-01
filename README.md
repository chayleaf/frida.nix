# frida.nix

a nixos flake to compile frida 16.0.11 from source (i don't plan on
updating it, but you're free to send prs).

## warning

vendoring is used extensively by frida devs, so this will take up a lot
of disk space! (relatively speaking)

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
  answer)
- q: so i can't use it in my own c programs because of potential symbol
  conflicts?
- a: you can because the symbols aren't exported from the .so (well at
  least i hope so). worst case you can `dlopen` it
- q: why not dynamic?
- a: there are dynamic builds for frida-gum, but not frida-core since it
  can't be built dynamically due to... a bug? whatever
- q: will you upstream this to nixpkgs?
- a: this is 0bsd so feel free to do it! i don't want to deal with this
  vendored mess
- q: some of frida's deps are basically the same as upstream code, why
  did you keep them vendored?
- a: for whatever reason they don't work without static linking

