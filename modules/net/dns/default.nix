# DNS domain: the role-based resolver stack (failover) and the shared tailnet
# resolver address — two sub-options, not one flag, because delphi binds the
# address without running the stack and frieren runs the stack regardless.
{...}: {
  imports = [
    ./failover.nix
    ./tailnet-address.nix
  ];
}
