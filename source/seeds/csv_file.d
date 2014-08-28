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


void seedFromCsvFile(StructConverter, alias pred = record => record.save())(string fileName) {
	auto data = cast(string)read(fileName);

	seedFromCsvData!(StructConverter, pred)(data);
}
