"
Unit tests for GQLExecutor: selection, aliases, variables, coercion, fragments, operations, error handling with paths/locations, null propagation, directives and limits.

The fixture schema (see #setUp) is:
  Query { hello, greet(name: String!): String!, echo(s, i, f, b, id, e: Color, l: [Int]): String, nums(take: Int = 3): [Int!]!, person(id: ID!): Person, people: [Person!]!, persons: [Person], boom: String, boomNN: String!, ctx: String }
  Person { id: ID!, name: String, friend: Person, boomNN: String! }
The echo and person resolvers record the coerced arguments in lastArgs.
"
Class {
	#name : 'GQLExecutorTest',
	#superclass : 'TestCase',
	#instVars : [
		'schema',
		'lastArgs',
		'people'
	],
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'helpers' }
GQLExecutorTest >> errorMessagesOf: aResult [

	^ (aResult at: 'errors' ifAbsent: [ #(  ) ]) collect: [ :each |
		  each at: 'message' ]
]

{ #category : 'helpers' }
GQLExecutorTest >> execute: aQuery [

	^ self execute: aQuery variables: nil
]

{ #category : 'helpers' }
GQLExecutorTest >> execute: aQuery variables: aDictionary [

	^ (GQLExecutor schema: schema)
		  execute: aQuery
		  operationName: nil
		  variables: aDictionary
		  context: nil
]

{ #category : 'running' }
GQLExecutorTest >> setUp [

	| b alice bob |
	super setUp.
	bob := Dictionary new
		       at: 'id' put: '2';
		       at: 'name' put: 'Bob';
		       yourself.
	alice := Dictionary new
		         at: 'id' put: '1';
		         at: 'name' put: 'Alice';
		         at: 'friend' put: bob;
		         yourself.
	people := {
		          alice.
		          bob }.
	b := GQLSchemaBuilder new.
	b enum: 'Color' values: #( 'RED' 'GREEN' ).
	b object: 'Person' fields: [ :o |
			o field: 'id' type: 'ID!'.
			o field: 'name' type: 'String'.
			o field: 'friend' type: 'Person'.
			"raises for Alice (index 0) only"
			o field: 'boomNN' type: 'String!' resolve: [ :src |
					(src at: 'id') = '1'
						ifTrue: [ self error: 'person boom' ]
						ifFalse: [ 'fine' ] ] ].
	b object: 'Query' fields: [ :o |
			o field: 'hello' type: 'String' resolve: [ 'world' ].
			o
				field: 'greet'
				type: 'String!'
				args: { ('name' -> 'String!') }
				resolve: [ :src :args | 'Hello, ' , (args at: 'name') ].
			o
				field: 'echo'
				type: 'String'
				args: {
						('s' -> 'String').
						('i' -> 'Int').
						('f' -> 'Float').
						('b' -> 'Boolean').
						('id' -> 'ID').
						('e' -> 'Color').
						('l' -> '[Int]') }
				resolve: [ :src :args |
						lastArgs := args.
						'ok' ].
			o
				field: 'nums'
				type: '[Int!]!'
				args: { (GQLArgument name: 'take' type: 'Int' default: 3) }
				resolve: [ :src :args | (1 to: (args at: 'take')) asArray ].
			o
				field: 'person'
				type: 'Person'
				args: { ('id' -> 'ID!') }
				resolve: [ :src :args |
						lastArgs := args.
						people
							detect: [ :p | (p at: 'id') = (args at: 'id') ]
							ifNone: [ nil ] ].
			o field: 'people' type: '[Person!]!' resolve: [ people ].
			o field: 'persons' type: '[Person]' resolve: [ people ].
			o field: 'boom' type: 'String' resolve: [ self error: 'boom!' ].
			o
				field: 'boomNN'
				type: 'String!'
				resolve: [ self error: 'boomNN!' ].
			o
				field: 'ctx'
				type: 'String'
				resolve: [ :src :args :ctx | ctx printString ] ].
	b query: 'Query'.
	schema := b build
]

{ #category : 'tests - basics' }
GQLExecutorTest >> testAliasesKeepSelectionOrder [
	"Response keys follow the selection order, not alphabetical order"

	| data |
	data := (self execute: '{ zeta: hello alpha: hello mid: hello }')
		        at: 'data'.
	self assert: data keys asArray equals: #( 'zeta' 'alpha' 'mid' ).
	self assert: (data values allSatisfy: [ :each | each = 'world' ])
]

{ #category : 'tests - basics' }
GQLExecutorTest >> testContextReachesResolvers [

	| result |
	result := (GQLExecutor schema: schema)
		          execute: '{ ctx }'
		          operationName: nil
		          variables: nil
		          context: 42.
	self assert: ((result at: 'data') at: 'ctx') equals: '42'.
	"GQLSchema convenience entry point"
	result := schema
		          execute: '{ ctx }'
		          operationName: nil
		          variables: nil
		          context: #token.
	self
		assert: ((result at: 'data') at: 'ctx')
		equals: #token printString
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testDuplicateErrorsAreMerged [
	"A field reached twice through fragments is merged: one error, with all its locations"

	| result |
	result := self execute: '{ boom ...F } fragment F on Query { boom }'.
	self assert: (result at: 'errors') size equals: 1.
	self
		assert: ((result at: 'errors') first at: 'locations') size
		equals: 2.
	"the same unknown field spread twice from the same fragment is reported once"
	result := self execute:
		          '{ ...F ...F } fragment F on Query { nope hello }'.
	self assert: (result at: 'errors') size equals: 1.
	self assert: ((result at: 'data') at: 'hello') equals: 'world'
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testErrorsAtDistinctLocationsAreKept [
	"Errors are deduplicated by message + location only: the same failure at two aliases yields two errors"

	| result |
	result := self execute: '{ boom a: boom }'.
	self assert: (result at: 'errors') size equals: 2.
	self
		assert:
			((result at: 'errors') collect: [ :each |
				 (each at: 'path') asArray ]) asArray
		equals: #( #( 'boom' ) #( 'a' ) )
]

{ #category : 'tests - fragments' }
GQLExecutorTest >> testFragmentWithWrongTypeConditionIsSkipped [

	| result |
	result := self execute:
		          '{ ... on Person { name } ...F hello } fragment F on Person { id }'.
	self deny: (result includesKey: 'errors').
	self assert: (result at: 'data') keys asArray equals: #( 'hello' )
]

{ #category : 'tests - coercion' }
GQLExecutorTest >> testIDArgumentIsAlwaysAString [
	"ID accepts both string and int literals (and variables); the resolver always receives a String"

	| result |
	result := self execute: '{ person(id: 1) { name } }'.
	self assert: (lastArgs at: 'id') equals: '1'.
	self
		assert: ((result at: 'data') at: 'person')
		equals: (OrderedDictionary new
				 at: 'name' put: 'Alice';
				 yourself).
	result := self execute: '{ person(id: "2") { name } }'.
	self assert: (lastArgs at: 'id') equals: '2'.
	self
		assert: (((result at: 'data') at: 'person') at: 'name')
		equals: 'Bob'.
	result := self
		          execute: 'query($i: ID!) { person(id: $i) { name } }'
		          variables: (Dictionary new
				           at: 'i' put: 1;
				           yourself).
	self assert: (lastArgs at: 'id') equals: '1'.
	self
		assert: (((result at: 'data') at: 'person') at: 'name')
		equals: 'Alice'
]

{ #category : 'tests - coercion' }
GQLExecutorTest >> testInvalidArgumentLiterals [
	"A bad literal is a field error: the field is null and the error has a path"

	| result |
	result := self execute: '{ echo(i: "x") hello }'.
	self assert: ((result at: 'data') at: 'echo') isNil.
	self assert: ((result at: 'data') at: 'hello') equals: 'world'.
	self assert: ((self errorMessagesOf: result) first beginsWith:
			 'Argument "i" has invalid value').
	self
		assert: ((result at: 'errors') first at: 'path') asArray
		equals: #( 'echo' ).
	result := self execute: '{ echo(e: BLUE) }'.
	self assert: ((self errorMessagesOf: result) first beginsWith:
			 'Argument "e" has invalid value').
	"missing required argument on a non-null field propagates to data"
	result := self execute: '{ greet }'.
	self assert: (result at: 'data') isNil.
	self
		assert: (self errorMessagesOf: result)
		equals:
		#( 'Argument "name" of required type "String!" was not provided.' )
]

{ #category : 'tests - variables' }
GQLExecutorTest >> testInvalidVariableType [

	| result |
	result := self
		          execute: 'query($t: Int) { nums(take: $t) }'
		          variables: (Dictionary new
				           at: 't' put: 'abc';
				           yourself).
	self deny: (result includesKey: 'data').
	self assert: (result at: 'errors') size equals: 1.
	self assert: ((self errorMessagesOf: result) first beginsWith:
			 'Variable "$t" got invalid value')
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testListIndexInErrorPath [
	"Errors inside list items carry the item index in their path"

	| result |
	"[Person!]! at the root: the null bubbles up to data"
	result := self execute: '{ people { boomNN } }'.
	self assert: (result at: 'data') isNil.
	self assert: (result at: 'errors') size equals: 1.
	self
		assert: ((result at: 'errors') first at: 'path') asArray
		equals: #( 'people' 0 'boomNN' ).
	"[Person] is nullable per item: only item 0 becomes null"
	result := self execute: '{ persons { boomNN } }'.
	self assert: ((result at: 'data') at: 'persons') size equals: 2.
	self assert: ((result at: 'data') at: 'persons') first isNil.
	self
		assert: (((result at: 'data') at: 'persons') second at: 'boomNN')
		equals: 'fine'.
	self
		assert: ((result at: 'errors') first at: 'path') asArray
		equals: #( 'persons' 0 'boomNN' )
]

{ #category : 'tests - coercion' }
GQLExecutorTest >> testLiteralKinds [
	"Each literal kind is coerced to the matching Smalltalk value"

	| result |
	result := self execute:
		          '{ echo(s: "a\nb", i: -4, f: 1.5e2, b: false, id: 7, e: GREEN, l: [1, 2, null]) }'.
	self deny: (result includesKey: 'errors').
	self assert: ((result at: 'data') at: 'echo') equals: 'ok'.
	self assert: (lastArgs at: 's') equals: 'a' , String lf , 'b'.
	self assert: (lastArgs at: 'i') equals: -4.
	self assert: (lastArgs at: 'f') isFloat.
	self assert: (lastArgs at: 'f') equals: 150.0.
	self assert: (lastArgs at: 'b') equals: false.
	self assert: (lastArgs at: 'id') equals: '7'.
	self assert: (lastArgs at: 'e') equals: 'GREEN'.
	self assert: (lastArgs at: 'l') asArray equals: #( 1 2 nil ).
	"an Int literal is accepted for a Float argument"
	self execute: '{ echo(f: 3) }'.
	self assert: (lastArgs at: 'f') isFloat.
	self assert: (lastArgs at: 'f') equals: 3.0.
	"explicit null"
	self execute: '{ echo(s: null) }'.
	self assert: (lastArgs at: 's') isNil
]

{ #category : 'tests - limits' }
GQLExecutorTest >> testMaxListSizeCapsLists [
	"List results are truncated to maxListSize items (nil means the GQLExecutionContext default)"

	| executor result |
	executor := GQLExecutor schema: schema.
	self assert: executor maxListSize isNil.
	result := executor execute: '{ nums(take: 5) }'.
	self
		assert: ((result at: 'data') at: 'nums') asArray
		equals: #( 1 2 3 4 5 ).
	executor maxListSize: 2.
	self assert: executor maxListSize equals: 2.
	result := executor execute: '{ nums(take: 5) people { name } }'.
	self deny: (result includesKey: 'errors').
	self
		assert: ((result at: 'data') at: 'nums') asArray
		equals: #( 1 2 ).
	self assert: ((result at: 'data') at: 'people') size equals: 2.
	executor maxListSize: 1.
	result := executor execute: '{ nums(take: 5) people { name } }'.
	self assert: ((result at: 'data') at: 'nums') asArray equals: #( 1 ).
	self
		assert: (((result at: 'data') at: 'people') collect: [ :each |
				 each at: 'name' ]) asArray
		equals: #( 'Alice' )
]

{ #category : 'tests - variables' }
GQLExecutorTest >> testMissingRequiredVariableIsRequestError [
	"Variable coercion errors happen before execution: the response has no 'data' key"

	| result |
	result := self execute: 'query($n: String!) { greet(name: $n) }'.
	self deny: (result includesKey: 'data').
	self
		assert: (self errorMessagesOf: result)
		equals:
		#( 'Variable "$n" of required type "String!" was not provided.' ).
	self
		assert:
		(((result at: 'errors') first at: 'locations') first at: 'column')
		equals: 7
]

{ #category : 'tests - operations' }
GQLExecutorTest >> testMutationIsNotSupported [

	| result |
	result := self execute: 'mutation { hello }'.
	self deny: (result includesKey: 'data').
	self
		assert: (self errorMessagesOf: result)
		equals: #( 'Schema is not configured for mutations.' )
]

{ #category : 'tests - fragments' }
GQLExecutorTest >> testNamedAndInlineFragments [

	| result data |
	result := self execute:
		          '{ ...Root person(id: 1) { ...P ... on Person { friend { name } } } }
fragment Root on Query { hello }
fragment P on Person { id name }'.
	self deny: (result includesKey: 'errors').
	data := result at: 'data'.
	self assert: data keys asArray equals: #( 'hello' 'person' ).
	self
		assert: (data at: 'person') keys asArray
		equals: #( 'id' 'name' 'friend' ).
	self assert: ((data at: 'person') at: 'id') equals: '1'.
	self
		assert: (((data at: 'person') at: 'friend') at: 'name')
		equals: 'Bob'.
	"inline fragment without type condition"
	data := (self execute: '{ ... { hello } }') at: 'data'.
	self assert: (data at: 'hello') equals: 'world'
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testNonNullErrorAtRootNullsData [

	| result |
	result := self execute: '{ boomNN hello }'.
	self assert: (result includesKey: 'data').
	self assert: (result at: 'data') isNil.
	self assert: (self errorMessagesOf: result) equals: #( 'boomNN!' ).
	self
		assert: ((result at: 'errors') first at: 'path') asArray
		equals: #( 'boomNN' )
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testNonNullErrorPropagatesToNullableParent [
	"person.boomNN is String!: the error nulls the nearest nullable ancestor (person)"

	| result |
	result := self execute: '{ person(id: "1") { name boomNN } hello }'.
	self assert: ((result at: 'data') at: 'person') isNil.
	self assert: ((result at: 'data') at: 'hello') equals: 'world'.
	self assert: (result at: 'errors') size equals: 1.
	self
		assert: ((result at: 'errors') first at: 'message')
		equals: 'person boom'.
	self
		assert: ((result at: 'errors') first at: 'path') asArray
		equals: #( 'person' 'boomNN' )
]

{ #category : 'tests - variables' }
GQLExecutorTest >> testNullForNonNullVariable [

	| result |
	result := self
		          execute: 'query($n: String!) { greet(name: $n) }'
		          variables: (Dictionary new
				           at: 'n' put: nil;
				           yourself).
	self deny: (result includesKey: 'data').
	self
		assert: (self errorMessagesOf: result)
		equals:
		#( 'Variable "$n" of non-null type "String!" must not be null.' )
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testNullableResolverErrorBecomesNull [

	| result error |
	result := self execute: '{ boom hello }'.
	self
		assert: (result at: 'data') keys asArray
		equals: #( 'boom' 'hello' ).
	self assert: ((result at: 'data') at: 'boom') isNil.
	self assert: ((result at: 'data') at: 'hello') equals: 'world'.
	error := (result at: 'errors') first.
	self assert: (error at: 'message') equals: 'boom!'.
	self assert: (error at: 'path') asArray equals: #( 'boom' ).
	self assert: ((error at: 'locations') first at: 'column') equals: 3
]

{ #category : 'tests - operations' }
GQLExecutorTest >> testOperationNameSelection [

	| executor document result |
	document := 'query A { hello } query B { greet(name: "q") }'.
	executor := GQLExecutor schema: schema.
	result := executor
		          execute: document
		          operationName: 'B'
		          variables: nil
		          context: nil.
	self assert: (result at: 'data') keys asArray equals: #( 'greet' ).
	self assert: ((result at: 'data') at: 'greet') equals: 'Hello, q'.
	result := executor
		          execute: document
		          operationName: 'A'
		          variables: nil
		          context: nil.
	self assert: (result at: 'data') keys asArray equals: #( 'hello' ).
	"a single named operation can be run without giving its name"
	result := executor execute: 'query Only { hello }'.
	self assert: ((result at: 'data') at: 'hello') equals: 'world'
]

{ #category : 'tests - operations' }
GQLExecutorTest >> testOperationSelectionErrors [

	| result |
	result := self execute: 'query A { hello } query B { boom }'.
	self deny: (result includesKey: 'data').
	self
		assert: (self errorMessagesOf: result)
		equals:
		#( 'Must provide operation name if query contains multiple operations.' ).
	result := (GQLExecutor schema: schema)
		          execute: 'query A { hello } query B { boom }'
		          operationName: 'C'
		          variables: nil
		          context: nil.
	self deny: (result includesKey: 'data').
	self
		assert: (self errorMessagesOf: result)
		equals: #( 'Unknown operation named "C".' )
]

{ #category : 'tests - variables' }
GQLExecutorTest >> testRequiredVariable [

	| result |
	result := self
		          execute: 'query($n: String!) { greet(name: $n) }'
		          variables: (Dictionary new
				           at: 'n' put: 'Zoe';
				           yourself).
	self deny: (result includesKey: 'errors').
	self assert: ((result at: 'data') at: 'greet') equals: 'Hello, Zoe'
]

{ #category : 'tests - basics' }
GQLExecutorTest >> testResultIsJSONSerializable [
	"Results (data, nested lists, nulls, errors with paths and locations) serialize with NeoJSON and round-trip"

	| json parsed |
	json := NeoJSONWriter toString:
		        (self execute:
			         '{ boom hello people { name friend { name } } }').
	self
		assert: json
		equals:
		'{"data":{"boom":null,"hello":"world","people":[{"name":"Alice","friend":{"name":"Bob"}},{"name":"Bob","friend":null}]},"errors":[{"message":"boom!","locations":[{"line":1,"column":3}],"path":["boom"]}]}'.
	parsed := NeoJSONReader fromString: json.
	self assert: ((parsed at: 'data') at: 'hello') equals: 'world'.
	"pre-execution error responses serialize too"
	json := NeoJSONWriter toString: (self execute: '{').
	self assert: ((NeoJSONReader fromString: json) includesKey: 'errors')
]

{ #category : 'tests - basics' }
GQLExecutorTest >> testSameFieldTwiceWithAliasesAndDifferentArguments [

	| result data |
	result := self execute: '{ a: greet(name: "x") b: greet(name: "y") }'.
	self deny: (result includesKey: 'errors').
	data := result at: 'data'.
	self assert: data keys asArray equals: #( 'a' 'b' ).
	self assert: (data at: 'a') equals: 'Hello, x'.
	self assert: (data at: 'b') equals: 'Hello, y'
]

{ #category : 'tests - basics' }
GQLExecutorTest >> testSchemaConvenienceEntryPoints [

	self
		assert: (((schema execute: '{ hello }') at: 'data') at: 'hello')
		equals: 'world'.
	self
		assert: (((schema
				   execute: 'query($n: String!) { greet(name: $n) }'
				   variables: (Dictionary new
						    at: 'n' put: 'V';
						    yourself)) at: 'data') at: 'greet')
		equals: 'Hello, V'.
	self
		assert: ((((GQLExecutor schema: schema)
				   execute: 'query($n: String!) { greet(name: $n) }'
				   variables: (Dictionary new
						    at: 'n' put: 'W';
						    yourself)) at: 'data') at: 'greet')
		equals: 'Hello, W'
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testSelectionShapeErrors [

	| result |
	"a sub-selection on a leaf"
	result := self execute: '{ hello { x } }'.
	self
		assert: (self errorMessagesOf: result)
		equals:
		#( 'Field "hello" must not have a selection since type "String" has no subfields.' ).
	self
		assert: ((result at: 'errors') first at: 'path') asArray
		equals: #( 'hello' ).
	"a missing sub-selection on an object"
	result := self execute: '{ person(id: "1") }'.
	self
		assert: (self errorMessagesOf: result)
		equals:
		#( 'Field "person" of type "Person" must have a selection of subfields.' ).
	self
		assert: ((result at: 'errors') first at: 'path') asArray
		equals: #( 'person' )
]

{ #category : 'tests - basics' }
GQLExecutorTest >> testShorthandQuery [
	"A selection set without the 'query' keyword is an anonymous query"

	| result |
	result := self execute: '{ hello }'.
	self deny: (result includesKey: 'errors').
	self assert: ((result at: 'data') at: 'hello') equals: 'world'.
	self assert: (result at: 'data') keys asArray equals: #( 'hello' )
]

{ #category : 'tests - coercion' }
GQLExecutorTest >> testSingleValueIsWrappedForListArgument [
	"Input coercion: a non-list value given for a list type becomes a one-element list (literal and variable)"

	self execute: '{ echo(l: 5) }'.
	self assert: (lastArgs at: 'l') asArray equals: #( 5 ).
	self
		execute: 'query($x: [Int]) { echo(l: $x) }'
		variables: (Dictionary new
				 at: 'x' put: 9;
				 yourself).
	self assert: (lastArgs at: 'l') asArray equals: #( 9 )
]

{ #category : 'tests - directives' }
GQLExecutorTest >> testSkipAndIncludeDirectives [

	| result |
	result := self execute:
		          '{ hello @skip(if: true) boom @include(if: false) nums @include(if: true) a: hello @skip(if: false) }'.
	self deny: (result includesKey: 'errors').
	self assert: (result at: 'data') keys asArray equals: #( 'nums'
	   'a' ).
	"with variables, and on fragments"
	result := self
		          execute:
		          'query($yes: Boolean!) { ... on Query @include(if: $yes) { hello } ...F @skip(if: $yes) } fragment F on Query { boom }'
		          variables: (Dictionary new
				           at: 'yes' put: true;
				           yourself).
	self deny: (result includesKey: 'errors').
	self assert: (result at: 'data') keys asArray equals: #( 'hello' )
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testSyntaxErrorHasLocationsAndNoData [

	| result error |
	result := self execute: '{ hello '.
	self deny: (result includesKey: 'data').
	self assert: (result at: 'errors') size equals: 1.
	error := (result at: 'errors') first.
	self assert: ((error at: 'message') beginsWith: 'Syntax Error').
	self assert: ((error at: 'locations') first at: 'line') equals: 1.
	self assert: ((error at: 'locations') first at: 'column') equals: 9
]

{ #category : 'tests - basics' }
GQLExecutorTest >> testTypename [

	| data |
	data := (self execute:
		         '{ __typename people { __typename name } person(id: 1) { friend { __typename } } }')
		        at: 'data'.
	self assert: (data at: '__typename') equals: 'Query'.
	self
		assert:
			((data at: 'people') collect: [ :each | each at: '__typename' ])
				asArray
		equals: #( 'Person' 'Person' ).
	self
		assert: (((data at: 'person') at: 'friend') at: '__typename')
		equals: 'Person'
]

{ #category : 'tests - errors' }
GQLExecutorTest >> testUnknownFieldIsReportedAndOthersStillExecute [

	| result error |
	result := self execute: '{ hello nope }'.
	"the unknown field key is omitted"
	self assert: (result at: 'data') keys asArray equals: #( 'hello' ).
	self assert: ((result at: 'data') at: 'hello') equals: 'world'.
	self assert: (result at: 'errors') size equals: 1.
	error := (result at: 'errors') first.
	self
		assert: (error at: 'message')
		equals: 'Cannot query field "nope" on type "Query".'.
	self assert: (error at: 'path') asArray equals: #( 'nope' ).
	self assert: ((error at: 'locations') first at: 'line') equals: 1.
	self assert: ((error at: 'locations') first at: 'column') equals: 9
]

{ #category : 'tests - fragments' }
GQLExecutorTest >> testUnknownFragmentIsAnError [

	| result |
	result := self execute: '{ ...G hello }'.
	self
		assert: (self errorMessagesOf: result)
		equals: #( 'Unknown fragment "G".' ).
	self
		assert: ((result at: 'errors') first at: 'locations') first
		equals: (OrderedDictionary new
				 at: 'line' put: 1;
				 at: 'column' put: 3;
				 yourself).
	"the rest of the selection still executes"
	self assert: ((result at: 'data') at: 'hello') equals: 'world'
]

{ #category : 'tests - variables' }
GQLExecutorTest >> testVariableDefaults [
	"The variable default is used when the variable is not provided; an argument default applies when an optional variable is absent"

	self
		assert:
		((self execute: 'query($t: Int = 2) { nums(take: $t) }') at: 'data')
		equals: (OrderedDictionary new
				 at: 'nums' put: #( 1 2 );
				 yourself).
	self
		assert:
			(((self execute: 'query($t: Int) { nums(take: $t) }') at: 'data')
				 at: 'nums')
		equals: #( 1 2 3 ).
	self
		assert: (((self
				   execute: 'query($t: Int = 2) { nums(take: $t) }'
				   variables: (Dictionary new
						    at: 't' put: 4;
						    yourself)) at: 'data') at: 'nums')
		equals: #( 1 2 3 4 ).
	"argument default without any variable"
	self
		assert: (((self execute: '{ nums }') at: 'data') at: 'nums')
		equals: #( 1 2 3 )
]
