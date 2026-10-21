"
Tokenizer for GraphQL source text. Use (GQLLexer on: aString) then #peek / #next to obtain GQLToken instances. Skips whitespace, commas, BOM and # comments. Signals GQLSyntaxError.
"
Class {
	#name : 'GQLLexer',
	#superclass : 'Object',
	#instVars : [
		'stream',
		'line',
		'column',
		'peeked'
	],
	#category : 'GraphQL-Core-Lexer',
	#package : 'GraphQL-Core',
	#tag : 'Lexer'
}

{ #category : 'utilities' }
GQLLexer class >> blockStringValue: aString [
	"Apply the GraphQL block string algorithm: remove the common indentation
	(ignoring the first line) and leading/trailing blank lines. Lines are joined with LF."

	| lines commonIndent isBlank |
	isBlank := [ :each |
		           each allSatisfy: [ :ch |
			           ch = Character space or: [ ch = Character tab ] ] ].
	lines := (Character lf split: aString) asOrderedCollection.
	commonIndent := nil.
	lines allButFirst do: [ :each |
			| indent |
			indent := each findFirst: [ :ch |
				          ch ~= Character space and: [ ch ~= Character tab ] ].
			indent > 0 ifTrue: [
					commonIndent := commonIndent
						                ifNil: [ indent - 1 ]
						                ifNotNil: [ commonIndent min: indent - 1 ] ] ].
	commonIndent ifNotNil: [
			2 to: lines size do: [ :i |
					lines
						at: i
						put:
						((lines at: i) allButFirst:
							 (commonIndent min: (lines at: i) size)) ] ].
	[ lines notEmpty and: [ isBlank value: lines first ] ] whileTrue: [
		lines removeFirst ].
	[ lines notEmpty and: [ isBlank value: lines last ] ] whileTrue: [
		lines removeLast ].
	^ String lf join: lines
]

{ #category : 'utilities' }
GQLLexer class >> escapedCharacters [
	"Character following a backslash in a string -> escaped Character (\u escapes are handled separately)"

	^ Dictionary new
		  at: $" put: $";
		  at: $\ put: $\;
		  at: $/ put: $/;
		  at: $b put: Character backspace;
		  at: $f put: Character newPage;
		  at: $n put: Character lf;
		  at: $r put: Character cr;
		  at: $t put: Character tab;
		  yourself
]

{ #category : 'instance creation' }
GQLLexer class >> on: aString [

	^ self new setSource: aString
]

{ #category : 'private - reading' }
GQLLexer >> advance [
	"Consume one character, keeping line/column up to date. Line terminators (CR, LF, CRLF) are answered as LF"

	| char |
	char := stream next.
	char = Character cr ifTrue: [
		stream peek = Character lf ifTrue: [ stream next ].
		line := line + 1.
		column := 1.
		^ Character lf ].
	char = Character lf ifTrue: [
		line := line + 1.
		column := 1.
		^ char ].
	column := column + 1.
	^ char
]

{ #category : 'testing' }
GQLLexer >> atEnd [

	^ self peek isEOF
]

{ #category : 'private - testing' }
GQLLexer >> atTripleQuote [

	^ stream peek = $" and: [ (self lookAhead: 2) = $" and: [ (self lookAhead: 3) = $" ] ]
]

{ #category : 'accessing' }
GQLLexer >> column [

	^ column
]

{ #category : 'private - errors' }
GQLLexer >> describeChar: aCharacter [

	aCharacter ifNil: [ ^ '<EOF>' ].
	^ (aCharacter codePoint < 16r20 or: [ aCharacter codePoint = 16r7F ])
		  ifTrue: [ 'U+' , (aCharacter codePoint printStringBase: 16 length: 4 padded: true) ]
		  ifFalse: [ '"' , aCharacter asString , '"' ]
]

{ #category : 'private - testing' }
GQLLexer >> isDigit: aCharacter [

	^ aCharacter notNil and: [ aCharacter between: $0 and: $9 ]
]

{ #category : 'private - testing' }
GQLLexer >> isIgnored: aCharacter [

	^ aCharacter = Character space or: [
		  aCharacter = Character tab or: [
			  aCharacter = $, or: [ (self isLineTerminator: aCharacter) or: [ aCharacter codePoint = 16rFEFF ] ] ] ]
]

{ #category : 'private - testing' }
GQLLexer >> isLineTerminator: aCharacter [

	^ aCharacter = Character cr or: [ aCharacter = Character lf ]
]

{ #category : 'private - testing' }
GQLLexer >> isNameContinue: aCharacter [

	^ (self isNameStart: aCharacter) or: [ self isDigit: aCharacter ]
]

{ #category : 'private - testing' }
GQLLexer >> isNameStart: aCharacter [

	^ aCharacter notNil and: [
		  aCharacter = $_ or: [ (aCharacter between: $a and: $z) or: [ aCharacter between: $A and: $Z ] ] ]
]

{ #category : 'accessing' }
GQLLexer >> line [

	^ line
]

{ #category : 'private - reading' }
GQLLexer >> lookAhead: anInteger [
	"Answer the character at offset anInteger from the current position (1 = next character), or nil"

	| position char |
	position := stream position.
	char := nil.
	anInteger timesRepeat: [ char := stream next ].
	stream position: position.
	^ char
]

{ #category : 'accessing' }
GQLLexer >> next [
	"Answer and consume the next token. At end of input, answers #eof tokens forever"

	| token |
	token := self peek.
	peeked := nil.
	^ token
]

{ #category : 'accessing' }
GQLLexer >> peek [
	"Answer the next token without consuming it"

	^ peeked ifNil: [ peeked := self readToken ]
]

{ #category : 'private - reading' }
GQLLexer >> readBlockStringLine: aLine column: aColumn [

	| ws |
	ws := WriteStream on: String new.
	3 timesRepeat: [ self advance ].
	[
		stream peek ifNil: [ ^ self syntaxError: 'Unterminated string.' ].
		self atTripleQuote ] whileFalse: [
			(stream peek = $\ and: [
					 (self lookAhead: 2) = $" and: [
						 (self lookAhead: 3) = $" and: [ (self lookAhead: 4) = $" ] ] ])
				ifTrue: [
						4 timesRepeat: [ self advance ].
						ws nextPutAll: '"""' ]
				ifFalse: [ ws nextPut: self advance ] ].
	3 timesRepeat: [ self advance ].
	^ GQLToken
		  kind: #blockString
		  value: (self class blockStringValue: ws contents)
		  line: aLine
		  column: aColumn
]

{ #category : 'private - reading' }
GQLLexer >> readDigitsInto: aWriteStream [

	(self isDigit: stream peek) ifFalse: [
		^ self syntaxError: 'Invalid number, expected digit but got: ' , (self describeChar: stream peek) ].
	[ self isDigit: stream peek ] whileTrue: [ aWriteStream nextPut: self advance ]
]

{ #category : 'private - reading' }
GQLLexer >> readEscapeInto: aWriteStream [
	"The backslash has already been consumed"

	| char escaped |
	char := stream peek.
	(char isNil or: [ self isLineTerminator: char ]) ifTrue: [
		^ self syntaxError: 'Unterminated string.' ].
	char = $u ifTrue: [
			self advance.
			^ aWriteStream nextPut: self readUnicodeEscape ].
	escaped := self class escapedCharacters at: char ifAbsent: [
			           ^ self syntaxError:
				             'Invalid character escape sequence: \'
				             , char asString ].
	self advance.
	^ aWriteStream nextPut: escaped
]

{ #category : 'private - reading' }
GQLLexer >> readHex4 [

	| code |
	code := 0.
	4 timesRepeat: [
		| char digit |
		char := stream peek.
		digit := char ifNil: [ 0 ] ifNotNil: [ '0123456789abcdef' indexOf: char asLowercase ].
		digit = 0 ifTrue: [ ^ self syntaxError: 'Invalid Unicode escape sequence.' ].
		self advance.
		code := code * 16 + digit - 1 ].
	^ code
]

{ #category : 'private - reading' }
GQLLexer >> readNameLine: aLine column: aColumn [

	| ws |
	ws := WriteStream on: String new.
	[ self isNameContinue: stream peek ] whileTrue: [ ws nextPut: self advance ].
	^ GQLToken kind: #name value: ws contents line: aLine column: aColumn
]

{ #category : 'private - reading' }
GQLLexer >> readNumberLine: aLine column: aColumn [
	"-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)? ; the token value keeps the source text"

	| ws isFloat |
	ws := WriteStream on: String new.
	isFloat := false.
	stream peek = $- ifTrue: [ ws nextPut: self advance ].
	stream peek = $0
		ifTrue: [
				ws nextPut: self advance.
				(self isDigit: stream peek) ifTrue: [
						^ self syntaxError:
							  'Invalid number, unexpected digit after 0: '
							  , (self describeChar: stream peek) ] ]
		ifFalse: [ self readDigitsInto: ws ].
	stream peek = $. ifTrue: [
			isFloat := true.
			ws nextPut: self advance.
			self readDigitsInto: ws ].
	('eE' includes: stream peek) ifTrue: [
			isFloat := true.
			ws nextPut: self advance.
			('+-' includes: stream peek) ifTrue: [ ws nextPut: self advance ].
			self readDigitsInto: ws ].
	(stream peek = $. or: [ self isNameStart: stream peek ]) ifTrue: [
			^ self syntaxError: 'Invalid number, expected digit but got: '
				  , (self describeChar: stream peek) ].
	^ GQLToken
		  kind: (isFloat
				   ifTrue: [ #float ]
				   ifFalse: [ #int ])
		  value: ws contents
		  line: aLine
		  column: aColumn
]

{ #category : 'private - reading' }
GQLLexer >> readSpreadLine: aLine column: aColumn [

	((self lookAhead: 2) = $. and: [ (self lookAhead: 3) = $. ]) ifFalse: [
		^ self syntaxError: 'Unexpected character: "."' line: aLine column: aColumn ].
	3 timesRepeat: [ self advance ].
	^ GQLToken kind: #punct value: '...' line: aLine column: aColumn
]

{ #category : 'private - reading' }
GQLLexer >> readStringLine: aLine column: aColumn [

	| ws char |
	ws := WriteStream on: String new.
	self advance.
	[
	char := stream peek.
	(char isNil or: [ self isLineTerminator: char ]) ifTrue: [ ^ self syntaxError: 'Unterminated string.' ].
	char = $" ] whileFalse: [
		char = $\
			ifTrue: [
				self advance.
				self readEscapeInto: ws ]
			ifFalse: [ ws nextPut: self advance ] ].
	self advance.
	^ GQLToken kind: #string value: ws contents line: aLine column: aColumn
]

{ #category : 'private - reading' }
GQLLexer >> readToken [

	| char startLine startColumn |
	self skipIgnored.
	startLine := line.
	startColumn := column.
	char := stream peek.
	char ifNil: [ ^ GQLToken kind: #eof value: nil line: startLine column: startColumn ].
	('!$&()[]{}:=@|' includes: char) ifTrue: [
		self advance.
		^ GQLToken kind: #punct value: char asString line: startLine column: startColumn ].
	char = $. ifTrue: [ ^ self readSpreadLine: startLine column: startColumn ].
	(self isNameStart: char) ifTrue: [ ^ self readNameLine: startLine column: startColumn ].
	(char = $- or: [ self isDigit: char ]) ifTrue: [ ^ self readNumberLine: startLine column: startColumn ].
	char = $" ifTrue: [
		^ ((self lookAhead: 2) = $" and: [ (self lookAhead: 3) = $" ])
			  ifTrue: [ self readBlockStringLine: startLine column: startColumn ]
			  ifFalse: [ self readStringLine: startLine column: startColumn ] ].
	^ self syntaxError: 'Unexpected character: ' , (self describeChar: char)
]

{ #category : 'private - reading' }
GQLLexer >> readUnicodeEscape [
	"Answer the Character of a \uXXXX escape (the \u has already been consumed), combining a UTF-16 surrogate pair"

	| code low |
	code := self readHex4.
	(code between: 16rD800 and: 16rDBFF) ifTrue: [
			(stream peek = $\ and: [ (self lookAhead: 2) = $u ]) ifFalse: [
				^ self syntaxError: 'Invalid Unicode escape sequence.' ].
			self
				advance;
				advance.
			low := self readHex4.
			(low between: 16rDC00 and: 16rDFFF) ifFalse: [
				^ self syntaxError: 'Invalid Unicode escape sequence.' ].
			code := code - 16rD800 * 16r400 + (low - 16rDC00) + 16r10000 ].
	(code between: 16rDC00 and: 16rDFFF) ifTrue: [
		^ self syntaxError: 'Invalid Unicode escape sequence.' ].
	^ Character value: code
]

{ #category : 'initialization' }
GQLLexer >> setSource: aString [

	stream := ReadStream on: aString.
	line := 1.
	column := 1.
	peeked := nil
]

{ #category : 'private - reading' }
GQLLexer >> skipIgnored [
	"Skip whitespace, line terminators, commas, BOM and comments"

	[
	| char |
	char := stream peek.
	char notNil and: [ (self isIgnored: char) or: [ char = $# ] ] ] whileTrue: [
		stream peek = $#
			ifTrue: [ [ stream peek notNil and: [ (self isLineTerminator: stream peek) not ] ] whileTrue: [ self advance ] ]
			ifFalse: [ self advance ] ]
]

{ #category : 'private - errors' }
GQLLexer >> syntaxError: aString [

	^ self syntaxError: aString line: line column: column
]

{ #category : 'private - errors' }
GQLLexer >> syntaxError: aString line: aLine column: aColumn [

	^ GQLSyntaxError
		  signal: ((aString endsWith: '.')
				   ifTrue: [ aString ]
				   ifFalse: [ aString , '.' ])
		  line: aLine
		  column: aColumn
]
