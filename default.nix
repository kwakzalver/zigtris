let
  pkgs = import <nixpkgs> {};
in pkgs.mkShell {
  packages = with pkgs; [
    zig
    sdl3
    sdl3-ttf
    pkg-config
    zls
  ];
}
