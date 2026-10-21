"
Unit tests for GQLParser and the GraphQL executable-document AST (operations, selections, fragments, arguments, values, type references, directives and syntax errors).
"
Class {
	#name : 'GQLParserTest',
	#superclass : 'TestCase',
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'helpers' }
GQLParserTest >> assertSyntaxError: aBlock line: aLine column: aColumn [
	"Evaluate aBlock, which must signal a GQLSyntaxError located at aLine/aColumn. Answer the error"

	| error |
	error := nil.
	aBlock
		on: GQLSyntaxError
		do: [ :e | error := e ].
	self assert: error notNil description: 'Expected a GQLSyntaxError'.
	self assert: error line equals: aLine.
	self assert: error column equals: aColumn.
	self assert: (error messageText beginsWith: 'Syntax Error: ').
	self assert: (error messageText endsWith:
			 '(line ' , aLine printString , ', column ' , aColumn printString
			 , ')').
	^ error
]

{ #category : 'helpers' }
GQLParserTest >> firstFieldOf: aString [
	"Answer the first selection of the first operation of the parsed document"

	^ (GQLParser parse: aString) operations first selectionSet selections
		  first
]

{ #category : 'tests' }
GQLParserTest >> testAliases [

	| fields aliased plain |
	fields := (GQLParser parse:
		           '{ t0: __type(name: "Characters") { name } plain }')
		          operations first selectionSet selections.
	aliased := fields first.
	self assert: aliased isField.
	self assert: aliased alias equals: 't0'.
	self assert: aliased name equals: '__type'.
	self assert: aliased responseKey equals: 't0'.
	self
		assert: (aliased arguments at: 'name') class
		equals: GQLStringValue.
	self
		assert: (aliased arguments at: 'name') value
		equals: 'Characters'.
	self
		assert: aliased selectionSet selections first name
		equals: 'name'.
	plain := fields second.
	self assert: plain alias isNil.
	self assert: plain responseKey equals: 'plain'.
	self assert: plain selectionSet isNil
]

{ #category : 'tests' }
GQLParserTest >> testAnonymousQueryWithVariables [

	| operation field |
	operation := (GQLParser parse:
		              'query($id: ID!) { entity(id: $id) { id } }')
		             operations first.
	self assert: operation isQuery.
	self assert: operation name isNil.
	self assert: operation variableDefinitions size equals: 1.
	self assert: operation variableDefinitions first name equals: 'id'.
	self
		assert: operation variableDefinitions first typeRef printString
		equals: 'ID!'.
	field := operation selectionSet selections first.
	self assert: field name equals: 'entity'.
	self assert: (field arguments at: 'id') isVariable.
	self assert: (field arguments at: 'id') name equals: 'id'.
	self assert: field selectionSet selections first name equals: 'id'
]

{ #category : 'tests' }
GQLParserTest >> testArgumentsOfAllLiteralKinds [

	| field args |
	field := self firstFieldOf:
		         '{ f(i: -3, fl: 1.5e2, s: "str", bs: """block""", t: true, fa: false, n: null, e: RED, l: [1, "a"], o: {x: 1, y: {z: B}}, v: $var) }'.
	args := field arguments.
	self assert: args class equals: OrderedDictionary.
	"Argument order is preserved"
	self
		assert: args keys asArray
		equals: #( 'i' 'fl' 's' 'bs' 't' 'fa' 'n' 'e' 'l' 'o' 'v' ).
	self assert: (args at: 'i') class equals: GQLIntValue.
	self assert: (args at: 'i') value equals: -3.
	self assert: (args at: 'fl') class equals: GQLFloatValue.
	self assert: (args at: 'fl') value equals: 150.0.
	self assert: (args at: 's') class equals: GQLStringValue.
	self assert: (args at: 's') value equals: 'str'.
	self assert: (args at: 'bs') class equals: GQLStringValue.
	self assert: (args at: 'bs') value equals: 'block'.
	self assert: (args at: 't') class equals: GQLBooleanValue.
	self assert: (args at: 't') value.
	self deny: (args at: 'fa') value.
	self assert: (args at: 'n') class equals: GQLNullValue.
	self assert: (args at: 'n') isNull.
	self assert: (args at: 'e') class equals: GQLEnumValue.
	self assert: (args at: 'e') value equals: 'RED'.
	self assert: (args at: 'l') class equals: GQLListValue.
	self assert: (args at: 'l') values size equals: 2.
	self assert: (args at: 'o') class equals: GQLObjectValue.
	self
		assert: ((args at: 'o') fields at: 'y') class
		equals: GQLObjectValue.
	self assert: (args at: 'v') class equals: GQLVariableValue.
	self assert: (args at: 'v') name equals: 'var'.
	self assert: (args at: 'v') isVariable.
	self deny: (args at: 'v') isConstant.
	self assert: (args at: 'o') isConstant
]

{ #category : 'tests' }
GQLParserTest >> testAsGraphQLString [
	"Values print back to GraphQL syntax"

	| args |
	args := (self firstFieldOf:
		         '{ f(a: $v, b: [1, 2.5, "x\"y", true, null, RED], c: {x: 1, y: [$w]}) }')
		        arguments.
	self assert: (args at: 'a') asGraphQLString equals: '$v'.
	self
		assert: (args at: 'b') asGraphQLString
		equals: '[1, 2.5, "x\"y", true, null, RED]'.
	self assert: (args at: 'c') asGraphQLString equals: '{x: 1, y: [$w]}'
]

{ #category : 'tests' }
GQLParserTest >> testComments [

	| document |
	document := GQLParser parse: '# the query
query Q { # open
  a # field a
  # standalone
  b
} # trailing'.
	self
		assert:
			(document operations first selectionSet selections collect: [ :f |
				 f name ]) asArray
		equals: #( 'a' 'b' )
]

{ #category : 'tests' }
GQLParserTest >> testDirectives [

	| document field directives spread inline |
	document := GQLParser parse:
		            'query Q($x: Boolean!) @opDir { a @skip(if: $x) @include(if: true) ...F @skip(if: false) ... on T @include(if: $x) { b } } fragment F on T { c }'.
	self assert: document operations first directives size equals: 1.
	self
		assert: document operations first directives first name
		equals: 'opDir'.
	self assert:
		document operations first directives first arguments isEmpty.
	field := document operations first selectionSet selections first.
	directives := field directives.
	self
		assert: (directives collect: [ :d | d name ]) asArray
		equals: #( 'skip' 'include' ).
	self
		assert: (directives first arguments at: 'if') class
		equals: GQLVariableValue.
	self assert: (directives first arguments at: 'if') name equals: 'x'.
	self assert:
		((directives first arguments at: 'if') valueWithVariables:
			 (Dictionary new
				  at: 'x' put: true;
				  yourself)).
	self
		assert: (directives second arguments at: 'if') class
		equals: GQLBooleanValue.
	self assert: (directives second arguments at: 'if') value.
	spread := document operations first selectionSet selections second.
	self assert: spread isFragmentSpread.
	self assert: spread directives first name equals: 'skip'.
	inline := document operations first selectionSet selections third.
	self assert: inline isInlineFragment.
	self assert: inline typeCondition equals: 'T'.
	self assert: inline directives first name equals: 'include'
]

{ #category : 'tests - errors' }
GQLParserTest >> testErrorEmptyDocument [

	| error |
	error := self
		         assertSyntaxError: [ GQLParser parse: '' ]
		         line: 1
		         column: 1.
	self
		assert: error messageText
		equals: 'Syntax Error: Unexpected <EOF>. (line 1, column 1)'.
	"Only ignored tokens is still an empty document"
	self
		assertSyntaxError: [
				GQLParser parse: '  # nothing
' ]
		line: 2
		column: 1
]

{ #category : 'tests - errors' }
GQLParserTest >> testErrorEmptySelectionSet [

	| error |
	error := self
		         assertSyntaxError: [ GQLParser parse: '{ }' ]
		         line: 1
		         column: 3.
	self
		assert: error messageText
		equals: 'Syntax Error: Expected Name, found "}". (line 1, column 3)'
]

{ #category : 'tests - errors' }
GQLParserTest >> testErrorFragmentNamedOn [
	"'on' is not a valid fragment name"

	| error |
	error := self
		         assertSyntaxError: [
		         GQLParser parse: 'fragment on X { a }' ]
		         line: 1
		         column: 10.
	self
		assert: error messageText
		equals: 'Syntax Error: Unexpected Name "on". (line 1, column 10)'.
	"...nor a valid spread name: '...on' starts an inline fragment that lacks a type"
	self should: [ GQLParser parse: '{ ...on }' ] raise: GQLSyntaxError
]

{ #category : 'tests - errors' }
GQLParserTest >> testErrorInvalidTypeRef [

	| error |
	error := self
		         assertSyntaxError: [ GQLParser parseTypeRef: '[ID!]!!' ]
		         line: 1
		         column: 7.
	self
		assert: error messageText
		equals: 'Syntax Error: Unexpected "!". (line 1, column 7)'.
	self
		assertSyntaxError: [ GQLParser parseTypeRef: '[ID' ]
		line: 1
		column: 4.
	self
		assertSyntaxError: [ GQLParser parseTypeRef: '' ]
		line: 1
		column: 1
]

{ #category : 'tests - errors' }
GQLParserTest >> testErrorMisc [
	"Various malformed documents, with positions on later lines"

	self
		assertSyntaxError: [
				GQLParser parse: '{ a }
}' ]
		line: 2
		column: 1.
	self
		assertSyntaxError: [ GQLParser parse: 'query Q($x: = 1) { a }' ]
		line: 1
		column: 13.
	self
		assertSyntaxError: [
			GQLParser parse:
				'query Q { a(x: $v) }  query Q2($d: Int = $v) { b }' ]
		line: 1
		column: 42.
	self
		assertSyntaxError: [ GQLParser parse: 'unknown { a }' ]
		line: 1
		column: 1.
	self
		assertSyntaxError: [
				GQLParser parse: '{
  a(x: 1
' ]
		line: 3
		column: 1.
	"Lexer errors propagate through the parser"
	self
		assertSyntaxError: [ GQLParser parse: '{ a(x: "abc) }' ]
		line: 1
		column: 15
]

{ #category : 'tests - errors' }
GQLParserTest >> testErrorUnclosedArguments [

	| error |
	error := self
		         assertSyntaxError: [ GQLParser parse: '{ a(' ]
		         line: 1
		         column: 5.
	self
		assert: error messageText
		equals:
		'Syntax Error: Expected Name, found <EOF>. (line 1, column 5)'
]

{ #category : 'tests' }
GQLParserTest >> testFieldLineAndColumn [

	| hero name |
	hero := self firstFieldOf: '{
  hero {
    name
  }
}'.
	self assert: hero line equals: 2.
	self assert: hero column equals: 3.
	name := hero selectionSet selections first.
	self assert: name line equals: 3.
	self assert: name column equals: 5.
	self assert: name location equals: (Dictionary new
			 at: 'line' put: 3;
			 at: 'column' put: 5;
			 yourself).
	"An aliased field is located at its alias"
	self assert: (self firstFieldOf: '{ x: y }') column equals: 3
]

{ #category : 'tests' }
GQLParserTest >> testFluidIntrospectionQuery [
	"Exact introspection query sent by the Fluid client"

	| operation type fields typeField depth ref |
	operation := (GQLParser parse:
		              'query FluidTypeDeep($name: String!) { __type(name: $name) { kind name description fields(includeDeprecated: false) { name description args { name type { kind name ofType { kind name ofType { kind name } } } } type { kind name ofType { kind name ofType { kind name ofType { kind name } } } } __typename } __typename } }')
		             operations first.
	self assert: operation name equals: 'FluidTypeDeep'.
	self assert: operation variableDefinitions first name equals: 'name'.
	self
		assert: operation variableDefinitions first typeRef printString
		equals: 'String!'.
	type := operation selectionSet selections first.
	self assert: type name equals: '__type'.
	self assert: (type arguments at: 'name') isVariable.
	self
		assert:
			((type arguments at: 'name') valueWithVariables: (Dictionary new
					  at: 'name' put: 'Characters';
					  yourself))
		equals: 'Characters'.
	self
		assert:
		(type selectionSet selections collect: [ :f | f name ]) asArray
		equals: #( 'kind' 'name' 'description' 'fields' '__typename' ).
	fields := type selectionSet selections fourth.
	self
		assert:
		((fields arguments at: 'includeDeprecated') valueWithVariables: nil)
		equals: false.
	self
		assert:
		(fields selectionSet selections collect: [ :f | f name ]) asArray
		equals: #( 'name' 'description' 'args' 'type' '__typename' ).
	"type { kind name ofType { kind name ofType { kind name ofType { kind name } } } } : 3 nested ofType"
	typeField := fields selectionSet selections fourth.
	depth := 0.
	ref := typeField.
	[
		(ref selectionSet selections
			 detect: [ :f | f name = 'ofType' ]
			 ifNone: [ nil ]) notNil ] whileTrue: [
			ref := ref selectionSet selections detect: [ :f |
				       f name = 'ofType' ].
			depth := depth + 1 ].
	self assert: depth equals: 3.
	self
		assert:
		(ref selectionSet selections collect: [ :f | f name ]) asArray
		equals: #( 'kind' 'name' )
]

{ #category : 'tests' }
GQLParserTest >> testFragments [
	"Named fragment spreads, inline fragments with and without type condition, fragment definitions"

	| document selections spread typed untyped fragment |
	document := GQLParser parse: '
query Q {
  hero {
    ...HeroFields
    ... on Droid { primaryFunction }
    ... { id }
  }
}
fragment HeroFields on Character { name }'.
	self assert: document definitions size equals: 2.
	self assert: document operations size equals: 1.
	selections := document operations first selectionSet selections first
		              selectionSet selections.
	self assert: selections size equals: 3.
	spread := selections first.
	self assert: spread isFragmentSpread.
	self assert: spread class equals: GQLFragmentSpread.
	self assert: spread name equals: 'HeroFields'.
	typed := selections second.
	self assert: typed isInlineFragment.
	self assert: typed typeCondition equals: 'Droid'.
	self
		assert: typed selectionSet selections first name
		equals: 'primaryFunction'.
	untyped := selections third.
	self assert: untyped isInlineFragment.
	self assert: untyped typeCondition isNil.
	self assert: untyped selectionSet selections first name equals: 'id'.
	self assert: document fragments size equals: 1.
	fragment := document fragments at: 'HeroFields'.
	self assert: fragment isFragmentDefinition.
	self assert: fragment name equals: 'HeroFields'.
	self assert: fragment typeCondition equals: 'Character'.
	self
		assert: fragment selectionSet selections first name
		equals: 'name'
]

{ #category : 'tests' }
GQLParserTest >> testMultipleOperations [

	| document |
	document := GQLParser parse:
		            'query A { a } mutation B { b } subscription C { c } fragment F on T { f }'.
	self assert: document definitions size equals: 4.
	self assert: document operations size equals: 3.
	self assert: (document operationNamed: 'A') isQuery.
	self assert: (document operationNamed: 'B') isMutation.
	self assert: (document operationNamed: 'C') isSubscription.
	self
		assert:
		(document operationNamed: 'C') selectionSet selections first name
		equals: 'c'.
	self assert: (document operationNamed: 'F') isNil.
	self assert: (document operationNamed: 'Unknown') isNil
]

{ #category : 'tests' }
GQLParserTest >> testMutationAndSubscriptionKeywords [

	| mutation subscription |
	mutation := (GQLParser parse: 'mutation { like(id: 1) { count } }')
		            operations first.
	self assert: mutation operation equals: #mutation.
	self assert: mutation isMutation.
	self deny: mutation isQuery.
	self deny: mutation isSubscription.
	self assert: mutation name isNil.
	subscription := (GQLParser parse:
		                 'subscription OnEvent($x: Int) { event }')
		                operations first.
	self assert: subscription operation equals: #subscription.
	self assert: subscription isSubscription.
	self assert: subscription name equals: 'OnEvent'.
	self assert: subscription variableDefinitions size equals: 1
]

{ #category : 'tests' }
GQLParserTest >> testNamedQueryWithVariables [

	| operation vars |
	operation := (GQLParser parse:
		              'query Q($id: ID!, $t: Int = 10, $l: [String!]!) { a }')
		             operations first.
	self assert: operation name equals: 'Q'.
	self assert: operation isQuery.
	vars := operation variableDefinitions.
	self assert: vars size equals: 3.
	self
		assert: (vars collect: [ :v | v name ]) asArray
		equals: #( 'id' 't' 'l' ).
	"Type references print back as SDL"
	self
		assert: (vars collect: [ :v | v typeRef printString ]) asArray
		equals: #( 'ID!' 'Int' '[String!]!' ).
	self assert: vars first typeRef isNonNull.
	self assert: vars first typeRef namedType name equals: 'ID'.
	self deny: vars second typeRef isNonNull.
	self assert: vars second typeRef isNamed.
	self assert: vars third typeRef isNonNull.
	self assert: vars third typeRef ofType isList.
	self assert: vars third typeRef ofType ofType isNonNull.
	self assert: vars third typeRef namedType name equals: 'String'.
	"Default values"
	self assert: vars first defaultValue isNil.
	self assert: vars second defaultValue class equals: GQLIntValue.
	self assert: vars second defaultValue value equals: 10.
	self assert: vars third defaultValue isNil
]

{ #category : 'tests' }
GQLParserTest >> testNestedSelections [

	| hero friends |
	hero := self firstFieldOf:
		        '{ hero { name friends { name id } appearsIn } }'.
	self assert: hero name equals: 'hero'.
	self
		assert:
		(hero selectionSet selections collect: [ :f | f name ]) asArray
		equals: #( 'name' 'friends' 'appearsIn' ).
	friends := hero selectionSet selections second.
	self
		assert:
		(friends selectionSet selections collect: [ :f | f name ]) asArray
		equals: #( 'name' 'id' ).
	self assert: hero selectionSet selections first selectionSet isNil
]

{ #category : 'tests' }
GQLParserTest >> testParseTypeRef [

	| ref |
	ref := GQLParser parseTypeRef: '[ID!]!'.
	self assert: ref printString equals: '[ID!]!'.
	self assert: ref class equals: GQLNonNullTypeRef.
	self assert: ref isNonNull.
	self deny: ref isList.
	self assert: ref ofType class equals: GQLListTypeRef.
	self assert: ref ofType isList.
	self assert: ref nullableType printString equals: '[ID!]'.
	self assert: ref namedType class equals: GQLNamedTypeRef.
	self assert: ref namedType name equals: 'ID'.
	self assert: ref equals: (GQLNonNullTypeRef of: (GQLListTypeRef of:
				  (GQLNonNullTypeRef of: (GQLNamedTypeRef named: 'ID')))).
	self
		assert: (GQLParser parseTypeRef: 'String') printString
		equals: 'String'.
	self
		assert: (GQLParser parseTypeRef: '[[Int]]') printString
		equals: '[[Int]]'.
	self
		assert: (GQLParser parseTypeRef: ' [ Int ! ] ') printString
		equals: '[Int!]'
]

{ #category : 'tests' }
GQLParserTest >> testParseValue [
	"GQLParser class>>parseValue: parses constant values only"

	| value |
	value := GQLParser parseValue:
		         '{a: [1, 2.5, "x", true, null, RED], b: {c: -3}}'.
	self assert: value class equals: GQLObjectValue.
	self assert: (value valueWithVariables: nil) equals: (Dictionary new
			 at: 'a' put: (Array
					  with: 1
					  with: 2.5
					  with: 'x'
					  with: true
					  with: nil
					  with: 'RED');
			 at: 'b' put: (Dictionary new
					  at: 'c' put: -3;
					  yourself);
			 yourself).
	self assert: (GQLParser parseValue: '42') value equals: 42.
	self
		assertSyntaxError: [ GQLParser parseValue: '$v' ]
		line: 1
		column: 1.
	self
		assertSyntaxError: [ GQLParser parseValue: '1 2' ]
		line: 1
		column: 3
]

{ #category : 'tests' }
GQLParserTest >> testShorthandQuery [
	"'{ ... }' is an anonymous query"

	| document operation |
	document := GQLParser parse: '{ hero { name } }'.
	self assert: document class equals: GQLDocument.
	self assert: document definitions size equals: 1.
	self assert: document operations size equals: 1.
	self assert: document fragments isEmpty.
	operation := document operations first.
	self assert: operation isOperationDefinition.
	self assert: operation operation equals: #query.
	self assert: operation isQuery.
	self assert: operation name isNil.
	self assert: operation variableDefinitions isEmpty.
	self assert: operation directives isEmpty.
	self assert: operation selectionSet selections size equals: 1.
	self
		assert: operation selectionSet selections first name
		equals: 'hero'
]

{ #category : 'tests' }
GQLParserTest >> testTypename [

	| selections |
	selections := (GQLParser parse:
		               '{ __typename hero { __typename name } }') operations
		              first selectionSet selections.
	self assert: selections first name equals: '__typename'.
	self assert: selections first responseKey equals: '__typename'.
	self assert: selections first arguments isEmpty.
	self assert: selections first selectionSet isNil.
	self
		assert: selections second selectionSet selections first name
		equals: '__typename'
]

{ #category : 'tests' }
GQLParserTest >> testValueWithVariables [
	"Literal AST values are converted to Smalltalk objects, variables are resolved from the dictionary"

	| args vars |
	args := (self firstFieldOf:
		         '{ f(a: $v, b: [1, $w, null], c: {x: $v, e: RED}, d: 2.5, s: "x", m: $missing) }')
		        arguments.
	vars := Dictionary new
		        at: 'v' put: 'hello';
		        at: 'w' put: 7;
		        yourself.
	self
		assert: ((args at: 'a') valueWithVariables: vars)
		equals: 'hello'.
	self
		assert: ((args at: 'b') valueWithVariables: vars) asArray
		equals: #( 1 7 nil ).
	self
		assert: ((args at: 'c') valueWithVariables: vars)
		equals: (Dictionary new
				 at: 'x' put: 'hello';
				 at: 'e' put: 'RED';
				 yourself).
	self assert: ((args at: 'd') valueWithVariables: vars) equals: 2.5.
	self assert: ((args at: 's') valueWithVariables: nil) equals: 'x'.
	"Missing variables resolve to nil; isDefinedIn: distinguishes them"
	self assert: ((args at: 'm') valueWithVariables: vars) isNil.
	self assert: ((args at: 'a') valueWithVariables: nil) isNil.
	self assert: ((args at: 'a') isDefinedIn: vars).
	self deny: ((args at: 'm') isDefinedIn: vars).
	self deny: ((args at: 'a') isDefinedIn: nil).
	self assert: ((args at: 'a') isDefinedIn: (Dictionary new
				  at: 'v' put: nil;
				  yourself))
]
