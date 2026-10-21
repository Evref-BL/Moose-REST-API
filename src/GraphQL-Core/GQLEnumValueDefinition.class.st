"
I describe one value of a GQLEnumType.
"
Class {
	#name : 'GQLEnumValueDefinition',
	#superclass : 'Object',
	#instVars : [
		'name',
		'description',
		'isDeprecated',
		'deprecationReason'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLEnumValueDefinition class >> name: aString [
	^ self new name: aString; yourself
]

{ #category : 'instance creation' }
GQLEnumValueDefinition class >> name: aString description: aDescription [
	^ self new name: aString; description: aDescription; yourself
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> deprecate: aReason [
	isDeprecated := true.
	deprecationReason := aReason
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> deprecationReason [
	^ deprecationReason
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> deprecationReason: aString [
	deprecationReason := aString
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> description [
	^ description
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> description: aString [
	description := aString
]

{ #category : 'initialization' }
GQLEnumValueDefinition >> initialize [
	super initialize.
	isDeprecated := false
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> isDeprecated [
	^ isDeprecated
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> isDeprecated: aBoolean [
	"Coerced once here so that #isDeprecated always answers a Boolean (nil or any non-true value means not deprecated)"

	isDeprecated := aBoolean == true
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> name [
	^ name
]

{ #category : 'accessing' }
GQLEnumValueDefinition >> name: aString [
	name := aString asString
]

{ #category : 'printing' }
GQLEnumValueDefinition >> printOn: aStream [
	aStream nextPutAll: (name ifNil: [ '<unnamed>' ])
]
