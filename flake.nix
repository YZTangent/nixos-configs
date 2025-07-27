# /etc/nixos/flake.nix
{
  description = "A composable NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      # IMPORTANT: we're using "libgbm" and is only available in unstable so ensure
      # to have it up-to-date or simply don't specify the nixpkgs input
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations = {
      # Replace `your-hostname` with the actual hostname of your system.
      # You can find it by running the `hostname` command in your terminal.
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # Pass inputs to other modules
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.yztangent = import ./home.nix;
	          home-manager.backupFileExtension = "backup";

            # This makes the flake's inputs available to home.nix and its modules
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
        ];
      };
    };
  };
}
