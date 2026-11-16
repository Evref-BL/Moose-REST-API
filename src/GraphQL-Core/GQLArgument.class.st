"
I describe an argument of a field. defaultValue is a Pharo value; hasDefault tells whether a default was declared (a nil default is distinct from no default).
"
Class {
	#name : 'GQLArgument',
	#superclass : 'Object',
	#instVars : [
		'name',
		'description',
		'type',
		'typeRef',
		'defaultValue',
		'hasDefault'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLArgument class >> name: aString type: aTypeSpec [
	"aTypeSpec is a type String such as 'Int!', a type reference AST or a GQLType"
	^ self new name: aString; typeSpec: aTypeSpec; yourself
]

{ #category : 'instance creation' }
GQLArgument class >> name: aString type: aTypeSpec default: aValue [
	^ (self name: aString type: aTypeSpec) defaultValue: aValue; yourself
]

{ #category : 'instance creation' }
GQLArgument class >> name: aString type: aTypeSpec description: aDescription [
	^ (self name: aString type: aTypeSpec) description: aDescription; yourself
]

{ #category : 'instance creation' }
GQLArgument class >> name: aString type: aTypeSpec description: aDescription default: aValue [
	^ (self name: aString type: aTypeSpec default: aValue) description: aDescription; yourself
]

{ #category : 'accessing' }
GQLArgument >> defaultValue [
	"The default as a Pharo value (meaningful only if hasDefault)"
	^ defaultValue
]

{ #category : 'accessing' }
GQLArgument >> defaultValue: aValue [
	"Set a default value (a Pharo value; nil means a null default, which differs from no default)"
	defaultValue := aValue.
	hasDefault := true
]

{ #category : 'accessing' }
GQLArgument >> defaultValueLiteral [
	"Answer the default value as a GraphQL literal String (for introspection), nil if there is no default.
	Without a resolved type, the untyped GQLType class>>literalFor: is used"

	self hasDefault ifFalse: [ ^ nil ].
	^ (type ifNil: [ GQLType ]) literalFor: defaultValue
]

{ #category : 'accessing' }
GQLArgument >> description [
	^ description
]

{ #category : 'accessing' }
GQLArgument >> description: aString [
	description := aString
]

{ #category : 'testing' }
GQLArgument >> hasDefault [
	"Always a Boolean: initialized to false, set by #defaultValue: and #removeDefault"

	^ hasDefault
]

{ #category : 'initialization' }
GQLArgument >> initialize [
	super initialize.
	hasDefault := false
]

{ #category : 'testing' }
GQLArgument >> isRequired [
	"Answer whether the argument must be provided: non-null type without default value"

	^ type notNil and: [ type isNonNull and: [ self hasDefault not ] ]
]

{ #category : 'accessing' }
GQLArgument >> name [
	^ name
]

{ #category : 'accessing' }
GQLArgument >> name: aString [
	name := aString asString
]

{ #category : 'printing' }
GQLArgument >> printOn: aStream [
	aStream
		nextPutAll: (name ifNil: [ '<unnamed>' ]);
		nextPutAll: ': ';
		nextPutAll: (self typeString ifNil: [ '?' ])
]

{ #category : 'accessing' }
GQLArgument >> removeDefault [
	defaultValue := nil.
	hasDefault := false
]

{ #category : 'resolving' }
GQLArgument >> resolveTypeIn: aSchema [
	"Resolve my typeRef against aSchema (no-op if I was given a GQLType directly)"
	typeRef ifNil: [ ^ type ].
	^ type := aSchema resolveTypeRef: typeRef
]

{ #category : 'accessing' }
GQLArgument >> type [
	"Answer the resolved GQLType (nil before the schema is built if declared with a type string)"
	^ type
]

{ #category : 'accessing' }
GQLArgument >> type: aGQLType [
	type := aGQLType
]

{ #category : 'accessing' }
GQLArgument >> typeRef [
	"Answer the parsed type reference AST, used to resolve the type when the schema is built"
	^ typeRef
]

{ #category : 'accessing' }
GQLArgument >> typeRef: aTypeRefNode [
	typeRef := aTypeRefNode
]

{ #category : 'accessing' }
GQLArgument >> typeSpec: aTypeSpec [
	"Set my type from a type String (e.g. '[ID!]!', parsed and resolved later), a type reference AST or a GQLType"
	aTypeSpec isString ifTrue: [ ^ typeRef := GQLParser parseTypeRef: aTypeSpec ].
	(aTypeSpec isKindOf: GQLType) ifTrue: [ ^ type := aTypeSpec ].
	(aTypeSpec isKindOf: GQLTypeRef) ifTrue: [ ^ typeRef := aTypeSpec ].
	self error: 'Invalid type specification: ' , aTypeSpec printString
]

{ #category : 'accessing' }
GQLArgument >> typeString [

	^ (type ifNil: [ typeRef ]) ifNotNil: [ :t | t printString ]
]
