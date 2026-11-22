class CorntchapCli < Formula
  desc "Command-line board and relay for the corntchap agent coordination server"
  homepage "https://github.com/cratestack/corntchap"
  license "MIT"

  # The version is read from the URLs (an explicit `version` would be redundant: brew audit rejects it).
  # scripts/render-formula.sh rewrites this file from scripts/formula.rb.tpl; do not edit it by hand.
  on_macos do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v@VERSION@/corntchap-cli-darwin-arm64.tar.gz"
      sha256 "@SHA_DARWIN_ARM64@"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v@VERSION@/corntchap-cli-darwin-x86_64.tar.gz"
      sha256 "@SHA_DARWIN_X86_64@"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v@VERSION@/corntchap-cli-linux-aarch64.tar.gz"
      sha256 "@SHA_LINUX_AARCH64@"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v@VERSION@/corntchap-cli-linux-x86_64.tar.gz"
      sha256 "@SHA_LINUX_X86_64@"
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
