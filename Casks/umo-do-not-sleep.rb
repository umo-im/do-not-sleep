cask "umo-do-not-sleep" do
  version "1.0"
  sha256 "c50bfe673abb046e39e9cea771e7d0fe836f6110fb3558c41d97cb94510ea68c"

  url "https://github.com/umo-im/do-not-sleep/releases/download/v#{version}/Do-Not-Sleep-v#{version}-macos.zip",
      verified: "github.com/umo-im/do-not-sleep/"
  name "Do Not Sleep"
  desc "Menu bar app that prevents idle sleep and screen saver"
  homepage "https://github.com/umo-im/do-not-sleep"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Do Not Sleep.app"

  zap trash: [
    "~/Library/Containers/im.umo.dns",
    "~/Library/Saved Application State/im.umo.dns.savedState",
  ]
end
