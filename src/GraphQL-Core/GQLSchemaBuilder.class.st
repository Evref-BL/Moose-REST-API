"
I am a small DSL to build a GQLSchema:
	b := GQLSchemaBuilder new.
	b object: 'Query' fields: [ :o | o field: 'hello' type: 'String!' resolve: [ :src :args :ctx | 'world' ] ].
	b enum: 'Color' values: #('RED' 'GREEN').
	b query: 'Query'.
	schema := b build.
Type strings are parsed eagerly and resolved in #build, so forward references work.
"
Class {
	#name : 'GQLSchemaBuilder',
	#superclass : 'Object',
	#instVars : [
		'schema',
		'queryTypeName'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'private' }
GQLSchemaBuilder >> addCompositeType: aCompositeType description: aDescription implements: interfaceNames fields: aBlock [
	"Register aCompositeType (object or interface type) after declaring its description, interfaces and fields. Answer it"

	(schema typeNamed: aCompositeType name) ifNotNil: [
			^ self error:
				  'Type "' , aCompositeType name asString , '" is already defined' ].
	aCompositeType description: aDescription.
	interfaceNames ifNotNil: [
			(interfaceNames isString
				 ifTrue: [ { interfaceNames } ]
				 ifFalse: [ interfaceNames ]) do: [ :each |
				aCompositeType addInterfaceNamed: each ] ].
	aBlock ifNotNil: [
		aBlock value: (GQLObjectTypeBuilder on: aCompositeType) ].
	^ schema addType: aCompositeType
]

{ #category : 'building' }
GQLSchemaBuilder >> build [
	"Resolve all type references, set the query type (defaults to 'Query'), validate and answer the GQLSchema"
	| name |
	schema resolveTypes.
	name := queryTypeName ifNil: [ 'Query' ].
	(schema typeNamed: name) ifNil: [ ^ self error: 'Unknown query type "' , name asString , '"' ].
	schema queryType: name asString.
	schema validate.
	schema postBuild.
	^ schema
]

{ #category : 'accessing' }
GQLSchemaBuilder >> description: aString [
	schema description: aString
]

{ #category : 'declaring' }
GQLSchemaBuilder >> enum: aName description: aDescription values: aCollection [
	"aCollection elements: names (String/Symbol), Associations name -> description, or GQLEnumValueDefinition"
	| type |
	(schema typeNamed: aName) ifNotNil: [ ^ self error: 'Type "' , aName asString , '" is already defined' ].
	type := GQLEnumType name: aName values: aCollection.
	type description: aDescription.
	^ schema addType: type
]

{ #category : 'declaring' }
GQLSchemaBuilder >> enum: aName values: aCollection [
	^ self enum: aName description: nil values: aCollection
]

{ #category : 'initialization' }
GQLSchemaBuilder >> initialize [
	super initialize.
	schema := GQLSchema new
]

{ #category : 'declaring' }
GQLSchemaBuilder >> interface: aName description: aDescription fields: aBlock [
	"Declare an interface type; aBlock receives a GQLObjectTypeBuilder. Answer the GQLInterfaceType"

	^ self
		  interface: aName
		  description: aDescription
		  implements: #(  )
		  fields: aBlock
]

{ #category : 'declaring' }
GQLSchemaBuilder >> interface: aName description: aDescription implements: interfaceNames fields: aBlock [
	"Declare an interface type implementing the interfaces named in interfaceNames (a collection of names, or a single name);
	aBlock receives a GQLObjectTypeBuilder. Answer the GQLInterfaceType (send it #resolveTypeBlock: to give it its own type resolver)"

	^ self
		  addCompositeType: (GQLInterfaceType name: aName)
		  description: aDescription
		  implements: interfaceNames
		  fields: aBlock
]

{ #category : 'declaring' }
GQLSchemaBuilder >> interface: aName fields: aBlock [

	^ self interface: aName description: nil fields: aBlock
]

{ #category : 'declaring' }
GQLSchemaBuilder >> object: aName description: aDescription fields: aBlock [
	"Declare an object type; aBlock receives a GQLObjectTypeBuilder. Answer the GQLObjectType"

	^ self
		  object: aName
		  description: aDescription
		  implements: #(  )
		  fields: aBlock
]

{ #category : 'declaring' }
GQLSchemaBuilder >> object: aName description: aDescription implements: interfaceNames fields: aBlock [
	"Declare an object type implementing the interfaces named in interfaceNames (a collection of names, or a single name);
	aBlock receives a GQLObjectTypeBuilder. Answer the GQLObjectType"

	^ self
		  addCompositeType: (GQLObjectType name: aName)
		  description: aDescription
		  implements: interfaceNames
		  fields: aBlock
]

{ #category : 'declaring' }
GQLSchemaBuilder >> object: aName fields: aBlock [
	^ self object: aName description: nil fields: aBlock
]

{ #category : 'declaring' }
GQLSchemaBuilder >> query: aTypeName [
	queryTypeName := aTypeName
]

{ #category : 'declaring' }
GQLSchemaBuilder >> scalar: aGQLScalarType [
	"Register a custom scalar (may replace a built-in scalar of the same name)"
	^ schema addType: aGQLScalarType
]

{ #category : 'accessing' }
GQLSchemaBuilder >> schema [
	"The schema under construction"
	^ schema
]

{ #category : 'declaring' }
GQLSchemaBuilder >> type: aNamedGQLType [
	"Register an already built named type"
	^ schema addType: aNamedGQLType
]

{ #category : 'declaring' }
GQLSchemaBuilder >> typeResolver: aBlock [
	"Set the schema default type resolver of abstract types: aBlock is evaluated with cull: value cull: context cull: abstractType
	and answers the name of the concrete object type"

	schema typeResolver: aBlock
]
