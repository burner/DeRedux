module deredux;

import std.array : appender;
import std.format : formattedWrite;
import std.traits;

/*private string genReducerActionEnum(Type,Reducer)() pure @safe nothrow {
	auto app = appender!string();
	app.put("enum {\n");

	foreach(memIt; __traits(allMembers, Reducer)) {
		auto mem = __traits(getMember, Reducer, memIt);	
		static if(isFunction!mem) {
			auto params = Parameter!mem;
			static if(params.length > 0 && is(params[0] == const(Type))) {
				formattedWrite(app, "%s,", memIt);
			}
		}
	}

	return app.data;
}*/

struct ImmuWrapper(T) {
	union {
		immutable(T) immu;
		T nImmu;
	}
}

struct Foo {
	int value;
}

struct FooRedux {
	Foo fun(const(Foo) foo) {
		return cast(Foo)foo;
	}
}

Foo bar(const(Foo) foo) {
	return cast(Foo)foo;
}

unittest {
	import std.stdio;

	State!(Foo) fooState;
	fooState.exe(&bar);

	FooRedux fr;
	fooState.exe(&fr.fun);
}

struct State(Type) {
	import std.typecons : Rebindable;
	import core.sync;

	shared(byte[(ImmuWrapper!Type).sizeof * 32]) stats;
	shared(int) low;
	shared(int) high;
	shared(ImmuWrapper!Type) latest;
	shared(Mutex) mutex;

	this() {
		this.mutex = new shared(Mutex)();
	}

	this(Type initState) {
		this();
	}

	void exe(F,Args...)(F f, Args args) {
		this.beginning.nImmu = f(this.beginning.immu, args);
	}
}
