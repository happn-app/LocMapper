// swift-tools-version:5.0
import PackageDescription


let package = Package(
	name: "LocMapper",
	platforms: [
		.macOS(.v10_12)
	],
	products: [
		.library(name: "LocMapper", targets: ["LocMapper"]),
	],
	dependencies: [
		.package(url: "https://github.com/happn-tech/DummyLinuxOSLog.git", from: "1.0.1"),
		.package(url: "https://github.com/happn-tech/XibLoc.git", from: "0.9.7")
	],
	targets: [
		.systemLibrary(name: "CZlib", path: "CZlib", providers: [.apt(["zlib1g-dev"])]),
		
		.target(name: "LocMapper", dependencies: ["DummyLinuxOSLog", "XibLoc", "CZlib"], path: "LocMapper"), /* A better name would be LocMapperKit. I’m lazy enough not to refactor. */
		.testTarget(name: "LocMapperTests", dependencies: ["LocMapper"]),
		
		.target(name: "locmapper", dependencies: ["LocMapper"], path: "LocMapper CLI")
		/* As an alternative to the two targets above, we can have only one
		 * “locmapper” target that compile both folders directly. I prefer the
		 * lib/executable structure (among other it allows having other targets
		 * that uses the LocMapper lib), but here’s the alternative (note it does
		 * not work out of the box because the FileHandleOutputStream class is
		 * implemented both in the lib and the executable…):
		.target(name: "locmapper", dependencies: ["XibLoc"], path: ".", sources: ["LocMapper", "LocMapper CLI"])*/
	]
)
