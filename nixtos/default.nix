# TODO(high): Add the equivalent of nixos-rebuild

{ pkgs, hooks ? {} }:

# TODO(low): Cleanup this list by moving things to their right place
let
  top = pkgs.lib.recursiveUpdate {
    block-device = import ./block-device { inherit pkgs top; };
    bootloader = import ./bootloader { inherit pkgs top; };
    bootloaders = import ./bootloaders { inherit pkgs top; };
    build-vm = import ./build-vm { inherit pkgs top; };
    core-system = import ./core-system { inherit pkgs top; };
    files = import ./files { inherit pkgs top; };
    filesystem = import ./filesystem { inherit pkgs top; };
    groups = import ./groups { inherit pkgs top; };
    init = import ./init { inherit pkgs top; };
    lib = import ./lib { inherit pkgs top; };
    operating-system = import ./operating-system { inherit pkgs top; };
    pam = import ./pam { inherit pkgs top; };
    tty = import ./tty { inherit pkgs top; };
    udev = import ./udev { inherit pkgs top; };
    users = import ./users { inherit pkgs top; };
    version = import ./version { inherit pkgs top; };
    vm-drive = import ./vm-drive { inherit pkgs top; };
  } hooks;
in
  top
