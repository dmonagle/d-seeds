module seeds.CSVParser;

import std.string;
import std.array;
import std.regex;

public import seeds.DataConsumer;

class CSVParser {
	private {
		const static string EOL = `(\r\n|\r|\n)`;
		const static string COLUMN_TERMINATOR = `,`;

		auto reWhitespace = ctRegex!(`^\s+`);
		auto reEOL = ctRegex!("^" ~ EOL);

		auto reColumnTerminator = ctRegex!("^" ~ COLUMN_TERMINATOR);
		auto reSimpleColumn = ctRegex!(`^[^,"\r\n]+`); // Anything that is not a comma or a double quote or end of line.
		auto reSubColumn = ctRegex!(`^([^"])+`); // Anything that is not a double quote
		auto reDoubleQuote = ctRegex!(`^"`); // A double quote
		auto reDoubleDoubleQuote = ctRegex!(`^""`); // A double double quote

		int _maxConsecutiveEmptyRecords;
		int _consecutiveEmptyRecords;
		int _recordCount;

		string _data;
		size_t _cursor;
		bool _recordHasContent;
		int _columnNumber;
		int _lineNumber;
		DataConsumer _consumer;
	}
	
	@property int maxConsecutiveEmptyRecords() {
		return _maxConsecutiveEmptyRecords;
	}
	
	@property int maxConsecutiveEmptyRecords(int value) {
		return _maxConsecutiveEmptyRecords = value;
	}
	
	@property bool eof() {
		return _data.length == _cursor;
	}
	
	@property size_t cursor() {
		return _cursor;
	}
	
	string next(T)(T regex, bool munch = true) {
		auto c = matchFirst(_data[_cursor..$], regex);
		if (c.length > 0) {
			if(munch) _cursor += c.hit.length;
			return c.hit;
		} 
		return "";
	}

	string parseSimpleColumn() {
		return next(reSimpleColumn, true);
	}
	
	string parseSubColumn() {
		return next(reSubColumn, true);
	}

	string parseEscapedColumn() {
		auto returnString = parseSubColumn();
		while (next(reDoubleDoubleQuote).length) {
			returnString ~= '"';
			returnString ~= parseSubColumn();
		}

		return returnString;
	}
	
	string parseQuotedColumn() {
		auto returnString = parseEscapedColumn();
		assert(next(reDoubleQuote).length == 1);
		return returnString;
	}
	
	void parseRawColumn() {
		string columnValue;
		next(reWhitespace); // Consume whitespace
		if (!next(reColumnTerminator, false).length) {
			if (next(reDoubleQuote).length)
				columnValue = parseQuotedColumn();
			else
				columnValue = parseSimpleColumn();
			_consumer.consumeColumn(_columnNumber, columnValue);
			_recordHasContent = true;
		} else {
			_consumer.noValueColumn(_columnNumber);
		}
	}
	
	void parseRecord() {
		bool nextColumnExpected = true;

		_columnNumber = 0;
		_recordHasContent = false;
		_consumer.startRecord(_lineNumber);

		while(!next(reEOL).length && !eof) {
			parseRawColumn();
			++_columnNumber;
			nextColumnExpected = next(reColumnTerminator).length > 0; // Is there a next column terminator?
		}

		if (nextColumnExpected) // If we finished with a column terminator then there is a trailing empty value
			_consumer.noValueColumn(_columnNumber++);

		_consumer.endRecord(_lineNumber, _columnNumber, _recordHasContent);
		if (_recordHasContent) {
			_recordCount++;
			_consecutiveEmptyRecords = 0;
		} else {
			_consecutiveEmptyRecords++;
		}
		++_lineNumber;
	}
	
	void parse() {
		bool finished;

		_recordCount = 0;
		_consumer.startParse();
		while (!finished) {
			while(next(reEOL).length) { ++_lineNumber; } // Consume empty lines
			parseRecord();
			if (_maxConsecutiveEmptyRecords && (_consecutiveEmptyRecords >= _maxConsecutiveEmptyRecords)) {
				finished = true;
			} else {
				finished = eof;
			}
		}
		_consumer.endParse(_recordCount);
	}
	
	this(string data, DataConsumer consumer) {
		_data = data;
		_consumer = consumer;
	}
}

unittest {
	auto csvData = "one,two,three,four" ~ "\r\n";
	csvData ~= `"With a , comma", multiple words, "With a ""quote""", "and` ~"\n" ~ `last"` ~ "\r\n\r\n";
	csvData ~= `"",,notEmpty ,` ~ "\n";

	auto csvData2 = "1,2,3,4,5,6,7,8,9,10\r\n";
	csvData2 ~= ",,,,,value,,,,\r\n";
	csvData2 ~= ",,,,,,,,,\r\n";
}