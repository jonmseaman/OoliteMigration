/*

OOLogOutputHandler.m
By Jens Ayton


Copyright (C) 2007-2013 Jens Ayton and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/


#define OOLOG_POISON_NSLOG 0

#import "OOLogOutputHandler.h"
#import "OOLogging.h"
#import "OOFoundationBridge.h"
#import <objc/runtime.h>
#import <objc/objc-arc.h>
#include <stdlib.h>
#include <stdio.h>
#if OOLITE_WINDOWS
#include <io.h>
#else
#include <unistd.h>
#endif
#include "oofnd/StdLib.hpp"
#include "oofnd/Thread.hpp"
#include "oofnd/Date.hpp"
#include "oofnd/FileSystem.hpp"
#include "oofnd/String.hpp"
#import "NSFileManagerOOExtensions.h"
#include <SDL3/SDL_stdinc.h>
#include <atomic>
#include <chrono>
#include <thread>


#undef NSLog		// We need to be able to call the real NSLog.


#if OOLITE_MAC_OS_X

#include <dlfcn.h>

#ifndef NDEBUG

#define SET_CRASH_REPORTER_INFO 1

// Function to set "Application Specific Information" field in crash reporter log in Leopard.
// Extremely unsupported, so not used in release builds.
static void InitCrashReporterInfo(void);
static void SetCrashReporterInfo(const char *info);
static BOOL sCrashReporterInfoAvailable = NO;

#endif


typedef void (*LogCStringFunctionProc)(const char *string, unsigned length, BOOL withSyslogBanner);
typedef LogCStringFunctionProc (*LogCStringFunctionGetterProc)(void);
typedef void (*LogCStringFunctionSetterProc)(LogCStringFunctionProc);

static LogCStringFunctionGetterProc _NSLogCStringFunction = NULL;
static LogCStringFunctionSetterProc _NSSetLogCStringFunction = NULL;

static void LoadLogCStringFunctions(void);
static void OONSLogCStringFunction(const char *string, unsigned length, BOOL withSyslogBanner);

static std::string GetAppName(void);

static LogCStringFunctionProc	sDefaultLogCStringFunction = NULL;

#elif OOLITE_GNUSTEP

// (gnustep-base's NSLog hook is in OOLogOutputHandler+FoundationBridge.mm)

#else
#error Unknown platform!
#endif


namespace {

BOOL DirectoryExistCreatingIfNecessary(const std::string &path);


// What the logger thread is sent: log text, or a flush or stop request (were Foundation data, and
// the strings "flush" and "die", on an OOAsyncQueue).
struct LogItem
{
	enum Kind: std::uint8_t { kText, kFlush, kDie }	kind;
	std::string							bytes;	// kText: the UTF-8 to write
};


// The queue to the logger thread (was an OOAsyncQueue): any thread enqueues; one thread dequeues,
// blocking until there is an item. Items come out in the order they went in.
class LogQueue
{
public:
	void enqueue(LogItem item)
	{
		{
			std::lock_guard<std::mutex> lock(_lock);
			_incoming.push_back(std::move(item));
		}
		_changed.notify_one();
	}

	LogItem dequeue()
	{
		if (_next == _outgoing.size())
		{
			_outgoing.clear();
			_next = 0;
			std::unique_lock<std::mutex> lock(_lock);
			_changed.wait(lock, [this] { return !_incoming.empty(); });
			_outgoing.swap(_incoming);
		}
		return std::move(_outgoing[_next++]);
	}

	// Only while no thread is dequeuing (a new queue, as the Foundation one was allocated afresh).
	void clear()
	{
		std::lock_guard<std::mutex> lock(_lock);
		_incoming.clear();
		_outgoing.clear();
		_next = 0;
	}

private:
	std::mutex					_lock;
	std::condition_variable		_changed;
	std::vector<LogItem>		_incoming;
	std::vector<LogItem>		_outgoing;	// the dequeuing thread's batch
	std::size_t					_next = 0;
};


// Create (or empty) the log file and open it for writing, as -createFileAtPath:contents:nil
// attributes:nil and +fileHandleForWritingAtPath: did. Unbuffered: each write reaches the file at
// once, as the file handle's did.
std::FILE *CreateLogFile(const std::string &path)
{
#if OOLITE_WINDOWS
	std::FILE *file = _wfopen(oo::fs::pathFromUTF8(path).c_str(), L"wb");
#else
	std::FILE *file = fopen(oo::fs::pathFromUTF8(path).c_str(), "wb");
#endif
	if (file != NULL)  setvbuf(file, NULL, _IONBF, 0);
	return file;
}


// -synchronizeFile: push the file's data to the disk.
void SynchronizeLogFile(std::FILE *file)
{
	if (file == NULL)  return;
	fflush(file);
#if OOLITE_WINDOWS
	_commit(_fileno(file));
#else
	fsync(fileno(file));
#endif
}


// The log file's name (was a static Foundation string; a function-local static, since a static
// std::string's initialization could throw).
std::string &LogFileName()
{
	static std::string sLogFileName = "Latest.log";
	return sLogFileName;
}

}	// namespace


#define kFlushInterval	2.0		// Lower bound on interval between explicit log file flushes.


@interface OOAsyncLogger: OOObject
{
@private
	LogQueue				messageQueue;
	BOOL					haveMessageQueue;	// (the Foundation queue was nil until -startLogging made it)
	
	/*	threadStateMonitor, a Foundation condition lock until bead oo-3rb.7, as its parts: the
		lock, the state it guards (kCondition* below), the broadcast a change makes, and whether
		there is a monitor at all (it was released and set to nil when the thread failed to
		start, which made every later message to it a no-op).
	*/
	std::mutex				threadStateLock;
	std::condition_variable	threadStateChanged;
	int						threadState;
	BOOL					haveThreadStateMonitor;
	
	std::FILE			*logFile;
}

- (void)asyncLogMessage:(std::string)message;
- (void)endLogging;

- (void)changeFile;

// Internal
- (BOOL)startLogging;
- (void)loggerThread;
- (void)flushLog;

@end


static BOOL						sInited = NO;
static BOOL						sWriteToStderr = YES;
static BOOL						sWriteToStdout = NO;
static BOOL						sSaturated = NO;
static OOAsyncLogger			*sLogger = nil;

/*	The pending flush (was a one-shot run-loop timer, proposed ADR-0033): a deadline on
	std::chrono::steady_clock that the frame loop checks. The timer was
	scheduled on the logging thread's run loop, and only the main thread's run
	loop ever runs, so a flush first requested from another thread never fired
	and blocked later ones; kFlushNever keeps that.
*/
static const int64_t				kFlushNever = INT64_MAX;
static std::atomic<bool>			sFlushPending{false};
static std::atomic<int64_t>			sFlushDeadline{kFlushNever};	// steady_clock ticks since its epoch
static std::thread::id				sMainThreadID;


void OOLogOutputHandlerInit(void)
{
	if (sInited)  return;
	
#if SET_CRASH_REPORTER_INFO
	InitCrashReporterInfo();
#endif
	
	sMainThreadID = std::this_thread::get_id();
	sLogger = [[OOAsyncLogger alloc] init];
	sInited = YES;
	
	if (sLogger != nil)
	{
		sWriteToStderr = [[NSUserDefaults standardUserDefaults] boolForKey:@"logging-echo-to-stderr"];
	}
	else
	{
		sWriteToStderr = YES;
	}
	
#if OOLITE_MAC_OS_X
	LoadLogCStringFunctions();
	if (_NSSetLogCStringFunction != NULL)
	{
		sDefaultLogCStringFunction = _NSLogCStringFunction();
		_NSSetLogCStringFunction(OONSLogCStringFunction);
	}
	else
	{
		OOLog(@"logging.nsLogFilter.install.failed", @"Failed to install NSLog() filter; system messages will not be logged in log file.");
	}
#elif GNUSTEP_BASE_LIBRARY
	OOLogOutputHandlerInstallNSLogHook();
#endif
	
	atexit(OOLogOutputHandlerClose);
}


void OOLogOutputHandlerClose(void)
{
	if (sInited)
	{
		sWriteToStderr = YES;
		sInited = NO;
		
		[sLogger endLogging];
		DESTROY(sLogger);
		
#if OOLITE_MAC_OS_X
		if (sDefaultLogCStringFunction != NULL && _NSSetLogCStringFunction != NULL)
		{
			_NSSetLogCStringFunction(sDefaultLogCStringFunction);
			sDefaultLogCStringFunction = NULL;
		}
#elif GNUSTEP_BASE_LIBRARY
		OOLogOutputHandlerRemoveNSLogHook();
#endif
	}
}

void OOLogOutputHandlerStartLoggingToStdout()
{
	sWriteToStdout = true;
}
void OOLogOutputHandlerStopLoggingToStdout()
{
	sWriteToStdout = false;
}

void OOLogOutputHandlerFlushIfDue(void)
{
	if (!sFlushPending || sLogger == nil)  return;
	if (std::chrono::steady_clock::now().time_since_epoch().count() < sFlushDeadline)  return;
	[sLogger flushLog];
}


void cxx_OOLogOutputHandlerPrint(std::string_view string)
{
	if (sInited && sLogger != nil && !sWriteToStdout)  [sLogger asyncLogMessage:std::string(string)];
	
	BOOL doCStringStuff = sWriteToStderr || sWriteToStdout;
#if SET_CRASH_REPORTER_INFO
	doCStringStuff = doCStringStuff || sCrashReporterInfoAvailable;
#endif
	
	if (doCStringStuff)
	{
		const std::string line = std::string(string) + "\n";
		const char *cStr = line.c_str();
		if (sWriteToStdout)
			fputs(cStr, stdout);
		else if (sWriteToStderr)
			fputs(cStr, stderr);
		
#if SET_CRASH_REPORTER_INFO
		if (sCrashReporterInfoAvailable)  SetCrashReporterInfo(cStr);
#endif
	}
	
}


std::optional<std::string> cxx_OOLogHandlerGetLogPath(void)
{
	const std::optional<std::string> basePath = cxx_OOLogHandlerGetLogBasePath();
	if (!basePath.has_value())  return std::nullopt;
	return oo::str::appendingPathComponent(*basePath, LogFileName());
}


void cxx_OOLogOutputHandlerChangeLogFile(const std::string &newLogName)
{
	if (LogFileName() != newLogName)
	{
		LogFileName() = newLogName;
		[sLogger changeFile];
	}
}


enum
{
	kConditionReadyToDealloc = 1,
	kConditionWorking
};


@implementation OOAsyncLogger

- (id)init
{
	BOOL						OK = YES;
	std::optional<std::string>	logPath;
	std::optional<std::string>	oldPath;
	NSFileManager				*fmgr = nil;

	self = [super init];
	if (self == nil)  OK = NO;

	if (OK)
	{
		fmgr = [NSFileManager defaultManager];
		logPath = cxx_OOLogHandlerGetLogPath();

		// If there is an existing file, move it to Previous.log.
		if ([fmgr fileExistsAtPath:oo::NSStringOrNil(logPath)])
		{
			const std::optional<std::string> basePath = cxx_OOLogHandlerGetLogBasePath();
			if (basePath.has_value())  oldPath = oo::str::appendingPathComponent(*basePath, "Previous.log");
			[fmgr oo_removeItemAtPath:oo::NSStringOrNil(oldPath)];
			if (![fmgr oo_moveItemAtPath:oo::NSStringOrNil(logPath) toPath:oo::NSStringOrNil(oldPath)])
			{
				if (![fmgr oo_removeItemAtPath:oo::NSStringOrNil(logPath)])
				{
					NSLog(@"Log setup: could not move or delete existing log at %@, will log to stdout instead.", oo::NSStringOrNil(logPath));
					OK = NO;
				}
			}
		}
	}
	
	if (OK)  OK = [self startLogging];
	
	if (!OK)  DESTROY(self);
	
	return self;
}


- (void)dealloc
{
	messageQueue.clear();
	if (logFile != NULL)
	{
		fclose(logFile);
		logFile = NULL;
	}
	
	[super dealloc];
}


- (BOOL)startLogging
{
	BOOL						OK = YES;
	std::optional<std::string>	logPath;

	if (OK)
	{
		messageQueue.clear();
		haveMessageQueue = YES;
	}
	
	if (OK)
	{
		// set up threadStateMonitor -- used as a binary semaphore of sorts to check when the worker thread starts and stops.
		{
			std::lock_guard<std::mutex> stateLock(threadStateLock);
			threadState = kConditionReadyToDealloc;
		}
		haveThreadStateMonitor = YES;
	}
	
	if (OK)
	{
		// Create work thread to actually handle messages.
		// This needs to be done early to avoid messy state if something goes wrong.
		// The thread holds the handler until -loggerThread returns, as a detached selector thread did.
		[self retain];
		oo::thread::detach([self]()
		{
			@autoreleasepool
			{
				[self loggerThread];
			}
			[self release];
		});
		// Wait for it to start.
		const std::chrono::steady_clock::time_point startDeadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
		std::unique_lock<std::mutex> stateLock(threadStateLock);
		while (threadState != kConditionWorking && threadStateChanged.wait_until(stateLock, startDeadline) != std::cv_status::timeout)  {}
		if (threadState != kConditionWorking)
		{
			stateLock.unlock();
			// If it doesn't signal a start within five seconds, assume something's wrong.
			// Send kill signal, just in case it comes to life...
			messageQueue.enqueue(LogItem{LogItem::kDie, {}});
			// ...and stop -dealloc from waiting for thread death
			haveThreadStateMonitor = NO;
			OK = NO;
		}
		else
		{
			threadState = kConditionWorking;
			threadStateChanged.notify_all();
			stateLock.unlock();
		}
	}
	
	if (OK)
	{
		logPath = cxx_OOLogHandlerGetLogPath();
		OK = logPath.has_value();
	}

	if (OK)
	{
		// Create shiny new log file
		logFile = CreateLogFile(*logPath);
		OK = (logFile != NULL);
		if (!OK)
		{
			NSLog(@"Log setup: could not open log at %@, will log to stdout instead.", oo::NSStringOrNil(logPath));
			OK = NO;
		}
	}
	
	return OK;
}


- (void)endLogging
{
	if (haveMessageQueue && haveThreadStateMonitor)
	{
		// We're fully inited; write postamble, wait for worker thread to terminate cleanly, and close file.
		[self asyncLogMessage:oo::str::format("\nClosing log at %s.", oo::date::description().c_str())];
		messageQueue.enqueue(LogItem{LogItem::kDie, {}});	// Kill message
		{
			std::unique_lock<std::mutex> stateLock(threadStateLock);
			while (threadState != kConditionReadyToDealloc)  threadStateChanged.wait(stateLock);
		}
		
		if (logFile != NULL)
		{
			fclose(logFile);
			logFile = NULL;
		}
	}
}


- (void)changeFile
{
	[self endLogging];
	if (![self startLogging])  sWriteToStderr = YES;
}


- (void)asyncLogMessage:(std::string)message
{
	// Don't log of saturated flag is set.
	if (sSaturated)  return;

	{
		message += "\n";

#if OOLITE_WINDOWS
		// Convert Unix line endings to Windows ones.
		message = oo::str::replaceOccurrences(message, "\n", "\r\n", oo::str::Search::literal);
#endif

		messageQueue.enqueue(LogItem{LogItem::kText, std::move(message)});
		
		if (!sFlushPending.exchange(true))
		{
			// No pending flush
			if (std::this_thread::get_id() == sMainThreadID)
			{
				std::chrono::steady_clock::time_point deadline = std::chrono::steady_clock::now() + std::chrono::duration_cast<std::chrono::steady_clock::duration>(std::chrono::duration<double>(kFlushInterval));
				sFlushDeadline = deadline.time_since_epoch().count();
			}
		}
	}
}


- (void)flushLog
{
	sFlushDeadline = kFlushNever;
	sFlushPending = false;
	messageQueue.enqueue(LogItem{LogItem::kFlush, {}});
}


- (void)loggerThread
{
	void				*pool = NULL;
	NSUInteger			size = 0;
	
	@autoreleasepool
	{
		oo::thread::setCurrentName("loggerThread");
		
		// Signal readiness (the queue is an ivar, and this thread holds the logger)
		if (haveThreadStateMonitor)
		{
			std::lock_guard<std::mutex> stateLock(threadStateLock);
			threadState = kConditionWorking;
			threadStateChanged.notify_all();
		}
		
		@try
		{
			for (;;)
			{
				pool = objc_autoreleasePoolPush();
				
				LogItem message = messageQueue.dequeue();

				if (!sSaturated && message.kind == LogItem::kText)
				{
					size += message.bytes.size();
					if (size > 1 << 30)	// 1 GiB
					{
						sSaturated = YES;
#if OOLITE_WINDOWS
						message.bytes = "\r\n\r\n\r\n***** LOG TRUNCATED DUE TO EXCESSIVE LENGTH *****\r\n";
#else
						message.bytes = "\n\n\n***** LOG TRUNCATED DUE TO EXCESSIVE LENGTH *****\n";
#endif
					}

					if (logFile != NULL)  fwrite(message.bytes.data(), 1, message.bytes.size(), logFile);
				}
				else if (message.kind == LogItem::kFlush)
				{
					SynchronizeLogFile(logFile);
				}
				else if (message.kind == LogItem::kDie)
				{
					break;
				}
				
				objc_autoreleasePoolPop(pool);
			}
		}
		@catch (NSException *exception) {}
		objc_autoreleasePoolPop(pool);
		
		// Clean up; after this, ivars are out of bounds.
		if (haveThreadStateMonitor)
		{
			std::lock_guard<std::mutex> stateLock(threadStateLock);
			threadState = kConditionReadyToDealloc;
			threadStateChanged.notify_all();
		}
	}
}

@end


#if OOLITE_MAC_OS_X

/*	LoadLogCStringFunctions()
	
	We wish to make NSLogv() call our custom function OONSLogCStringFunction()
	rather than printing to stdout, by calling _NSSetLogCStringFunction().
	Additionally, in order to close the logger cleanly, we wish to be able to
	restore the standard logger, which requires us to call
	_NSLogCStringFunction(). These functions are private.
	_NSLogCStringFunction() is undocumented. _NSSetLogCStringFunction() is
	documented at http://docs.info.apple.com/article.html?artnum=70081 ,
	with the warning:
	
		Be aware that this code references private APIs; this is an
		unsupported workaround and users should use these instructions at
		their own risk. Apple will not guarantee or provide support for
		this procedure.
	
	The approach taken here is to load the functions dynamically. This makes
	us safe in the case of Apple removing the functions. In the unlikely event
	that they change the functions' paramters without renaming them, we would
	have a problem.
*/
static void LoadLogCStringFunctions(void)
{
	CFBundleRef						foundationBundle = NULL;
	LogCStringFunctionGetterProc	getter = NULL;
	LogCStringFunctionSetterProc	setter = NULL;
	
	foundationBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.Foundation"));
	if (foundationBundle != NULL)
	{
		getter = CFBundleGetFunctionPointerForName(foundationBundle, CFSTR("_NSLogCStringFunction"));
		setter = CFBundleGetFunctionPointerForName(foundationBundle, CFSTR("_NSSetLogCStringFunction"));
		
		if (getter != NULL && setter != NULL)
		{
			_NSLogCStringFunction = getter;
			_NSSetLogCStringFunction = setter;
		}
	}
}


static void OONSLogCStringFunction(const char *string, unsigned length, BOOL withSyslogBanner)
{
	if (OOLogWillDisplayMessagesInClass(@"system"))
	{
		OOLogWithFunctionFileAndLine(@"system", NULL, NULL, 0, @"%s", string);
	}
}

#endif


namespace {

BOOL DirectoryExistCreatingIfNecessary(const std::string &path)
{
	BOOL				exists, directory;
	NSFileManager		*fmgr =  [NSFileManager defaultManager];

	exists = [fmgr fileExistsAtPath:oo::NSStringFrom(path) isDirectory:&directory];

	if (exists && !directory)
	{
		NSLog(@"Log setup: expected %@ to be a folder, but it is a file.", oo::NSStringFrom(path));
		return NO;
	}
	if (!exists)
	{
		if (![fmgr oo_createDirectoryAtPath:oo::NSStringFrom(path) attributes:nil])
		{
			NSLog(@"Log setup: could not create folder %@.", oo::NSStringFrom(path));
			return NO;
		}
	}

	return YES;
}

}	// namespace


#if OOLITE_MAC_OS_X
static void ExcludeFromTimeMachine(const std::string &path)
{
	OSStatus (*CSBackupSetItemExcluded)(NSURL *item, Boolean exclude, Boolean excludeByPath) = NULL;
	CFBundleRef carbonCoreBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.CoreServices.CarbonCore"));
	if (carbonCoreBundle)
	{
		CSBackupSetItemExcluded = CFBundleGetFunctionPointerForName(carbonCoreBundle, CFSTR("CSBackupSetItemExcluded"));
		if (CSBackupSetItemExcluded != NULL)
		{
			(void)CSBackupSetItemExcluded([NSURL fileURLWithPath:oo::NSStringFrom(path)], YES, NO);
		}
	}
}

static std::string GetAppName(void)
{
	static std::optional<std::string>	appName;
	NSBundle							*bundle = nil;

	if (!appName.has_value())
	{
		bundle = [NSBundle mainBundle];
		appName = oo::OptionalString([bundle objectForInfoDictionaryKey:@"CFBundleName"]);
		if (!appName.has_value())  appName = oo::OptionalString([bundle bundleIdentifier]);
		if (!appName.has_value())  appName = "<unknown application>";
	}

	return *appName;
}
#endif

std::optional<std::string> cxx_OOLogHandlerGetLogBasePath(void)
{
	// (a failure is not remembered, so the next call tries again; the Foundation string was)
	static std::optional<std::string>	sBasePath;

	if (!sBasePath.has_value())
	{
		std::string		basePath;
		const char		*logdirEnv = SDL_getenv("OO_LOGSDIR");

		if (logdirEnv)
		{
			basePath = logdirEnv;
		}
		else
		{
#if OOLITE_MAC_OS_X
			// ~/Library
			basePath = oo::StdString([NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0]);
#elif OOLITE_LINUX
			// ~
			basePath = oo::StdString(NSHomeDirectory());

			// ~/.Oolite
			basePath = oo::str::appendingPathComponent(basePath, ".Oolite");
			if (!DirectoryExistCreatingIfNecessary(basePath))  return std::nullopt;
#elif OOLITE_WINDOWS
			// <Install path>\Oolite
			basePath = oo::StdString(NSHomeDirectory());
#endif

			// .../Logs
			basePath = oo::str::appendingPathComponent(basePath, "Logs");
			if (!DirectoryExistCreatingIfNecessary(basePath))  return std::nullopt;

#if OOLITE_MAC_OS_X
			// ~/Library/Logs/Oolite
			basePath = oo::str::appendingPathComponent(basePath, GetAppName());
			if (!DirectoryExistCreatingIfNecessary(basePath))  return std::nullopt;
#endif
		}
#if OOLITE_MAC_OS_X
		ExcludeFromTimeMachine(basePath);
#endif
		sBasePath = basePath;
	}

	return sBasePath;
}

#if SET_CRASH_REPORTER_INFO

static char **sCrashReporterInfo = NULL;
static char *sOldCrashReporterInfo = NULL;
static std::mutex sCrashReporterInfoLock;

// Evil hackery based on http://www.allocinit.net/blog/2008/01/04/application-specific-information-in-leopard-crash-reports/
static void InitCrashReporterInfo(void)
{
	sCrashReporterInfo = dlsym(RTLD_DEFAULT, "__crashreporter_info__");
	if (sCrashReporterInfo != NULL)
	{
		sCrashReporterInfoAvailable = YES;
	}
}

static void SetCrashReporterInfo(const char *info)
{
	char					*copy = NULL, *old = NULL;
	
	/*	Don't do anything if setup failed or the string is NULL or empty.
		(The NULL and empty checks may not be desirable in other uses.)
	*/
	if (!sCrashReporterInfoAvailable || info == NULL || *info == '\0')  return;
	
	// Copy the string, which we assume to be dynamic...
	copy = strdup(info);
	if (copy == NULL)  return;
	
	/*	...and swap it in.
		Note that we keep a separate pointer to the old value, in case
		something else overwrites __crashreporter_info__.
	*/
	sCrashReporterInfoLock.lock();
	*sCrashReporterInfo = copy;
	old = sOldCrashReporterInfo;
	sOldCrashReporterInfo = copy;
	sCrashReporterInfoLock.unlock();
	
	// Delete our old string.
	if (old != NULL)  free(old);
}

#endif
