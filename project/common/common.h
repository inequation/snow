/**************************************************************************
**
**   SNOW - CS224 BROWN UNIVERSITY
**
**   common.h
**   Author: mliberma
**   Created: 6 Apr 2014
**
**************************************************************************/

#ifndef COMMON_H
#define COMMON_H

#include <cassert>
#include <stdlib.h>
#include <iostream>
#include <time.h>
#if _WIN32 || _WIN64
#else
	#include <sys/time.h>
#endif

#define SAFE_DELETE(MEM)                \
    {                                   \
        if ((MEM)) {                    \
            delete ((MEM));             \
            (MEM) = NULL;               \
        }                               \
    }

#define SAFE_DELETE_ARRAY(MEM)          \
    {                                   \
        if ((MEM)) {                    \
            delete[] ((MEM));           \
            (MEM) = NULL;               \
        }                               \
    }

#ifndef QT_NO_DEBUG
	#if _MSC_VER
		// FIXME: This is fugly, calls to gettimeofday() should be replaced instead.
		#ifndef	WIN32_LEAN_AND_MEAN
			#define WIN32_LEAN_AND_MEAN
		#endif
		#include <Windows.h>
		#include <winsock.h>	// for timeval
		static int gettimeofday(struct timeval * tp, struct timezone * tzp)
		{
			/* FILETIME of Jan 1 1970 00:00:00. */
			static const unsigned __int64 epoch = ((unsigned __int64) 116444736000000000ULL);

			FILETIME    file_time;
			SYSTEMTIME  system_time;
			ULARGE_INTEGER ularge;

			GetSystemTime(&system_time);
			SystemTimeToFileTime(&system_time, &file_time);
			ularge.LowPart = file_time.dwLowDateTime;
			ularge.HighPart = file_time.dwHighDateTime;

			tp->tv_sec = (long) ((ularge.QuadPart - epoch) / 10000000L);
			tp->tv_usec = (long) (system_time.wMilliseconds * 1000);

			return 0;
		}
	#endif
    #define LOG(...) {                                  \
        time_t rawtime;                                 \
        struct tm *timeinfo;                            \
        char buffer[16];                                \
        time( &rawtime );                               \
        timeinfo = localtime( &rawtime );               \
        strftime( buffer, 16, "%H:%M:%S", timeinfo );   \
        fprintf( stderr, "[%s] ", buffer );             \
        fprintf( stderr, __VA_ARGS__ );                 \
        fprintf( stderr, "\n" );                        \
        fflush( stderr );                               \
    }
    #define LOGIF( TEST, ... ) {                            \
        if ( (TEST) ) {                                     \
            time_t rawtime;                                 \
            struct tm *timeinfo;                            \
            char buffer[16];                                \
            time( &rawtime );                               \
            timeinfo = localtime( &rawtime );               \
            strftime( buffer, 16, "%H:%M:%S", timeinfo );   \
            fprintf( stderr, "[%s] ", buffer );             \
            fprintf( stderr, __VA_ARGS__ );                 \
            fprintf( stderr, "\n" );                        \
            fflush( stderr );                               \
        }                                                   \
    }
    #define TIME( START, END, ... ) {                       \
        timeval start, end;                                 \
        gettimeofday( &start, NULL );                       \
        printf( "%s", START ); fflush(stdout);              \
        { __VA_ARGS__ };                                    \
        gettimeofday( &end, NULL );                         \
        long int ms = (end.tv_sec-start.tv_sec)*1000 +      \
                  (end.tv_usec-start.tv_usec)/1000;         \
        printf( "[%ld ms] %s", ms, END ); fflush(stdout);   \
    }
#else
    #define LOG(...) do {} while(0)
    #define LOGIF( TEST, ... ) do {} while(0)
    #define TIME( START, END, ... ) do {} while(0)
#endif

#define STR( QSTR ) QSTR.toStdString().c_str()

#endif // COMMON_H
