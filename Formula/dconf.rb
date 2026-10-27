class Dconf < Formula
  desc "GSettings backend that lets Homebrew's GLib read GNOME desktop settings"
  homepage "https://wiki.gnome.org/Projects/dconf"
  url "https://download.gnome.org/sources/dconf/51/dconf-51.0.tar.xz"
  sha256 "e65c1b7867f836faad9f9ee04acf5c5a6cae2bbc784833fe093207e0cb590248"
  license "LGPL-2.1-or-later"

  bottle do
    root_url "https://github.com/bigredsponge/homebrew-tap/releases/download/dconf-51.0"
    sha256 cellar: :any, x86_64_linux: "860b049b38fe77d3c3743da280b1887d024d095f66394ec0d028164feade26a2"
  end

  # Homebrew/core has no dconf. Without its GIO module, Homebrew's GLib falls back to an
  # in-memory backend and GTK apps ignore desktop settings such as dark mode.
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "glib"
  depends_on :linux

  def install
    # gvdb is a small library bundled in the tarball, not packaged by Homebrew
    system "meson", "setup", "build", "--force-fallback-for=gvdb",
                                      "-Dbash_completion=false", "-Dman=false", "-Dvapi=false",
                                      *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
    # Shared with other formulae's GIO modules, so don't link a cache that lists only ours
    rm lib/"gio/modules/giomodule.cache"
  end

  test do
    assert_path_exists lib/"gio/modules/libdconfsettings.so"
    system bin/"dconf", "help"
  end
end
