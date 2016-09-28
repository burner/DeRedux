module deredux;

import std.array : appender;
import std.format : formattedWrite;
import std.traits;

private string genReducerActionEnum(Type,Reducer)() pure @safe nothrow {
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
}

struct Foo {

}

struct FooRedux {
	Foo fun(const(Foo) foo) {
		return foo;
	}
}

unittest {
	import std.stdio;
	writeln(genReducerActionEnum!(Foo, FooRedux)());
}

struct State(Type,Reducer) {
	Type beginning;
	Type latest;
}
