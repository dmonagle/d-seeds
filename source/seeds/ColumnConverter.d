module seeds.ColumnConverter;

import std.conv;
import std.datetime;
import std.regex;
import std.typecons;

class ColumnConversionException : Exception {
	this(string s) { super(s); }
}

class ColumnConverter(Options ...) {
	static T convert(T)(string data) {
		return to!(T)(data);
	}

	static T convert(T : bool)(string data) {
		if(data.length == 0) return false;
		import std.stdio;
		writeln(data);
		if (match(data, ctRegex!(`^[fn0]`, "i"))) return false;
		return true;
	}

	static T convert(T : Date)(string data) {
		return yearMonthDay(data);
	}
	
	static T convert(T : Nullable!Date)(string data) {
		return yearMonthDay(data);
	}
	
	static T convert(T : Date)(string data) {
		return Date();
	}
	
	static Nullable!Date dayMonthYear(string data) {
		if (!data.length) return Nullable!Date();
		auto m = splitDate(data);
		auto returnDate = Nullable!Date();
		if (m) {
			auto year = convertYear(m.captures[3]);
			returnDate =  Date(year, to!int(m.captures[2]), to!int(m.captures[1]));
		} else {
			throw new ColumnConversionException("Could not convert '" ~ data ~ "' to Date (DMY)");
		}
		return returnDate;
	}
	
	static Nullable!Date monthDayYear(string data) {
		if (!data.length) return Nullable!Date();
		auto returnDate = Nullable!Date();
		auto m = splitDate(data);
		if (m) {
			auto year = convertYear(m.captures[3]);
			returnDate = Date(year, to!int(m.captures[1]), to!int(m.captures[2]));
		} else {
			throw new ColumnConversionException("Could not convert '" ~ data ~ "' to Date (MDY)");
		}
		return returnDate;
	}
	
	static Nullable!Date yearMonthDay(string data) {
		if (!data.length) return Nullable!Date();
		auto returnDate = Nullable!Date();
		static const string separator = `[\\\/-]`;
		static auto dateRegex = ctRegex!(`^(\d{4})` ~ separator ~ `(\d{2})` ~ separator ~ `(\d{2})$`);
		auto m = match(data, dateRegex);
		if (m) {
			returnDate = Date(to!int(m.captures[1]), to!int(m.captures[2]), to!int(m.captures[3]));
		} else {
			throw new ColumnConversionException("Could not convert '" ~ data ~ "' to Date (YYYY-MM-DD)");
		}
		return returnDate;
	}
	
	protected {
		static auto splitDate(string data) {
			static const string separator = `[\\\/-]`;
			static auto dateRegex = ctRegex!(`^(\d{1,2})` ~ separator ~ `(\d{1,2})` ~ separator ~ `(\d{4}|\d{2})$`);
			return match(data, dateRegex);
		}

		static int convertYear(string year) {
			auto y = to!int(year);
			if (y < 100) y += 2000; // For people who have their data storing only the last two digits of a year
			return y;
		}
	}
}

alias DefaultColumnConverter = ColumnConverter!();

unittest {
	assert(DefaultColumnConverter.convert!int("123") == 123);
}

