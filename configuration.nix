{ config, pkgs, ... }:

let
  # Import nix-software-center from GitHub repository
  nix-software-center = import (pkgs.fetchFromGitHub {
    owner = "snowfallorg";
    repo = "nix-software-center";
    rev = "0.1.2";
    sha256 = "xiqF1mP8wFubdsAQ1BmfjzCgOD3YZf7EGWl9i69FTls=";
  }) {};
  
in
{
  # --------------------------- System Settings ---------------------------
  imports = [ ./hardware-configuration.nix ];
  system.stateVersion = "24.11";  # Ensure this matches your NixOS version

  # --------------------------- Boot Configuration ------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];
  boot.loader.grub.configurationLimit = 4;  # Limit stored GRUB configurations
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "03:00" ];  # Schedule optimization at 3 AM

  # Enable LUKS encryption
  boot.initrd.luks.devices."luks-fd9fcc23-8a95-4443-aa71-fee30a3ca3e9".device = "/dev/disk/by-uuid/fd9fcc23-8a95-4443-aa71-fee30a3ca3e9";

  # ------------------------- Networking Configuration ---------------------
  networking.hostName = "desktop-nixos";
  networking.networkmanager.enable = true;
  
  # Enable OpenSSH for remote access
  services.openssh.enable = true;

  # Enable Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-routes=192.168.31.0/24" "--advertise-exit-node" ];
  };

  # --------------------------- Locale Settings ---------------------------
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
  };

  # ------------------------ User & Permissions ---------------------------
  users.users.luke = {
    isNormalUser = true;
    description = "Luke";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
  };

  # --------------------- Graphical & Desktop Settings --------------------
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.mutter ];
  services.xserver.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer']
  '';
  services.xserver.xkb.layout = "gb";
  console.keyMap = "uk";

  # Disable GNOME core utilities (optional)
  services.gnome.core-utilities.enable = false;

  # Enable Flatpak
  services.flatpak.enable = true;

  # ---------------------------- Hardware ------------------------------
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  
  # Enable audio with PipeWire
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ------------------------- Virtualization -----------------------------
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["luke"];
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf.enable = true;
      ovmf.packages = [(pkgs.OVMF.override { secureBoot = true; tpmSupport = true; }).fd];
    };
  };

  # -------------------------- Storage & Mounts -------------------------
  fileSystems = {
    "/home/luke/mnt/Nostromo" = {
      device = "LABEL=Nostromo";
      fsType = "auto";
      options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" ];
    };
    "/home/luke/mnt/Backup" = {
      device = "LABEL=Backup";
      fsType = "auto";
      options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" ];
    };
    "/home/luke/mnt/Windows" = {
      device = "LABEL=Windows";
      fsType = "ntfs3";
      options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" ];
    };
  };

  # ------------------------- Package Management ------------------------
  nixpkgs.config.allowUnfreePredicate = pkg: true;
  environment.systemPackages = with pkgs; [
    nix-software-center
    git
    wget
    wine
    wine64
    winetricks
    protonplus
    protontricks
    bottles
    fluent-icon-theme
    ptyxis
    tailscale
    ldmtool
    gnomeExtensions.arcmenu
    gnomeExtensions.dash-to-dock
    gnomeExtensions.just-perfection
    gnomeExtensions.user-themes
    gnomeExtensions.tailscale-qs
    gnomeExtensions.smart-home
    gnomeExtensions.colosseum
    gnomeExtensions.gtk4-desktop-icons-ng-ding
    gnome-disk-utility
    gnome-extension-manager
    gnome-text-editor
    gnome-software    
    nautilus
    geary
    refine
    fragments
    adw-gtk3
    openrgb-with-all-plugins
    gearlever
    dolphin-emu
    pcsx2
    rpcs3
    adwsteamgtk
    gamescope
    steam-rom-manager
    parabolic
    discord
    tsukimi
    rclone
    impression
    obs-studio
    pika-backup
    varia
    spotify
    mission-center
    vscode
    distrobox
    boxbuddy
    mangohud
    menulibre
    gnome-photos
    gnomecast
    shotwell
    virt-manager
    vlc
    github-desktop
    protonup-qt
  ];

  # ------------------------- Gaming Configuration ----------------------
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  
  # ------------------------- Docker & Services -------------------------
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };
  boot.kernelModules = [ "btrfs" ];

  # Systemd service: Local Data Manager (LDM)
  systemd.services.local-data-manager = {
    enable = true;
    description = "Local Data Manager";
    after = [ "local-fs-pre.target" ];
    serviceConfig = {
      Type = "forking";
      User = "root";
      ExecStart = "/run/current-system/sw/bin/ldmtool create all";
      Restart = "on-failure";
      Environment = "PATH=/run/current-system/sw/bin:/usr/bin:/bin";
    };
    wantedBy = [ "multi-user.target" ];
  };
  
  # ------------------------- User Services ----------------------------
  # Wait for PATH environment to be fully populated before starting xdg-desktop-portal
  systemd.user.services."wait-for-full-path" = {
    description = "wait for systemd units to have full PATH";
    wantedBy = [ "xdg-desktop-portal.service" ];
    before = [ "xdg-desktop-portal.service" ];
    path = with pkgs; [ systemd coreutils gnugrep ];
    script = ''
      ispresent () {
        systemctl --user show-environment | grep -E '^PATH=.*/.nix-profile/bin'
      }
      while ! ispresent; do
        sleep 0.1;
      done
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "60";
    };
  };
}
