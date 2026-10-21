"
I am a non-null wrapper type around ofType.
"
Class {
	#name : 'GQLNonNullType',
	#superclass : 'GQLType',
	#instVars : [
		'ofType'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLNonNullType class >> of: aType [
	^ self new ofType: aType; yourself
]

{ #category : 'execution' }
GQLNonNullType >> coerceInputValue: aValue executor: anExecutor [

	aValue ifNil: [
			^ GQLCoercionError signal:
				  'Expected non-nullable type "' , self printString
				  , '" not to be null.' ].
	^ ofType coerceInputValue: aValue executor: anExecutor
]

{ #category : 'execution' }
GQLNonNullType >> completeValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [

	^ anExecutor
		  completeNonNullValue: self
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
		  parentType: anObjectType
		  fieldDefinition: aFieldDefinition
]

{ #category : 'testing' }
GQLNonNullType >> isLeaf [
	^ false
]

{ #category : 'testing' }
GQLNonNullType >> isNamed [
	^ false
]

{ #category : 'testing' }
GQLNonNullType >> isNonNull [
	^ true
]

{ #category : 'accessing' }
GQLNonNullType >> kind [
	^ 'NON_NULL'
]

{ #category : 'literals' }
GQLNonNullType >> literalFor: aValue [
	^ ofType literalFor: aValue
]

{ #category : 'accessing' }
GQLNonNullType >> name [
	"Wrapper types are anonymous"
	^ nil
]

{ #category : 'accessing' }
GQLNonNullType >> namedType [
	^ ofType ifNotNil: [ :t | t namedType ]
]

{ #category : 'accessing' }
GQLNonNullType >> nullableType [
	^ ofType
]

{ #category : 'accessing' }
GQLNonNullType >> ofType [
	^ ofType
]

{ #category : 'accessing' }
GQLNonNullType >> ofType: aType [
	ofType := aType
]

{ #category : 'printing' }
GQLNonNullType >> printOn: aStream [
	aStream print: ofType; nextPut: $!
]

{ #category : 'execution' }
GQLNonNullType >> recoverFromFieldError: aFieldError [
	"A non-null value cannot be made null: propagate the error to the nearest nullable position"

	^ aFieldError pass
]
