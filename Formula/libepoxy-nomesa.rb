class LibepoxyNomesa < Formula
  desc "Library for handling OpenGL function pointer management, without Mesa at runtime"
  homepage "https://github.com/anholt/libepoxy"
  url "https://download.gnome.org/sources/libepoxy/1.5/libepoxy-1.5.10.tar.xz"
  sha256 "072cda4b59dd098bba8c2363a6247299db1fa89411dc221c8b81b8ee8192e623"
  license "MIT"

  livecheck do
    formula "libepoxy"
  end

  bottle do
    root_url "https://github.com/bigredsponge/homebrew-tap/releases/download/libepoxy-nomesa-1.5.10"
    sha256 cellar: :any, x86_64_linux: "e0a62a15d1243372b975f8ad9a94cda3437439537cade3e8c19dcadb444a5bcc"
  end

  # Core's libepoxy depends on freeglut, and so on Mesa and LLVM, although it loads GL
  # at run time and only needs Mesa's headers to compile.
  keg_only "it would conflict with Homebrew's libepoxy"

  depends_on "mesa" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "python@3.14" => :build
  depends_on "libx11"
  depends_on :linux

  def install
    system "meson", "setup", "build", "-Dtests=false", *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <epoxy/gl.h>
      int main(void) { return !epoxy_gl_version; }
    C

    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lepoxy", "-o", "test"
    system "./test"
  end
end
