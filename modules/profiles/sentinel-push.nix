# note p1-sentinel-push: one egress shape per sentinel host. frieren.lan pin: bare tailnet 404s the vhost.
{config, ...}: {
  networking.extraHosts = ''
    100.97.61.65 frieren.lan
  '';

  services.fleetSentinel.push = {
    url = "http://frieren.lan/sentinel/ingest";
    tokenFile = config.sops.secrets."agent-turns-token".path;
  };

  sops.secrets."agent-turns-token" = {};
}
