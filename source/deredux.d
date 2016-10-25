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

struct Data(T) {
	import core.sync.mutex;
	immutable(T)* data;
	Mutex* muPtr;

	this(immutable(T)* data, shared(Mutex*) muPtr) {
		this.data = data;
		this.muPtr = cast(Mutex*)muPtr;
	}

	this() @disable;

	~this() {
		(*this.muPtr).unlock();
	}

	this(this) @disable {}
	void opAssign(T)(T other) @disable {}

	alias get this;

	ref immutable(T) get() {
		return *this.data;
	}

	ref immutable(T) opCast(T)() {
		return *this.data;
	}
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
		Mutex mu = cast(Mutex)this.mutex;
		mu.lock();
		scope(exit) mu.unlock();

		if(this.state.length + 1 == this.state.capacity()) {
			this.state.removeFront();
		}
		this.state.insertBack(ImmuWrapper!Type(f(this.state.back.immu, args)));
	}

	Data!(Type) peek() {
		Mutex mu = cast(Mutex)this.mutex;
		mu.lock();
		return Data!(Type)(&this.state.back.immu, &this.mutex);
	}
}

struct Foo {
	int value;
}

struct FooRedux {
	Foo fun(const(Foo) foo) {
		return Foo(foo.value + 2);
	}
}

Foo bar(const(Foo) foo) {
	return Foo(foo.value + 1);
}

unittest {
	import std.stdio;
	import exceptionhandling;

	const begin = 1337;

	auto fooState = State!(Foo)(Foo(begin));

	int cnt = 126;
	for(int i = 1; i <= cnt; ++i) {
		fooState.exe(&bar);
		cast(void)assertEqual(fooState.peek().value, begin + i);
	}

	cast(void)assertEqual(fooState.peek().value, begin + cnt);

	auto f = fooState.peek();
	pragma(msg, typeof(f));

	FooRedux fr;
	fooState.exe(&fr.fun);
}
