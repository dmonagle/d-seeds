module seeds.DataConsumer;

interface DataConsumer {
	void startParse();
	void endParse(int records);
	void startRecord(int lineNumber);
	void endRecord(int lineNumber, int columnCount, bool hasContent = true);
	void noValueColumn(int columnNumber);
	void consumeColumn(int columnNumber, string value);
}

