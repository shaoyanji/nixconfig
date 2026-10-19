# Declarative Pie Menu (Kando) Generator & Schema Builder
#
# Transforms clean, high-level tool catalogs and compositor actions into
# valid Kando 3.0.0 menu trees.
#
# Solves the three core operational requirements:
#   1. Zero closure bloat: tools run ephemerally via `nix run` / `nix shell`.
#   2. Compositor integration: native `niri msg action` spatial actions.
#   3. Pure declarative compilation: turns plain Nix attrsets into Kando JSON.
#
{lib}: let
  # --- Action Builders --------------------------------------------------------
  mkCloseMenuAction = {type = "close-menu";};
  mkCloseSubmenuAction = {type = "close-submenu";};

  # Executes an arbitrary shell command.
  mkExecuteCommandAction = {
    command,
    detached ? true,
    isolated ? false,
  }: {
    type = "execute-command";
    inherit command detached isolated;
  };

  # Ephemeral invocation via `nix run`.
  # For CLI tools: wraps in a terminal (default: kitty) holding the output so the
  # window doesn't instantly close on completion.
  # For GUI tools: launches directly detached in Wayland.
  mkNixRunAction = {
    pkg,
    args ? "",
    type ? "cli",
    terminal ? "kitty",
    flake ? "nixpkgs",
  }: let
    argStr = lib.optionalString (args != "") " -- ${args}";
    runCmd = "nix run ${flake}#${pkg}${argStr}";
    command =
      if type == "cli"
      then "${terminal} --hold -- sh -c \"${runCmd}; exec $SHELL\""
      else runCmd;
  in
    mkExecuteCommandAction {
      inherit command;
      detached = true;
      isolated = false;
    };

  # Ephemeral multi-package development / debug shell via `nix shell`.
  mkNixShellAction = {
    pkgs,
    command ? "",
    terminal ? "kitty",
    flake ? "nixpkgs",
  }: let
    pkgList = lib.concatMapStringsSep " " (p: "${flake}#${p}") pkgs;
    cmdPart = lib.optionalString (command != "") " -c \"${command}; exec $SHELL\"";
    shellCmd = "${terminal} -- nix shell ${pkgList}${cmdPart}";
  in
    mkExecuteCommandAction {
      command = shellCmd;
      detached = true;
      isolated = false;
    };

  # Native Niri compositor action (e.g. `focus-workspace-up`, `toggle-overview`).
  mkNiriAction = {action}:
    mkExecuteCommandAction {
      command = "niri msg action ${action}";
      detached = true;
      isolated = false;
    };

  # Opens a Web URI or bookmark.
  mkOpenUriAction = {uri}: {
    type = "open-uri";
    inherit uri;
  };

  # Simulates a keyboard shortcut (e.g. "ControlLeft+KeyV").
  mkSimulateHotkeyAction = {hotkey}: {
    type = "simulate-hotkey";
    inherit hotkey;
  };

  # --- Node Builders ----------------------------------------------------------

  # Creates a leaf action button in Kando.
  mkButton = {
    name,
    icon ? "circle",
    iconTheme ? "material-symbols-rounded",
    angle ? null,
    actions ? [],
    quickSelectKey ? null,
  }: let
    allActions = actions ++ [mkCloseMenuAction];
    node = {
      type = "button";
      inherit name icon iconTheme;
      selectWorkflow =
        {
          actions = allActions;
        }
        // lib.optionalAttrs (quickSelectKey != null) {inherit quickSelectKey;};
    };
  in
    node // lib.optionalAttrs (angle != null) {inherit angle;};

  # Creates a nested submenu node with back navigation.
  mkSubmenu = {
    name,
    icon ? "folder",
    iconTheme ? "material-symbols-rounded",
    angle ? null,
    quickSelectKey ? null,
    children ? [],
  }: let
    node = {
      type = "submenu";
      inherit name icon iconTheme children;
      activateWorkflow = {
        quickSelectKey = "Backspace";
        actions = [mkCloseSubmenuAction];
      };
    };
  in
    node
    // lib.optionalAttrs (angle != null) {inherit angle;}
    // lib.optionalAttrs (quickSelectKey != null) {
      openWorkflow = {
        inherit quickSelectKey;
        actions = [];
      };
    };

  # Creates the root container for a menu.
  mkRoot = {
    name,
    icon ? "award_star",
    iconTheme ? "material-symbols-rounded",
    children ? [],
  }: {
    type = "root";
    inherit name icon iconTheme children;
    activateWorkflow = {
      quickSelectKey = "Backspace";
      actions = [mkCloseMenuAction];
    };
  };

  # Creates a top-level menu specification.
  mkMenu = {
    name,
    shortcut ? "",
    shortcutID ? "",
    icon ? "award_star",
    iconTheme ? "material-symbols-rounded",
    children ? [],
    centered ? false,
    anchored ? false,
    hoverMode ? false,
    tags ? [],
  }: {
    inherit shortcut shortcutID anchored hoverMode tags;
    useFixedPosition = centered;
    fixedMenuPosition = {
      x = 0.5;
      y = 0.5;
    };
    root = mkRoot {
      inherit name icon iconTheme children;
    };
  };

  # Creates a complete Kando 3.0.0 configuration object.
  mkConfig = {
    menus ? [],
    collections ? [],
  }: {
    version = "3.0.0";
    inherit menus collections;
  };

  # --- High-Level Compilers ---------------------------------------------------

  # Compiles a structured catalog of security / dev tools into a nested Kando menu.
  #
  # Example input catalog:
  # {
  #   "Recon" = {
  #     icon = "radar";
  #     tools = [
  #       { name = "Rustscan"; pkg = "rustscan"; type = "cli"; icon = "speed"; }
  #       { name = "Amass"; pkg = "amass"; type = "cli"; }
  #     ];
  #   };
  #   "Web" = {
  #     icon = "language";
  #     tools = [
  #       { name = "Burp Suite"; pkg = "burpsuite"; type = "gui"; icon = "security"; }
  #     ];
  #   };
  # }
  fromToolCatalog = {
    name ? "Athena Tools",
    shortcut ? "Control+Space",
    shortcutID ? "athena-menu",
    icon ? "security",
    iconTheme ? "material-symbols-rounded",
    hoverMode ? false,
    categories,
  }: let
    compileTool = tool:
      mkButton {
        inherit (tool) name;
        icon = tool.icon or "terminal";
        iconTheme = tool.iconTheme or "material-symbols-rounded";
        angle = tool.angle or null;
        actions = [
          (mkNixRunAction {
            inherit (tool) pkg;
            args = tool.args or "";
            type = tool.type or "cli";
            terminal = tool.terminal or "kitty";
            flake = tool.flake or "nixpkgs";
          })
        ];
      };

    compileCategory = catName: catData:
      mkSubmenu {
        name = catName;
        icon = catData.icon or "folder";
        iconTheme = catData.iconTheme or "material-symbols-rounded";
        angle = catData.angle or null;
        children = map compileTool (catData.tools or []);
      };

    categorySubmenus = lib.mapAttrsToList compileCategory categories;
  in
    mkMenu {
      inherit name shortcut shortcutID icon iconTheme hoverMode;
      children = categorySubmenus;
    };

  # Compiles directional / spatial Niri compositor navigation into a 4-quadrant radial menu.
  #
  # Example:
  # fromSpatialNiri {
  #   up = "focus-workspace-up";
  #   down = "focus-workspace-down";
  #   left = "focus-monitor-left";
  #   right = "focus-monitor-right";
  #   extra = [
  #     { name = "Overview"; action = "toggle-overview"; icon = "dashboard"; }
  #   ];
  # }
  fromSpatialNiri = {
    name ? "Niri Spatial",
    shortcut ? "Mod+B",
    shortcutID ? "niri-spatial",
    up ? "focus-workspace-up",
    down ? "focus-workspace-down",
    left ? "focus-monitor-left",
    right ? "focus-monitor-right",
    extra ? [],
  }: let
    # Angles in Kando: 0 = East/Right, 90 = South/Down, 180 = West/Left, 270 = North/Up
    directions = [
      (mkButton {
        name = "Right";
        icon = "arrow_forward";
        angle = 0;
        actions = [(mkNiriAction {action = right;})];
      })
      (mkButton {
        name = "Down";
        icon = "arrow_downward";
        angle = 90;
        actions = [(mkNiriAction {action = down;})];
      })
      (mkButton {
        name = "Left";
        icon = "arrow_back";
        angle = 180;
        actions = [(mkNiriAction {action = left;})];
      })
      (mkButton {
        name = "Up";
        icon = "arrow_upward";
        angle = 270;
        actions = [(mkNiriAction {action = up;})];
      })
    ];

    extraButtons = map (item:
      mkButton {
        inherit (item) name;
        icon = item.icon or "circle";
        iconTheme = item.iconTheme or "material-symbols-rounded";
        actions = [(mkNiriAction {inherit (item) action;})];
      })
    extra;
  in
    mkMenu {
      inherit name shortcut shortcutID;
      icon = "navigation";
      hoverMode = true;
      children = directions ++ extraButtons;
    };
in {
  inherit
    mkCloseMenuAction
    mkCloseSubmenuAction
    mkExecuteCommandAction
    mkNixRunAction
    mkNixShellAction
    mkNiriAction
    mkOpenUriAction
    mkSimulateHotkeyAction
    mkButton
    mkSubmenu
    mkRoot
    mkMenu
    mkConfig
    fromToolCatalog
    fromSpatialNiri
    ;

  # Serializer helper to output pure JSON formatted string
  toJSON = config: builtins.toJSON config;
}
