{
  description = "Zigtris";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
  let build_for = system:
  let pkgs = import nixpkgs { inherit system; };
  in pkgs.stdenv.mkDerivation {
    name = "zigtris";
    src = self;
    buildInputs = with pkgs; [
      zig_0_15
      sdl3
      sdl3-ttf
      pkg-config
      zls
    ];
    buildPhase = "zig build test";
    installPhase = "zig build -Doptimize=ReleaseFast";
  }; in {
    packages.x86_64-linux.default = build_for "x86_64-linux";
  };
}
