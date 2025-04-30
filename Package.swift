// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "100Days",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "100Days",
            targets: ["100Days"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "100Days",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
            ]),
        .testTarget(
            name: "100DaysTests",
            dependencies: ["100Days"]),
    ]
) 