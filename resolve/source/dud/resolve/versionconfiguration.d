module dud.resolve.versionconfiguration;

import std.array : empty;
import std.format : format;
import dud.semver;
import dud.pkgdescription.versionspecifier;

@safe:

struct NotConf {
	string conf;
	bool isNot;
}

struct VersionConfiguration {
	const VersionSpecifier ver;
	const NotConf conf;
}

/** Return if a is a subset of b, or if a and b are disjoint, or
if a and b overlap
*/
SetRelation relation(const(VersionConfiguration) a,
		const(VersionConfiguration) b)
{
	const SetRelation rel = dud.pkgdescription.versionspecifier
		.relation(a.ver, b.ver);
	const bool conf = a.conf == b.conf || b.conf.empty;

	return conf
		? rel
		: SetRelation.disjoint;
}

unittest {
	SemVer a = SemVer("1.0.0");
	SemVer b = SemVer("2.0.0");
	SemVer c = SemVer("3.0.0");

	auto v1 = VersionConfiguration(VersionSpecifier(a, true, b, true), "");
	auto v2 = VersionConfiguration(VersionSpecifier(a, true, b, false), "");
	auto v3 = VersionConfiguration(VersionSpecifier(a, true, c, false), "");
	auto v4 = VersionConfiguration(VersionSpecifier(b, true, c, false), "");

	auto r = relation(v1, v2);
	assert(r == SetRelation.overlapping, format("%s", r));

	r = relation(v1, v3);
	assert(r == SetRelation.subset, format("%s", r));

	r = relation(v2, v4);
	assert(r == SetRelation.disjoint, format("%s", r));

	r = relation(v1, v4);
	assert(r == SetRelation.overlapping, format("%s", r));
}

unittest {
	SemVer a = SemVer("1.0.0");
	SemVer b = SemVer("2.0.0");
	SemVer c = SemVer("3.0.0");

	auto v1 = VersionConfiguration(VersionSpecifier(a, true, b, true), "conf1");
	auto v2 = VersionConfiguration(VersionSpecifier(a, true, b, false), "");
	auto v3 = VersionConfiguration(VersionSpecifier(a, true, b, true), "conf2");

	auto r = relation(v1, v2);
	assert(r == SetRelation.overlapping, format("%s", r));

	r = relation(v1, v1);
	assert(r == SetRelation.subset, format("%s", r));

	r = relation(v1, v3);
	assert(r == SetRelation.disjoint, format("%s", r));

	r = relation(v2, v3);
	assert(r == SetRelation.disjoint, format("%s", r));

	r = relation(v2, v2);
	assert(r == SetRelation.subset, format("%s", r));

	r = relation(v3, v3);
	assert(r == SetRelation.subset, format("%s", r));
}
