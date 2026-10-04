class RuleLookupResult {
  const RuleLookupResult({
    required this.target,
    required this.port,
    required this.network,
    required this.mode,
    required this.rule,
    required this.rulePayload,
    required this.proxy,
    required this.chains,
    required this.destinationIp,
  });

  factory RuleLookupResult.fromJson(Map<String, dynamic> json) {
    return RuleLookupResult(
      target: json['target'] as String,
      port: json['port'] as int,
      network: json['network'] as String,
      mode: json['mode'] as String,
      rule: json['rule'] as String,
      rulePayload: json['rule-payload'] as String,
      proxy: json['proxy'] as String,
      chains: List<String>.from(json['chains'] as List),
      destinationIp: json['destination-ip'] as String,
    );
  }

  final String target;
  final int port;
  final String network;
  final String mode;
  final String rule;
  final String rulePayload;
  final String proxy;
  final List<String> chains;
  final String destinationIp;
}
