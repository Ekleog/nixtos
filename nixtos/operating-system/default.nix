{ pkgs, top }:
{
  name ? top.version.name,
  kernel ? pkgs.linuxPackages.kernel,
  initrd-modules ? [],
  block-devices,
  filesystems,
  packages,
  services ? {},
}:

assert !(services ? "kernel");
assert !(services ? "activation-scripts");
# TODO(high): Add de-activation scripts
# The idea is to be able to delete state directories that are no longer needed.
# So the de-activation scripts would be run and passed as arguments the new
# config, so that they can remove things no longer wanted
# NOTE: this MUST NOT delete any user data, ONLY things that can be re-generated
# from the configuration, should a roll-back occur
# Maybe it would make sense to warn the user about state directories used by no
# service too?

let
  solved-services = top.lib.solve-services services;

  assertion-extenders =
    solved-services.extenders-for-assert-type "assertions" "assertion-failure";
  assert-assertions =
    if assertion-extenders == [] then {}
    else throw ''
      Assertions failed:

      ${builtins.concatStringsSep "\n" (
        builtins.map (a:
          " * In service '${a.meta.source}':\n   " +
          builtins.replaceStrings ["\n"] ["\n   "] a.message
        ) assertion-extenders
      )}
    '';

  kernel-extenders = solved-services.extenders-for-assert-type "kernel" "init";
  init-command = assert builtins.length kernel-extenders == 1;
                 (builtins.head kernel-extenders).command;

  activation-extenders =
    solved-services.extenders-for-assert-type "activation-scripts" "script";
  activation-script = pkgs.writeScript "activation-script" ''
    #!${pkgs.bash}/bin/bash
    PATH=${pkgs.coreutils}/bin

    ${builtins.concatStringsSep "\n" (map (e: e.script) activation-extenders)}
  '';

  initrd = top.lib.make-initrd {
    inherit kernel;

    modules = pkgs.lib.unique (
      initrd-modules ++
      pkgs.lib.flatten (pkgs.lib.mapAttrsToList (device: device-type:
        device-type.extra-modules
      ) block-devices) ++
      pkgs.lib.flatten (pkgs.lib.mapAttrsToList (fs-name: fs-type:
        fs-type.extra-modules
      ) filesystems)
    );

    inherit block-devices filesystems;
  };

  modules = pkgs.aggregateModules [ kernel ];

  system-packages = pkgs.buildEnv {
    name = "system-packages";
    paths = packages;
    ignoreCollisions = true;
  };

  complete-system = pkgs.stdenvNoCC.mkDerivation {
    inherit name;

    buildCommand = ''
      mkdir $out

      ln -s ${kernel}/bzImage $out/kernel
      ln -s ${initrd}/initrd $out/initrd
      ln -s ${modules} $out/kernel-modules
      ln -s ${system-packages} $out/sw

      cat > $out/init <<EOF
      #!${pkgs.bash}/bin/bash
      PATH=${pkgs.coreutils}/bin:${pkgs.utillinux}/bin

      echo "Mounting filesystems"
      mkdir /dev /proc /sys
      mount -t devtmpfs none /dev
      mount -t proc none /proc
      mount -t sysfs none /sys
      ${(top.lib.solve-filesystems filesystems).mount-all "/"}

      # TODO(low): allow configuring what is /bin/sh?
      echo "Setting up basic filesystem"
      mkdir -p /bin /home /root /run /tmp /var/log /var/run
      ln -s ${pkgs.bash}/bin/bash /bin/sh

      echo "Adding /run/{booted,current}-system symlinks"
      ln -s $out /run/booted-system
      ln -s $out /run/current-system

      # TODO: move to an activation script
      echo "Allowing module autoloading"
      echo "${pkgs.kmod}/bin/modprobe" > /proc/sys/kernel/modprobe

      ${activation-script}

      exec ${init-command}
      EOF
      chmod +x $out/init
    '';

    passthru = {
      inherit solved-services;
    };
  };
in
  builtins.seq assert-assertions complete-system
