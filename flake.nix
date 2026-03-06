{
  description = "TinyTapeout TTSKY26a VGA Demoscene Project";

  inputs = {
    nix-eda.url = "github:fossi-foundation/nix-eda";
    ciel.url = "github:fossi-foundation/ciel";
    devshell.url = "github:numtide/devshell";
  };

  inputs.ciel.inputs.nix-eda.follows = "nix-eda";
  inputs.devshell.inputs.nixpkgs.follows = "nix-eda/nixpkgs";

  outputs = { self, nix-eda, ciel, devshell, ... }:
  let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nix-eda.inputs.nixpkgs.lib.genAttrs systems;
  in {
    devShells = forAllSystems (system:
      let
        pkgs = import nix-eda.inputs.nixpkgs {
          inherit system;
          overlays = [
            devshell.overlays.default
            nix-eda.overlays.default
          ];
        };
      in {
        default = pkgs.devshell.mkShell {
          name = "tt-demoscene-vga";
          packages = [
            # All EDA tools from nix-eda
            pkgs.yosys
            pkgs.verilator
            pkgs.magic-vlsi
            pkgs.netgen
            pkgs.klayout
            pkgs.ngspice
            pkgs.gtkwave

            # PDK management (ciel - Leo Moser's tool)
            ciel.packages.${system}.default

            pkgs.python3
          ];
          env = [
            { name = "PDK"; value = "sky130A"; }
          ];
        };
      }
    );
  };
}
