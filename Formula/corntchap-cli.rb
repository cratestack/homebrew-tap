class CorntchapCli < Formula
  desc "Command-line board and relay for the corntchap agent coordination server"
  homepage "https://github.com/cratestack/corntchap"
  license "MIT"

  # The version is read from the URLs (an explicit `version` would be redundant: brew audit rejects it).
  # scripts/render-formula.sh rewrites this file from scripts/formula.rb.tpl; do not edit it by hand.
  on_macos do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-darwin-arm64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-darwin-x86_64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-linux-aarch64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-linux-x86_64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    # the tarball holds one file, corntchap-cli-<platform>
    bin.install Dir["corntchap-cli-*"].first => "corntchap-cli"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/corntchap-cli --version")
  end
end
