{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixvim.url = "github:nix-community/nixvim";
    # Internal nhost backend flake (local checkout, tracks its main branch).
    # Bump the pinned revision with: nix flake update nhost-be
    nhost-be.url = "git+file:///home/alberto/code/be";
    nhost.url = "git+file:///home/alberto/code/nhost";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./secureframe.nix
        inputs.sops-nix.nixosModules.sops
      ];
    };
  };
}
