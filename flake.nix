{
  description = "A self-contained flake for running Mac OS System 7 with QEMU";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # This defines the script that will run the emulator.
        # It uses $PWD to construct an absolute path at runtime,
        # ensuring the local files are found.
        run-script = pkgs.writeShellScriptBin "run-system7" ''
          #!/bin/sh
          
          # Check if the required files exist in the current directory
          if [ ! -f "System 7.5.3 HD.dsk" ] || [ ! -f "Quadra-650.ROM" ]; then
            echo "Error: Make sure 'System 7.5.3 HD.dsk' and 'Quadra-650.ROM' are in the current directory."
            exit 1
          fi

          echo "Starting QEMU for System 7..."

          # Use qemu_full, which includes all emulators.
          # Use the specific 'q800' machine type for the Quadra 800.
          # Explicitly define the SCSI controller and attach the drive to it.
          ${pkgs.qemu_full}/bin/qemu-system-m68k \
            -bios "$PWD/Quadra-650.ROM" \
            -M q800 \
            -m 128 \
            -device scsi-hd,bus=scsi.0,drive=hd0 \
            -drive id=hd0,file="$PWD/System 7.5.3 HD.dsk",format=raw,if=none \
            -g 800x600x8 \
            -display default,show-cursor=on
        '';

      in
      {
        # A runnable app that starts the emulator.
        apps.default = {
          type = "app";
          program = "${run-script}/bin/run-system7";
        };

        # A development shell for convenience.
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.qemu_full ];
          shellHook = ''
            echo "Welcome to the QEMU development shell."
            echo "qemu-system-m68k is available."
          '';
        };
      });
}

