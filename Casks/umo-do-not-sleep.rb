cask "umo-do-not-sleep" do
  version "1.0.1"
  sha256 "da781c3a6707d8411cc1fd972ebcf009643a9b7d3b6d33d3a3c41496c0f7748a"

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
