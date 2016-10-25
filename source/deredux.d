module deredux;

import std.array : appender;
import std.format : formattedWrite;
import std.traits;

struct ImmuWrapper(T) {
	union {
		immutable(T) immu;
		T nImmu;
	}

	this(T v) {
		this.nImmu = v;
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

	auto fooState = State!(Foo)(Foo(1337));
	fooState.exe(&bar);

	FooRedux fr;
	fooState.exe(&fr.fun);
}

struct State(Type) {
	import std.typecons : Rebindable;
	import core.sync.mutex;
	import fixedsizearray;

	FixedSizeArray!(ImmuWrapper!Type,16) state;

	shared(Mutex) mutex;

	this() @disable;

	this(Type initState) {
		this.mutex = cast(shared)(new Mutex());
		this.state.insertBack(ImmuWrapper!Type(initState));
	}

	void exe(F,Args...)(F f, Args args) {
		if(this.state.length + 1 == this.state.capacity()) {
			this.state.removeFront();
		}
		this.state.insertBack(ImmuWrapper!Type(f(this.state.back.immu, args)));
	}
}
