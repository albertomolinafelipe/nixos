{ lib, buildGoModule, fetchFromGitHub }:

# Fleet's osquery extension providing the fleetd_* tables (orbit_info, etc.)
# that Secureframe's distributed queries reference. Not in nixpkgs, so we build
# it from the pinned fleet source. Bump rev/hashes in ../secureframe/versions.toml.
let
  v = (import ../secureframe/versions.nix).fleetd-tables;
in
buildGoModule {
  pname = "fleetd-tables";
  version = v.version;

  src = fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    rev = v.rev;
    hash = v.srcHash;
  };

  vendorHash = v.vendorHash;

  subPackages = [ "orbit/cmd/fleetd_tables" ];

  # osquery only autoloads extensions whose filename ends in `.ext`.
  postInstall = ''
    mv "$out/bin/fleetd_tables" "$out/bin/fleetd_tables.ext"
  '';

  meta = {
    description = "Fleet osquery extension tables (fleetd_tables.ext)";
    homepage = "https://github.com/fleetdm/fleet";
    mainProgram = "fleetd_tables.ext";
  };
}
