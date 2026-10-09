package main

import (
	"slices"
	"testing"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/rules"
	"github.com/metacubex/mihomo/tunnel"
)

func TestRuleLookupMetadata(t *testing.T) {
	for _, target := range []string{"Example.COM.", "192.0.2.1", "2001:db8::1", "例子.中国"} {
		metadata, err := ruleLookupMetadata(&RuleLookupParams{Target: target, DestinationPort: 443, Network: "tcp"})
		if err != nil {
			t.Fatalf("%s: %v", target, err)
		}
		if metadata.DstPort != 443 || metadata.NetWork != C.TCP || metadata.Type != C.INNER {
			t.Fatalf("unexpected metadata: %+v", metadata)
		}
		if target == "Example.COM." && metadata.Host != "example.com" {
			t.Fatalf("host = %s", metadata.Host)
		}
	}
	for _, target := range []string{"", "https://example.com", "example.com:443", "999.0.0.1", "a..com", "a b.com", "-a.com", "fe80::1%eth0"} {
		if _, err := ruleLookupMetadata(&RuleLookupParams{Target: target, DestinationPort: 443, Network: "tcp"}); err == nil {
			t.Errorf("accepted invalid target %q", target)
		}
	}
	for _, params := range []RuleLookupParams{
		{Target: "example.com", SourcePort: -1, DestinationPort: 443, Network: "tcp"},
		{Target: "example.com", SourcePort: 65536, DestinationPort: 443, Network: "tcp"},
		{Target: "example.com", DestinationPort: 0, Network: "tcp"},
		{Target: "example.com", DestinationPort: 65536, Network: "tcp"},
		{Target: "example.com", DestinationPort: 443, Network: "http"},
	} {
		if _, err := ruleLookupMetadata(&params); err == nil {
			t.Errorf("accepted invalid parameters %+v", params)
		}
	}
}

func TestRuleLookupSourcePortBounds(t *testing.T) {
	for _, sourcePort := range []int{0, 1, 65535} {
		metadata, err := ruleLookupMetadata(&RuleLookupParams{
			Target: "example.com", SourcePort: sourcePort, DestinationPort: 443, Network: "tcp",
		})
		if err != nil {
			t.Fatal(err)
		}
		if int(metadata.SrcPort) != sourcePort || metadata.DstPort != 443 {
			t.Fatalf("unexpected ports: %+v", metadata)
		}
	}
}

func TestRuleLookupUsesLiveRulesAndMode(t *testing.T) {
	oldRules, oldMode := tunnel.Rules(), tunnel.Mode()
	t.Cleanup(func() {
		tunnel.UpdateRules(oldRules, nil, nil)
		tunnel.SetMode(oldMode)
	})
	withProbeProxies(t, "DIRECT", "GLOBAL", "node-a", "node-b")
	group := selectorGroup(t, "group", "node-a", "node-b")
	proxies := tunnel.Proxies()
	updated := make(map[string]C.Proxy, len(proxies)+1)
	for name, proxy := range proxies {
		updated[name] = proxy
	}
	updated["group"] = group
	tunnel.UpdateProxies(updated, nil)
	domainRule, err := rules.ParseRule("DOMAIN", "example.com", "group", nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	tunnel.UpdateRules([]C.Rule{domainRule}, nil, nil)
	tunnel.SetMode(tunnel.Rule)

	lookup := func(target string) *RuleLookupResult {
		t.Helper()
		metadata, err := ruleLookupMetadata(&RuleLookupParams{Target: target, DestinationPort: 443, Network: "tcp"})
		if err != nil {
			t.Fatal(err)
		}
		result, err := handleRuleLookup(metadata, target)
		if err != nil {
			t.Fatal(err)
		}
		return result
	}
	result := lookup("example.com")
	if result.Proxy != "group" || result.Rule != "Domain" || result.RulePayload != "example.com" || !slices.Equal(result.Chains, []string{"group", "node-a"}) {
		t.Fatalf("unexpected domain route: %+v", result)
	}
	selector, err := selectableGroup("group")
	if err != nil {
		t.Fatal(err)
	}
	if err := selector.Set("node-b"); err != nil {
		t.Fatal(err)
	}
	if result = lookup("example.com"); !slices.Equal(result.Chains, []string{"group", "node-b"}) {
		t.Fatalf("selection was not read live: %+v", result)
	}
	for _, mode := range []tunnel.TunnelMode{tunnel.Direct, tunnel.Global} {
		tunnel.SetMode(mode)
		result = lookup("example.com")
		if result.Mode != mode.String() || result.Rule != "" || result.Proxy == "group" {
			t.Fatalf("mode %s: %+v", mode, result)
		}
	}
	tunnel.SetMode(tunnel.Rule)
	ipRule, err := rules.ParseRule("IP-CIDR", "2001:db8::/32", "node-b", []string{"no-resolve"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	tunnel.UpdateRules([]C.Rule{ipRule}, nil, nil)
	if result = lookup("2001:db8::1"); result.Proxy != "node-b" || result.DestinationIP != "2001:db8::1" {
		t.Fatalf("unexpected IPv6 route: %+v", result)
	}
	if result = lookup("192.0.2.1"); result.Proxy != "DIRECT" || result.Rule != "" {
		t.Fatalf("unexpected default route: %+v", result)
	}
	udpRule, err := rules.ParseRule("NETWORK", "udp", "node-a", nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	portRule, err := rules.ParseRule("DST-PORT", "8443", "node-b", nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	sourcePortRule, err := rules.ParseRule("SRC-PORT", "54321", "node-a", nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	tunnel.UpdateRules([]C.Rule{udpRule, sourcePortRule, portRule}, nil, nil)
	for _, params := range []RuleLookupParams{
		{Target: "192.0.2.1", DestinationPort: 443, Network: "udp"},
		{Target: "192.0.2.1", DestinationPort: 8443, Network: "tcp"},
		{Target: "192.0.2.1", SourcePort: 54321, DestinationPort: 8443, Network: "tcp"},
	} {
		metadata, err := ruleLookupMetadata(&params)
		if err != nil {
			t.Fatal(err)
		}
		result, err := handleRuleLookup(metadata, params.Target)
		if err != nil {
			t.Fatal(err)
		}
		want := "node-a"
		if params.DestinationPort == 8443 && params.SourcePort == 0 {
			want = "node-b"
		}
		if result.Proxy != want {
			t.Fatalf("%+v routed to %s, want %s", params, result.Proxy, want)
		}
		if result.SourcePort != params.SourcePort || result.DestinationPort != params.DestinationPort {
			t.Fatalf("unexpected result ports: %+v", result)
		}
	}
}
