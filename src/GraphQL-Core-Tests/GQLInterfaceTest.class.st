"
Tests for GraphQL INTERFACE support: schema building and validation (IsValidImplementation rules), execution of fields typed by an interface (runtime type resolution, fragments, __typename) and introspection of interface types.

The shared fixture (see #schemaWithResolver:) is:
	interface Node { id: ID! }
	interface Named implements Node { id: ID! name: String }
	type User implements Node & Named { id: ID! name: String email: String }
	type Post implements Node { id: ID! title: String }
	type Query { nodes: [Node!]! node(id: ID!): Node user: User named: Named }
Values are Dictionaries whose 'kind' key names their concrete type.
"
Class {
	#name : 'GQLInterfaceTest',
	#superclass : 'TestCase',
	#instVars : [
		'schema'
	],
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'helpers' }
GQLInterfaceTest >> buildErrorOf: aBuilder [
	"Build aBuilder and answer the message text of the signalled Error, or nil when the build succeeds"

	^ [
		  aBuilder build.
		  nil ]
		  on: Error
		  do: [ :e | e messageText ]
]

{ #category : 'helpers' }
GQLInterfaceTest >> builderWithResolver: aResolverBlockOrNil [
	"Answer an unbuilt builder for the fixture schema:
		interface Node { id: ID! }
		interface Named implements Node { id: ID!, name: String }
		type User implements Node & Named { id: ID!, name: String, email: String }
		type Post implements Node { id: ID!, title: String }
		type Query { nodes: [Node!]!, node(id: ID!): Node, user: User, named: [Named!]! }
	aResolverBlockOrNil is installed as the schema typeResolver"

	| b values |
	values := {
		          self userValue.
		          self postValue }.
	b := GQLSchemaBuilder new.
	b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	b
		interface: 'Named'
		description: nil
		implements: #( 'Node' )
		fields: [ :o |
				o field: 'id' type: 'ID!'.
				o field: 'name' type: 'String' ].
	b
		object: 'User'
		description: nil
		implements: #( 'Node' 'Named' )
		fields: [ :o |
				o field: 'id' type: 'ID!'.
				o field: 'name' type: 'String'.
				o field: 'email' type: 'String' ].
	b
		object: 'Post'
		description: nil
		implements: #( 'Node' )
		fields: [ :o |
				o field: 'id' type: 'ID!'.
				o field: 'title' type: 'String' ].
	b object: 'Query' fields: [ :o |
			o field: 'nodes' type: '[Node!]!' resolve: [ values ].
			o
				field: 'node'
				type: 'Node'
				args: { ('id' -> 'ID!') }
				resolve: [ :src :args |
					values
						detect: [ :v | (v at: 'id') = (args at: 'id') ]
						ifNone: [ nil ] ].
			o field: 'user' type: 'User' resolve: [ self userValue ].
			o field: 'named' type: '[Named!]!' resolve: [ { self userValue } ] ].
	b query: 'Query'.
	aResolverBlockOrNil ifNotNil: [ b typeResolver: aResolverBlockOrNil ].
	^ b
]

{ #category : 'helpers' }
GQLInterfaceTest >> errorsOf: aResult [
	"Answer the errors list of a response (empty when absent)"

	^ aResult at: 'errors' ifAbsent: [ #(  ) ]
]

{ #category : 'helpers' }
GQLInterfaceTest >> execute: aQuery [
	"Execute aQuery against the schema under test and answer the response dictionary"

	^ (GQLExecutor schema: schema)
		  execute: aQuery
		  operationName: nil
		  variables: nil
		  context: nil
]

{ #category : 'helpers' }
GQLInterfaceTest >> introspect: aTypeName [
	"Answer the __type introspection dictionary for aTypeName"

	| result |
	result := self execute: '{ __type(name: "' , aTypeName , '") { kind name fields { name } possibleTypes { name } interfaces { name } } }'.
	self assert: (self errorsOf: result) isEmpty.
	^ (result at: 'data') at: '__type'
]

{ #category : 'helpers' }
GQLInterfaceTest >> kindResolver [
	"Schema typeResolver used by default: the concrete type name is stored under 'kind'"

	^ [ :value | value at: 'kind' ]
]

{ #category : 'helpers' }
GQLInterfaceTest >> minimalBuilderQuerying: aTypeName [
	"Answer an unbuilt builder holding only 'type Query { it: <aTypeName> }' and the kind typeResolver.
	Validation tests add their own interface/object types on top of it (references are resolved at build time)"

	| b |
	b := GQLSchemaBuilder new.
	b object: 'Query' fields: [ :o | o field: 'it' type: aTypeName ].
	b query: 'Query'.
	b typeResolver: self kindResolver.
	^ b
]

{ #category : 'helpers' }
GQLInterfaceTest >> namesIn: aCollectionOrNil [
	"Answer the 'name' values of introspection entries as an Array"

	^ (aCollectionOrNil collect: [ :each | each at: 'name' ]) asArray
]

{ #category : 'helpers' }
GQLInterfaceTest >> postValue [
	"A Post value: the 'kind' key drives the schema typeResolver of the fixture"

	^ Dictionary new
		  at: 'kind' put: 'Post';
		  at: 'id' put: 'p1';
		  at: 'title' put: 'Hello';
		  yourself
]

{ #category : 'helpers' }
GQLInterfaceTest >> schemaWithResolver: aResolverBlockOrNil [
	"Build the fixture schema (see #builderWithResolver:) and keep it as the schema under test"

	^ schema := (self builderWithResolver: aResolverBlockOrNil) build
]

{ #category : 'running' }
GQLInterfaceTest >> setUp [
	"Build the fixture schema with a schema-level typeResolver reading the 'kind' key"

	super setUp.
	self schemaWithResolver: self kindResolver
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testCovariantFieldTypeAccepted [
	"Covariance: an interface field typed Node may be implemented with User (an implementer of Node),
	and a nullable String field may be implemented with String!"

	| b |
	b := self minimalBuilderQuerying: 'HasOwner'.
	b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	b interface: 'HasOwner' fields: [ :o |
		o field: 'owner' type: 'Node'.
		o field: 'label' type: 'String' ].
	b object: 'User' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'id' type: 'ID!' ].
	b object: 'Thing' description: nil implements: #( 'HasOwner' ) fields: [ :o |
		o field: 'owner' type: 'User'.
		o field: 'label' type: 'String!' ].
	self assert: (self buildErrorOf: b) isNil
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testExtraOptionalArgumentAccepted [
	"An implementing field may add optional (nullable) arguments"

	| b |
	b := self minimalBuilderQuerying: 'Searchable'.
	b interface: 'Searchable' fields: [ :o | o field: 'find' type: 'String' ].
	b object: 'Thing' description: nil implements: #( 'Searchable' ) fields: [ :o |
		o field: 'find' type: 'String' args: { 'q' -> 'String' } ].
	self assert: (self buildErrorOf: b) isNil
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testExtraRequiredArgumentFails [
	"An implementing field may not add a required (non-null, no default) argument absent from the interface field"

	| b error |
	b := self minimalBuilderQuerying: 'Searchable'.
	b interface: 'Searchable' fields: [ :o | o field: 'find' type: 'String' ].
	b object: 'Thing' description: nil implements: #( 'Searchable' ) fields: [ :o |
		o field: 'find' type: 'String' args: { 'q' -> 'String!' } ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'includes required argument q that is missing from the interface field')
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testImplementingNonInterfaceFails [
	"Only interfaces can be implemented: implementing an object type is reported at build time"

	| b error |
	b := self minimalBuilderQuerying: 'Thing'.
	b object: 'Other' fields: [ :o | o field: 'id' type: 'ID!' ].
	b object: 'Thing' description: nil implements: #( 'Other' ) fields: [ :o | o field: 'id' type: 'ID!' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'Type "Other" implemented by type "Thing" is not an interface')
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testIncompatibleFieldTypeFails [
	"The implementing field type must be a subtype of the interface field type: String is not a subtype of ID!"

	| b error |
	b := self minimalBuilderQuerying: 'Node'.
	b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	b object: 'Thing' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'id' type: 'String' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'Interface field Node.id expects type "')
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testInlineFragmentOnConcreteType [
	"Inline fragments on concrete types only apply to elements resolved to that type"

	| result nodes |
	result := self execute: '{ nodes { id ... on User { name } ... on Post { title } } }'.
	self assert: (self errorsOf: result) isEmpty.
	nodes := (result at: 'data') at: 'nodes'.
	self assert: (nodes first at: 'name') equals: 'Ann'.
	self deny: (nodes first includesKey: 'title').
	self assert: (nodes second at: 'title') equals: 'Hello'.
	self deny: (nodes second includesKey: 'name')
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testInterfaceFragmentInsideObjectField [
	"A fragment on an interface (Named) applies inside a field typed with an implementing object type (User)"

	| result user |
	result := self execute: '{ user { id ... on Named { name } } }'.
	self assert: (self errorsOf: result) isEmpty.
	user := (result at: 'data') at: 'user'.
	self assert: (user at: 'id') equals: 'u1'.
	self assert: (user at: 'name') equals: 'Ann'
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testInterfaceImplementingInterfaceIsValid [
	"An interface may implement another interface when it repeats its fields; implementers declare both"

	| b |
	b := self minimalBuilderQuerying: 'Named'.
	b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	b interface: 'Named' description: nil implements: #( 'Node' ) fields: [ :o |
		o field: 'id' type: 'ID!'.
		o field: 'name' type: 'String' ].
	b object: 'Thing' description: nil implements: #( 'Node' 'Named' ) fields: [ :o |
		o field: 'id' type: 'ID!'.
		o field: 'name' type: 'String' ].
	self assert: (self buildErrorOf: b) isNil
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testInterfaceMissingParentFieldFails [
	"An interface implementing another interface must itself provide the parent interface fields"

	| b error |
	b := self minimalBuilderQuerying: 'Named'.
	b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	b interface: 'Named' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'name' type: 'String' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'Interface field Node.id expected but type "Named" does not provide it')
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testInterfaceResolveTypeBlockReplacesSchemaResolver [
	"A per-interface resolveTypeBlock is enough: no schema typeResolver is then needed"

	| b node |
	b := GQLSchemaBuilder new.
	node := b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	node resolveTypeBlock: [ :value | 'Thing' ].
	b object: 'Thing' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'id' type: 'ID!' ].
	b object: 'Query' fields: [ :o | o field: 'it' type: 'Node' ].
	b query: 'Query'.
	self assert: (self buildErrorOf: b) isNil
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testInterfaceResolveTypeBlockTakesPrecedence [
	"The per-interface resolveTypeBlock wins over the schema-level typeResolver"

	| b node result |
	b := GQLSchemaBuilder new.
	node := b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	node resolveTypeBlock: [ :value | 'A' ].
	b object: 'A' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'id' type: 'ID!' ].
	b object: 'B' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'id' type: 'ID!' ].
	b object: 'Query' fields: [ :o |
		o field: 'it' type: 'Node' resolve: [ Dictionary new at: 'id' put: 'x'; yourself ] ].
	b query: 'Query'.
	b typeResolver: [ :value | 'B' ].
	schema := b build.
	result := self execute: '{ it { __typename id } }'.
	self assert: (self errorsOf: result) isEmpty.
	self assert: (((result at: 'data') at: 'it') at: '__typename') equals: 'A'
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testInterfaceWithoutFieldsFails [
	"An interface must define at least one field"

	| b error |
	b := self minimalBuilderQuerying: 'Empty'.
	b interface: 'Empty' fields: [ :o | ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'must define at least one field')
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testInterfaceWithoutResolverFails [
	"Without a schema typeResolver nor a per-interface resolveTypeBlock, abstract types cannot be resolved"

	| error |
	error := self buildErrorOf: (self builderWithResolver: nil).
	self assert: error notNil.
	self assert: (error includesSubstring: 'has no type resolver')
]

{ #category : 'tests - introspection' }
GQLInterfaceTest >> testIntrospectNamedInterface [
	"Named introspects as INTERFACE implementing Node, with User as only possible type"

	| type |
	type := self introspect: 'Named'.
	self assert: (type at: 'kind') equals: 'INTERFACE'.
	self assert: (self namesIn: (type at: 'fields')) equals: #( 'id' 'name' ).
	self assert: (self namesIn: (type at: 'possibleTypes')) equals: #( 'User' ).
	self assert: (self namesIn: (type at: 'interfaces')) equals: #( 'Node' )
]

{ #category : 'tests - introspection' }
GQLInterfaceTest >> testIntrospectNodeInterface [
	"Node introspects as INTERFACE with its fields, its implementers as possibleTypes (sorted by name), no interfaces"

	| type |
	type := self introspect: 'Node'.
	self assert: (type at: 'kind') equals: 'INTERFACE'.
	self assert: (type at: 'name') equals: 'Node'.
	self assert: (self namesIn: (type at: 'fields')) equals: #( 'id' ).
	self assert: (self namesIn: (type at: 'possibleTypes')) equals: #( 'Post' 'User' ).
	self assert: (self namesIn: (type at: 'interfaces')) equals: #(  )
]

{ #category : 'tests - introspection' }
GQLInterfaceTest >> testIntrospectObjectInterfaces [
	"User introspects as OBJECT listing both implemented interfaces; possibleTypes is null for object types"

	| type |
	type := self introspect: 'User'.
	self assert: (type at: 'kind') equals: 'OBJECT'.
	self assert: (self namesIn: (type at: 'interfaces')) asSet equals: #( 'Named' 'Node' ) asSet.
	self assert: (type at: 'possibleTypes') isNil.
	type := self introspect: 'Post'.
	self assert: (self namesIn: (type at: 'interfaces')) equals: #( 'Node' ).
	self assert: (type at: 'possibleTypes') isNil
]

{ #category : 'tests - introspection' }
GQLInterfaceTest >> testIntrospectObjectWithoutInterfaces [
	"An object type implementing nothing answers an empty interfaces list (not null)"

	self assert: ((self introspect: 'Query') at: 'interfaces') isEmpty
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testMissingInterfaceArgumentFails [
	"Every argument of the interface field must be accepted by the implementing field"

	| b error |
	b := self minimalBuilderQuerying: 'Searchable'.
	b interface: 'Searchable' fields: [ :o | o field: 'find' type: 'String' args: { 'q' -> 'String' } ].
	b object: 'Thing' description: nil implements: #( 'Searchable' ) fields: [ :o | o field: 'find' type: 'String' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'Interface field argument Searchable.find(q:) expected but')
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testMissingInterfaceFieldFails [
	"An object implementing an interface must provide every interface field"

	| b error |
	b := self minimalBuilderQuerying: 'Node'.
	b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	b object: 'Thing' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'name' type: 'String' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'Interface field Node.id expected but type "Thing" does not provide it')
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testMissingTransitiveInterfaceFails [
	"A type implementing Named (which implements Node) must also declare Node"

	| b error |
	b := self minimalBuilderQuerying: 'Named'.
	b interface: 'Node' fields: [ :o | o field: 'id' type: 'ID!' ].
	b interface: 'Named' description: nil implements: #( 'Node' ) fields: [ :o |
		o field: 'id' type: 'ID!'.
		o field: 'name' type: 'String' ].
	b object: 'Thing' description: nil implements: #( 'Named' ) fields: [ :o |
		o field: 'id' type: 'ID!'.
		o field: 'name' type: 'String' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'must implement "Node" because it is implemented by "Named"')
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testNamedFragmentSpreadOnConcreteType [
	"A named fragment on a concrete type applies only to elements of that type"

	| result nodes |
	result := self execute: 'query { nodes { id ...U } } fragment U on User { email }'.
	self assert: (self errorsOf: result) isEmpty.
	nodes := (result at: 'data') at: 'nodes'.
	self assert: (nodes first at: 'email') equals: 'ann@example.com'.
	self deny: (nodes second includesKey: 'email')
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testNamedFragmentSpreadOnInterface [
	"A named fragment on the interface type applies to every element"

	| result nodes |
	result := self execute: 'query { nodes { ...N } } fragment N on Node { id }'.
	self assert: (self errorsOf: result) isEmpty.
	nodes := (result at: 'data') at: 'nodes'.
	self assert: (nodes collect: [ :n | n at: 'id' ]) asArray equals: #( 'u1' 'p1' )
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testNodeByIdResolvesConcreteType [
	"A nullable interface field with arguments resolves to the concrete type of the found value"

	| result node |
	result := self execute: '{ node(id: "p1") { __typename ... on Post { title } } }'.
	self assert: (self errorsOf: result) isEmpty.
	node := (result at: 'data') at: 'node'.
	self assert: (node at: '__typename') equals: 'Post'.
	self assert: (node at: 'title') equals: 'Hello'
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testNullInterfaceValueIsNotAnError [
	"A nil value for a nullable interface field is answered as null without invoking the type resolver"

	| result |
	result := self execute: '{ node(id: "nope") { id } }'.
	self assert: (self errorsOf: result) isEmpty.
	self assert: ((result at: 'data') at: 'node') isNil
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testParentInterfaceFragmentInsideChildInterfaceList [
	"A fragment on Node applies to elements of a Named list, since Named implements Node"

	| result named |
	result := self execute: '{ named { __typename ... on Node { id } } }'.
	self assert: (self errorsOf: result) isEmpty.
	named := (result at: 'data') at: 'named'.
	self assert: named size equals: 1.
	self assert: (named first at: '__typename') equals: 'User'.
	self assert: (named first at: 'id') equals: 'u1'
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testResolutionErrorInNonNullListNullsData [
	"In [Node!]!, a resolution failure on an element propagates null up to the (nullable) data root"

	| result errors |
	self schemaWithResolver: [ :value | nil ].
	result := self execute: '{ nodes { id } }'.
	errors := self errorsOf: result.
	self assert: errors notEmpty.
	self assert: ((errors first at: 'message') includesSubstring: 'must resolve to an object type at runtime').
	self assert: (errors first at: 'path') asArray equals: #( 'nodes' 0 ).
	self assert: (result at: 'data' ifAbsent: [ nil ]) isNil
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testResolverAnsweringNilIsFieldError [
	"A resolver answering nil yields a field error; the nullable field becomes null"

	| result errors |
	self schemaWithResolver: [ :value | nil ].
	result := self execute: '{ node(id: "u1") { id } }'.
	errors := self errorsOf: result.
	self assert: errors size equals: 1.
	self assert: ((errors first at: 'message') includesSubstring: 'must resolve to an object type at runtime').
	self assert: (errors first at: 'path') asArray equals: #( 'node' ).
	self assert: ((result at: 'data') at: 'node') isNil
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testResolverAnsweringNonImplementingTypeIsFieldError [
	"A resolver answering an object type that does not implement the interface yields a field error with a path;
	the nullable field becomes null"

	| result errors |
	self schemaWithResolver: [ :value | 'Query' ].
	result := self execute: '{ node(id: "u1") { id } }'.
	errors := self errorsOf: result.
	self assert: errors size equals: 1.
	self assert: ((errors first at: 'message') includesSubstring: 'is not a possible type for').
	self assert: (errors first at: 'path') asArray equals: #( 'node' ).
	self assert: ((result at: 'data') at: 'node') isNil
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testResolverAnsweringUnknownTypeNameIsFieldError [
	"A resolver answering a name that is not a schema type yields a field error (same message as nil);
	the nullable field becomes null"

	| result errors |
	self schemaWithResolver: [ :value | 'Nope' ].
	result := self execute: '{ node(id: "u1") { id } }'.
	errors := self errorsOf: result.
	self assert: errors size equals: 1.
	self assert: ((errors first at: 'message') includesSubstring: 'must resolve to an object type at runtime').
	self assert: (errors first at: 'path') asArray equals: #( 'node' ).
	self assert: ((result at: 'data') at: 'node') isNil
]

{ #category : 'tests - introspection' }
GQLInterfaceTest >> testSchemaTypesListInterfaces [
	"__schema { types } lists Node and Named with kind INTERFACE"

	| result types kinds |
	result := self execute: '{ __schema { types { name kind } } }'.
	self assert: (self errorsOf: result) isEmpty.
	types := ((result at: 'data') at: '__schema') at: 'types'.
	kinds := Dictionary new.
	types do: [ :each | kinds at: (each at: 'name') put: (each at: 'kind') ].
	self assert: (kinds at: 'Node') equals: 'INTERFACE'.
	self assert: (kinds at: 'Named') equals: 'INTERFACE'.
	self assert: (kinds at: 'User') equals: 'OBJECT'
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testSelfImplementationFails [
	"An interface may not implement itself"

	| b error |
	b := self minimalBuilderQuerying: 'Node'.
	b interface: 'Node' description: nil implements: #( 'Node' ) fields: [ :o | o field: 'id' type: 'ID!' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'Type "Node" cannot implement itself')
]

{ #category : 'tests - execution' }
GQLInterfaceTest >> testTypenameThroughInterfaceList [
	"__typename selected through an interface-typed list answers the concrete object type of each element"

	| result nodes |
	result := self execute: '{ nodes { __typename id } }'.
	self assert: (self errorsOf: result) isEmpty.
	nodes := (result at: 'data') at: 'nodes'.
	self assert: (nodes collect: [ :n | n at: '__typename' ]) asArray equals: #( 'User' 'Post' ).
	self assert: (nodes collect: [ :n | n at: 'id' ]) asArray equals: #( 'u1' 'p1' )
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testUnknownInterfaceFails [
	"Implementing an undeclared interface is reported at build time"

	| b error |
	b := self minimalBuilderQuerying: 'Thing'.
	b object: 'Thing' description: nil implements: #( 'Missing' ) fields: [ :o | o field: 'id' type: 'ID!' ].
	error := self buildErrorOf: b.
	self assert: error notNil.
	self assert: (error includesSubstring: 'Unknown interface "Missing" implemented by type "Thing"')
]

{ #category : 'tests - validation' }
GQLInterfaceTest >> testValidInterfaceSchemaBuilds [
	"The fixture schema (interfaces Node and Named, Named implementing Node, User and Post implementing them) is valid"

	self assert: (self buildErrorOf: (self builderWithResolver: self kindResolver)) isNil
]

{ #category : 'helpers' }
GQLInterfaceTest >> userValue [
	"A User value: the 'kind' key drives the schema typeResolver of the fixture"

	^ Dictionary new
		  at: 'kind' put: 'User';
		  at: 'id' put: 'u1';
		  at: 'name' put: 'Ann';
		  at: 'email' put: 'ann@example.com';
		  yourself
]
