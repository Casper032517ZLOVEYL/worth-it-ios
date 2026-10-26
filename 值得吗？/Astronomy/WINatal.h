#ifndef WI_NATAL_H
#define WI_NATAL_H
// UTC inputs; tropical geocentric ecliptic of date. -1 = ascendant, -2 = MC.
double WI_NatalLongitude(int body, int year, int month, int day, int hour, int minute, double latitude, double longitude);
#endif
