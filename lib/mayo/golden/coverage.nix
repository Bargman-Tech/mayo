# lib/mayo/golden/coverage.nix
# Golden coverage audit (Mayo layer — golden tooling ruling 2026-11-11).
#
# Data-injected on purpose (split-readiness): the caller supplies machine names,
# topology names and the goldens directory — this file never imports Ketchup and
# never reads fleet data itself. Behaviour is byte-identical to the former
# parent-side lib/golden_coverage.nix for the same inputs.
{ goldenDir, topologyMachines, machineNames }:

let
  goldenFiles = builtins.readDir goldenDir;
  goldenMachines = builtins.map
    (name: builtins.substring 0 (builtins.stringLength name - 5) name)
    (builtins.attrNames (builtins.filterAttrs
      (name: type: type == "regular" && builtins.match ".*\\.json" name != null)
      goldenFiles));

  missingTopology = builtins.filter (m: ! builtins.elem m topologyMachines) machineNames;
  missingGolden = builtins.filter (m: builtins.elem m machineNames && ! builtins.elem m goldenMachines) topologyMachines;

  isComplete = missingTopology == [ ] && missingGolden == [ ];

  coveredMachines = builtins.filter
    (m: builtins.elem m topologyMachines && builtins.elem m goldenMachines)
    machineNames;
  coveredCount = builtins.length coveredMachines;
  totalMachines = builtins.length machineNames;
  coveragePercent = if totalMachines == 0 then 100 else builtins.floor (coveredCount * 100.0 / totalMachines);

  missing = {
    topology = missingTopology;
    golden = missingGolden;
  };
in
{
  inherit isComplete missing coveragePercent coveredCount totalMachines;
}
