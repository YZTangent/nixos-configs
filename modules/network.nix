{ ... }:

{
  # networking.hostName is set per-host in hosts/<hostname>.nix
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  # Local caching resolver + DoT to public resolvers, bypassing the router's
  # rate-limited DNS forwarder. See docs/adr/2026-07-15-bypass-router-dns.md
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = true;
      DNSSEC = "allow-downgrade";
      Domains = "~."; # route all lookups to global DNS, ignore router's link DNS
    };
  };

  networking.nameservers = [
    "1.1.1.1#cloudflare-dns.com"
    "1.0.0.1#cloudflare-dns.com"
    "9.9.9.9#dns.quad9.net"
  ];

  networking.firewall.allowedTCPPorts = [ 1883 ];
}
