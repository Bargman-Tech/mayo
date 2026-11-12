# lib/mayo/monitoring/genDashboard.nix
#
# genDashboard: monitoring inventory -> Grafana dashboard attrsets
#
# Mayo layer (other library assets — monitoring tooling). Pure data
# transformation. NO module system, NO user Nix. Dashboards are composed from
# templates (lib/mayo/monitoring/dashboard_templates/*.nix) using the small
# builder API exposed here. Host-derived PromQL — the node job union and the
# IP -> hostname rename transforms — is generated from the inventory, so fleet
# membership is never hand-maintained inside dashboard JSON.
#
# DATA INJECTION: both arguments come from the consuming repo — this file
# never imports Ketchup and never reads fleet data:
#   inventory  the consumer's monitoring inventory (host list, jobs, ports)
#   datasource the consumer's Grafana Prometheus datasource descriptor
#
# Callable (consumer side):
#   inventory = (import "${repo}/lib/monitoring/inventory.nix" …) { … };
#   gen = (import mayoLib.monitoring.genDashboard { inherit lib; })
#           { inherit inventory; datasource = { type = "prometheus"; uid = "…"; }; };
#   dashboard = gen.mkDashboard (import mayoLib.monitoring.dashboards … { dash = gen; });
#
# Does NOT:
# - Reference the NixOS module system (no `config`, no `lib.mkIf`)
# - Read filesystem paths or user config
# - Name machines, IPs, or jobs (all supplied via `inventory`)
{ lib }:
{ inventory, datasource }:
let
  inherit (builtins) replaceStrings isString isList isAttrs map removeAttrs;
  inherit (lib) concatStringsSep foldl' mapAttrs;

  # PromQL job union (inventory-supplied), e.g. "node|custom-job".
  nodeJobs = concatStringsSep "|" inventory.nodeJobs;

  # Recursively substitute the __NODE_JOBS__ placeholder with the job union.
  subst = value:
    if isString value then replaceStrings [ "__NODE_JOBS__" ] [ nodeJobs ] value
    else if isList value then map subst value
    else if isAttrs value then mapAttrs (_: subst) value
    else value;

  # Escape dotted IP for use in a Grafana renameByRegex pattern.
  escapeIp = ip: replaceStrings [ "." ] [ "\\." ] ip;

  # One renameByRegex transform: "<ip>:<port>" (or "<ip>") -> hostname.
  mkRename = withPort: host: {
    id = "renameByRegex";
    options = {
      regex = "/${escapeIp host.ip}:(.*)/";
      renamePattern = if withPort then "${host.hostname}:$1" else host.hostname;
    };
  };

  mkRenameTransforms = { hosts, withPort ? true }:
    map (mkRename withPort) hosts;

  # Named, inventory-derived rename sets templates can reference directly.
  renames = {
    nodeBare = mkRenameTransforms { hosts = inventory.node; withPort = false; };
    nodePort = mkRenameTransforms { hosts = inventory.node; withPort = true; };
    zfsPort = mkRenameTransforms { hosts = inventory.zfs; withPort = true; };
    nvidiaPort = mkRenameTransforms { hosts = inventory.nvidia; withPort = true; };
  };

  # Normalize a compact target spec into a full Grafana target.
  # `isRange` selects range-query targets (timeseries-like panels); stat/gauge
  # panels use instant queries and must not set range/editorMode.
  mkTarget = isRange: t:
    let
      refId = t.refId or "A";
    in
    { inherit datasource refId; editorMode = "code"; }
    // (if isRange then { range = true; } else { })
    // (if t ? legendFormat then { inherit (t) legendFormat; } else { })
    // (removeAttrs t [ "refId" "legendFormat" ]);

  # Panel types that issue range queries.
  rangePanelTypes = [ "timeseries" "heatmap" "state-timeline" "barchart" ];

  # Build a full panel from a compact spec.
  # Required: type, title, y. Optional: x, w, h, fieldConfig (the defaults
  # object), overrides, options, targets, transformations, extra.
  panel = spec:
    let
      isRange = builtins.elem spec.type rangePanelTypes;
    in
    {
      inherit datasource;
      inherit (spec) type title;
      gridPos = {
        x = spec.x or 0;
        y = spec.y;
        w = spec.w or 12;
        h = spec.h or 8;
      };
      targets = map (mkTarget isRange) (spec.targets or [ ]);
    }
    // (if spec ? fieldConfig then {
      fieldConfig = {
        defaults = spec.fieldConfig;
        overrides = spec.overrides or [ ];
      };
    } else { })
    // (if spec ? options then { inherit (spec) options; } else { })
    // (if spec ? transformations then { inherit (spec) transformations; } else { })
    // (if spec ? extra then spec.extra else { });

  # Row header panel.
  row = { title, y, collapsed ? false }:
    {
      type = "row";
      inherit title collapsed;
      gridPos = { h = 1; w = 24; x = 0; y = y; };
      panels = [ ];
    };

  # Assign sequential panel ids (Grafana requires unique ids).
  assignIds = panels:
    (foldl'
      (acc: p: {
        panels = acc.panels ++ [ (p // { id = acc.next; }) ];
        next = acc.next + 1;
      })
      { panels = [ ]; next = 1; }
      panels).panels;

  # Shared dashboard root defaults.
  rootDefaults = {
    annotations = { list = [ ]; };
    editable = false;
    fiscalYearStartMonth = 0;
    graphTooltip = 1;
    id = null;
    links = [ ];
    schemaVersion = 42;
    templating = { list = [ ]; };
    timepicker = { };
    version = 1;
    timezone = "utc";
    refresh = "30s";
    time = { from = "now-1h"; to = "now"; };
  };

  # Turn a template attrset into a complete dashboard attrset.
  mkDashboard = tpl:
    rootDefaults
    // {
      uid = tpl.uid;
      title = tpl.title;
      description = tpl.description or "";
      tags = tpl.tags or [ "fleet" "nix-provisioned" ];
      refresh = tpl.refresh or rootDefaults.refresh;
      time = tpl.time or rootDefaults.time;
      timezone = tpl.timezone or rootDefaults.timezone;
      graphTooltip = tpl.graphTooltip or rootDefaults.graphTooltip;
      panels = assignIds (map subst tpl.panels);
    };
in
{
  inherit
    datasource
    nodeJobs
    renames
    mkRenameTransforms
    panel
    row
    mkDashboard
    subst
    lib
    inventory;
}
