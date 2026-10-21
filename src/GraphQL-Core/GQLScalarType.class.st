"
I am a GraphQL scalar type. serializeBlock converts a Pharo result value to its output form, coerceBlock converts an input value. Both signal GQLCoercionError on invalid values. Built-ins: string, int, float, boolean, id (class side).
"
Class {
	#name : 'GQLScalarType',
	#superclass : 'GQLType',
	#instVars : [
		'serializeBlock',
		'coerceBlock'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'built-ins' }
GQLScalarType class >> boolean [

	| type check |
	type := self new
		        name: 'Boolean';
		        description:
			        'The `Boolean` scalar type represents `true` or `false`.';
		        yourself.
	check := [ :v |
		         (self isBooleanValue: v)
			         ifTrue: [ v ]
			         ifFalse: [ type coercionError: v ] ].
	type serializeBlock: check.
	type coerceBlock: check.
	^ type
]

{ #category : 'built-ins' }
GQLScalarType class >> builtIns [
	"Answer fresh instances of the five specified scalars"
	^ { self string. self int. self float. self boolean. self id }
]

{ #category : 'private' }
GQLScalarType class >> describe: aValue [
	^ [ (aValue printString truncateTo: 50) ] on: Error do: [ :e | 'a ' , aValue class name ]
]

{ #category : 'built-ins' }
GQLScalarType class >> float [

	| type |
	type := self new
		        name: 'Float';
		        description:
			        'The `Float` scalar type represents signed double-precision fractional values.';
		        yourself.
	type serializeBlock: [ :v |
			v isNumber
				ifTrue: [ v asFloat in: [ :f | f isFinite ifTrue: [ f ] ] ]
				ifFalse: [ type coercionError: v ] ].
	type coerceBlock: [ :v |
			(v isNumber and: [ v asFloat isFinite ])
				ifTrue: [ v asFloat ]
				ifFalse: [ type coercionError: v ] ].
	^ type
]

{ #category : 'built-ins' }
GQLScalarType class >> id [

	| type |
	type := self new
		        name: 'ID';
		        description:
			        'The `ID` scalar type represents a unique identifier, serialized as a String.';
		        yourself.
	type serializeBlock: [ :v |
			v isString
				ifTrue: [ v asString ]
				ifFalse: [
						[ v printString ]
							on: Error
							do: [ :e | type coercionError: v ] ] ].
	type coerceBlock: [ :v |
			v isString
				ifTrue: [ v asString ]
				ifFalse: [
						v isInteger
							ifTrue: [ v printString ]
							ifFalse: [ type coercionError: v ] ] ].
	^ type
]

{ #category : 'built-ins' }
GQLScalarType class >> int [
	| type toInt |
	type := self new name: 'Int'; description: 'The `Int` scalar type represents non-fractional signed whole numeric values.'; yourself.
	toInt := [ :v |
		v isInteger
			ifTrue: [ v ]
			ifFalse: [
				(v isFloat and: [ v isFinite and: [ v fractionPart = 0 ] ])
					ifTrue: [ v asInteger ]
					ifFalse: [ type coercionError: v ] ] ].
	type serializeBlock: toInt.
	type coerceBlock: [ :v |
		(v isString and: [ v matchesRegex: '-?[0-9]+' ])
			ifTrue: [ v asString asInteger ]
			ifFalse: [ toInt value: v ] ].
	^ type
]

{ #category : 'instance creation' }
GQLScalarType class >> name: aString description: aDescription serialize: aSerializeBlock coerce: aCoerceBlock [
	^ (self name: aString serialize: aSerializeBlock coerce: aCoerceBlock)
		description: aDescription;
		yourself
]

{ #category : 'instance creation' }
GQLScalarType class >> name: aString serialize: aSerializeBlock coerce: aCoerceBlock [
	^ self new
		name: aString;
		serializeBlock: aSerializeBlock;
		coerceBlock: aCoerceBlock;
		yourself
]

{ #category : 'built-ins' }
GQLScalarType class >> string [

	| type |
	type := self new
		        name: 'String';
		        description:
			        'The `String` scalar type represents textual data, represented as UTF-8 character sequences.';
		        yourself.
	type serializeBlock: [ :v |
			(v isString or: [ v isCharacter or: [ v isNumber ] ])
				ifTrue: [ v asString ]
				ifFalse: [
						[ v printString ]
							on: Error
							do: [ :e | type coercionError: v ] ] ].
	type coerceBlock: [ :v |
			v isString
				ifTrue: [ v asString ]
				ifFalse: [ type coercionError: v ] ].
	^ type
]

{ #category : 'coercion' }
GQLScalarType >> coerce: aValue [
	"Convert an input value (literal or variable) to its Pharo form. nil is passed through.
	Signal GQLCoercionError when the value is not acceptable."
	aValue ifNil: [ ^ nil ].
	^ coerceBlock ifNil: [ aValue ] ifNotNil: [ :b | b value: aValue ]
]

{ #category : 'accessing' }
GQLScalarType >> coerceBlock [
	^ coerceBlock
]

{ #category : 'accessing' }
GQLScalarType >> coerceBlock: aBlock [
	coerceBlock := aBlock
]

{ #category : 'execution' }
GQLScalarType >> coercePresentInputValue: aValue executor: anExecutor [

	^ self coerce: aValue
]

{ #category : 'coercion' }
GQLScalarType >> coercionError: aValue [
	^ GQLCoercionError signal: (self class describe: aValue) , ' is not a valid ' , name printString , ' value'
]

{ #category : 'execution' }
GQLScalarType >> completePresentValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [

	^ anExecutor
		  completeLeafValue: self
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
]

{ #category : 'testing' }
GQLScalarType >> isLeaf [
	^ true
]

{ #category : 'testing' }
GQLScalarType >> isScalar [
	^ true
]

{ #category : 'accessing' }
GQLScalarType >> kind [
	^ 'SCALAR'
]

{ #category : 'coercion' }
GQLScalarType >> serialize: aValue [
	"Convert a resolved Pharo value to its output form. nil is passed through.
	Signal GQLCoercionError when the value is not representable."
	aValue ifNil: [ ^ nil ].
	^ serializeBlock ifNil: [ aValue ] ifNotNil: [ :b | b value: aValue ]
]

{ #category : 'accessing' }
GQLScalarType >> serializeBlock [
	^ serializeBlock
]

{ #category : 'accessing' }
GQLScalarType >> serializeBlock: aBlock [
	serializeBlock := aBlock
]
