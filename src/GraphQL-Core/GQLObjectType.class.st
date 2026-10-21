"
I am a GraphQL object type; fields is an OrderedDictionary name -> GQLFieldDefinition.
"
Class {
	#name : 'GQLObjectType',
	#superclass : 'GQLType',
	#instVars : [
		'fields'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLObjectType class >> name: aString [
	^ self new name: aString; yourself
]

{ #category : 'adding' }
GQLObjectType >> addField: aFieldDefinition [
	(fields includesKey: aFieldDefinition name) ifTrue: [
		^ self error: 'Field "' , aFieldDefinition name , '" is already defined in type "' , name asString , '"' ].
	^ fields at: aFieldDefinition name put: aFieldDefinition
]

{ #category : 'execution' }
GQLObjectType >> completePresentValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [

	^ anExecutor
		  completeObjectValue: self
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
]

{ #category : 'accessing' }
GQLObjectType >> fieldNamed: aString [
	^ fields at: aString asString ifAbsent: [ nil ]
]

{ #category : 'accessing' }
GQLObjectType >> fields [
	^ fields
]

{ #category : 'initialization' }
GQLObjectType >> initialize [
	super initialize.
	fields := OrderedDictionary new
]

{ #category : 'accessing' }
GQLObjectType >> interfaces [
	"Interfaces are not supported: an object type implements none"

	^ #(  )
]

{ #category : 'testing' }
GQLObjectType >> isObject [
	^ true
]

{ #category : 'accessing' }
GQLObjectType >> kind [
	^ 'OBJECT'
]

{ #category : 'resolving' }
GQLObjectType >> resolveFieldTypesIn: aSchema [

	fields do: [ :each | each resolveTypeIn: aSchema ]
]
