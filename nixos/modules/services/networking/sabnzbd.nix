{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.sabnzbd;
  inherit (pkgs) sabnzbd;

in

{

  ###### interface

  options = {
    services.sabnzbd = {
      enable = mkEnableOption (lib.mdDoc "the sabnzbd server");

      package = mkOption {
        type = types.package;
        default = pkgs.sabnzbd;
        defaultText = lib.literalExpression "pkgs.sabnzbd";
        description = lib.mdDoc "The sabnzbd executable package run by the service.";
      };

      configFile = mkOption {
        type = types.path;
        default = "${cfg.dataDir}/sabnzbd.ini";
        description = lib.mdDoc "Path to config file.";
      };

      user = mkOption {
        default = "sabnzbd";
        type = types.str;
        description = lib.mdDoc "User to run the service as";
      };

      group = mkOption {
        type = types.str;
        default = "sabnzbd";
        description = lib.mdDoc "Group to run the service as";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/sabnzbd";
        description = lib.mdDoc ''
          The directory where sabnzbd stores its data files.
        '';
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc ''
          Open ports in the firewall for the sabnzbd web interface
        '';
      };
    };
  };


  ###### implementation

  config = mkIf cfg.enable {
    users.users = mkIf (cfg.user == "sabnzbd") {
      sabnzbd = {
        uid = config.ids.uids.sabnzbd;
        group = cfg.group;
        description = "sabnzbd user";
        home = cfg.dataDir;
      };
    };

    users.groups = mkIf (cfg.group == "sabnzbd") {
      sabnzbd.gid = config.ids.gids.sabnzbd;
    };

    systemd.services.sabnzbd = {
        description = "sabnzbd server";
        wantedBy    = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          Type = "forking";
          GuessMainPID = "no";
          User = cfg.user;
          Group = cfg.group;

          # Run the pre-start script with full permissions (the "!" prefix) so it
          # can create the data directory if necessary.
          ExecStartPre = let
            preStartScript = pkgs.writeScript "sabnzbd-run-prestart" ''
              #!${pkgs.bash}/bin/bash

              # Create data directory if it doesn't exist
              if ! test -d "${cfg.dataDir}"; then
                echo "Creating initial sabnzbd data directory in: ${cfg.dataDir}"
                install -d -m 0700 -o "${cfg.user}" -g "${cfg.group}" "${cfg.dataDir}"
              fi
            '';
          in
            "!${preStartScript}";

          ExecStart = "${lib.getBin cfg.package}/bin/sabnzbd -d -f ${cfg.configFile}";
        };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 8080 ];
    };
  };
}
