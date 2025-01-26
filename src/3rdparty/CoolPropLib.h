/** \brief This file defines an interface for shared library (DLL) wrapping
 *
 * In general the functions defined here take strings which are 0-terminated (C-style),
 * vectors of doubles are passed as double* and length
 * These functions pass directly to equivalently named functions in CoolProp.h in the CoolProp namespace
 * that take std::string, vector<double> etc.
 *
 * Functions with the call type like
 * EXPORT_CODE void CONVENTION AFunction(double, double);
 * will be exported to the DLL
 *
 * The exact symbol that will be exported depends on the values of the preprocessor macros COOLPROP_LIB, EXPORT_CODE, CONVENTION, etc.
 *
 * In order to have 100% control over the export macros, you can specify EXPORT_CODE and CONVENTION directly. Check out
 * CMakeLists.txt in the repo root to see some examples.
 *
 */

#ifndef COOLPROPDLL_H
#define COOLPROPDLL_H

// See also http://stackoverflow.com/questions/5919996/how-to-detect-reliably-mac-os-x-ios-linux-windows-in-c-preprocessor
// Copied verbatim from PlatformDetermination.h in order to have a single-include header
#if _WIN64
#    define __ISWINDOWS__
#elif _WIN32
#    define __ISWINDOWS__
#elif __APPLE__
#    define __ISAPPLE__
#elif __linux || __unix || __posix
#    define __ISLINUX__
#elif __powerpc__
#    define __ISPOWERPC__
#else
#    pragma error
#endif

#if defined(COOLPROP_LIB)
#    ifndef EXPORT_CODE
#        if defined(__ISWINDOWS__)
#            define EXPORT_CODE extern "C" __declspec(dllexport)
#        else
#            define EXPORT_CODE extern "C"
#        endif
#    endif
#    ifndef CONVENTION
#        if defined(__ISWINDOWS__)
#            define CONVENTION __stdcall
#        else
#            define CONVENTION
#        endif
#    endif
#else
#    ifndef EXPORT_CODE
#        define EXPORT_CODE
#    endif
#    ifndef CONVENTION
#        define CONVENTION
#    endif
#endif

// Hack for PowerPC compilation to only use extern "C"
#if defined(__powerpc__) || defined(EXTERNC)
#    undef EXPORT_CODE
#    define EXPORT_CODE extern "C"
#endif

#if defined(__powerpc__)
// From https://rowley.zendesk.com/entries/46176--Undefined-reference-to-assert-error-message
// The __assert function is an error handler function that is invoked when an assertion fails.
// If you are writing a program that uses the assert macro then you must supply you own __assert error handler function. For example
inline void __assert(const char* error) {
    while (1);
}
#endif

EXPORT_CODE double CONVENTION PropsSI(const char* Output, const char* Name1, double Prop1, const char* Name2, double Prop2, const char* Ref);

EXPORT_CODE void CONVENTION PropsSImulti(const char* Outputs, const char* Name1, double* Prop1, const long size_Prop1, const char* Name2,
                                         double* Prop2, const long size_Prop2, char* backend, const char* FluidNames, const double* fractions,
                                         const long length_fractions, double* result, long* resdim1, long* resdim2);
EXPORT_CODE double CONVENTION PropsS(const char* Output, const char* Name1, double Prop1, const char* Name2, double Prop2, const char* Ref);

EXPORT_CODE double CONVENTION Props(const char* Output, const char Name1, double Prop1, const char Name2, double Prop2, const char* Ref);

EXPORT_CODE double CONVENTION Props1(const char* FluidName, const char* Output);

#endif
