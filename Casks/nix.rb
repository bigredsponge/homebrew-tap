cask "nix" do
  arch arm: "aarch64", intel: "x86_64"

  version "2.34.9,20261102.1"
  sha256 arm64_linux:  "dfc60f0128f2fe1c6278b8b34d32e066510e0bb695e71d4148d1d4cb460f32c9",
         x86_64_linux: "be75c42b733284f26d8f5a5e956a6fe16efe7d46606f211cabd95dbaaad6259b"

  url "https://github.com/bigredsponge/nix/releases/download/#{version.csv.first}-#{version.csv.second}/nix-#{version.csv.first}-#{arch}-linux.tar.gz"
  name "Nix"
  desc "Statically linked build of the Nix package manager"
  homepage "https://github.com/bigredsponge/nix"

  livecheck do
    url :homepage
    regex(/^v?(\d+(?:\.\d+)+)-(\d+(?:\.\d+)+)$/i)
    strategy :github_latest do |json, regex|
      match = json["tag_name"]&.match(regex)
      next if match.blank?

      "#{match[1]},#{match[2]}"
    end
  end

  depends_on :linux

  binary "bin/nix"
  binary "bin/nix-build"
  binary "bin/nix-channel"
  binary "bin/nix-collect-garbage"
  binary "bin/nix-copy-closure"
  binary "bin/nix-daemon"
  binary "bin/nix-env"
  binary "bin/nix-hash"
  binary "bin/nix-instantiate"
  binary "bin/nix-prefetch-url"
  binary "bin/nix-shell"
  binary "bin/nix-store"
  manpage "share/man/man1/nix.1.gz"
  manpage "share/man/man1/nix-build.1.gz"
  manpage "share/man/man1/nix-channel.1.gz"
  manpage "share/man/man1/nix-collect-garbage.1.gz"
  manpage "share/man/man1/nix-copy-closure.1.gz"
  manpage "share/man/man1/nix-env.1.gz"
  manpage "share/man/man1/nix-hash.1.gz"
  manpage "share/man/man1/nix-instantiate.1.gz"
  manpage "share/man/man1/nix-prefetch-url.1.gz"
  manpage "share/man/man1/nix-shell.1.gz"
  manpage "share/man/man1/nix-store.1.gz"
  manpage "share/man/man5/nix.conf.5.gz"
  manpage "share/man/man5/nix-profiles.5.gz"
  manpage "share/man/man8/nix-daemon.8.gz"
  bash_completion "share/bash-completion/completions/nix"
  zsh_completion "share/zsh/site-functions/_nix"
  fish_completion "share/fish/vendor_completions.d/nix.fish"
end
