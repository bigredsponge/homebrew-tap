class EmacsPgtk < Formula
  desc "GNU Emacs with GTK (Wayland/X11), tree-sitter and native compilation"
  homepage "https://www.gnu.org/software/emacs/"
  url "https://ftpmirror.gnu.org/emacs/emacs-31.1.tar.xz"
  mirror "https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz"
  sha256 "1da5790d9580c81932b5bf700633114468da7b3412d69faa767daebf974f4586"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://github.com/bigredsponge/homebrew-tap/releases/download/emacs-pgtk-31.1"
    sha256 x86_64_linux: "af4c0ac285e40d84c68ef8d61bf7013cab9bdb9abd43a5f4b4f22155b1582152"
  end

  depends_on "pkgconf" => :build
  depends_on "texinfo" => :build
  depends_on "binutils"
  depends_on "cairo"
  depends_on "dbus"
  depends_on "fontconfig"
  depends_on "freetype"
  depends_on "gcc"
  depends_on "gdk-pixbuf"
  depends_on "giflib"
  depends_on "glib"
  depends_on "glibc"
  depends_on "gmp"
  depends_on "gnutls"
  depends_on "gtk3-nomesa" # core's gtk+3 would add Mesa and LLVM, which Emacs never uses
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
    glibc = formula_opt_prefix("glibc")
    gcc = formula_opt_prefix("gcc")
    libgcc = gcc/"lib/gcc/current"

    # libgccjit ships no pkg-config file, so point the build at it by hand
    libgccjit = formula_opt_lib("libgccjit")/"gcc/current"
    ENV.append "LDFLAGS", "-L#{libgccjit} -Wl,-rpath,#{libgccjit}"
    ENV.prepend_path "LIBRARY_PATH", libgccjit
    ENV.prepend_path "CPATH", formula_opt_include("libgccjit")

    site_load = buildpath/"lisp/site-load.el"

    # Hosts may have no assembler, linker or C runtime files
    site_load.write <<~ELISP
      (setq native-comp-driver-options
            '("-B#{binutils}/bin/" "-B#{glibc}/lib/" "-B#{libgcc}/gcc/" "-L#{libgcc}"))
    ELISP

    # Keep the build-time PATH out of the dump so that the bottle is relocatable
    site_load.append_lines "(setq exec-path nil)"

    site_lisp = HOMEBREW_PREFIX/"share/emacs/site-lisp"
    versioned_site_lisp = share/"emacs/#{version}/site-lisp"

    system "./configure", *std_configure_args,
                          "--disable-silent-rules",
                          "--enable-locallisppath=#{versioned_site_lisp}:#{site_lisp}",
                          "--infodir=#{info}/emacs",
                          "--with-pgtk",
                          "--with-native-compilation=aot",
                          "--with-tree-sitter",
                          "--with-modules",
                          "--with-xml2",
                          "--without-selinux"

    system "make", "install"

    # Homebrew builds this cache itself in its prefix, so ours would conflict when linked
    rm share/"glib-2.0/schemas/gschemas.compiled"

    # Use our versioned site-lisp to expand shared packages before any init files run
    rm share/"emacs/site-lisp/subdirs.el"
    (versioned_site_lisp/"subdirs.el").append_lines <<~ELISP
      (when (and (member "#{site_lisp}" load-path)
                 (file-directory-p "#{site_lisp}"))
        (let ((default-directory "#{site_lisp}/"))
          (normal-top-level-add-subdirs-to-load-path)))
    ELISP

    # Hosts may have no C compiler, which tree-sitter grammars and modules need. Homebrew's gcc
    # looks for its runtime libraries in the prefix, where they are missing if linking gcc failed.
    toolchain = libexec/"toolchain"
    toolchain.install_symlink binutils/"bin/as", binutils/"bin/ld"

    (toolchain/"cc").write <<~SH
      #!/bin/sh
      exec "#{gcc}/bin"/gcc-[0-9]* -B"#{glibc}/lib/" -L"#{libgcc}" \\
        -idirafter "#{glibc}/include" -idirafter "#{HOMEBREW_PREFIX}/include" \\
        -Wl,--dynamic-linker="#{HOMEBREW_PREFIX}/lib/ld.so" -Wl,-rpath,"#{libgcc}" "$@"
    SH

    (toolchain/"c++").write <<~SH
      #!/bin/sh
      exec "#{gcc}/bin"/g++-[0-9]* -B"#{glibc}/lib/" -L"#{libgcc}" \\
        -idirafter "#{glibc}/include" -idirafter "#{HOMEBREW_PREFIX}/include" \\
        -Wl,--dynamic-linker="#{HOMEBREW_PREFIX}/lib/ld.so" -Wl,-rpath,"#{libgcc}" "$@"
    SH

    chmod 0755, [toolchain/"cc", toolchain/"c++"]

    data_dirs = "#{HOMEBREW_PREFIX}/share:#{formula_opt_prefix("gtk3-nomesa")}/share"

    # Wayland desktops match windows to emacs.desktop by program name. The name is absolute
    # because Emacs finds its own directory from it, and Homebrew is not always in PATH.
    rm bin/"emacs"
    (bin/"emacs").write <<~SH
      #!/bin/bash
      export PATH="#{toolchain}:$PATH"
      # GTK crashes opening a file dialog on hosts without its schemas, icon theme and
      # MIME database, which Homebrew provides in its prefix and, for gtk3-nomesa, in its keg
      export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:#{data_dirs}"
      exec -a "#{opt_bin}/emacs" "#{bin}/emacs-#{version}" "$@"
    SH
    chmod 0755, bin/"emacs"

    # An empty --alternate-editor starts a daemon by looking for emacs in PATH
    libexec.install bin/"emacsclient"
    (bin/"emacsclient").write_env_script libexec/"emacsclient", PATH: "#{opt_bin}:$PATH"

    # Desktop sessions don't have Homebrew in PATH
    inreplace Dir[share/"applications/*.desktop"] do |s|
      s.gsub! "Exec=emacs", "Exec=#{opt_bin}/emacs"
      s.gsub! "Icon=emacs", "Icon=#{opt_share}/icons/hicolor/scalable/apps/emacs.svg"
    end
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
    (testpath/"hello.c").write <<~C
      #include <stdio.h>
      int main(void) { return puts("hi") < 0; }
    C

    (testpath/"test.el").write <<~ELISP
      (princ (treesit-available-p))
      (princ (funcall (native-compile (lambda () 42))))
      (princ (call-process "cc" nil nil nil "hello.c"))
    ELISP

    # A bare environment proves that no host toolchain is needed
    assert_equal "t420", shell_output("env -i HOME=#{testpath} #{bin}/emacs --batch --load test.el")

    assert_equal "hi\n", shell_output("./a.out")

    begin
      # The client must also find Emacs when starting a daemon without Homebrew in PATH
      output = shell_output("env -i HOME=#{testpath} #{bin}/emacsclient --quiet --alternate-editor= " \
                            "--socket-name=emacs-pgtk-test --eval '(+ 20 22)'")
      assert_equal "42", output.lines.last.strip
    ensure
      shell_output("env -i HOME=#{testpath} #{bin}/emacsclient --socket-name=emacs-pgtk-test --eval '(kill-emacs)'")
    end
  end
end
