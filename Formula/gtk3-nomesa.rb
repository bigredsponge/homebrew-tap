class Gtk3Nomesa < Formula
  desc "Toolkit for creating graphical user interfaces, without Mesa at runtime"
  homepage "https://gtk.org/"
  url "https://download.gnome.org/sources/gtk/3.24/gtk-3.24.52.tar.xz"
  sha256 "80931fa472a77b9a164f6740e3c0b444fac6770054632d35a7ff9d679e5e7b9f"
  license "LGPL-2.0-or-later"

  livecheck do
    formula "gtk+3"
  end

  bottle do
    root_url "https://github.com/bigredsponge/homebrew-tap/releases/download/gtk3-nomesa-3.24.52"
    sha256 x86_64_linux: "a1887bf9b57cde90e790b9f76377458dce892e43d5869b8c1bfca895a846f474"
  end

  # Core's gtk+3 is built against core's libepoxy, so using libepoxy-nomesa needs a matching
  # GTK. This one leaves out what Emacs doesn't use (introspection, demos, examples, man pages)
  # and needs Mesa only to compile.
  keg_only "it would conflict with Homebrew's gtk+3"

  depends_on "gettext" => :build
  depends_on "mesa" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "wayland-protocols" => :build
  depends_on "xorgproto" => :build
  depends_on "at-spi2-core"
  depends_on "cairo"
  depends_on "fontconfig"
  depends_on "fribidi"
  depends_on "gdk-pixbuf"
  depends_on "glib"
  depends_on "gsettings-desktop-schemas"
  depends_on "harfbuzz"
  depends_on "hicolor-icon-theme"
  depends_on "iso-codes"
  depends_on "libepoxy-nomesa"
  depends_on "libx11"
  depends_on "libxdamage"
  depends_on "libxext"
  depends_on "libxfixes"
  depends_on "libxi"
  depends_on "libxinerama"
  depends_on "libxkbcommon"
  depends_on "libxrandr"
  depends_on :linux
  depends_on "pango"
  depends_on "wayland"

  def install
    # GTK 3 finds loadable input methods through a cache that nothing generates for a
    # keg-only formula, so compile them into GTK itself instead
    system "meson", "setup", "build", "-Dbuiltin_immodules=all", "-Ddemos=false", "-Dexamples=false",
                                      "-Dintrospection=false", "-Dtests=false", *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_match version.to_s, (lib/"pkgconfig/gtk+-3.0.pc").read
    system bin/"gtk-query-immodules-3.0"
  end
end
