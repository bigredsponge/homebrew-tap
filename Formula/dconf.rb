class Dconf < Formula
  desc "GSettings backend that lets Homebrew's GLib read GNOME desktop settings"
  homepage "https://wiki.gnome.org/Projects/dconf"
  url "https://download.gnome.org/sources/dconf/51/dconf-51.0.tar.xz"
  sha256 "e65c1b7867f836faad9f9ee04acf5c5a6cae2bbc784833fe093207e0cb590248"
  license "LGPL-2.1-or-later"

  bottle do
    root_url "https://github.com/bigredsponge/homebrew-tap/releases/download/dconf-51.0"
    rebuild 1
    sha256 cellar: :any, x86_64_linux: "a82d3668167a99cd03b0b8dee511ce86f0ecce551213c333b2d4dbbd960371e1"
  end

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "glib"
  depends_on :linux

  def install
    # https://mesonbuild.com/Subprojects.html#commandline-options
    system "meson", "setup", "build", "--force-fallback-for=gvdb",
                                      "-Dbash_completion=false", "-Dman=false", "-Dvapi=false",
                                      *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
    rm lib/"gio/modules/giomodule.cache"
  end

  test do
    (testpath/"db.d/test").write <<~INI
      [dconf/test]
      enabled=true
    INI
    system bin/"dconf", "compile", testpath/"db", testpath/"db.d"

    # https://manpages.debian.org/testing/dconf-cli/dconf.7.en.html#PROFILES
    (testpath/"profile").write "file-db:#{testpath}/db\n"

    (testpath/"dconf.test.gschema.xml").write <<~XML
      <schemalist>
        <schema id="dconf.test" path="/dconf/test/">
          <key name="enabled" type="b"><default>false</default></key>
        </schema>
      </schemalist>
    XML

    glib = formula_opt_bin("glib")
    system glib/"glib-compile-schemas", testpath

    output = shell_output("env -i DCONF_PROFILE=#{testpath}/profile GSETTINGS_SCHEMA_DIR=#{testpath} " \
                          "#{glib}/gsettings get dconf.test enabled")
    assert_equal "true\n", output
  end
end
