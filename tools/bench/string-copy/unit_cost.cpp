// unit_cost.cpp -- the noise-free half of the decision-4 benchmark (bead oo-lvj).
//
// The golden runs count, per game run, how many std::string copies the shadow hook made (n), how
// many of them outgrew the 15-byte small-string buffer (heap) and how many bytes those held
// (bytes). This times the same operation OOBenchStringCopy.mm performs, on an idle core, so
//     added CPU  =  n * perCopy  +  heap * perHeapCopy  +  bytes * perByte
// can be computed exactly for any mode, independently of how loaded the machine was.
//
//     unit_cost <n> <heap> <bytes>     prints the three unit costs (ns) and the modelled CPU (ms)
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>

static volatile char gSink;
static volatile std::size_t gLength;

// The copy escapes through a call the optimiser cannot see into, so neither the allocation nor the
// fill can be elided (clang may otherwise drop a new/delete pair whose memory never escapes).
static void (*volatile gEscape)(const char*) = [](const char* p) { gSink = p[0]; };

static double nsPerCopy(std::size_t length, long iterations)
{
	gLength = length;
	const auto t0 = std::chrono::steady_clock::now();
	for (long i = 0; i < iterations; ++i)
	{
		std::string copy(gLength, 'x');
		gEscape(copy.data());
	}
	const auto t1 = std::chrono::steady_clock::now();
	return std::chrono::duration<double, std::nano>(t1 - t0).count() / static_cast<double>(iterations);
}

static double best(std::size_t length, long iterations)
{
	double b = 1e300;
	for (int r = 0; r < 7; ++r)
	{
		const double t = nsPerCopy(length, iterations);
		if (t < b) b = t;
	}
	return b;
}

int main(int argc, char** argv)
{
	const double sso = best(8, 2000000);                       // no allocation
	const double small = best(32, 1000000);                    // allocation, few bytes
	const double large = best(36 * 1024, 20000);               // the "all" mode's mean heap copy
	const double perByte = (large - small) / (36.0 * 1024 - 32);
	const double perHeap = small - sso - 32 * perByte;
	std::printf("unit costs: copy %.2f ns, heap copy +%.2f ns, per byte %.4f ns\n", sso, perHeap, perByte);
	if (argc == 4)
	{
		const double n = std::atof(argv[1]), heap = std::atof(argv[2]), bytes = std::atof(argv[3]);
		const double ms = (n * sso + heap * perHeap + bytes * perByte) / 1e6;
		std::printf("modelled added CPU for n=%.0f heap=%.0f bytes=%.0f: %.1f ms\n", n, heap, bytes, ms);
	}
	return 0;
}
