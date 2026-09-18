# Codespaces内の開発時だけ、このCodespaceの転送先を許可します。
# config.hosts.clear のように、すべてのホストを許可する設定にはしません。
if Rails.env.development? && ENV["CODESPACES"] == "true"
  name = ENV.fetch("CODESPACE_NAME", "")
  domain = ENV.fetch("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN", "app.github.dev")
  port = ENV.fetch("PORT", "3000")
  if name.match?(/\A[a-z0-9-]+\z/i) && domain.match?(/\A[a-z0-9.-]+\z/i) &&
     port.match?(/\A\d{1,5}\z/) && (1..65_535).cover?(port.to_i)
    Rails.application.config.hosts << "#{name}-#{port}.#{domain}"
  end
end
