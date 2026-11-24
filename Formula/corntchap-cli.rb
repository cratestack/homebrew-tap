class CorntchapCli < Formula
  desc "Command-line board and relay for the corntchap agent coordination server"
  homepage "https://github.com/cratestack/corntchap"
  license "MIT"

  # The version is read from the URLs (an explicit `version` would be redundant: brew audit rejects it).
  # scripts/render-formula.sh rewrites this file from scripts/formula.rb.tpl; do not edit it by hand.
  on_macos do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.1/corntchap-cli-darwin-arm64.tar.gz"
      sha256 "03d9a0bcab0af6e925d9431121b726d974b506eb30a549cedf8760ff5cd388b7"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.1/corntchap-cli-darwin-x86_64.tar.gz"
      sha256 "551dbfbf850a16de7b6558ae8ac9d9149af6c34d73496ef673547040b152c5f2"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.1/corntchap-cli-linux-aarch64.tar.gz"
      sha256 "a7c260d6e2d916bc116fb3052804187399b5e12dc6f74d279af65739f50ef68b"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.1/corntchap-cli-linux-x86_64.tar.gz"
      sha256 "df11a1c282ea2eade6c5bcd8fa5b8c2a391d129b0bdbb99d07ac42603c87f93f"
    end
  end

  def install
    # the tarball holds one file, corntchap-cli-<platform>
    bin.install Dir["corntchap-cli-*"].first => "corntchap-cli"
    # bash, zsh and fish completions from `corntchap-cli completions <shell>` (corntchap >= 0.2.0)
    generate_completions_from_executable(bin/"corntchap-cli", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/corntchap-cli --version")
    assert_match "#compdef corntchap-cli", shell_output("#{bin}/corntchap-cli completions zsh")
  end
end
