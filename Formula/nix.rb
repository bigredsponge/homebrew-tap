class Nix < Formula
  desc "Statically linked build of the Nix package manager"
  homepage "https://github.com/bigredsponge/nix"
  url "https://github.com/bigredsponge/nix/releases/download/2.34.9/nix-2.34.9-x86_64-linux.tar.gz"
  sha256 "973491841fd2c25676310fc1d42c3a287ca1e761a0f5dbffe7d9a59aa246e9bb"
  license "MIT"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  depends_on :linux

  on_linux do
    on_arm do
      url "https://github.com/bigredsponge/nix/releases/download/2.34.9/nix-2.34.9-aarch64-linux.tar.gz"
      sha256 "d4dfa7bdb2afed18c101df63932c7f5bfc1a7b954a4ab746736f40a7b7cf919a"
    end
  end

  def install
    prefix.install "bin", "libexec", "share"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/nix --version")
  end
end
