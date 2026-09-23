/*	tools/plist-fuzz/oofnd_plist.cpp — the oofnd side of the PList differential harness (bead
	oo-g2k, contract C1). Same command line and output protocol as gnustep_oracle.mm:

	    oofnd_plist <list> <outdir> [parse-only]

	    F <id>
	    P OK <format> <dump> | P NIL | P ERR <message>
	    W1 OK | W1 ERR <message>           (oo::writeOldStylePList; not in parse-only)
	    W2 OK | W2 ERR <message>           (oo::writeXMLPList; not in parse-only)

	The parse is oo::parsePropertyList, i.e. OOPropertyListFromData minus logging; <dump> is
	tests/unit/oofnd/plist_dump.hpp's canonical form.
*/

#include "oofnd/PListParsing.hpp"
#include "oofnd/PListWriting.hpp"

#include "plist_dump.hpp"

#include <cstdio>
#include <fstream>
#include <iterator>
#include <sstream>
#include <string>

namespace {

void printEscaped(const char* tag, const std::string& msg)
{
	std::string s;
	for (char c : msg)
	{
		if (c == '\\') s += "\\\\";
		else if (c == '\n') s += "\\n";
		else if (c == '\r') s += "\\r";
		else s += c;
	}
	std::printf("%s %s\n", tag, s.c_str());
}

bool readFile(const std::string& path, std::string& out)
{
	std::ifstream in(path, std::ios::binary);
	if (!in) return false;
	out.assign(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>());
	return true;
}

bool writeFile(const std::string& path, const oo::Data& data)
{
	std::ofstream out(path, std::ios::binary);
	const auto bytes = data.span();
	out.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
	return static_cast<bool>(out);
}

} // namespace

int main(int argc, char** argv)
{
	if (argc < 3)
	{
		std::fprintf(stderr, "usage: oofnd_plist <list> <outdir> [parse-only]\n");
		return 2;
	}
	const bool parseOnly = argc > 3 && std::string(argv[3]) == "parse-only";
	const std::string outDir = argv[2];
	std::string list;
	if (!readFile(argv[1], list))
	{
		std::fprintf(stderr, "cannot read list\n");
		return 2;
	}
	std::istringstream lines(list);
	std::string line;
	while (std::getline(lines, line))
	{
		const auto tab = line.find('\t');
		if (tab == std::string::npos) continue;
		const std::string id = line.substr(0, tab);
		const std::string path = line.substr(tab + 1);
		std::printf("F %s\n", id.c_str());

		std::string bytes;
		const bool read = readFile(path, bytes);
		oo::PListFormat format{};
		auto r = oo::parsePropertyList(read ? bytes : std::string(), &format);
		if (!r) printEscaped("P ERR", r.error().description());   // what OOPropertyListFromData logged
		else if (r->isNull()) std::printf("P NIL\n");
		else std::printf("P OK %d %s\n", static_cast<int>(format), oo_test::dump(*r).c_str());
		std::fflush(stdout);

		if (r && !r->isNull() && !parseOnly)
		{
			auto old = oo::writeOldStylePList(*r);
			if (old && writeFile(outDir + "/" + id + ".old", *old)) std::printf("W1 OK\n");
			else printEscaped("W1 ERR", old ? std::string("cannot write output") : old.error().message);
			auto xml = oo::writeXMLPList(*r);
			if (xml && writeFile(outDir + "/" + id + ".xml", *xml)) std::printf("W2 OK\n");
			else printEscaped("W2 ERR", xml ? std::string("cannot write output") : xml.error().message);
			std::fflush(stdout);
		}
	}
	std::printf("END\n");
	return 0;
}
