let
  flake = builtins.getFlake (toString ../../../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
in
pkgs.writeShellScriptBin "computer-use-runtime" ''
  if [[ $# -lt 1 ]]; then
    printf 'computer-use-runtime: expected native executable and arguments\n' >&2
    exit 2
  fi
  exec "${pkgs.stdenv.cc.bintools.dynamicLinker}" \
    --library-path "${pkgs.glibc}/lib:${pkgs.stdenv.cc.cc.libgcc}/lib" \
    "$@"
''
