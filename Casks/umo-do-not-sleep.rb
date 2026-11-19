cask "umo-do-not-sleep" do
  version "1.0.2"
  sha256 "e83bad4284bb789639dd0eb327366e2607306c50c6edb390506a22771a1baa7a"

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
