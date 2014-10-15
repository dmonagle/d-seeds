module seeds.csv_file;

import std.file;
import std.stdio;

import seeds.StructConsumer;
import seeds.ColumnConverter;
import seeds.CSVParser;

void seedFromCsvData(StructConverter, alias pred = record => record.save())(string data) {
	static if (__traits(hasMember, StructConverter, "ColumnConverter"))
		alias ColumnConverter = StructConverter.ColumnConverter;
	else
		alias ColumnConverter = DefaultColumnConverter;
	
	auto consumer = new StructConsumer!(StructConverter, pred
	                                    
	                                    , ColumnConverter);
	
	auto parser = new CSVParser(data, consumer);
	parser.maxConsecutiveEmptyRecords = 0;
	parser.parse();
}


void seedFromCsvFile(StructConverter, alias pred = record => record.save())(string fileName, bool filterNonAscii = true) {
	import std.algorithm;
	import std.array;

	if (exists(fileName)) {
		auto fileContent = cast(ubyte[])(std.file.read(fileName));
		if (filterNonAscii) fileContent = fileContent.filter!((ubyte a) => a < 128).array;
		auto data = cast(string) fileContent;

		seedFromCsvData!(StructConverter, pred)(data);
	}
}

