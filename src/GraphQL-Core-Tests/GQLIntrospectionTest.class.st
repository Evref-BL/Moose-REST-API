"
Unit tests for GQLIntrospection: the __schema / __type meta fields, the __Schema, __Type, __Field, __InputValue, __EnumValue and __Directive types, and compatibility with the queries sent by common GraphQL clients (graphql-js getIntrospectionQuery, ""Fluid"" style queries).

Fixture (see #setUp): Query { hello, nums(take: Int = 3): [Int!]!, people: [Person!]!, person(id: ID!): Person, color: Color, old: String (deprecated) }, Person { id: ID!, name: String }, enum Color { RED GREEN }.
"
Class {
	#name : 'GQLIntrospectionTest',
	#superclass : 'TestCase',
	#instVars : [
		'schema'
	],
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'helpers' }
GQLIntrospectionTest >> execute: aQuery [

	^ self execute: aQuery variables: nil
]

{ #category : 'helpers' }
GQLIntrospectionTest >> execute: aQuery variables: aDictionary [
	"Execute aQuery and fail if any error is reported; answer the data"

	| result |
	result := schema execute: aQuery variables: aDictionary.
	self
		deny: (result includesKey: 'errors')
		description: [
		'Unexpected errors: ' , (result at: 'errors') printString ].
	^ result at: 'data'
]

{ #category : 'helpers' }
GQLIntrospectionTest >> graphqlJsIntrospectionQuery [
	"The text produced by graphql-js getIntrospectionQuery() with default options"

	^ '
    query IntrospectionQuery {
      __schema {
        
        queryType { name }
        mutationType { name }
        subscriptionType { name }
        types {
          ...FullType
        }
        directives {
          name
          description
          
          locations
          args {
            ...InputValue
          }
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description
      
      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue
      
      
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
  '
]

{ #category : 'running' }
GQLIntrospectionTest >> setUp [

	| b |
	super setUp.
	b := GQLSchemaBuilder new.
	b enum: 'Color' values: #( 'RED' 'GREEN' ).
	b object: 'Person' fields: [ :o |
			o field: 'id' type: 'ID!'.
			o field: 'name' type: 'String' ].
	b object: 'Query' fields: [ :o |
			o
				field: 'hello'
				type: 'String'
				description: 'Says hello'
				resolve: [ 'world' ].
			o
				field: 'nums'
				type: '[Int!]!'
				args: { (GQLArgument name: 'take' type: 'Int' default: 3) }
				resolve: [ :src :args | (1 to: (args at: 'take')) asArray ].
			o field: 'people' type: '[Person!]!' resolve: [ #(  ) ].
			o
				field: 'person'
				type: 'Person'
				args: { ('id' -> 'ID!') }
				resolve: [ :src :args |
						Dictionary new
							at: 'id' put: (args at: 'id');
							at: 'name' put: 'Ann';
							yourself ].
			o field: 'color' type: 'Color' resolve: [ 'RED' ].
			(o field: 'old' type: 'String' resolve: [ 'legacy' ]) deprecate:
				'Use hello' ].
	b query: 'Query'.
	schema := b build
]

{ #category : 'tests' }
GQLIntrospectionTest >> testAliasedTypeLookupsWithUnknownType [
	"An unknown type name answers null without any error"

	| data |
	data := self execute:
		        '{ t0: __type(name: "Nope") { name } t1: __type(name: "Person") { name kind } }'.
	self assert: data keys asArray equals: #( 't0' 't1' ).
	self assert: (data at: 't0') isNil.
	self assert: ((data at: 't1') at: 'name') equals: 'Person'.
	self assert: ((data at: 't1') at: 'kind') equals: 'OBJECT'
]

{ #category : 'tests' }
GQLIntrospectionTest >> testArgumentDefaultValue [
	"defaultValue is the default printed as a GraphQL literal, or null when there is none"

	| fields nums person |
	fields := ((self execute:
		            '{ __type(name: "Query") { fields { name args { name defaultValue type { kind name ofType { kind name } } } } } }')
		           at: '__type') at: 'fields'.
	nums := fields detect: [ :each | (each at: 'name') = 'nums' ].
	self assert: ((nums at: 'args') first at: 'defaultValue') equals: '3'.
	self
		assert: (((nums at: 'args') first at: 'type') at: 'kind')
		equals: 'SCALAR'.
	person := fields detect: [ :each | (each at: 'name') = 'person' ].
	self assert: ((person at: 'args') first at: 'defaultValue') isNil.
	self
		assert: (((person at: 'args') first at: 'type') at: 'kind')
		equals: 'NON_NULL'.
	self
		assert:
		((((person at: 'args') first at: 'type') at: 'ofType') at: 'name')
		equals: 'ID'.
	self assert:
		((fields detect: [ :each | (each at: 'name') = 'hello' ]) at: 'args')
			isEmpty
]

{ #category : 'tests' }
GQLIntrospectionTest >> testDeprecatedFieldHiddenUnlessRequested [

	| t old |
	t := (self execute:
		      '{ __type(name: "Query") { default: fields { name } hidden: fields(includeDeprecated: false) { name } all: fields(includeDeprecated: true) { name isDeprecated deprecationReason } } }')
		     at: '__type'.
	self deny:
		(((t at: 'default') collect: [ :each | each at: 'name' ]) includes:
			 'old').
	self deny:
		(((t at: 'hidden') collect: [ :each | each at: 'name' ]) includes:
			 'old').
	old := (t at: 'all') detect: [ :each | (each at: 'name') = 'old' ].
	self assert: (old at: 'isDeprecated') equals: true.
	self assert: (old at: 'deprecationReason') equals: 'Use hello'.
	self assert: (t at: 'all') size equals: (t at: 'default') size + 1.
	"a deprecated field can still be queried"
	self assert: ((self execute: '{ old }') at: 'old') equals: 'legacy'
]

{ #category : 'tests' }
GQLIntrospectionTest >> testEnumValues [

	| t |
	t := (self execute:
		      '{ __type(name: "Color") { kind fields { name } enumValues { name description isDeprecated deprecationReason } } }')
		     at: '__type'.
	self assert: (t at: 'kind') equals: 'ENUM'.
	self assert: (t at: 'fields') isNil.
	self
		assert:
		((t at: 'enumValues') collect: [ :each | each at: 'name' ]) asArray
		equals: #( 'RED' 'GREEN' ).
	(t at: 'enumValues') do: [ :each |
			self assert: (each at: 'isDeprecated') equals: false.
			self assert: (each at: 'deprecationReason') isNil ].
	"built-in introspection enums are introspectable too"
	t := (self execute:
		      '{ __type(name: "__TypeKind") { kind enumValues { name } } }')
		     at: '__type'.
	self assert: (t at: 'kind') equals: 'ENUM'.
	self assert:
		(((t at: 'enumValues') collect: [ :each | each at: 'name' ])
			 includesAll: #( 'SCALAR' 'OBJECT' 'ENUM' 'LIST' 'NON_NULL' ))
]

{ #category : 'tests - clients' }
GQLIntrospectionTest >> testFluidRootTypeQuery [
	"Exact query sent by the Fluid client to discover the root type"

	| s |
	s := (self execute:
		      'query FluidRootType { __schema { queryType { name __typename } __typename } }')
		     at: '__schema'.
	self assert: s equals: (OrderedDictionary new
			 at: 'queryType' put: (OrderedDictionary new
					  at: 'name' put: 'Query';
					  at: '__typename' put: '__Type';
					  yourself);
			 at: '__typename' put: '__Schema';
			 yourself)
]

{ #category : 'tests - clients' }
GQLIntrospectionTest >> testFluidTypeDeepQuery [
	"Exact deep query sent by the Fluid client: [Person!]! unwraps as NON_NULL / LIST / NON_NULL / OBJECT, wrappers have a null name and meta fields are not listed"

	| t fields people type nums |
	t := (self
		      execute:
		      'query FluidTypeDeep($name: String!) { __type(name: $name) { kind name description fields(includeDeprecated: false) { name description args { name type { kind name ofType { kind name ofType { kind name __typename } __typename } __typename } __typename } type { kind name ofType { kind name ofType { kind name ofType { kind name __typename } __typename } __typename } __typename } __typename } __typename } }'
		      variables: (Dictionary new
				       at: 'name' put: 'Query';
				       yourself)) at: '__type'.
	self assert: (t at: 'kind') equals: 'OBJECT'.
	self assert: (t at: 'name') equals: 'Query'.
	self assert: (t at: '__typename') equals: '__Type'.
	fields := t at: 'fields'.
	self
		assert: (fields collect: [ :each | each at: 'name' ]) asArray
		equals: #( 'hello' 'nums' 'people' 'person' 'color' ).
	self deny:
		((fields collect: [ :each | each at: 'name' ]) includesAny:
			 #( '__schema' '__type' '__typename' 'old' )).
	self
		assert:
			((fields detect: [ :each | (each at: 'name') = 'hello' ]) at:
				 'description')
		equals: 'Says hello'.
	people := fields detect: [ :each | (each at: 'name') = 'people' ].
	self assert: (people at: '__typename') equals: '__Field'.
	type := people at: 'type'.
	self assert: (type at: 'kind') equals: 'NON_NULL'.
	self assert: (type at: 'name') isNil.
	type := type at: 'ofType'.
	self assert: (type at: 'kind') equals: 'LIST'.
	self assert: (type at: 'name') isNil.
	type := type at: 'ofType'.
	self assert: (type at: 'kind') equals: 'NON_NULL'.
	self assert: (type at: 'name') isNil.
	type := type at: 'ofType'.
	self assert: (type at: 'kind') equals: 'OBJECT'.
	self assert: (type at: 'name') equals: 'Person'.
	self assert: (type at: '__typename') equals: '__Type'.
	nums := fields detect: [ :each | (each at: 'name') = 'nums' ].
	self assert: ((nums at: 'args') first at: 'name') equals: 'take'.
	self
		assert: ((nums at: 'args') first at: '__typename')
		equals: '__InputValue'.
	self
		assert: (((nums at: 'args') first at: 'type') at: 'name')
		equals: 'Int'
]

{ #category : 'tests - clients' }
GQLIntrospectionTest >> testFluidTypeShallowQuery [
	"Shallow variant of the Fluid type query: one level of ofType"

	| t id |
	t := (self
		      execute:
		      'query FluidType($name: String!) { __type(name: $name) { kind name description fields(includeDeprecated: false) { name description type { kind name ofType { kind name __typename } __typename } __typename } __typename } }'
		      variables: (Dictionary new
				       at: 'name' put: 'Person';
				       yourself)) at: '__type'.
	self assert: (t at: 'kind') equals: 'OBJECT'.
	self assert: (t at: 'name') equals: 'Person'.
	self assert: (t at: 'description') isNil.
	self
		assert:
		((t at: 'fields') collect: [ :each | each at: 'name' ]) asArray
		equals: #( 'id' 'name' ).
	id := (t at: 'fields') first at: 'type'.
	self assert: (id at: 'kind') equals: 'NON_NULL'.
	self assert: (id at: 'name') isNil.
	self assert: ((id at: 'ofType') at: 'kind') equals: 'SCALAR'.
	self assert: ((id at: 'ofType') at: 'name') equals: 'ID'.
	self assert: ((id at: 'ofType') at: '__typename') equals: '__Type'
]

{ #category : 'tests - clients' }
GQLIntrospectionTest >> testGraphqlJsIntrospectionQuery [
	"The full query from graphql-js getIntrospectionQuery() (used by GraphiQL, Apollo, codegen...) runs without errors"

	| result s types query |
	result := schema execute: self graphqlJsIntrospectionQuery.
	self deny: (result includesKey: 'errors').
	s := (result at: 'data') at: '__schema'.
	self assert: ((s at: 'queryType') at: 'name') equals: 'Query'.
	self assert: (s at: 'mutationType') isNil.
	types := s at: 'types'.
	query := types
		         detect: [ :each | (each at: 'name') = 'Query' ]
		         ifNone: [ nil ].
	self assert: query notNil.
	self assert: (query at: 'kind') equals: 'OBJECT'.
	"includeDeprecated: true is used by the query"
	self assert:
		(((query at: 'fields') collect: [ :each | each at: 'name' ])
			 includes: 'old').
	self
		assert:
			((types detect: [ :each | (each at: 'name') = 'Color' ]) at:
				 'enumValues') size
		equals: 2.
	"the response is JSON serializable"
	self assert:
		((NeoJSONReader fromString: (NeoJSONWriter toString: result))
			 includesKey: 'data')
]

{ #category : 'tests' }
GQLIntrospectionTest >> testInstallOnIsIdempotent [

	| typeCount typeNames names |
	self assert: (GQLIntrospection new
			 schema: schema;
			 isInstalled).
	typeCount := schema types size.
	self assert: (GQLIntrospection installOn: schema) identicalTo: schema.
	GQLIntrospection installOn: schema.
	schema installIntrospection.
	self assert: schema types size equals: typeCount.
	self
		assert: schema metaFields keys asSet
		equals: #( '__schema' '__type' ) asSet.
	typeNames := ((self execute: '{ __schema { types { name } } }') at:
		              '__schema') at: 'types'.
	names := typeNames collect: [ :each | each at: 'name' ].
	self assert: names asSet size equals: names size.
	self assert: (names count: [ :each | each = '__Type' ]) equals: 1
]

{ #category : 'tests' }
GQLIntrospectionTest >> testIntrospectionTypesAndDirectives [

	| s typeNames directives |
	s := (self execute:
		      '{ __schema { types { name } directives { name locations args { name type { kind ofType { name } } } } } }')
		     at: '__schema'.
	typeNames := (s at: 'types') collect: [ :each | each at: 'name' ].
	self assert: (typeNames includesAll:
			 #( 'Query' 'Person' 'Color' 'String' 'Int' 'Float' 'Boolean'
			    'ID' )).
	self assert: (typeNames includesAll:
			 #( '__Schema' '__Type' '__Field' '__InputValue' '__EnumValue'
			    '__Directive' '__TypeKind' '__DirectiveLocation' )).
	self assert: typeNames asSet size equals: typeNames size.
	directives := s at: 'directives'.
	self
		assert: (directives collect: [ :each | each at: 'name' ]) asSet
		equals: #( 'skip' 'include' ) asSet.
	directives do: [ :each |
			self assert: ((each at: 'locations') includesAll:
					 #( 'FIELD' 'FRAGMENT_SPREAD' 'INLINE_FRAGMENT' )).
			self
				assert: ((each at: 'args') collect: [ :a | a at: 'name' ]) asArray
				equals: #( 'if' ).
			self
				assert: (((each at: 'args') first at: 'type') at: 'kind')
				equals: 'NON_NULL'.
			self
				assert:
				((((each at: 'args') first at: 'type') at: 'ofType') at: 'name')
				equals: 'Boolean' ]
]

{ #category : 'tests' }
GQLIntrospectionTest >> testMetaFieldsOnlyOnQueryType [
	"__schema and __type are only available on the root query type; __typename is everywhere"

	| result |
	result := schema execute:
		          '{ person(id: 1) { name __typename __schema { description } } }'.
	self
		assert:
			((result at: 'errors') collect: [ :each | each at: 'message' ])
				asArray
		equals: #( 'Cannot query field "__schema" on type "Person".' ).
	self
		assert: (((result at: 'data') at: 'person') at: '__typename')
		equals: 'Person'.
	result := schema execute:
		          '{ person(id: 1) { __type(name: "Query") { name } } }'.
	self
		assert:
			((result at: 'errors') collect: [ :each | each at: 'message' ])
				asArray
		equals: #( 'Cannot query field "__type" on type "Person".' )
]

{ #category : 'tests' }
GQLIntrospectionTest >> testScalarHasNullFieldsAndLists [

	| t |
	t := (self execute:
		      '{ __type(name: "String") { kind name fields { name } enumValues { name } inputFields { name } interfaces { name } possibleTypes { name } ofType { name } } }')
		     at: '__type'.
	self assert: (t at: 'kind') equals: 'SCALAR'.
	self assert: (t at: 'name') equals: 'String'.
	#( 'fields' 'enumValues' 'inputFields' 'interfaces' 'possibleTypes'
	   'ofType' ) do: [ :key |
			self
				assert: (t at: key) isNil
				description: key , ' should be null for a scalar' ].
	"objects have an empty interface list, not null"
	t := (self execute:
		      '{ __type(name: "Query") { interfaces { name } enumValues { name } } }')
		     at: '__type'.
	self assert: (t at: 'interfaces') isEmpty.
	self assert: (t at: 'enumValues') isNil
]

{ #category : 'tests' }
GQLIntrospectionTest >> testSchemaRootTypes [

	| s |
	s := (self execute:
		      '{ __schema { queryType { name } mutationType { name } subscriptionType { name } } }')
		     at: '__schema'.
	self
		assert: s keys asArray
		equals: #( 'queryType' 'mutationType' 'subscriptionType' ).
	self assert: ((s at: 'queryType') at: 'name') equals: 'Query'.
	self assert: (s at: 'mutationType') isNil.
	self assert: (s at: 'subscriptionType') isNil
]

{ #category : 'tests' }
GQLIntrospectionTest >> testTypenameOfMetaObjects [

	| s t field arg |
	s := (self execute: '{ __schema { __typename } }') at: '__schema'.
	self assert: (s at: '__typename') equals: '__Schema'.
	t := (self execute:
		      '{ __type(name: "Query") { __typename fields { __typename name args { __typename name type { __typename kind } } } } }')
		     at: '__type'.
	self assert: (t at: '__typename') equals: '__Type'.
	field := (t at: 'fields') detect: [ :each |
		         (each at: 'name') = 'nums' ].
	self assert: (field at: '__typename') equals: '__Field'.
	arg := (field at: 'args') first.
	self assert: (arg at: '__typename') equals: '__InputValue'.
	self assert: ((arg at: 'type') at: '__typename') equals: '__Type'
]
