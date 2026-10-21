"
I install GraphQL introspection support on a GQLSchema: the object types __Schema, __Type, __Field, __InputValue, __EnumValue, __Directive, the enums __TypeKind and __DirectiveLocation, and the meta fields __schema and __type of the query type.

Introspection objects are the schema objects themselves: the GQLSchema for __Schema, GQLType instances for __Type, GQLFieldDefinition for __Field, GQLArgument for __InputValue, GQLEnumValueDefinition for __EnumValue and Dictionaries for __Directive.

Usage:
	GQLIntrospection installOn: aSchema

Installation is idempotent and done automatically by GQLSchemaBuilder>>build (through GQLSchema>>postBuild).
"
Class {
	#name : 'GQLIntrospection',
	#superclass : 'Object',
	#instVars : [
		'schema'
	],
	#category : 'GraphQL-Core-Introspection',
	#package : 'GraphQL-Core',
	#tag : 'Introspection'
}

{ #category : 'installing' }
GQLIntrospection class >> installOn: aSchema [
	"Install introspection types and meta fields on aSchema (idempotent). Answer aSchema"

	^ self new
		  schema: aSchema;
		  install
]

{ #category : 'testing' }
GQLIntrospection class >> isIntrospectionName: aString [
	"Answer whether aString is reserved for introspection (names starting with two underscores)"

	^ aString notNil and: [ aString asString beginsWith: '__' ]
]

{ #category : 'accessing' }
GQLIntrospection class >> typeNames [
	"Names of the types added to a schema by introspection"

	^ #( '__Schema' '__Type' '__Field' '__InputValue' '__EnumValue'
	     '__Directive' '__TypeKind' '__DirectiveLocation' )
]

{ #category : 'types' }
GQLIntrospection >> directiveLocationEnum [

	| type |
	type := GQLEnumType name: '__DirectiveLocation' values: {
			        ('QUERY' -> 'Location adjacent to a query operation.').
			        ('MUTATION' -> 'Location adjacent to a mutation operation.').
			        ('SUBSCRIPTION'
			         -> 'Location adjacent to a subscription operation.').
			        ('FIELD' -> 'Location adjacent to a field.').
			        ('FRAGMENT_DEFINITION'
			         -> 'Location adjacent to a fragment definition.').
			        ('FRAGMENT_SPREAD'
			         -> 'Location adjacent to a fragment spread.').
			        ('INLINE_FRAGMENT'
			         -> 'Location adjacent to an inline fragment.').
			        ('VARIABLE_DEFINITION'
			         -> 'Location adjacent to a variable definition.').
			        ('SCHEMA' -> 'Location adjacent to a schema definition.').
			        ('SCALAR' -> 'Location adjacent to a scalar definition.').
			        ('OBJECT'
			         -> 'Location adjacent to an object type definition.').
			        ('FIELD_DEFINITION'
			         -> 'Location adjacent to a field definition.').
			        ('ARGUMENT_DEFINITION'
			         -> 'Location adjacent to an argument definition.').
			        ('INTERFACE'
			         -> 'Location adjacent to an interface definition.').
			        ('UNION' -> 'Location adjacent to a union definition.').
			        ('ENUM' -> 'Location adjacent to an enum definition.').
			        ('ENUM_VALUE'
			         -> 'Location adjacent to an enum value definition.').
			        ('INPUT_OBJECT'
			         -> 'Location adjacent to an input object type definition.').
			        ('INPUT_FIELD_DEFINITION'
			         ->
			         'Location adjacent to an input object field definition.') }.
	type description:
		'A Directive can be adjacent to many parts of the GraphQL language, a __DirectiveLocation describes one such possible adjacencies.'.
	^ type
]

{ #category : 'resolving' }
GQLIntrospection >> directiveNamed: aName description: aDescription ifDescription: anArgumentDescription [
	"Answer a __Directive source Dictionary for a field/fragment directive taking an 'if: Boolean!' argument"

	| ifArgument |
	ifArgument := GQLArgument
		              name: 'if'
		              type:
		              (GQLNonNullType of: (schema typeNamed: 'Boolean'))
		              description: anArgumentDescription.
	^ Dictionary new
		  at: 'name' put: aName;
		  at: 'description' put: aDescription;
		  at: 'isRepeatable' put: false;
		  at: 'locations'
		  put: #( 'FIELD' 'FRAGMENT_SPREAD' 'INLINE_FRAGMENT' );
		  at: 'args' put: { ifArgument };
		  yourself
]

{ #category : 'types' }
GQLIntrospection >> directiveType [
	"__Directive; the source object is a Dictionary (see #directiveNamed:description:)"

	^ self
		  object: '__Directive'
		  description:
			  'A Directive provides a way to describe alternate runtime execution and type validation behavior in a GraphQL document.

In some cases, you need to provide options to alter GraphQL''s execution behavior in ways field arguments will not suffice, such as conditionally including or skipping a field. Directives provide this by describing additional information to the executor.'
		  fields: [ :f |
				  f
					  field: 'name'
					  type: 'String!'
					  description: nil
					  resolve: [ :d | d at: 'name' ].
				  f
					  field: 'description'
					  type: 'String'
					  description: nil
					  resolve: [ :d | d at: 'description' ifAbsent: [ nil ] ].
				  f
					  field: 'isRepeatable'
					  type: 'Boolean!'
					  description: nil
					  resolve: [ :d | d at: 'isRepeatable' ifAbsent: [ false ] ].
				  f
					  field: 'locations'
					  type: '[__DirectiveLocation!]!'
					  description: nil
					  resolve: [ :d | d at: 'locations' ].
				  f
					  field: 'args'
					  type: '[__InputValue!]!'
					  description: nil
					  args: { self includeDeprecatedArgument }
					  resolve: [ :d | d at: 'args' ifAbsent: [ #(  ) ] ] ]
]

{ #category : 'resolving' }
GQLIntrospection >> directives [
	"Answer the directives supported by the executor (@skip and @include), as Dictionaries"

	^ {
		  (self
			   directiveNamed: 'include'
			   description:
			   'Directs the executor to include this field or fragment only when the `if` argument is true.'
			   ifDescription: 'Included when true.').
		  (self
			   directiveNamed: 'skip'
			   description:
			   'Directs the executor to skip this field or fragment when the `if` argument is true.'
			   ifDescription: 'Skipped when true.') }
]

{ #category : 'types' }
GQLIntrospection >> enumValueType [
	"__EnumValue; the source object is a GQLEnumValueDefinition"

	^ self
		  object: '__EnumValue'
		  description:
		  'One possible value for a given Enum. Enum values are unique values, not a placeholder for a string or numeric value. However an Enum value is returned in a JSON response as a string.'
		  fields: [ :f |
				  f
					  field: 'name'
					  type: 'String!'
					  description: nil
					  resolve: [ :value | value name ].
				  f
					  field: 'description'
					  type: 'String'
					  description: nil
					  resolve: [ :value | value description ].
				  f
					  field: 'isDeprecated'
					  type: 'Boolean!'
					  description: nil
					  resolve: [ :value | value isDeprecated ].
				  f
					  field: 'deprecationReason'
					  type: 'String'
					  description: nil
					  resolve: [ :value | value deprecationReason ] ]
]

{ #category : 'resolving' }
GQLIntrospection >> enumValuesOf: aType includeDeprecated: aBoolean [
	"Answer the values of aType (nil unless it is an enum type)"

	aType isEnum ifFalse: [ ^ nil ].
	^ (aType values select: [ :each |
		   aBoolean or: [ each isDeprecated not ] ]) asArray
]

{ #category : 'types' }
GQLIntrospection >> fieldType [
	"__Field; the source object is a GQLFieldDefinition"

	^ self
		  object: '__Field'
		  description:
		  'Object and Interface types are described by a list of Fields, each of which has a name, potentially a list of arguments, and a return type.'
		  fields: [ :f |
				  f
					  field: 'name'
					  type: 'String!'
					  description: nil
					  resolve: [ :field | field name ].
				  f
					  field: 'description'
					  type: 'String'
					  description: nil
					  resolve: [ :field | field description ].
				  f
					  field: 'args'
					  type: '[__InputValue!]!'
					  description: nil
					  args: { self includeDeprecatedArgument }
					  resolve: [ :field | field arguments values asArray ].
				  f
					  field: 'type'
					  type: '__Type!'
					  description: nil
					  resolve: [ :field | field type ].
				  f
					  field: 'isDeprecated'
					  type: 'Boolean!'
					  description: nil
					  resolve: [ :field | field isDeprecated ].
				  f
					  field: 'deprecationReason'
					  type: 'String'
					  description: nil
					  resolve: [ :field | field deprecationReason ] ]
]

{ #category : 'resolving' }
GQLIntrospection >> fieldsOf: aType includeDeprecated: aBoolean [
	"Answer the introspectable fields of aType (nil unless it is an object type): meta fields (named __*) are hidden"

	aType isObject ifFalse: [ ^ nil ].
	^ (aType fields values select: [ :each |
			   (self class isIntrospectionName: each name) not and: [
				   aBoolean or: [ each isDeprecated not ] ] ]) asArray
]

{ #category : 'private' }
GQLIntrospection >> includeDeprecatedArgument [
	"The includeDeprecated: Boolean = false argument declaration"

	^ 'includeDeprecated' -> #( 'Boolean' false )
]

{ #category : 'private' }
GQLIntrospection >> includeDeprecatedIn: anArgsDictionary [
	"The includeDeprecated argument is coerced by the Boolean scalar: it is true, false, or nil when given as null (meaning false)"

	anArgsDictionary ifNil: [ ^ false ].
	^ (anArgsDictionary at: 'includeDeprecated' ifAbsent: [ nil ])
		  ifNil: [ false ]
]

{ #category : 'types' }
GQLIntrospection >> inputValueType [
	"__InputValue; the source object is a GQLArgument"

	^ self
		  object: '__InputValue'
		  description:
		  'Arguments provided to Fields or Directives and the input fields of an InputObject are represented as Input Values which describe their type and optionally a default value.'
		  fields: [ :f |
				  f
					  field: 'name'
					  type: 'String!'
					  description: nil
					  resolve: [ :arg | arg name ].
				  f
					  field: 'description'
					  type: 'String'
					  description: nil
					  resolve: [ :arg | arg description ].
				  f
					  field: 'type'
					  type: '__Type!'
					  description: nil
					  resolve: [ :arg | arg type ].
				  f
					  field: 'defaultValue'
					  type: 'String'
					  description:
					  'A GraphQL-formatted string representing the default value for this input value.'
					  resolve: [ :arg | arg defaultValueLiteral ].
				  f
					  field: 'isDeprecated'
					  type: 'Boolean!'
					  description: nil
					  resolve: [ :arg | false ].
				  f
					  field: 'deprecationReason'
					  type: 'String'
					  description: nil
					  resolve: [ :arg | nil ] ]
]

{ #category : 'installing' }
GQLIntrospection >> install [
	"Install introspection types and meta fields on my schema unless already done. Answer the schema"

	| newTypes |
	self isInstalled ifTrue: [ ^ schema ].
	newTypes := OrderedCollection new.
	newTypes add: self typeKindEnum.
	newTypes add: self directiveLocationEnum.
	newTypes
		add: self schemaType;
		add: self typeType;
		add: self fieldType;
		add: self inputValueType;
		add: self enumValueType;
		add: self directiveType.
	newTypes do: [ :each | schema addType: each ].
	newTypes do: [ :each | self resolveTypesOf: each ].
	self metaFieldDefinitions do: [ :each |
			each resolveTypeIn: schema.
			schema addMetaField: each ].
	^ schema
]

{ #category : 'testing' }
GQLIntrospection >> isInstalled [
	"Answer whether my schema already has the introspection types and meta fields"

	^ (self class typeNames allSatisfy: [ :each |
		   (schema typeNamed: each) notNil ]) and: [
			  (schema metaFieldNamed: '__schema') notNil and: [
				  (schema metaFieldNamed: '__type') notNil ] ]
]

{ #category : 'types' }
GQLIntrospection >> metaFieldDefinitions [
	"Answer the (unresolved) meta field definitions __schema and __type of the query type"

	| schemaField typeField |
	schemaField := GQLFieldDefinition name: '__schema' type: '__Schema!'.
	schemaField description:
		'Access the current type schema of this server.'.
	schemaField resolver: [ :source | schema ].
	typeField := GQLFieldDefinition name: '__type' type: '__Type'.
	typeField description:
		'Request the type information of a single type.'.
	typeField addArgument: (GQLArgument name: 'name' type: 'String!').
	typeField resolver: [ :source :args |
		schema typeNamed: (args at: 'name' ifAbsent: [ nil ]) ].
	^ {
		  schemaField.
		  typeField }
]

{ #category : 'private' }
GQLIntrospection >> object: aName description: aDescription fields: aBlock [
	"Answer a new GQLObjectType (not yet registered); aBlock receives a GQLObjectTypeBuilder"

	| type |
	type := GQLObjectType name: aName.
	type description: aDescription.
	aBlock value: (GQLObjectTypeBuilder on: type).
	^ type
]

{ #category : 'private' }
GQLIntrospection >> resolveTypesOf: aNamedType [
	"Resolve the type references of the fields and arguments of aNamedType against my schema"

	aNamedType resolveFieldTypesIn: schema
]

{ #category : 'accessing' }
GQLIntrospection >> schema [

	^ schema
]

{ #category : 'accessing' }
GQLIntrospection >> schema: aSchema [

	schema := aSchema
]

{ #category : 'types' }
GQLIntrospection >> schemaType [
	"__Schema; the source object is the GQLSchema"

	^ self
		  object: '__Schema'
		  description:
		  'A GraphQL Schema defines the capabilities of a GraphQL server. It exposes all available types and directives on the server, as well as the entry points for query, mutation, and subscription operations.'
		  fields: [ :f |
				  f
					  field: 'description'
					  type: 'String'
					  description: nil
					  resolve: [ :s | s description ].
				  f
					  field: 'types'
					  type: '[__Type!]!'
					  description: 'A list of all types supported by this server.'
					  resolve: [ :s | s allNamedTypes ].
				  f
					  field: 'queryType'
					  type: '__Type!'
					  description:
					  'The type that query operations will be rooted at.'
					  resolve: [ :s | s queryType ].
				  f
					  field: 'mutationType'
					  type: '__Type'
					  description:
					  'If this server supports mutation, the type that mutation operations will be rooted at.'
					  resolve: [ :s | nil ].
				  f
					  field: 'subscriptionType'
					  type: '__Type'
					  description:
					  'If this server support subscription, the type that subscription operations will be rooted at.'
					  resolve: [ :s | nil ].
				  f
					  field: 'directives'
					  type: '[__Directive!]!'
					  description:
					  'A list of all directives supported by this server.'
					  resolve: [ :s | self directives ] ]
]

{ #category : 'types' }
GQLIntrospection >> typeKindEnum [

	| type |
	type := GQLEnumType name: '__TypeKind' values: {
			        ('SCALAR' -> 'Indicates this type is a scalar.').
			        ('OBJECT'
			         ->
			         'Indicates this type is an object. `fields` and `interfaces` are valid fields.').
			        ('INTERFACE'
			         ->
			         'Indicates this type is an interface. `fields`, `interfaces`, and `possibleTypes` are valid fields.').
			        ('UNION'
			         ->
			         'Indicates this type is a union. `possibleTypes` is a valid field.').
			        ('ENUM'
			         ->
			         'Indicates this type is an enum. `enumValues` is a valid field.').
			        ('INPUT_OBJECT'
			         ->
			         'Indicates this type is an input object. `inputFields` is a valid field.').
			        ('LIST'
			         ->
			         'Indicates this type is a list. `ofType` is a valid field.').
			        ('NON_NULL'
			         ->
			         'Indicates this type is a non-null. `ofType` is a valid field.') }.
	type description:
		'An enum describing what kind of type a given `__Type` is.'.
	^ type
]

{ #category : 'types' }
GQLIntrospection >> typeType [
	"__Type; the source object is a GQLType (named or wrapper)"

	^ self
		  object: '__Type'
		  description:
			  'The fundamental unit of any GraphQL Schema is the type. There are many kinds of types in GraphQL as represented by the `__TypeKind` enum.

Depending on the kind of a type, certain fields describe information about that type. Scalar types provide no information beyond a name, description and optional `specifiedByURL`, while Enum types provide their values. Object and Interface types provide the fields they describe. Abstract types, Union and Interface, provide the Object types possible at runtime. List and NonNull types compose other types.'
		  fields: [ :f |
				  f
					  field: 'kind'
					  type: '__TypeKind!'
					  description: nil
					  resolve: [ :t | t kind ].
				  f
					  field: 'name'
					  type: 'String'
					  description: nil
					  resolve: [ :t | t name ].
				  f
					  field: 'description'
					  type: 'String'
					  description: nil
					  resolve: [ :t | t description ].
				  f
					  field: 'specifiedByURL'
					  type: 'String'
					  description: nil
					  resolve: [ :t | nil ].
				  f
					  field: 'fields'
					  type: '[__Field!]'
					  description: nil
					  args: { self includeDeprecatedArgument }
					  resolve: [ :t :args |
						  self
							  fieldsOf: t
							  includeDeprecated: (self includeDeprecatedIn: args) ].
				  f
					  field: 'interfaces'
					  type: '[__Type!]'
					  description: nil
					  resolve: [ :t | t interfaces ].
				  f
					  field: 'possibleTypes'
					  type: '[__Type!]'
					  description: nil
					  resolve: [ :t | nil ].
				  f
					  field: 'enumValues'
					  type: '[__EnumValue!]'
					  description: nil
					  args: { self includeDeprecatedArgument }
					  resolve: [ :t :args |
							  self
								  enumValuesOf: t
								  includeDeprecated: (self includeDeprecatedIn: args) ].
				  f
					  field: 'inputFields'
					  type: '[__InputValue!]'
					  description: nil
					  args: { self includeDeprecatedArgument }
					  resolve: [ :t | nil ].
				  f
					  field: 'ofType'
					  type: '__Type'
					  description: nil
					  resolve: [ :t | t ofType ].
				  f
					  field: 'isOneOf'
					  type: 'Boolean'
					  description: nil
					  resolve: [ :t | nil ] ]
]
