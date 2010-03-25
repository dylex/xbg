/*
 * sunpos.c
 * kirk johnson
 * july 1993
 *
 * code for calculating the position on the earth's surface for which
 * the sun is directly overhead (adapted from _practical astronomy
 * with your calculator, third edition_, peter duffett-smith,
 * cambridge university press, 1988.)
 *
 * RCS $Id: sunpos.c,v 1.4 1995/09/24 00:51:03 tuna Exp $
 *
 * Copyright (C) 1989, 1990, 1993, 1994, 1995 Kirk Lauritz Johnson
 *
 * Parts of the source code (as marked) are:
 *   Copyright (C) 1989, 1990, 1991 by Jim Frost
 *   Copyright (C) 1992 by Jamie Zawinski <jwz@lucid.com>
 *
 * Permission to use, copy, modify and freely distribute xearth for
 * non-commercial and not-for-profit purposes is hereby granted
 * without fee, provided that both the above copyright notice and this
 * permission notice appear in all copies and in supporting
 * documentation.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <assert.h>
#include <sys/time.h>
#include "sunpos.h"

#define SQRT(x) (((x) <= 0.0) ? (0.0) : (sqrt(x)))

#define TWOPI (2*M_PI)


/*
 * the epoch upon which these astronomical calculations are based is
 * 1990 january 0.0, 631065600 seconds since the beginning of the
 * "unix epoch" (00:00:00 GMT, Jan. 1, 1970)
 *
 * given a number of seconds since the start of the unix epoch,
 * DaysSinceEpoch() computes the number of days since the start of the
 * astronomical epoch (1990 january 0.0)
 */

#define EpochStart           (631065600)
#define DaysSinceEpoch(secs) (((secs)-EpochStart)*(1.0/(24*3600)))

/*
 * assuming the apparent orbit of the sun about the earth is circular,
 * the rate at which the orbit progresses is given by RadsPerDay --
 * TWOPI radians per orbit divided by 365.242191 days per year:
 */

#define RadsPerDay (TWOPI/365.242191)

/*
 * details of sun's apparent orbit at epoch 1990.0 (after
 * duffett-smith, table 6, section 46)
 *
 * Epsilon_g    (ecliptic longitude at epoch 1990.0) 279.403303 degrees
 * OmegaBar_g   (ecliptic longitude of perigee)      282.768422 degrees
 * Eccentricity (eccentricity of orbit)                0.016713
 */

#define Epsilon_g    (279.403303*(TWOPI/360))
#define OmegaBar_g   (282.768422*(TWOPI/360))
#define Eccentricity (0.016713)

/*
 * MeanObliquity gives the mean obliquity of the earth's axis at epoch
 * 1990.0 (computed as 23.440592 degrees according to the method given
 * in duffett-smith, section 27)
 */
#define MeanObliquity (23.440592*(TWOPI/360))

static double solve_keplers_equation (double);
static double sun_ecliptic_longitude (time_t);
static void   ecliptic_to_equatorial (double, double, double *, double *);
static double julian_date (int, int, int);
static double GST (time_t);

/*
 * solve Kepler's equation via Newton's method
 * (after duffett-smith, section 47)
 */
static double solve_keplers_equation(M)
     double M;
{
  double E;
  double delta;

  E = M;
  while (1)
  {
    delta = E - Eccentricity*sin(E) - M;
    if (fabs(delta) <= 1e-10) break;
    E -= delta / (1 - Eccentricity*cos(E));
  }

  return E;
}


/*
 * compute ecliptic longitude of sun (in radians)
 * (after duffett-smith, section 47)
 */
static double sun_ecliptic_longitude(ssue)
     time_t ssue;               /* seconds since unix epoch */
{
  double D, N;
  double M_sun, E;
  double v;

  D = DaysSinceEpoch(ssue);

  N = RadsPerDay * D;
  N = fmod(N, TWOPI);
  if (N < 0) N += TWOPI;

  M_sun = N + Epsilon_g - OmegaBar_g;
  if (M_sun < 0) M_sun += TWOPI;

  E = solve_keplers_equation(M_sun);
  v = 2 * atan(sqrt((1+Eccentricity)/(1-Eccentricity)) * tan(E/2));

  return (v + OmegaBar_g);
}


/*
 * convert from ecliptic to equatorial coordinates
 * (after duffett-smith, section 27)
 */
static void ecliptic_to_equatorial(lambda, beta, alpha, delta)
     double  lambda;            /* ecliptic longitude       */
     double  beta;              /* ecliptic latitude        */
     double *alpha;             /* (return) right ascension */
     double *delta;             /* (return) declination     */
{
  double sin_e, cos_e;

  sin_e = sin(MeanObliquity);
  cos_e = cos(MeanObliquity);

  *alpha = atan2(sin(lambda)*cos_e - tan(beta)*sin_e, cos(lambda));
  *delta = asin(sin(beta)*cos_e + cos(beta)*sin_e*sin(lambda));
}


/*
 * computing julian dates (assuming gregorian calendar, thus this is
 * only valid for dates of 1582 oct 15 or later)
 * (after duffett-smith, section 4)
 */
static double julian_date(y, m, d)
     int y;                     /* year (e.g. 19xx)          */
     int m;                     /* month (jan=1, feb=2, ...) */
     int d;                     /* day of month              */
{
  int    A, B, C, D;
  double JD;

  /* lazy test to ensure gregorian calendar */
  assert(y >= 1583);

  if ((m == 1) || (m == 2))
  {
    y -= 1;
    m += 12;
  }

  A = y / 100;
  B = 2 - A + (A / 4);
  C = 365.25 * y;
  D = 30.6001 * (m + 1);

  JD = B + C + D + d + 1720994.5;

  return JD;
}


/*
 * compute greenwich mean sidereal time (GST) corresponding to a given
 * number of seconds since the unix epoch
 * (after duffett-smith, section 12)
 */
static double GST(ssue)
     time_t ssue;               /* seconds since unix epoch */
{
  double     JD;
  double     T, T0;
  double     UT;
  struct tm *tm;

  tm = gmtime(&ssue);

  JD = julian_date(tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday);
  T  = (JD - 2451545) / 36525;

  T0 = ((T + 2.5862e-5) * T + 2400.051336) * T + 6.697374558;

  T0 = fmod(T0, 24.0);
  if (T0 < 0) T0 += 24;

  UT = tm->tm_hour + (tm->tm_min + tm->tm_sec / 60.0) / 60.0;

  T0 += UT * 1.002737909;
  T0 = fmod(T0, 24.0);
  if (T0 < 0) T0 += 24;

  return T0;
}


/*
 * given a particular time (expressed in seconds since the unix
 * epoch), compute position on the earth (lat, lon) such that sun is
 * directly overhead.
 */
struct coords sun_location(time_t ssue)
{
  double lambda;
  double alpha, delta;
  double tmp;

  lambda = sun_ecliptic_longitude(ssue);
  ecliptic_to_equatorial(lambda, 0.0, &alpha, &delta);

  tmp = alpha - (TWOPI/24)*GST(ssue);
  if (tmp < -M_PI)
  {
    do tmp += TWOPI;
    while (tmp < -M_PI);
  }
  else if (tmp > M_PI)
  {
    do tmp -= TWOPI;
    while (tmp < -M_PI);
  }

  return (struct coords){ delta, tmp };
}

struct coords location_altaz(struct coords o, struct coords t)
{
	double h = t.y - o.y;
	return (struct coords){
		asin(                  sin(o.x)*sin(t.x) + cos(o.x)*cos(t.x)*cos(h)),
		atan2(sin(h)*cos(t.x), cos(o.x)*sin(t.x) - sin(o.x)*cos(t.x)*cos(h))
	};
}

struct coords location_ascdec(struct coords o, struct coords t)
{
	double h = t.y - o.y;
	return (struct coords){
		atan2(sin(h)*cos(t.x), sin(o.x)*sin(t.x) + cos(o.x)*cos(t.x)*cos(h)),
		asin(                  cos(o.x)*sin(t.x) - sin(o.x)*cos(t.x)*cos(h))
	};
}

struct coords degrees(struct coords c)
{
	return (struct coords){ c.x*180./M_PI, c.y*180./M_PI };
}

struct coords radians(struct coords c)
{
	return (struct coords){ c.x*M_PI/180., c.y*M_PI/180. };
}

static struct coords Pos;
static int GotPos = 0;

void set_location(struct coords l)
{
	Pos = l;
	GotPos ++;
}

struct coords get_location()
{
	if (GotPos)
		return Pos;

	FILE *f = NULL;
	if (!f)
	{
		static char buf[256];
		snprintf(buf, sizeof(buf), "%s/.geopos", getenv("HOME"));
		f = fopen(buf, "r");
	}
	if (!f)
		f = fopen("/etc/geopos", "r");
	if (!f)
	{
		/* guess */
		struct timezone tz = {};
		gettimeofday(NULL, &tz);
		return (struct coords){ 0, -0.25*tz.tz_minuteswest };
	}
	struct coords pos;
	fscanf(f, "%lf %lf", &pos.x, &pos.y);
	fclose(f);
	Pos = radians(pos);
	GotPos ++;
	return Pos;
}

struct coords sun_position(time_t t)
{
	struct coords sun = sun_location(t);
	struct coords here = get_location();
	return location_altaz(here, sun);
}

static double angle(time_t t)
{
	return sun_position(t).x;
}

static double dangle(time_t t)
{
	static const double dt = 60.0;
	return (angle(t + dt) - angle(t))/dt;
}

time_t find_riseset(time_t t)
{
	int Rise = signbit(angle(t));
	double Dir = Rise ? 1 : -1;
	while (Dir*dangle(t) < 2e-5)
		t += 3600;
	int i = 0;
	while (i++ < 100)
	{
		double ddt = dangle(t);
		double td = -angle(t)/ddt;
		if (td > 14400)
			td = 14400;
		if (td < -14400)
			td = -14400;
		if (fabs(angle(t)) <= fabs(angle(t + td)))
			break;
		t += td;
	}
	return t;
}

time_t find_minmax(time_t t)
{
	int D = signbit(dangle(t));
	time_t l = t;
	time_t h = 12*3600;
	while (h > 60)
	{
		h /= 2;
		time_t m = l + h;
		if (signbit(dangle(m)) == D)
			l = m;
	}
	return l;
}

/* from pom.c
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 */

#define PI M_PI
#define EPOCH_MINUS_1970	(20 * 365 + 5 - 1) /* 20 years, 5 leaps, back 1 day to Jan 0 */
#define	EPSILONg  279.403303	/* solar ecliptic long at EPOCH */
#define	RHOg	  282.768422	/* solar ecliptic long of perigee at EPOCH */
#define	ECCEN	  0.016713	/* solar orbit eccentricity */
#define	lzero	  318.351648	/* lunar mean long at EPOCH */
#define	Pzero	  36.340410	/* lunar mean long of perigee at EPOCH */
#define	Nzero	  318.510107	/* lunar mean long of node at EPOCH */

static double dtor(deg)
	double deg;
{
	return(deg * PI / 180);
}

static void adj360(deg)
	double *deg;
{
	for (;;)
		if (*deg < 0)
			*deg += 360;
		else if (*deg > 360)
			*deg -= 360;
		else
			break;
}

static double potm(days)
	double days;
{
	double N, Msol, Ec, LambdaSol, l, Mm, Ev, Ac, A3, Mmprime;
	double A4, lprime, V, ldprime, D, Nm;

	N = 360 * days / 365.242191;				/* sec 46 #3 */
	adj360(&N);
	Msol = N + EPSILONg - RHOg;				/* sec 46 #4 */
	adj360(&Msol);
	Ec = 360 / PI * ECCEN * sin(dtor(Msol));		/* sec 46 #5 */
	LambdaSol = N + Ec + EPSILONg;				/* sec 46 #6 */
	adj360(&LambdaSol);
	l = 13.1763966 * days + lzero;				/* sec 65 #4 */
	adj360(&l);
	Mm = l - (0.1114041 * days) - Pzero;			/* sec 65 #5 */
	adj360(&Mm);
	Nm = Nzero - (0.0529539 * days);			/* sec 65 #6 */
	adj360(&Nm);
	Ev = 1.2739 * sin(dtor(2*(l - LambdaSol) - Mm));	/* sec 65 #7 */
	Ac = 0.1858 * sin(dtor(Msol));				/* sec 65 #8 */
	A3 = 0.37 * sin(dtor(Msol));
	Mmprime = Mm + Ev - Ac - A3;				/* sec 65 #9 */
	Ec = 6.2886 * sin(dtor(Mmprime));			/* sec 65 #10 */
	A4 = 0.214 * sin(dtor(2 * Mmprime));			/* sec 65 #11 */
	lprime = l + Ev + Ec - Ac + A4;				/* sec 65 #12 */
	V = 0.6583 * sin(dtor(2 * (lprime - LambdaSol)));	/* sec 65 #13 */
	ldprime = lprime + V;					/* sec 65 #14 */
	D = ldprime - LambdaSol;				/* sec 67 #2 */
	return(D);
}

double moon_phase(time_t now)
{
	double day = (now - EPOCH_MINUS_1970 * 86400) / 86400.0;
	double pom = potm(day);
	return pom;
}
