// swift-tools-version:5.5
import PackageDescription


let package = Package(
	name: "LocMapper",
	platforms: [
		.macOS(.v11),
		.iOS(.v14)
	],
	products: [
		.library(name: "LocMapper", targets: ["LocMapper"]),
		.executable(name: "locmapper", targets: ["locmapper"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.3.0"),
		.package(url: "https://github.com/happn-app/XibLoc.git", from: "1.0.0"),
		.package(url: "https://github.com/xcode-actions/CLTLogger.git", from: "0.5.1")
	],
	targets: [
		.systemLibrary(name: "CZlib", path: "CZlib", providers: [.apt(["zlib1g-dev"])]),
		
		/* A better name would be LocMapperKit. I’m lazy enough not to refactor. */
		.target(
			name: "LocMapper",
			dependencies: [
				.product(name: "Logging", package: "swift-log"),
				.product(name: "XibLoc",  package: "XibLoc"),
				.target(name: "CZlib")
			],
			path: "LocMapper"
		),
		.testTarget(name: "LocMapperTests", dependencies: ["LocMapper"]),
		
		.executableTarget(
			name: "locmapper",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "CLTLogger",      package: "CLTLogger"),
				.target(name: "LocMapper")
			],
			path: "LocMapper CLI"
		)
		/* As an alternative to the two targets above, we can have only one “locmapper” target that compile both folders directly.
		 * I prefer the lib/executable structure (among other it allows having other targets that uses the LocMapper lib, like the test target for instance),
		 * but here’s the alternative (note it does not work out of the box because the FileHandleOutputStream class is implemented both in the lib and the executable…).
		.target(name: "locmapper", dependencies: ["XibLoc", .product(name: "ArgumentParser", package: "swift-argument-parser")], path: ".", sources: ["LocMapper", "LocMapper CLI"])*/
	]
)
