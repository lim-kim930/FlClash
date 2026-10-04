package main

import (
	"fmt"
	"net/netip"
	"strings"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"golang.org/x/net/idna"
)

type RuleLookupParams struct {
	Target  string `json:"target"`
	Port    int    `json:"port"`
	Network string `json:"network"`
}

type RuleLookupResult struct {
	Target        string   `json:"target"`
	Port          int      `json:"port"`
	Network       string   `json:"network"`
	Mode          string   `json:"mode"`
	Rule          string   `json:"rule"`
	RulePayload   string   `json:"rule-payload"`
	Proxy         string   `json:"proxy"`
	Chains        []string `json:"chains"`
	DestinationIP string   `json:"destination-ip"`
}

func ruleLookupMetadata(params *RuleLookupParams) (*C.Metadata, error) {
	if params.Port < 1 || params.Port > 65535 {
		return nil, fmt.Errorf("port must be between 1 and 65535")
	}
	metadata := &C.Metadata{Type: C.INNER, DNSMode: C.DNSNormal, DstPort: uint16(params.Port)}
	switch params.Network {
	case "tcp":
		metadata.NetWork = C.TCP
	case "udp":
		metadata.NetWork = C.UDP
	default:
		return nil, fmt.Errorf("network must be tcp or udp")
	}
	target := strings.TrimSpace(params.Target)
	if ip, err := netip.ParseAddr(target); err == nil {
		if ip.Zone() != "" {
			return nil, fmt.Errorf("scoped IP addresses are not supported")
		}
		metadata.DstIP = ip.Unmap()
		return metadata, nil
	}
	host, err := idna.Lookup.ToASCII(strings.TrimSuffix(strings.ToLower(target), "."))
	if err != nil || len(host) == 0 || len(host) > 253 || strings.ContainsAny(host, ":/\\?#@[]") {
		return nil, fmt.Errorf("target must be a domain or IP address")
	}
	for _, label := range strings.Split(host, ".") {
		if len(label) == 0 || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return nil, fmt.Errorf("invalid domain label")
		}
		for _, char := range label {
			if !(char >= 'a' && char <= 'z' || char >= '0' && char <= '9' || char == '-') {
				return nil, fmt.Errorf("invalid domain label")
			}
		}
	}
	if strings.Trim(host, "0123456789.") == "" {
		return nil, fmt.Errorf("invalid IP address")
	}
	metadata.Host = host
	return metadata, nil
}

func handleRuleLookup(metadata *C.Metadata, target string) (*RuleLookupResult, error) {
	configMu.Lock()
	defer configMu.Unlock()
	selectMu.Lock()
	defer selectMu.Unlock()

	proxy, rule, err := tunnel.MatchRoute(metadata)
	if err != nil {
		return nil, err
	}
	if proxy == nil {
		return nil, fmt.Errorf("no routing policy available")
	}
	result := &RuleLookupResult{
		Target: strings.TrimSpace(target), Port: int(metadata.DstPort),
		Network: metadata.NetWork.String(), Mode: tunnel.Mode().String(),
		Proxy: proxy.Name(), Chains: []string{},
	}
	if rule != nil {
		result.Rule = rule.RuleType().String()
		result.RulePayload = rule.Payload()
	}
	if metadata.DstIP.IsValid() {
		result.DestinationIP = metadata.DstIP.String()
	}
	seen := map[string]bool{}
	for adapter := C.ProxyAdapter(proxy); adapter != nil; adapter = adapter.Unwrap(metadata, false) {
		if seen[adapter.Name()] {
			return nil, fmt.Errorf("proxy group cycle at %s", adapter.Name())
		}
		seen[adapter.Name()] = true
		result.Chains = append(result.Chains, adapter.Name())
	}
	return result, nil
}
