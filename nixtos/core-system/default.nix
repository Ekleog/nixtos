{ pkgs, top }:

{
  files ? top.files {},
  init ? top.init.runit {},
  users ? top.users.unix {},
  groups ? top.groups.unix {},
  pam ? top.pam {},
  udev ? top.udev.eudev {},
  ttys ? {
    tty1 = top.tty.agetty {};
    tty2 = top.tty.agetty {};
    tty3 = top.tty.agetty {};
    tty4 = top.tty.agetty {};
    tty5 = top.tty.agetty {};
    tty6 = top.tty.agetty {};
  },
}:

services:

# TODO(high): Handle logging (and add a /dev/log device for stuff used to it)

top.lib.disjoint-union (d:
  throw "Passed service names that were already taken by core system: ${toString d}"
) services (
  top.lib.disjoint-union (d:
    throw "Passed tty names that were already taken by core system: ${toString d}"
  ) {
    inherit files init users groups pam udev;
  } (pkgs.lib.mapAttrs (n: v: v n) ttys))
