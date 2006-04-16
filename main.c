#ifdef __linux__
#define HAVE_ARGP 1
#define HAVE_GETDATE 1
#endif

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#ifdef HAVE_ARGP
#include <argp.h>
#else
#include <getopt.h>
#endif
#include <stdarg.h>
#include "sunpos.h"

static char *ReadFmt = NULL;
static bool RiseSet = false;
static char *Fmt = NULL;
static bool LatLon = false;
static bool AltAz = true;
static bool AscDec = false;
static bool GeoPos = false;
static bool Degrees = true;
static bool NowSet = false;
static time_t Now;
static struct coords Loc;

#ifndef HAVE_ARGP
struct argp_state {
	int next;
	int argc;
	char **argv;
};

static void argp_error(struct argp_state *state, const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	fprintf(stderr, "%s: ", state->argv[0]);
	vfprintf(stderr, fmt, args);
	fprintf(stderr, "\n");
	va_end(args);
	exit(1);
}

typedef int error_t;
#define ARGP_KEY_ARGS 256
#define ARGP_KEY_NO_ARGS 257
#define ARGP_ERR_UNKNOWN -1
#endif

static error_t parse_opts(int key, char *optarg, struct argp_state *state)
{
	char *e;

	switch (key)
	{
		case '*':
			LatLon = AltAz = AscDec = GeoPos = true;
			Fmt = "%c";
			break;

		case 'f':
			ReadFmt = optarg;
			break;
		case 'F':
			ReadFmt = NULL;
			break;

		case 't':
			Fmt = optarg ?: "%c";
			break;
		case 'T':
			Fmt = NULL;
			break;

		case '0':
			RiseSet = true;
			if (!Fmt)
				Fmt = "%c";
			break;

		case 'g':
			GeoPos = true;
			break;
		case 'G':
			GeoPos = false;
			break;

		case 'l':
			LatLon = true;
			break;
		case 'L':
			LatLon = false;
			break;

		case 'a':
			AltAz = true;
			break;
		case 'A':
			AltAz = false;
			break;

		case 'd':
			AscDec = true;
			break;
		case 'D':
			AscDec = false;
			break;

		case 'r':
			Degrees = false;
			break;

		case ARGP_KEY_ARGS:
			while (1) switch (state->argc - state->next)
			{
				case 0:
					return 0;
				case 1:
				case 3:
					optarg = state->argv[state->next++];
					if (ReadFmt)
					{
						struct tm ts;
						e = strptime(optarg, ReadFmt, &ts);
						if (!e || *e)
							argp_error(state, "invalid time format: %s", optarg);
						Now = timelocal(&ts);
					}
					else
					{
#ifdef HAVE_GETDATE
						struct tm *ts = getdate(optarg);
						if (!ts)
							argp_error(state, "invalid time format: error %d from getdate(3)", getdate_err);
						Now = timelocal(ts);
#else
						argp_error(state, "time format required (getdate not supported)");
#endif
					}
					NowSet = true;
					break;

				case 2:
					optarg = state->argv[state->next++];
					Loc.x = strtod(optarg, &e);
					if (*e)
						argp_error(state, "invalid latitude: %s", optarg);
					optarg = state->argv[state->next++];
					Loc.y = strtod(optarg, &e);
					if (*e)
						argp_error(state, "invalid longitude: %s", optarg);
					if (Degrees)
						Loc = radians(Loc);
					set_location(Loc);
					break;

				default:
					argp_error(state, "unexpected argument: %s", optarg);
			}

		case ARGP_KEY_NO_ARGS:
			break;

		default:
			return ARGP_ERR_UNKNOWN;
	}
	return 0;
}

#ifdef HAVE_ARGP
static const struct argp_option argp_options[] = {
#define ARG(LONG, SHORT, ARG, OPT, DESC) {LONG, SHORT, ARG, OPT, DESC}
#define ARG_NONE 0
#define ARG_OPT OPTION_ARG_OPTIONAL
#define ARG_REQ 0
#else
static struct option getopt_options[] = {
#define ARG(LONG, SHORT, ARG, OPT, DESC) {LONG, OPT, NULL, SHORT}
#define ARG_NONE no_argument
#define ARG_OPT optional_argument
#define ARG_REQ required_argument
#endif
	ARG("timefmt", 'f', "FMT", ARG_REQ, "use strptime(3) FMT for the time argument"),
	ARG("getdate", 'F', NULL, ARG_NONE, "use getdate for the time argument [default]"),
	ARG("time", 't', "FMT", ARG_OPT, "print the time in strftime(3) FMT"),
	ARG("no-time", 'T', NULL, ARG_NONE, "don't print the time [default unless -0]"),
	ARG("geopos", 'g', NULL, ARG_NONE, "print the local geographic position used"),
	ARG("no-geopos", 'G', NULL, ARG_NONE, "don't print the local geographic position [default]"),
	ARG("riseset", '0', NULL, ARG_NONE, "find and use the next sun rise/set time (implies -t)"),
	ARG("latlon", 'l', NULL, ARG_NONE, "print the coordinates of the sun"),
	ARG("no-latlon", 'L', NULL, ARG_NONE, "don't print the coordinates of the sun [default]"),
	ARG("altaz", 'a', NULL, ARG_NONE, "print the altitude and azimuth of the sun [default]"),
	ARG("no-altaz", 'A', NULL, ARG_NONE, "don't print the altitude and azimuth of the sun"),
	ARG("ascdec", 'd', NULL, ARG_NONE, "print the ascension and declination of the sun"),
	ARG("no-ascdec", 'D', NULL, ARG_NONE, "don't print the ascension and declination of the sun [default]"),
	ARG("radians", 'r', NULL, ARG_NONE, "print angles in radians [degrees]"),
	ARG("all", '*', NULL, ARG_NONE, "enable all display modes"),
	{}
};

#ifdef HAVE_ARGP
static const struct argp argp_parser = {
	.options =	argp_options,
	.parser =	&parse_opts,
	.args_doc =	"[TIME]",
	.doc =		"determine information about the location of the sun\v\
Each type of information in displayed on one line.  If all information in requested, in is displayed in the following order: time, geopos, lat lon, alt az, asc dec.  Local coordinates are determined from ~/.geopos or /etc/geopos, or from the local timezone."
};
#endif

static inline struct coords units(struct coords x)
{
	return Degrees ? degrees(x) : x;
}

static inline void print_coords(struct coords c)
{
	c = units(c);
	printf("%3.2f %3.2f\n", c.x, c.y);
}

int main(int argc, char **argv)
{
#ifdef HAVE_ARGP
	if ((errno = argp_parse(&argp_parser, argc, argv, 0, 0, 0)))
		exit(1);
#else
	struct argp_state state = { 0, argc, argv };
	while (1)
	{
		state.next = optind;
		int c = getopt_long(argc, argv, "f:Ft::TgG0lLaAdDr*", getopt_options, NULL);
		if (c < 0)
			break;
		if (parse_opts(c, optarg, &state) != 0)
		{
			if (c != '?')
				fprintf(stderr, "%s: unhandled option '%c'\n", argv[0], c);
			exit(1);
		}
	}
	parse_opts(ARGP_KEY_ARGS, NULL, &state);
#endif

	if (!NowSet)
		time(&Now);
	Loc = get_location();

	if (RiseSet)
		Now = find_riseset(Now);

	struct coords sun = sun_location(Now);

	if (Fmt)
	{
		struct tm *ts = localtime(&Now);
		static char buf[256];
		if (!strftime(buf, sizeof(buf), Fmt, ts))
			exit(1);
		printf("%s\n", buf);
	}
	if (GeoPos)
		print_coords(Loc);
	if (LatLon)
		print_coords(sun);
	if (AltAz)
		print_coords(location_altaz(Loc, sun));
	if (AscDec)
		print_coords(location_ascdec(Loc, sun));

	return 0;
}
