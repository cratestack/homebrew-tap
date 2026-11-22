class CorntchapCli < Formula
  desc "Command-line board and relay for the corntchap agent coordination server"
  homepage "https://github.com/cratestack/corntchap"
  license "MIT"

  # The version is read from the URLs (an explicit `version` would be redundant: brew audit rejects it).
  # scripts/render-formula.sh rewrites this file from scripts/formula.rb.tpl; do not edit it by hand.
  on_macos do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-darwin-arm64.tar.gz"
      sha256 "325afdd905faaf9cbc529031ee9bb381d9ea18ac611cabe61958e9a4723e8e1b"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-darwin-x86_64.tar.gz"
      sha256 "aaef07f1a11a2835c726c4a5b557fbe9d7f9ae880ccd46b5cc546123066c28fe"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-linux-aarch64.tar.gz"
      sha256 "a123d831a7898cff7c914c31d20e87ae3723157dd34dd5f719ab2b174647baa9"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.1.0/corntchap-cli-linux-x86_64.tar.gz"
      sha256 "40b3869dfbd8c41b1b3e4f8a9c5d01769575bbe7385af028c69410ee5ea0bce6"
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
