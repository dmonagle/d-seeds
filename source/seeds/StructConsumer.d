module seeds.StructConsumer;

import std.conv;
import vibe.internal.meta.uda;
import vibe.core.log;
import std.traits;
import std.regex;
import std.algorithm;

import seeds.attributes;
import seeds.DataConsumer;
import seeds.ColumnConverter;

template Tuple (T...) {
	alias Tuple = T;
}

private template hasAttribute(alias decl, T) { enum hasAttribute = findFirstUDA!(T, decl).found; }

private template hasConvertableFields(T, size_t idx = 0)
{
	static if (idx < __traits(allMembers, T).length) {
		enum mname = __traits(allMembers, T)[idx];
		static if (!isRWPlainField!(T, mname) && !isRWField!(T, mname)) enum hasConvertableFields = hasConvertableFields!(T, idx+1);
		else static if (!hasAttribute!(__traits(getMember, T, mname), ColumnAttribute)) enum hasConvertableFields = hasConvertableFields!(T, idx+1);
		else enum hasConvertableFields = true;
	} else enum hasConvertableFields = false;
}

package template isRWPlainField(T, string M)
{
	static if( !__traits(compiles, typeof(__traits(getMember, T, M))) ){
		enum isRWPlainField = false;
	} else {
		//pragma(msg, T.stringof~"."~M~":"~typeof(__traits(getMember, T, M)).stringof);
		enum isRWPlainField = isRWField!(T, M) && __traits(compiles, *(&__traits(getMember, Tgen!T(), M)) = *(&__traits(getMember, Tgen!T(), M)));
	}
}

package template isRWField(T, string M)
{
	enum isRWField = __traits(compiles, __traits(getMember, Tgen!T(), M) = __traits(getMember, Tgen!T(), M));
	//pragma(msg, T.stringof~"."~M~": "~(isRWField?"1":"0"));
}

package T Tgen(T)(){ return T.init; }

class StructConsumer(StructType, alias CallBack = (data) {}, ConverterType = DefaultColumnConverter) : DataConsumer {
	private static string defineTranslations() {
		static assert (hasConvertableFields!StructType, StructType.stringof ~ " has no convertable fields");

		string code;
		string enumCode = "enum ColumnType {";
		string mandatoryColumnsCode = "static ColumnType[] _mandatoryColumns = [";
		string columnsCode = "static ColumnType[] _columns = [";
		string matchHeaderCode = "private bool matchHeader(ColumnType column, string data) {";
		string setColumnCode = "private void setColumn(ColumnType column, string data, ref " ~ fullyQualifiedName!StructType ~ " recordStruct) {";

		matchHeaderCode ~= "final switch(column) {";
		setColumnCode ~= "final switch(column) {";

		foreach (memberName; __traits(allMembers, StructType)) {
			static if (isRWPlainField!(StructType, memberName) || isRWField!(StructType, memberName)) {
				alias member = Tuple!(__traits(getMember, StructType, memberName));
				alias memberType = typeof(__traits(getMember, StructType, memberName));

				alias columnUDA = findFirstUDA!(ColumnAttribute, member);

				static if (columnUDA.found) {
					enumCode ~= memberName ~ ",";

					// Check if column is mandatory
					bool mandatoryColumn = true;
					alias optionalUDA = findFirstUDA!(seeds.attributes.OptionalAttribute, member);
					static if (optionalUDA.found && optionalUDA.value.optional) {
						mandatoryColumn = false;
					}
					if (mandatoryColumn) mandatoryColumnsCode ~= "ColumnType." ~ memberName ~ ",";

					// Build the header regex
					alias matchHeaderUDA = findFirstUDA!(MatchHeaderAttribute, member);
					static if (matchHeaderUDA.found) {
						auto headerRegexCode = `ctRegex!(r"` ~ matchHeaderUDA.value.expression ~ `", "` ~ matchHeaderUDA.value.flags ~ `")`;
					} else {
						// Build a regex from the name of the column
						auto headerRegexCode = `ctRegex!(r"` ~ memberName ~ `", "i")`;
					}
					matchHeaderCode ~= "case ColumnType." ~ memberName ~ ": return cast(bool)match(data, " ~ headerRegexCode ~ ");";

					alias convertUDA = findFirstUDA!(ConvertAttribute, member);
					static if (convertUDA.found) {
						pragma(msg, "We have a custom converter for " ~ memberName);
						setColumnCode ~= "case ColumnType." ~ memberName ~ ": recordStruct." ~ memberName ~ " = ConverterType." ~ convertUDA.value.converterName ~ "(data); break;";
					} else {
						setColumnCode ~= "case ColumnType." ~ memberName ~ ": recordStruct." ~ memberName ~ " = ConverterType.convert!(" ~ fullyQualifiedName!memberType ~ ")(data); break;";
					}
				}
			}
		}

		enumCode ~= "}";
		mandatoryColumnsCode ~= "];";
		columnsCode ~= "];";

		matchHeaderCode ~= "}}"; // Close the switch statement and the function
		setColumnCode ~= "}}"; // Close the switch statement and the function

		code ~= enumCode;
		code ~= mandatoryColumnsCode;
		code ~= columnsCode;
		code ~= matchHeaderCode;
		code ~= setColumnCode;

		return code;
	}

	mixin(defineTranslations());

	private {
		StructType _recordStruct;
		bool _foundHeaders;
		bool[ColumnType] _headersRequired;
		ColumnType[int] _headerMap;
	}
	
	@property auto mandatoryColumns() { return _mandatoryColumns; }

	override void startParse() {
		_foundHeaders = false;
	}

	override void startRecord(int lineNumber) {
		if (_foundHeaders) {
			static if (is(StructType == struct))
				_recordStruct = StructType();
			else
			    _recordStruct = new StructType();
		}
		else {
			foreach(c; mandatoryColumns())
				_headersRequired[c] = false;
		}
	}
	
	override void endRecord(int lineNumber, int columnCount, bool hasContent) {
		if (_foundHeaders) {
			if (hasContent) {
				CallBack(_recordStruct);
			}
		}
		else {
			if(all(_headersRequired.values)) {
				logDebug("Found all mandatory headers on line " ~ to!string(lineNumber));
				foreach(key, value; _headerMap) logDebugV("%s: %s", key, value);
				_foundHeaders = true;
			}
		}
	}

	override void endParse(int records) {
		logDebug("Parsing finished. Total lines consumed: " ~ to!string(records));
	}
	
	override void noValueColumn(int columnNumber) {
	}
	
	override void consumeColumn(int columnNumber, string value) {
		if (_foundHeaders) {
			if(columnNumber in _headerMap) {
				setColumn(_headerMap[columnNumber], value, _recordStruct);
			}
		} else {
			foreach (immutable ct; [EnumMembers!ColumnType]) {
				if(matchHeader(ct, value)) {
					_headersRequired[ct] = true;
					_headerMap[columnNumber] = ct;
					logDebug("Found header " ~ to!string(ct));
				}
			}
		}
	}
}


