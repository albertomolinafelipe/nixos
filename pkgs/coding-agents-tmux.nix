{
  pkgs,
  lib,
  ...
}:
let
  commander = pkgs.fetchurl {
    url = "https://registry.npmjs.org/commander/-/commander-15.0.0.tgz";
    hash = "sha256-YyweA5sx6Y+nnE+uWxCl/7v53w8hyf+z106Vc0swaW8=";
  };
in
pkgs.tmuxPlugins.mkTmuxPlugin {
  pluginName = "coding-agents-tmux";
  version = "0-unstable-2026-09-10";
  rtpFilePath = "coding-agents-tmux.tmux";

  src = pkgs.fetchFromGitHub {
    owner = "corwinm";
    repo = "coding-agents-tmux";
    rev = "9e349cc331c5c61b5e95cf0d6b93da90f6fa28a4";
    hash = "sha256-neIkLDMT5N+ngoLXu35NHQ+cY9u21s8i9uOuWNA5T0A=";
  };

  # The plugin npm-installs commander at runtime, which cannot work from the
  # read-only nix store, so vendor it and let its dependency check short-circuit.
  postInstall = ''
    mkdir -p $target/node_modules/commander
    tar -xzf ${commander} -C $target/node_modules/commander --strip-components=1

    for f in $target/coding-agents-tmux.tmux $target/bin/coding-agents-tmux $target/scripts/*.sh; do
      wrapProgram $f --prefix PATH : ${
        lib.makeBinPath [
          pkgs.nodejs_24
          pkgs.bash
        ]
      }
    done
  '';

  nativeBuildInputs = [ pkgs.makeWrapper ];
}
