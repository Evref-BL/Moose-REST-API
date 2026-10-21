"
I am the abstract root of GraphQL schema types. Named types (scalars, enums, objects) have a name; wrapper types (list, non-null) wrap another type through ofType.
I print myself in SDL form: Name, [Inner], Inner!.
"
Class {
	#name : 'GQLType',
	#superclass : 'Object',
	#instVars : [
		'name',
		'description'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'literals' }
GQLType class >> literalFor: aValue [
	"Answer a GraphQL literal String for a Pharo value, without type information"
	aValue ifNil: [ ^ 'null' ].
	(aValue == true or: [ aValue == false ]) ifTrue: [ ^ aValue printString ].
	aValue isString ifTrue: [ ^ self quotedString: aValue ].
	aValue isInteger ifTrue: [ ^ aValue printString ].
	aValue isNumber ifTrue: [ ^ aValue asFloat printString ].
	aValue isDictionary ifTrue: [
		^ String streamContents: [ :s |
			s nextPut: ${.
			aValue keys
				do: [ :k | s nextPutAll: k asString; nextPutAll: ': '; nextPutAll: (self literalFor: (aValue at: k)) ]
				separatedBy: [ s nextPutAll: ', ' ].
			s nextPut: $} ] ].
	aValue isCollection ifTrue: [
		^ String streamContents: [ :s |
			s nextPut: $[.
			aValue do: [ :e | s nextPutAll: (self literalFor: e) ] separatedBy: [ s nextPutAll: ', ' ].
			s nextPut: $] ] ].
	^ self quotedString: aValue printString
]

{ #category : 'literals' }
GQLType class >> quotedString: aString [
	"Answer aString as a GraphQL string literal, with escapes"
	^ String streamContents: [ :s |
		s nextPut: $".
		aString asString do: [ :ch |
			ch = $" ifTrue: [ s nextPutAll: '\"' ] ifFalse: [
			ch = $\ ifTrue: [ s nextPutAll: '\\' ] ifFalse: [
			ch = Character lf ifTrue: [ s nextPutAll: '\n' ] ifFalse: [
			ch = Character cr ifTrue: [ s nextPutAll: '\r' ] ifFalse: [
			ch = Character tab ifTrue: [ s nextPutAll: '\t' ] ifFalse: [
			ch asInteger < 32
				ifTrue: [ s nextPutAll: '\u'; nextPutAll: ((ch asInteger printStringBase: 16) asLowercase padLeftTo: 4 with: $0) ]
				ifFalse: [ s nextPut: ch ] ] ] ] ] ] ].
		s nextPut: $" ]
]

{ #category : 'accessing' }
GQLType >> description [
	^ description
]

{ #category : 'accessing' }
GQLType >> description: aString [
	description := aString
]

{ #category : 'testing' }
GQLType >> isEnum [
	^ false
]

{ #category : 'testing' }
GQLType >> isInputType [
	"Answer whether the receiver can be used as an argument / variable type"
	^ self namedType isLeaf
]

{ #category : 'testing' }
GQLType >> isLeaf [
	"Scalars and enums are leaf types"
	^ false
]

{ #category : 'testing' }
GQLType >> isList [
	^ false
]

{ #category : 'testing' }
GQLType >> isNamed [
	^ true
]

{ #category : 'testing' }
GQLType >> isNonNull [
	^ false
]

{ #category : 'testing' }
GQLType >> isObject [
	^ false
]

{ #category : 'testing' }
GQLType >> isOutputType [
	^ true
]

{ #category : 'testing' }
GQLType >> isScalar [
	^ false
]

{ #category : 'testing' }
GQLType >> isWrapper [
	^ self isNamed not
]

{ #category : 'testing' }
GQLType >> kind [
	"Answer the introspection __TypeKind of the receiver as a String"
	^ self subclassResponsibility
]

{ #category : 'literals' }
GQLType >> literalFor: aValue [
	"Answer a GraphQL literal String representing aValue as a value of the receiver type"
	^ self class literalFor: aValue
]

{ #category : 'accessing' }
GQLType >> name [
	^ name
]

{ #category : 'accessing' }
GQLType >> name: aString [
	name := aString ifNotNil: [ :n | n asString ]
]

{ #category : 'accessing' }
GQLType >> namedType [
	"Answer the named type, unwrapping list and non-null wrappers"
	^ self
]

{ #category : 'accessing' }
GQLType >> nullableType [
	"Answer the receiver without its outermost non-null wrapper"
	^ self
]

{ #category : 'accessing' }
GQLType >> ofType [
	"Answer the wrapped type, nil for named types"
	^ nil
]

{ #category : 'printing' }
GQLType >> printOn: aStream [
	"SDL form of the type reference"
	aStream nextPutAll: (name ifNil: [ '<anonymous>' ])
]

{ #category : 'printing' }
GQLType >> sdlString [
	^ self printString
]
