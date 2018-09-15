// swift-tools-version:4.2
import PackageDescription


let package = Package(
	name: "LocMapper",
	dependencies: [
		.package(url: "git@github.com:happn-app/Swift-zlib.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/DummyLinuxOSLog.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/XibLoc.git", from: "0.9.2")
	],
	targets: [
		.target(name: "LocMapper", dependencies: ["DummyLinuxOSLog", "XibLoc"], path: "LocMapper"), /* A better name would be LocMapperKit. I’m lazy enough not to refactor. */
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
