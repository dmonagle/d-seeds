module seeds.attributes;

struct ColumnAttribute {
}

struct OptionalAttribute {
	bool optional;
}

struct MatchHeaderAttribute {
	string expression;
	string flags = "i";
}

struct ConvertAttribute {
	string converterName;
}

MatchHeaderAttribute matchHeader(string expression) {
	return MatchHeaderAttribute(expression);
}

@property ColumnAttribute column() {
	return ColumnAttribute();
}

@property OptionalAttribute optional(bool value = true) {
	return OptionalAttribute(value);
}

@property ConvertAttribute convert(string converterName) {
	return ConvertAttribute(converterName);
}
