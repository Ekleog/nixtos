{ pkgs, top }:

{
  eudev = import ./eudev { inherit pkgs top; };
}
