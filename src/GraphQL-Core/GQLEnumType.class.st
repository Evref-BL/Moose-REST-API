"
I am a GraphQL enum type; values is an OrderedCollection of GQLEnumValueDefinition.
"
Class {
	#name : 'GQLEnumType',
	#superclass : 'GQLType',
	#instVars : [
		'values'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLEnumType class >> name: aString values: aCollection [
	| type |
	type := self new name: aString; yourself.
	aCollection do: [ :each | type addValue: each ].
	^ type
]

{ #category : 'adding' }
GQLEnumType >> addValue: aValueOrName [
	"Add a GQLEnumValueDefinition, a String/Symbol name, or an Association name -> description"

	| def |
	def := self valueDefinitionFrom: aValueOrName.
	(self valueNamed: def name) ifNotNil: [
			^ self error:
				  'Enum value "' , def name , '" is already defined in enum "'
				  , name asString , '"' ].
	values add: def.
	^ def
]

{ #category : 'coercion' }
GQLEnumType >> coerce: aValue [
	"Answer the String name of the enum value; signal GQLCoercionError if aValue is not one of my values. nil is passed through."
	^ self serialize: aValue
]

{ #category : 'execution' }
GQLEnumType >> coercePresentInputValue: aValue executor: anExecutor [

	^ self coerce: aValue
]

{ #category : 'coercion' }
GQLEnumType >> coercionError: aValue [
	^ GQLCoercionError signal: (GQLScalarType describe: aValue) , ' is not a valid value of enum ' , name printString
]

{ #category : 'execution' }
GQLEnumType >> completePresentValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [

	^ anExecutor
		  completeLeafValue: self
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
]

{ #category : 'testing' }
GQLEnumType >> includesValue: aString [
	^ aString isString and: [ (self valueNamed: aString) notNil ]
]

{ #category : 'initialization' }
GQLEnumType >> initialize [
	super initialize.
	values := OrderedCollection new
]

{ #category : 'testing' }
GQLEnumType >> isEnum [
	^ true
]

{ #category : 'testing' }
GQLEnumType >> isLeaf [
	^ true
]

{ #category : 'accessing' }
GQLEnumType >> kind [
	^ 'ENUM'
]

{ #category : 'literals' }
GQLEnumType >> literalFor: aValue [

	(self includesValue: aValue) ifTrue: [ ^ aValue asString ].
	^ super literalFor: aValue
]

{ #category : 'coercion' }
GQLEnumType >> serialize: aValue [
	"Answer the String name of the enum value; signal GQLCoercionError if aValue is not one of my values. nil is passed through."
	aValue ifNil: [ ^ nil ].
	(self includesValue: aValue) ifFalse: [ ^ self coercionError: aValue ].
	^ aValue asString
]

{ #category : 'adding' }
GQLEnumType >> valueDefinitionFrom: aValueOrName [
	"Answer a GQLEnumValueDefinition from a GQLEnumValueDefinition, a String/Symbol name, or an Association name -> description"

	(aValueOrName isKindOf: GQLEnumValueDefinition) ifTrue: [
		^ aValueOrName ].
	aValueOrName isAssociation ifTrue: [
			^ GQLEnumValueDefinition
				  name: aValueOrName key
				  description: aValueOrName value ].
	^ GQLEnumValueDefinition name: aValueOrName
]

{ #category : 'accessing' }
GQLEnumType >> valueNamed: aString [
	"Answer the GQLEnumValueDefinition named aString, nil if absent"
	| key |
	key := aString asString.
	^ values detect: [ :v | v name = key ] ifNone: [ nil ]
]

{ #category : 'accessing' }
GQLEnumType >> valueNames [
	^ values collect: [ :v | v name ]
]

{ #category : 'accessing' }
GQLEnumType >> values [
	^ values
]
