/*

OOLogOutputHandler+FoundationBridge.mm

TRANSITIONAL: see OOLogOutputHandler+FoundationBridge.h. The NSLog hook moved here unchanged from
OOLogOutputHandler.mm; each Foundation-typed function forwards to its cxx_ counterpart and converts
as the old function did (nil for nil).

*/

#import "OOLogOutputHandler.h"	// declares the bridge at its end
#import "OOLogging.h"
#import "OOFoundationBridge.h"


#if OOLITE_GNUSTEP

namespace {

void OONSLogPrintfHandler(NSString *message)
{
	if (OOLogWillDisplayMessagesInClass(@"gnustep"))
	{
		OOLogWithFunctionFileAndLine(@"gnustep", NULL, NULL, 0, @"%@", message);
	}
}

}	// namespace

#endif


void OOLogOutputHandlerInstallNSLogHook(void)
{
#if OOLITE_GNUSTEP
	// gnustep-base's own NSLog lock, not ours to replace: it goes with the NSLog hook (oo-qps).
	[GSLogLock() lock];
	_NSLog_printf_handler = OONSLogPrintfHandler;
	[GSLogLock() unlock];
#endif
}


void OOLogOutputHandlerRemoveNSLogHook(void)
{
#if OOLITE_GNUSTEP
	[GSLogLock() lock];
	_NSLog_printf_handler = NULL;
	[GSLogLock() unlock];
#endif
}


void OOLogOutputHandlerPrint(NSString *string)
{
	cxx_OOLogOutputHandlerPrint(oo::StdString(string));
}


NSString *OOLogHandlerGetLogPath(void)
{
	return oo::NSStringOrNil(cxx_OOLogHandlerGetLogPath());
}


NSString *OOLogHandlerGetLogBasePath(void)
{
	return oo::NSStringOrNil(cxx_OOLogHandlerGetLogBasePath());
}


void OOLogOutputHandlerChangeLogFile(NSString *newLogName)
{
	cxx_OOLogOutputHandlerChangeLogFile(oo::StdString(newLogName));
}
