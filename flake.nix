{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    socle = {
      url = "github:dvdjv/socle/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, socle, ... }:
    let
      pkgs = import nixpkgs {
        # Change localSystem to aarch64-linux and remove crossSystem if you are going to use this configuration on your SBC
        localSystem = "x86_64-linux";
        crossSystem = "aarch64-linux";
      };
    in {
      nixosConfigurations = {
        nixos = pkgs.nixos [
          # Uncomment one of the below lines depending on your board
          socle.nixosModules.orangepi-5
          # socle.nixosModules.orangepi-5-plus

          {
            # You can set your timezone here
            # time.timeZone = "Europe/Dublin";

            # Hardware can be turned on and off here
            board.hardware.enabled = {
              # If you are useing Orange Pi 5, uncomment the line below to turn the LED off
              # led = false;

              # If you are using Orange Pi 5 Plus, uncomment the line below to turn the LEDs off
              # leds = false;

              # Uncomment the line below to turn on the AP6275P Wi-Fi module
              # wifi-ap6275p = true;
            };

            # Following are the nurmal NixOS configurations which you can find in a /etc/nixos/configuration.nix.

            nix.settings = {
              experimental-features = [ "nix-command" "flakes" ];
              # Binary Cache for Haskell.nix
              trusted-public-keys = [
                "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
                "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
              ];
              substituters =
                [ "https://cache.iog.io" "https://cache.zw3rk.com" ];
            };

            # Set your time zone.
            time.timeZone = "Asia/Shanghai";

            # List packages installed in system profile. To search, run:
            # $ nix search wget
            environment.systemPackages = with pkgs; [
              git # used by nix flakes
              curl
              wget

              neofetch
              lm_sensors # `sensors`
              btop # monitor system resources

              # Peripherals
              mtdutils
              i2c-tools
              minicom

              # some utils
              file
              tree
              psmisc

              # some dev tools
            ];

            # use systemd-network instead
            networking.useNetworkd = true;
            systemd.network.enable = true;

            # use dhcp for the LAN interface
            systemd.network.networks."40-end1" = {
              matchConfig.Name = "end1";
              networkConfig = {
                # start a DHCP Client for IPv4 Addressing/Routing
                DHCP = "ipv4";
                # accept Router Advertisements for Stateless IPv6 Autoconfiguraton (SLAAC)
                IPv6AcceptRA = true;
              };
              # make routing on this interface a dependency for network-online.target
              linkConfig = {
                RequiredForOnline = "routable";
                MACAddress = "c2:d3:89:3c:a2:6e";
              };
            };

            # Open ports in the firewall.
            networking.firewall.allowedTCPPorts = [ 22 443 8883 ];
            # networking.firewall.allowedUDPPorts = [ ... ];
            # Or disable the firewall altogether.
            # networking.firewall.enable = false;
            # Enable the OpenSSH daemon.

            services.openssh = {
              enable = true;
              settings = {
                X11Forwarding = true;
                PasswordAuthentication = true;
              };
              openFirewall = true;
            };

            # =========================================================================
            #      Users & Groups NixOS Configuration
            # =========================================================================

            # TODO Define a user account. Don't forget to update this!
            users.users."chenjf" = {
              hashedPassword =
                "$y$j9T$U.t7m6E8cELNNcY4yatIx1$XfaRrx7xZch1tfnZo16oCboW1wtp7ujnTLe70nSwCA.";
              isNormalUser = true;
              home = "/home/chenjf";
              extraGroups = [ "users" "wheel" ];
            };

            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDouazcY0grLX8lAz/XrtDS1ZIo0s91BS7VrCKlzfRZtmcoI041vz+SBCCWbtnOMmWRFtA948aGtCN6EKD3JSREmrmJU1JfTIoekYzemdbjMbsTnIw0czP7weFtfFgdwhn8vro11k3uy0uG/32+aUYNUx+CNaDKulBRtg+oXRmjkrHCtapCHpN9/FMsvZjP0NbqVKtbf5Jem6Pqx8Himo3cZq3SKSYG8UIC/mAebEz793M5rR4FSvzXlfgiwCBn07F3+0rQAL6ZtsNEE521iJyU88tk6VsewPsZNvguCY21y3eKGYsny+ITMfR4liZjToIkrJGt3l7EMJawsAUemMWz hugh.jf.chen@gmail.com"
            ];

            users.groups = {
              "chenjf" = { };
              docker = { };
            };

            # config NOPASSWORD for the user
            security.sudo.extraRules = [{
              users = [ "chenjf" ];
              commands = [{
                command = "ALL";
                options = [
                  "NOPASSWD"
                ]; # "SETENV" # Adding the following could be a good idea
              }];
            }];

            # some env settting for shell
            environment.interactiveShellInit = ''
              alias 'ls=ls --color=always'
              alias 'll=ls -l'
              alias 'ltr=ls -ltr'
              alias 'ltra=ls -ltra'
              export 'TERM=xterm-256color'
            '';

            # This value determines the NixOS release from which the default
            # settings for stateful data, like file locations and database versions
            # on your system were taken. It‘s perfectly fine and recommended to leave
            # this value at the release version of the first install of this system.
            # Before changing this value read the documentation for this option
            # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
            system.stateVersion = "23.11"; # Did you read the comment?

            # add a service unit to start the sshuttle poor man's VPN service
            systemd.services.sshuttle = {
              description = "the poor man's VPN";
              wantedBy = [ "multi-user.target" ]; # starts after login
              after = [ "network-online.target" ];
              serviceConfig = {
                Restart = "on-failure";
                ExecStartPre = "${pkgs.coreutils-full}/bin/sleep 1";
                ExecStart =
                  "${pkgs.sshuttle}/bin/sshuttle -x detachmentsoft.top -x detachment-soft.top --latency-buffer-size 65536 --dns -r chenjf@detachmentsoft.top 0/0";
              };
            };

            # add a periodly running command to make sshuttle tunnel active
            systemd.services."check-sshuttle-tunnel" = {
              script = ''
                set -eu
                ${pkgs.curl}/bin/curl https://www.twitter.com
              '';
              serviceConfig = {
                Type = "oneshot";
                User = "chenjf";
              };
            };

            systemd.timers."check-sshuttle-tunnel" = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "15m";
                OnUnitActiveSec = "15m";
                Unit = "check-sshuttle-tunnel.service";
              };
            };
          }
        ];
      };
    };
}
