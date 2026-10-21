"
A lexical token of a GraphQL document. kind is one of #punct #name #int #float #string #blockString #eof. value is the punctuator / name / number source text / decoded string. line and column (1-based) locate the token start.
"
Class {
	#name : 'GQLToken',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'value',
		'line',
		'column'
	],
	#category : 'GraphQL-Core-Lexer',
	#package : 'GraphQL-Core',
	#tag : 'Lexer'
}

{ #category : 'instance creation' }
GQLToken class >> kind: aSymbol value: aString line: aLine column: aColumn [

	^ self new
		  kind: aSymbol;
		  value: aString;
		  line: aLine;
		  column: aColumn;
		  yourself
]

{ #category : 'accessing' }
GQLToken >> column [

	^ column
]

{ #category : 'accessing' }
GQLToken >> column: anObject [

	column := anObject
]

{ #category : 'printing' }
GQLToken >> description [
	"Human readable description used in syntax error messages, e.g. <EOF>, ""{"" or Name ""foo"""

	kind = #eof ifTrue: [ ^ '<EOF>' ].
	kind = #punct ifTrue: [ ^ '"' , value , '"' ].
	^ ({
		   (#name -> 'Name').
		   (#int -> 'Int').
		   (#float -> 'Float').
		   (#string -> 'String').
		   (#blockString -> 'BlockString') } asDictionary at: kind ifAbsent: [ kind asString ]) , ' "' , value asString , '"'
]

{ #category : 'testing' }
GQLToken >> isEOF [

	^ kind = #eof
]

{ #category : 'testing' }
GQLToken >> isName: aString [

	^ kind = #name and: [ value = aString ]
]

{ #category : 'testing' }
GQLToken >> isPunct: aString [

	^ kind = #punct and: [ value = aString ]
]

{ #category : 'accessing' }
GQLToken >> kind [

	^ kind
]

{ #category : 'accessing' }
GQLToken >> kind: anObject [

	kind := anObject
]

{ #category : 'accessing' }
GQLToken >> line [

	^ line
]

{ #category : 'accessing' }
GQLToken >> line: anObject [

	line := anObject
]

{ #category : 'printing' }
GQLToken >> printOn: aStream [

	aStream
		nextPutAll: 'GQLToken(';
		nextPutAll: self description;
		nextPutAll: ' @';
		print: line;
		nextPut: $:;
		print: column;
		nextPut: $)
]

{ #category : 'accessing' }
GQLToken >> value [

	^ value
]

{ #category : 'accessing' }
GQLToken >> value: anObject [

	value := anObject
]
