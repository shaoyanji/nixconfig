# The blog as files on the tailnet; the mount is in servicePortal.mounts so the
# origin check and the card cannot disagree. docs/mataroa-console.md
{config, ...}: {
  services.mataroaConsole = {
    enable = true;
    tailnetHost = config.services.servicePortal.tailnetHost;
  };
}
