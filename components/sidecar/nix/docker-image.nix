{ pkgs, version, adversary-exe, cardano-cli, ... }:
let
  # Copy over the antithesis test driver
  antithesis-drivers = pkgs.runCommand "antithesis-drivers" { } ''
    mkdir -p $out/opt/antithesis/test/v1/
    cp -r ${../composer}/.  $out/opt/antithesis/test/v1
    chmod 0755 $out/opt/antithesis/test/v1/*/*
  '';

  # Create a wrapper script for the flaky chain sync driver (for testing purposes)
  flaky-chain-sync = pkgs.writeShellScriptBin "flaky-chain-sync" ''
    exec ${antithesis-drivers}/opt/antithesis/test/v1/chain-sync-client/parallel_driver_flaky_chain_sync.sh "$@"'';
  eventually-converged = pkgs.writeShellScriptBin "eventually-converged" ''
    exec ${antithesis-drivers}/opt/antithesis/test/v1/convergence/eventually_converged.sh "$@"'';

  # Make sure /usr/bin/env is available in the image
  usrBinEnv = pkgs.runCommand "usr-bin-env" { } ''
    mkdir -p $out/usr/bin
    ln -s ${pkgs.coreutils}/bin/env $out/usr/bin/env
  '';
  sidecar =
    pkgs.writeShellScriptBin "sidecar" (builtins.readFile ../sidecar.sh);
in pkgs.dockerTools.buildImage {
  name = "ghcr.io/cardano-foundation/cardano-node-antithesis/sidecar";
  tag = version;
  config = { EntryPoint = [ "sidecar" ]; };
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [
      pkgs.coreutils
      pkgs.bash
      pkgs.jq
      usrBinEnv
      antithesis-drivers
      flaky-chain-sync
      eventually-converged
      adversary-exe
      cardano-cli
      sidecar
    ];
  };
}
