"
Unit tests for GQLLexer / GQLToken / GQLSyntaxError: punctuators, names, numbers, strings, block strings, ignored tokens, positions and lexical errors.
"
Class {
	#name : 'GQLLexerTest',
	#superclass : 'TestCase',
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'helpers' }
GQLLexerTest >> assertSyntaxErrorIn: aString line: aLine column: aColumn [
	"Lex aString fully and answer the GQLSyntaxError that must be raised at aLine/aColumn"

	| error |
	error := nil.
	[ self tokensOf: aString ]
		on: GQLSyntaxError
		do: [ :e | error := e ].
	self assert: error notNil description: 'Expected a GQLSyntaxError'.
	self assert: error line equals: aLine.
	self assert: error column equals: aColumn.
	^ error
]

{ #category : 'tests' }
GQLLexerTest >> testBOMIsIgnored [
	"A leading byte order mark is skipped but still counts as a column (as in graphql-js)"

	| token |
	token := (GQLLexer on:
		          (String with: (Character value: 16rFEFF)) , 'abc') next.
	self assert: (token isName: 'abc').
	self assert: token line equals: 1.
	self assert: token column equals: 2
]

{ #category : 'tests' }
GQLLexerTest >> testBlockString [
	"Block strings: common indentation removed, leading/trailing blank lines dropped, no escape processing"

	| token |
	token := (GQLLexer on: '"""
    hello
      world \n
    """') next.
	self assert: token kind equals: #blockString.
	self assert: token line equals: 1.
	self assert: token column equals: 1.
	self
		assert: token value
		equals: 'hello' , (String with: Character lf) , '  world \n'
]

{ #category : 'tests' }
GQLLexerTest >> testBlockStringEscapedTripleQuote [

	| token |
	token := (GQLLexer on: '"""a \""" b"""') next.
	self assert: token kind equals: #blockString.
	self assert: token value equals: 'a """ b'
]

{ #category : 'tests' }
GQLLexerTest >> testBlockStringValue [
	"Class-side dedent algorithm (spec BlockStringValue): first line is not part of the common indent"

	| lf |
	lf := String with: Character lf.
	self
		assert:
		(GQLLexer blockStringValue:
			 lf , '    a' , lf , '      b' , lf , '  ')
		equals: 'a' , lf , '  b'.
	self
		assert: (GQLLexer blockStringValue: 'first' , lf , '  second')
		equals: 'first' , lf , 'second'.
	self assert: (GQLLexer blockStringValue: '') equals: ''
]

{ #category : 'tests' }
GQLLexerTest >> testCommentsAndCommasAreIgnored [

	| tokens |
	tokens := self tokensOf: '# leading comment
a,, b # trailing comment
,c'.
	self
		assert: (tokens collect: [ :t | t value ]) asArray
		equals: #( 'a' 'b' 'c' ).
	self assert: tokens first line equals: 2.
	self assert: tokens third line equals: 3.
	self assert: tokens third column equals: 2
]

{ #category : 'tests' }
GQLLexerTest >> testEOF [

	| lexer token |
	lexer := GQLLexer on: '  # only a comment
 , ,'.
	token := lexer next.
	self assert: token isEOF.
	self assert: token kind equals: #eof.
	self assert: token line equals: 2.
	self assert: token column equals: 5.
	"EOF is sticky"
	self assert: lexer next isEOF.
	self assert: (GQLLexer on: '') next isEOF
]

{ #category : 'tests' }
GQLLexerTest >> testFloats [
	"Fraction and/or exponent make a float; exponent sign and case are accepted"

	| tokens |
	tokens := self tokensOf: '1.5 -0.25 3.5e-2 1E10 2e+3 -4.0E2'.
	self assert: (tokens allSatisfy: [ :t | t kind = #float ]).
	self
		assert: (tokens collect: [ :t | t value ]) asArray
		equals: #( '1.5' '-0.25' '3.5e-2' '1E10' '2e+3' '-4.0E2' )
]

{ #category : 'tests' }
GQLLexerTest >> testIncompleteSpread [

	self assertSyntaxErrorIn: '..' line: 1 column: 1.
	self should: [ self tokensOf: '. a' ] raise: GQLSyntaxError
]

{ #category : 'tests' }
GQLLexerTest >> testIntegers [
	"Int token values keep their source text"

	| tokens |
	tokens := self tokensOf: '0 42 -12 -0'.
	self assert: (tokens allSatisfy: [ :t | t kind = #int ]).
	self
		assert: (tokens collect: [ :t | t value ]) asArray
		equals: #( '0' '42' '-12' '-0' )
]

{ #category : 'tests' }
GQLLexerTest >> testInvalidCharacter [

	| error |
	error := self
		         assertSyntaxErrorIn: 'a
  ?'
		         line: 2
		         column: 3.
	self assert: error reason equals: 'Unexpected character: "?".'.
	self
		assert: error messageText
		equals:
		'Syntax Error: Unexpected character: "?". (line 2, column 3)'.
	self
		assert: error graphQLMessage
		equals: 'Syntax Error: Unexpected character: "?".'
]

{ #category : 'tests' }
GQLLexerTest >> testInvalidEscape [

	self should: [ self tokensOf: '"\x"' ] raise: GQLSyntaxError.
	self should: [ self tokensOf: '"\u00ZZ"' ] raise: GQLSyntaxError
]

{ #category : 'tests' }
GQLLexerTest >> testInvalidNumbers [
	"Leading zeros, a missing fraction and a name directly after a number are rejected"

	self assertSyntaxErrorIn: '01' line: 1 column: 2.
	self assertSyntaxErrorIn: '12abc' line: 1 column: 3.
	self should: [ self tokensOf: '1.' ] raise: GQLSyntaxError.
	self should: [ self tokensOf: '1e' ] raise: GQLSyntaxError
]

{ #category : 'tests' }
GQLLexerTest >> testLineAfterBlockString [
	"Newlines inside a block string advance the line counter"

	| lexer token |
	lexer := GQLLexer on: '"""
a
"""
b'.
	lexer next.
	token := lexer next.
	self assert: (token isName: 'b').
	self assert: token line equals: 4.
	self assert: token column equals: 1
]

{ #category : 'tests' }
GQLLexerTest >> testLineAndColumnAfterNewlines [
	"LF, CRLF and CR are all line terminators (CRLF counts once); columns are 1-based"

	| tokens |
	tokens := self tokensOf: 'a' , (String with: Character lf) , '  b'
		          , (String with: Character cr with: Character lf) , 'c'
		          , (String with: Character cr) , '    d'.
	self
		assert: (tokens collect: [ :t | t line ]) asArray
		equals: #( 1 2 3 4 ).
	self
		assert: (tokens collect: [ :t | t column ]) asArray
		equals: #( 1 3 1 5 )
]

{ #category : 'tests' }
GQLLexerTest >> testNames [

	| tokens |
	tokens := self tokensOf: 'foo _bar Baz9 __typename on'.
	self assert: (tokens allSatisfy: [ :t | t kind = #name ]).
	self
		assert: (tokens collect: [ :t | t value ]) asArray
		equals: #( 'foo' '_bar' 'Baz9' '__typename' 'on' ).
	self assert: (tokens fourth isName: '__typename').
	self deny: (tokens first isName: 'bar')
]

{ #category : 'tests' }
GQLLexerTest >> testPeekDoesNotConsume [

	| lexer |
	lexer := GQLLexer on: 'a b'.
	self assert: (lexer peek isName: 'a').
	self assert: (lexer peek isName: 'a').
	self assert: (lexer next isName: 'a').
	self assert: (lexer peek isName: 'b').
	self assert: (lexer next isName: 'b').
	self assert: lexer next isEOF
]

{ #category : 'tests' }
GQLLexerTest >> testPunctuators [
	"Every GraphQL punctuator, including the three-char spread '...'"

	| tokens |
	tokens := self tokensOf: '! $ & ( ) ... : = @ [ ] { | }'.
	self
		assert: (tokens collect: [ :t | t value ]) asArray
		equals:
		#( '!' '$' '&' '(' ')' '...' ':' '=' '@' '[' ']' '{' '|' '}' ).
	self assert: (tokens allSatisfy: [ :t | t kind = #punct ]).
	self assert: (tokens sixth isPunct: '...').
	self deny: (tokens first isPunct: '$').
	self
		assert: (tokens collect: [ :t | t column ]) asArray
		equals: #( 1 3 5 7 9 11 15 17 19 21 23 25 27 29 )
]

{ #category : 'tests' }
GQLLexerTest >> testSpreadAdjacentToName [
	"'...Frag' is a spread followed by a name"

	| tokens |
	tokens := self tokensOf: '...Frag'.
	self assert: tokens size equals: 2.
	self assert: (tokens first isPunct: '...').
	self assert: (tokens second isName: 'Frag').
	self assert: tokens second column equals: 4
]

{ #category : 'tests' }
GQLLexerTest >> testStringEscapes [
	"All simple escapes plus \u unicode escapes"

	| token expected |
	token := (GQLLexer on: '"q\"b\\s\/n\nr\rt\tb\bf\fuéA"') next.
	expected := String new writeStream
		            nextPutAll: 'q"b\s/n';
		            nextPut: Character lf;
		            nextPut: $r;
		            nextPut: Character cr;
		            nextPut: $t;
		            nextPut: Character tab;
		            nextPut: $b;
		            nextPut: Character backspace;
		            nextPut: $f;
		            nextPut: Character newPage;
		            nextPutAll: 'u';
		            nextPut: (Character value: 16rE9);
		            nextPut: $A;
		            contents.
	self assert: token kind equals: #string.
	self assert: token value equals: expected
]

{ #category : 'tests' }
GQLLexerTest >> testStrings [

	| tokens |
	tokens := self tokensOf: '"hello" "" "with space"'.
	self assert: (tokens allSatisfy: [ :t | t kind = #string ]).
	self
		assert: (tokens collect: [ :t | t value ]) asArray
		equals: #( 'hello' '' 'with space' ).
	self
		assert: (tokens collect: [ :t | t column ]) asArray
		equals: #( 1 9 12 )
]

{ #category : 'tests' }
GQLLexerTest >> testUnterminatedString [
	"Reported where the string ends unexpectedly (end of input or end of line), as graphql-js does"

	| error |
	error := self
		         assertSyntaxErrorIn: '
  "abc'
		         line: 2
		         column: 7.
	self assert: error reason equals: 'Unterminated string.'.
	self
		assert: error messageText
		equals: 'Syntax Error: Unterminated string. (line 2, column 7)'.
	self
		assertSyntaxErrorIn: '"abc
"'
		line: 1
		column: 5.
	self assertSyntaxErrorIn: '"""abc' line: 1 column: 7
]

{ #category : 'helpers' }
GQLLexerTest >> tokensOf: aString [
	"Answer all tokens of aString, excluding the final <EOF> token"

	| lexer tokens |
	lexer := GQLLexer on: aString.
	tokens := OrderedCollection new.
	[ lexer peek isEOF ] whileFalse: [ tokens add: lexer next ].
	^ tokens
]
