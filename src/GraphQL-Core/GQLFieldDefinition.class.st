"
I describe a field of a GQLObjectType: its name, its type (a GQLType after schema build, typeRef holds the parsed type reference AST before resolution), its arguments (name -> GQLArgument) and an optional resolver block [:source :args :context | ...].
Without resolver, I resolve by Dictionary lookup (String or Symbol key) or by sending the unary selector named like me to the source.
"
Class {
	#name : 'GQLFieldDefinition',
	#superclass : 'Object',
	#instVars : [
		'name',
		'description',
		'type',
		'typeRef',
		'arguments',
		'resolver',
		'isDeprecated',
		'deprecationReason'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLFieldDefinition class >> name: aString type: aTypeSpec [
	^ self new name: aString; typeSpec: aTypeSpec; yourself
]

{ #category : 'adding' }
GQLFieldDefinition >> addArgument: aGQLArgument [
	(arguments includesKey: aGQLArgument name) ifTrue: [
		^ self error: 'Argument "' , aGQLArgument name , '" is already defined on field "' , name asString , '"' ].
	^ arguments at: aGQLArgument name put: aGQLArgument
]

{ #category : 'accessing' }
GQLFieldDefinition >> argumentNamed: aString [
	^ arguments at: aString asString ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GQLFieldDefinition >> arguments [
	"OrderedDictionary name -> GQLArgument"
	^ arguments
]

{ #category : 'resolving' }
GQLFieldDefinition >> defaultResolve: aSource [
	"Dictionary sources are looked up by String then Symbol key; other objects receive the unary message named like the field"

	| selector |
	aSource ifNil: [ ^ nil ].
	aSource isDictionary ifTrue: [
			^ aSource
				  at: name
				  ifAbsent: [ aSource at: name asSymbol ifAbsent: [ nil ] ] ].
	selector := name asSymbol.
	^ (selector numArgs = 0 and: [ aSource respondsTo: selector ])
		  ifTrue: [ aSource perform: selector ]
]

{ #category : 'accessing' }
GQLFieldDefinition >> deprecate: aReason [
	isDeprecated := true.
	deprecationReason := aReason
]

{ #category : 'accessing' }
GQLFieldDefinition >> deprecationReason [
	^ deprecationReason
]

{ #category : 'accessing' }
GQLFieldDefinition >> deprecationReason: aString [
	deprecationReason := aString
]

{ #category : 'accessing' }
GQLFieldDefinition >> description [
	^ description
]

{ #category : 'accessing' }
GQLFieldDefinition >> description: aString [
	description := aString
]

{ #category : 'initialization' }
GQLFieldDefinition >> initialize [
	super initialize.
	arguments := OrderedDictionary new.
	isDeprecated := false
]

{ #category : 'accessing' }
GQLFieldDefinition >> isDeprecated [
	^ isDeprecated
]

{ #category : 'accessing' }
GQLFieldDefinition >> isDeprecated: aBoolean [
	"Coerced once here so that #isDeprecated always answers a Boolean (nil or any non-true value means not deprecated)"

	isDeprecated := aBoolean == true
]

{ #category : 'accessing' }
GQLFieldDefinition >> name [
	^ name
]

{ #category : 'accessing' }
GQLFieldDefinition >> name: aString [
	name := aString asString
]

{ #category : 'printing' }
GQLFieldDefinition >> printOn: aStream [
	aStream
		nextPutAll: (name ifNil: [ '<unnamed>' ]);
		nextPutAll: ': ';
		nextPutAll: (self typeString ifNil: [ '?' ])
]

{ #category : 'resolving' }
GQLFieldDefinition >> resolve: aSource args: anArgsDictionary context: aContext [
	"Answer the value of this field for aSource. Use the resolver block if any, otherwise the default resolution"
	resolver ifNotNil: [ ^ resolver cull: aSource cull: anArgsDictionary cull: aContext ].
	^ self defaultResolve: aSource
]

{ #category : 'resolving' }
GQLFieldDefinition >> resolveTypeIn: aSchema [
	"Resolve my type and the types of my arguments"
	arguments do: [ :each | each resolveTypeIn: aSchema ].
	typeRef ifNil: [ ^ type ].
	^ type := aSchema resolveTypeRef: typeRef
]

{ #category : 'accessing' }
GQLFieldDefinition >> resolver [
	^ resolver
]

{ #category : 'accessing' }
GQLFieldDefinition >> resolver: aBlock [
	"aBlock is [ :source :args :context | ... ]; blocks with fewer arguments are accepted"
	resolver := aBlock
]

{ #category : 'accessing' }
GQLFieldDefinition >> type [
	"Answer the resolved GQLType (nil before the schema is built if declared with a type string)"
	^ type
]

{ #category : 'accessing' }
GQLFieldDefinition >> type: aGQLType [
	type := aGQLType
]

{ #category : 'accessing' }
GQLFieldDefinition >> typeRef [
	"Answer the parsed type reference AST, used to resolve the type when the schema is built"
	^ typeRef
]

{ #category : 'accessing' }
GQLFieldDefinition >> typeRef: aTypeRefNode [
	typeRef := aTypeRefNode
]

{ #category : 'accessing' }
GQLFieldDefinition >> typeSpec: aTypeSpec [
	"Set my type from a type String (e.g. '[ID!]!', parsed and resolved later), a type reference AST or a GQLType"
	aTypeSpec isString ifTrue: [ ^ typeRef := GQLParser parseTypeRef: aTypeSpec ].
	(aTypeSpec isKindOf: GQLType) ifTrue: [ ^ type := aTypeSpec ].
	(aTypeSpec isKindOf: GQLTypeRef) ifTrue: [ ^ typeRef := aTypeSpec ].
	self error: 'Invalid type specification: ' , aTypeSpec printString
]

{ #category : 'accessing' }
GQLFieldDefinition >> typeString [

	^ (type ifNil: [ typeRef ]) ifNotNil: [ :t | t printString ]
]
