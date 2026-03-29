class Pellucid < Formula
  desc "Native macOS markdown viewer"
  homepage "https://github.com/ehkropf/Pellucid-Markdown-Viewer"
  url "https://github.com/ehkropf/Pellucid-Markdown-Viewer/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "48c8f3495026dc29412b1acf67d165b383f7d86d64f6940db2c1251037497c0e"
  license "GPL-3.0-or-later"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"

    app = prefix/"Pellucid.app/Contents"
    (app/"MacOS").mkpath
    (app/"Resources").mkpath

    (app/"MacOS").install ".build/release/Pellucid"
    app.install "Resources/Info.plist"
    (app/"Resources").install "Resources/AppIcon.icns"
    (app/"Resources").install Dir[".build/release/*.bundle"].first
  end

  def caveats
    <<~EOS
      Pellucid.app has been installed to:
        #{prefix}/Pellucid.app

      To link it into /Applications:
        ln -sf #{prefix}/Pellucid.app /Applications/Pellucid.app
    EOS
  end

  test do
    system "swift", "test", "--disable-sandbox"
  end
end
