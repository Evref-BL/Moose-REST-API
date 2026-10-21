"
Unit tests for the GraphQL schema model (package GraphQL-Core, tag Schema): built-in scalars and their serialize:/coerce: rules, enums, list/non-null wrappers, GQLSchemaBuilder (forward references, validation errors), field resolution (default resolver and resolver blocks) and argument defaults.
"
Class {
	#name : 'GQLSchemaTest',
	#superclass : 'TestCase',
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'helpers' }
GQLSchemaTest >> peopleSchema [
	"Query references Person before Person is declared (forward reference)"

	| builder |
	builder := GQLSchemaBuilder new.
	builder object: 'Query' fields: [ :t |
			t field: 'people' type: '[Person!]!' resolve: [ #(  ) ].
			t field: 'hello' type: 'String' ].
	builder object: 'Person' description: 'A person' fields: [ :t |
			t field: 'name' type: 'String!'.
			t field: 'id' type: 'ID!' ].
	^ builder build
]

{ #category : 'tests - schema' }
GQLSchemaTest >> testAllNamedTypes [
	"allNamedTypes lists built-in scalars and user types, sorted by name (introspection types, named __*, are ignored here)"

	| schema names |
	schema := self peopleSchema.
	names := (schema allNamedTypes collect: [ :t | t name ]) reject: [
		         :each | each beginsWith: '__' ].
	self
		assert: names asArray
		equals: #( 'Boolean' 'Float' 'ID' 'Int' 'Person' 'Query' 'String' ).
	self
		assert:
			((schema objectTypes collect: [ :t | t name ]) reject: [ :each |
				 each beginsWith: '__' ]) asArray
		equals: #( 'Person' 'Query' ).
	self assert: schema validate identicalTo: schema
]

{ #category : 'tests - arguments' }
GQLSchemaTest >> testArgumentsAndDefaults [
	"Arguments declared through the builder in the three accepted forms; defaults and their GraphQL literals"

	| builder schema field take skip order greeting |
	builder := GQLSchemaBuilder new.
	builder enum: 'Color' values: #( 'RED' 'GREEN' ).
	builder object: 'Query' fields: [ :t |
			t
				field: 'items'
				type: '[String]'
				description: 'Some items'
				args: {
						('take' -> 'Int').
						(GQLArgument name: 'skip' type: 'Int' default: 10).
						('order' -> #( 'Color' 'RED' )) }
				resolve: [ :s :a | #(  ) ].
			t
				field: 'greeting'
				type: 'String'
				description: 'Hi'
				resolve: [ 'hi' ].
			t
				field: 'echo'
				type: 'String'
				args: { (GQLArgument name: 'text' type: 'String' default: 'a"b') }
				resolve: [ :s :a | a at: 'text' ] ].
	schema := builder build.
	field := schema queryType fieldNamed: 'items'.
	self assert: field description equals: 'Some items'.
	self
		assert: field arguments keys asArray
		equals: #( 'take' 'skip' 'order' ).
	take := field argumentNamed: 'take'.
	self assert: take type identicalTo: (schema typeNamed: 'Int').
	self deny: take hasDefault.
	self assert: take defaultValueLiteral isNil.
	skip := field argumentNamed: 'skip'.
	self assert: skip hasDefault.
	self assert: skip defaultValue equals: 10.
	self assert: skip defaultValueLiteral equals: '10'.
	order := field argumentNamed: 'order'.
	self assert: order type identicalTo: (schema typeNamed: 'Color').
	self assert: order defaultValue equals: 'RED'.
	self assert: order defaultValueLiteral equals: 'RED'.
	self assert: (field argumentNamed: 'missing') isNil.
	self
		assert:
			((schema queryType fieldNamed: 'echo') argumentNamed: 'text')
				defaultValueLiteral
		equals: '"a\"b"'.
	greeting := schema queryType fieldNamed: 'greeting'.
	self assert: greeting description equals: 'Hi'.
	self
		assert: (greeting resolve: nil args: Dictionary new context: nil)
		equals: 'hi'.
	"a nil default is still a default, distinct from no default"
	self assert:
		(GQLArgument name: 'x' type: 'Int' default: nil) hasDefault.
	self
		assert:
		(GQLArgument name: 'x' type: 'Int' default: nil) defaultValueLiteral
		equals: 'null'.
	self deny: (GQLArgument name: 'x' type: 'Int') hasDefault
]

{ #category : 'tests - scalars' }
GQLSchemaTest >> testBooleanScalar [
	"Boolean only accepts true and false (no truthy integers)"

	| bool |
	bool := GQLScalarType boolean.
	self assert: (bool serialize: true) equals: true.
	self assert: (bool coerce: false) equals: false.
	self should: [ bool coerce: 1 ] raise: GQLCoercionError.
	self should: [ bool coerce: 'true' ] raise: GQLCoercionError.
	self should: [ bool serialize: 0 ] raise: GQLCoercionError
]

{ #category : 'tests - builder' }
GQLSchemaTest >> testBuildWithUnknownArgumentTypeMentionsArgument [
	"Unknown argument types are reported with the argument and its field"

	| builder message |
	builder := GQLSchemaBuilder new.
	builder object: 'Query' fields: [ :t |
			t
				field: 'pets'
				type: 'String'
				args: { ('filter' -> 'PetFilter') }
				resolve: nil ].
	message := [
		           builder build.
		           nil ]
		           on: Error
		           do: [ :e | e messageText ].
	self assert: message notNil.
	self assert: (message includesSubstring: '"PetFilter"').
	self assert: (message includesSubstring: '"filter"').
	self assert: (message includesSubstring: 'Query.pets')
]

{ #category : 'tests - builder' }
GQLSchemaTest >> testBuildWithUnknownTypeMentionsField [
	"Referencing an undeclared type fails at build time with a message naming the type and the field"

	| builder message |
	builder := GQLSchemaBuilder new.
	builder
		object: 'Query'
		fields: [ :t | t field: 'pets' type: '[Pet]' ].
	message := [
		           builder build.
		           nil ]
		           on: Error
		           do: [ :e | e messageText ].
	self assert: message notNil.
	self assert: (message includesSubstring: '"Pet"').
	self assert: (message includesSubstring: 'Query.pets')
]

{ #category : 'tests - builder' }
GQLSchemaTest >> testBuilderErrors [
	"Duplicate type names, missing query type, duplicate fields in a builder block"

	| builder |
	builder := GQLSchemaBuilder new.
	builder
		object: 'Person'
		fields: [ :t | t field: 'name' type: 'String' ].
	self
		should: [
		builder object: 'Person' fields: [ :t | t field: 'x' type: 'Int' ] ]
		raise: Error.
	self should: [ builder enum: 'String' values: #( 'A' ) ] raise: Error.
	"no Query type declared"
	self should: [ builder build ] raise: Error.
	self
		should: [
				GQLSchemaBuilder new object: 'Query' fields: [ :t |
						t field: 'a' type: 'Int'.
						t field: 'a' type: 'Int' ] ]
		raise: Error.
	"an explicit query: name is honoured"
	builder query: 'Person'.
	self assert: builder build queryType name equals: 'Person'
]

{ #category : 'tests - builder' }
GQLSchemaTest >> testBuilderResolvesForwardReferences [
	"Query.people references Person, declared later; after build the field type is resolved
	and its named type is the very instance registered in the schema"

	| schema people person |
	schema := self peopleSchema.
	person := schema typeNamed: 'Person'.
	self assert: person notNil.
	self assert: person description equals: 'A person'.
	self
		assert: schema queryType
		identicalTo: (schema typeNamed: 'Query').
	people := schema queryType fieldNamed: 'people'.
	self assert: people type printString equals: '[Person!]!'.
	self assert: people type kind equals: 'NON_NULL'.
	self assert: people type namedType identicalTo: person.
	self
		assert: (person fieldNamed: 'id') type ofType
		identicalTo: (schema typeNamed: 'ID').
	self
		assert: (schema queryType fieldNamed: 'hello') type
		identicalTo: (schema typeNamed: 'String')
]

{ #category : 'tests - schema' }
GQLSchemaTest >> testBuiltInScalarsAreRegistered [
	"A fresh schema knows the five spec scalars; unknown names answer nil"

	| schema |
	schema := GQLSchema new.
	#( 'String' 'Int' 'Float' 'Boolean' 'ID' ) do: [ :n |
			| type |
			type := schema typeNamed: n.
			self assert: type notNil.
			self assert: type isScalar.
			self assert: type name equals: n.
			self assert: type kind equals: 'SCALAR' ].
	self assert: (schema typeNamed: 'Nope') isNil.
	self assert: (schema typeNamed: nil) isNil.
	self
		assert: (GQLScalarType builtIns collect: [ :t | t name ]) asArray
		equals: #( 'String' 'Int' 'Float' 'Boolean' 'ID' )
]

{ #category : 'tests - resolution' }
GQLSchemaTest >> testDefaultResolverOnDictionary [
	"Dictionary sources are looked up by String key first, then Symbol key; missing keys answer nil"

	| field |
	field := GQLFieldDefinition name: 'name' type: 'String'.
	self
		assert: (field
				 resolve: (Dictionary new
						  at: 'name' put: 'str';
						  yourself)
				 args: Dictionary new
				 context: nil)
		equals: 'str'.
	self
		assert: (field
				 resolve: (Dictionary new
						  at: #name put: 'sym';
						  yourself)
				 args: Dictionary new
				 context: nil)
		equals: 'sym'.
	self assert: (field
			 resolve: (Dictionary new
					  at: 'other' put: 1;
					  yourself)
			 args: Dictionary new
			 context: nil) isNil.
	self assert:
		(field resolve: nil args: Dictionary new context: nil) isNil
]

{ #category : 'tests - resolution' }
GQLSchemaTest >> testDefaultResolverOnObject [
	"Other objects receive the unary message named like the field; unknown or non-unary names answer nil"

	| numerator unknown keyword binary |
	numerator := GQLFieldDefinition name: 'numerator' type: 'Int'.
	self
		assert: (numerator resolve: 3 / 4 args: Dictionary new context: nil)
		equals: 3.
	unknown := GQLFieldDefinition name: 'notAMessage' type: 'Int'.
	self assert:
		(unknown resolve: 3 / 4 args: Dictionary new context: nil) isNil.
	keyword := GQLFieldDefinition name: 'at:' type: 'Int'.
	self assert:
		(keyword resolve: #( 1 2 ) args: Dictionary new context: nil) isNil.
	binary := GQLFieldDefinition name: '+' type: 'Int'.
	self assert:
		(binary resolve: 3 args: Dictionary new context: nil) isNil
]

{ #category : 'tests - builder' }
GQLSchemaTest >> testEmptyObjectTypeFailsValidation [
	"Every object type must define at least one field"

	| builder message |
	builder := GQLSchemaBuilder new.
	builder
		object: 'Query'
		fields: [ :t | t field: 'hello' type: 'String' ].
	builder object: 'Empty' fields: [ :t |  ].
	message := [
		           builder build.
		           nil ]
		           on: Error
		           do: [ :e | e messageText ].
	self assert: message notNil.
	self assert: (message includesSubstring: '"Empty"').
	self assert: (message includesSubstring: 'at least one field')
]

{ #category : 'tests - enums' }
GQLSchemaTest >> testEnumType [
	"Enum values serialize to their String name; unknown values signal GQLCoercionError"

	| color |
	color := GQLEnumType name: 'Color' values: #( #A 'B' ).
	self assert: color kind equals: 'ENUM'.
	self assert: color isEnum.
	self assert: color isLeaf.
	self assert: color isInputType.
	self assert: color valueNames asArray equals: #( 'A' 'B' ).
	self assert: (color serialize: #A) equals: 'A'.
	self deny: (color serialize: #A) isSymbol.
	self assert: (color coerce: 'B') equals: 'B'.
	self assert: (color serialize: nil) isNil.
	self should: [ color coerce: 'C' ] raise: GQLCoercionError.
	self should: [ color serialize: 1 ] raise: GQLCoercionError.
	self should: [ color addValue: 'A' ] raise: Error
]

{ #category : 'tests - scalars' }
GQLSchemaTest >> testFloatScalar [
	"Float answers Floats; non-finite values serialize to nil and are rejected on input"

	| float |
	float := GQLScalarType float.
	self assert: (float serialize: 1.5) equals: 1.5.
	self assert: (float serialize: 2) equals: 2.0.
	self assert: (float serialize: Float infinity) isNil.
	self assert: (float serialize: Float nan) isNil.
	self should: [ float serialize: 'x' ] raise: GQLCoercionError.
	self assert: (float coerce: 2) equals: 2.0.
	self assert: (float coerce: 2) isFloat.
	self should: [ float coerce: Float nan ] raise: GQLCoercionError.
	self should: [ float coerce: Float infinity ] raise: GQLCoercionError.
	self should: [ float coerce: '1.5' ] raise: GQLCoercionError
]

{ #category : 'tests - scalars' }
GQLSchemaTest >> testIDScalar [
	"ID accepts Strings and Integers and always answers a String"

	| id |
	id := GQLScalarType id.
	self assert: (id serialize: 12) equals: '12'.
	self assert: (id serialize: 'abc') equals: 'abc'.
	self assert: (id coerce: 5) equals: '5'.
	self assert: (id coerce: 'x1') equals: 'x1'.
	self should: [ id coerce: 1.5 ] raise: GQLCoercionError.
	self should: [ id coerce: true ] raise: GQLCoercionError
]

{ #category : 'tests - scalars' }
GQLSchemaTest >> testIntScalar [
	"Int accepts integers, integral floats and integer-looking strings on input; rejects fractions and non-numbers"

	| int |
	int := GQLScalarType int.
	self assert: (int serialize: 7) equals: 7.
	self assert: (int serialize: 4.0) equals: 4.
	self should: [ int serialize: 4.5 ] raise: GQLCoercionError.
	self assert: (int coerce: 42) equals: 42.
	self assert: (int coerce: '-42') equals: -42.
	self assert: (int coerce: 3.0) equals: 3.
	self assert: (int coerce: 3.0) isInteger.
	self should: [ int coerce: 3.5 ] raise: GQLCoercionError.
	self should: [ int coerce: 'abc' ] raise: GQLCoercionError.
	self should: [ int coerce: true ] raise: GQLCoercionError
]

{ #category : 'tests - builder' }
GQLSchemaTest >> testNonInputArgumentTypeFailsValidation [
	"Object types cannot be used as argument types"

	| builder message |
	builder := GQLSchemaBuilder new.
	builder object: 'Query' fields: [ :t |
			t
				field: 'find'
				type: 'Person'
				args: { ('like' -> 'Person') }
				resolve: nil ].
	builder
		object: 'Person'
		fields: [ :t | t field: 'name' type: 'String' ].
	message := [
		           builder build.
		           nil ]
		           on: Error
		           do: [ :e | e messageText ].
	self assert: message notNil.
	self assert: (message includesSubstring: 'not an input type').
	self assert: (message includesSubstring: '"like"')
]

{ #category : 'tests - types' }
GQLSchemaTest >> testObjectTypeFields [
	"fieldNamed: answers nil when absent; adding a field twice is an error; fields keep declaration order"

	| type |
	type := GQLObjectType name: 'Person'.
	type addField:
		(GQLFieldDefinition name: 'name' type: GQLScalarType string).
	type addField:
		(GQLFieldDefinition name: 'age' type: GQLScalarType int).
	self assert: type fields keys asArray equals: #( 'name' 'age' ).
	self assert: (type fieldNamed: 'name') name equals: 'name'.
	self assert: (type fieldNamed: #age) type name equals: 'Int'.
	self assert: (type fieldNamed: 'missing') isNil.
	self
		should: [
		type addField: (GQLFieldDefinition name: 'name' type: 'String') ]
		raise: Error
]

{ #category : 'tests - schema' }
GQLSchemaTest >> testResolveTypeRef [
	"resolveTypeRef: accepts a type String or a parsed type ref AST and builds the wrappers"

	| schema type message |
	schema := GQLSchema new.
	type := schema resolveTypeRef: '[Int!]'.
	self assert: type kind equals: 'LIST'.
	self assert: type printString equals: '[Int!]'.
	self assert: type namedType identicalTo: (schema typeNamed: 'Int').
	type := schema resolveTypeRef: (GQLParser parseTypeRef: 'String!').
	self assert: type kind equals: 'NON_NULL'.
	self assert: type ofType identicalTo: (schema typeNamed: 'String').
	message := [
		           schema resolveTypeRef: '[Unknown]!'.
		           nil ]
		           on: Error
		           do: [ :e | e messageText ].
	self assert: message equals: 'Unknown type "Unknown"'
]

{ #category : 'tests - resolution' }
GQLSchemaTest >> testResolverBlocks [
	"Resolver blocks are invoked with cull:cull:cull: so they may take 0 to 3 arguments (source, args, context)"

	| field args |
	args := Dictionary new
		        at: 'n' put: 2;
		        yourself.
	field := GQLFieldDefinition name: 'f' type: 'Int'.
	field resolver: [ 42 ].
	self assert: (field resolve: 10 args: args context: 'ctx') equals: 42.
	field resolver: [ :source | source + 1 ].
	self assert: (field resolve: 10 args: args context: 'ctx') equals: 11.
	field resolver: [ :source :arguments | source * (arguments at: 'n') ].
	self assert: (field resolve: 10 args: args context: 'ctx') equals: 20.
	field resolver: [ :source :arguments :context |
			{
				source.
				(arguments at: 'n').
				context } ].
	self
		assert: (field resolve: 10 args: args context: 'ctx')
		equals: { 10. 2. 'ctx' }.
	"a resolver takes precedence over the default resolver"
	field := GQLFieldDefinition name: 'numerator' type: 'Int'.
	field resolver: [ :source | source denominator ].
	self assert: (field resolve: 3 / 4 args: args context: nil) equals: 4
]

{ #category : 'tests - scalars' }
GQLSchemaTest >> testScalarsPassNilThrough [
	"nil is never coerced nor serialized: it is passed through by every scalar"

	GQLScalarType builtIns do: [ :t |
			self assert: (t serialize: nil) isNil.
			self assert: (t coerce: nil) isNil ]
]

{ #category : 'tests - scalars' }
GQLSchemaTest >> testStringScalar [
	"String output is lenient (numbers, booleans, symbols become Strings) but input requires a String"

	| string result |
	string := GQLScalarType string.
	self assert: (string serialize: 'abc') equals: 'abc'.
	self assert: (string serialize: 3.5) equals: '3.5'.
	self assert: (string serialize: 12) equals: '12'.
	self assert: (string serialize: true) equals: 'true'.
	result := string serialize: #sym.
	self assert: result equals: 'sym'.
	self deny: result isSymbol.
	self assert: (string coerce: 'x') equals: 'x'.
	self deny: (string coerce: #sym) isSymbol.
	self should: [ string coerce: 3 ] raise: GQLCoercionError.
	self should: [ string coerce: true ] raise: GQLCoercionError
]

{ #category : 'tests - types' }
GQLSchemaTest >> testWrapperTypes [
	"[Person!]! : kind/ofType chain NON_NULL -> LIST -> NON_NULL -> OBJECT, SDL printing, anonymous wrappers"

	| person type list inner |
	person := GQLObjectType name: 'Person'.
	type := GQLNonNullType of:
		        (GQLListType of: (GQLNonNullType of: person)).
	self assert: type printString equals: '[Person!]!'.
	self assert: type sdlString equals: '[Person!]!'.
	self assert: type kind equals: 'NON_NULL'.
	self assert: type name isNil.
	self assert: type isWrapper.
	list := type ofType.
	self assert: list kind equals: 'LIST'.
	self assert: list name isNil.
	self assert: list isList.
	inner := list ofType.
	self assert: inner kind equals: 'NON_NULL'.
	self assert: inner ofType identicalTo: person.
	self assert: person kind equals: 'OBJECT'.
	self assert: person ofType isNil.
	self assert: person printString equals: 'Person'.
	self assert: type namedType identicalTo: person.
	self assert: type nullableType identicalTo: list.
	self deny: type isInputType.
	self assert: (GQLListType of: GQLScalarType int) isInputType
]
