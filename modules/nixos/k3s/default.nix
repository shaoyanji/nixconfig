{config, ...}: {
  services = {
    k3s = {
      enable = true;
      role = "agent";
      #role = "server"; # Or "agent" for worker only nodes
      tokenFile = "${config.sops.secrets."local/k3s/token".path}";
      serverAddr = "https://k3s.local:6443";
      #serverAddr = "https://thinsandy.cloudforest-kardashev.ts.net:6443";
    };
  };

  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
    2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
    2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  ];

  networking.firewall.allowedUDPPorts = [
    8472 # k3s, flannel: required if using multi-node for inter-node networking
  ];
}
