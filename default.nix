{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "scf";
  src = ./.;

  nativeBuildInputs = [];
  buildInputs = [];

  installPhase = ''
    mkdir -p $out/bin
    cp ./csf.scm $out/bin/
    echo "#!/usr/bin/env sh" > $out/bin/csf
    echo "${pkgs.chez}/bin/scheme --program $out/bin/csf.scm \"\''${@:1}\"" >> $out/bin/csf
    chmod +x $out/bin/csf
  '';
}
