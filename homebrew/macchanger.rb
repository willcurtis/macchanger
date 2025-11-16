class Macchanger < Formula
  desc "Change or spoof your MAC address on macOS"
  homepage "https://github.com/willcurtis/macchanger"
  url "https://github.com/willcurtis/macchanger/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "<fill-in-from-github-release>"
  version "1.0.0"

  def install
    bin.install "macchanger.sh" => "macchanger"
  end

  test do
    assert_match "Version:", shell_output("#{bin}/macchanger --version 2>&1")
  end
end
