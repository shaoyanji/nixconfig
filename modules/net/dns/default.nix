# DNS domain: the role-based resolver stack (failover) and the shared tailnet
# resolver address. Two sub-options, not one flag — delphi binds the address
# without running the stack, and frieren runs the stack whether or not a host
# advertises the address.
{...}: {
  imports = [
    ./failover.nix
    ./tailnet-address.nix
  ];
}
