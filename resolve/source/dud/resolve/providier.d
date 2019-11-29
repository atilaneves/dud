module dud.resolve.providier;

import std.algorithm.iteration : map, filter;
import std.algorithm.searching : find;
import std.algorithm.sorting : sort;
import std.array : array, empty, front;
import std.exception : enforce;
import std.json;
import std.format : format;
import dud.pkgdescription : PackageDescription, jsonToPackageDescription;
import dud.semver;
import dud.pkgdescription.versionspecifier : parseVersionSpecifier,
	   VersionSpecifier, isInRange;

@safe pure:

interface PackageProvidier {
	const(PackageDescription)[] getPackage(string name,
			const(VersionSpecifier) verRange);

	const(PackageDescription) getPackage(string name, string ver);
}

struct DumpFileProvidier {
	// the cache either holds all or non
	bool isLoaded;
	const string dumpFileName;
	PackageDescription[][string] cache;
	JSONValue[string] parsedPackages;

	this(string dumpFileName) {
		this.dumpFileName = dumpFileName;
	}

	private void makeSureIsLoaded() {
		import std.file : readText;
		if(!this.isLoaded) {
			JSONValue dump = parseJSON(readText(this.dumpFileName));
			enforce(dump.type == JSONType.array);
			foreach(value; dump.arrayNoRef()) {
				enforce(value.type == JSONType.object);
				enforce("name" in value && value["name"].type == JSONType.string);
				string name = value["name"].str();
				this.parsedPackages[name] = value;
			}
			this.isLoaded = true;
		}
	}

	const(PackageDescription)[] getPackages(string name,
			string verRange)
	{
		return this.getPackages(name, parseVersionSpecifier(verRange));
	}

	const(PackageDescription)[] getPackages(string name,
			const(VersionSpecifier) verRange)
	{
		this.makeSureIsLoaded();
		auto pkgs = this.ensurePackageIsInCache(name);
		return (*pkgs)
			.filter!(pkg => !pkg.version_.isBranch())
			.filter!(pkg => isInRange(verRange, pkg.version_))
			.array;
	}

	PackageDescription[]* ensurePackageIsInCache(string name) {
		auto pkgs = name in this.cache;
		if(pkgs is null) {
			auto ptr = name in parsedPackages;
			enforce(ptr !is null, format(
				"Couldn't find '%s' in dump.json", name));
			this.cache[name] = dumpJSONToPackage(*ptr);
			pkgs = name in this.cache;
		}
		return pkgs;
	}

	const(PackageDescription) getPackage(string name, string ver) {
		this.makeSureIsLoaded();
		auto pkgs = this.ensurePackageIsInCache(name);
		auto f = (*pkgs).find!((it, s) => it.version_.m_version == s)(ver);
		enforce(!f.empty, format("No version '%s' for package '%s' could"
			~ " be found in versions [%s]", name, ver,
			(*pkgs).map!(it => it.version_.m_version)));
		return f.front;
	}
}

private PackageDescription[] dumpJSONToPackage(JSONValue jv) {
	enforce(jv.type == JSONType.object, format("Expected object got '%s'",
			jv.type));
	auto vers = "versions" in jv;
	enforce(vers !is null, "Couldn't find versions array");
	enforce((*vers).type == JSONType.array, format("Expected array got '%s'",
			(*vers).type));

	return (*vers).arrayNoRef()
		.map!((it) {
			auto ptr = "packageDescription" in it;
			enforce(ptr !is null && (*ptr).type == JSONType.object);
			PackageDescription pkg = jsonToPackageDescription(*ptr);
			enforce(pkg.version_.m_version.empty);

			auto ver = "version" in it;
			enforce(ver !is null && (*ver).type == JSONType.string);
			pkg.version_ = SemVer((*ver).str());
			return pkg;
		})
		.array
		.sort!((a, b) => a.version_ > b.version_)
		.array;
}
