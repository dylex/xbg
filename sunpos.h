#ifndef SUNPOS_H
#define SUNPOS_H

#include <time.h>

struct coords {
	double x, y;
};

struct coords sun_location(time_t) __attribute__((const));
struct coords location_altaz(struct coords, struct coords) __attribute__((const));
struct coords location_ascdec(struct coords, struct coords) __attribute__((const));
struct coords get_location(void) __attribute__((pure));
void set_location(struct coords);
struct coords sun_position(time_t) __attribute__((pure));
struct coords degrees(struct coords) __attribute((const));
struct coords radians(struct coords) __attribute((const));
time_t find_riseset(time_t) __attribute__((pure));
time_t find_minmax(time_t) __attribute__((pure));
double moon_phase(time_t) __attribute__((const));

#endif
