class EmacsPgtk < Formula
  desc "GNU Emacs with GTK (Wayland/X11), tree-sitter and native compilation"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftpmirror.gnu.org/emacs/emacs-31.1.tar.xz"
  mirror "https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz"
  sha256 "1da5790d9580c81932b5bf700633114468da7b3412d69faa767daebf974f4586"
  license "GPL-3.0-or-later"
  revision 2

  bottle do
    root_url "https://github.com/bigredsponge/homebrew-tap/releases/download/emacs-pgtk-31.1_1"
    sha256 x86_64_linux: "ddfe64ddb05e398775eb56001c14a02ec7bb54af82485be0ab81a93d1b385442"
  end

  depends_on "pkgconf" => :build
  depends_on "texinfo" => :build
  depends_on "binutils"
  depends_on "cairo"
  depends_on "dbus"
  depends_on "dconf"
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "gcc"
  depends_on "gdk-pixbuf"
  depends_on "giflib"
  depends_on "glib"
  depends_on "glibc"
  depends_on "gmp"
  depends_on "gnutls"
  depends_on "gtk+3"
  depends_on "harfbuzz"
  depends_on "jpeg-turbo"
  depends_on "libgccjit"
  depends_on "libpng"
  depends_on "librsvg"
  depends_on "libtiff"
  depends_on "libxml2"
  depends_on :linux
  depends_on "ncurses"
  depends_on "pango"
  depends_on "sqlite"
  depends_on "tree-sitter"
  depends_on "webp"
  depends_on "zlib-ng-compat"

  conflicts_with "emacs", because: "both install `emacs` and `emacsclient` binaries"

  def install
    binutils = formula_opt_prefix("binutils")
    gcc = formula_opt_prefix("gcc")
    glibc = formula_opt_prefix("glibc")
    libgcc = gcc/"lib/gcc/current"

    libgccjit = formula_opt_lib("libgccjit")/"gcc/current"
    ENV.append "LDFLAGS", "-L#{libgccjit} -Wl,-rpath,#{libgccjit}"
    ENV.prepend_path "LIBRARY_PATH", libgccjit
    ENV.prepend_path "CPATH", formula_opt_include("libgccjit")

    # https://www.gnu.org/software/emacs/manual/html_node/elisp/Building-Emacs.html#index-site_002dload_002eel
    (buildpath/"lisp/site-load.el").write <<~ELISP
      (setq native-comp-driver-options
            '("-B#{binutils}/bin/" "-B#{glibc}/lib/" "-B#{libgcc}/gcc/" "-L#{libgcc}"))
      (setq exec-path nil)
    ELISP

    system "./configure", *std_configure_args,
                          "--disable-silent-rules",
                          "--enable-locallisppath=#{HOMEBREW_PREFIX}/share/emacs/site-lisp",
                          "--infodir=#{info}/emacs",
                          "--with-pgtk",
                          "--with-native-compilation=aot",
                          "--with-tree-sitter",
                          "--with-modules",
                          "--with-dbus",
                          "--without-selinux"

    system "make", "install"

    rm share/"glib-2.0/schemas/gschemas.compiled"
    rm share/"emacs/site-lisp/subdirs.el"

    # https://gcc.gnu.org/onlinedocs/gcc/Directory-Options.html#index-B
    toolchain = libexec/"toolchain"
    { "cc" => "gcc", "c++" => "g++" }.each do |name, driver|
      (toolchain/name).write <<~SH
        #!/bin/sh
        exec "#{gcc}/bin"/#{driver}-[0-9]* -B"#{binutils}/bin/" -B"#{glibc}/lib/" -idirafter "#{glibc}/include" "$@"
      SH
    end
    chmod 0755, toolchain.children

    rm bin/"emacs"
    (bin/"emacs").write <<~SH
      #!/bin/bash
      export PATH="#{opt_libexec}/toolchain${PATH:+:$PATH}"
      # https://specifications.freedesktop.org/basedir-spec/latest/#variables
      export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:#{HOMEBREW_PREFIX}/share"
      # https://docs.gtk.org/glib/func.set_prgname.html
      exec -a "#{opt_bin}/emacs" "#{bin}/emacs-#{version}" "$@"
    SH
    chmod 0755, bin/"emacs"

    libexec.install bin/"emacsclient"
    (bin/"emacsclient").write_env_script libexec/"emacsclient", PATH: "#{opt_bin}:$PATH"

    inreplace Dir[share/"applications/*.desktop"] do |s|
      s.gsub! "Exec=emacs", "Exec=#{opt_bin}/emacs"
      s.gsub! "Icon=emacs", "Icon=#{opt_share}/icons/hicolor/scalable/apps/emacs.svg"
    end

    inreplace Dir[share/"applications/emacsclient*.desktop"], "#{bin}/emacsclient", "#{opt_bin}/emacsclient"
  end

  service do
    run [opt_bin/"emacs", "--fg-daemon"]
    keep_alive true
  end

  def caveats
    <<~EOS
      To add Emacs to your application menu:
        ln -sf #{opt_share}/applications/emacs.desktop ~/.local/share/applications/
    EOS
  end

  test do
    (testpath/"test.c").write <<~C
      #include <stdio.h>
      int main(void) { return 0; }
    C
    (testpath/"test.cc").write <<~CPP
      #include <string>
      int main() { return std::string().empty() ? 0 : 1; }
    CPP

    (testpath/"test.el").write <<~ELISP
      ;;; -*- lexical-binding: t; -*-
      (require 'cl-lib)
      (cl-assert (featurep 'pgtk))
      (cl-assert (treesit-available-p))
      (cl-assert (= (funcall (native-compile (lambda () 1))) 1))
      (cl-assert (zerop (call-process "cc" nil nil nil "test.c" "-o" "c")))
      (cl-assert (zerop (call-process "c++" nil nil nil "test.cc" "-o" "cc")))
    ELISP

    env = ["env", "-i", "HOME=#{testpath}", "XDG_RUNTIME_DIR=#{testpath}"]
    system(*env, bin/"emacs", "--batch", "--load", "test.el")
    system "./c"
    system "./cc"

    begin
      output = shell_output("#{env.join(" ")} #{bin}/emacsclient --quiet --alternate-editor= " \
                            "--socket-name=test --eval '(+ 1 1)'")
      assert_equal "2", output.lines.last.strip
    ensure
      quiet_system(*env, bin/"emacsclient", "--socket-name=test", "--eval", "(kill-emacs)")
    end
  end
end
