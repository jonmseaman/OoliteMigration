/*	oofnd/objc/OOException.h
	The Foundation-free Objective-C exception (proposed ADR-0029 Decision 4, bead oo-3rb.5).

	Exceptions stay Objective-C in Phase 2: @try/@catch/@finally are kept exactly as they are,
	only the thrown object changes. A C++ exception would not be caught by the game's
	`@catch (id)` sites (ADR-0029 measurement 10), so moving to C++ exceptions waits for Phase 3,
	class by class.

	    NSException                                   OOException
	    --------------------------------------------  ----------------------------------------------
	    [NSException raise:NSInvalidArgumentException [OOException raise:OOInvalidArgumentException
	                format:@"bad %@", x]                          format:"bad %s", ...]  (printf)
	    [NSException exceptionWithName:reason:        [OOException exceptionWithName:reason:
	                              userInfo:nil]                                  ]  (const char *)
	    [e raise], @throw e                           the same
	    @catch (NSException *e)                       @catch (OOException *e)
	    [e name], [e reason] (NSString *)             [e name], [e reason] (const char *, UTF-8)
	    NSInvalidArgumentException & co. (NSString)   OOInvalidArgumentException & co.: const char *
	                                                  with the SAME text, so logged names do not change

	+raise:format: never returns. %@ has no meaning in the format: callers pass UTF-8 strings
	(%s), class names (class_getName) and selector names (sel_getName) instead.

	Transition note: until every raise site in a call chain is converted, a `@catch (NSException *)`
	does not catch an OOException (and vice versa); `@catch (id)` catches both. Convert a raise
	site together with the handlers that expect it, or leave the handler as `@catch (id)`.
*/

#ifndef OOFND_OBJC_OOEXCEPTION_H
#define OOFND_OBJC_OOEXCEPTION_H

#include "oofnd/objc/OOObject.h"

#ifdef __cplusplus
extern "C" {
#endif

// Exception names. The text is Foundation's, so a name that reaches a log reads as it did.
extern const char *const OOGenericException;
extern const char *const OOInvalidArgumentException;
extern const char *const OORangeException;
extern const char *const OOInternalInconsistencyException;
extern const char *const OOMallocException;

/*	+[OOException raise:name format:...] as a function, for converted C++ code (Phase 3, proposed
	ADR-0056 amendment oo-dqxj). Since bead oo-rskgl.1 it throws the C++ oo::Exception
	(oofnd/Exception.hpp) with the same name and formatted reason, not the Objective-C object; the
	game's handlers catch it with oo::CurrentOOException() or catch (const oo::Exception &).
	Never returns.
*/
void OORaiseException(const char *name, const char *format, ...) __attribute__((format(printf, 2, 3), noreturn));

#ifdef __cplusplus
}
#endif

@interface OOException : OOObject

// Autoreleased, like +[NSException exceptionWithName:reason:userInfo:]. Both strings are copied;
// nil/NULL becomes "".
+ (id) exceptionWithName:(const char *)name reason:(const char *)reason;

// Formats the reason with printf semantics, then throws. Never returns.
+ (void) raise:(const char *)name format:(const char *)format, ... __attribute__((format(printf, 2, 3), noreturn));

- (id) initWithName:(const char *)name reason:(const char *)reason;

// UTF-8, owned by the exception: valid while it is alive.
- (const char *) name;
- (const char *) reason;

// @throw self. Never returns.
- (void) raise __attribute__((noreturn));

@end

#ifdef __cplusplus
#include "oofnd/Exception.hpp"
#include <optional>
#include <utility>

namespace oo {

/*	The game's @try/@catch/@finally as C++ try/catch (ADR-0056 amendment oo-rskgl). Since bead
	oo-rskgl.1 the thrown object is the C++ oo::Exception (OORaiseException), so the handlers ask for
	that:

	    @catch (OOException *e) { ... [e name] ... }   catch (...)
	                                                    {
	                                                        const auto e = oo::CurrentOOException();
	                                                        if (!e)  throw;	// not an OOException: on up
	                                                        ... e->name() ...
	                                                    }
	    @throw e;  (inside that handler)                throw;  (the same object, rethrown)
	    @catch (id e) { ... }                           catch (const oo::Exception &e) { ... }  (what
	                                                    src throws; no Objective-C object is thrown)
	    @catch (id e) {}                                catch (...)
	                                                    {
	                                                        if (!oo::CurrentOOException())  throw;
	                                                    }  (the same, without an empty handler)
	    @try { A } @finally { B }                       { oo::Finally f([&] { B }); A }

	CurrentOOException() tells the game's exception from anything else, as @catch (OOException *)
	did.
*/
class CaughtOOException
{
public:
	explicit CaughtOOException(const oo::Exception *exception) : _exception(exception) {}

	// [exception name], [exception reason]: UTF-8, valid while the handler runs.
	const char *name() const  { return _exception->name(); }
	const char *reason() const  { return _exception->reason(); }

	// The exception itself, for an interface that still takes one.
	const oo::Exception *object() const  { return _exception; }

private:
	const oo::Exception	*_exception;
};

// Inside a catch handler only: the exception being handled when it is the game's oo::Exception,
// else std::nullopt (the handler then rethrows with `throw;`, as @catch (OOException *) let it pass).
std::optional<CaughtOOException> CurrentOOException();


// @finally: runs the body when the scope is left, normally or by an exception, after the handlers.
template <typename Body>
class Finally
{
public:
	explicit Finally(Body body) : _body(std::move(body)) {}
	~Finally() noexcept(false)  { _body(); }

	Finally(const Finally &) = delete;
	Finally &operator=(const Finally &) = delete;

private:
	Body			_body;
};

}	// namespace oo
#endif	// __cplusplus

#endif	// OOFND_OBJC_OOEXCEPTION_H
