# DNS domain: the role-based resolver stack (failover) and the shared tailnet
# resolver address — two sub-options, not one flag, because delphi binds the
# address without running the stack and frieren runs the stack regardless.
{self, ...}: {
  imports = [
    self.modules."net.dns.failover"
    self.modules."net.dns.tailnet-address"
  ];
}
