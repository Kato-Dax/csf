{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "csf";
  src = ./.;

  nativeBuildInputs = [];
  buildInputs = [];

  buildPhase = ''
    gcc -O3 ./csf.c -o csf
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp ./csf $out/bin/
    chmod +x $out/bin/csf
  '';
}
