module deredux;

import std.array : appender;
import std.format : formattedWrite;
import std.traits;

private struct ImmuWrapper(T) {
	union {
		immutable(T) immu;
		T nImmu;
	}

	this(T v) {
		this.nImmu = v;
	}
}

private struct Data(T) {
	import core.sync.mutex;
	immutable(T)* data;

	this(immutable(T)* data) {
		this.data = data;
	}

	this() @disable;

	this(this) @disable {}
	void opAssign(T)(T other) @disable {}

	alias get this;

	ref immutable(T) get() {
		return *this.data;
	}
}

private union Parameters {
	ubyte Ubyte;
	ushort Ushort;
	uint Uint;
	ulong Ulong;
	byte Byte;
	short Short;
	int Int;
	long Long;
	string String;
	wstring Wstring;
	dstring Dstring;
	bool Bool;
}

private struct StringParameter {
	import fixedsizearray;
	import taggedalgebraic;

	string funcName;
	int line;
	FixedSizeArray!(TaggedAlgebraic!Parameters,16) parameters; 

	this(Args...)(string funcName, int line, Args args) {
		this.funcName = funcName;
		this.line = line;
		foreach(it; args) {
			this.parameters.insertBack(it);
		}
	}
}

/** State can be your single source of truth if you let it.
Call `exe` to run a function and use to `peek` to have a look at the last
version of `immutable(Type)`. You should not hold a copy of the data returned
by `peek`.
*/
struct State(Type,int Size = 16) {
	import std.typecons : Rebindable;
	import std.variant : Variant;
	import core.sync.mutex;
	import fixedsizearray;
	import taggedalgebraic;

	FixedSizeArray!(ImmuWrapper!Type,Size) state;
	FixedSizeArray!(StringParameter,Size - 1) parameter;

	this() @disable;

	this(Type initState) {
		this.state.insertBack(ImmuWrapper!Type(initState));
	}

	void exe(F,int line = __LINE__ ,Args...)(F f, Args args) {
		if(this.state.length + 1 == this.state.capacity()) {
			this.state.removeFront();
			this.parameter.removeFront();
		}
		this.state.insertBack(ImmuWrapper!Type(f(this.state.back.immu, args)));
		this.parameter.insertBack(StringParameter(
				fullyQualifiedName!(F), line, args
		));
	}

	Data!(Type) peek() {
		return Data!(Type)(&this.state.back.immu);
	}

	/** Call this to get an output of the last few states and the passed
	parameter.
	*/
	string toString() const {
		import std.array : appender;
		auto app = appender!string();

		this.toString(app);
		return app.data;
	}

	void toString(D)(D app) const {
		import std.stdio;
		import std.format : formattedWrite;

		for(int i = 0; i < this.parameter.length; ++i) {
			formattedWrite(app, "%2d %s line %d: %s(", this.parameter.length - i,
					this.state[i].immu, this.parameter[i].line,
					this.parameter[i].funcName
			);
			bool first = true;
			foreach(it; this.parameter[i].parameters[]) {
				if(first) {
					formattedWrite(app, "%s", it);
				} else {
					formattedWrite(app, ",%s", it);
				}
				first = false;
			}
			formattedWrite(app, ")\n");
		}
		formattedWrite(app, "%2d %s", 0, this.state.back.immu);
	}
}

/// Ditto
unittest {
	struct Foo {
		int value;
	}
	
	struct FooRedux {
		Foo fun(const(Foo) foo) {
			return Foo(foo.value + 2);
		}
	}
	
	Foo bar(const(Foo) foo, int i) {
		return Foo(foo.value + i);
	}
	import std.stdio;
	import exceptionhandling;

	const begin = 1337;

	auto fooState = State!(Foo)(Foo(begin));

	int cnt = 0;
	for(int i = 1; i <= 126; ++i) {
		fooState.exe(&bar, i);
		cnt += i;
		cast(void)assertEqual(fooState.peek().value, begin + cnt);
	}

	cast(void)assertEqual(fooState.peek().value, begin + cnt);

	auto f = fooState.peek();

	FooRedux fr;
	fooState.exe(&fr.fun);
	writeln(fooState.toString());
}
