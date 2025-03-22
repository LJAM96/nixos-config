{ config, pkgs, ... }:

let
  # Import the nix-software-center from GitHub repository
  nix-software-center = import (pkgs.fetchFromGitHub {
    owner = "snowfallorg";
    repo = "nix-software-center";
    rev = "0.1.2";
    sha256 = "xiqF1mP8wFubdsAQ1BmfjzCgOD3YZf7EGWl9i69FTls=";
  }) {};
in
{
  # -------------------------------------------------------------------
  # Systemd Service for Local Data Manager (LDM)
  # -------------------------------------------------------------------
  systemd.services.local-data-manager = {
    enable = true;  # Enable the Local Data Manager service
    description = "Local Data Manager";  # Service description
    after = [ "local-fs-pre.target" ];  # Ensure LDM starts after filesystem is mounted
    serviceConfig = {
      Type = "forking";  # Service forks into the background
      User = "root";  # Run as root user
      ExecStart = "/run/current-system/sw/bin/ldmtool create all";  # Command to start LDM
      Restart = "on-failure";  # Restart service on failure
      Environment = "PATH=/run/current-system/sw/bin:/usr/bin:/bin";  # Set PATH for environment
    };
    wantedBy = [ "multi-user.target" ];  # Enable service at multi-user target (default system startup)
  };
  
  # -------------------------------------------------------------------
  # Mount drives within User directory
  # -------------------------------------------------------------------
  fileSystems."/home/luke/mnt/Nostromo" = {
    device = "LABEL=Nostromo";
    fsType = "auto";
    options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" ];
  };

  fileSystems."/home/luke/mnt/Backup" = {
    device = "LABEL=Backup";
    fsType = "auto";
    options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" ];
  };

   fileSystems."/home/luke/mnt/Windows" = {
    device = "LABEL=Windows";
    fsType = "ntfs3";
    options = [ "nosuid" "nodev" "nofail" "x-gvfs-show" ];
  };

  # -------------------------------------------------------------------
  # Import Hardware Configuration
  # -------------------------------------------------------------------
  imports = [ ./hardware-configuration.nix ];

  # -------------------------------------------------------------------
  # Bootloader Configuration (systemd-boot for UEFI systems)
  # -------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];

  # -------------------------------------------------------------------
  # LUKS Encryption for the Boot Device
  # -------------------------------------------------------------------
  boot.initrd.luks.devices."luks-fd9fcc23-8a95-4443-aa71-fee30a3ca3e9".device = "/dev/disk/by-uuid/fd9fcc23-8a95-4443-aa71-fee30a3ca3e9";
 
    # -------------------------------------------------------------------
  # Networking Configuration
  # -------------------------------------------------------------------
  networking.hostName = "desktop-nixos";  # Set system hostname
  networking.networkmanager.enable = true;  # Enable NetworkManager for easy network management

  # -------------------------------------------------------------------
  # Timezone and Locale Configuration
  # -------------------------------------------------------------------
  time.timeZone = "Europe/London";  # Set timezone
  i18n.defaultLocale = "en_GB.UTF-8";  # Set default locale
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";  # Set locale settings for various categories
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # -------------------------------------------------------------------
  # Enable Graphical Environment with GNOME
  # -------------------------------------------------------------------
  services.xserver.enable = true;  # Enable X11 (graphical server)
  services.xserver.displayManager.gdm.enable = true;  # Enable GNOME Display Manager (GDM)
  services.xserver.displayManager.gdm.wayland = true;  # Enable Wayland
  services.xserver.desktopManager.gnome.enable = true;  # Enable GNOME desktop environment
  services.xserver.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.mutter ];
  services.xserver.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer']
  '';
  services.xserver.xkb = {
    layout = "gb";  # Set keyboard layout to UK
    variant = "";  # Default keyboard variant (no variant)
  };
  console.keyMap = "uk";  # Set console keymap to UK English

  # -------------------------------------------------------------------
  # Enable Printing with CUPS (Common UNIX Printing System)
  # -------------------------------------------------------------------
  services.printing.enable = true;

  # -------------------------------------------------------------------
  # Audio Configuration with PipeWire
  # -------------------------------------------------------------------
  hardware.pulseaudio.enable = false;  # Disable PulseAudio (use PipeWire instead)
  security.rtkit.enable = true;  # Enable real-time scheduling for low-latency audio
  services.pipewire = {
    enable = true;  # Enable PipeWire sound server
    alsa.enable = true;  # Enable ALSA (Advanced Linux Sound Architecture) support
    alsa.support32Bit = true;  # Support for 32-bit ALSA apps
    pulse.enable = true;  # Enable PulseAudio compatibility in PipeWire
  };

  # -------------------------------------------------------------------
  # Define User "luke" with Custom Groups and Packages
  # -------------------------------------------------------------------
  users.users.luke = {
    isNormalUser = true;  # Regular user (non-root)
    description = "Luke";  # User description
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];  # Groups for network management and sudo access
    packages = with pkgs; [
      # Add user-specific packages here
    ];
  };

  # -------------------------------------------------------------------
  # Nix Garbage Collection Settings
  # -------------------------------------------------------------------
  nix = {
    gc = {
      automatic = true;  # Enable automatic garbage collection
      options = "--max-freed 1G --delete-older-than 7d";  # Clean up old packages and free space
    };
  };

  # -------------------------------------------------------------------
  # Enable Experimental Nix Features (e.g., Flakes and nix-command)
  # -------------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # -------------------------------------------------------------------
  # NVIDIA Graphics Configuration
  # -------------------------------------------------------------------
  hardware.graphics.enable = true;  # Enable graphics hardware
  services.xserver.videoDrivers = ["nvidia"];  # Use NVIDIA proprietary drivers
  hardware.nvidia = {
    modesetting.enable = true;  # Enable modesetting for NVIDIA
    powerManagement.enable = false;  # Disable power management for NVIDIA GPU
    powerManagement.finegrained = false;  # Disable fine-grained power management
    open = false;  # Disable the open-source Nouveau driver
    nvidiaSettings = true;  # Enable NVIDIA settings control
    package = config.boot.kernelPackages.nvidiaPackages.stable;  # Use stable NVIDIA driver package
  };

  # -------------------------------------------------------------------
  # Allow Unfree Packages (e.g., proprietary drivers)
  # -------------------------------------------------------------------
  nixpkgs.config.allowUnfreePredicate = pkg: true;
  
  # -------------------------------------------------------------------
  # Enable Flatpak Package Management
  # -------------------------------------------------------------------
  services.flatpak.enable = true;

  # -------------------------------------------------------------------
  # List Installed System Packages (Available system-wide)
  # -------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    nix-software-center
    git
    wget
    wine
    wine64
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
    gnomeExtensions.desktop-icons-ng-ding
    gnome-disk-utility
    gnome-extension-manager
    gnome-text-editor
    gnome-software    
    nautilus
    protonplus
    protontricks
    winetricks
    refine
    adw-gtk3
    openrgb-with-all-plugins
    gearlever
    dolphin-emu
    pcsx2
    rpcs3
    fragments
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
    geary
    vscode
    distrobox
    boxbuddy
    mangohud
    menulibre
    gnome-photos
    gnomecast
    shotwell
    gnomeExtensions.gtk4-desktop-icons-ng-ding
    virt-manager
  ];

  # -------------------------------------------------------------------
  # Steam Settings (Gaming Setup)
  # -------------------------------------------------------------------
  programs.steam = {
    enable = true;  # Enable Steam
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;  # Open firewall ports for Steam Remote Play
    dedicatedServer.openFirewall = true;  # Open firewall ports for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true;
  };

  # -------------------------------------------------------------------
  # GRUB Bootloader Configuration
  # -------------------------------------------------------------------
  boot.loader.grub.configurationLimit = 4;  # Limit the number of GRUB configurations
  nix.optimise.automatic = true;  # Enable automatic Nix store optimization
  nix.optimise.dates = [ "03:00" ];  # Schedule optimization at 3 AM
  
  # -------------------------------------------------------------------
  # Disable GNOME Core Utilities (Optional)
  # -------------------------------------------------------------------
  services.gnome.core-utilities.enable = false;

  # -------------------------------------------------------------------
  # Enable Docker
  # -------------------------------------------------------------------
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";  
  };
  boot.kernelModules = [ "btrfs" ];
  
  # -------------------------------------------------------------------
  # Tailscale Service
  # -------------------------------------------------------------------
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-routes=192.168.31.0/24" "--advertise-exit-node" ];
  };
  
  # -------------------------------------------------------------------
  # Enable Libvirt
  # -------------------------------------------------------------------
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["luke"];
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [(pkgs.OVMF.override {
          secureBoot = true;
          tpmSupport = true;
        }).fd];
      };
    };
  };
  virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];

  # -------------------------------------------------------------------
  # Enable OpenSSH for Remote Access
  # -------------------------------------------------------------------
  services.openssh.enable = true;  # Enable OpenSSH server for remote login

  # -------------------------------------------------------------------
  # Specify NixOS Version
  # -------------------------------------------------------------------
  system.stateVersion = "24.11";  # The system version, should match your NixOS version
}
