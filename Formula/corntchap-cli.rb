class CorntchapCli < Formula
  desc "Command-line board and relay for the corntchap agent coordination server"
  homepage "https://github.com/cratestack/corntchap"
  license "MIT"

  # The version is read from the URLs (an explicit `version` would be redundant: brew audit rejects it).
  # scripts/render-formula.sh rewrites this file from scripts/formula.rb.tpl; do not edit it by hand.
  on_macos do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.0/corntchap-cli-darwin-arm64.tar.gz"
      sha256 "655ded26dd73bb959abe3dfa37920208c63d3f0659e363091b95568af0611778"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.0/corntchap-cli-darwin-x86_64.tar.gz"
      sha256 "b50015922a862cd2eec273f6a9e16ad0d83277be85bfeb9f5c8561b16e0a6c5f"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.0/corntchap-cli-linux-aarch64.tar.gz"
      sha256 "b2dd4a87f4cd318b3ae60a5658a45669798371a533b5399a6eb21160e2441ca0"
    end
    on_intel do
      url "https://github.com/cratestack/corntchap/releases/download/v0.2.0/corntchap-cli-linux-x86_64.tar.gz"
      sha256 "8efa3b15c91344b7fe062b5967bf79ba5b893758e2ec25e12f4465835bc04980"
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
