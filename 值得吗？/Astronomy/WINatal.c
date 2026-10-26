#include "WINatal.h"
#include "astronomy.h"
#include <math.h>
static double normalized(double x) { x = fmod(x,360.0); return x < 0 ? x+360.0 : x; }
double WI_NatalLongitude(int body, int year, int month, int day, int hour, int minute, double latitude, double longitude) {
    astro_time_t t = Astronomy_MakeTime(year,month,day,hour,minute,0);
    if (body >= 0) {
        astro_body_t bodies[] = {BODY_SUN,BODY_MOON,BODY_MERCURY,BODY_VENUS,BODY_MARS,BODY_JUPITER,BODY_SATURN,BODY_URANUS,BODY_NEPTUNE,BODY_PLUTO};
        if (body > 9) return NAN;
        astro_vector_t vector = Astronomy_GeoVector(bodies[body],t,ABERRATION);
        astro_ecliptic_t ecliptic = Astronomy_Ecliptic(vector);
        return ecliptic.status == ASTRO_SUCCESS ? normalized(ecliptic.elon) : NAN;
    }
    const double rad = 3.14159265358979323846/180.0;
    double theta = normalized(Astronomy_SiderealTime(&t)*15.0+longitude)*rad;
    astro_rotation_t rotation = Astronomy_Rotation_EQD_ECT(&t);
    if (rotation.status != ASTRO_SUCCESS) return NAN;
    double epsilon = acos(rotation.rot[1][1]);
    if (body == -2) return normalized(atan2(sin(theta),cos(theta)*cos(epsilon))/rad);
    if (body != -1 || fabs(latitude)>=66.0) return NAN; // polar ascendant is not handled here.
    return normalized(atan2(-cos(theta),sin(theta)*cos(epsilon)+tan(latitude*rad)*sin(epsilon))/rad+180.0);
}
