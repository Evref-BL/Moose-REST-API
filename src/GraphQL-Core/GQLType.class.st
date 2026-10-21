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

{ #category : 'testing' }
GQLType class >> isBooleanValue: anObject [
	"Answer whether anObject is true or false. anObject is an arbitrary value (resolver result, decoded JSON, literal),
	so this identity test is a type test, not a redundant Boolean comparison"

	^ anObject == true or: [ anObject == false ]
]

{ #category : 'literals' }
GQLType class >> listLiteralFor: aCollection itemType: anItemType [
	"Answer a GraphQL list literal; anItemType (a GQLType, or a GQLType class for untyped literals) answers the literal of each item"

	^ String streamContents: [ :s |
			  s nextPut: $[.
			  aCollection
				  do: [ :e | s nextPutAll: (anItemType literalFor: e) ]
				  separatedBy: [ s nextPutAll: ', ' ].
			  s nextPut: $] ]
]

{ #category : 'literals' }
GQLType class >> literalFor: aValue [
	"Answer a GraphQL literal String for a Pharo value, without type information"

	aValue ifNil: [ ^ 'null' ].
	(self isBooleanValue: aValue) ifTrue: [ ^ aValue printString ].
	aValue isString ifTrue: [ ^ self quotedString: aValue ].
	aValue isInteger ifTrue: [ ^ aValue printString ].
	aValue isNumber ifTrue: [ ^ aValue asFloat printString ].
	aValue isDictionary ifTrue: [ ^ self objectLiteralFor: aValue ].
	aValue isCollection ifTrue: [
		^ self listLiteralFor: aValue itemType: self ].
	^ self quotedString: aValue printString
]

{ #category : 'literals' }
GQLType class >> objectLiteralFor: aDictionary [
	"Answer a GraphQL input object literal for aDictionary, without type information"

	^ String streamContents: [ :s |
			  s nextPut: ${.
			  aDictionary keys
				  do: [ :k |
						  s
							  nextPutAll: k asString;
							  nextPutAll: ': ';
							  nextPutAll: (self literalFor: (aDictionary at: k)) ]
				  separatedBy: [ s nextPutAll: ', ' ].
			  s nextPut: $} ]
]

{ #category : 'literals' }
GQLType class >> quotedString: aString [
	"Answer aString as a GraphQL string literal, with escapes"

	| escapes |
	escapes := self stringEscapes.
	^ String streamContents: [ :s |
			  s nextPut: $".
			  aString asString do: [ :ch |
					  escapes
						  at: ch
						  ifPresent: [ :escape | s nextPutAll: escape ]
						  ifAbsent: [
								  ch asInteger < 32
									  ifTrue: [
											  s
												  nextPutAll: '\u';
												  nextPutAll:
													  ((ch asInteger printStringBase: 16) asLowercase
														   padLeftTo: 4
														   with: $0) ]
									  ifFalse: [ s nextPut: ch ] ] ].
			  s nextPut: $" ]
]

{ #category : 'literals' }
GQLType class >> stringEscapes [
	"Character -> escape sequence used in GraphQL string literals"

	^ Dictionary new
		  at: $" put: '\"';
		  at: $\ put: '\\';
		  at: Character lf put: '\n';
		  at: Character cr put: '\r';
		  at: Character tab put: '\t';
		  yourself
]

{ #category : 'execution' }
GQLType >> coerceInputValue: aValue executor: anExecutor [
	"Double dispatch from GQLExecutor: coerce an input value against the receiver (nullable) type.
	Signal GQLCoercionError on invalid values"

	aValue ifNil: [ ^ nil ].
	^ self coercePresentInputValue: aValue executor: anExecutor
]

{ #category : 'execution' }
GQLType >> coercePresentInputValue: aValue executor: anExecutor [
	"Coerce a non-nil input value. Subclasses usable as input types override this"

	^ GQLCoercionError signal:
		  'Type "' , self printString , '" is not an input type.'
]

{ #category : 'execution' }
GQLType >> completePresentValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [
	"Complete a non-nil aResult. Subclasses supporting output values override this"

	^ anExecutor
		  completeUnsupportedValue: self
		  fields: aFieldCollection
		  path: aPath
]

{ #category : 'execution' }
GQLType >> completeValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [
	"Double dispatch from GQLExecutor: complete aResult as a value of the receiver (nullable) type"

	aResult ifNil: [ ^ nil ].
	^ self
		  completePresentValue: aResult
		  fields: aFieldCollection
		  path: aPath
		  parentType: anObjectType
		  fieldDefinition: aFieldDefinition
		  executor: anExecutor
]

{ #category : 'accessing' }
GQLType >> description [
	^ description
]

{ #category : 'accessing' }
GQLType >> description: aString [
	description := aString
]

{ #category : 'accessing' }
GQLType >> interfaces [
	"Answer the interfaces implemented by the receiver (introspection __Type.interfaces): nil unless the receiver is an object type"

	^ nil
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

{ #category : 'execution' }
GQLType >> recoverFromFieldError: aFieldError [
	"A field error makes the value of a nullable type null"

	^ nil
]

{ #category : 'resolving' }
GQLType >> resolveFieldTypesIn: aSchema [
	"Resolve the type references of the fields and arguments of the receiver against aSchema. Only object types have fields"

	
]

{ #category : 'printing' }
GQLType >> sdlString [
	^ self printString
]
