"
I am a GraphQL schema: a registry of named types (built-in scalars are registered at creation) and the root query type.
Use GQLSchemaBuilder to build me. #postBuild is a hook called by the builder after resolution and validation (e.g. to install introspection types later).
"
Class {
	#name : 'GQLSchema',
	#superclass : 'Object',
	#instVars : [
		'queryType',
		'types',
		'description',
		'metaFields'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'adding' }
GQLSchema >> addMetaField: aGQLFieldDefinition [
	"Register a meta field available on the query type (not listed by introspection) and answer it"

	^ self metaFields
		  at: aGQLFieldDefinition name
		  put: aGQLFieldDefinition
]

{ #category : 'adding' }
GQLSchema >> addType: aNamedType [
	"Register a named type (replacing any type with the same name) and answer it"

	aNamedType name isEmptyOrNil ifTrue: [
			^ self error:
				  'Cannot register a type without name: ' , aNamedType printString ].
	aNamedType isNamed ifFalse: [
			^ self error:
				  'Cannot register a wrapper type: ' , aNamedType printString ].
	^ types at: aNamedType name put: aNamedType
]

{ #category : 'accessing' }
GQLSchema >> allNamedTypes [
	"All registered named types sorted by name"
	^ (types values asSortedCollection: [ :a :b | a name <= b name ]) asArray
]

{ #category : 'accessing' }
GQLSchema >> description [
	^ description
]

{ #category : 'accessing' }
GQLSchema >> description: aString [
	description := aString
]

{ #category : 'execution' }
GQLSchema >> execute: aQueryString [
	^ self execute: aQueryString operationName: nil variables: nil context: nil
]

{ #category : 'execution' }
GQLSchema >> execute: aQueryString operationName: anOperationNameOrNil variables: aDictionaryOrNil context: anObject [
	"Execute a GraphQL request against the receiver; answer an OrderedDictionary with 'data' and/or 'errors'"
	^ (GQLExecutor schema: self)
		execute: aQueryString
		operationName: anOperationNameOrNil
		variables: aDictionaryOrNil
		context: anObject
]

{ #category : 'execution' }
GQLSchema >> execute: aQueryString variables: aDictionaryOrNil [
	^ self execute: aQueryString operationName: nil variables: aDictionaryOrNil context: nil
]

{ #category : 'accessing' }
GQLSchema >> existingTypeNamed: aString [
	"Answer the type named aString; signal an Error if it is not registered"

	^ (self typeNamed: aString) ifNil: [
		  self error: 'Unknown type "' , aString asString , '"' ]
]

{ #category : 'accessing' }
GQLSchema >> includesTypeNamed: aString [
	^ (self typeNamed: aString) notNil
]

{ #category : 'initialization' }
GQLSchema >> initialize [
	super initialize.
	types := Dictionary new.
	GQLScalarType builtIns do: [ :each | self addType: each ]
]

{ #category : 'building' }
GQLSchema >> installIntrospection [
	"Add the introspection types (__Schema, __Type...) and the meta fields __schema and __type. Idempotent. Answer the receiver"

	GQLIntrospection installOn: self
]

{ #category : 'accessing' }
GQLSchema >> metaFieldNamed: aString [
	"Answer the GQLFieldDefinition of a meta field (such as __schema or __type) available on the query type, nil if none"

	aString ifNil: [ ^ nil ].
	^ self metaFields at: aString asString ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GQLSchema >> metaFields [
	"OrderedDictionary name -> GQLFieldDefinition of the meta fields (such as __schema and __type) available on the query type"

	^ metaFields ifNil: [ metaFields := OrderedDictionary new ]
]

{ #category : 'accessing' }
GQLSchema >> objectTypes [
	^ self allNamedTypes select: [ :each | each isObject ]
]

{ #category : 'building' }
GQLSchema >> postBuild [
	"Hook called by GQLSchemaBuilder>>build once types are resolved and the schema validated: install introspection support"

	self installIntrospection
]

{ #category : 'printing' }
GQLSchema >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; print: types size; nextPutAll: ' types'.
	queryType ifNotNil: [ :q | aStream nextPutAll: ', query: '; nextPutAll: q name ].
	aStream nextPut: $)
]

{ #category : 'accessing' }
GQLSchema >> queryType [
	^ queryType
]

{ #category : 'accessing' }
GQLSchema >> queryType: aTypeOrName [
	"Set the root query type, given as a GQLObjectType or the name of a registered type"
	aTypeOrName isString ifFalse: [ ^ queryType := aTypeOrName ].
	queryType := (self typeNamed: aTypeOrName) ifNil: [
		^ self error: 'Unknown query type "' , aTypeOrName , '"' ]
]

{ #category : 'adding' }
GQLSchema >> removeTypeNamed: aString [
	^ types removeKey: aString asString ifAbsent: [ nil ]
]

{ #category : 'private' }
GQLSchema >> resolveTypeOf: aFieldOrArgument describedAs: aString [
	| ref |
	ref := aFieldOrArgument typeRef ifNil: [ ^ aFieldOrArgument type ].
	(self typeNamed: ref typeName) ifNil: [
		^ self error: 'Unknown type "' , ref typeName asString , '" referenced by ' , aString ].
	^ aFieldOrArgument type: (self resolveTypeRef: ref)
]

{ #category : 'resolving' }
GQLSchema >> resolveTypeRef: aTypeRef [
	"Answer the GQLType for a type reference AST (or a type String such as '[ID!]!'), building list/non-null wrappers.
	Signal an Error for unknown type names."

	| ref |
	ref := aTypeRef isString
		       ifTrue: [ GQLParser parseTypeRef: aTypeRef ]
		       ifFalse: [ aTypeRef ].
	^ ref resolveIn: self
]

{ #category : 'resolving' }
GQLSchema >> resolveTypes [
	"Resolve the type references of all fields and arguments of the object types"
	self objectTypes do: [ :objectType |
		objectType fields do: [ :field |
			field arguments do: [ :arg |
				self resolveTypeOf: arg describedAs: 'argument "' , arg name , '" of field ' , objectType name , '.' , field name ].
			self resolveTypeOf: field describedAs: 'field ' , objectType name , '.' , field name ] ]
]

{ #category : 'accessing' }
GQLSchema >> typeNamed: aString [
	aString ifNil: [ ^ nil ].
	^ types at: aString asString ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GQLSchema >> types [
	"Dictionary name -> GQLType"
	^ types
]

{ #category : 'validation' }
GQLSchema >> validate [
	"Check the schema is consistent; signal an Error with a clear message otherwise. Answer the receiver."

	queryType ifNil: [ ^ self error: 'Schema has no query type' ].
	queryType isObject ifFalse: [
			^ self error:
				  'Query type "' , queryType name asString
				  , '" must be an object type' ].
	(self typeNamed: queryType name) == queryType ifFalse: [
			^ self error: 'Query type "' , queryType name asString
				  , '" is not registered in the schema' ].
	self objectTypes do: [ :objectType |
			objectType fields ifEmpty: [
					^ self error:
						  'Object type "' , objectType name
						  , '" must define at least one field' ].
			objectType fields do: [ :field |
					self
						validateType: field type
						describedAs: 'field ' , objectType name , '.' , field name.
					field arguments do: [ :arg |
							| where |
							where := 'argument "' , arg name , '" of field '
							         , objectType name , '.' , field name.
							self validateType: arg type describedAs: where.
							arg type isInputType ifFalse: [
									^ self error:
										  'Type "' , arg type printString , '" of ' , where
										  , ' is not an input type' ] ] ] ].
	^ self
]

{ #category : 'private' }
GQLSchema >> validateType: aType describedAs: aString [

	| namedType |
	(aType isKindOf: GQLType) ifFalse: [
		^ self error: 'Type of ' , aString , ' is not resolved' ].
	namedType := aType namedType.
	(namedType notNil and: [
		 (self typeNamed: namedType name) == namedType ]) ifFalse: [
			^ self error: 'Type "' , aType printString , '" of ' , aString
				  , ' is not registered in the schema' ]
]
