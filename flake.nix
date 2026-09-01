{
  description = "Mitishell Hyprland shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    quickshell = {
      url = "github:quickshell-mirror/quickshell?ref=v0.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      quickshell,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;
          quickshellPackage = quickshell.packages.${system}.default;
          fontConfig = pkgs.makeFontsConf {
            fontDirectories = [ pkgs.nerd-fonts.adwaita-mono ];
          };
          runtimePath = lib.makeBinPath [
            pkgs.bash
            pkgs.fontconfig
            pkgs.hyprshutdown
            quickshellPackage
          ];
        in
        pkgs.buildGoModule {
          pname = "mitishell";
          version = "1.3.3";
          src = self;

          vendorHash = "sha256-Ac63bZlBvCrhS7b8mk7aJdApI8UGtJxnZG35L37roGY=";
          subPackages = [ "cmd/mitishell" ];
          ldflags = [
            "-s"
            "-w"
          ];

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postInstall = ''
            mkdir -p "$out/share/mitishell"
            cp -R shell "$out/share/mitishell/shell"

            install -Dm644 data/mitishell.desktop \
              "$out/share/applications/mitishell.desktop"
            substituteInPlace "$out/share/applications/mitishell.desktop" \
              --replace-fail "Exec=mitishell" "Exec=mitishell-shell"

            wrapProgram "$out/bin/mitishell" \
              --set-default MITISHELL_BIN "$out/bin/mitishell" \
              --set-default MITISHELL_QS_BIN "${quickshellPackage}/bin/qs" \
              --set-default MITISHELL_QS_PATH "$out/share/mitishell/shell" \
              --set-default FONTCONFIG_FILE "${fontConfig}" \
              --prefix PATH : "${runtimePath}"

            makeWrapper "${quickshellPackage}/bin/quickshell" \
              "$out/bin/mitishell-shell" \
              --add-flags "-n -p $out/share/mitishell/shell" \
              --set MITISHELL_BIN "$out/bin/mitishell" \
              --set MITISHELL_QS_BIN "${quickshellPackage}/bin/qs" \
              --set MITISHELL_QS_PATH "$out/share/mitishell/shell" \
              --set FONTCONFIG_FILE "${fontConfig}" \
              --prefix PATH : "${runtimePath}"
          '';

          meta = {
            description = "Personal Hyprland desktop shell built with QuickShell";
            homepage = "https://github.com/aileks/mitishell";
            license = lib.licenses.gpl3Plus;
            mainProgram = "mitishell-shell";
            platforms = lib.platforms.linux;
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          package = packageFor system;
        in
        {
          default = package;
          mitishell = package;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${packageFor system}/bin/mitishell-shell";
          meta.description = "Run the Mitishell desktop shell";
        };
      });

      checks = forAllSystems (system: {
        mitishell = packageFor system;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;
          quickshellPackage = quickshell.packages.${system}.default;
          qmlImportPath = lib.makeSearchPath pkgs.qt6.qtbase.qtQmlPrefix [
            pkgs.qt6.qtdeclarative
            quickshellPackage
          ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.fontconfig
              pkgs.git
              pkgs.go_1_26
              pkgs.gnumake
              pkgs.hyprshutdown
              pkgs.nerd-fonts.adwaita-mono
              pkgs.nodejs
              pkgs.qt6.qtdeclarative
              quickshellPackage
            ];

            QMLLINT = lib.getExe' pkgs.qt6.qtdeclarative "qmllint";
            QMLTESTRUNNER = lib.getExe' pkgs.qt6.qtdeclarative "qmltestrunner";
            QML_IMPORT_PATH = qmlImportPath;
            FONTCONFIG_FILE = pkgs.makeFontsConf {
              fontDirectories = [ pkgs.nerd-fonts.adwaita-mono ];
            };
          };
        }
      );
    };
}
