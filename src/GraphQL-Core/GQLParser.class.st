"
Recursive descent parser for GraphQL executable documents. GQLParser parse: aString -> GQLDocument. GQLParser parseTypeRef: '[ID!]!' -> GQLTypeRef. GQLParser parseValue: aString -> constant GQLValueNode. Signals GQLSyntaxError.
"
Class {
	#name : 'GQLParser',
	#superclass : 'Object',
	#instVars : [
		'lexer'
	],
	#category : 'GraphQL-Core-Parser',
	#package : 'GraphQL-Core',
	#tag : 'Parser'
}

{ #category : 'parsing' }
GQLParser class >> parse: aString [
	"Parse aString as a GraphQL executable document. Signals GQLSyntaxError"

	^ self new parse: aString
]

{ #category : 'parsing' }
GQLParser class >> parseTypeRef: aString [
	"Parse a type reference such as '[ID!]!'. Signals GQLSyntaxError"

	^ self new parseTypeRef: aString
]

{ #category : 'parsing' }
GQLParser class >> parseValue: aString [
	"Parse a constant GraphQL value literal such as '{a: [1, 2]}'. Signals GQLSyntaxError"

	^ self new parseValue: aString
]

{ #category : 'private - errors' }
GQLParser >> error: anExpectation found: aToken [

	^ GQLSyntaxError
		  signal: anExpectation , ', found ' , aToken description , '.'
		  line: aToken line
		  column: aToken column
]

{ #category : 'private - tokens' }
GQLParser >> expect: aString [
	"Consume and answer the punctuator aString or signal a syntax error"

	(lexer peek isPunct: aString) ifTrue: [ ^ lexer next ].
	^ self error: 'Expected "' , aString , '"' found: lexer peek
]

{ #category : 'private - tokens' }
GQLParser >> expectEOF [

	lexer peek isEOF ifFalse: [ self unexpected: lexer peek ]
]

{ #category : 'private - tokens' }
GQLParser >> expectKeyword: aString [

	(lexer peek isName: aString) ifTrue: [ ^ lexer next ].
	^ self error: 'Expected "' , aString , '"' found: lexer peek
]

{ #category : 'private - building' }
GQLParser >> node: aNode at: aToken [

	aNode line: aToken line column: aToken column.
	^ aNode
]

{ #category : 'parsing' }
GQLParser >> parse: aString [

	self setSource: aString.
	^ self parseDocument
]

{ #category : 'private - parsing' }
GQLParser >> parseArgumentsConst: isConst [

	| arguments |
	arguments := OrderedDictionary new.
	(self skip: '(') ifFalse: [ ^ arguments ].
	[
	| name |
	name := self parseName.
	self expect: ':'.
	arguments at: name put: (self parseValueConst: isConst).
	self skip: ')' ] whileFalse.
	^ arguments
]

{ #category : 'private - parsing' }
GQLParser >> parseDefinition [

	| token |
	token := lexer peek.
	(token isPunct: '{') ifTrue: [ ^ self parseOperationDefinition ].
	token kind = #name ifTrue: [
		(#( 'query' 'mutation' 'subscription' ) includes: token value) ifTrue: [ ^ self parseOperationDefinition ].
		token value = 'fragment' ifTrue: [ ^ self parseFragmentDefinition ] ].
	^ self unexpected: token
]

{ #category : 'private - parsing' }
GQLParser >> parseDirectivesConst: isConst [

	| directives |
	directives := OrderedCollection new.
	[ self peekPunct: '@' ] whileTrue: [
		| directive |
		directive := self node: GQLDirective new at: lexer next.
		directive
			name: self parseName;
			arguments: (self parseArgumentsConst: isConst).
		directives add: directive ].
	^ directives
]

{ #category : 'private - parsing' }
GQLParser >> parseDocument [

	| document |
	document := self node: GQLDocument new at: lexer peek.
	[ document definitions add: self parseDefinition.
	lexer peek isEOF ] whileFalse.
	^ document
]

{ #category : 'private - parsing' }
GQLParser >> parseField [

	| field nameOrAlias |
	field := self node: GQLField new at: lexer peek.
	nameOrAlias := self parseName.
	(self skip: ':')
		ifTrue: [
			field
				alias: nameOrAlias;
				name: self parseName ]
		ifFalse: [ field name: nameOrAlias ].
	field
		arguments: (self parseArgumentsConst: false);
		directives: (self parseDirectivesConst: false).
	(self peekPunct: '{') ifTrue: [ field selectionSet: self parseSelectionSet ].
	^ field
]

{ #category : 'private - parsing' }
GQLParser >> parseFragment [
	"Parse either a fragment spread (...Name) or an inline fragment (... on Type {}, ... @dir {}, ... {})"

	| start |
	start := self expect: '...'.
	(lexer peek kind = #name and: [ (lexer peek isName: 'on') not ]) ifTrue: [
		^ (self node: GQLFragmentSpread new at: start)
			  name: self parseFragmentName;
			  directives: (self parseDirectivesConst: false);
			  yourself ].
	^ (self node: GQLInlineFragment new at: start)
		  typeCondition: ((lexer peek isName: 'on')
				   ifTrue: [
					   lexer next.
					   self parseName ]
				   ifFalse: [ nil ]);
		  directives: (self parseDirectivesConst: false);
		  selectionSet: self parseSelectionSet;
		  yourself
]

{ #category : 'private - parsing' }
GQLParser >> parseFragmentDefinition [

	| fragment |
	fragment := self node: GQLFragmentDefinition new at: (self expectKeyword: 'fragment').
	fragment name: self parseFragmentName.
	self expectKeyword: 'on'.
	^ fragment
		  typeCondition: self parseName;
		  directives: (self parseDirectivesConst: false);
		  selectionSet: self parseSelectionSet;
		  yourself
]

{ #category : 'private - parsing' }
GQLParser >> parseFragmentName [

	(lexer peek isName: 'on') ifTrue: [ ^ self unexpected: lexer peek ].
	^ self parseName
]

{ #category : 'private - parsing' }
GQLParser >> parseListConst: isConst [

	| list |
	list := self node: GQLListValue new at: (self expect: '[').
	[ self skip: ']' ] whileFalse: [ list values add: (self parseValueConst: isConst) ].
	^ list
]

{ #category : 'private - parsing' }
GQLParser >> parseName [

	| token |
	token := lexer peek.
	token kind = #name ifFalse: [ ^ self error: 'Expected Name' found: token ].
	^ lexer next value
]

{ #category : 'private - parsing' }
GQLParser >> parseObjectConst: isConst [

	| object |
	object := self node: GQLObjectValue new at: (self expect: '{').
	[ self skip: '}' ] whileFalse: [
		| name |
		name := self parseName.
		self expect: ':'.
		object fields at: name put: (self parseValueConst: isConst) ].
	^ object
]

{ #category : 'private - parsing' }
GQLParser >> parseOperationDefinition [

	| operation |
	operation := self node: GQLOperationDefinition new at: lexer peek.
	(self peekPunct: '{') ifTrue: [
		operation
			operation: #query;
			selectionSet: self parseSelectionSet.
		^ operation ].
	operation operation: self parseOperationType.
	lexer peek kind = #name ifTrue: [ operation name: self parseName ].
	operation
		variableDefinitions: self parseVariableDefinitions;
		directives: (self parseDirectivesConst: false);
		selectionSet: self parseSelectionSet.
	^ operation
]

{ #category : 'private - parsing' }
GQLParser >> parseOperationType [

	| token |
	token := lexer peek.
	(token kind = #name and: [ #( 'query' 'mutation' 'subscription' ) includes: token value ])
		ifFalse: [ ^ self unexpected: token ].
	^ lexer next value asSymbol
]

{ #category : 'private - parsing' }
GQLParser >> parseSelection [

	^ (self peekPunct: '...')
		  ifTrue: [ self parseFragment ]
		  ifFalse: [ self parseField ]
]

{ #category : 'private - parsing' }
GQLParser >> parseSelectionSet [

	| selectionSet |
	selectionSet := self node: GQLSelectionSet new at: (self expect: '{').
	[ selectionSet selections add: self parseSelection.
	self skip: '}' ] whileFalse.
	^ selectionSet
]

{ #category : 'private - parsing' }
GQLParser >> parseType [
	"Type : NamedType | [ Type ] | Type !"

	| start type |
	start := lexer peek.
	type := (self skip: '[')
		        ifTrue: [
			        | inner |
			        inner := self parseType.
			        self expect: ']'.
			        self node: (GQLListTypeRef of: inner) at: start ]
		        ifFalse: [ self node: (GQLNamedTypeRef named: self parseName) at: start ].
	(self skip: '!') ifTrue: [ type := self node: (GQLNonNullTypeRef of: type) at: start ].
	^ type
]

{ #category : 'parsing' }
GQLParser >> parseTypeRef: aString [

	| type |
	self setSource: aString.
	type := self parseType.
	self expectEOF.
	^ type
]

{ #category : 'parsing' }
GQLParser >> parseValue: aString [

	| value |
	self setSource: aString.
	value := self parseValueConst: true.
	self expectEOF.
	^ value
]

{ #category : 'private - parsing' }
GQLParser >> parseValueConst: isConst [

	| token |
	token := lexer peek.
	(token isPunct: '[') ifTrue: [ ^ self parseListConst: isConst ].
	(token isPunct: '{') ifTrue: [ ^ self parseObjectConst: isConst ].
	(token isPunct: '$') ifTrue: [
		isConst ifTrue: [ ^ self unexpected: token ].
		lexer next.
		^ self node: (GQLVariableValue named: self parseName) at: token ].
	token kind = #int ifTrue: [
		lexer next.
		^ self node: (GQLIntValue value: token value asInteger) at: token ].
	token kind = #float ifTrue: [
		lexer next.
		^ self node: (GQLFloatValue value: (Number readFrom: token value asLowercase) asFloat) at: token ].
	(token kind = #string or: [ token kind = #blockString ]) ifTrue: [
		lexer next.
		^ self node: (GQLStringValue value: token value) at: token ].
	token kind = #name ifTrue: [
		lexer next.
		token value = 'true' ifTrue: [ ^ self node: (GQLBooleanValue value: true) at: token ].
		token value = 'false' ifTrue: [ ^ self node: (GQLBooleanValue value: false) at: token ].
		token value = 'null' ifTrue: [ ^ self node: GQLNullValue new at: token ].
		^ self node: (GQLEnumValue value: token value) at: token ].
	^ self unexpected: token
]

{ #category : 'private - parsing' }
GQLParser >> parseVariableDefinition [

	| definition |
	definition := self node: GQLVariableDefinition new at: (self expect: '$').
	definition name: self parseName.
	self expect: ':'.
	definition typeRef: self parseType.
	(self skip: '=') ifTrue: [ definition defaultValue: (self parseValueConst: true) ].
	definition directives: (self parseDirectivesConst: true).
	^ definition
]

{ #category : 'private - parsing' }
GQLParser >> parseVariableDefinitions [

	| definitions |
	definitions := OrderedCollection new.
	(self skip: '(') ifFalse: [ ^ definitions ].
	[ definitions add: self parseVariableDefinition.
	self skip: ')' ] whileFalse.
	^ definitions
]

{ #category : 'private - tokens' }
GQLParser >> peek [

	^ lexer peek
]

{ #category : 'private - tokens' }
GQLParser >> peekPunct: aString [

	^ lexer peek isPunct: aString
]

{ #category : 'initialization' }
GQLParser >> setSource: aString [

	lexer := GQLLexer on: aString
]

{ #category : 'private - tokens' }
GQLParser >> skip: aString [
	"Consume the punctuator aString if it is the next token. Answer whether it was consumed"

	(lexer peek isPunct: aString) ifFalse: [ ^ false ].
	lexer next.
	^ true
]

{ #category : 'private - errors' }
GQLParser >> unexpected: aToken [

	^ GQLSyntaxError
		  signal: 'Unexpected ' , aToken description , '.'
		  line: aToken line
		  column: aToken column
]
