// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "MeteorDDP",
  platforms: [
    .iOS(.v12), .visionOS(.v1)
  ],
  products: [
    .library(
      name: "MeteorDDP",
      targets: ["MeteorDDP"]
    )
  ],
  dependencies: [
      .package(
          url: "https://github.com/marblear/CryptoSwift.git",
          branch: "visionos"
      ),
      .package(
          url: "https://github.com/marblear/Starscream.git",
          branch: "visionos"
     )
  ],
  targets: [
    .target(
        name: "MeteorDDP",
        dependencies: ["CryptoSwift", "Starscream"],
        path: "MeteorDDP/Classes",
        resources: [.copy("PrivacyInfo.xcprivacy")]
    )
  ],
  swiftLanguageVersions: [.v5]
)

#if swift(>=5.6)
  // Add the documentation compiler plugin if possible
  package.dependencies.append(
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
  )
#endif
