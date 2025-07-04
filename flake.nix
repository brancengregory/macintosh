{
  description = "A flake for running Mac OS System 7 with QEMU";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    alejandra.url = "github:kamadorueda/alejandra";
  };

  outputs = { self, nixpkgs, alejandra }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      formatter = forAllSystems (system: alejandra.defaultPackage.${system});

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Create a custom QEMU package with classic Mac emulation enabled.
          # The default QEMU in nixpkgs disables this target.
          qemu-with-mac = pkgs.qemu.overrideAttrs (old: {
            configureFlags = old.configureFlags ++ [ "--target-list=m68k-softmmu" ];
          });

        in
        {
          default = pkgs.stdenv.mkDerivation {
            name = "qemu-system7-runner";
            src = ./.;
            # Use our custom QEMU package
            buildInputs = [ qemu-with-mac ];

            script = pkgs.writeShellScriptBin "run-system7" ''
              #!/bin/sh
              
              # Check if the required files exist
              if [ ! -f "System 7.5.3 HD.dsk" ] || [ ! -f "Quadra-650.ROM" ]; then
                echo "Error: Make sure 'System 7.5.3 HD.dsk' and 'Quadra-650.ROM' are in the current directory."
                exit 1
              fi

              echo "Starting QEMU for System 7..."

              # QEMU command to emulate a Macintosh
              # Using the 'mac' machine type which should now be supported.
              ${qemu-with-mac}/bin/qemu-system-m68k \
                -bios ./Quadra-650.ROM \
                -M mac \
                -m 128 \
                -hda "System 7.5.3 HD.dsk" \
                -g 1024x768x8 \
                -display default,show-cursor=on
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp ${self.packages.${system}.default.script}/bin/run-system7 $out/bin
            '';
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/run-system7";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              # You could also add qemu-with-mac here for development
              pkgs.qemu
            ];
            shellHook = ''
              echo "Welcome to the QEMU development shell."
              echo "Note: the default qemu here may not have Mac support."
              echo "The 'run-system7' script uses a custom-built QEMU."
            '';
          };
        });
    };
}

